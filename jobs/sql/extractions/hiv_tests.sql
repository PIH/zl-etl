DROP TEMPORARY TABLE IF EXISTS temp_hiv_lab_tests;
CREATE TEMPORARY TABLE temp_hiv_lab_tests
(
obs_id          INT,
obs_group_id    INT,
person_id       INT,
emr_id          VARCHAR(25),
encounter_id    INT,
test_date       DATETIME,
test_date1      DATETIME,
result_date     DATETIME,
result_date1    DATETIME,
concept_name    VARCHAR(100),
value_coded     VARCHAR(100),
date_created    DATETIME
);

INSERT INTO temp_hiv_lab_tests(obs_id, obs_group_id, person_id, emr_id, encounter_id, test_date, concept_name, value_coded, date_created)
SELECT obs_id, obs_group_id, person_id, ZLEMR(person_id), encounter_id, obs_datetime, CONCEPT_NAME(concept_id, 'en'), CONCEPT_NAME(value_coded, 'en'), date_created
FROM obs WHERE voided  = 0 AND concept_id = CONCEPT_FROM_MAPPING('CIEL', '163722');

UPDATE temp_hiv_lab_tests t SET test_date1 = OBS_VALUE_DATETIME(t.encounter_id, 'PIH', 'HIV TEST DATE');
UPDATE temp_hiv_lab_tests t SET result_date = OBS_VALUE_DATETIME(t.encounter_id, 'PIH', '10783');
UPDATE temp_hiv_lab_tests t SET result_date1 = OBS_VALUE_DATETIME(t.encounter_id, 'PIH', 'DATE OF LABORATORY TEST');

DROP TEMPORARY TABLE IF EXISTS temp_hiv_lab_tests1;
CREATE TEMPORARY TABLE temp_hiv_lab_tests1
(
obs_id          INT,
obs_group_id    INT,
person_id       INT,
emr_id          VARCHAR(25),
encounter_id    INT,
test_date       DATETIME,
test_date1      DATETIME,
result_date     DATETIME,
result_date1    DATETIME,
concept_name    VARCHAR(100),
value_coded     VARCHAR(100),
date_created    DATETIME
);

INSERT INTO temp_hiv_lab_tests1(obs_id, obs_group_id, person_id, emr_id, encounter_id, test_date, concept_name, value_coded, date_created)
SELECT obs_id, obs_group_id, person_id, ZLEMR(person_id), encounter_id, obs_datetime, CONCEPT_NAME(concept_id, 'en'), CONCEPT_NAME(value_coded, 'en'), date_created
FROM obs WHERE voided  = 0 AND concept_id = CONCEPT_FROM_MAPPING('CIEL', '1030');

UPDATE temp_hiv_lab_tests1 t SET test_date1 = OBS_VALUE_DATETIME(t.encounter_id, 'PIH', 'HIV TEST DATE');
UPDATE temp_hiv_lab_tests1 t SET result_date = OBS_VALUE_DATETIME(t.encounter_id, 'PIH', '10783');
UPDATE temp_hiv_lab_tests1 t SET result_date1 = OBS_VALUE_DATETIME(t.encounter_id, 'PIH', 'DATE OF LABORATORY TEST');

## HIV test construct 
DROP TEMPORARY TABLE IF EXISTS temp_hiv_lab_tests2;
CREATE TEMPORARY TABLE temp_hiv_lab_tests2
(
obs_id          INT,
obs_group_id    INT,
person_id       INT,
emr_id          VARCHAR(25),
encounter_id    INT,
test_date       DATETIME,
test_date1      DATETIME,
result_date     DATETIME,
result_date1    DATETIME,
concept_name    VARCHAR(100),
value_coded     VARCHAR(100),
date_created    DATETIME
);

INSERT INTO temp_hiv_lab_tests2(obs_id, obs_group_id, person_id, emr_id, encounter_id, test_date, concept_name, value_coded, date_created)
SELECT obs_id, obs_group_id, person_id, ZLEMR(person_id), encounter_id, obs_datetime, CONCEPT_NAME(concept_id, 'en'), CONCEPT_NAME(value_coded, 'en'), date_created
FROM obs WHERE voided  = 0 AND concept_id = CONCEPT_FROM_MAPPING('PIH', '11522');
UPDATE temp_hiv_lab_tests2 t SET test_date1 = OBS_VALUE_DATETIME(t.encounter_id, 'PIH', 'HIV TEST DATE');
UPDATE temp_hiv_lab_tests2 t SET result_date = OBS_VALUE_DATETIME(t.encounter_id, 'PIH', '10783');
UPDATE temp_hiv_lab_tests2 t SET result_date1 = OBS_VALUE_DATETIME(t.encounter_id, 'PIH', 'DATE OF LABORATORY TEST');

## final results
DROP TEMPORARY TABLE IF EXISTS temp_lab_tests_final;
CREATE TEMPORARY TABLE temp_lab_tests_final
(
person_id INT, 
emr_id VARCHAR(25), 
encounter_id INT, 
specimen_collection_date DATETIME, 
result_date DATETIME, 
test_type VARCHAR(150), 
results VARCHAR(150), 
date_created DATETIME,
index_asc INT,
index_desc INT
);

INSERT INTO temp_lab_tests_final
(
person_id, 
emr_id, 
encounter_id, 
specimen_collection_date, 
result_date, 
test_type, 
results, 
date_created 
)
SELECT person_id, emr_id, encounter_id, COALESCE(test_date1, test_date) specimen_collection_date, 
COALESCE(result_date1, result_date) result_date, concept_name, value_coded, date_created FROM temp_hiv_lab_tests
UNION ALL
SELECT person_id, emr_id, encounter_id, COALESCE(test_date1, test_date) specimen_collection_date, 
COALESCE(result_date1, result_date) result_date, concept_name, value_coded, date_created FROM temp_hiv_lab_tests1 
UNION ALL
SELECT person_id, emr_id, encounter_id, COALESCE(test_date1, test_date) specimen_collection_date, 
COALESCE(result_date1, result_date) result_date, concept_name, value_coded,  date_created FROM temp_hiv_lab_tests2;

# indexes
# index_asc (ascending count of rows per patient, ordered by specimen date)
# index_desc (descending count of the above)

DROP TEMPORARY TABLE IF EXISTS temp_hiv_lab_index_asc;
CREATE TEMPORARY TABLE temp_hiv_lab_index_asc
(
			SELECT  
            person_id,
            encounter_id,
			specimen_collection_date,
            test_type,
            date_created,
			index_asc
FROM (SELECT  
             @r:= IF(@u = person_id, @r + 1,1) index_asc,
             person_id,
             encounter_id,
             specimen_collection_date,
             test_type,
             date_created,
			 @u:= person_id
            FROM temp_lab_tests_final,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY person_id, encounter_id ASC, specimen_collection_date ASC, date_created ASC, test_type ASC
        ) index_ascending );

DROP TEMPORARY TABLE IF EXISTS temp_hiv_lab_index_desc;
CREATE TEMPORARY TABLE temp_hiv_lab_index_desc
(
			SELECT  
            person_id,
            encounter_id,
			specimen_collection_date,
            test_type,
            date_created,
			index_desc
FROM (SELECT  
             @r:= IF(@u = person_id, @r + 1,1) index_desc,
             person_id,
             encounter_id,
             specimen_collection_date,
             test_type,
             date_created,
			 @u:= person_id
            FROM temp_lab_tests_final,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY person_id, encounter_id DESC, specimen_collection_date DESC, date_created DESC, test_type DESC
        ) index_descending );
	
create index temp_hiv_lab_index_asc_encounter_id on temp_hiv_lab_index_asc(encounter_id);
create index temp_hiv_lab_index_asc_test_type on temp_hiv_lab_index_asc(test_type);
create index temp_hiv_lab_index_desc_encounter_id on temp_hiv_lab_index_desc(encounter_id);
create index temp_hiv_lab_index_desc_test_type on temp_hiv_lab_index_desc(test_type);	

create index temp_hiv_lab_index_asc_encounter_id on temp_hiv_lab_index_asc(encounter_id);
create index temp_hiv_lab_index_asc_test_type on temp_hiv_lab_index_asc(test_type);
create index temp_hiv_lab_index_desc_encounter_id on temp_hiv_lab_index_desc(encounter_id);
create index temp_hiv_lab_index_desc_test_type on temp_hiv_lab_index_desc(test_type);

UPDATE temp_lab_tests_final tbf JOIN temp_hiv_lab_index_asc tbia ON tbf.encounter_id = tbia.encounter_id AND tbf.test_type = tbia.test_type
SET tbf.index_asc = tbia.index_asc;

UPDATE temp_lab_tests_final tbf JOIN temp_hiv_lab_index_desc tbia ON tbf.encounter_id = tbia.encounter_id AND tbf.test_type = tbia.test_type
SET tbf.index_desc = tbia.index_desc;

SELECT
    emr_id,
    patient_identifier(person_id, '139766e8-15f5-102d-96e4-000c29c2a5d7') hivemr_v1_id,
    encounter_id,
    DATE(specimen_collection_date),
    DATE(result_date),
    test_type,
    results,
    index_asc,
    index_desc
FROM temp_lab_tests_final ORDER BY person_id, index_asc, index_desc;
