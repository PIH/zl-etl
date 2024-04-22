SET @partition = '${partitionNum}';
SET sql_safe_updates = 0;


select encounter_type_id  into @consult_type_id 
from encounter_type et where uuid='92fd09b4-5335-4f7e-9f63-b2a663fd09a6';
SELECT 'a541af1e-105c-40bf-b345-ba1fd6a59b85' INTO @emr_identifier_type;
drop temporary table if exists temp_consult_encs;
create temporary table temp_consult_encs
(
 patient_id          int(11),          
 emr_id              varchar(15),  
 encounter_id        int(11),          
 visit_id            int(11),          
 encounter_datetime  datetime,
 creator             int(11),
 user_entered        varchar(255), 
 datetime_created    datetime, 
 location_id         int(11),
 encounter_location  varchar(255), 
 provider            varchar(255), 
 encounter_type      int(11),          
 encounter_type_name varchar(50),  
 trauma              boolean,       
 trauma_type         varchar(255), 
 return_visit_date   date,         
 disposition         varchar(255), 
 index_asc           int,          
 index_desc          int           
);

insert into temp_consult_encs (patient_id, encounter_id, visit_id, encounter_datetime, datetime_created, encounter_type, creator,location_id)
select patient_id, encounter_id, visit_id, encounter_datetime, date_created, encounter_type, creator, location_id 
from encounter e
where e.voided = 0
AND encounter_type IN (@consult_type_id)
ORDER BY encounter_datetime desc;

create index temp_consult_encs_ei on temp_consult_encs(encounter_id);

UPDATE temp_consult_encs
SET encounter_type_name = encounter_type_name_from_id(encounter_type);

UPDATE temp_consult_encs
set user_entered = person_name_of_user(creator);

UPDATE temp_consult_encs
SET encounter_location = location_name(location_id);

UPDATE temp_consult_encs
SET provider = provider(encounter_id);

UPDATE temp_consult_encs t
SET emr_id = patient_identifier(patient_id, @emr_identifier_type);

-- observations
set @trauma = concept_from_mapping('PIH','8848');
set @trauma_type = concept_from_mapping('PIH','8849');
set @return_visit_date = concept_from_mapping('PIH','5096');
set @disposition = concept_from_mapping('PIH','8620');

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, 
o.value_text,o.value_datetime, o.comments, o.date_created
from obs o
inner join temp_consult_encs t on t.encounter_id = o.encounter_id
where o.voided = 0
and concept_id IN (@trauma,@trauma_type,@return_visit_date,@disposition);

create index temp_obs_io on temp_obs(obs_id);
create index temp_obs_ei on temp_obs(encounter_id);
create index temp_obs_ci1 on temp_obs(encounter_id,concept_id);

drop temporary table if exists temp_obs_collated;
create temporary table temp_obs_collated 
select encounter_id,
max(case when concept_id = @trauma then value_coded end) "trauma_value_coded",
max(case when concept_id = @trauma_type then concept_name(value_coded,@locale) end) "trauma_type",
max(case when concept_id = @return_visit_date then value_numeric end) "return_visit_date",
max(case when concept_id = @disposition then concept_name(value_coded,@locale) end) "disposition"
from temp_obs
group by encounter_id;

create index temp_obs_collated_ei on temp_obs_collated(encounter_id);

update temp_consult_encs t
inner join temp_obs_collated o on o.encounter_id = t.encounter_id
set t.trauma =
		CASE o.trauma_value_coded
			WHEN concept_from_mapping('PIH','YES') then 1
			WHEN concept_from_mapping('PIH','NO') then 0
		END,
	t.trauma_type = o.trauma_type,
	t.return_visit_date = o.return_visit_date,
	t.disposition = o.disposition
;	

-- final output
SELECT 
emr_id,
CONCAT(@partition,'-',encounter_id) "encounter_id",
CONCAT(@partition,'-',visit_id) "visit_id",
encounter_datetime,
user_entered, 
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
