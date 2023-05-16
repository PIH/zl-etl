SELECT encounter_type_id  INTO @enc_type_intake FROM encounter_type et WHERE uuid='a936ae01-6d10-455d-befc-b2d1828dad04';
SELECT encounter_type_id  INTO @enc_type_tp FROM encounter_type et WHERE uuid='f9cfdf8b-d086-4658-9b9d-45a62896da03';
SET @partition = '${partitionNum}';

DROP TABLE IF EXISTS oncology_diagnosis;
CREATE TEMPORARY TABLE oncology_diagnosis (
patient_id int,
emr_id varchar(50),
encounter_id int,
encounter_datetime datetime,
encounter_location varchar(100),
date_entered date,
user_entered varchar(30),
encounter_provider varchar(30),
encounter_type varchar(30),
diagnosis_order varchar(20),
diagnosis varchar(100)
);


INSERT INTO oncology_diagnosis(patient_id,emr_id,encounter_id,encounter_datetime,encounter_location,
							date_entered,user_entered,encounter_provider,encounter_type,diagnosis_order,diagnosis)
SELECT 
patient_id,
zlemr(e.patient_id),
e.encounter_id,
e.encounter_datetime ,
encounter_location_name(e.encounter_id),
e.date_created,
encounter_creator(e.encounter_id),
provider(e.encounter_id),
encounter_type_name_from_id(@enc_type_intake),
obs_from_group_id_value_coded(o.obs_group_id,'PIH','7537','en') diagnosis_order, value_coded_name(o.obs_id,'en')
FROM obs o
INNER JOIN encounter e ON o.encounter_id = e.encounter_id AND e.encounter_type = @enc_type_intake
WHERE  o.concept_id = concept_from_mapping('PIH','3064')
AND o.voided =0
AND e.voided =0
ORDER BY obs_id ASC;


INSERT INTO oncology_diagnosis(patient_id,emr_id,encounter_id,encounter_datetime,encounter_location,
							date_entered,user_entered,encounter_provider,encounter_type,diagnosis_order,diagnosis)
SELECT 
patient_id,
zlemr(e.patient_id),
e.encounter_id,
e.encounter_datetime ,
encounter_location_name(e.encounter_id),
e.date_created,
encounter_creator(e.encounter_id),
provider(e.encounter_id),
encounter_type_name_from_id(@enc_type_tp),
obs_from_group_id_value_coded(o.obs_group_id,'PIH','7537','en') diagnosis_order, value_coded_name(o.obs_id,'en')
FROM obs o
INNER JOIN encounter e ON o.encounter_id = e.encounter_id AND e.encounter_type = @enc_type_tp
WHERE  o.concept_id = concept_from_mapping('PIH','3064')
AND o.voided =0
AND e.voided =0
ORDER BY obs_id ASC;


SELECT 
emr_id,
CONCAT(@partition,'-',encounter_id) "encounter_id",
encounter_datetime ,
encounter_location ,
date_entered ,
user_entered ,
encounter_provider ,
encounter_type,
diagnosis_order ,
diagnosis 
FROM oncology_diagnosis;