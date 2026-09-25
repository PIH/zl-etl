SET @partition = '${partitionNum}';
SET @locale = 'fr';
SET sql_safe_updates = 0;

-- ---------------------------------------------------------------
-- 0. Resolve every lookup ONCE up front
--    (functions in UPDATE/CASE/SELECT otherwise run once per row)
-- ---------------------------------------------------------------
select encounter_type_id into @consult_type_id
from encounter_type et where uuid = '92fd09b4-5335-4f7e-9f63-b2a663fd09a6';
set @consult_type_name   = encounter_type_name_from_id(@consult_type_id);
set @emr_identifier_type = 'a541af1e-105c-40bf-b345-ba1fd6a59b85';

set @trauma            = concept_from_mapping('PIH','8848');
set @trauma_type       = concept_from_mapping('PIH','8849');
set @return_visit_date = concept_from_mapping('PIH','5096');
set @disposition       = concept_from_mapping('PIH','8620');
set @location_within   = concept_from_mapping('PIH','8621');
set @location_out      = concept_from_mapping('PIH','8854');
set @adm_location      = concept_from_mapping('PIH','8622');
set @yes               = concept_from_mapping('PIH','YES');
set @no                = concept_from_mapping('PIH','NO');
set @dispo_admit       = concept_from_mapping('PIH','3799');
set @dispo_internal    = concept_from_mapping('PIH','8623');
set @dispo_external    = concept_from_mapping('PIH','8624');

-- ---------------------------------------------------------------
-- 1. Small lookup tables, each keyed by a primary key
-- ---------------------------------------------------------------

-- user names (function runs once per user, not once per encounter)
drop temporary table if exists temp_consult_users;
create temporary table temp_consult_users
(
 user_id   int(11) primary key,
 user_name varchar(255)
);
insert into temp_consult_users
select user_id, person_name_of_user(user_id) from users;

-- EMR ids (function runs once per patient, not once per encounter)
drop temporary table if exists temp_consult_emrids;
create temporary table temp_consult_emrids
(
 patient_id int(11) primary key,
 emr_id     varchar(50)
);
insert into temp_consult_emrids
select p.patient_id, patient_identifier(p.patient_id, @emr_identifier_type)
from (select distinct patient_id from encounter
      where voided = 0 and encounter_type = @consult_type_id) p;

-- obs values collapsed to one row per encounter
drop temporary table if exists temp_consult_obs;
create temporary table temp_consult_obs
(
 encounter_id       int(11) primary key,
 trauma_value_coded int(11),
 trauma_type        varchar(255),
 return_visit_date  datetime,
 disposition        varchar(255),
 disposition_code   int,
 location_within    varchar(255),
 location_out       varchar(255),
 adm_location       varchar(255)
);
insert into temp_consult_obs
select o.encounter_id,
       max(case when o.concept_id = @trauma            then o.value_coded end),
       max(case when o.concept_id = @trauma_type       then concept_name(o.value_coded, @locale) end),
       max(case when o.concept_id = @return_visit_date then o.value_datetime end),
       max(case when o.concept_id = @disposition       then concept_name(o.value_coded, @locale) end),
       max(case when o.concept_id = @disposition       then o.value_coded end),
       max(case when o.concept_id = @location_within   then location_name(o.value_text) end),
       max(case when o.concept_id = @location_out      then concept_name(o.value_coded, @locale) end),
       max(case when o.concept_id = @adm_location      then location_name(o.value_text) end)
from encounter e
inner join obs o on o.encounter_id = e.encounter_id
where e.voided = 0
  and e.encounter_type = @consult_type_id
  and o.voided = 0
  and o.concept_id in (@trauma, @trauma_type, @return_visit_date, @disposition,
                       @location_within, @location_out, @adm_location)
group by o.encounter_id;

-- ---------------------------------------------------------------
-- 2. Main table with explicit column types, filled in ONE pass
--    (typed table => service sees int(11) for index_asc / index_desc)
-- ---------------------------------------------------------------
drop temporary table if exists temp_consult_encs;
create temporary table temp_consult_encs
(
 encounter_id               int(11) primary key,
 emr_id                     varchar(15),
 visit_id                   int(11),
 visit_location             varchar(255),
 encounter_datetime         datetime,
 user_entered               varchar(255),
 datetime_created           datetime,
 encounter_location         varchar(255),
 site                       varchar(255),
 encounter_type             varchar(50),
 provider                   varchar(255),
 trauma                     boolean,
 trauma_type                varchar(255),
 return_visit_date          date,
 disposition                varchar(255),
 admission_location         varchar(255),
 internal_transfer_location varchar(255),
 external_transfer_location varchar(255),
 index_asc                  int(11),
 index_desc                 int(11)
);

insert into temp_consult_encs
(encounter_id, emr_id, visit_id, visit_location, encounter_datetime, user_entered,
 datetime_created, encounter_location, site, encounter_type, provider,
 trauma, trauma_type, return_visit_date, disposition,
 admission_location, internal_transfer_location, external_transfer_location)
select
 e.encounter_id,
 em.emr_id,
 e.visit_id,
 vl.location_name,
 e.encounter_datetime,
 u.user_name,
 e.date_created,
 el.location_name,
 -- site: visit's location when there is one, otherwise the
 -- Visit Location ancestor of the encounter location
 coalesce(vl.location_name, el.site),
 @consult_type_name,
 provider(e.encounter_id),
 CASE o.trauma_value_coded
      WHEN @yes THEN 1
      WHEN @no  THEN 0
 END,
 o.trauma_type,
 o.return_visit_date,
 o.disposition,
 CASE WHEN o.disposition_code = @dispo_admit    THEN o.adm_location    END,
 CASE WHEN o.disposition_code = @dispo_internal THEN o.location_within END,
 CASE WHEN o.disposition_code = @dispo_external THEN o.location_out    END
FROM encounter e
left join temp_consult_emrids em on em.patient_id   = e.patient_id
left join temp_consult_users  u  on u.user_id       = e.creator
left join locations           el on el.location_id  = e.location_id
left join visit               v  on v.visit_id      = e.visit_id
left join locations           vl on vl.location_id  = v.location_id
left join temp_consult_obs    o  on o.encounter_id  = e.encounter_id
where e.voided = 0
  and e.encounter_type = @consult_type_id;

-- ---------------------------------------------------------------
-- 3. Final output
-- ---------------------------------------------------------------
SELECT
emr_id,
CONCAT(@partition,'-',encounter_id) "encounter_id",
CONCAT(@partition,'-',visit_id) "visit_id",
visit_location,
encounter_datetime,
user_entered,
datetime_created,
encounter_location,
site,
encounter_type,
provider,
trauma,
trauma_type,
return_visit_date,
disposition,
admission_location,
internal_transfer_location,
external_transfer_location,
index_asc,
index_desc
FROM temp_consult_encs
ORDER BY encounter_datetime desc;
