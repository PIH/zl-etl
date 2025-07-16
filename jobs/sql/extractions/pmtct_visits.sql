SET sqL_safe_updates = 0;
set @partition = '${partitionNum}';

SET @initial_pmtct_encounter = ENCOUNTER_TYPE('584124b9-1f10-4757-ba09-91fc9075af92');
SET @followup_pmtct_encounter =  ENCOUNTER_TYPE('95e03e7d-9aeb-4a99-bd7a-94e8591ec2c5');
set @hiv_program = (select program_id from program WHERE uuid = 'b1cb1fc1-5190-4f7a-af08-48870975dafc');

-- drop and create temp pmct visit table
DROP TEMPORARY TABLE IF EXISTS temp_pmtct_visit;
CREATE TEMPORARY TABLE temp_pmtct_visit (
 visit_id                INT,          
 encounter_id            INT,          
 patient_id              INT,    
 hiv_program_id        INT(11),
 emr_id                  VARCHAR(25),  
 visit_date              DATE,         
 health_facility         VARCHAR(100), 
 date_entered            DATETIME,     
 user_entered            VARCHAR(50),  
 hiv_test_date           DATE,         
 expected_delivery_date  DATE,         
 tb_screening_date       DATE,         
 has_provided_contact    BIT,          
 breastfeeding_status    VARCHAR(255), 
 last_breastfeeding_date DATETIME,     
 next_visit_date         DATETIME,     
 delivery                BOOLEAN,      
 delivery_datetime       DATETIME,  
 index_asc               INT,          
 index_desc              INT,   	
 index_program_asc       INT,          
 index_program_desc      INT           
);

INSERT INTO temp_pmtct_visit (visit_id, encounter_id, patient_id, emr_id, date_entered, user_entered)
SELECT visit_id, encounter_id, patient_id, ZLEMR(patient_id), date_created, USERNAME(creator) FROM encounter WHERE encounter_type IN (@initial_pmtct_encounter, @followup_pmtct_encounter) AND voided = 0;

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.comments,o.date_created, o.obs_datetime  
from obs o
inner join temp_pmtct_visit t on t.encounter_id = o.encounter_id
where o.voided = 0;

create index temp_obs_concept_id on temp_obs(concept_id);
create index temp_obs_ei on temp_obs(encounter_id);

-- visit date
UPDATE temp_pmtct_visit t SET t.visit_date = VISIT_DATE(t.encounter_id);

-- facility where healthcare is received
 UPDATE temp_pmtct_visit t SET t.health_facility = ENCOUNTER_LOCATION_NAME(t.encounter_id);
 
-- expected delivery date
UPDATE  temp_pmtct_visit t SET expected_delivery_date = obs_value_datetime_from_temp(t.encounter_id, 'PIH', '5596');

-- Hiv test date
UPDATE  temp_pmtct_visit t SET hiv_test_date = obs_value_datetime_from_temp(t.encounter_id, 'PIH', 'HIV TEST DATE');

-- contacts
SET @relationship = CONCEPT_FROM_MAPPING('PIH', '13265');
SET @first_name = CONCEPT_FROM_MAPPING('PIH', 'FIRST NAME');
SET @last_name = CONCEPT_FROM_MAPPING('PIH', 'LAST NAME');
SET @phone = CONCEPT_FROM_MAPPING('PIH', 'TELEPHONE NUMBER OF CONTACT');
UPDATE temp_pmtct_visit t SET has_provided_contact = (SELECT 1 FROM temp_obs o WHERE voided = 0 AND o.encounter_id = t.encounter_id AND 
o.concept_id IN (@relationship, @first_name, @last_name, @phone) GROUP BY o.encounter_id); 

-- tb screening date
DROP TEMPORARY TABLE IF EXISTS temp_pmtct_tb_visits;
CREATE TEMPORARY TABLE temp_pmtct_tb_visits
(
patient_id INT(11),
encounter_id INT(11),
obs_date DATETIME,
cough_result_concept INT(11),
fever_result_concept INT(11),
weight_loss_result_concept INT(11),
tb_contact_result_concept INT(11),
lymph_pain_result_concept INT(11),
bloody_cough_result_concept INT(11),
dyspnea_result_concept INT(11),
chest_pain_result_concept INT(11),
tb_screening_date DATETIME
);

INSERT INTO temp_pmtct_tb_visits (patient_id, encounter_id)
SELECT patient_id, encounter_id FROM temp_pmtct_visit;

SET @present = CONCEPT_FROM_MAPPING('PIH','11563');
SET @fever_result_concept_id = CONCEPT_FROM_MAPPING('PIH', '11565');
SET @weight_loss_result_concept_id = CONCEPT_FROM_MAPPING('PIH', '11566');
SET @cough_result_concept_id = CONCEPT_FROM_MAPPING('PIH', '11567');
SET @tb_contact_result_concept_id = CONCEPT_FROM_MAPPING('PIH', '11568');
SET @lymph_pain_result_concept_id = CONCEPT_FROM_MAPPING('PIH', '11569');
SET @bloody_cough_result_concept_id = CONCEPT_FROM_MAPPING('PIH', '970');
SET @dyspnea_result_concept_id = CONCEPT_FROM_MAPPING('PIH', '5960');
SET @chest_pain_result_concept_id = CONCEPT_FROM_MAPPING('PIH', '136');

UPDATE temp_pmtct_tb_visits t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND value_coded IN 
(
@fever_result_concept_id,
@weight_loss_result_concept_id,
@cough_result_concept_id,
@tb_contact_result_concept_id,
@lymph_pain_result_concept_id,
@bloody_cough_result_concept_id,
@dyspnea_result_concept_id,
@chest_pain_result_concept_id
)
SET t.obs_date = o.obs_datetime;

UPDATE temp_pmtct_tb_visits t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @fever_result_concept_id
SET fever_result_concept = o.concept_id;

UPDATE temp_pmtct_tb_visits t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @weight_loss_result_concept_id
SET weight_loss_result_concept =o.concept_id;

UPDATE temp_pmtct_tb_visits t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @cough_result_concept_id
SET cough_result_concept =o.concept_id;

UPDATE temp_pmtct_tb_visits t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @tb_contact_result_concept_id
SET tb_contact_result_concept =o.concept_id;

UPDATE temp_pmtct_tb_visits t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @lymph_pain_result_concept_id
SET lymph_pain_result_concept =o.concept_id;

UPDATE temp_pmtct_tb_visits t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @bloody_cough_result_concept_id
SET bloody_cough_result_concept =o.concept_id;

UPDATE temp_pmtct_tb_visits t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @dyspnea_result_concept_id
SET dyspnea_result_concept =o.concept_id;

UPDATE temp_pmtct_tb_visits t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @chest_pain_result_concept_id
SET chest_pain_result_concept = o.concept_id;

UPDATE temp_pmtct_tb_visits t SET tb_screening_date = IF(cough_result_concept = @present, t.obs_date,
  IF(fever_result_concept = @present, t.obs_date,
    IF(weight_loss_result_concept = @present, t.obs_date,
      IF(tb_contact_result_concept = @present, t.obs_date,
        IF(lymph_pain_result_concept = @present, t.obs_date,
          IF(bloody_cough_result_concept = @present, t.obs_date,
            IF(dyspnea_result_concept = @present, t.obs_date,
              IF(chest_pain_result_concept = @present, t.obs_date,
                NULL)))))))); 

UPDATE temp_pmtct_visit t SET tb_screening_date = (SELECT tb_screening_date FROM temp_pmtct_tb_visits tp WHERE tp.encounter_id = t.encounter_id);

-- next visit date
set @next_visit_concept_id = concept_from_mapping('PIH','5096');
UPDATE temp_pmtct_visit t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.concept_id = @next_visit_concept_id
SET next_visit_date = o.value_datetime;

-- breastfeeding data
UPDATE 	temp_pmtct_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('PIH','13642') and o.voided = 0
set breastfeeding_status = concept_name(o.value_coded, @locale);

UPDATE 	temp_pmtct_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('PIH','6889') and o.voided = 0
set last_breastfeeding_date = o.value_datetime;

set @yes = concept_from_mapping('PIH','1065');
set @no = concept_from_mapping('PIH','1066');
UPDATE 	temp_pmtct_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('PIH','14990') and o.voided = 0
set delivery = 
	CASE  o.value_coded
		when @yes then 1
		when @no then 0
	END;
	

UPDATE 	temp_pmtct_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('PIH','5599') and o.voided = 0
set delivery_datetime = o.value_datetime;

update temp_pmtct_visit t
set hiv_program_id = patient_program_id_from_encounter(patient_id, @hiv_program, encounter_id);


/*
-- index asc
DROP TEMPORARY TABLE IF EXISTS temp_pmtct_visit_index_asc;
CREATE TEMPORARY TABLE temp_pmtct_visit_index_asc
(
    SELECT
            visit_date,
            visit_id,
            encounter_id,
            patient_id,
			index_asc
    FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_asc,
            visit_date,
            visit_id,
            encounter_id,
            patient_id,
            @u:= patient_id
      FROM temp_pmtct_visit,
            (SELECT @r:= 1) AS r,
            (SELECT @u:= 0) AS u
      ORDER BY patient_id, visit_date ASC, visit_id ASC, encounter_id ASC
        ) index_ascending );

-- index desc
DROP TEMPORARY TABLE IF EXISTS temp_pmtct_visit_index_desc;
CREATE TEMPORARY TABLE temp_pmtct_visit_index_desc
(
    SELECT
            visit_date,
            visit_id,
            encounter_id,
            patient_id,
			index_desc
    FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_desc,
            visit_date,
            visit_id,
            encounter_id,
            patient_id,
            @u:= patient_id
      FROM temp_pmtct_visit,
            (SELECT @r:= 1) AS r,
            (SELECT @u:= 0) AS u
      ORDER BY patient_id, visit_date DESC, visit_id DESC, encounter_id DESC
        ) index_descending );
 
UPDATE temp_pmtct_visit t SET t.index_asc = (SELECT index_asc FROM temp_pmtct_visit_index_asc a WHERE t.visit_id = a.visit_id AND t.encounter_id = a.encounter_id);
UPDATE temp_pmtct_visit t SET t.index_desc = (SELECT index_desc FROM temp_pmtct_visit_index_desc b WHERE t.visit_id = b.visit_id AND t.encounter_id = b.encounter_id);
*/

SELECT 
visit_id,
concat(@partition,'-',encounter_id),
concat(@partition, '-', hiv_program_id),
emr_id,
visit_date,
health_facility,
date_entered,
user_entered,
hiv_test_date,
expected_delivery_date,
tb_screening_date,
has_provided_contact,
breastfeeding_status,
last_breastfeeding_date,
next_visit_date,
delivery,
delivery_datetime,
index_asc,
index_desc	
index_program_asc,
index_program_desc
FROM temp_pmtct_visit ORDER BY patient_id, visit_date, visit_id;
