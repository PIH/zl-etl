set @partition = '${partitionNum}';
set @locale = 'en';

DROP TABLE IF EXISTS temp_patients;
CREATE TEMPORARY TABLE  temp_patients
(
emr_id                            varchar(50),   
hiv_emr_id                        varchar(50),   
dossier_id                        varchar(50),   
patient_id                        int,           
mothers_first_name                varchar(255),  
country                           varchar(255),  
registration_encounter_id         int(11),       
department                        varchar(255),  
commune                           varchar(255),  
section_communale                 varchar(255),  
locality                          varchar(255),  
telephone_number                  varchar(255),  
civil_status                      varchar(255),  
occupation                        varchar(255),  
reg_location                      varchar(50),   
reg_location_id                   int(11),       
registration_date                 date,          
registration_entry_date           datetime,      
creator                           int(11),       
user_entered                      varchar(50),   
first_encounter_date              date,          
last_encounter_date               date,          
name                              varchar(50),   
family_name                       varchar(50),   
dob                               date,          
dob_estimated                     bit,           
gender                            varchar(2),    
dead                              bit,           
death_date                        date,          
cause_of_death_concept_id         int(11),       
cause_of_death                    varchar(100), 
last_modified_patient             datetime,     
last_modified_datetime            datetime,     
last_modified_person_datetime     datetime,     
last_modified_name_datetime       datetime,     
last_modified_address_datetime    datetime,     
last_modified_attributes_datetime datetime,     
last_modified_obs_datetime        datetime,
last_modified_registration_datetime datetime,
patient_uuid                      varchar(38),
patient_url                       text
);

-- load all patients
insert into temp_patients (patient_id,last_modified_patient) 
select patient_id,COALESCE(date_changed, date_created) from patient p where p.voided = 0;

create index temp_patients_pi on temp_patients(patient_id);

-- person info
update temp_patients t
inner join person p on p.person_id = t.patient_id
set t.gender = p.gender,
	t.dob = p.birthdate,
	t.dob_estimated = p.birthdate_estimated,
	t.dead = p.dead,
	t.death_date = date(p.death_date),
	t.cause_of_death_concept_id = p.cause_of_death,
	t.last_modified_person_datetime = COALESCE(date_changed,date_created),
    t.patient_uuid = p.uuid; 

update temp_patients t set cause_of_death = concept_name(cause_of_death_concept_id,@locale);

-- name info
update temp_patients t
inner join person_name n on n.person_name_id =
	(select n2.person_name_id from person_name n2
	where n2.person_id = t.patient_id
	order by preferred desc, date_created desc limit 1)
set t.name = n.given_name,
	t.family_name = n.family_name,
	t.last_modified_name_datetime = COALESCE(date_changed,date_created);

-- address info
update temp_patients t
inner join person_address a on a.person_address_id =
	(select a2.person_address_id from person_address a2
	where a2.person_id = t.patient_id
	order by preferred desc, date_created desc limit 1)
set t.country = a.country,
	t.department = a.state_province,
	t.commune = a.city_village,
	t.section_communale = a.address3,
	t.locality = a.address1,
	t.last_modified_address_datetime = COALESCE(date_changed,date_created);

-- identifiers
update temp_patients t set emr_id = patient_identifier(patient_id,'a541af1e-105c-40bf-b345-ba1fd6a59b85');
update temp_patients t set hiv_emr_id = patient_identifier(patient_id, '139766e8-15f5-102d-96e4-000c29c2a5d7');
update temp_patients t set dossier_id = patient_identifier(patient_id, 'e66645eb-03a8-4991-b4ce-e87318e37566');

-- person attributes
select person_attribute_type_id into @telephone from person_attribute_type where name = 'Telephone Number' ;
select person_attribute_type_id into @motherName from person_attribute_type where name = 'First Name of Mother' ;
update temp_patients t set telephone_number = person_attribute_value(patient_id,'Telephone Number');
update temp_patients t set mothers_first_name = person_attribute_value(patient_id,'First Name of Mother');
update temp_patients t set last_modified_attributes_datetime =
	(select max(COALESCE(date_changed,date_created)) from person_attribute a 
	where a.person_id = t.patient_id
	and a.voided = 0
	and a.person_attribute_type_id in (@telephone, @motherName));

-- registration encounter
update temp_patients t set registration_encounter_id = latestEnc(patient_id,'Enregistrement de patient',null);
create index temp_patients_pri on temp_patients(registration_encounter_id); 

-- registration encounter fields
update temp_patients t 
inner join encounter e on e.encounter_id = t.registration_encounter_id
set t.reg_location_id = e.location_id,
	t.registration_entry_date = e.date_created,
	t.registration_date = date(e.encounter_datetime),
	t.creator = e.creator,
    t.last_modified_registration_datetime = e.date_changed ;

update temp_patients t set reg_location = location_name(reg_location_id);
update temp_patients t set user_entered = person_name_of_user(creator);

-- registration obs

set @civilStatus = concept_from_mapping('PIH','1054');
set @occupation = concept_from_mapping('PIH','1304');

DROP TABLE IF EXISTS temp_obs;
CREATE TEMPORARY TABLE temp_obs AS
SELECT o.person_id, o.obs_id ,o.obs_group_id, o.obs_datetime, o.date_created, o.encounter_id, o.value_coded, o.concept_id, o.value_numeric, o.voided, o.value_drug
from obs o
inner join temp_patients t on t.registration_encounter_id = o.encounter_id
WHERE o.voided = 0;
create index temp_obs_ci1 on temp_obs(encounter_id, concept_id);
create index temp_obs_pi on temp_obs(person_id);

update temp_patients t set civil_status = obs_value_coded_list_from_temp(t.registration_encounter_id, 'PIH','1054',@locale );
update temp_patients t set occupation = obs_value_coded_list_from_temp(t.registration_encounter_id, 'PIH','1304',@locale );
update temp_patients t set last_modified_obs_datetime = 
	(select max(o.date_created) from temp_obs o where o.person_id = t.patient_id);

-- first/latest encounter
update temp_patients t set first_encounter_date = (select date(min(encounter_datetime)) from encounter e where e.patient_id = t.patient_id);
update temp_patients t set last_encounter_date = (select date(max(encounter_datetime)) from encounter e where e.patient_id = t.patient_id);

-- set last modified datetime to most recent of all the changes
update temp_patients t set last_modified_datetime =
	greatest(ifnull(last_modified_person_datetime,last_modified_patient),
			ifnull(last_modified_name_datetime,last_modified_patient),
			ifnull(last_modified_address_datetime,last_modified_patient),
			ifnull(last_modified_attributes_datetime,last_modified_patient),
			ifnull(last_modified_obs_datetime,last_modified_patient),
            ifnull(last_modified_registration_datetime,last_modified_patient),
			last_modified_patient);

-- patient url
set @site_url = SUBSTRING_INDEX(global_property_value('host.url',null), "/", 4);
update temp_patients t 
set patient_url = concat(@site_url,'/coreapps/clinicianfacing/patient.page?patientId=',patient_uuid);

-- final output
SELECT 
emr_id,
hiv_emr_id,
dossier_id,
concat(@partition,"-",patient_id) patient_id,
mothers_first_name,
country,
department,
commune,
section_communale,
locality,
telephone_number,
civil_status,
occupation,
reg_location,
registration_date,
registration_entry_date,
user_entered,
first_encounter_date,
last_encounter_date,
name,
family_name,
dob,
dob_estimated,
gender,
dead,
death_date,
cause_of_death,
last_modified_datetime,
patient_url
FROM temp_patients;
