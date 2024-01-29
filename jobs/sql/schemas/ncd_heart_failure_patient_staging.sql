CREATE TABLE ncd_heart_failure_patient_staging
(
emr_id		VARCHAR(50),
sex		VARCHAR(2),
birthdate	DATE,
hf_diagnosis_date	DATE,
ncd_enrolled	BIT,
hf_ncd		BIT,
hf_broad	BIT,
hf_left		BIT,
hf_isolated_right	BIT,
hf_congestive	BIT,
hf_rheumatic	BIT,
last_visit_date	DATE,
deceased	BIT
);
