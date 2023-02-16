SET sql_safe_updates = 0;
SET @pmtct_pregnacy_state = (SELECT program_workflow_state_id FROM program_workflow_state  WHERE retired = 0 AND concept_id = CONCEPT_FROM_MAPPING('PIH', 'PATIENT PREGNANT'));
SET @hiv_program_id = (SELECT PROGRAM('HIV'));
SET @initial_pmtct_encounter = ENCOUNTER_TYPE('584124b9-1f10-4757-ba09-91fc9075af92');
SET @followup_pmtct_encounter =  ENCOUNTER_TYPE('95e03e7d-9aeb-4a99-bd7a-94e8591ec2c5');

# pmtct status is pregnant and the patient is in the HIV program
# patient is active in the hiv program

DROP TEMPORARY TABLE IF EXISTS temp_pmtct_pregnancy;

CREATE TEMPORARY TABLE temp_pmtct_pregnancy (
patient_id                      INT,
zlemr                           VARCHAR(25),
start_date                      DATE, -- date when the pregnancy is reported
patient_program_id              INT,
patient_state_id                INT,
birthdate                       DATE,
age_at_pregnancy                DOUBLE,
age_at_pregnancy_cat            VARCHAR(10),
art_start_date1                 DATETIME,
art_start_date                  DATETIME,
art_start_date_followupform     DATETIME,
has_birthplan                   BIT,
is_active_on_art                BIT,
pmtct_enrollment_date           DATE,
transfer_status                 BIT,
cd4_count_assessed_obs          FLOAT,
cd4_count_assessed              DOUBLE,
health_facility                 VARCHAR(255),
post_test_counseling_date_latest_obs INT,
post_test_counseling_date 		DATETIME,
hiv_known_before_current_pregnancy_latest_obs INT,
hiv_known_before_current_pregnancy BIT,
index_asc                       INT,
index_desc                      INT
);

INSERT INTO temp_pmtct_pregnancy(patient_id, zlemr, start_date, patient_program_id, patient_state_id)
SELECT patient_id, ZLEMR(patient_id), ps.start_date, pp.patient_program_id, ps.patient_state_id FROM patient_program pp JOIN patient_state ps ON 
pp.patient_program_id =  ps.patient_program_id
AND pp.voided = 0 AND ps.voided = 0 
AND pp.program_id = @hiv_program_id
AND ps.state = @pmtct_pregnacy_state 
AND pp.date_completed IS NULL;

UPDATE temp_pmtct_pregnancy t SET pmtct_enrollment_date = PATIENTSTATESTARTDATE(t.patient_state_id);



-- age at date_started above
UPDATE temp_pmtct_pregnancy tp SET birthdate = (SELECT birthdate FROM current_name_address c WHERE c.person_id = tp.patient_id); 
UPDATE temp_pmtct_pregnancy SET age_at_pregnancy = TIMESTAMPDIFF(YEAR, birthdate, start_date);

-- art start date as the start date of orders with order reason of hiv
-- note this date can also be recorded on the pmtct followup form
UPDATE temp_pmtct_pregnancy tp
SET art_start_date1 = ORDERREASONSTARTDATE(tp.patient_id,'PIH','11197');

# art start date from the followup form
#
DROP TEMPORARY TABLE IF EXISTS temp_pmtct_followup_arv_date_encounter_obsid;
CREATE TEMPORARY TABLE temp_pmtct_followup_arv_date_encounter_obsid(
patient_id      INT,
encounter_id    INT,
arv_date_obs_id INT
);

INSERT INTO temp_pmtct_followup_arv_date_encounter_obsid (patient_id, encounter_id)
SELECT patient_id, encounter_id FROM encounter WHERE 
encounter_type = @followup_pmtct_encounter AND voided = 0 GROUP BY encounter_id;
SET @art_start_date_concept_id = CONCEPT_FROM_MAPPING('CIEL', '159599');
UPDATE temp_pmtct_followup_arv_date_encounter_obsid t SET arv_date_obs_id = (SELECT obs_id FROM obs o WHERE voided = 0 AND o.encounter_id = t.encounter_id AND concept_id = @art_start_date_concept_id);

DROP TEMPORARY TABLE IF EXISTS temp_pmtct_followup_encounter;
CREATE TEMPORARY TABLE temp_pmtct_followup_encounter(
patient_id INT,
arv_date_obs_id INT,
art_start_date_followupform DATETIME
);

INSERT INTO temp_pmtct_followup_encounter (patient_id, arv_date_obs_id)
SELECT patient_id, MAX(arv_date_obs_id) FROM temp_pmtct_followup_arv_date_encounter_obsid GROUP BY patient_id;

UPDATE temp_pmtct_followup_encounter t SET art_start_date_followupform = VALUE_DATETIME(t.arv_date_obs_id);

# earliest of 2 arv dates
UPDATE temp_pmtct_pregnancy t SET art_start_date_followupform = (SELECT art_start_date_followupform FROM temp_pmtct_followup_encounter tp WHERE t.patient_id = tp.patient_id);
# earliest arv date
UPDATE temp_pmtct_pregnancy t SET art_start_date = LEAST(art_start_date1, art_start_date_followupform);
# least only works when the 2 dates are not null, thus use coalesce too
UPDATE temp_pmtct_pregnancy t SET art_start_date = COALESCE(art_start_date1, art_start_date_followupform) WHERE t.art_start_date IS NULL;

# 15-19 years; 20-24 years; 25-29 years;  30-34 years; 35-39 years; 40-44 years; over 50 years; age unknown
UPDATE temp_pmtct_pregnancy SET age_at_pregnancy_cat =  CASE
												    WHEN age_at_pregnancy BETWEEN 15 AND 19 THEN "Group 1"
                                                    WHEN age_at_pregnancy BETWEEN 20 AND 24 THEN "Group 2"
                                                    WHEN age_at_pregnancy BETWEEN 25 AND 29 THEN "Group 3"
                                                    WHEN age_at_pregnancy BETWEEN 30 AND 34 THEN "Group 4"
                                                    WHEN age_at_pregnancy BETWEEN 35 AND 39 THEN "Group 5"
                                                    WHEN age_at_pregnancy BETWEEN 40 AND 44 THEN "Group 6"
                                                    WHEN age_at_pregnancy BETWEEN 45 AND 49 THEN "Group 7"
                                                    WHEN age_at_pregnancy > 50 THEN "Group 7"
                                                    WHEN age_at_pregnancy IS NULL THEN "Group 10"
                                                    END;
 
# latest delivery plan obs from pmtct intake/followup
# 1 = yes
# note that when the answer is "no", the output will be null
# note this concept is used on both section-obgyn-plan and section-hiv-plan
# latest delivery plan
UPDATE temp_pmtct_pregnancy t SET has_birthplan = ANSWEREVEREXISTS(t.patient_id, 'CIEL', '159758', 'CIEL', '1065', t.start_date);

# patient active on art
# whether patient has active order for order_reason = hiv
# patient can be on more than 1 art drug, thus we group by
# note: drug stop date and auto expire date should be null
# There is a possiblity that this could return a "yes" that has a art start date
# that is older than the program start date (DQ should be done here)
UPDATE temp_pmtct_pregnancy t SET is_active_on_art = (SELECT IF(concept_id IS NULL, NULL, 1) FROM orders o WHERE o.order_reason=CONCEPT_FROM_MAPPING('PIH','11197') AND voided = 0
AND auto_expire_date IS NULL AND date_stopped IS NULL AND t.patient_id = o.patient_id GROUP BY o.patient_id);

# transfer status
# whether transfer is chosen on pmtct intake
# intake is within the pmtct enrollment date
UPDATE temp_pmtct_pregnancy t SET transfer_status = ANSWEREVEREXISTS(t.patient_id, 'PIH', 'REFERRAL OR TRANSFER', 'PIH', 'TRANSFER', t.start_date);

## latest cd4 count
## should we include start date?
UPDATE temp_pmtct_pregnancy t SET cd4_count_assessed_obs = LATESTOBS(t.patient_id, CONCEPT_FROM_MAPPING('CIEL', '5497'), NULL);
UPDATE temp_pmtct_pregnancy t SET cd4_count_assessed = (SELECT value_numeric FROM obs WHERE obs_id = cd4_count_assessed_obs
AND voided = 0 AND t.patient_id = person_id);

## health_facility
## location of latest pmtct form (intake or followup)
## I think this is best represented on the pmtct_visit table
## 
DROP TEMPORARY TABLE IF EXISTS temp_pmtct_encounter;

CREATE TEMPORARY TABLE temp_pmtct_encounter(
patient_id      INT,
encounter_id    INT,
location_id     INT,
health_facility VARCHAR(255)
);

INSERT INTO temp_pmtct_encounter (patient_id, encounter_id)
SELECT patient_id, MAX(encounter_id) FROM encounter WHERE 
encounter_type IN (@initial_pmtct_encounter, @followup_pmtct_encounter) AND voided = 0 GROUP BY patient_id;

UPDATE temp_pmtct_encounter t SET location_id = (SELECT location_id FROM encounter e WHERE voided = 0 AND t.encounter_id = e.encounter_id);

UPDATE temp_pmtct_pregnancy t SET health_facility = (SELECT  LOCATION_NAME(location_id) FROM temp_pmtct_encounter tp WHERE tp.patient_id = t.patient_id);

## Post-Test Counseling Date
## note this approach may not account 
## for retrospective data entry in cases
## where there could be more than 1 intake form
SET @post_test_counseling_date_concept_id_in = CONCEPT_FROM_MAPPING('PIH', 11525);
UPDATE temp_pmtct_pregnancy t SET post_test_counseling_date_latest_obs = LATESTOBS(t.patient_id, @post_test_counseling_date_concept_id_in, t.start_date);
UPDATE temp_pmtct_pregnancy t SET post_test_counseling_date = VALUE_DATETIME(t.post_test_counseling_date_latest_obs);


SET @hiv_known_before_current_pregnancy_concept_id = CONCEPT_FROM_MAPPING('PIH', 13955);
UPDATE temp_pmtct_pregnancy t SET hiv_known_before_current_pregnancy_latest_obs = LATESTOBS(t.patient_id, @hiv_known_before_current_pregnancy_concept_id, t.start_date);
UPDATE temp_pmtct_pregnancy t SET hiv_known_before_current_pregnancy = VALUE_CODED_AS_BOOLEAN(hiv_known_before_current_pregnancy_latest_obs);

/*
## indexes
## This is based on the date when the pregnancy per woman is reported
-- index asc
DROP TEMPORARY TABLE IF EXISTS temp_pmtct_pregnancy_index_asc;
CREATE TEMPORARY TABLE temp_pmtct_pregnancy_index_asc
(
    SELECT
            patient_id,
            pmtct_enrollment_date,
            index_asc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_asc,
            patient_id,
            pmtct_enrollment_date,
            @u:= patient_id
      FROM temp_pmtct_pregnancy,
        (SELECT @r:= 1) AS r,
        (SELECT @u:= 0) AS u
      ORDER BY patient_id, pmtct_enrollment_date ASC
        ) index_ascending );

-- index desc
DROP TEMPORARY TABLE IF EXISTS temp_pmtct_pregnancy_index_desc;
CREATE TEMPORARY TABLE temp_pmtct_pregnancy_index_desc
(
    SELECT
            patient_id,
            pmtct_enrollment_date,
            index_desc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_desc,
            patient_id,
            pmtct_enrollment_date,
            @u:= patient_id
      FROM temp_pmtct_pregnancy,
        (SELECT @r:= 1) AS r,
        (SELECT @u:= 0) AS u
      ORDER BY patient_id, pmtct_enrollment_date DESC
        ) index_descending );

UPDATE temp_pmtct_pregnancy t SET index_asc = (SELECT index_asc FROM temp_pmtct_pregnancy_index_asc tp WHERE tp.patient_id = t.patient_id AND tp.pmtct_enrollment_date = t.pmtct_enrollment_date);
UPDATE temp_pmtct_pregnancy t SET index_desc = (SELECT index_desc FROM temp_pmtct_pregnancy_index_desc tp WHERE tp.patient_id = t.patient_id AND tp.pmtct_enrollment_date = t.pmtct_enrollment_date);
*/

## final query
SELECT 
    zlemr,
    start_date,
    pmtct_enrollment_date,
    health_facility,
    art_start_date,
    birthdate,
    age_at_pregnancy,
    age_at_pregnancy_cat,
    has_birthplan,
    is_active_on_art,
    transfer_status,
    cd4_count_assessed,
    DATE(post_test_counseling_date) post_test_counseling_date,
    hiv_known_before_current_pregnancy,
    index_asc,
    index_desc
FROM temp_pmtct_pregnancy;
