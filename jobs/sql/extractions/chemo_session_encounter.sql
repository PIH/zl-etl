set @partition = '${partitionNum}';
select et.encounter_type_id into @chemo_form from encounter_type et where uuid = '828964fa-17eb-446e-aba4-e940b0f4be5b';

drop temporary table if exists chemo_encounters;
create temporary table chemo_encounters
(patient_id                int(11),      
emr_id                     varchar(50),  
encounter_id               int(11),    
visit_id                   int(11),
encounter_datetime         datetime,     
creator                    int(11),      
user_entered               text,         
date_created               datetime,
provider_name              varchar(255),
location_id                int(11),      
encounter_location         varchar(255), 
cycle_number               double,       
planned_chemo_sessions     double,       
treatment_plan             varchar(255), 
visit_information_comments text,
index_asc                  INT,          
index_desc                 INT       
);

insert into chemo_encounters (patient_id , visit_id, encounter_id ,encounter_datetime , creator , date_created, location_id)
select e.patient_id , e.visit_id, e.encounter_id , e.encounter_datetime , e.creator , e.date_created, e.location_id  from encounter e 
where e.voided = 0
and e.encounter_type  = @chemo_form
;

create index chemo_encounter_ei on chemo_encounters(encounter_id);

-- emr_id
drop temporary table if exists temp_emrids;
create temporary table temp_emrids
(
    patient_id int(11),
    emr_id     varchar(50)
);

insert into temp_emrids(patient_id)
select DISTINCT patient_id
from chemo_encounters
;
create index temp_emrids_patient_id on temp_emrids (patient_id);

update temp_emrids t
set emr_id = patient_identifier(patient_id, 'ZL EMR ID');

update chemo_encounters t
set t.emr_id = zlemrid_from_temp(t.patient_id);

-- user entered
drop temporary table if exists temp_users;
create temporary table temp_users
(
    user_id int(11),
    user_name     text
);

insert into temp_users (user_id) 
select distinct creator from chemo_encounters;

create index temp_users_ui on temp_users (user_id);

update temp_users
set user_name = person_name_of_user(user_id);

update chemo_encounters t
inner join temp_users u on u.user_id = t.creator
set user_entered = u.user_name;

-- location 
drop temporary table if exists temp_locations;
create temporary table temp_locations
(
    location_id int(11),
    location_name     text
);

insert into temp_locations (location_id) 
select distinct location_id from chemo_encounters;

create index temp_locations_ui on temp_locations (location_id);

update temp_locations
set location_name = location_name (location_id);

update chemo_encounters t
inner join temp_locations u on u.location_id = t.location_id
set encounter_location = u.location_name;

-- provider
drop temporary table if exists temp_providers;
create temporary table temp_providers
(
    provider_id   int(11),
    provider_name text
);


insert into temp_providers (provider_id) 
select distinct creator from chemo_encounters;

create index temp_providers_ui on temp_providers (provider_id);

update temp_providers
set provider_name = person_name_of_user(provider_id);

update chemo_encounters t
inner join temp_providers u on u.provider_id = t.creator
set t.provider_name = u.provider_name;

-- clinical observations

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, 
o.value_text,o.value_datetime, o.comments, o.date_created
from obs o
inner join chemo_encounters t on t.encounter_id = o.encounter_id
where o.voided = 0;

create index temp_obs_io on temp_obs(obs_id);
create index temp_obs_ei on temp_obs(encounter_id);
create index temp_obs_ci1 on temp_obs(encounter_id,concept_id);

update chemo_encounters ce
set cycle_number = obs_value_numeric_from_temp(encounter_id, 'PIH','3648');

update chemo_encounters ce
set planned_chemo_sessions = obs_value_numeric_from_temp(encounter_id, 'PIH','10538');

update chemo_encounters ce
set treatment_plan = obs_value_coded_list_from_temp(encounter_id, 'PIH','10525',@locale);

update chemo_encounters ce
set visit_information_comments = obs_value_text_from_temp(encounter_id, 'PIH','10534');

select 
e.emr_id,
concat(@partition, '-', e.encounter_id),
concat(@partition, '-', e.visit_id),
e.encounter_datetime,
e.provider_name,
e.user_entered,
e.date_created,
e.encounter_location,
e.cycle_number,
e.planned_chemo_sessions,
e.treatment_plan,
e.visit_information_comments,
e.index_asc,
e.index_desc
from chemo_encounters e
;
