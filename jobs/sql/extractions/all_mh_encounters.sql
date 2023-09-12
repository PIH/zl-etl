
SELECT encounter_type_id INTO @mh_enctype FROM encounter_type et WHERE et.uuid ='a8584ab8-cc2a-11e5-9956-625662870761';
SET @partition = '${partitionNum}';

DROP TABLE IF EXISTS all_mh_encounters;
CREATE TEMPORARY TABLE all_mh_encounters
(
patient_id int, 
emr_id varchar(30),
encounter_id int, 
encounter_date date,
date_entered date,
user_entered varchar(100),
provider_name varchar(100),
psychological_interventions varchar(1000),
inpatient varchar(30), -- 
suicidal_ideation boolean,
suicide_attempts boolean,
safety_plan varchar(100), -- 
zldsi_score int,
cgi_score int,
ces_dc_score int,
pcl_5_score int,
psc_35_score int,
aims varchar(20), 
whodas_score int,
return_encounter_date date
);


DROP TABLE IF EXISTS temp_encounter;
CREATE TEMPORARY TABLE temp_encounter AS 
SELECT patient_id, encounter_id, encounter_datetime, encounter_type , date_created
FROM encounter e 
WHERE e.encounter_type = @mh_enctype
AND e.voided =0;

create index temp_encounter_ci1 on temp_encounter(encounter_id);


DROP TABLE IF EXISTS temp_obs;
CREATE TEMPORARY TABLE temp_obs AS 
SELECT o.person_id, o.obs_id , o.obs_group_id , o.obs_datetime ,o.date_created , o.encounter_id, o.value_coded, o.concept_id, o.value_numeric , o.value_datetime , o.value_text , o.voided 
FROM temp_encounter te  INNER JOIN  obs o ON te.encounter_id=o.encounter_id 
WHERE o.voided =0;


set @identifier_type ='a541af1e-105c-40bf-b345-ba1fd6a59b85';

INSERT INTO all_mh_encounters (patient_id, encounter_id, encounter_date, emr_id, date_entered, user_entered, provider_name)
SELECT  patient_id, 
		encounter_id, 
		date(encounter_datetime),
		patient_identifier(patient_id,@identifier_type) AS emr_id,
		date_created AS date_entered, 
		encounter_creator_name(encounter_id) AS user_entered,
		provider(encounter_id)
FROM temp_encounter;

UPDATE all_mh_encounters SET psychological_interventions=obs_value_coded_list_from_temp(encounter_id,'PIH','10636','en');

UPDATE all_mh_encounters SET suicidal_ideation=answer_exists_in_encounter_temp(encounter_id,'PIH', '10140','PIH','10633');
UPDATE all_mh_encounters SET suicide_attempts=answer_exists_in_encounter_temp(encounter_id,'PIH', '10140','PIH','7514');


UPDATE all_mh_encounters SET zldsi_score=obs_value_numeric_from_temp(encounter_id,'PIH', '10584');
UPDATE all_mh_encounters SET cgi_score=obs_value_numeric_from_temp(encounter_id,'PIH', '10587');
UPDATE all_mh_encounters SET ces_dc_score=obs_value_numeric_from_temp(encounter_id,'PIH', '10590');
UPDATE all_mh_encounters SET pcl_5_score=obs_value_numeric_from_temp(encounter_id,'PIH', '12428');
UPDATE all_mh_encounters SET psc_35_score=obs_value_numeric_from_temp(encounter_id,'PIH', '12422');
UPDATE all_mh_encounters SET psc_35_score=obs_value_numeric_from_temp(encounter_id,'PIH', '12422');
UPDATE all_mh_encounters SET aims=obs_value_coded_list_from_temp(encounter_id,'PIH','10591','en');
UPDATE all_mh_encounters SET whodas_score=obs_value_numeric_from_temp(encounter_id,'PIH', '10589');
UPDATE all_mh_encounters SET return_encounter_date=obs_value_datetime_from_temp(encounter_id, 'PIH','5096');

SELECT
CONCAT(@partition,'-',emr_id) "emr_id",
encounter_id, 
encounter_date,
date_entered,
user_entered,
provider_name,
psychological_interventions,
inpatient, -- 
suicidal_ideation,
suicide_attempts,
safety_plan, -- 
zldsi_score,
cgi_score,
ces_dc_score,
pcl_5_score,
psc_35_score,
aims, 
whodas_score,
return_encounter_date
FROM all_mh_encounters;

