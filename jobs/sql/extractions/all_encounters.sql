-- set @previousWatermark = null;  
-- set @newWatermark = now();
SET @partition = '${partitionNum}';
set sql_safe_updates = 0;
set @next_appt_date_concept_id = CONCEPT_FROM_MAPPING('PIH', 5096);

drop temporary table if exists temp_all_encounters;
create temporary table temp_all_encounters
(
    encounter_id         int,
    encounter_datetime   datetime,
    patient_id           int,
    visit_id             int,
    creator              int(11),
    user_entered         varchar(255),
    encounter_location   varchar(255),
    encounter_type_name  varchar(50),
    entered_datetime     datetime,
    emr_id               varchar(15),
    next_appt_date       date,
    voided               bit
);

-- If there is not a previous watermark, initialize with all encounters
insert into temp_all_encounters (encounter_id)
select encounter_id from encounter
where voided = 0
and @previousWatermark is null;

-- If there is a previous watermark, initialize with only those encounters since that watermark
insert into temp_all_encounters (encounter_id)
select encounter_id from encounter
inner join dbevent_patient dp on encounter.patient_id = dp.patient_id
where voided = 0 
and @previousWatermark is not null
and dp.last_updated >= @previousWatermark
and dp.last_updated <= @newWatermark;

create index temp_all_encounters_encounterId ON temp_all_encounters (encounter_id);

-- Load the encounters
update temp_all_encounters t
inner join encounter e on t.encounter_id = e.encounter_id
set t.encounter_datetime = e.encounter_datetime,
    t.encounter_type_name = encounter_type_name_from_id(e.encounter_type),
    t.encounter_location = location_name(e.location_id),
    t.patient_id = e.patient_id,
    t.visit_id = e.visit_id,
    t.user_entered = person_name_of_user(e.creator),
    t.entered_datetime = e.date_created,
    t.voided = e.voided
;

CREATE INDEX temp_all_encounters_patientId ON temp_all_encounters (patient_id);

-- next visit date
-- all next appt date obs loaded to temp table before looking up for each encounter
-- this avoids having to access the full obs table for each encounter
DROP TABLE IF EXISTS temp_next_appt_obs;
CREATE TEMPORARY TABLE temp_next_appt_obs
select encounter_id, max(value_datetime) "next_appt_date"
from obs
where concept_id = @next_appt_date_concept_id
  and voided = 0
group by encounter_id;

create index temp_next_appt_obs_ei on temp_next_appt_obs (encounter_id);

update temp_all_encounters te
    inner join temp_next_appt_obs tvo on tvo.encounter_id = te.encounter_id
set te.next_appt_date = tvo.next_appt_date
where te.voided = 0;

-- emr_id
-- unique patients loaded to temp table before looking up emr_id and joining back in to the temp_all_encounters table
drop temporary table if exists temp_emrids;
create temporary table temp_emrids
(
    patient_id int(11),
    emr_id     varchar(50)
);

insert into temp_emrids(patient_id)
select DISTINCT patient_id
from temp_all_encounters
;
create index temp_emrids_patient_id on temp_emrids (patient_id);

update temp_emrids t
set emr_id = patient_identifier(patient_id, 'ZL EMR ID');

update temp_all_encounters t
    inner join temp_emrids te on te.patient_id = t.patient_id
set t.emr_id = te.emr_id
;

-- final query
select emr_id,
       CONCAT(@partition, '-', encounter_id) as encounter_id,
       CONCAT(@partition, '-', patient_id) as patient_id,
       CONCAT(@partition, '-', visit_id) as visit_id,
       encounter_type_name,
       encounter_location,
       encounter_datetime,
       entered_datetime,
       user_entered,
       next_appt_date,
       voided
from temp_all_encounters t
ORDER BY t.patient_id, t.encounter_id;
