SELECT encounter_type_id  INTO @enc_type FROM encounter_type et WHERE uuid='f9cfdf8b-d086-4658-9b9d-45a62896da03';
SELECT program_id  INTO @prog_id FROM program p WHERE uuid='0e69c3ab-1ccb-430b-b0db-b9760319230f';
SELECT encounter_type_id INTO @enctype FROM encounter_type et WHERE et.uuid ='a8584ab8-cc2a-11e5-9956-625662870761';
SET @partition = '${partitionNum}';


DROP TABLE IF EXISTS all_mh_patients;
CREATE TEMPORARY TABLE all_mh_patients (
patient_id int,
encounter_id int,
emr_id varchar(50),
dob date,
gender varchar(50),
town varchar(500),
referral varchar(500),
program_enrollment_date date,
interventions varchar(1000));


INSERT INTO all_mh_patients(patient_id,emr_id,program_enrollment_date)
SELECT 
pp.patient_id,
zlemr(pp.patient_id),
pp.date_enrolled
FROM patient_program pp 
WHERE pp.program_id = @prog_id
AND pp.voided = 0;

DROP TABLE IF EXISTS enrolled_patients;
CREATE TEMPORARY TABLE enrolled_patients AS 
SELECT patient_id FROM all_mh_patients;

INSERT INTO all_mh_patients(patient_id,emr_id)
SELECT
patient_id,
zlemr(patient_id)
FROM encounter e 
WHERE e.encounter_type =@enctype
AND e.patient_id  NOT IN (SELECT patient_id FROM enrolled_patients);


UPDATE all_mh_patients
SET gender=gender(patient_id),
dob=birthdate(patient_id);

UPDATE all_mh_patients tgt
SET town=(
	SELECT IFNULL(city_village,'')
	FROM person_address pa WHERE pa.person_id=tgt.patient_id
	and pa.voided = 0 
	order by preferred desc, date_created desc limit 1
);

DROP TABLE IF EXISTS last_mh_visit;
CREATE TEMPORARY TABLE last_mh_visit AS 
SELECT patient_id,max(encounter_id) encounter_id
FROM encounter e 
WHERE encounter_type =@enctype
GROUP BY patient_id;


-- interventions
UPDATE all_mh_patients tgt
SET interventions = (
SELECT group_concat(distinct value_coded_name(o.obs_id,'en') separator ' | ')
FROM obs o 
WHERE o.person_id = tgt.patient_id
AND o.concept_id = concept_from_mapping('PIH','10636')
AND o.voided =0
AND o.encounter_id IN (SELECT encounter_id FROM last_mh_visit)
)
;


-- referral
UPDATE all_mh_patients tgt
SET referral = (
SELECT group_concat(distinct value_coded_name(o.obs_id,'en') separator ' | ')
FROM obs o 
WHERE o.person_id =tgt.patient_id
AND o.concept_id = concept_from_mapping('PIH','10647')
AND o.voided =0
AND o.encounter_id IN (SELECT encounter_id FROM last_mh_visit)
)
;

SELECT 
CONCAT(@partition,'-',emr_id) "emr_id",
dob,
gender,
town,
referral,
program_enrollment_date,
interventions
FROM all_mh_patients;