SELECT encounter_type_id  INTO @enc_type FROM encounter_type et WHERE uuid='f9cfdf8b-d086-4658-9b9d-45a62896da03';
SELECT program_id  INTO @mh_prog_id FROM program p WHERE uuid='0e69c3ab-1ccb-430b-b0db-b9760319230f';
SELECT encounter_type_id INTO @mh_enctype FROM encounter_type et WHERE et.uuid ='a8584ab8-cc2a-11e5-9956-625662870761';
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
last_visit_enc_id int,
interventions varchar(1000));

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
WHERE o.voided =0;


INSERT INTO all_mh_patients(patient_id,emr_id, program_enrollment_date)
SELECT 
pp.patient_id,
zlemr(pp.patient_id),
pp.date_enrolled 
FROM patient_program pp 
WHERE pp.program_id = @mh_prog_id
AND pp.voided = 0;

DROP TABLE IF EXISTS enrolled_patients;
CREATE TEMPORARY TABLE enrolled_patients AS 
SELECT patient_id 
FROM all_mh_patients;

INSERT INTO all_mh_patients(patient_id,emr_id)
SELECT
patient_id,
zlemr(patient_id)
FROM temp_encounter e 
WHERE e.patient_id  NOT IN (SELECT patient_id FROM enrolled_patients);

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

UPDATE all_mh_patients tgt
SET tgt.last_visit_enc_id = latest_enc_from_temp(patient_id, @mh_enctype, null);


-- interventions
UPDATE all_mh_patients tgt
SET interventions =  obs_value_coded_list_from_temp(last_visit_enc_id, 'PIH', '10636', 'en');



-- referral
UPDATE all_mh_patients tgt
SET referral =  obs_value_coded_list_from_temp(last_visit_enc_id, 'PIH', '10647', 'en');

SELECT 
CONCAT(@partition,'-',emr_id) "emr_id",
dob,
gender,
town,
referral,
program_enrollment_date,
interventions
FROM all_mh_patients;