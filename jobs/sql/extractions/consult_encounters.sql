SET @partition = '${partitionNum}';
SET sql_safe_updates = 0;


select encounter_type_id  into @consult_type_id 
from encounter_type et where uuid='92fd09b4-5335-4f7e-9f63-b2a663fd09a6';
SELECT 'a541af1e-105c-40bf-b345-ba1fd6a59b85' INTO @emr_identifier_type;
drop temporary table if exists temp_consult_encs;
create temporary table temp_consult_encs
(
 patient_id          int,          
 emr_id              varchar(15),  
 encounter_id        int,          
 visit_id            int,          
 encounter_datetime  datetime,     
 creator             varchar(255), 
 datetime_created    datetime,     
 encounter_location  varchar(255), 
 provider            varchar(255), 
 encounter_type      int,          
 encounter_type_name varchar(50),  
 trauma              boolean,       
 trauma_type         varchar(255), 
 return_visit_date   date,         
 disposition         varchar(255), 
 index_asc           int,          
 index_desc          int           
);


insert into temp_consult_encs (patient_id, encounter_id, visit_id, encounter_datetime, datetime_created, encounter_type)
select patient_id, encounter_id, visit_id, encounter_datetime, date_created, encounter_type
from encounter e
where e.voided = 0
AND encounter_type IN (@consult_type_id)
ORDER BY encounter_datetime desc;

UPDATE temp_consult_encs
SET encounter_type_name = encounter_type_name_from_id(encounter_type);

UPDATE temp_consult_encs
SET creator = encounter_creator_name(encounter_id);

UPDATE temp_consult_encs
SET encounter_location = encounter_location_name(encounter_id);

UPDATE temp_consult_encs
SET provider = provider(encounter_id);

UPDATE temp_consult_encs t
SET emr_id = patient_identifier(patient_id, @emr_identifier_type);

-- observations
DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, 
o.value_text,o.value_datetime, o.comments, o.date_created
from obs o
inner join temp_consult_encs t on t.encounter_id = o.encounter_id
where o.voided = 0;

update temp_consult_encs t
set trauma = value_coded_as_boolean(obs_id_from_temp(t.encounter_id, 'PIH',8848,0));

update temp_consult_encs t
set trauma_type = obs_value_coded_list_from_temp(t.encounter_id, 'PIH',8849,@locale);

update temp_consult_encs t
set return_visit_date = date(obs_value_datetime_from_temp(t.encounter_id, 'PIH',5096));

update temp_consult_encs t
set disposition = obs_value_coded_list_from_temp(t.encounter_id, 'PIH',8620,@locale);

-- final output
SELECT 
emr_id,
CONCAT(@partition,'-',encounter_id) "encounter_id",
CONCAT(@partition,'-',visit_id) "visit_id",
encounter_datetime,
creator AS user_entered,
datetime_created,
encounter_location,
encounter_type_name AS encounter_type,
provider,
trauma,
trauma_type,
return_visit_date,
disposition, 
index_asc,
index_desc
FROM temp_consult_encs;
