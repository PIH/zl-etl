-- -------- Start of the script #######
SELECT encounter_type_id  INTO @enc_type FROM encounter_type et WHERE uuid='f9cfdf8b-d086-4658-9b9d-45a62896da03';
SELECT program_id  INTO @prog_id FROM program p WHERE uuid='5bdbf9f6-690c-11e8-adc0-fa7ae01bbebc';
SET @partition = '${partitionNum}';

DROP TABLE IF EXISTS oncology_program;
CREATE TEMPORARY TABLE oncology_program (
patient_id int,
patient_program_id int,
emr_id varchar(50),
status_start_date date,
status_end_date date,
status_type varchar(50),
status varchar(50)
);

INSERT INTO oncology_program(patient_id,patient_program_id,emr_id,status_start_date,status_end_date,status_type,status)
SELECT 
pp.patient_id,
pp.patient_program_id,
zlemr(pp.patient_id) emr_id,
CAST(date_enrolled AS date) status_start_date,
CAST(date_completed AS date) status_end_date,
'enrollment_status' status_type,
'enrolled' status
FROM patient_program pp 
WHERE  pp.patient_id = 267645 AND pp.program_id = @prog_id
AND pp.voided = 0
;

INSERT INTO oncology_program(patient_id,patient_program_id,emr_id,status_start_date,status_end_date,status_type,status)
SELECT 
pp.patient_id,
pp.patient_program_id,
zlemr(pp.patient_id) emr_id,
CAST(date_completed AS date) status_start_date,
CAST(date_completed AS date) status_end_date,
'outcome' status_type,
concept_name(outcome_concept_id,'en') status
FROM patient_program pp 
WHERE  pp.patient_id = 267645 AND pp.program_id = @prog_id
AND pp.voided = 0
;


INSERT INTO oncology_program(patient_id,patient_program_id,emr_id,status_start_date,status_end_date,status_type,status)
SELECT 
pp.patient_id,
pp.patient_program_id,
zlemr(pp.patient_id) emr_id,
cast(ps.start_date AS date) program_status_start_date,
cast(ps.end_date AS date) program_status_end_date,
'program_status' status_type,
concept_name(pws.concept_id ,'en') program_status
FROM patient_program pp 
LEFT OUTER JOIN patient_state ps ON pp.patient_program_id =ps.patient_program_id 
LEFT OUTER JOIN program_workflow_state pws ON pws.program_workflow_state_id =ps.state 
WHERE pp.program_id = @prog_id
AND pp.voided = 0
AND ps.voided = 0
AND pws.concept_id IN (concept_from_mapping('PIH','11582'),concept_from_mapping('PIH','11583'),concept_from_mapping('PIH','1345'),concept_from_mapping('PIH','2224') );


INSERT INTO oncology_program(patient_id,patient_program_id,emr_id,status_start_date,status_end_date,status_type,status)
SELECT 
pp.patient_id,
pp.patient_program_id,
zlemr(pp.patient_id) emr_id,
cast(ps.start_date AS date) treatment_status_start_date,
cast(ps.end_date AS date) treatment_status_end_date,
'treatment_status' status_type,
concept_name(pws.concept_id ,'en') treatment_status
FROM patient_program pp 
LEFT OUTER JOIN patient_state ps ON pp.patient_program_id =ps.patient_program_id 
LEFT OUTER JOIN program_workflow_state pws ON pws.program_workflow_state_id =ps.state 
WHERE pp.program_id = @prog_id
AND pp.voided = 0
AND ps.voided = 0
AND pws.concept_id IN (concept_from_mapping('PIH','10364'),concept_from_mapping('PIH','10359'));

SELECT 
DISTINCT 
CONCAT(@partition,'-',emr_id) "emr_id",
status_start_date,
status_end_date,
status_type,
status
FROM oncology_program 
ORDER BY emr_id, status_start_date asc
;
