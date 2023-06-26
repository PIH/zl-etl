-- ------------ Start of the script --------------------------
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
program_outcome varchar(100),
program_status_start_date date,
program_status_end_date date,
program_status varchar(50),
treatment_status_start_date date,
treatment_status_end_date date,
treatment_status varchar(50)
);


DROP TABLE IF EXISTS oncolog_program_info;
CREATE TEMPORARY TABLE oncolog_program_info AS 
SELECT 
pp.patient_id,
pp.patient_program_id,
zlemr(pp.patient_id) emr_id,
CAST(date_enrolled AS date) program_enrollment_date,
CAST(date_completed AS date) program_completion_date,
concept_name(outcome_concept_id,'en') program_outcome
FROM patient_program pp 
WHERE pp.program_id = @prog_id
AND pp.voided = 0;


DROP TABLE IF EXISTS oncolog_program_status;
CREATE TEMPORARY TABLE oncolog_program_status AS 
SELECT 
pp.patient_id,
pp.patient_program_id,
zlemr(pp.patient_id) emr_id,
cast(ps.start_date AS date) program_status_start_date,
cast(ps.end_date AS date) program_status_end_date,
concept_name(pws.concept_id ,'en') program_status
FROM patient_program pp 
LEFT OUTER JOIN patient_state ps ON pp.patient_program_id =ps.patient_program_id 
LEFT OUTER  JOIN program_workflow_state pws ON pws.program_workflow_state_id =ps.state 
WHERE pp.program_id = @prog_id
AND pp.voided = 0
AND ps.voided = 0
AND pws.concept_id IN (concept_from_mapping('PIH','11582'),concept_from_mapping('PIH','11583'),concept_from_mapping('PIH','1345'),concept_from_mapping('PIH','2224') );

DROP TABLE IF EXISTS oncolog_treatment_status;
CREATE TEMPORARY TABLE oncolog_treatment_status AS 
SELECT 
pp.patient_id,
pp.patient_program_id,
zlemr(pp.patient_id) emr_id,
cast(ps.start_date AS date) treatment_status_start_date,
cast(ps.end_date AS date) treatment_status_end_date,
concept_name(pws.concept_id ,'en') treatment_status
FROM patient_program pp 
LEFT OUTER JOIN patient_state ps ON pp.patient_program_id =ps.patient_program_id 
LEFT OUTER  JOIN program_workflow_state pws ON pws.program_workflow_state_id =ps.state 
WHERE pp.program_id = @prog_id
AND pp.voided = 0
AND ps.voided = 0
AND pws.concept_id IN (concept_from_mapping('PIH','10364'),concept_from_mapping('PIH','10359'));


SELECT 
oi.patient_id,
oi.patient_program_id,
CONCAT(@partition,'-',oi.emr_id) "emr_id",
oi.program_enrollment_date ,
oi.program_completion_date ,
oi.program_outcome,
op.program_status_start_date ,
op.program_status_end_date ,
op.program_status ,
ot.treatment_status_start_date ,
ot.treatment_status_end_date ,
ot.treatment_status
FROM oncolog_program_info oi
LEFT OUTER JOIN oncolog_program_status op ON op.patient_id=oi.patient_id AND op.patient_program_id=oi.patient_program_id
LEFT OUTER JOIN oncolog_treatment_status ot ON ot.patient_id=oi.patient_id AND ot.patient_program_id=oi.patient_program_id
;