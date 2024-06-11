SET @locale = GLOBAL_PROPERTY_VALUE('default_locale', 'en');
SET @partition = '${partitionNum}';

DROP TEMPORARY TABLE IF EXISTS temp_diagnoses;
CREATE TEMPORARY TABLE temp_diagnoses
(
 patient_id               int(11),      
 encounter_id             int(11),      
 obs_id                   int(11),      
 obs_datetime             datetime,     
 diagnosis_entered        text,         
 dx_order                 varchar(255), 
 certainty                varchar(255), 
 coded                    varchar(255), 
 non_coded                text,
 diagnosis_concept        int(11),      
 diagnosis_coded_fr       varchar(255), 
 dossierId                varchar(50),  
 patient_primary_id       varchar(50),  
 loc_registered           varchar(255), 
 unknown_patient          varchar(50),  
 gender                   varchar(50),  
 department               varchar(255), 
 commune                  varchar(255), 
 section                  varchar(255),  
 locality                 varchar(255), 
 street_landmark          varchar(255), 
 birthdate                datetime,     
 birthdate_estimated      boolean,      
 section_communale_CDC_ID varchar(11),   
 encounter_location       varchar(255), 
 age_at_encounter         int(3),       
 entered_by               varchar(255), 
 provider                 varchar(255), 
 date_created             datetime,     
 retrospective            int(1),       
 visit_id                 int(11),      
 encounter_type           varchar(255), 
 icd10_code               varchar(255), 
 notifiable               int(1),       
 urgent                   int(1),       
 santeFamn                int(1),       
 psychological            int(1),       
 pediatric                int(1),       
 outpatient               int(1),       
 ncd                      int(1),       
 non_diagnosis            int(1),        
 ed                       int(1),        
 age_restricted           int(1),       
 oncology                 int(1)        
);

insert into temp_diagnoses (
patient_id,
encounter_id,
obs_id,
obs_datetime,
date_created 
)
select 
o.person_id,
o.encounter_id,
o.obs_id,
o.obs_datetime,
o.date_created 
from obs o 
where concept_id = concept_from_mapping('PIH','Visit Diagnoses')
AND o.voided = 0
;

create index temp_diagnoses_e on temp_diagnoses(encounter_id);
create index temp_diagnoses_p on temp_diagnoses(patient_id);
create index temp_diagnoses_o on temp_diagnoses(obs_id);

-- patient level info
DROP TEMPORARY TABLE IF EXISTS temp_dx_patient;
CREATE TEMPORARY TABLE temp_dx_patient
(
patient_id               int(11),      
dossierId                varchar(50),  
patient_primary_id       varchar(50),  
loc_registered           varchar(255), 
unknown_patient          varchar(50),  
gender                   varchar(50),  
department               varchar(255), 
commune                  varchar(255), 
section                  varchar(255),  
locality                 varchar(255), 
street_landmark          varchar(255), 
birthdate                datetime,     
birthdate_estimated      boolean,      
section_communale_CDC_ID varchar(11)   
);
   
insert into temp_dx_patient(patient_id)
select distinct patient_id from temp_diagnoses;

create index temp_dx_patient_pi on temp_dx_patient(patient_id);

update temp_dx_patient set patient_primary_id = patient_identifier(patient_id, metadata_uuid('org.openmrs.module.emrapi', 'emr.primaryIdentifierType'));
update temp_dx_patient set dossierid = dosid(patient_id);
update temp_dx_patient set loc_registered = loc_registered(patient_id);
update temp_dx_patient set unknown_patient = unknown_patient(patient_id);
update temp_dx_patient set gender = gender(patient_id);

update temp_dx_patient t
inner join person p on p.person_id  = t.patient_id
set t.birthdate = p.birthdate,
	t.birthdate_estimated = p.birthdate_estimated;

update temp_dx_patient set department = person_address_state_province(patient_id);
update temp_dx_patient set commune = person_address_city_village(patient_id);
update temp_dx_patient set section = person_address_three(patient_id);
update temp_dx_patient set locality = person_address_one(patient_id);
update temp_dx_patient set street_landmark = person_address_two(patient_id);
update temp_dx_patient set section_communale_CDC_ID = cdc_id(patient_id);

update temp_diagnoses t
inner join temp_dx_patient p on p.patient_id = t.patient_id
set t.patient_primary_id = p.patient_primary_id,
	t.dossierId = p.dossierid,
	t.loc_registered = p.loc_registered,
	t.unknown_patient = p.unknown_patient,
	t.gender = p.gender,
	t.department = p.department,
	t.commune = p.commune,
	t.section = p.section,
	t.locality = p.locality,
	t.street_landmark = p.street_landmark,
	t.birthdate = p.birthdate,
	t.birthdate_estimated = p.birthdate_estimated,
	t.section_communale_CDC_ID = p.section_communale_CDC_ID;

-- encounter level information
DROP TEMPORARY TABLE IF EXISTS temp_dx_encounter;
CREATE TEMPORARY TABLE temp_dx_encounter
(
 encounter_id        int(11),      
 location_id         int(11),      
 encounter_location  varchar(255), 
 age_at_encounter    int(3),       
 creator             int(11),      
 entered_by          varchar(255), 
 provider            varchar(255), 
 date_created        datetime,     
 retrospective       int(1),       
 visit_id            int(11),      
 birthdate           datetime,     
 birthdate_estimated boolean,      
 encounter_type_id   int(11),      
 encounter_type      varchar(255)  
);
   
insert into temp_dx_encounter(encounter_id)
select distinct encounter_id from temp_diagnoses;

create index temp_dx_encounter_ei on temp_dx_encounter(encounter_id);

update temp_dx_encounter t
inner join encounter e on e.encounter_id  = t.encounter_id
set t.location_id = e.location_id, 
    t.creator = e.creator, 
    t.date_created = e.date_created, 
    t.visit_id = e.visit_id,
    t.encounter_type_id = e.encounter_type ; 

update temp_dx_encounter set encounter_location = location_name(location_id);
update temp_dx_encounter set provider = provider(encounter_id);
update temp_dx_encounter set entered_by = person_name_of_user(creator);
update temp_dx_encounter set encounter_type = encounter_type_name_from_id(encounter_type_id);


update temp_diagnoses t
inner join temp_dx_encounter e on e.encounter_id = t.encounter_id
set t.encounter_location = e.encounter_location,
	t.entered_by = e.entered_by,
	t.provider = e.provider,
	t.date_created = e.date_created,
	t.retrospective = e.retrospective,
	t.visit_id = e.visit_id,
	t.encounter_type = e.encounter_type;

update temp_diagnoses t set age_at_encounter = CEILING(DATEDIFF(NOW(), birthdate) / 365);

 -- diagnosis info
DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.value_coded_name_id ,o.comments 
from obs o
inner join temp_diagnoses t on t.obs_id = o.obs_group_id
where o.voided = 0;


create index temp_obs_concept_id on temp_obs(concept_id);
create index temp_obs_ogi on temp_obs(obs_group_id);
create index temp_obs_ci1 on temp_obs(obs_group_id, concept_id);
set @coded_dx = concept_from_mapping('PIH','DIAGNOSIS');
set @non_coded_dx = concept_from_mapping('PIH','Diagnosis or problem, non-coded');
set @dx_certainty = concept_from_mapping('PIH','1379');
set @dx_order = concept_from_mapping('PIH','7537');
drop temporary table if exists temp_obs_collated;
create temporary table temp_obs_collated 
select obs_group_id,
max(case when concept_id = @coded_dx then value_coded end) value_coded,
max(case when concept_id = @coded_dx then 1 end) coded,
max(case when concept_id = @coded_dx then concept_name(value_coded,'fr') end) diagnosis_coded_fr,
max(case when concept_id = @non_coded_dx then value_text end) non_coded,
max(case when concept_id = @dx_certainty then concept_name(value_coded,@locale) end) certainty,
max(case when concept_id = @dx_order then concept_name(value_coded,@locale) end) dx_order
from temp_obs
group by obs_group_id;

create index temp_obs_collated_ogi on temp_obs_collated(obs_group_id);

update temp_diagnoses t
inner join temp_obs_collated o on o.obs_group_id = t.obs_id
set t.diagnosis_coded_fr = o.diagnosis_coded_fr,
    t.non_coded = o.non_coded,
    t.dx_order = o.dx_order,
    t.certainty = o.certainty,
    t.diagnosis_concept = o.value_coded,
    t.coded = o.coded;

update temp_diagnoses t
set diagnosis_entered = IFNULL(t.diagnosis_coded_fr,t.non_coded);

-- diagnosis concept-level info
DROP TEMPORARY TABLE IF EXISTS temp_dx_concept;
CREATE TEMPORARY TABLE temp_dx_concept
(
 diagnosis_concept int(11),       
 icd10_code        varchar(255), 
 notifiable        int(1),       
 urgent            int(1),       
 santeFamn         int(1),       
 psychological     int(1),       
 pediatric         int(1),       
 outpatient        int(1),       
 ncd               int(1),       
 non_diagnosis     int(1),        
 ed                int(1),        
 age_restricted    int(1),       
 oncology          int(1)        
);
   
insert into temp_dx_concept(diagnosis_concept)
select distinct diagnosis_concept from temp_diagnoses;

create index temp_dx_patient_dc on temp_dx_concept(diagnosis_concept);

update temp_dx_concept set icd10_code = retrieveICD10(diagnosis_concept);
    
select concept_id into @non_diagnoses from concept where uuid = 'a2d2124b-fc2e-4aa2-ac87-792d4205dd8d';  

set @notifiable = concept_from_mapping('PIH','8612');
set @santeFamn = concept_from_mapping('PIH','7957');
set @urgent = concept_from_mapping('PIH','7679');
set @psychological = concept_from_mapping('PIH','7942');
set @pediatric = concept_from_mapping('PIH','7933');
set @outpatient = concept_from_mapping('PIH','7936');
set @ncd = concept_from_mapping('PIH','7935');
set @ed = concept_from_mapping('PIH','7934');
set @age_restricted = concept_from_mapping('PIH','7677');
set @oncology = concept_from_mapping('PIH','8934');
update temp_dx_concept set notifiable = concept_in_set(diagnosis_concept, @notifiable);
update temp_dx_concept set santeFamn = concept_in_set(diagnosis_concept, @santeFamn);
update temp_dx_concept set urgent = concept_in_set(diagnosis_concept, @urgent);
update temp_dx_concept set psychological = concept_in_set(diagnosis_concept, @psychological);
update temp_dx_concept set pediatric = concept_in_set(diagnosis_concept, @pediatric);
update temp_dx_concept set outpatient = concept_in_set(diagnosis_concept, @outpatient);
update temp_dx_concept set ncd = concept_in_set(diagnosis_concept, @ncd);
update temp_dx_concept set non_diagnosis = concept_in_set(diagnosis_concept, @non_diagnoses);
update temp_dx_concept set ed = concept_in_set(diagnosis_concept, @ed);
update temp_dx_concept set age_restricted = concept_in_set(diagnosis_concept, @age_restricted);
update temp_dx_concept set oncology = concept_in_set(diagnosis_concept, @oncology);
    
update temp_diagnoses t
inner join temp_dx_concept c on c.diagnosis_concept = t.diagnosis_concept
set t.icd10_code = c.icd10_code,
	t.notifiable = c.notifiable,
	t.urgent = c.urgent,
	t.santeFamn = c.santeFamn,
	t.psychological = c.psychological,
	t.pediatric = c.pediatric,
	t.outpatient = c.outpatient,
	t.ncd = c.ncd,
	t.non_diagnosis = c.non_diagnosis,
	t.ed = c.ed,
	t.age_restricted = c.age_restricted,
	t.oncology = c.oncology;

-- select final output
select 
CONCAT(@partition, '-', patient_id) as patient_id,
dossierId,
patient_primary_id,
loc_registered,
unknown_patient,
gender,
age_at_encounter,
department,
commune,
section,
locality,
street_landmark,
CONCAT(@partition, '-', encounter_id) as encounter_id,
encounter_location,
CONCAT(@partition, '-', obs_id) as obs_id,
obs_datetime,
entered_by,
provider,
diagnosis_entered,
dx_order,
certainty,
coded,
diagnosis_concept,
diagnosis_coded_fr,
icd10_code,
notifiable,
urgent,
santeFamn,
psychological,
pediatric,
outpatient,
ncd,
non_diagnosis,
ed,
age_restricted,
oncology,
date_created,
IF(TIME_TO_SEC(date_created) - TIME_TO_SEC(obs_datetime) > 1800,1,0) "retrospective",
CONCAT(@partition, '-', visit_id) as visit_id,
birthdate,
birthdate_estimated,
encounter_type,
section_communale_CDC_ID
from temp_diagnoses;
