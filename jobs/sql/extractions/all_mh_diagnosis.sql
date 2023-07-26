SELECT encounter_type_id  INTO @enc_type FROM encounter_type et WHERE uuid='f9cfdf8b-d086-4658-9b9d-45a62896da03';
SELECT program_id  INTO @prog_id FROM program p WHERE uuid='0e69c3ab-1ccb-430b-b0db-b9760319230f';
SELECT encounter_type_id INTO @enctype FROM encounter_type et WHERE et.uuid ='a8584ab8-cc2a-11e5-9956-625662870761';
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


DROP TABLE IF EXISTS enrolled_patients;
CREATE TEMPORARY TABLE enrolled_patients
SELECT
patient_id,
zlemr(patient_id) emr_id
FROM encounter e 
WHERE e.encounter_type =@enctype;



DROP TABLE IF EXISTS temp_diagnosis;
CREATE TEMPORARY TABLE temp_diagnosis
SELECT 
patient_id,
zlemr(patient_id) emr_id,
encounter_id,
encounter_datetime ,
encounter_location_name(encounter_id) encounter_location_name,
encounter_creator(encounter_id) encounter_creator,
provider(encounter_id) provider
FROM encounter e 
WHERE e.encounter_type =@enctype
AND e.patient_id IN (SELECT patient_id FROM enrolled_patients);

DROP TABLE IF EXISTS diagnosis_set;
CREATE TEMPORARY TABLE diagnosis_set 
SELECT
patient_id,
zlemr(patient_id) emr_id,
value_coded_name(o.obs_id,'en') diagnosis
FROM obs o INNER JOIN temp_diagnosis al ON o.encounter_id =al.encounter_id 
WHERE o.concept_id = 3004;

INSERT INTO all_mh_diagnosis(patient_id,emr_id,encounter_id,encounter_datetime,encounter_location_name,encounter_creator,provider,diagnosis)
SELECT 
ad.patient_id,
ad.emr_id,
encounter_id,
encounter_datetime,
encounter_location_name,
encounter_creator,
provider,
ds.diagnosis
FROM temp_diagnosis ad INNER JOIN diagnosis_set ds ON ad.patient_id=ds.patient_id;

SELECT 
emr_id,
encounter_id,
encounter_datetime,
encounter_location_name,
encounter_creator,
provider,
diagnosis
FROM all_mh_diagnosis;