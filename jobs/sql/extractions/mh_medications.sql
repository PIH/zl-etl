-- set @startDate='2025-02-01';
-- set @endDate='2025-03-05';

SELECT encounter_type_id INTO @mh_enctype FROM encounter_type et WHERE et.uuid ='a8584ab8-cc2a-11e5-9956-625662870761';
SET @partition = '${partitionNum}';

DROP TABLE IF EXISTS all_mh_medications;
CREATE TEMPORARY TABLE all_mh_medications (
patient_id int,
emr_id varchar(50),
encounter_id int,
obs_group_id int,
encounter_datetime datetime,
encounter_location_name varchar(50),
encounter_creator varchar(50),
provider varchar(50),
medication_name varchar(500),
dosage int,
dosage_unit varchar(50)
);

DROP TABLE IF EXISTS temp_encounter;
CREATE TEMPORARY TABLE temp_encounter AS 
SELECT patient_id, encounter_id, encounter_datetime, encounter_type 
FROM encounter e 
WHERE e.encounter_type =@mh_enctype
AND e.voided =0
and (DATE(encounter_datetime) >=  date(@startDate) or @startDate is null)
and (DATE(encounter_datetime) <=  date(@endDate) or @endDate is null);;

create index temp_encounter_e on temp_encounter(encounter_id);

DROP TABLE IF EXISTS temp_obs;
CREATE TEMPORARY TABLE temp_obs AS 
SELECT o.person_id, o.obs_id , o.obs_group_id , o.obs_datetime ,o.date_created , o.encounter_id, o.value_coded, o.concept_id, o.value_numeric , o.voided 
FROM obs o INNER JOIN temp_encounter te ON te.encounter_id=o.encounter_id 
WHERE o.voided =0;

create index temp_obs_c1 on temp_obs(encounter_id, concept_id);
create index temp_obs_c2 on temp_obs(obs_group_id, concept_id);

INSERT INTO all_mh_medications(patient_id,emr_id,encounter_id,obs_group_id,encounter_datetime,encounter_location_name,encounter_creator,provider)
SELECT 
DISTINCT
patient_id,
zlemr(patient_id) emr_id,
e.encounter_id,
o.obs_id AS obs_group_id,
e.encounter_datetime ,
encounter_location_name(e.encounter_id) encounter_location_name,
encounter_creator(e.encounter_id) encounter_creator,
provider(e.encounter_id) provider
FROM temp_encounter e INNER JOIN temp_obs o ON e.encounter_id=o.encounter_id
AND concept_id=concept_from_mapping('PIH','10742');


UPDATE all_mh_medications SET medication_name=obs_from_group_id_value_coded_list(obs_group_id,'PIH','10634','en');
UPDATE all_mh_medications SET dosage_unit=obs_from_group_id_value_coded_list(obs_group_id,'PIH','10744','en');
UPDATE all_mh_medications SET dosage=obs_from_group_id_value_numeric_from_temp(obs_group_id,'PIH','9073');


SELECT
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',encounter_id),encounter_id) "encounter_id",
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',patient_id),patient_id) "patient_id",
emr_id,
encounter_datetime,
encounter_location_name,
encounter_creator,
provider,
medication_name,
dosage,
dosage_unit
FROM all_mh_medications;
