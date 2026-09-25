set sql_safe_updates = 0;
set @partition = '${partitionNum}';
set @locale = 'fr';

-- ---------------------------------------------------------------
-- 0. Resolve every lookup ONCE up front
-- ---------------------------------------------------------------
set @prescription_construct = concept_from_mapping('PIH','10742');
set @order_dose          = concept_from_mapping('PIH','9073');
set @dosing_units        = concept_from_mapping('PIH','10744');
set @med                 = concept_from_mapping('PIH','1282');
set @mh_med              = concept_from_mapping('PIH','10634');
set @frequency           = concept_from_mapping('PIH','9363');
set @duration            = concept_from_mapping('PIH','9075');
set @dur_units           = concept_from_mapping('PIH','6412');
set @order_qty           = concept_from_mapping('PIH','9071');
set @dosing_instructions = concept_from_mapping('PIH','9072');
set @primary_id_type     = METADATA_UUID('org.openmrs.module.emrapi', 'emr.primaryIdentifierType');

-- ---------------------------------------------------------------
-- 1. Base rows (narrow), one table per source
-- ---------------------------------------------------------------

-- meds from obs: one row per prescription obs group on a non-voided encounter
drop temporary table if exists temp_obs_base;
create temporary table temp_obs_base
(
 obs_group_id       int(11) primary key,
 encounter_id       int(11),
 patient_id         int(11),
 encounter_type_id  int(11),
 encounter_datetime datetime,
 date_created       datetime
);
insert into temp_obs_base
select o.obs_id, o.encounter_id, o.person_id, e.encounter_type, e.encounter_datetime, e.date_created
from obs o
inner join encounter e on e.encounter_id = o.encounter_id and e.voided = 0
where o.concept_id = @prescription_construct
  and o.voided = 0;

-- obs values collapsed to one row per prescription obs group
drop temporary table if exists temp_obs_collated;
create temporary table temp_obs_collated
(
 obs_group_id         int(11) primary key,
 drug_concept_id      int(11),
 drug_id              int(11),
 order_dose           double,
 order_dose_unit      varchar(255),
 dosing_instructions  text,
 order_frequency      varchar(255),
 order_duration       double,
 order_duration_units varchar(255),
 order_quantity       double
);
insert into temp_obs_collated
select o.obs_group_id,
       max(case when o.concept_id = @med or o.concept_id = @mh_med then o.value_coded end),
       max(case when o.concept_id = @med or o.concept_id = @mh_med then o.value_drug end),
       max(case when o.concept_id = @order_dose          then o.value_numeric end),
       max(case when o.concept_id = @dosing_units        then concept_name(o.value_coded, @locale) end),
       max(case when o.concept_id = @dosing_instructions then o.value_text end),
       max(case when o.concept_id = @frequency           then concept_name(o.value_coded, @locale) end),
       max(case when o.concept_id = @duration            then o.value_numeric end),
       max(case when o.concept_id = @dur_units           then concept_name(o.value_coded, @locale) end),
       max(case when o.concept_id = @order_qty           then o.value_numeric end)
from temp_obs_base b
inner join obs o on o.obs_group_id = b.obs_group_id
where o.voided = 0
  and o.concept_id in (@med, @mh_med, @order_dose, @dosing_units, @dosing_instructions,
                       @frequency, @duration, @dur_units, @order_qty)
group by o.obs_group_id;

-- meds from orders: one row per non-voided drug order
drop temporary table if exists temp_order_base;
create temporary table temp_order_base
(
 order_id            int(11) primary key,
 encounter_id        int(11),
 patient_id          int(11),
 concept_id          int(11),
 drug_inventory_id   int(11),
 order_reason        int(11),
 dose                double,
 dose_units          int(11),
 dosing_instructions text,
 route               int(11),
 frequency           int(11),
 quantity            double,
 quantity_units      int(11),
 duration            int(11),
 duration_units      int(11),
 num_refills         int(11),
 drug_non_coded      varchar(255),
 date_created        date,
 date_activated      date
);
insert into temp_order_base
select o.order_id, o.encounter_id, o.patient_id, o.concept_id, d.drug_inventory_id, o.order_reason,
       d.dose, d.dose_units, d.dosing_instructions, d.route, d.frequency, d.quantity,
       d.quantity_units, d.duration, d.duration_units, d.num_refills, d.drug_non_coded,
       date(o.date_created), date(o.date_activated)
from orders o
inner join drug_order d on o.order_id = d.order_id
where o.voided = 0;

-- ---------------------------------------------------------------
-- 2. Lookup tables, each keyed by a primary key
--    (every function runs once per patient / encounter / drug / concept,
--     instead of once per row in ~20 full-table UPDATEs)
-- ---------------------------------------------------------------

-- EMR ids, once per patient
drop temporary table if exists temp_mo_emr;
create temporary table temp_mo_emr
(patient_id int(11) primary key,
 emr_id     varchar(50));
insert into temp_mo_emr
select p.patient_id, PATIENT_IDENTIFIER(p.patient_id, @primary_id_type)
from (select patient_id from temp_obs_base
      union
      select patient_id from temp_order_base) p;

-- encounter-level info, once per encounter (both sources)
-- visit_id / location_id only from non-voided encounters, as before
drop temporary table if exists temp_mo_enc;
create temporary table temp_mo_enc
(encounter_id int(11) primary key,
 visit_id     int(11),
 location_id  int(11),
 user_entered varchar(255),
 prescriber   varchar(255));
insert into temp_mo_enc
select x.encounter_id,
       case when e.voided = 0 then e.visit_id end,
       case when e.voided = 0 then e.location_id end,
       encounter_creator_name(x.encounter_id),
       provider(x.encounter_id)
from (select encounter_id from temp_obs_base
      union
      select encounter_id from temp_order_base where encounter_id is not null) x
left join encounter e on e.encounter_id = x.encounter_id;

-- order-only encounter info (encounter type name + medication comments)
drop temporary table if exists temp_mo_order_enc;
create temporary table temp_mo_order_enc
(encounter_id   int(11) primary key,
 encounter_type varchar(255),
 order_comments text);
insert into temp_mo_order_enc
select x.encounter_id,
       encounter_type_name(x.encounter_id),
       obs_value_text(x.encounter_id, 'PIH', 'Medication comments (text)')
from (select distinct encounter_id from temp_order_base where encounter_id is not null) x;

-- encounter type names for obs-based rows (same function as before)
drop temporary table if exists temp_mo_enc_types;
create temporary table temp_mo_enc_types
(encounter_type_id int(11) primary key,
 encounter_type    varchar(255));
insert into temp_mo_enc_types
select encounter_type_id, encounter_type_name_from_id(encounter_type_id) from encounter_type;

-- drug name + openboxes code
drop temporary table if exists temp_mo_drugs;
create temporary table temp_mo_drugs
(drug_id      int(11) primary key,
 drug_name    text,
 product_code varchar(255));
insert into temp_mo_drugs
select drug_id, drugName(drug_id), openboxesCode(drug_id) from drug;

-- order frequency names
drop temporary table if exists temp_mo_freq;
create temporary table temp_mo_freq
(order_frequency_id int(11) primary key,
 name               varchar(255));
insert into temp_mo_freq
select order_frequency_id, concept_name(concept_id, @locale) from order_frequency;

-- concept names: every distinct concept used by either source, named once
drop temporary table if exists temp_mo_concepts;
create temporary table temp_mo_concepts
(concept_id int(11) primary key,
 name       varchar(255));
insert ignore into temp_mo_concepts(concept_id) select drug_concept_id from temp_obs_collated where drug_concept_id is not null;
insert ignore into temp_mo_concepts(concept_id) select concept_id     from temp_order_base where concept_id     is not null;
insert ignore into temp_mo_concepts(concept_id) select order_reason   from temp_order_base where order_reason   is not null;
insert ignore into temp_mo_concepts(concept_id) select dose_units     from temp_order_base where dose_units     is not null;
insert ignore into temp_mo_concepts(concept_id) select route          from temp_order_base where route          is not null;
insert ignore into temp_mo_concepts(concept_id) select quantity_units from temp_order_base where quantity_units is not null;
insert ignore into temp_mo_concepts(concept_id) select duration_units from temp_order_base where duration_units is not null;
update temp_mo_concepts set name = concept_name(concept_id, @locale);

-- MySQL can't join the same temp table more than once in a query,
-- so make small copies for each role in the orders insert
drop temporary table if exists temp_mo_c_reason;
create temporary table temp_mo_c_reason like temp_mo_concepts;
insert into temp_mo_c_reason select * from temp_mo_concepts;

drop temporary table if exists temp_mo_c_dose_units;
create temporary table temp_mo_c_dose_units like temp_mo_concepts;
insert into temp_mo_c_dose_units select * from temp_mo_concepts;

drop temporary table if exists temp_mo_c_route;
create temporary table temp_mo_c_route like temp_mo_concepts;
insert into temp_mo_c_route select * from temp_mo_concepts;

drop temporary table if exists temp_mo_c_qty_units;
create temporary table temp_mo_c_qty_units like temp_mo_concepts;
insert into temp_mo_c_qty_units select * from temp_mo_concepts;

drop temporary table if exists temp_mo_c_dur_units;
create temporary table temp_mo_c_dur_units like temp_mo_concepts;
insert into temp_mo_c_dur_units select * from temp_mo_concepts;

-- ---------------------------------------------------------------
-- 3. Main table: each source inserted fully populated in ONE pass.
--    Column types unchanged, so rounding/truncation behave as before.
--    (now a TEMPORARY table -- the original created a permanent one)
-- ---------------------------------------------------------------
drop temporary table if exists temp_medication_orders;
create temporary table temp_medication_orders
(
encounter_id int,
patient_id int,
emr_id varchar(20),
visit_id int,
visit_location varchar(255),
order_id int,
orderer int,
drug_concept_id int,
drug_id int,
location_id int,
encounter_type_id int(11),
encounter_type varchar(255),
prescription_obs_group_id int(11),
order_drug text,
order_formulation text,
order_formulation_non_coded text,
order_location varchar(255),
site varchar(255),
order_created_date date,
order_date_activated date,
user_entered varchar(255),
order_quantity int,
order_quantity_units_id int,
order_quantity_units varchar(50),
order_quantity_num_refills int,
order_dose int,
order_dose_units_id int,
order_dose_unit varchar(50),
order_dosing_instructions text,
order_route_id int,
order_route varchar(50),
order_frequency_id int,
order_frequency varchar(50),
order_duration int,
order_duration_units_id int,
order_duration_units varchar(50),
order_reason_concept int,
order_reason text,
order_comments text,
product_code varchar(25),
prescriber varchar(255)
);

-- meds from obs
insert into temp_medication_orders
(encounter_id, patient_id, emr_id, visit_id, visit_location, location_id,
 encounter_type_id, encounter_type, prescription_obs_group_id,
 order_date_activated, order_created_date,
 drug_concept_id, drug_id, order_drug, order_formulation, product_code,
 order_dose, order_dose_unit, order_dosing_instructions, order_frequency,
 order_duration, order_duration_units, order_quantity,
 order_location, site, user_entered, prescriber)
select
 b.encounter_id,
 b.patient_id,
 em.emr_id,
 en.visit_id,
 vl.location_name,
 en.location_id,
 b.encounter_type_id,
 et.encounter_type,
 b.obs_group_id,
 b.encounter_datetime,
 b.date_created,
 c.drug_concept_id,
 c.drug_id,
 cn.name,
 dr.drug_name,
 dr.product_code,
 c.order_dose,
 c.order_dose_unit,
 c.dosing_instructions,
 c.order_frequency,
 c.order_duration,
 c.order_duration_units,
 c.order_quantity,
 ls.location_name,
 -- site: visit's location when there is one, otherwise the
 -- Visit Location ancestor of the encounter location (same as before)
 coalesce(vl.location_name, ls.site),
 en.user_entered,
 en.prescriber
from temp_obs_base b
left join temp_obs_collated c    on c.obs_group_id       = b.obs_group_id
left join temp_mo_emr em         on em.patient_id        = b.patient_id
left join temp_mo_enc en         on en.encounter_id      = b.encounter_id
left join temp_mo_enc_types et   on et.encounter_type_id = b.encounter_type_id
left join locations ls           on ls.location_id       = en.location_id
left join visit v                on v.visit_id           = en.visit_id
left join locations vl           on vl.location_id       = v.location_id
left join temp_mo_drugs dr       on dr.drug_id           = c.drug_id
left join temp_mo_concepts cn    on cn.concept_id        = c.drug_concept_id;

-- meds from orders
insert into temp_medication_orders
(encounter_id, patient_id, emr_id, visit_id, visit_location, location_id,
 order_id, encounter_type,
 drug_concept_id, drug_id, order_drug, order_formulation, order_formulation_non_coded, product_code,
 order_reason_concept, order_reason,
 order_dose, order_dose_units_id, order_dose_unit, order_dosing_instructions,
 order_route_id, order_route, order_frequency_id, order_frequency,
 order_quantity, order_quantity_units_id, order_quantity_units,
 order_duration, order_duration_units_id, order_duration_units,
 order_quantity_num_refills, order_created_date, order_date_activated,
 order_location, site, user_entered, prescriber, order_comments)
select
 b.encounter_id,
 b.patient_id,
 em.emr_id,
 en.visit_id,
 vl.location_name,
 en.location_id,
 b.order_id,
 oe.encounter_type,
 b.concept_id,
 b.drug_inventory_id,
 cn.name,
 dr.drug_name,
 b.drug_non_coded,
 dr.product_code,
 b.order_reason,
 cr.name,
 b.dose,
 b.dose_units,
 cdu.name,
 b.dosing_instructions,
 b.route,
 crt.name,
 b.frequency,
 f.name,
 b.quantity,
 b.quantity_units,
 cqu.name,
 b.duration,
 b.duration_units,
 cdur.name,
 b.num_refills,
 b.date_created,
 b.date_activated,
 ls.location_name,
 coalesce(vl.location_name, ls.site),
 en.user_entered,
 en.prescriber,
 oe.order_comments
from temp_order_base b
left join temp_mo_emr em           on em.patient_id    = b.patient_id
left join temp_mo_enc en           on en.encounter_id  = b.encounter_id
left join temp_mo_order_enc oe     on oe.encounter_id  = b.encounter_id
left join locations ls             on ls.location_id   = en.location_id
left join visit v                  on v.visit_id       = en.visit_id
left join locations vl             on vl.location_id   = v.location_id
left join temp_mo_drugs dr         on dr.drug_id       = b.drug_inventory_id
left join temp_mo_concepts cn      on cn.concept_id    = b.concept_id
left join temp_mo_c_reason cr      on cr.concept_id    = b.order_reason
left join temp_mo_c_dose_units cdu on cdu.concept_id   = b.dose_units
left join temp_mo_c_route crt      on crt.concept_id   = b.route
left join temp_mo_c_qty_units cqu  on cqu.concept_id   = b.quantity_units
left join temp_mo_c_dur_units cdur on cdur.concept_id  = b.duration_units
left join temp_mo_freq f           on f.order_frequency_id = b.frequency;

-- ---------------------------------------------------------------
-- 4. Final query (unchanged)
-- ---------------------------------------------------------------
select
emr_id,
encounter_type,
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',encounter_id),encounter_id) "encounter_id",
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',visit_id),visit_id) "visit_id",
visit_location,
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',order_id),order_id) "order_id",
order_location,
site,
order_created_date,
order_date_activated,
user_entered,
prescriber,
order_drug,
order_formulation,
order_formulation_non_coded,
product_code,
order_quantity,
order_quantity_units,
order_quantity_num_refills,
order_dose,
order_dose_unit,
order_dosing_instructions,
order_route,
order_frequency,
order_duration,
order_duration_units,
order_reason,
order_comments
from temp_medication_orders
order by order_date_activated, patient_id;
