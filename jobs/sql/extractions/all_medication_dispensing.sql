SELECT encounter_type_id INTO @disp_enc_type FROM encounter_type et WHERE uuid='8ff50dea-18a1-4609-b4c9-3f8f2d611b84';
SET @partition = '${partitionNum}';
set @locale = 'fr';

-- ---------------------------------------------------------------
-- 0. Resolve every lookup ONCE up front
-- ---------------------------------------------------------------
set @dispensing_construct = concept_from_mapping('PIH','9070');
set @dose            = concept_from_mapping('PIH','9073');
set @doseUnit        = concept_from_mapping('PIH','9074');
set @drug            = concept_from_mapping('PIH','1282');
set @duration        = concept_from_mapping('PIH','9075');
set @duration_unit   = concept_from_mapping('PIH','6412');
set @frequency       = concept_from_mapping('PIH','9363');
set @inxs            = concept_from_mapping('PIH','9072');
set @quantity        = concept_from_mapping('PIH','9071');
set @qunits          = concept_from_mapping('PIH','9074');
set @complete_status = concept_from_mapping('PIH','1267');
set @primary_emr_id  = METADATA_UUID('org.openmrs.module.emrapi', 'emr.primaryIdentifierType');

-- ---------------------------------------------------------------
-- 1. Small lookup tables, each keyed by a primary key.
--    Built from the (small) source tables, so every function runs once
--    per user / provider / drug / location / patient instead of once per row.
-- ---------------------------------------------------------------

-- user names (creator)
drop temporary table if exists temp_user_names;
create temporary table temp_user_names
(user_id   int(11) primary key,
 user_name text);
insert into temp_user_names
select user_id, person_name_of_user(user_id) from users;

-- provider names (dispenser, new form)
drop temporary table if exists temp_providers;
create temporary table temp_providers
(provider_id   int(11) primary key,
 provider_name text);
insert into temp_providers
select provider_id, provider_name_from_provider_id(provider_id) from provider;

-- drug name + openboxes code
drop temporary table if exists temp_drug_ids;
create temporary table temp_drug_ids
(drug_id             int(11) primary key,
 drug_name           varchar(255),
 drug_openboxes_code int);
insert into temp_drug_ids
select drug_id, drugName(drug_id), openboxesCode(drug_id) from drug;

-- location names (same location_name() function as before)
drop temporary table if exists temp_location_names;
create temporary table temp_location_names
(location_id   int(11) primary key,
 location_name varchar(255));
insert into temp_location_names
select location_id, location_name(location_id) from location;

-- EMR ids, once per patient across both forms
drop temporary table if exists temp_emr_ids;
create temporary table temp_emr_ids
(patient_id int(11) primary key,
 emr_id     varchar(50));
insert into temp_emr_ids
select p.patient_id, PATIENT_IDENTIFIER(p.patient_id, @primary_emr_id)
from (select person_id as patient_id from obs
      where concept_id = @dispensing_construct and voided = 0
      union
      select patient_id from medication_dispense
      where status = @complete_status) p;

-- old form: provider, once per encounter
drop temporary table if exists temp_encounter;
create temporary table temp_encounter
(encounter_id       int(11) primary key,
 encounter_provider text);
insert into temp_encounter
select g.encounter_id, provider(g.encounter_id)
from (select distinct encounter_id from obs
      where concept_id = @dispensing_construct and voided = 0
        and encounter_id is not null) g;

-- old form: obs values collapsed to one row per dispensing obs group
-- (goes straight from obs; the intermediate temp_obs table isn't needed)
drop temporary table if exists temp_obs_collated;
create temporary table temp_obs_collated
(obs_group_id  int(11) primary key,
 dose          double,
 doseUnit      text,
 drugId        int(11),
 duration      double,
 duration_unit varchar(255),
 frequency     varchar(255),
 quantity      double,
 qunits        text,
 inxs          text);
insert into temp_obs_collated
select o.obs_group_id,
       max(case when o.concept_id = @dose          then o.value_numeric end),
       max(case when o.concept_id = @doseUnit      then o.value_text end),
       max(case when o.concept_id = @drug          then o.value_drug end),
       max(case when o.concept_id = @duration      then o.value_numeric end),
       max(case when o.concept_id = @duration_unit then concept_name(o.value_coded, @locale) end),
       max(case when o.concept_id = @frequency     then concept_name(o.value_coded, @locale) end),
       max(case when o.concept_id = @quantity      then o.value_numeric end),
       max(case when o.concept_id = @qunits        then o.value_text end),
       max(case when o.concept_id = @inxs          then o.value_text end)
from obs g
inner join obs o on o.obs_group_id = g.obs_id
where g.concept_id = @dispensing_construct
  and g.voided = 0
  and o.voided = 0
  and o.concept_id in (@dose, @doseUnit, @drug, @duration, @duration_unit,
                       @frequency, @inxs, @quantity, @qunits)
group by o.obs_group_id;

-- new form: concept names for units and frequency
-- (separate tables because MySQL can't join the same temp table twice in one query)
drop temporary table if exists temp_md_dose_units;
create temporary table temp_md_dose_units
(concept_id int(11) primary key,
 name       varchar(255));
insert into temp_md_dose_units
select u.concept_id, concept_name(u.concept_id, @locale)
from (select distinct dose_units as concept_id from medication_dispense
      where status = @complete_status and dose_units is not null) u;

drop temporary table if exists temp_md_qty_units;
create temporary table temp_md_qty_units
(concept_id int(11) primary key,
 name       varchar(255));
insert into temp_md_qty_units
select u.concept_id, concept_name(u.concept_id, @locale)
from (select distinct quantity_units as concept_id from medication_dispense
      where status = @complete_status and quantity_units is not null) u;

drop temporary table if exists temp_md_frequency;
create temporary table temp_md_frequency
(order_frequency_id int(11) primary key,
 name               varchar(255));
insert into temp_md_frequency
select order_frequency_id, concept_name(concept_id, @locale) from order_frequency;

-- ---------------------------------------------------------------
-- 2. Main table: each form inserted fully populated in ONE pass
--    (replaces ~12 full-table UPDATEs). Column types are unchanged.
--    ORDER BY keeps dispensing_id assigned in the same order as before
--    (old form by obs_id, then new form by medication_dispense_id).
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS all_medication_dispensing;
CREATE TEMPORARY TABLE all_medication_dispensing
(dispensing_id      int(11) NOT NULL AUTO_INCREMENT,
patient_id          int,
obs_group_id        int,
form                varchar(10),
emr_id              varchar(50),
encounter_id        int,
encounter_datetime  datetime,
location_id         int(11),
encounter_location  varchar(100),
site                varchar(255),
visit_id            int,
visit_location      varchar(100),
datetime_entered    datetime,
user_entered        text,
creator             int(11),
encounter_provider  text,
dispenser           int(11),
drug_id             int(11),
drug_name           varchar(500),
drug_openboxes_code int,
duration            int,
duration_unit       varchar(20),
quantity_per_dose   double,
dose_unit           text,
frequency           varchar(50),
quantity_dispensed  int,
quantity_unit       varchar(30),
order_id            int,
dispensing_status   varchar(50),
status_reason       varchar(50),
instructions        text,
index_asc           int,
index_desc          int,
PRIMARY KEY (dispensing_id)
);

-- old form: one row per dispensing obs group
insert into all_medication_dispensing
(form, patient_id, encounter_id, obs_group_id, emr_id,
 encounter_datetime, datetime_entered, creator, user_entered, location_id,
 encounter_location, site, visit_id, visit_location, encounter_provider,
 drug_id, drug_name, drug_openboxes_code,
 duration, duration_unit, quantity_per_dose, dose_unit, frequency,
 quantity_dispensed, quantity_unit, instructions)
select
 'Old',
 g.person_id,
 g.encounter_id,
 g.obs_id,
 em.emr_id,
 e.encounter_datetime,
 e.date_created,
 e.creator,
 un.user_name,
 e.location_id,
 ln.location_name,
 -- site: visit's location when there is one, otherwise the
 -- Visit Location ancestor of the encounter location (same as before)
 coalesce(vl.location_name, l.site),
 e.visit_id,
 vl.location_name,
 te.encounter_provider,
 c.drugId,
 dr.drug_name,
 dr.drug_openboxes_code,
 c.duration,
 c.duration_unit,
 c.dose,
 c.doseUnit,
 c.frequency,
 c.quantity,
 c.qunits,
 c.inxs
from obs g
left join encounter e               on e.encounter_id  = g.encounter_id
left join temp_encounter te         on te.encounter_id = g.encounter_id
left join temp_obs_collated c       on c.obs_group_id  = g.obs_id
left join temp_emr_ids em           on em.patient_id   = g.person_id
left join temp_user_names un        on un.user_id      = e.creator
left join temp_location_names ln    on ln.location_id  = e.location_id
left join locations l               on l.location_id   = e.location_id
left join visit v                   on v.visit_id      = e.visit_id
left join locations vl              on vl.location_id  = v.location_id
left join temp_drug_ids dr          on dr.drug_id      = c.drugId
where g.concept_id = @dispensing_construct
  and g.voided = 0
order by g.obs_id;

-- new form: one row per completed medication_dispense
-- (encounter_provider is the dispenser's provider name, as before)
insert into all_medication_dispensing
(form, patient_id, encounter_id, emr_id,
 encounter_datetime, datetime_entered, creator, user_entered, dispenser, location_id,
 encounter_location, site, visit_id, visit_location, encounter_provider,
 drug_id, drug_name, drug_openboxes_code,
 quantity_per_dose, dose_unit, frequency, quantity_dispensed, quantity_unit,
 order_id, instructions)
select
 'New',
 md.patient_id,
 md.encounter_id,
 em.emr_id,
 md.date_handed_over,
 md.date_created,
 md.creator,
 un.user_name,
 md.dispenser,
 md.location_id,
 ln.location_name,
 coalesce(vl.location_name, l.site),
 e.visit_id,
 vl.location_name,
 p.provider_name,
 md.drug_id,
 dr.drug_name,
 dr.drug_openboxes_code,
 md.dose,
 du.name,
 f.name,
 md.quantity,
 qu.name,
 md.drug_order_id,
 md.dosing_instructions
from medication_dispense md
left join temp_md_frequency f       on f.order_frequency_id = md.frequency
left join temp_md_dose_units du     on du.concept_id   = md.dose_units
left join temp_md_qty_units qu      on qu.concept_id   = md.quantity_units
left join temp_emr_ids em           on em.patient_id   = md.patient_id
left join temp_user_names un        on un.user_id      = md.creator
left join temp_providers p          on p.provider_id   = md.dispenser
left join temp_location_names ln    on ln.location_id  = md.location_id
left join locations l               on l.location_id   = md.location_id
left join encounter e               on e.encounter_id  = md.encounter_id
left join visit v                   on v.visit_id      = e.visit_id
left join locations vl              on vl.location_id  = v.location_id
left join temp_drug_ids dr          on dr.drug_id      = md.drug_id
where md.status = @complete_status
order by md.medication_dispense_id;

-- ---------------------------------------------------------------
-- 3. Final select (unchanged)
-- ---------------------------------------------------------------
SELECT
CONCAT(@partition,'-',dispensing_id) "dispensing_id",
form,
CONCAT(@partition,'-',patient_id) "patient_id",
emr_id,
CONCAT(@partition,'-',encounter_id) "encounter_id",
encounter_datetime,
encounter_location,
site,
CONCAT(@partition,'-',visit_id) "visit_id",
visit_location,
datetime_entered,
user_entered,
encounter_provider,
drug_name,
drug_openboxes_code,
duration,
duration_unit,
quantity_per_dose,
dose_unit,
frequency,
quantity_dispensed,
quantity_unit,
CONCAT(@partition,'-',order_id) "order_id",
instructions,
index_asc,
index_desc
FROM all_medication_dispensing;
