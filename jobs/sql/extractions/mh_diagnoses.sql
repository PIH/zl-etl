-- set @startDate='2025-02-01';
-- set @endDate='2025-03-05';

SELECT encounter_type_id INTO @mh_enctype FROM encounter_type et WHERE et.uuid ='a8584ab8-cc2a-11e5-9956-625662870761';
SET @partition = '${partitionNum}';

DROP TABLE IF EXISTS all_mh_diagnosis;
CREATE TEMPORARY TABLE all_mh_diagnosis
(
    patient_id              int,
    emr_id                  varchar(50),
    encounter_id            int,
    encounter_datetime      datetime,
    encounter_location_name varchar(50),
    facility                varchar(255),
    visit_id                int,
    visit_location          varchar(100),
    encounter_creator       text,
    provider                text,
    age_at_enc              double,
    gender                  varchar(50),
    diagnosis               varchar(255)
);

DROP TABLE IF EXISTS temp_encounter;
CREATE TEMPORARY TABLE temp_encounter AS
SELECT patient_id, encounter_id, encounter_datetime, encounter_type, visit_id
FROM encounter e
WHERE e.encounter_type =@mh_enctype
AND e.voided =0
and (DATE(encounter_datetime) >=  date(@startDate) or @startDate is null)
and (DATE(encounter_datetime) <=  date(@endDate) or @endDate is null);;

DROP TABLE IF EXISTS temp_obs;
CREATE TEMPORARY TABLE temp_obs AS 
SELECT o.person_id, o.obs_id , o.obs_datetime , o.encounter_id, o.value_coded, o.concept_id, o.voided 
FROM obs o INNER JOIN temp_encounter te ON te.encounter_id=o.encounter_id 
WHERE o.voided =0
AND o.concept_id = concept_from_mapping('PIH','10594');


INSERT INTO all_mh_diagnosis(patient_id,emr_id,encounter_id,encounter_datetime,encounter_location_name,visit_id,encounter_creator,provider,age_at_enc,gender,diagnosis)
SELECT
patient_id,
zlemr(patient_id) emr_id,
e.encounter_id,
e.encounter_datetime ,
encounter_location_name(e.encounter_id) encounter_location_name,
e.visit_id,
encounter_creator(e.encounter_id) encounter_creator,
provider(e.encounter_id) provider,
age_at_enc(patient_id, e.encounter_id) age_at_enc,
gender(patient_id),
value_coded_name(o.obs_id,'en') diagnosis
FROM temp_encounter e INNER JOIN temp_obs o ON e.encounter_id=o.encounter_id
INNER JOIN person p ON p.person_id = e.patient_id;

-- Sets facility as the Visit Location ancestor of the encounter location (fallback for rows with no visit).
UPDATE all_mh_diagnosis t
INNER JOIN encounter e ON e.encounter_id = t.encounter_id
INNER JOIN locations l ON l.location_id = e.location_id
SET t.facility = l.facility;

-- Sets visit_location from the visit's location.
-- Overrides facility with visit_location when a visit exists, since visits are
-- associated directly with the Visit Location — more accurate than the ancestor walk.
UPDATE all_mh_diagnosis t
INNER JOIN visit v ON v.visit_id = t.visit_id
INNER JOIN locations l ON l.location_id = v.location_id
SET t.visit_location = l.location_name,
    t.facility = l.location_name;

SELECT
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',encounter_id),encounter_id) "encounter_id",
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',patient_id),patient_id) "patient_id",
emr_id,
encounter_datetime,
encounter_location_name,
facility,
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',visit_id),visit_id) "visit_id",
visit_location,
encounter_creator,
provider,
age_at_enc,
gender,
diagnosis
FROM all_mh_diagnosis;
