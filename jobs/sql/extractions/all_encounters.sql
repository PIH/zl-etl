-- set @previousWatermark = null;  
-- set @newWatermark = now();
SET @partition = '${partitionNum}';
set sql_safe_updates = 0;
set @next_appt_date_concept_id = CONCEPT_FROM_MAPPING('PIH', 5096);

drop temporary table if exists temp_encounter;
create temporary table temp_encounter
(
    encounter_id         int,
    encounter_datetime   datetime,
    patient_id           int,
    visit_id             int,
    creator              int(11),
    user_entered         varchar(255),
    location_id 		 int,
    encounter_location   varchar(255),
    encounter_type 		 int,
    encounter_type_name  varchar(50),
    entered_datetime     datetime,
    emr_id               varchar(15),
    next_appt_date       date,
    voided               bit
);

-- If there is not a previous watermark, initialize with all encounters
insert into temp_encounter (encounter_id, encounter_datetime, encounter_type, location_id, patient_id, visit_id, creator, entered_datetime, voided)
select encounter_id, encounter_datetime, encounter_type, location_id, patient_id, visit_id, creator, date_created, voided
from encounter
where voided = 0
and @previousWatermark is null;

-- If there is a previous watermark, initialize with only those encounters since that watermark
insert into temp_encounter (encounter_id, encounter_datetime, encounter_type, location_id, patient_id, visit_id, creator, entered_datetime, voided  )
select encounter_id, encounter_datetime, 
encounter_type, location_id, encounter.patient_id, visit_id, creator, date_created, voided
from encounter
inner join dbevent_patient dp on encounter.patient_id = dp.patient_id
where voided = 0 
and @previousWatermark is not null
and dp.last_updated >= @previousWatermark
and dp.last_updated <= @newWatermark;


CREATE INDEX temp_all_encounters_encounterId ON temp_encounter (encounter_id);
CREATE INDEX temp_all_encounters_patientId ON temp_encounter (patient_id);

UPDATE temp_encounter t SET t.encounter_type_name = encounter_type_name_from_id(t.encounter_type);
UPDATE temp_encounter t SET t.encounter_location = location_name(t.location_id);
UPDATE temp_encounter t SET t.user_entered = person_name_of_user(t.creator);
UPDATE temp_encounter t SET t.emr_id = patient_identifier(t.patient_id, 'ZL EMR ID');

DROP TABLE IF EXISTS temp_obs;
CREATE TEMPORARY TABLE temp_obs AS 
SELECT o.person_id, o.encounter_id, o.obs_id , o.concept_id, o.value_datetime, o.voided , o.date_created
FROM temp_encounter te  INNER JOIN  obs o ON te.encounter_id=o.encounter_id 
WHERE o.voided =0
AND concept_id = @next_appt_date_concept_id;

UPDATE temp_encounter t SET t.next_appt_date = obs_value_datetime_from_temp(t.encounter_id, 'PIH', '5096');

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
from temp_encounter t
ORDER BY t.patient_id, t.encounter_id;