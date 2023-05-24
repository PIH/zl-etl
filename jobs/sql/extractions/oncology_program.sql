## Start of the script #######
SELECT encounter_type_id  INTO @enc_type FROM encounter_type et WHERE uuid='f9cfdf8b-d086-4658-9b9d-45a62896da03';
SELECT program_id  INTO @prog_id FROM program p WHERE uuid='5bdbf9f6-690c-11e8-adc0-fa7ae01bbebc';
SET @partition = '${partitionNum}';

DROP TABLE IF EXISTS oncology_program;
CREATE TEMPORARY TABLE oncology_program (
patient_id int,
patient_program_id int,
emr_id varchar(50),
program_enrollment_date date,
program_completion_date date,
status_start_date date,
status_end_date date, 
program_status varchar(30),
status_date date,
outcome varchar(100)
);

INSERT INTO oncology_program(patient_id, patient_program_id, emr_id, program_enrollment_date, program_completion_date, status_start_date, status_end_date, program_status, status_date, outcome)
SELECT 
pp.patient_id,
pp.patient_program_id,
zlemr(pp.patient_id),
CAST(date_enrolled AS date) program_enrollment_date,
CAST(date_completed AS date) program_completion_date,
cast(ps.start_date AS date) status_start_date,
cast(ps.end_date AS date) status_end_date,
concept_name(pws.concept_id ,'en') program_status,
CAST(ps.date_created AS date) status_date,
concept_name(outcome_concept_id,'en') outcome
FROM patient_program pp 
LEFT OUTER JOIN patient_state ps ON pp.patient_program_id =ps.patient_program_id 
LEFT OUTER  JOIN program_workflow_state pws ON pws.program_workflow_state_id =ps.state 
WHERE pp.program_id = @prog_id
AND pp.voided = 0
AND ps.voided = 0;

SELECT 
CONCAT(@partition,'-',emr_id) "emr_id",
program_enrollment_date,
program_completion_date,
status_start_date, 
status_end_date,
program_status, 
status_date, 
outcome
FROM oncology_program
ORDER BY emr_id, status_start_date, status_start_date;