SELECT encounter_type_id  INTO @disp_enc_type FROM encounter_type et WHERE uuid='8ff50dea-18a1-4609-b4c9-3f8f2d611b84';
SET @partition = '${partitionNum}';

DROP TABLE IF EXISTS all_medication_dispensing;
CREATE TEMPORARY TABLE all_medication_dispensing
(
patient_id int,
obs_group_id int,
emr_id varchar(50),
encounter_id int,
encounter_datetime datetime,
encounter_location varchar(100),
date_entered date,
user_entered varchar(30),
encounter_provider varchar(30),
drug_name varchar(500),
drug_openboxes_code int,
duration int,
duration_unit varchar(20),
quantity_per_dose int,
dose_unit varchar(50),
frequency varchar(50),
quantity_dispensed int,
prescription varchar(500)
);

DROP TABLE IF EXISTS temp_encounter;
CREATE TEMPORARY TABLE temp_encounter
SELECT patient_id,encounter_id, encounter_type ,encounter_datetime, date_created 
FROM encounter e 
WHERE e.encounter_type = @disp_enc_type
AND e.voided = 0;

create index temp_encounter_ci1 on temp_encounter(encounter_id);

DROP TEMPORARY TABLE if exists temp_obs;
CREATE TEMPORARY TABLE temp_obs
select o.obs_id, o.voided, o.obs_group_id, o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text, o.value_datetime, o.value_drug, o.comments, o.date_created, o.obs_datetime
from obs o inner join temp_encounter t on o.encounter_id = t.encounter_id
where o.voided = 0;

create index temp_obs_ci1 on temp_obs(obs_id, concept_id);
create index temp_obs_ci2 on temp_obs(obs_id);
create index temp_obs_ci3 on temp_obs(obs_group_id,concept_id);


INSERT INTO all_medication_dispensing(
patient_id,
obs_group_id,
emr_id,
encounter_id,
encounter_datetime,
encounter_location,
date_entered,
user_entered,
encounter_provider,
duration,
duration_unit,
quantity_per_dose,
dose_unit,
frequency,
quantity_dispensed,
prescription
)
SELECT 
e.patient_id,
o.obs_group_id,
zlemr(e.patient_id),
e.encounter_id,
e.encounter_datetime ,
encounter_location_name(e.encounter_id),
e.date_created,
encounter_creator(e.encounter_id),
provider(e.encounter_id),
NULL,
NULL,
NULL,
NULL,
NULL,
NULL,
NULL
FROM temp_obs o
INNER JOIN temp_encounter e ON o.encounter_id = e.encounter_id
WHERE  o.concept_id = concept_from_mapping('PIH','1282')
ORDER BY obs_id ASC;


UPDATE all_medication_dispensing tgt 
INNER JOIN temp_obs o ON o.encounter_id = tgt.encounter_id AND o.obs_group_id=tgt.obs_group_id
AND o.concept_id=concept_from_mapping('PIH','9075')
SET duration= value_numeric;

UPDATE all_medication_dispensing tgt 
SET duration_unit= obs_from_group_id_value_coded(obs_group_id,'PIH','6412','en');

UPDATE all_medication_dispensing tgt 
INNER JOIN obs o ON o.encounter_id = tgt.encounter_id AND o.obs_group_id=tgt.obs_group_id
AND o.concept_id=concept_from_mapping('PIH','9073')
SET quantity_per_dose= value_numeric;

UPDATE all_medication_dispensing tgt 
SET dose_unit=obs_from_group_id_value_text_from_temp(obs_group_id, 'PIH','9074');


UPDATE all_medication_dispensing tgt 
SET frequency= obs_from_group_id_value_coded(obs_group_id,'PIH','9363','en') ;

UPDATE all_medication_dispensing tgt 
INNER JOIN obs o ON o.encounter_id = tgt.encounter_id AND o.obs_group_id=tgt.obs_group_id
AND o.concept_id=concept_from_mapping('PIH','9071')
SET quantity_dispensed= value_numeric;

UPDATE all_medication_dispensing tgt 
SET prescription=obs_from_group_id_value_text_from_temp(obs_group_id, 'PIH','9072');


DROP TEMPORARY TABLE IF EXISTS drug_name;
CREATE TEMPORARY TABLE drug_name AS 
SELECT e.patient_id, o.obs_group_id, e.encounter_id, d.name, openboxesCode(o.value_drug) drug_openboxes_code
FROM temp_obs o 
INNER JOIN temp_encounter e ON o.encounter_id = e.encounter_id
INNER JOIN drug d ON d.drug_id = o.value_drug 
WHERE o.concept_id = concept_from_mapping('PIH','1282')
ORDER BY obs_id ASC;


UPDATE all_medication_dispensing am
SET drug_openboxes_code = (
SELECT drug_openboxes_code
FROM drug_name dn
WHERE am.encounter_id=dn.encounter_id 
AND am.patient_id=dn.patient_id 
AND am.obs_group_id=dn.obs_group_id
);


UPDATE all_medication_dispensing am
SET drug_name = (
SELECT name
FROM drug_name dn
WHERE am.encounter_id=dn.encounter_id 
AND am.patient_id=dn.patient_id 
AND am.obs_group_id=dn.obs_group_id
);

SELECT 
emr_id,
CONCAT(@partition,'-',encounter_id) "encounter_id",
encounter_datetime,
encounter_location,
date_entered,
user_entered,
encounter_provider,
drug_name,
drug_openboxes_code,
duration,
duration_unit,
quantity_per_dose,
dose_unit,
frequency,
quantity_dispensed,
prescription
FROM all_medication_dispensing;