SELECT encounter_type_id  INTO @enc_type FROM encounter_type et WHERE uuid='8ff50dea-18a1-4609-b4c9-3f8f2d611b84';
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
patient_id,
o.obs_group_id,
zlemr(e.patient_id),
e.encounter_id,
e.encounter_datetime ,
encounter_location_name(e.encounter_id),
e.date_created,
encounter_creator(e.encounter_id),
provider(e.encounter_id),
obs_from_group_id_value_numeric(o.obs_group_id,'PIH','9075')  duration,
obs_from_group_id_value_coded(o.obs_group_id,'PIH','6412','en') duration_unit,
obs_from_group_id_value_numeric(o.obs_group_id,'PIH','9073')  quantity_per_dose,
obs_from_group_id_value_text(o.obs_group_id,'PIH','9074')  dose_unit,
obs_from_group_id_value_coded(o.obs_group_id,'PIH','9363','en')  frequency,
obs_from_group_id_value_numeric(o.obs_group_id,'PIH','9071') quantity_dispensed,
obs_from_group_id_value_text(o.obs_group_id,'PIH','9072') prescription
FROM obs o
INNER JOIN encounter e ON o.encounter_id = e.encounter_id AND e.encounter_type = @enc_type
WHERE  o.concept_id = concept_from_mapping('PIH','1282')
AND o.voided =0
AND e.voided =0
ORDER BY obs_id ASC;

DROP TEMPORARY TABLE IF EXISTS drug_name;
CREATE TEMPORARY TABLE drug_name AS 
SELECT e.patient_id, o.obs_group_id, e.encounter_id, d.name, openboxesCode(o.value_drug) drug_openboxes_code
FROM obs o 
INNER JOIN encounter e ON o.encounter_id = e.encounter_id AND e.encounter_type = @enc_type
INNER JOIN drug d ON d.drug_id = o.value_drug 
WHERE o.concept_id = concept_from_mapping('PIH','1282')
AND o.voided =0
AND e.voided =0
ORDER BY obs_id ASC;


UPDATE all_medication_dispensing am
INNER JOIN drug_name dn ON am.encounter_id=dn.encounter_id AND am.patient_id=dn.patient_id AND am.obs_group_id=dn.obs_group_id
SET am.drug_openboxes_code= dn.drug_openboxes_code,
am.drug_name = dn.name;

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