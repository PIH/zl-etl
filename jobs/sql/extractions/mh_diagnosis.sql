
SELECT encounter_type_id INTO @mh_enctype FROM encounter_type et WHERE et.uuid ='a8584ab8-cc2a-11e5-9956-625662870761';
SET @partition = '${partitionNum}';

DROP TABLE IF EXISTS all_mh_diagnosis;
CREATE TEMPORARY TABLE all_mh_diagnosis (
patient_id int,
emr_id varchar(50),
encounter_id int,
encounter_datetime datetime,
encounter_location_name varchar(50),
encounter_creator varchar(50),
provider varchar(50),
diagnosis varchar(100)
);


DROP TABLE IF EXISTS temp_encounter;
CREATE TEMPORARY TABLE temp_encounter AS 
SELECT patient_id, encounter_id, encounter_datetime, encounter_type 
FROM encounter e 
WHERE e.encounter_type =@mh_enctype
AND e.voided =0;

DROP TABLE IF EXISTS temp_obs;
CREATE TEMPORARY TABLE temp_obs AS 
SELECT o.person_id, o.obs_id , o.obs_datetime , o.encounter_id, o.value_coded, o.concept_id, o.voided 
FROM obs o INNER JOIN temp_encounter te ON te.encounter_id=o.encounter_id 
WHERE o.voided =0
AND o.concept_id = concept_from_mapping('PIH','10594');


INSERT INTO all_mh_diagnosis(patient_id,emr_id,encounter_id,encounter_datetime,encounter_location_name,encounter_creator,provider,diagnosis)
SELECT 
patient_id,
zlemr(patient_id) emr_id,
e.encounter_id,
e.encounter_datetime ,
encounter_location_name(e.encounter_id) encounter_location_name,
encounter_creator(e.encounter_id) encounter_creator,
provider(e.encounter_id) provider,
value_coded_name(o.obs_id,'en') diagnosis
FROM temp_encounter e INNER JOIN temp_obs o ON e.encounter_id=o.encounter_id;

SELECT 
emr_id,
encounter_id,
encounter_datetime,
encounter_location_name,
encounter_creator,
provider,
diagnosis
FROM all_mh_diagnosis;