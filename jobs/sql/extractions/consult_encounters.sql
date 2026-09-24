SET @partition = '${partitionNum}';
SET sql_safe_updates = 0;
SET @locale = 'fr';

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
-- (goes straight from encounter -> obs; the intermediate temp_obs table isn't needed)
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
-- 2. Final output: one pass over the consult encounters
--    (no wide temp table, no full-table UPDATEs)
-- ---------------------------------------------------------------
SELECT
em.emr_id,
CONCAT(@partition,'-',e.encounter_id) "encounter_id",
CONCAT(@partition,'-',e.visit_id) "visit_id",
vl.location_name as visit_location,
e.encounter_datetime,
u.user_name as user_entered,
e.date_created as datetime_created,
el.location_name as encounter_location,
-- site: visit's location when there is one, otherwise the
-- Visit Location ancestor of the encounter location (same as before)
coalesce(vl.location_name, el.site) as site,
@consult_type_name AS encounter_type,
provider(e.encounter_id) as provider,
CASE o.trauma_value_coded
     WHEN @yes THEN 1
     WHEN @no  THEN 0
END as trauma,
o.trauma_type,
date(o.return_visit_date) as return_visit_date,
o.disposition,
CASE WHEN o.disposition_code = @dispo_admit    THEN o.adm_location    ELSE NULL END AS admission_location,
CASE WHEN o.disposition_code = @dispo_internal THEN o.location_within ELSE NULL END AS internal_transfer_location,
CASE WHEN o.disposition_code = @dispo_external THEN o.location_out    ELSE NULL END AS external_transfer_location,
null as index_asc,
null as index_desc
FROM encounter e
left join temp_consult_emrids em on em.patient_id   = e.patient_id
left join temp_consult_users  u  on u.user_id       = e.creator
left join locations           el on el.location_id  = e.location_id
left join visit               v  on v.visit_id      = e.visit_id
left join locations           vl on vl.location_id  = v.location_id
left join temp_consult_obs    o  on o.encounter_id  = e.encounter_id
where e.voided = 0
  and e.encounter_type = @consult_type_id
ORDER BY e.encounter_datetime desc;
