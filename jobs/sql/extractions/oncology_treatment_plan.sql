SELECT encounter_type_id  INTO @enc_type FROM encounter_type et WHERE uuid='f9cfdf8b-d086-4658-9b9d-45a62896da03';
SELECT program_id  INTO @prog_id FROM program p WHERE uuid='5bdbf9f6-690c-11e8-adc0-fa7ae01bbebc';
SET @partition = '${partitionNum}';


DROP TABLE IF EXISTS oncology_treatment_plan;
CREATE TEMPORARY TABLE oncology_treatment_plan (
patient_id int,
emr_id varchar(50),
encounter_id int,
encounter_datetime datetime,
encounter_location varchar(100),
date_entered date,
user_entered varchar(30),
encounter_provider varchar(30),
date_enrolled date,
treatment_intent varchar(30),
cancer_stage varchar(30),
plan_details text);

INSERT INTO oncology_treatment_plan(patient_id, emr_id,encounter_id,encounter_datetime,encounter_location,date_entered,user_entered,encounter_provider)
SELECT 
patient_id,
zlemr(patient_id),
encounter_id,
encounter_datetime ,
encounter_location_name(encounter_id),
date_created,
encounter_creator(encounter_id),
provider(encounter_id)
FROM encounter e 
WHERE encounter_type = @enc_type
AND voided = 0;


-- Cancer Stage
UPDATE oncology_treatment_plan oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.concept_id = concept_from_mapping('PIH','10373')
AND o.voided =0
SET cancer_stage= value_coded_name(o.obs_id,'en');


-- plan_details
UPDATE oncology_treatment_plan oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.concept_id = concept_from_mapping('PIH','2881')
AND o.voided =0
SET plan_details= o.value_text;

DROP TABLE IF EXISTS p_date_enrolled;
CREATE TEMPORARY TABLE p_date_enrolled
SELECT max(date_enrolled) date_enrolled, patient_id
FROM patient_program pp 
WHERE program_id = @prog_id
AND date_completed IS NULL 
GROUP BY patient_id;

UPDATE oncology_treatment_plan oi INNER JOIN p_date_enrolled pd 
ON pd.patient_id =oi.patient_id
SET oi.date_enrolled= pd.date_enrolled;

UPDATE oncology_treatment_plan SET treatment_intent=currentProgramState(patientProgramId(patient_id, @prog_id, date_enrolled),5 ,'en');


SELECT 
emr_id,
CONCAT(@partition,'-',encounter_id) "encounter_id",
encounter_datetime,
encounter_location,
date_entered,
user_entered,
encounter_provider,
treatment_intent,
cancer_stage ,
plan_details
FROM oncology_treatment_plan;
