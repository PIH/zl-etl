set @partition = '${partitionNum}';

DROP TEMPORARY TABLE IF EXISTS temp_hiv_lab_tests;
CREATE TEMPORARY TABLE temp_hiv_lab_tests
(
obs_id          		INT,
obs_group_id    		INT,
person_id       		INT,
emr_id          		VARCHAR(25),
encounter_id    		INT,
test_date       		DATETIME,
test_date_specified     DATETIME,
result_date     		DATETIME,
result_date_received	DATETIME,
test_type   			VARCHAR(255),
test_result				VARCHAR(255),
date_created    		DATETIME
);

-- load test results for rapid tests, pcr tests
set @rapid_test = CONCEPT_FROM_MAPPING('CIEL', '163722');
set @pcr_test = CONCEPT_FROM_MAPPING('CIEL', '1030');
INSERT INTO temp_hiv_lab_tests(obs_id, obs_group_id, person_id, emr_id, encounter_id, test_date, test_type, test_result, date_created)
SELECT obs_id, obs_group_id, person_id, ZLEMR(person_id), encounter_id, obs_datetime, CONCEPT_NAME(concept_id, 'en'), CONCEPT_NAME(value_coded, 'en'), date_created
FROM obs WHERE voided  = 0 AND concept_id in (@rapid_test, @pcr_test);

-- depending on how the tests are modeled sometimes the test date is the obs_date of the test, sometimes it is explicitly captured with an obs as below
UPDATE temp_hiv_lab_tests t SET test_date_specified = OBS_VALUE_DATETIME(t.encounter_id, 'PIH', 'HIV TEST DATE');

-- depending on how the tests are modeled, sometimes we capture the test result date, and sometimes we capture the date the test results were received,  
-- which we can use as a proxy for the result date if that's all we have
UPDATE temp_hiv_lab_tests t SET result_date = OBS_VALUE_DATETIME(t.encounter_id, 'PIH', '10783'); 
UPDATE temp_hiv_lab_tests t SET result_date_received = OBS_VALUE_DATETIME(t.encounter_id, 'PIH', '11387');

DROP TEMPORARY TABLE IF EXISTS temp_hiv_lab_constructs;
CREATE TEMPORARY TABLE temp_hiv_lab_constructs
(
obs_id          		INT,
obs_group_id    		INT,
person_id       		INT,
emr_id          		VARCHAR(25),
encounter_id    		INT,
test_date       		DATETIME,
test_type   			VARCHAR(255),
test_result				VARCHAR(255),
date_created    		DATETIME
);

-- the following load test constructs from instances where tests are recorded using a construct
-- in cases we haven't captured above (e.g. rapid and pcr tests)
set @hiv_test_construct = CONCEPT_FROM_MAPPING('PIH', '11522');
INSERT INTO temp_hiv_lab_constructs(obs_id, obs_group_id, person_id, emr_id, encounter_id, test_type, date_created)
select obs_id, obs_id, person_id, ZLEMR(person_id), encounter_id, "HIV test", date_created
from obs o 
where voided  = 0 AND concept_id = @hiv_test_construct
and not EXISTS -- checks if this test has already been captured
	(select 1 from temp_hiv_lab_tests  t
	where t.obs_group_id = o.obs_id );

UPDATE temp_hiv_lab_constructs t SET test_date = obs_from_group_id_value_datetime(t.obs_group_id, 'PIH','1837'); 
UPDATE temp_hiv_lab_constructs t SET test_result = obs_from_group_id_value_coded_list(t.obs_group_id, 'PIH','2169',@locale);

-- loads these back into the main temp table
insert into temp_hiv_lab_tests(obs_id,obs_group_id,person_id,emr_id,encounter_id,test_date,test_type,test_result,date_created)
select 
obs_id,obs_group_id,person_id,emr_id,encounter_id,test_date,test_type,test_result,date_created
from temp_hiv_lab_constructs
;

DROP TEMPORARY TABLE IF EXISTS hiv_tests_final;
CREATE TEMPORARY TABLE hiv_tests_final (
	person_id					INT(11),
    emr_id                      VARCHAR(50),
    hivemr_v1_id                VARCHAR(50),
    encounter_id                INT(11),
    encounter_type				VARCHAR(255),
    specimen_collection_date    DATE,
    result_date                 DATE,
    test_type                   VARCHAR(255),
    test_result                 VARCHAR(255),
    date_created    			DATETIME,
    index_asc                   INT,
    index_desc                  INT
);

insert into hiv_tests_final(person_id, emr_id, encounter_id, specimen_collection_date, result_date, test_type, test_result, date_created)
select person_id ,emr_id, encounter_id, COALESCE(test_date, test_date_specified), COALESCE(result_date,result_date_received),test_type, test_result, date_created
from temp_hiv_lab_tests;

update hiv_tests_final set hivemr_v1_id  = patient_identifier(person_id, '139766e8-15f5-102d-96e4-000c29c2a5d7');   
update hiv_tests_final set encounter_type = encounter_type_name(encounter_id);
/*
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
            FROM hiv_tests_final,
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
            FROM hiv_tests_final,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY person_id, encounter_id DESC, specimen_collection_date DESC, date_created DESC, test_type DESC
        ) index_descending );
	
create index temp_hiv_lab_index_asc_encounter_id on temp_hiv_lab_index_asc(encounter_id);
create index temp_hiv_lab_index_asc_test_type on temp_hiv_lab_index_asc(test_type);
create index temp_hiv_lab_index_desc_encounter_id on temp_hiv_lab_index_desc(encounter_id);
create index temp_hiv_lab_index_desc_test_type on temp_hiv_lab_index_desc(test_type);	

UPDATE hiv_tests_final tbf JOIN temp_hiv_lab_index_asc tbia ON tbf.encounter_id = tbia.encounter_id AND tbf.test_type = tbia.test_type
SET tbf.index_asc = tbia.index_asc;

UPDATE hiv_tests_final tbf JOIN temp_hiv_lab_index_desc tbia ON tbf.encounter_id = tbia.encounter_id AND tbf.test_type = tbia.test_type
SET tbf.index_desc = tbia.index_desc;
*/
SELECT
    emr_id,
    hivemr_v1_id,
    concat(@partition,'-',encounter_id),
    encounter_type,
    specimen_collection_date,
    result_date,
    test_type,
    test_result,
    index_asc,
    index_desc
FROM hiv_tests_final 
ORDER BY person_id -- , index_asc, index_desc
;
