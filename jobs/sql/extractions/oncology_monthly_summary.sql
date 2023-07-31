-- Start ---------------------
SELECT encounter_type_id  INTO @trt_enc_type FROM encounter_type et WHERE uuid='f9cfdf8b-d086-4658-9b9d-45a62896da03';
SELECT encounter_type_id  INTO @intake_enc_type FROM encounter_type et WHERE uuid='a936ae01-6d10-455d-befc-b2d1828dad04';
SELECT program_id  INTO @prog_id FROM program p WHERE uuid='5bdbf9f6-690c-11e8-adc0-fa7ae01bbebc';
SET @date:=CURRENT_DATE() ;
SET @partition = '${partitionNum}';


DROP TABLE IF EXISTS oncology_monthly_summary;
CREATE TEMPORARY TABLE oncology_monthly_summary (
patient_id int,
patient_program_id int,
emr_id varchar(50),
enrollment_date date,
enrollment_location varchar(100),
program_completion_date date,
program_outcome varchar(50),
latest_stage varchar(100),
-- status (based on 1/3 month threshold logic)
latest_intake_date date,
latest_treatment_plan_date date,
latest_chemotherapy_date date,
latest_consult_note varchar(100),
latest_oncology_program_status varchar(100),
latest_oncology_treatment_status varchar(100)
);

INSERT INTO oncology_monthly_summary(patient_id,patient_program_id,emr_id,enrollment_date,enrollment_location,program_completion_date,program_outcome)
SELECT 
pp.patient_id,
pp.patient_program_id,
zlemr(pp.patient_id) emr_id,
pp.date_enrolled enrollment_date,
initialProgramLocation( pp.patient_id ,@prog_id) enrollment_location,
pp.date_completed program_completion_date,
concept_name(outcome_concept_id,'en') program_outcome
FROM patient_program pp 
WHERE  -- pp.patient_id = 267645 AND 
pp.program_id = @prog_id
AND pp.voided = 0
;

-- latest_intake_date
UPDATE oncology_monthly_summary src INNER JOIN (
SELECT patient_id, max(encounter_datetime) encounter_datetime
FROM encounter e 
WHERE encounter_type = @intake_enc_type
GROUP BY patient_id ) tgt
ON src.patient_id=tgt.patient_id
SET src.latest_intake_date=CAST(tgt.encounter_datetime AS date);

-- latest_treatment_plan_date
UPDATE oncology_monthly_summary src INNER JOIN (
SELECT patient_id, max(encounter_datetime) encounter_datetime
FROM encounter e 
WHERE encounter_type = @trt_enc_type
GROUP BY patient_id ) tgt
ON src.patient_id=tgt.patient_id
SET src.latest_treatment_plan_date=CAST(tgt.encounter_datetime AS date);

DROP TABLE IF EXISTS ltst_prog_stats;
CREATE TEMPORARY TABLE ltst_prog_stats
SELECT 
pp.patient_id,max(pp.patient_program_id) patient_program_id
FROM patient_program pp 
WHERE pp.program_id = @prog_id
GROUP BY patient_id;

DROP TABLE IF EXISTS ltst_trt_enc;
CREATE TEMPORARY TABLE ltst_trt_enc
SELECT 
patient_id,max(encounter_id) encounter_id
FROM encounter e 
WHERE encounter_type = @trt_enc_type
GROUP BY patient_id;

DROP TABLE IF EXISTS ltst_int_enc;
CREATE TEMPORARY TABLE ltst_int_enc
SELECT 
patient_id,max(encounter_id) encounter_id
FROM encounter e 
WHERE encounter_type = @intake_enc_type
GROUP BY patient_id;

-- Program Status
UPDATE oncology_monthly_summary tgt
SET latest_oncology_program_status = (
SELECT 
concept_name(pws.concept_id ,'en') program_status
FROM patient_program pp 
LEFT OUTER JOIN patient_state ps ON pp.patient_program_id =ps.patient_program_id 
LEFT OUTER JOIN program_workflow_state pws ON pws.program_workflow_state_id =ps.state 
WHERE pp.patient_id = tgt. patient_id -- 267645 
AND pp.program_id = @prog_id AND pp.patient_program_id IN (SELECT patient_program_id FROM ltst_prog_stats)
AND pp.voided = 0
AND ps.voided = 0
AND pws.concept_id IN (concept_from_mapping('PIH','11582'),concept_from_mapping('PIH','11583'),concept_from_mapping('PIH','1345'),concept_from_mapping('PIH','2224'))
ORDER BY cast(ps.start_date AS date) DESC 
LIMIT 1 );

-- Treatment Status
UPDATE oncology_monthly_summary tgt
SET latest_oncology_treatment_status = (
SELECT 
concept_name(pws.concept_id ,'en') program_status
FROM patient_program pp 
LEFT OUTER JOIN patient_state ps ON pp.patient_program_id =ps.patient_program_id 
LEFT OUTER JOIN program_workflow_state pws ON pws.program_workflow_state_id =ps.state 
WHERE pp.patient_id = tgt. patient_id -- 267645 
AND pp.program_id = @prog_id AND pp.patient_program_id IN (SELECT patient_program_id FROM ltst_prog_stats)
AND pp.voided = 0
AND ps.voided = 0
AND pws.concept_id IN (concept_from_mapping('PIH','10364'),concept_from_mapping('PIH','10359'))
ORDER BY cast(ps.start_date AS date) DESC 
LIMIT 1 );

-- Latest Stage
UPDATE oncology_monthly_summary tgt
SET latest_stage = (
SELECT value_coded_name(o.obs_id,'en')
FROM obs o
WHERE o.encounter_id IN (SELECT encounter_id FROM ltst_trt_enc) 
AND o.person_id  =tgt.patient_id
AND o.concept_id = concept_from_mapping('PIH','10373')
AND o.voided =0
);

-- Latest Consult Note
UPDATE oncology_monthly_summary tgt
SET latest_consult_note = (
SELECT value_text
FROM obs o
WHERE o.encounter_id IN (SELECT encounter_id FROM ltst_int_enc) 
AND o.person_id  =tgt.patient_id
AND o.concept_id = concept_from_mapping('PIH','10578')
AND o.voided =0
);

SELECT 
DATE_SUB(@date, INTERVAL DAYOFMONTH(@date)-1 DAY) report_month,
emr_id ,
enrollment_date ,
enrollment_location ,
program_completion_date ,
program_outcome ,
latest_stage,
latest_intake_date ,
latest_treatment_plan_date ,
latest_chemotherapy_date ,
latest_consult_note ,
latest_oncology_program_status ,
latest_oncology_treatment_status
FROM oncology_monthly_summary;