SET sql_safe_updates = 0;
SET @partition = '${partitionNum}';

SET @obgyn_encounter = (SELECT encounter_type_id FROM encounter_type WHERE uuid = 'd83e98fd-dc7b-420f-aa3f-36f648b4483d');
SET @visit_diagnosis_concept_id = CONCEPT_FROM_MAPPING('PIH', 'Visit Diagnoses');
SET @diagnosis_order = CONCEPT_FROM_MAPPING('PIH', 'Diagnosis order');
SET @primary_diagnosis = CONCEPT_FROM_MAPPING('PIH', 'primary');
SET @secondary_diagnosis = CONCEPT_FROM_MAPPING('PIH', 'secondary');
SET @diagnosis = CONCEPT_FROM_MAPPING('PIH', 'DIAGNOSIS');

DROP TEMPORARY TABLE IF EXISTS temp_obgyn_visit;
CREATE TEMPORARY TABLE temp_obgyn_visit
(
 patient_id                       INT,          
 encounter_id                     INT,          
 emr_id                           VARCHAR(25),  
 visit_date                       DATE,         
 visit_site                       VARCHAR(100), 
 age_at_visit                     DOUBLE,       
 date_entered                     DATETIME,     
 user_entered                     VARCHAR(50),  
 consultation_type                VARCHAR       (30),  
 consultation_type_fp             VARCHAR(30),  
 pregnant                         BIT,          
 breastfeeding                    VARCHAR(5),   
 pregnant_lmp                     DATE,         
 pregnant_edd                     DATE,         
 next_visit_date                  DATE,         
 triage_level                     VARCHAR(11),  
 referral_type                    VARCHAR(255), 
 referral_type_other              VARCHAR(255), 
 implant_inserted                 BIT,          
 IUD_inserted                     BIT,          
 tubal_ligation_completed         BIT,          
 abortion_completed               BIT,          
 reason_for_visit                 VARCHAR(255), 
 visit_type                       VARCHAR(255), 
 referring_service                VARCHAR(255), 
 other_service                    VARCHAR(255), 
 triage_color                     VARCHAR(255), 
 bcg_1                            DATE,         
 polio_0                          DATE,         
 polio_1                          DATE,         
 polio_2                          DATE,         
 polio_3                          DATE,         
 polio_booster_1                  DATE,         
 polio_booster_2                  DATE,         
 pentavalent_1                    DATE,         
 pentavalent_2                    DATE,         
 pentavalent_3                    DATE,         
 rotavirus_1                      DATE,         
 rotavirus_2                      DATE,         
 mmr_1                            DATE,         
 tetanus_0                        DATE,         
 tetanus_1                        DATE,         
 tetanus_2                        DATE,         
 tetanus_3                        DATE,         
 tetanus_booster_1                DATE,         
 tetanus_booster_2                DATE,         
 gyno_exam                        BIT,          
 wh_exam                          BIT,          
 via                              VARCHAR(255), 
 pap_test_performed               BIT,          
 previous_history                 TEXT,         
 cervical_cancer_screening_date   DATE,         
 cervical_cancer_screening_result BIT,          
 risk_factors                     TEXT,         
 risk_factors_other               TEXT,         
 examining_doctor                 VARCHAR(100), 
 hiv_test_admin                   BIT,          
 hiv_test_date                    DATE,         
 hiv_test_result                  VARCHAR(255), 
 received_post_test_counseling    VARCHAR(255), 
 post_test_counseling_date        DATE,         
 medication_order                 TEXT,         
 primary_diagnosis                TEXT,         
 secondary_diagnosis              TEXT,         
 diagnosis_non_coded              TEXT,         
 procedures                       TEXT,         
 procedures_other                 TEXT,         
 family_planning_group            INT(11),      
 family_planning_use              VARCHAR(5),         
 family_planning_patient_type     VARCHAR(255),       
 family_planning_method           VARCHAR(255),       
 fp_counseling_received           VARCHAR(255), 
 fp_start_date                    DATETIME,     
 fp_end_date                      DATETIME,           
 implant_date                     DATETIME,     
 condoms_provided                 VARCHAR(5),
 number_of_condoms                INT,
 location_of_delivery             VARCHAR(255), 
 delivery_datetime                DATETIME,     
 chlamydia                        BIT,          
 gonorrhea                        BIT,          
 genital_herpes                   BIT,          
 hep_b                            BIT,          
 hpv                              BIT,          
 trichomoniasis                   BIT,          
 bacterial_vaginosis              BIT,          
 syphilis_treatment_status        varchar(255), 
 sti_treatment                    BIT,          
 other_sti                        text,         
 index_patient_asc                INT,          
 index_patient_desc               INT,          
 index_type_asc                   INT,          
 index_type_desc                  INT           
);


INSERT INTO temp_obgyn_visit(patient_id, encounter_id, visit_date, visit_site, date_entered)
SELECT DISTINCT e.patient_id, e.encounter_id, DATE(e.encounter_datetime), LOCATION_NAME(e.location_id), e.date_created 
FROM encounter e
INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 -- ensure that only rows with obs are included
WHERE e.voided = 0 AND encounter_type = @obgyn_encounter;

CREATE INDEX temp_obgyn_visit_patient_id ON temp_obgyn_visit (patient_id);
CREATE INDEX temp_obgyn_visit_encounter_id ON temp_obgyn_visit (encounter_id);

UPDATE temp_obgyn_visit t 
SET 
    examining_doctor = PROVIDER(t.encounter_id);

DELETE FROM temp_obgyn_visit 
WHERE
    patient_id IN (SELECT 
        a.person_id
    FROM
        person_attribute a
            JOIN
        person_attribute_type t ON a.person_attribute_type_id = t.person_attribute_type_id
            AND a.value = 'true'
            AND t.name = 'Test Patient');

DROP TEMPORARY TABLE IF EXISTS temp_obs;
CREATE TEMPORARY TABLE temp_obs 
SELECT o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.comments 
FROM obs o
INNER JOIN temp_obgyn_visit t ON t.encounter_id = o.encounter_id
WHERE o.voided = 0;

CREATE INDEX temp_obs_concept_id ON temp_obs(concept_id);
CREATE INDEX temp_obs_ei ON temp_obs(encounter_id);

           
           
UPDATE temp_obgyn_visit t 
SET 
    previous_history = (SELECT 
            GROUP_CONCAT(CONCEPT_NAME(value_coded, 'en')
                    SEPARATOR ' | ')
        FROM
            temp_obs o
        WHERE
           --  o.voided = 0
                t.encounter_id = o.encounter_id
                AND o.value_coded <> 1
                AND obs_group_id IN (SELECT 
                    obs_id
                FROM
                    obs
                WHERE
                    concept_id = CONCEPT_FROM_MAPPING('CIEL', '1633')));

UPDATE temp_obgyn_visit t JOIN temp_obs o ON o.encounter_id = t.encounter_id AND o.voided = 0 AND o.concept_id = CONCEPT_FROM_MAPPING('PIH','Type of HUM visit')
SET consultation_type = CONCEPT_NAME(value_coded, 'en');

UPDATE temp_obgyn_visit t JOIN temp_obs o ON o.encounter_id = t.encounter_id AND o.voided = 0 AND o.concept_id = CONCEPT_FROM_MAPPING('PIH','REASON FOR VISIT')
SET consultation_type_fp = CONCEPT_NAME(value_coded, 'en');

UPDATE temp_obgyn_visit t 
SET user_entered = ENCOUNTER_CREATOR(t.encounter_id);

# pregnancy
DROP TEMPORARY TABLE IF EXISTS temp_obgyn_pregnacy;
CREATE TEMPORARY TABLE IF NOT EXISTS temp_obgyn_pregnacy
(
encounter_id INT,
patient_id INT,
antenatal_visit VARCHAR(20),
estimated_delivery_date DATE
);

CREATE INDEX temp_obgyn_pregnacy_patient_id ON temp_obgyn_pregnacy (patient_id);
CREATE INDEX temp_obgyn_pregnacy_encounter_id ON temp_obgyn_pregnacy (encounter_id);

INSERT INTO temp_obgyn_pregnacy(encounter_id, patient_id)
SELECT encounter_id, patient_id FROM temp_obgyn_visit;

UPDATE temp_obgyn_pregnacy te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND concept_id = CONCEPT_FROM_MAPPING('PIH', '8879')
        AND value_coded = CONCEPT_FROM_MAPPING('PIH', 'ANC VISIT')
        AND o.voided = 0 
SET 
    antenatal_visit = 'Yes';-- yes
    

UPDATE temp_obgyn_pregnacy te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND concept_id = CONCEPT_FROM_MAPPING('PIH', 'ESTIMATED DATE OF CONFINEMENT')
        AND o.voided = 0 
SET 
    estimated_delivery_date = DATE(value_datetime);

UPDATE temp_obgyn_visit tv
        JOIN
    temp_obgyn_pregnacy t ON t.encounter_id = tv.encounter_id 
SET 
    pregnant = IF(antenatal_visit IS NULL, NULL, 1);

UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND concept_id = CONCEPT_FROM_MAPPING('PIH', 'METHOD OF FAMILY PLANNING')
        AND value_coded = CONCEPT_FROM_MAPPING('CIEL', '136163')
        AND o.voided = 0 
SET 
    breastfeeding = 'Yes';-- yes

UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND o.voided = 0
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'DATE OF LAST MENSTRUAL PERIOD') 
SET 
    pregnant_lmp = DATE(o.value_datetime);

UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND o.voided = 0
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'ESTIMATED DATE OF CONFINEMENT') 
SET 
    pregnant_edd = DATE(o.value_datetime);

UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND o.voided = 0
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'RETURN VISIT DATE') 
SET 
    next_visit_date = DATE(o.value_datetime);

UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND o.voided = 0
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'Triage color classification') 
SET 
    triage_level = CONCEPT_NAME(o.value_coded, 'en');

  /* 
UPDATE temp_obgyn_visit te 
SET 
    referral_type = OBS_VALUE_CODED_LIST(te.encounter_id,
            'PIH',
            'Type of referring service',
            'en');
*/           
UPDATE temp_obgyn_visit t 
INNER JOIN 
	(SELECT o.encounter_id, GROUP_CONCAT(DISTINCT  CONCEPT_NAME(o.value_coded,'en') SEPARATOR ' | ') AS ret
	FROM temp_obs o
	WHERE o.concept_id = CONCEPT_FROM_MAPPING('PIH','Type of referring service')
	GROUP BY o.encounter_id) i ON i.encounter_id = t.encounter_id
SET t.referral_type = i.ret;
           
UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND o.voided = 0
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'Type of referring service')
        AND value_coded = CONCEPT_FROM_MAPPING('PIH', 'OTHER') 
SET 
    referral_type_other = o.comments;

UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND concept_id = CONCEPT_FROM_MAPPING('PIH', 'METHOD OF FAMILY PLANNING')
        AND value_coded = CONCEPT_FROM_MAPPING('CIEL', '1873')
        AND o.voided = 0 
SET 
    implant_inserted = 1;-- yes

UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND concept_id = CONCEPT_FROM_MAPPING('PIH', 'METHOD OF FAMILY PLANNING')
        AND value_coded = CONCEPT_FROM_MAPPING('PIH', 'INTRAUTERINE DEVICE')
        AND o.voided = 0 
SET 
    IUD_inserted = 1;-- yes

UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND concept_id = CONCEPT_FROM_MAPPING('PIH', 'METHOD OF FAMILY PLANNING')
        AND value_coded = CONCEPT_FROM_MAPPING('PIH', 'TUBAL LIGATION')
        AND o.voided = 0 
SET 
    tubal_ligation_completed = 1; -- yes

#abortion_completed

### vaccinations
# polio
## START BUILDING VACCINATION TABLE
DROP TEMPORARY TABLE IF EXISTS temp_vaccinations;
CREATE TEMPORARY TABLE temp_vaccinations
(
    obs_group_id INT PRIMARY KEY,
    person_id INT,
    encounter_id INT,
    concept_id INT,
    vaccine      CHAR(38),
    dose_number  INT,
    vaccine_date DATE
);

CREATE INDEX temp_vaccinations_person_id ON temp_vaccinations (person_id);
CREATE INDEX temp_vaccinations_encounter_id ON temp_vaccinations (encounter_id);
CREATE INDEX temp_vaccinations_obs_group_id ON temp_vaccinations (obs_group_id);
CREATE INDEX temp_vaccinations_concept_id ON temp_vaccinations (concept_id);
CREATE INDEX temp_vaccinations_dose_number ON temp_vaccinations (dose_number);

INSERT INTO temp_vaccinations (obs_group_id, person_id, encounter_id, concept_id, vaccine)
SELECT o.obs_group_id, o.person_id, o.encounter_id, o.concept_id, a.uuid
FROM temp_obs o,
     concept c,
     concept a
WHERE o.concept_id = c.concept_id
  AND o.value_coded = a.concept_id
  AND c.uuid = '2dc6c690-a5fe-4cc4-97cc-32c70200a2eb' # Vaccinations
  AND o.voided = 0;

INSERT INTO temp_vaccinations (obs_group_id, dose_number)
SELECT o.obs_group_id, o.value_numeric
FROM temp_obs o,
     concept c
WHERE o.concept_id = c.concept_id
  AND c.uuid = 'ef6b45b4-525e-4d74-bf81-a65a41f3feb9' # Vaccination Sequence Number
  AND o.voided = 0
ON DUPLICATE KEY UPDATE dose_number = o.value_numeric;

INSERT INTO temp_vaccinations (obs_group_id, vaccine_date)
SELECT o.obs_group_id, DATE(o.value_datetime)
FROM temp_obs o,
     concept c
WHERE o.concept_id = c.concept_id
  AND c.uuid = '1410AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' # Vaccine Date
  AND o.voided = 0
ON DUPLICATE KEY UPDATE vaccine_date = o.value_datetime;

UPDATE temp_obgyn_visit te
        JOIN
    temp_vaccinations o ON te.encounter_id = o.encounter_id
        AND o.vaccine = '3cd4e004-26fe-102b-80cb-0017a47871b2' 
SET 
    te.bcg_1 = o.vaccine_date;


UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '3cd42c36-26fe-102b-80cb-0017a47871b2'
        AND v.dose_number = 0 
SET 
    e.polio_0 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '3cd42c36-26fe-102b-80cb-0017a47871b2'
        AND v.dose_number = 1 
SET 
    e.polio_1 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '3cd42c36-26fe-102b-80cb-0017a47871b2'
        AND v.dose_number = 2 
SET 
    e.polio_2 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '3cd42c36-26fe-102b-80cb-0017a47871b2'
        AND v.dose_number = 3 
SET 
    e.polio_3 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '3cd42c36-26fe-102b-80cb-0017a47871b2'
        AND v.dose_number = 11 
SET 
    e.polio_booster_1 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '3cd42c36-26fe-102b-80cb-0017a47871b2'
        AND v.dose_number = 12 
SET 
    e.polio_booster_2 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '1423AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        AND v.dose_number = 1 
SET 
    e.pentavalent_1 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '1423AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        AND v.dose_number = 2 
SET 
    e.pentavalent_2 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '1423AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        AND v.dose_number = 3 
SET 
    e.pentavalent_3 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '83531AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        AND v.dose_number = 1 
SET 
    e.rotavirus_1 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '83531AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        AND v.dose_number = 2 
SET 
    e.rotavirus_2 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '162586AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        AND v.dose_number = 1 
SET 
    e.mmr_1 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '3ccc6b7c-26fe-102b-80cb-0017a47871b2'
        AND v.dose_number = 0 
SET 
    e.tetanus_0 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '3ccc6b7c-26fe-102b-80cb-0017a47871b2'
        AND v.dose_number = 1 
SET 
    e.tetanus_1 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '3ccc6b7c-26fe-102b-80cb-0017a47871b2'
        AND v.dose_number = 2 
SET 
    e.tetanus_2 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '3ccc6b7c-26fe-102b-80cb-0017a47871b2'
        AND v.dose_number = 3 
SET 
    e.tetanus_3 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '3ccc6b7c-26fe-102b-80cb-0017a47871b2'
        AND v.dose_number = 11 
SET 
    e.tetanus_booster_1 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_vaccinations v ON e.encounter_id = v.encounter_id
        AND v.vaccine = '3ccc6b7c-26fe-102b-80cb-0017a47871b2'
        AND v.dose_number = 12 
SET 
    e.tetanus_booster_2 = v.vaccine_date;

UPDATE temp_obgyn_visit e
        JOIN
    temp_obs o ON e.encounter_id = o.encounter_id
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '13229')
        AND o.voided = 0 
SET 
    gyno_exam = 1;

UPDATE temp_obgyn_visit e
        JOIN
    temp_obs o ON e.encounter_id = o.encounter_id
        AND o.concept_id IN (CONCEPT_FROM_MAPPING('CIEL', '1439') , CONCEPT_FROM_MAPPING('CIEL', '160090'),
        CONCEPT_FROM_MAPPING('CIEL', '163749'),
        CONCEPT_FROM_MAPPING('CIEL', '1440'),
        CONCEPT_FROM_MAPPING('CIEL', '163750'),
        CONCEPT_FROM_MAPPING('CIEL', '160968'))
        AND o.concept_id IS NOT NULL
        AND o.voided = 0 
SET 
    wh_exam = 1;

UPDATE temp_obgyn_visit te
        JOIN temp_obs o ON te.encounter_id = o.encounter_id
        AND concept_id = CONCEPT_FROM_MAPPING('PIH', '11319')
        AND value_coded = CONCEPT_FROM_MAPPING('PIH', '1267')
        AND o.voided = 0 
SET 
    pap_test_performed = 1;
   
UPDATE temp_obgyn_visit te
        JOIN temp_obs o ON te.encounter_id = o.encounter_id
        AND concept_id = CONCEPT_FROM_MAPPING('PIH', '9759')
        AND o.voided = 0 
SET via = CONCEPT_NAME(o.value_coded, @locale);
   
UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND o.voided = 0
        AND o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '165429') 
SET 
    cervical_cancer_screening_date = DATE(o.value_datetime);

UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND concept_id = CONCEPT_FROM_MAPPING('CIEL', '163560')
        AND value_coded = CONCEPT_FROM_MAPPING('CIEL', '151185')
        AND o.voided = 0 
SET 
    cervical_cancer_screening_result = 1;

UPDATE temp_obgyn_visit t 
SET 
    risk_factors = (SELECT 
            GROUP_CONCAT(CONCEPT_NAME(value_coded, 'en')
                    SEPARATOR ' | ')
        FROM
            temp_obs o
        WHERE
            o.voided = 0
                AND t.encounter_id = o.encounter_id
                AND o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '160079'));

UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND o.voided = 0
        AND o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '160079')
        AND value_coded = CONCEPT_FROM_MAPPING('PIH', 'OTHER') 
SET 
    risk_factors_other = o.comments;

UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND o.voided = 0
        AND o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '164181') 
SET 
    visit_type = CONCEPT_NAME(value_coded, 'en');

UPDATE temp_obgyn_visit te 
SET 
    age_at_visit = AGE_AT_ENC(te.patient_id, te.encounter_id);
/*
### indexes
-- index ascending
DROP TEMPORARY TABLE IF EXISTS temp_mch_visit_index_asc;
CREATE TEMPORARY TABLE temp_mch_visit_index_asc
(
		SELECT
			patient_id,
			encounter_id,
			visit_date,
			index_asc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_asc,
            encounter_id,
            patient_id,
            visit_date,
            @u:= patient_id
      FROM temp_obgyn_visit,
            (SELECT @r:= 1) AS r,
            (SELECT @u:= 0) AS u
      ORDER BY patient_id, visit_date ASC, encounter_id ASC
        ) index_ascending );

-- index descending
DROP TEMPORARY TABLE IF EXISTS temp_mch_visit_index_desc;
CREATE TEMPORARY TABLE temp_mch_visit_index_desc
(
	    SELECT
	        patient_id,
	        encounter_id,
	        visit_date,
	        index_desc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_desc,
            encounter_id,
            patient_id,
            visit_date,
            @u:= patient_id
        FROM temp_obgyn_visit,
                (SELECT @r:= 1) AS r,
                (SELECT @u:= 0) AS u
        ORDER BY patient_id, visit_date DESC, encounter_id DESC
        ) index_descending );

CREATE INDEX mch_visit_index_asc ON temp_mch_visit_index_asc(patient_id, index_asc, encounter_id);
CREATE INDEX mch_visit_index_desc ON temp_mch_visit_index_desc(patient_id, index_desc, encounter_id);

UPDATE temp_obgyn_visit o
        JOIN
    temp_mch_visit_index_asc top ON o.encounter_id = top.encounter_id 
SET 
    o.index_asc = top.index_asc;

UPDATE temp_obgyn_visit o
        JOIN
    temp_mch_visit_index_desc top ON o.encounter_id = top.encounter_id 
SET 
    o.index_desc = top.index_desc;
*/

UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND o.voided = 0
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'HIV test done') 
SET 
    hiv_test_admin = value_coded;

-- UPDATE temp_obgyn_visit SET hiv_test_date = obs_value_datetime(encounter_id, 'CIEL', '164400');
UPDATE temp_obgyn_visit t 
INNER JOIN temp_obs o ON o.encounter_id = t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '164400')
SET t.hiv_test_date = o.value_datetime
;


-- UPDATE temp_obgyn_visit SET hiv_test_result = obs_value_coded_list(encounter_id, 'CIEL', '159427', 'en');
UPDATE temp_obgyn_visit t 
INNER JOIN 
	(SELECT o.encounter_id, GROUP_CONCAT(DISTINCT  CONCEPT_NAME(o.value_coded,'en') SEPARATOR ' | ') AS ret
	FROM temp_obs o
	WHERE o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '159427')
	GROUP BY o.encounter_id) i ON i.encounter_id = t.encounter_id
SET t.hiv_test_result = i.ret;

-- UPDATE temp_obgyn_visit SET received_post_test_counseling = obs_value_coded_list(encounter_id, 'CIEL', '159382', 'en');
UPDATE temp_obgyn_visit t 
INNER JOIN 
	(SELECT o.encounter_id, GROUP_CONCAT(DISTINCT  CONCEPT_NAME(o.value_coded,'en') SEPARATOR ' | ') AS ret
	FROM temp_obs o
	WHERE o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '159382')
	GROUP BY o.encounter_id) i ON i.encounter_id = t.encounter_id
SET t.received_post_test_counseling = i.ret;

-- UPDATE temp_obgyn_visit SET post_test_counseling_date = obs_value_datetime(encounter_id, 'PIH', '11525');
UPDATE temp_obgyn_visit t 
INNER JOIN temp_obs o ON o.encounter_id = t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '11525')
SET t.post_test_counseling_date = o.value_datetime
;

UPDATE temp_obgyn_visit te 
SET 
    medication_order = (SELECT 
            (GROUP_CONCAT(CONCEPT_NAME(concept_id, 'en')
                    SEPARATOR ' | '))
        FROM
            orders o
        WHERE
            te.encounter_id = o.encounter_id
                AND te.patient_id = o.patient_id
                AND o.voided = 0);

-- all mch diagnosis
DROP TEMPORARY TABLE IF EXISTS temp_diagnosis_obs_id;
CREATE TEMPORARY TABLE temp_diagnosis_obs_id
(
encounter_id INT,
obs_id INT
);

CREATE INDEX temp_diagnosis_obs_id_encounter_id ON temp_diagnosis_obs_id (encounter_id);
CREATE INDEX temp_diagnosis_obs_id_obs_id ON temp_diagnosis_obs_id (obs_id);

INSERT INTO temp_diagnosis_obs_id(encounter_id, obs_id)
SELECT
                        encounter_id, obs_id
                    FROM
                        temp_obs
                    WHERE
                        concept_id = @visit_diagnosis_concept_id
AND voided = 0
                    AND encounter_id IN (SELECT encounter_id temp_obgyn_visit);

-- return only mch primary diagnosis
DROP TEMPORARY TABLE IF EXISTS temp_primary_diagnosis_obs_group_id;
CREATE TEMPORARY TABLE temp_primary_diagnosis_obs_group_id
(
encounter_id INT,
obs_id INT,
obs_group_id INT
);

CREATE INDEX temp_primary_diagnosis_obs_group_id_encounter_id ON temp_primary_diagnosis_obs_group_id (encounter_id);
CREATE INDEX temp_primary_diagnosis_obs_group_id_obs_id ON temp_primary_diagnosis_obs_group_id (obs_id);
CREATE INDEX temp_primary_diagnosis_obs_group_id_obs_group_id ON temp_primary_diagnosis_obs_group_id (obs_group_id);

INSERT INTO temp_primary_diagnosis_obs_group_id(encounter_id, obs_id, obs_group_id)
SELECT
encounter_id, obs_id, obs_group_id
                    FROM
                        temp_obs
                    WHERE
                        concept_id = @diagnosis_order
                            AND voided = 0
                            AND value_coded = @primary_diagnosis
                            AND encounter_id IN (SELECT encounter_id FROM temp_diagnosis_obs_id);

DROP TEMPORARY TABLE IF EXISTS temp_primary_diagnosis_stage;
CREATE TEMPORARY TABLE temp_primary_diagnosis_stage
(
encounter_id INT,
value_coded INT,
diagnosis VARCHAR(255)
);

CREATE INDEX temp_primary_diagnosis_stage_encounter_id ON temp_primary_diagnosis_stage (encounter_id);
CREATE INDEX temp_primary_diagnosis_stage_value_coded ON temp_primary_diagnosis_stage (value_coded);

INSERT INTO temp_primary_diagnosis_stage (encounter_id, value_coded)
SELECT
encounter_id, value_coded
                    FROM
                        temp_obs
                    WHERE
                        concept_id = @diagnosis
                            AND voided = 0
                            AND obs_group_id IN (SELECT obs_group_id FROM temp_primary_diagnosis_obs_group_id);

DROP TEMPORARY TABLE IF EXISTS temp_primary_diagnosis_stage_names;
CREATE TEMPORARY TABLE temp_primary_diagnosis_stage_names
AS SELECT encounter_id, CONCEPT_NAME(value_coded, 'en') primary_diagnosis FROM temp_primary_diagnosis_stage;

DROP TEMPORARY TABLE IF EXISTS temp_primary_diagnosis;
CREATE TEMPORARY TABLE temp_primary_diagnosis
AS
SELECT
encounter_id, GROUP_CONCAT(t.primary_diagnosis SEPARATOR ' | ') primary_diagnosis
                    FROM
                        temp_primary_diagnosis_stage_names t
                    GROUP BY t.encounter_id;

UPDATE temp_obgyn_visit t JOIN temp_primary_diagnosis tp ON tp.encounter_id = t.encounter_id
SET t.primary_diagnosis = tp.primary_diagnosis;

-- return only mch secondary diagnosis
DROP TEMPORARY TABLE IF EXISTS temp_secondary_diagnosis_obs_group_id;
CREATE TEMPORARY TABLE temp_secondary_diagnosis_obs_group_id
(
encounter_id INT,
obs_id INT,
obs_group_id INT
);

CREATE INDEX temp_secondary_diagnosis_obs_group_id_encounter_id ON temp_secondary_diagnosis_obs_group_id (encounter_id);
CREATE INDEX temp_secondary_diagnosis_obs_group_id_obs_id ON temp_secondary_diagnosis_obs_group_id (obs_id);
CREATE INDEX temp_secondary_diagnosis_obs_group_id_obs_group_id ON temp_secondary_diagnosis_obs_group_id (obs_group_id);

INSERT INTO temp_secondary_diagnosis_obs_group_id(encounter_id, obs_id, obs_group_id)
SELECT
encounter_id, obs_id, obs_group_id
                    FROM
                        temp_obs
                    WHERE
                        concept_id = @diagnosis_order
                            AND voided = 0
                            AND value_coded = @secondary_diagnosis
                            AND encounter_id IN (SELECT encounter_id FROM temp_diagnosis_obs_id);

DROP TEMPORARY TABLE IF EXISTS temp_secondary_diagnosis_stage;
CREATE TEMPORARY TABLE temp_secondary_diagnosis_stage
(
encounter_id INT,
value_coded INT,
diagnosis VARCHAR(255)
);

CREATE INDEX temp_secondary_diagnosis_stage_encounter_id ON temp_secondary_diagnosis_stage (encounter_id);
CREATE INDEX temp_secondary_diagnosis_stage_value_coded ON temp_secondary_diagnosis_stage (value_coded);

INSERT INTO temp_secondary_diagnosis_stage (encounter_id, value_coded)
SELECT
encounter_id, value_coded
                    FROM
                        temp_obs
                    WHERE
                        concept_id = @diagnosis
                            AND voided = 0
                            AND obs_group_id IN (SELECT obs_group_id FROM temp_secondary_diagnosis_obs_group_id);

DROP TEMPORARY TABLE IF EXISTS temp_secondary_diagnosis_stage_names;
CREATE TEMPORARY TABLE temp_secondary_diagnosis_stage_names
AS SELECT encounter_id, CONCEPT_NAME(value_coded, 'en') secondary_diagnosis FROM temp_secondary_diagnosis_stage;

DROP TEMPORARY TABLE IF EXISTS temp_secondary_diagnosis;
CREATE TEMPORARY TABLE temp_secondary_diagnosis
AS
SELECT
encounter_id, GROUP_CONCAT(t.secondary_diagnosis SEPARATOR ' | ') secondary_diagnosis
                    FROM
                        temp_secondary_diagnosis_stage_names t
                    GROUP BY t.encounter_id;

UPDATE temp_obgyn_visit t JOIN temp_secondary_diagnosis tp ON tp.encounter_id = t.encounter_id
SET t.secondary_diagnosis = tp.secondary_diagnosis;

-- non coded diagnosis    
UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND o.voided = 0
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'Diagnosis or problem, non-coded') 
SET 
    diagnosis_non_coded = value_text;

-- UPDATE temp_obgyn_visit te 
-- SET 
--    procedures = OBS_VALUE_CODED_LIST(te.encounter_id, 'CIEL', '1651', 'en');
UPDATE temp_obgyn_visit t 
INNER JOIN 
	(SELECT o.encounter_id, GROUP_CONCAT(DISTINCT  CONCEPT_NAME(o.value_coded,'en') SEPARATOR ' | ') AS ret
	FROM temp_obs o
	WHERE o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '1651')
	GROUP BY o.encounter_id) i ON i.encounter_id = t.encounter_id
SET t.procedures = i.ret;

-- UPDATE temp_obgyn_visit te 
-- SET 
--    procedures_other = OBS_VALUE_TEXT(te.encounter_id, 'CIEL', '165264');
UPDATE temp_obgyn_visit t 
INNER JOIN temp_obs o ON o.encounter_id = t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '165264')
SET t.procedures_other = o.value_text
;   

-- UPDATE temp_obgyn_visit te 
-- SET 
--     family_planning_use = OBS_VALUE_CODED_LIST(te.encounter_id, 'CIEL', '965', 'en');
UPDATE temp_obgyn_visit t 
INNER JOIN 
	(SELECT o.encounter_id, GROUP_CONCAT(DISTINCT  CONCEPT_NAME(o.value_coded,'en') SEPARATOR ' | ') AS ret
	FROM temp_obs o
	WHERE o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '965')
	GROUP BY o.encounter_id) i ON i.encounter_id = t.encounter_id
SET t.family_planning_use = i.ret;
    
UPDATE temp_obgyn_visit t 
INNER JOIN temp_obs o ON o.encounter_id =  t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'Family planning construct')
SET t.family_planning_group = o.obs_id;


UPDATE temp_obgyn_visit te
        JOIN
    temp_obs o ON te.encounter_id = o.encounter_id
        AND o.voided = 0
        AND concept_id = CONCEPT_FROM_MAPPING('PIH', 'METHOD OF FAMILY PLANNING')
        AND o.obs_group_id = te.family_planning_group
SET 
    family_planning_method = CONCEPT_NAME(o.value_coded, 'en');
 
UPDATE temp_obgyn_visit t 
INNER JOIN temp_obs o ON o.encounter_id =  t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '14321')
SET t.family_planning_patient_type = CONCEPT_NAME(o.value_coded,'en');

UPDATE temp_obgyn_visit t 
INNER JOIN temp_obs o ON o.encounter_id =  t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '165309')
SET t.fp_counseling_received = CONCEPT_NAME(o.value_coded,'en');

UPDATE temp_obgyn_visit t 
INNER JOIN temp_obs o ON o.encounter_id =  t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '13006')
SET t.condoms_provided = CONCEPT_NAME(o.value_coded,'en');

UPDATE temp_obgyn_visit t 
INNER JOIN temp_obs o ON o.encounter_id =  t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '20151')
SET t.number_of_condoms = o.value_numeric;

UPDATE temp_obgyn_visit t 
INNER JOIN temp_obs o ON o.encounter_id =  t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '11348')
SET t.location_of_delivery = CONCEPT_NAME(o.value_coded,'en');

UPDATE temp_obgyn_visit t
INNER JOIN temp_obs o ON o.encounter_id =  t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '5599')
SET t.delivery_datetime = o.value_datetime;

UPDATE temp_obgyn_visit t 
INNER JOIN temp_obs o ON o.encounter_id =  t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '11466')
SET t.fp_start_date = o.value_datetime;

UPDATE temp_obgyn_visit t 
INNER JOIN temp_obs o ON o.encounter_id =  t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '11465')
SET t.fp_end_date = o.value_datetime;

UPDATE temp_obgyn_visit t 
INNER JOIN temp_obs o ON o.encounter_id =  t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '3203')
SET t.implant_date = o.value_datetime;

## Suspected STD
# Chlamydia
UPDATE temp_obgyn_visit t SET chlamydia = (SELECT 1 FROM obs o WHERE t.encounter_id = o.encounter_id AND o.voided = 0 AND concept_id = CONCEPT_FROM_MAPPING('PIH', '14365') AND value_coded
= CONCEPT_FROM_MAPPING('CIEL', '120733'));

# Gonorrhea
UPDATE temp_obgyn_visit t SET gonorrhea = (SELECT 1 FROM obs o WHERE t.encounter_id = o.encounter_id AND o.voided = 0 AND concept_id = CONCEPT_FROM_MAPPING('PIH', '14365') AND value_coded
= CONCEPT_FROM_MAPPING('CIEL', '117767'));

# Genital herpes
UPDATE temp_obgyn_visit t SET genital_herpes = (SELECT 1 FROM obs o WHERE t.encounter_id = o.encounter_id AND o.voided = 0 AND concept_id = CONCEPT_FROM_MAPPING('PIH', '14365') AND value_coded
= CONCEPT_FROM_MAPPING('CIEL', '117829'));

# Hepatitis B
UPDATE temp_obgyn_visit t SET hep_b = (SELECT 1 FROM obs o WHERE t.encounter_id = o.encounter_id AND o.voided = 0 AND concept_id = CONCEPT_FROM_MAPPING('PIH', '14365') AND value_coded
= CONCEPT_FROM_MAPPING('CIEL', '111759'));

# Human papillomavirus
UPDATE temp_obgyn_visit t SET hpv = (SELECT 1 FROM obs o WHERE t.encounter_id = o.encounter_id AND o.voided = 0 AND concept_id = CONCEPT_FROM_MAPPING('PIH', '14365') AND value_coded
= CONCEPT_FROM_MAPPING('CIEL', '1213'));

# Trichomoniasis
UPDATE temp_obgyn_visit t SET trichomoniasis = (SELECT 1 FROM obs o WHERE t.encounter_id = o.encounter_id AND o.voided = 0 AND concept_id = CONCEPT_FROM_MAPPING('PIH', '14365') AND value_coded
= CONCEPT_FROM_MAPPING('CIEL', '117146'));

# Bacterial vaginosis
UPDATE temp_obgyn_visit t SET bacterial_vaginosis = (SELECT 1 FROM obs o WHERE t.encounter_id = o.encounter_id AND o.voided = 0 AND concept_id = CONCEPT_FROM_MAPPING('PIH', '14365') AND value_coded
= CONCEPT_FROM_MAPPING('CIEL', '148002'));

# STI treatment
UPDATE temp_obgyn_visit t SET sti_treatment = (SELECT 1 FROM obs o WHERE t.encounter_id = o.encounter_id AND o.voided = 0 AND concept_id = CONCEPT_FROM_MAPPING('CIEL', '160742') AND value_coded
= CONCEPT_FROM_MAPPING('CIEL', '167125'));

# Syphilis treatment status
set @completed = concept_from_mapping('PIH','1267');
UPDATE temp_obgyn_visit t 
INNER JOIN temp_obs o ON o.encounter_id =  t.encounter_id AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '13024')
SET t.syphilis_treatment_status = if(o.value_coded = @completed,'Stopped' ,CONCEPT_NAME(o.value_coded,'en'));

# other STIs
set @sti_set = concept_from_mapping('PIH','13076');
drop temporary table if exists sti_dxs;
create temporary table sti_dxs
select answer_concept from concept_answer ca
where ca.concept_id = @sti_set;

create index sti_dxs_ci on sti_dxs(answer_concept);

update temp_obgyn_visit t
INNER JOIN (select encounter_id, group_concat(concept_name(value_coded, @locale)  SEPARATOR ' | ') 'stis' 
	from temp_obs o 
	inner join sti_dxs s on s.answer_concept = o.value_coded
	where o.concept_id = @diagnosis
group by encounter_id) o on o.encounter_id = t.encounter_id
set t.other_sti = o.stis;		

# final query
SELECT
    ZLEMR(patient_id),
    CONCAT(@partition,'-',encounter_id),
    visit_date,
    visit_site,
    visit_type,
    consultation_type,
    consultation_type_fp,
    age_at_visit,
    date_entered,
    user_entered,
    examining_doctor,
    pregnant,
    breastfeeding,
    pregnant_lmp,
    pregnant_edd,
    next_visit_date,
    triage_level,
    referral_type,
    referral_type_other,
    implant_inserted,
    IUD_inserted,
    tubal_ligation_completed,
    abortion_completed,
    bcg_1,
    polio_0,
    polio_1,
    polio_2,
    polio_3,
    polio_booster_1,
    polio_booster_2,
    pentavalent_1,
    pentavalent_2,
    pentavalent_3,
    rotavirus_1,
    rotavirus_2,
    mmr_1,
    tetanus_0,
    tetanus_1,
    tetanus_2,
    tetanus_3,
    tetanus_booster_1,
    tetanus_booster_2,
    gyno_exam,
    wh_exam,
    pap_test_performed,
    via,
    previous_history,
    hiv_test_admin,
    hiv_test_date,
    hiv_test_result,
    received_post_test_counseling,
    post_test_counseling_date,
    cervical_cancer_screening_date,
    cervical_cancer_screening_result,
    primary_diagnosis,
    secondary_diagnosis,
    diagnosis_non_coded,
    procedures,
    procedures_other,
    medication_order,
    IF(family_planning_use LIKE '%Yes%', 1, NULL),
    family_planning_patient_type,
    family_planning_method,
    IF(fp_counseling_received LIKE '%Family planning counseling%', 1, NULL),
    fp_start_date,
    fp_end_date,
    implant_date,
    condoms_provided,
    number_of_condoms,
    location_of_delivery,
    delivery_datetime,
    risk_factors,
    sti_treatment,
    syphilis_treatment_status,
    other_sti,
    chlamydia,
    gonorrhea,
    genital_herpes,
    hep_b,
    hpv,
    trichomoniasis,
    bacterial_vaginosis,
    index_patient_asc,
    index_patient_desc,
    index_type_asc,
    index_type_desc
FROM
    temp_obgyn_visit
ORDER BY patient_id;
