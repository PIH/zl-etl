SET sql_safe_updates = 0;
set @partition = '${partitionNum}';

SELECT encounter_type_id INTO @HIV_adult_intake FROM encounter_type WHERE uuid = 'c31d306a-40c4-11e7-a919-92ebcb67fe33';
SELECT encounter_type_id INTO @HIV_adult_followup FROM encounter_type WHERE uuid = 'c31d3312-40c4-11e7-a919-92ebcb67fe33';
SELECT encounter_type_id INTO @HIV_ped_intake FROM encounter_type WHERE uuid = 'c31d3416-40c4-11e7-a919-92ebcb67fe33';
SELECT encounter_type_id INTO @HIV_ped_followup FROM encounter_type WHERE uuid = 'c31d34f2-40c4-11e7-a919-92ebcb67fe33';
SET @present = CONCEPT_FROM_MAPPING('PIH','11563');
SET @absent = CONCEPT_FROM_MAPPING('PIH','11564');
set @positive = concept_from_mapping('PIH','703');
set @negative = concept_from_mapping('PIH','664');
set @tbScreeningResult = CONCEPT_FROM_MAPPING('CIEL', '160108');

DROP TEMPORARY TABLE IF EXISTS temp_TB_screening;
CREATE TEMPORARY TABLE temp_TB_screening
(
patient_id INT(11),
encounter_id INT(11),
screening_location VARCHAR(255),
cough_result_concept INT(11),
fever_result_concept INT(11),
weight_loss_result_concept INT(11),
tb_contact_result_concept INT(11),
lymph_pain_result_concept INT(11),
bloody_cough_result_concept INT(11),
dyspnea_result_concept INT(11),
chest_pain_result_concept INT(11),
tb_screening VARCHAR(30),
tb_screening_bool VARCHAR(25),
tb_screening_date DATETIME,
index_ascending INT(11),
index_descending INT(11),
date_entered DATETIME,
user_entered VARCHAR(50)
);

-- load temp table with all intake/followup forms with any TB screening answer given
INSERT INTO temp_TB_screening (patient_id, encounter_id, tb_screening_date, date_entered, user_entered)
SELECT e.patient_id, e.encounter_id,e.encounter_datetime, date_created, username(creator) FROM encounter e
WHERE e.voided =0 
AND e.encounter_type IN (@HIV_adult_intake,@HIV_adult_followup,@HIV_ped_intake,@HIV_ped_followup)
AND EXISTS
  (SELECT 1 FROM obs o WHERE o.encounter_id = e.encounter_id 
   AND o.voided = 0 AND o.concept_id IN (@absent,@present))
;  

CREATE INDEX temp_TB_screening_patient_id ON temp_TB_screening (patient_id);
CREATE INDEX temp_TB_screening_tb_screening_date ON temp_TB_screening (tb_screening_date);
CREATE INDEX temp_TB_screening_encounter_id ON temp_TB_screening (encounter_id);
create index temp_tb_screening_ei on temp_TB_screening(encounter_id);

UPDATE temp_TB_screening
set screening_location  = encounter_parent_location_name(encounter_id);

-- loading a temp table with the only obs we are concerned with:
-- symptoms present/absent or an explicit tb screening result
DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.comments, o.date_created  
from obs o
 inner join temp_TB_screening t on t.encounter_id = o.encounter_id
where o.voided = 0
and o.concept_id in (
	@tbScreeningResult,
	@positive,
	@negative);

create index temp_obs_ci1 on temp_obs(encounter_id,value_coded);
create index temp_obs_ci2 on temp_obs(encounter_id,concept_id);

-- update answer of each of the screening questions by bringing in the symptom/answer (fever, weight loss etc...)
-- and update the temp table column based on whether the obs question was symptom question was present or absent
set @feverResult = CONCEPT_FROM_MAPPING('PIH', '11565');
UPDATE temp_TB_screening t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @feverResult
SET fever_result_concept =o.concept_id;

set @weightLoss = CONCEPT_FROM_MAPPING('PIH', '11566');
UPDATE temp_TB_screening t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @weightLoss
SET weight_loss_result_concept =o.concept_id;

set @coughResult = CONCEPT_FROM_MAPPING('PIH', '11567');
UPDATE temp_TB_screening t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @coughResult
SET cough_result_concept =o.concept_id;

set @contactResult = CONCEPT_FROM_MAPPING('PIH', '11568');
UPDATE temp_TB_screening t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @contactResult
SET tb_contact_result_concept =o.concept_id;

set @lymphPain = CONCEPT_FROM_MAPPING('PIH', '11569');
UPDATE temp_TB_screening t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded =@lymphPain
SET lymph_pain_result_concept =o.concept_id;

set @bloodyCough = CONCEPT_FROM_MAPPING('PIH', '970');
UPDATE temp_TB_screening t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @bloodyCough 
SET bloody_cough_result_concept =o.concept_id;

set @dyspnea = CONCEPT_FROM_MAPPING('PIH', '5960');
UPDATE temp_TB_screening t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @dyspnea
SET dyspnea_result_concept =o.concept_id;

set @chestPain = CONCEPT_FROM_MAPPING('PIH', '136');
UPDATE temp_TB_screening t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.value_coded = @chestPain
SET chest_pain_result_concept =o.concept_id;


UPDATE temp_TB_screening t
INNER JOIN temp_obs o ON t.encounter_id = o.encounter_id AND o.concept_id = @tbScreeningResult
SET tb_screening = if(o.value_coded = @positive, '1',
					if(o.value_coded =  @negative,'0',null));

UPDATE temp_TB_screening t SET tb_screening_bool = IF(cough_result_concept = @present,'1',
  IF(fever_result_concept = @present,'1',
    IF(weight_loss_result_concept = @present,'1',
      IF(tb_contact_result_concept = @present,'1',
        IF(lymph_pain_result_concept = @present,'1',
          IF(bloody_cough_result_concept = @present,'1',
            IF(dyspnea_result_concept = @present,'1',
              IF(chest_pain_result_concept = @present,'1',
                '0')))))))); 

-- The ascending/descending indexes are calculated ordering on the screening date
-- new temp tables are used to build them and then joined into the main temp table. 
-- index ascending
DROP TEMPORARY TABLE IF EXISTS temp_screening_index_asc;
CREATE TEMPORARY TABLE temp_screening_index_asc
(
    SELECT
            patient_id,
            encounter_id,
            tb_screening_date,
            index_asc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_asc,
            patient_id,
            encounter_id,
            tb_screening_date,
            @u:= patient_id
      FROM temp_TB_screening,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id ASC, tb_screening_date ASC, encounter_id ASC
        ) index_ascending);

UPDATE temp_TB_screening t
INNER JOIN temp_screening_index_asc tsia ON tsia.encounter_id = t.encounter_id
SET t.index_ascending = tsia.index_asc;

-- index descending
DROP TEMPORARY TABLE IF EXISTS temp_screening_index_desc;
CREATE TEMPORARY TABLE temp_screening_index_desc
(
    SELECT
            patient_id,
            encounter_id,
            tb_screening_date,
            index_DESC
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_DESC,
            patient_id,
            encounter_id,
            tb_screening_date,
            @u:= patient_id
      FROM temp_TB_screening,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id DESC, tb_screening_date DESC, encounter_id DESC
        ) index_DESCending);

UPDATE temp_TB_screening t
INNER JOIN temp_screening_index_desc tsid ON tsid.encounter_id = t.encounter_id
SET t.index_descending = tsid.index_desc;

SELECT
ZLEMR(patient_id) emr_id,
DOSID(patient_id) dossier_id,
concat(@partition,'-',encounter_id),
screening_location, 
IF(cough_result_concept = @present,'1',IF(cough_result_concept = @absent,'0',NULL)) "cough_result",
IF(fever_result_concept = @present,'1',IF(fever_result_concept = @absent,'0',NULL)) "fever_result",
IF(weight_loss_result_concept = @present,'1',IF(weight_loss_result_concept = @absent,'0',NULL)) "weight_loss",
IF(tb_contact_result_concept = @present,'1',IF(tb_contact_result_concept = @absent,'0',NULL)) "tb_contact",
IF(lymph_pain_result_concept = @present,'1',IF(lymph_pain_result_concept = @absent,'0',NULL)) "lymph_pain",
IF(bloody_cough_result_concept = @present,'1',IF(bloody_cough_result_concept = @absent,'0',NULL)) "bloody_cough",
IF(dyspnea_result_concept = @present,'1',IF(dyspnea_result_concept = @absent,'0',NULL)) "dyspnea_result",
IF(chest_pain_result_concept = @present,'1',IF(chest_pain_result_concept = @absent,'0',NULL)) "chest_pain",
COALESCE(tb_screening, tb_screening_bool) "tb_screening_result",
tb_screening_date,
index_ascending,
index_descending,
date_entered,
user_entered
FROM temp_TB_screening
ORDER BY patient_id ASC, tb_screening_date ASC, encounter_id ASC;
