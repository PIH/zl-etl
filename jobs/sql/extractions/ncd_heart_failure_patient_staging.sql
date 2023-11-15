SET @isolated_right_heart_failure = CONCEPT_FROM_MAPPING('PIH', 4000);
SET @congestive_heart_failure_exacerbation = CONCEPT_FROM_MAPPING('PIH', 9444);
SET @left_heart_failure = CONCEPT_FROM_MAPPING('PIH', 12645);
SET @heart_failure = CONCEPT_FROM_MAPPING('PIH', 3468);
SET @rheumatic_heart_disease = CONCEPT_FROM_MAPPING('PIH', 221);
SET @ncd_initial_consult = (SELECT encounter_type_id FROM encounter_type e WHERE e.name="NCD Initial Consult" AND retired = 0);
SET @ncd_followup_consult = (SELECT encounter_type_id FROM encounter_type e WHERE e.name="NCD Followup Consult" AND retired = 0);
SET @ncd_program = (SELECT program_id FROM program p WHERE p.name = "NCD");

DROP TEMPORARY TABLE IF EXISTS temp_ncd_heart_failure_stage;
CREATE TEMPORARY TABLE temp_ncd_heart_failure_stage (
patient_id INT,
encounter_id INT,
obs_datetime datetime,
value_coded INT
);

INSERT INTO temp_ncd_heart_failure_stage (
patient_id,
encounter_id,
obs_datetime,
value_coded
)
SELECT 
person_id,
encounter_id,
obs_datetime,
value_coded 
FROM obs o 
WHERE -- concept_id = concept_from_mapping('PIH','DIAGNOSIS') AND 
value_coded IN (
@isolated_right_heart_failure, 
@congestive_heart_failure_exacerbation, 
@left_heart_failure, 
@heart_failure,
@rheumatic_heart_disease
)
AND o.voided = 0;

CREATE INDEX temp_ncd_heart_failure_stage_patientid ON temp_ncd_heart_failure_stage(patient_id);
CREATE INDEX temp_ncd_heart_failure_stage_encounterid ON temp_ncd_heart_failure_stage(encounter_id);
CREATE INDEX temp_ncd_heart_failure_stage_valuecoded ON temp_ncd_heart_failure_stage(value_coded);

DROP TEMPORARY TABLE IF EXISTS temp_ncd_heart_failure;
CREATE TEMPORARY TABLE temp_ncd_heart_failure (
patient_id INT,
emr_id VARCHAR(20),
encounter_id INT,
encounter_type_id INT,
encounter_type_name VARCHAR(100),
latest_encounter_type_name VARCHAR(100),
obs_id INT,
obs_datetime DATETIME,
date_created DATETIME,
value_coded INT,
hf_diagnosis_date DATETIME,
ncd_enrolled BOOLEAN,
hf_ncd BOOLEAN,
hf_broad BOOLEAN,
hf_left BOOLEAN,
hf_isolated_right BOOLEAN,
hf_congestive BOOLEAN,
hf_rheumatic BOOLEAN,
last_visit_date DATE,
deceased BOOLEAN
);

INSERT INTO temp_ncd_heart_failure (
patient_id,
emr_id
)
SELECT 
DISTINCT(patient_id), zlemr(patient_id) 
FROM temp_ncd_heart_failure_stage; 


-- index
CREATE INDEX temp_ncd_heart_failure_patientid ON temp_ncd_heart_failure(patient_id);
CREATE INDEX temp_ncd_heart_failure_encounterid ON temp_ncd_heart_failure(encounter_id);
CREATE INDEX temp_ncd_heart_failure_encountertypeid ON temp_ncd_heart_failure(encounter_type_id);

# Patient diagnosed with "broad category" heart failure	
drop temporary table if exists temp_hf_broad;
create temporary table temp_hf_broad as 
select patient_id from temp_ncd_heart_failure_stage where value_coded = @heart_failure group by patient_id;
  
UPDATE temp_ncd_heart_failure t join temp_hf_broad tt on t.patient_id = tt.patient_id 
SET hf_broad = 1;

UPDATE temp_ncd_heart_failure t
SET t.hf_broad = 0 WHERE t.hf_broad IS NULL;

# Patient diagnosed with left heart failure
drop temporary table if exists temp_hf_left;
create temporary table temp_hf_left as 
select patient_id from temp_ncd_heart_failure_stage where value_coded = @left_heart_failure group by patient_id;
  
UPDATE temp_ncd_heart_failure t join temp_hf_left tt on t.patient_id = tt.patient_id 
SET hf_left = 1;

UPDATE temp_ncd_heart_failure t
SET t.hf_left = 0 WHERE t.hf_left IS NULL;

# Patient diagnosed with isolated right heart failure
drop temporary table if exists temp_hf_isolated_right;
create temporary table temp_hf_isolated_right as 
select patient_id from temp_ncd_heart_failure_stage where value_coded = @isolated_right_heart_failure group by patient_id;
  
UPDATE temp_ncd_heart_failure t join temp_hf_isolated_right tt on t.patient_id = tt.patient_id 
SET hf_isolated_right = 1;

UPDATE temp_ncd_heart_failure t
SET t.hf_isolated_right = 0 WHERE t.hf_isolated_right IS NULL;
	
# Patient diagnosed with congestive heart failure exacerbation
drop temporary table if exists temp_hf_congestive;
create temporary table temp_hf_congestive as 
select patient_id from temp_ncd_heart_failure_stage where value_coded = @congestive_heart_failure_exacerbation group by patient_id;
  
UPDATE temp_ncd_heart_failure t join temp_hf_congestive tt on t.patient_id = tt.patient_id 
SET hf_congestive = 1;

UPDATE temp_ncd_heart_failure t
SET t.hf_congestive = 0 WHERE t.hf_congestive IS NULL;

# Patient diagnosed with rheumatic heart failure
drop temporary table if exists temp_hf_rheumatic;
create temporary table temp_hf_rheumatic as 
select patient_id from temp_ncd_heart_failure_stage where value_coded = @rheumatic_heart_disease group by patient_id;
  
UPDATE temp_ncd_heart_failure t join temp_hf_rheumatic tt on t.patient_id = tt.patient_id 
SET hf_rheumatic = 1;

UPDATE temp_ncd_heart_failure t
SET t.hf_rheumatic = 0 WHERE t.hf_rheumatic IS NULL;

# hf_diagnosis_date
UPDATE temp_ncd_heart_failure t  
SET hf_diagnosis_date = (select min(obs_datetime) from temp_ncd_heart_failure_stage tt where t.patient_id = tt.patient_id group by tt.patient_id);

# Patient diagnosed with heart failure in NCD form
DROP TEMPORARY TABLE IF EXISTS temp_ncd_heart_failure_ncd_enc;
CREATE TEMPORARY TABLE temp_ncd_heart_failure_ncd_enc AS
SELECT patient_id FROM temp_ncd_heart_failure_stage WHERE encounter_id in (select encounter_id from encounter where encounter_type IN (@ncd_initial_consult, @ncd_followup_consult) and voided = 0)
group by patient_id;
UPDATE temp_ncd_heart_failure t JOIN temp_ncd_heart_failure_ncd_enc tt
ON t.patient_id = tt.patient_id
SET t.hf_ncd = 1;

UPDATE temp_ncd_heart_failure t
SET t.hf_ncd = 0 WHERE t.hf_ncd IS NULL;


# Date of last visit
DROP TEMPORARY TABLE IF EXISTS temp_ncd_heart_failure_last_visit_date;
CREATE TEMPORARY TABLE temp_ncd_heart_failure_last_visit_date
(
patient_id INT, 
last_enc_date DATETIME
);
INSERT INTO temp_ncd_heart_failure_last_visit_date
(patient_id, 
last_enc_date)

SELECT patient_id, MAX(encounter_datetime) last_enc_date FROM encounter WHERE voided = 0 AND patient_id IN (SELECT patient_id FROM temp_ncd_heart_failure) GROUP BY patient_id;
UPDATE temp_ncd_heart_failure t JOIN temp_ncd_heart_failure_last_visit_date tt ON t.patient_id = tt.patient_id
SET last_visit_date = DATE(tt.last_enc_date);

# Is the patient deceased?	
UPDATE temp_ncd_heart_failure t INNER JOIN person p ON t.patient_id = p.person_id AND p.voided = 0
SET t.deceased = dead;

# Patient enrolled in NCD program?
DROP TEMPORARY TABLE IF EXISTS temp_ncd_heart_failure_ncd_program;
CREATE TEMPORARY TABLE temp_ncd_heart_failure_ncd_program AS
SELECT patient_id FROM patient_program WHERE date_completed IS NULL AND patient_id IN (SELECT patient_id FROM temp_ncd_heart_failure) AND program_id = @ncd_program AND voided = 0;
UPDATE temp_ncd_heart_failure t JOIN temp_ncd_heart_failure_ncd_program tt
ON t.patient_id = tt.patient_id
SET t.ncd_enrolled = 1;

UPDATE temp_ncd_heart_failure t
SET t.ncd_enrolled = 0 WHERE t.ncd_enrolled IS NULL;

# final query
SELECT
emr_id,
GENDER(patient_id) as 'sex',
BIRTHDATE(patient_id) as 'birthdate',
DATE(hf_diagnosis_date) as 'hf_diagnosis_date',
ncd_enrolled,
hf_ncd,
hf_broad,
hf_left,
hf_isolated_right,
hf_congestive,
hf_rheumatic,
last_visit_date,
deceased
FROM temp_ncd_heart_failure order by patient_id;
