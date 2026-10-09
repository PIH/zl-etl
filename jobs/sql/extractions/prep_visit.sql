-- ---------------------------------------------------------------
-- prep_visit
-- One row per PrEP Intake or PrEP Followup encounter
-- Forms: zl-emr htmlforms/hiv/prep-intake.xml and prep-followup.xml
-- Columns that only exist on one of the two forms are NULL for the other encounter type.
-- index_asc / index_desc / index_program_asc / index_program_desc are populated
-- downstream in sql/derivations/update_index_numbers.sql
-- ---------------------------------------------------------------
SET sql_safe_updates = 0;
SET @partition = '${partitionNum}';
SET @locale = 'en';

SET @prep_intake   = (SELECT encounter_type_id FROM encounter_type WHERE uuid = '2fb72359-f6fe-4b37-bb11-9b4cb5fd6ca7');
SET @prep_followup = (SELECT encounter_type_id FROM encounter_type WHERE uuid = '4fe5fc03-b42b-4bb2-8ed8-e3c7de8942fb');
SET @prep_program  = (SELECT program_id FROM program WHERE uuid = 'c5e3e6ca-d10f-4b80-9152-11a91f7d38eb');
SET @emr_identifier_type  = 'a541af1e-105c-40bf-b345-ba1fd6a59b85';
SET @prep_identifier_type = 'ea204038-be61-432d-a3fe-df31f784365e';

SET @vmmc     = concept_from_mapping('CIEL','166677');
SET @vmmc_yes = concept_from_mapping('CIEL','145096');
SET @vmmc_no  = concept_from_mapping('CIEL','163841');

DROP TEMPORARY TABLE IF EXISTS temp_prep_visit;
CREATE TEMPORARY TABLE temp_prep_visit
(
encounter_id                      INT(11),
visit_id                          INT(11),
patient_id                        INT(11),
emr_id                            VARCHAR(50),
prep_code                         VARCHAR(50),
prep_program_id                   INT(11),
encounter_type_id                 INT(11),
encounter_type                    VARCHAR(255),
encounter_datetime                DATETIME,
datetime_created                  DATETIME,
creator                           INT(11),
user_entered                      VARCHAR(255),
provider                          VARCHAR(255),
encounter_location_id             INT(11),
encounter_location                VARCHAR(255),
visit_location                    VARCHAR(255),
site                              VARCHAR(255),
-- intake: overview / population category
pop_msm                           BOOLEAN,
pop_sex_worker                    BOOLEAN,
pop_transgender                   BOOLEAN,
pop_injection_drug_user           BOOLEAN,
pop_serodiscordant_couple         BOOLEAN,
pop_other                         BOOLEAN,
education_level                   VARCHAR(255),
-- labs (both forms)
hiv_test_obs_group_id             INT(11),
hiv_test_result                   VARCHAR(255),
hiv_test_date                     DATE,
rpr_obs_group_id                  INT(11),
rpr_result                        VARCHAR(255),
rpr_date                          DATE,
creatinine_clearance              DOUBLE,
-- intake: steps before PrEP / screening / consent / initiation
prep_counseling                   BOOLEAN,
interested_in_prep                BOOLEAN,
hep_b_surface_antigen             VARCHAR(255),
pregnancy_test_result             VARCHAR(255),
last_sex_date                     DATE,
acute_hiv_signs                   BOOLEAN,
start_prep                        BOOLEAN,
prep_consent                      BOOLEAN,
prep_start_date                   DATE,
-- intake: transfer / referral in
followed_elsewhere_for_prep       BOOLEAN,
estimated_program_start_date      DATE,
referral_clinic                   TEXT,
referral_date                     DATE,
-- followup: monitoring
pregnant                          BOOLEAN,
breastfeeding_status              VARCHAR(255),
wean_date                         DATE,
side_effect_abdominal_pain        BOOLEAN,
side_effect_rash                  BOOLEAN,
side_effect_nausea                BOOLEAN,
side_effect_vomiting              BOOLEAN,
side_effect_diarrhea              BOOLEAN,
side_effect_fatigue               BOOLEAN,
side_effect_swollen_lymph_nodes   BOOLEAN,
side_effect_fever                 BOOLEAN,
side_effect_other                 BOOLEAN,
side_effect_other_text            TEXT,
sti_urethral_discharge            BOOLEAN,
sti_genital_ulcers                BOOLEAN,
sti_abnormal_vaginal_bleeding     BOOLEAN,
sti_foul_vaginal_discharge        BOOLEAN,
sti_abdominal_pain                BOOLEAN,
sti_scrotal_swelling              BOOLEAN,
sti_inguinal_bubo                 BOOLEAN,
sti_other                         BOOLEAN,
sti_other_text                    TEXT,
-- drug orders (both forms)
prep_drugs_prescribed             TEXT,
prep_drugs_discontinued           TEXT,
-- prevention and education (both forms)
hiv_risk_counseling               BOOLEAN,
condoms_provided                  BOOLEAN,
lubricant_provided                BOOLEAN,
vmmc                              BOOLEAN,
other_prevention                  TEXT,
-- followup: status
prep_adherence                    VARCHAR(255),
disposition                       VARCHAR(255),
remarks                           TEXT,
-- both forms
next_visit_date                   DATE,
index_asc                         INT,
index_desc                        INT,
index_program_asc                 INT,
index_program_desc                INT
);

INSERT INTO temp_prep_visit (encounter_id, visit_id, patient_id, encounter_type_id, encounter_datetime, datetime_created, creator, encounter_location_id)
SELECT encounter_id, visit_id, patient_id, encounter_type, encounter_datetime, date_created, creator, location_id
FROM encounter
WHERE voided = 0
AND encounter_type IN (@prep_intake, @prep_followup);

CREATE INDEX temp_prep_visit_pid ON temp_prep_visit (patient_id);
CREATE INDEX temp_prep_visit_eid ON temp_prep_visit (encounter_id);

-- remove test patients
DELETE FROM temp_prep_visit
WHERE patient_id IN
	(SELECT a.person_id
	FROM person_attribute a
	INNER JOIN person_attribute_type t ON a.person_attribute_type_id = t.person_attribute_type_id
		AND a.value = 'true'
		AND t.name = 'Test Patient');

-- ---------------------------------------------------------------
-- encounter-level columns
-- ---------------------------------------------------------------
UPDATE temp_prep_visit t
INNER JOIN encounter_type et ON et.encounter_type_id = t.encounter_type_id
SET t.encounter_type = et.name;

-- identifiers (functions run once per patient)
DROP TEMPORARY TABLE IF EXISTS temp_prep_identifiers;
CREATE TEMPORARY TABLE temp_prep_identifiers
(
patient_id   INT(11) PRIMARY KEY,
emr_id       VARCHAR(50),
prep_code    VARCHAR(50)
);
INSERT INTO temp_prep_identifiers (patient_id)
SELECT DISTINCT patient_id FROM temp_prep_visit;

UPDATE temp_prep_identifiers
SET emr_id = patient_identifier(patient_id, @emr_identifier_type),
	prep_code = patient_identifier(patient_id, @prep_identifier_type);

UPDATE temp_prep_visit t
INNER JOIN temp_prep_identifiers i ON i.patient_id = t.patient_id
SET t.emr_id = i.emr_id,
	t.prep_code = i.prep_code;

-- users (function runs once per user)
DROP TEMPORARY TABLE IF EXISTS temp_prep_users;
CREATE TEMPORARY TABLE temp_prep_users
(
user_id    INT(11) PRIMARY KEY,
user_name  VARCHAR(255)
);
INSERT INTO temp_prep_users (user_id)
SELECT DISTINCT creator FROM temp_prep_visit;
UPDATE temp_prep_users SET user_name = person_name_of_user(user_id);

UPDATE temp_prep_visit t
INNER JOIN temp_prep_users u ON u.user_id = t.creator
SET t.user_entered = u.user_name;

UPDATE temp_prep_visit
SET provider = provider(encounter_id);

UPDATE temp_prep_visit
SET prep_program_id = patient_program_id_from_encounter(patient_id, @prep_program, encounter_id);

-- Sets encounter_location from the encounter's location.
-- Sets site as the Visit Location ancestor of the encounter location (fallback for rows with no visit).
CREATE INDEX temp_prep_visit_li ON temp_prep_visit (encounter_location_id);
UPDATE temp_prep_visit t
INNER JOIN locations ls ON ls.location_id = t.encounter_location_id
SET t.encounter_location = ls.location_name,
	t.site = ls.site;

-- Sets visit_location from the visit's location.
-- Overrides site with visit_location when a visit exists, since visits are
-- associated directly with the Visit Location — more accurate than the ancestor walk.
CREATE INDEX temp_prep_visit_vi ON temp_prep_visit (visit_id);
UPDATE temp_prep_visit t
INNER JOIN visit v ON v.visit_id = t.visit_id
INNER JOIN locations ls ON ls.location_id = v.location_id
SET t.visit_location = ls.location_name,
	t.site = ls.location_name;

-- ---------------------------------------------------------------
-- obs
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_obs;
CREATE TEMPORARY TABLE temp_obs
SELECT o.obs_id, o.voided, o.obs_group_id, o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric,
	o.value_text, o.value_datetime, o.comments, o.date_created, o.obs_datetime
FROM obs o
INNER JOIN temp_prep_visit t ON t.encounter_id = o.encounter_id
WHERE o.voided = 0;

CREATE INDEX temp_obs_ci1 ON temp_obs (encounter_id, concept_id);
CREATE INDEX temp_obs_ci2 ON temp_obs (obs_group_id, concept_id);
CREATE INDEX temp_obs_oi ON temp_obs (obs_id);

-- population category (intake checkboxes, CIEL:160581)
UPDATE temp_prep_visit
SET pop_msm = answer_exists_in_encounter_temp(encounter_id, 'CIEL', '160581', 'CIEL', '160578')
WHERE encounter_type_id = @prep_intake;

UPDATE temp_prep_visit
SET pop_sex_worker = answer_exists_in_encounter_temp(encounter_id, 'CIEL', '160581', 'CIEL', '166513')
WHERE encounter_type_id = @prep_intake;

UPDATE temp_prep_visit
SET pop_transgender = answer_exists_in_encounter_temp(encounter_id, 'CIEL', '160581', 'CIEL', '166415')
WHERE encounter_type_id = @prep_intake;

UPDATE temp_prep_visit
SET pop_injection_drug_user = answer_exists_in_encounter_temp(encounter_id, 'CIEL', '160581', 'CIEL', '105')
WHERE encounter_type_id = @prep_intake;

UPDATE temp_prep_visit
SET pop_serodiscordant_couple = answer_exists_in_encounter_temp(encounter_id, 'CIEL', '160581', 'CIEL', '6096')
WHERE encounter_type_id = @prep_intake;

UPDATE temp_prep_visit
SET pop_other = answer_exists_in_encounter_temp(encounter_id, 'CIEL', '160581', 'CIEL', '5622')
WHERE encounter_type_id = @prep_intake;

UPDATE temp_prep_visit
SET education_level = obs_value_coded_list_from_temp(encounter_id, 'CIEL', '1712', @locale);

-- HIV test (obs group PIH:11522)
UPDATE temp_prep_visit
SET hiv_test_obs_group_id = obs_id_from_temp(encounter_id, 'PIH', '11522', 0);

UPDATE temp_prep_visit
SET hiv_test_result = obs_from_group_id_value_coded_list_from_temp(hiv_test_obs_group_id, 'CIEL', '163722', @locale)
WHERE hiv_test_obs_group_id IS NOT NULL;

UPDATE temp_prep_visit
SET hiv_test_date = DATE(obs_from_group_id_value_datetime_from_temp(hiv_test_obs_group_id, 'PIH', 'DATE OF LABORATORY TEST'))
WHERE hiv_test_obs_group_id IS NOT NULL;

-- RPR / syphilis test (obs group PIH:11523)
UPDATE temp_prep_visit
SET rpr_obs_group_id = obs_id_from_temp(encounter_id, 'PIH', '11523', 0);

UPDATE temp_prep_visit
SET rpr_result = obs_from_group_id_value_coded_list_from_temp(rpr_obs_group_id, 'PIH', 'RPR', @locale)
WHERE rpr_obs_group_id IS NOT NULL;

UPDATE temp_prep_visit
SET rpr_date = DATE(obs_from_group_id_value_datetime_from_temp(rpr_obs_group_id, 'PIH', 'DATE OF LABORATORY TEST'))
WHERE rpr_obs_group_id IS NOT NULL;

UPDATE temp_prep_visit
SET creatinine_clearance = obs_value_numeric_from_temp(encounter_id, 'CIEL', '161134');

-- intake: steps before PrEP, screening, consent, initiation
UPDATE temp_prep_visit
SET prep_counseling       = value_coded_as_boolean(obs_id_from_temp(encounter_id, 'CIEL', '165335', 0));

UPDATE temp_prep_visit
SET interested_in_prep    = value_coded_as_boolean(obs_id_from_temp(encounter_id, 'CIEL', '166657', 0));

UPDATE temp_prep_visit
SET hep_b_surface_antigen = obs_value_coded_list_from_temp(encounter_id, 'CIEL', '159430', @locale);

UPDATE temp_prep_visit
SET pregnancy_test_result = obs_value_coded_list_from_temp(encounter_id, 'CIEL', '45', @locale);

UPDATE temp_prep_visit
SET last_sex_date         = DATE(obs_value_datetime_from_temp(encounter_id, 'PIH', '20885'));

UPDATE temp_prep_visit
SET acute_hiv_signs       = value_coded_as_boolean(obs_id_from_temp(encounter_id, 'PIH', '20888', 0));

UPDATE temp_prep_visit
SET start_prep            = value_coded_as_boolean(obs_id_from_temp(encounter_id, 'PIH', '20886', 0));

UPDATE temp_prep_visit
SET prep_consent          = value_coded_as_boolean(obs_id_from_temp(encounter_id, 'PIH', '20887', 0));

UPDATE temp_prep_visit
SET prep_start_date       = DATE(obs_value_datetime_from_temp(encounter_id, 'PIH', '20897'));

-- intake: transfer / referral in
UPDATE temp_prep_visit
SET followed_elsewhere_for_prep  = value_coded_as_boolean(obs_id_from_temp(encounter_id, 'CIEL', '170089', 0));

UPDATE temp_prep_visit
SET estimated_program_start_date = DATE(obs_value_datetime_from_temp(encounter_id, 'PIH', '21422'));

UPDATE temp_prep_visit
SET referral_clinic              = obs_value_text_from_temp(encounter_id, 'PIH', '11483');

UPDATE temp_prep_visit
SET referral_date                = DATE(obs_value_datetime_from_temp(encounter_id, 'CIEL', '163181'));

-- followup: pregnancy / breastfeeding
UPDATE temp_prep_visit
SET pregnant             = value_coded_as_boolean(obs_id_from_temp(encounter_id, 'CIEL', '5272', 0));

UPDATE temp_prep_visit
SET breastfeeding_status = obs_value_coded_list_from_temp(encounter_id, 'CIEL', '985', @locale);

UPDATE temp_prep_visit
SET wean_date            = DATE(obs_value_datetime_from_temp(encounter_id, 'CIEL', '166566'));

-- followup: medication side effects (checkboxes, PIH:ADVERSE EFFECT)
UPDATE temp_prep_visit
SET side_effect_abdominal_pain      = answer_exists_in_encounter_temp(encounter_id, 'PIH', 'ADVERSE EFFECT', 'CIEL', '151')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET side_effect_rash                = answer_exists_in_encounter_temp(encounter_id, 'PIH', 'ADVERSE EFFECT', 'CIEL', '512')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET side_effect_nausea              = answer_exists_in_encounter_temp(encounter_id, 'PIH', 'ADVERSE EFFECT', 'CIEL', '5978')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET side_effect_vomiting            = answer_exists_in_encounter_temp(encounter_id, 'PIH', 'ADVERSE EFFECT', 'CIEL', '122983')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET side_effect_diarrhea            = answer_exists_in_encounter_temp(encounter_id, 'PIH', 'ADVERSE EFFECT', 'CIEL', '142412')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET side_effect_fatigue             = answer_exists_in_encounter_temp(encounter_id, 'PIH', 'ADVERSE EFFECT', 'CIEL', '140501')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET side_effect_swollen_lymph_nodes = answer_exists_in_encounter_temp(encounter_id, 'PIH', 'ADVERSE EFFECT', 'PIH', '161')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET side_effect_fever               = answer_exists_in_encounter_temp(encounter_id, 'PIH', 'ADVERSE EFFECT', 'CIEL', '140238')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET side_effect_other               = answer_exists_in_encounter_temp(encounter_id, 'PIH', 'ADVERSE EFFECT', 'CIEL', '5622')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET side_effect_other_text          = obs_value_text_from_temp(encounter_id, 'PIH', '1729')
WHERE encounter_type_id = @prep_followup;

-- followup: STI symptoms (checkboxes, PIH:1293)
UPDATE temp_prep_visit
SET sti_urethral_discharge        = answer_exists_in_encounter_temp(encounter_id, 'PIH', '1293', 'CIEL', '123529')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET sti_genital_ulcers            = answer_exists_in_encounter_temp(encounter_id, 'PIH', '1293', 'CIEL', '864')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET sti_abnormal_vaginal_bleeding = answer_exists_in_encounter_temp(encounter_id, 'PIH', '1293', 'CIEL', '150802')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET sti_foul_vaginal_discharge    = answer_exists_in_encounter_temp(encounter_id, 'PIH', '1293', 'CIEL', '165162')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET sti_abdominal_pain            = answer_exists_in_encounter_temp(encounter_id, 'PIH', '1293', 'CIEL', '151')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET sti_scrotal_swelling          = answer_exists_in_encounter_temp(encounter_id, 'PIH', '1293', 'CIEL', '125203')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET sti_inguinal_bubo             = answer_exists_in_encounter_temp(encounter_id, 'PIH', '1293', 'CIEL', '137155')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET sti_other                     = answer_exists_in_encounter_temp(encounter_id, 'PIH', '1293', 'CIEL', '5622')
WHERE encounter_type_id = @prep_followup;

UPDATE temp_prep_visit
SET sti_other_text                = obs_value_text_from_temp(encounter_id, 'PIH', '1374')
WHERE encounter_type_id = @prep_followup;

-- prevention and education (both forms)
UPDATE temp_prep_visit
SET hiv_risk_counseling = value_coded_as_boolean(obs_id_from_temp(encounter_id, 'PIH', '20898', 0));

UPDATE temp_prep_visit
SET condoms_provided    = value_coded_as_boolean(obs_id_from_temp(encounter_id, 'CIEL', '159777', 0));

UPDATE temp_prep_visit
SET lubricant_provided  = value_coded_as_boolean(obs_id_from_temp(encounter_id, 'PIH', '21424', 0));

UPDATE temp_prep_visit
SET other_prevention    = obs_value_text_from_temp(encounter_id, 'PIH', '21428');

-- VMMC answers are not Yes/No concepts (CIEL:145096 = yes, CIEL:163841 = no on the form)
UPDATE temp_prep_visit t
INNER JOIN temp_obs o ON o.encounter_id = t.encounter_id AND o.concept_id = @vmmc
SET t.vmmc =
	CASE o.value_coded
		WHEN @vmmc_yes THEN 1
		WHEN @vmmc_no THEN 0
	END;

-- followup: status
UPDATE temp_prep_visit
SET prep_adherence = obs_value_coded_list_from_temp(encounter_id, 'CIEL', '164847', @locale);

UPDATE temp_prep_visit
SET disposition    = obs_value_coded_list_from_temp(encounter_id, 'PIH', '8620', @locale);

UPDATE temp_prep_visit
SET remarks        = obs_value_text_from_temp(encounter_id, 'PIH', '1620');

-- both forms
UPDATE temp_prep_visit
SET next_visit_date = DATE(obs_value_datetime_from_temp(encounter_id, 'PIH', 'RETURN VISIT DATE'));

-- ---------------------------------------------------------------
-- drug orders placed on the form (full order detail is in all_medication_prescribed)
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_prep_orders;
CREATE TEMPORARY TABLE temp_prep_orders
(
encounter_id             INT(11) PRIMARY KEY,
drugs_prescribed         TEXT,
drugs_discontinued       TEXT
);
INSERT INTO temp_prep_orders (encounter_id, drugs_prescribed, drugs_discontinued)
SELECT o.encounter_id,
	GROUP_CONCAT(DISTINCT CASE WHEN o.order_action <> 'DISCONTINUE' THEN drugName(d.drug_inventory_id) END ORDER BY o.order_id SEPARATOR ' | '),
	GROUP_CONCAT(DISTINCT CASE WHEN o.order_action = 'DISCONTINUE' THEN drugName(d.drug_inventory_id) END ORDER BY o.order_id SEPARATOR ' | ')
FROM orders o
INNER JOIN drug_order d ON d.order_id = o.order_id
INNER JOIN temp_prep_visit t ON t.encounter_id = o.encounter_id
WHERE o.voided = 0
GROUP BY o.encounter_id;

UPDATE temp_prep_visit t
INNER JOIN temp_prep_orders o ON o.encounter_id = t.encounter_id
SET t.prep_drugs_prescribed = o.drugs_prescribed,
	t.prep_drugs_discontinued = o.drugs_discontinued;

-- ---------------------------------------------------------------
-- final output
-- ---------------------------------------------------------------
SELECT
	emr_id,
	prep_code,
	CONCAT(@partition, '-', patient_id) "patient_id",
	CONCAT(@partition, '-', encounter_id) "encounter_id",
	CONCAT(@partition, '-', visit_id) "visit_id",
	CONCAT(@partition, '-', prep_program_id) "prep_program_id",
	encounter_type,
	encounter_datetime,
	datetime_created,
	user_entered,
	provider,
	encounter_location,
	visit_location,
	site,
	pop_msm,
	pop_sex_worker,
	pop_transgender,
	pop_injection_drug_user,
	pop_serodiscordant_couple,
	pop_other,
	education_level,
	hiv_test_result,
	hiv_test_date,
	rpr_result,
	rpr_date,
	creatinine_clearance,
	prep_counseling,
	interested_in_prep,
	hep_b_surface_antigen,
	pregnancy_test_result,
	last_sex_date,
	acute_hiv_signs,
	start_prep,
	prep_consent,
	prep_start_date,
	followed_elsewhere_for_prep,
	estimated_program_start_date,
	referral_clinic,
	referral_date,
	pregnant,
	breastfeeding_status,
	wean_date,
	side_effect_abdominal_pain,
	side_effect_rash,
	side_effect_nausea,
	side_effect_vomiting,
	side_effect_diarrhea,
	side_effect_fatigue,
	side_effect_swollen_lymph_nodes,
	side_effect_fever,
	side_effect_other,
	side_effect_other_text,
	sti_urethral_discharge,
	sti_genital_ulcers,
	sti_abnormal_vaginal_bleeding,
	sti_foul_vaginal_discharge,
	sti_abdominal_pain,
	sti_scrotal_swelling,
	sti_inguinal_bubo,
	sti_other,
	sti_other_text,
	prep_drugs_prescribed,
	prep_drugs_discontinued,
	hiv_risk_counseling,
	condoms_provided,
	lubricant_provided,
	vmmc,
	other_prevention,
	prep_adherence,
	disposition,
	remarks,
	next_visit_date,
	index_asc,
	index_desc,
	index_program_asc,
	index_program_desc
FROM temp_prep_visit;
