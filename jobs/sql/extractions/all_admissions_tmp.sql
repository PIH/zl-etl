SET @partition = '${partitionNum}';
SET sql_safe_updates = 0;

select encounter_type_id  into @trf_type_id 
from encounter_type et where uuid='436cfe33-6b81-40ef-a455-f134a9f7e580';

select encounter_type_id  into @adm_type_id 
from encounter_type et where uuid='260566e1-c909-4d61-a96f-c1019291a09d';

select encounter_type_id  into @sort_type_id 
from encounter_type et where uuid='b6631959-2105-49dd-b154-e1249e0fbcd7';

select encounter_type_id  into @cons_type_id 
from encounter_type et where uuid='92fd09b4-5335-4f7e-9f63-b2a663fd09a6';
SELECT 'a541af1e-105c-40bf-b345-ba1fd6a59b85' INTO @emr_identifier_type;

drop temporary table if exists all_admissions;
create temporary table all_admissions
(
    patient_id           int,
	emr_id               varchar(15),
    encounter_id         int,
    visit_id			 int,
    start_date           datetime,
    end_date             datetime,
    creator              varchar(255),
    date_entered		 date,
    encounter_location   varchar(255),
    provider 			 varchar(255),
    encounter_type 		 int,
    encounter_type_name  varchar(50),
    outcome_disposition	 varchar(255),
    voided               bit
);

insert into all_admissions (patient_id, encounter_id, visit_id, start_date, date_entered, encounter_type)
select patient_id, encounter_id, visit_id, encounter_datetime, date_created, encounter_type
from encounter
where voided = 0
AND encounter_type IN (@adm_type_id , @trf_type_id, @sort_type_id,@cons_type_id)
ORDER BY encounter_datetime desc;

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.comments 
from obs o
inner join all_admissions t on t.encounter_id = o.encounter_id
where o.voided = 0;

UPDATE all_admissions
SET encounter_type_name = encounter_type_name_from_id(encounter_type);

UPDATE all_admissions
SET creator = encounter_creator_name(encounter_id);

UPDATE all_admissions
SET encounter_location = encounter_location_name(encounter_id);

UPDATE all_admissions
SET provider = provider(encounter_id);

UPDATE all_admissions t
SET emr_id = patient_identifier(patient_id, @emr_identifier_type);

UPDATE all_admissions 
SET outcome_disposition=obs_value_coded_list_from_temp(encounter_id,'PIH','8620','en')
WHERE encounter_type=@cons_type_id;

DROP TABLE IF EXISTS temp_start_admission;
CREATE TEMPORARY TABLE temp_start_admission
SELECT emr_id, min(start_date) AS start_date
FROM all_admissions
WHERE encounter_type = @adm_type_id 
GROUP BY emr_id;


SELECT t.* 
FROM all_admissions t
INNER JOIN temp_start_admission tmp
ON t.emr_id = tmp.emr_id
AND t.start_date >= tmp.start_date
AND t.encounter_type IN (@adm_type_id , @trf_type_id, @sort_type_id);