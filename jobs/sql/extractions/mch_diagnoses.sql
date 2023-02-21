SET @locale =   if(@startDate is null, 'en', GLOBAL_PROPERTY_VALUE('default_locale', 'en'));
SET @mch_encounter = (select encounter_type_id from encounter_type where uuid = '00e5ebb2-90ec-11e8-9eb6-529269fb1459');
SET sql_safe_updates = 0;

DROP TEMPORARY TABLE IF EXISTS temp_mch_diagnoses;
CREATE TEMPORARY TABLE temp_mch_diagnoses
(
	patient_id                      int(11),
 	encounter_id			int(11),
    encounter_location				varchar(255),
	obs_id				int(11),
    obs_group_id int,
	obs_datetime			datetime,
    visit_id int,
    encounter_type varchar(100),
    entered_by					varchar(255),
	provider					varchar(255),
    diagnosis_concept	int(11),
	diagnosis_entered	text,
    diagnosis_coded_fr	varchar(255),
    icd10_code			varchar(255),
	dx_order			varchar(255),
	certainty			varchar(255),
	coded				varchar(255),
    retrospective		int(1),
 	date_created		datetime,
    abortion bit,
    abortion_with_sepsis bit,
    anemia bit,
    cervical_cancer bit,
    cervical_laceration bit,
    complete_abortion bit,
    diabetes int,
    dystocia bit,
eclampsia bit,
hemorrhage bit,
hypertension bit,
incomplete_abortion bit,
induced_abortion bit,
postpartum_hemorrhage bit,
laceration_of_perineum bit,
malaria bit,
postnatal_complication bit,
preeclampsia bit,
puerperal_infection bit,
spontaneous_abortion bit,
threatened_abortion bit
    );

insert into temp_mch_diagnoses (
patient_id,
encounter_id,
obs_id,
obs_group_id,
obs_datetime,
encounter_type,
date_created,
diagnosis_concept,
diagnosis_entered,
diagnosis_coded_fr,
coded,
retrospective
)
select 
person_id,
encounter_id,
obs_id,
obs_group_id,
obs_datetime,
encounter_type_name(encounter_id),
date_created,
value_coded,
IF(o.value_coded is null, o.value_text, concept_name(o.value_coded,'en')),
concept_name(o.value_coded,'fr'),
IF(o.value_coded is null, 0,1),
IF(TIME_TO_SEC(date_created) - TIME_TO_SEC(obs_datetime) > 1800,1,0)
from obs o 
WHERE 
concept_id in (concept_from_mapping('PIH','DIAGNOSIS'), concept_from_mapping('PIH','Diagnosis or problem, non-coded'))
AND obs_group_id in (select obs_id from obs o1 where voided = 0 and concept_id = concept_from_mapping('PIH','Visit Diagnoses'))
AND encounter_id in (select encounter_id from encounter e where voided = 0 and encounter_type = @mch_encounter)
;

update temp_mch_diagnoses tm set visit_id = (select visit_id from encounter e where e.voided = 0 and tm.encounter_id = e.encounter_id);

-- Categories
-- Abortion

update temp_mch_diagnoses tm set abortion = if(diagnosis_concept in (concept_from_mapping('CIEL', '120295'), concept_from_mapping('PIH', '7697'), concept_from_mapping('CIEL', '162206')), 1, 0);
update temp_mch_diagnoses tm set abortion_with_sepsis = if(diagnosis_concept = concept_from_mapping('CIEL', '150746'), 1, 0);
update temp_mch_diagnoses tm set anemia = if(diagnosis_concept in (
concept_from_mapping('CIEL', '149566'), 
concept_from_mapping('PIH', '3703'), 
concept_from_mapping('CIEL', '1226'),
concept_from_mapping('CIEL', '137932'),
concept_from_mapping('CIEL', '162042'), 
concept_from_mapping('PIH', '9325'),
concept_from_mapping('PIH', '9088'),
concept_from_mapping('PIH', '9089'),
concept_from_mapping('PIH', '3'),
concept_from_mapping('PIH', 'ANEMIA OF PREGNANCY'),
concept_from_mapping('PIH', '9431')
), 1, 0);

update temp_mch_diagnoses tm set cervical_cancer = if(diagnosis_concept = concept_from_mapping('CIEL', '116023'), 1, 0);

update temp_mch_diagnoses tm set cervical_laceration = if(diagnosis_concept = 
concept_from_mapping('CIEL', '145804'), 1, 0);

update temp_mch_diagnoses tm set complete_abortion = if(diagnosis_concept = 
concept_from_mapping('CIEL', '120295'), 1, 0);

update temp_mch_diagnoses tm set diabetes = if(diagnosis_concept in (
concept_from_mapping('PIH', '7961'), 
concept_from_mapping('PIH', '6693'), 
concept_from_mapping('PIH', '6691'),
concept_from_mapping('PIH', '6692'),
concept_from_mapping('PIH', '8538'), 
concept_from_mapping('PIH', '11943'),
concept_from_mapping('PIH', '11944'),
concept_from_mapping('PIH', '12227'),
concept_from_mapping('PIH', '12228'),
concept_from_mapping('PIH', '12251'),
concept_from_mapping('PIH', '8574'),
concept_from_mapping('PIH', '11441'),
concept_from_mapping('PIH', '9562'),
concept_from_mapping('PIH', '12632'),
concept_from_mapping('PIH', '3720'),
concept_from_mapping('PIH', '225'),
concept_from_mapping('PIH', '7961'),
concept_from_mapping('PIH', '6693')
), 1, 0);

update temp_mch_diagnoses tm set dystocia = if(diagnosis_concept in (
concept_from_mapping('PIH', '8017'), 
concept_from_mapping('PIH', '8031')
), 1, 0);

update temp_mch_diagnoses tm set eclampsia = if(diagnosis_concept = 
concept_from_mapping('PIH', '7696'), 1, 0);

update temp_mch_diagnoses tm set hemorrhage = if(diagnosis_concept in
(
concept_from_mapping('PIH', '228'),
concept_from_mapping('PIH', '7235'),
concept_from_mapping('PIH', '7102')
), 1, 0);

update temp_mch_diagnoses tm set hypertension = if(diagnosis_concept in
(
concept_from_mapping('PIH', '6847'),
concept_from_mapping('PIH', '903'),
concept_from_mapping('PIH', '12629'),
concept_from_mapping('PIH', '12634'),
concept_from_mapping('PIH', '14307'),
concept_from_mapping('PIH', '9058')
), 1, 0);

update temp_mch_diagnoses tm set incomplete_abortion = if(diagnosis_concept in
(
concept_from_mapping('PIH', '9333'),
concept_from_mapping('PIH', '9727'),
concept_from_mapping('PIH', '905'),
concept_from_mapping('PIH', '9335'),
concept_from_mapping('PIH', '8319')
), 1, 0);

update temp_mch_diagnoses tm set induced_abortion = if(diagnosis_concept = 
concept_from_mapping('PIH', '9727'), 1, 0);

update temp_mch_diagnoses tm set postpartum_hemorrhage = if(diagnosis_concept =
concept_from_mapping('PIH', '49'), 1, 0);

update temp_mch_diagnoses tm set laceration_of_perineum = if(diagnosis_concept in
(
concept_from_mapping('CIEL', '123620'),
concept_from_mapping('PIH', '12372'),
concept_from_mapping('PIH', '7230')
), 1, 0);


update temp_mch_diagnoses tm set malaria = if(diagnosis_concept in
(
concept_from_mapping('CIEL', '11487'),
concept_from_mapping('PIH', '7134'),
concept_from_mapping('PIH', '7646'),
concept_from_mapping('CIEL', '123'),
concept_from_mapping('PIH', '7568')
), 1, 0);

update temp_mch_diagnoses tm set postnatal_complication = if(diagnosis_concept = 
concept_from_mapping('PIH', '7252'), 1, 0);

update temp_mch_diagnoses tm set preeclampsia = if(diagnosis_concept in
(
concept_from_mapping('PIH', '8354'),
concept_from_mapping('PIH', '9344'),
concept_from_mapping('PIH', '47'),
concept_from_mapping('CIEL', '129251')
), 1, 0);

update temp_mch_diagnoses tm set puerperal_infection = if(diagnosis_concept in
(
concept_from_mapping('PIH', '9333'),
concept_from_mapping('PIH', '130')
), 1, 0);

update temp_mch_diagnoses tm set spontaneous_abortion = if(diagnosis_concept in
(
concept_from_mapping('PIH', '7252'),
concept_from_mapping('PIH', '7238')
), 1, 0);

update temp_mch_diagnoses tm set threatened_abortion = if(diagnosis_concept
= concept_from_mapping('PIH', '7993'), 1, 0);

/*
update temp_diagnoses t
 left outer join temp_obs o on o.obs_group_id = t.obs_id and o.concept_id = concept_from_mapping('PIH','DIAGNOSIS')
 left outer join obs o_non on o_non.obs_group_id = t.obs_id and o_non.concept_id = concept_from_mapping('PIH','Diagnosis or problem, non-coded') 
 left outer join concept_name cn on cn.concept_name_id  = o.value_coded_name_id 
 set t.diagnosis_entered = , 
 	 t.diagnosis_concept = o.value_coded,
     t.,
     */


update temp_mch_diagnoses set encounter_location = encounter_location_name(encounter_id);
update temp_mch_diagnoses set entered_by = encounter_creator_name(encounter_id);
update temp_mch_diagnoses set provider = provider(encounter_id);

update temp_mch_diagnoses t set t.dx_order = (select concept_name(o.value_coded, @locale) 
from obs o where voided = 0 and o.concept_id = concept_from_mapping( 'PIH','7537') and t.obs_group_id = o.obs_group_id
);

update temp_mch_diagnoses t set t.certainty = (select concept_name(o.value_coded, @locale) 
from obs o where voided = 0 and o.concept_id = concept_from_mapping( 'PIH','1379') and t.obs_group_id = o.obs_group_id
);


update temp_mch_diagnoses set icd10_code = retrieveICD10(diagnosis_concept);
/*
update s t
 left outer join temp_obs o on o.obs_group_id = t.obs_id and o.concept_id = concept_from_mapping('PIH','DIAGNOSIS')
 left outer join obs o_non on o_non.obs_group_id = t.obs_id and o_non.concept_id = concept_from_mapping('PIH','Diagnosis or problem, non-coded') 
 left outer join concept_name cn on cn.concept_name_id  = o.value_coded_name_id 
 set t.diagnosis_entered = IFNULL(cn.name,IFNULL( concept_name(o.value_coded,'en'),o_non.value_text)), 
 	 t.diagnosis_concept = o.value_coded,
     t.diagnosis_coded_fr = concept_name(o.value_coded,'fr'),
     t.coded = IF(o.value_coded is null, 0,1);
*/

select * from temp_mch_diagnoses;
/*
create index temp_mch_diagnoses_e on temp_mch_diagnoses(encounter_id);
create index temp_mch_diagnoses_p on temp_mch_diagnoses(patient_id);

-- patient level info
DROP TEMPORARY TABLE IF EXISTS temp_dx_patient;
CREATE TEMPORARY TABLE temp_dx_patient
(
patient_id                      int(11),
dossierId                       varchar(50),
patient_primary_id              varchar(50),
loc_registered                  varchar(255),
unknown_patient			varchar(50),
gender				varchar(50),
department			varchar(255),
commune				varchar(255),
section				varchar(255),	
locality			varchar(255),
street_landmark			varchar(255),
birthdate			datetime,
birthdate_estimated		boolean,
section_communale_CDC_ID	varchar(11)	
    );
   
insert into temp_dx_patient(patient_id)
select distinct patient_id from temp_mch_diagnoses;

create index temp_dx_patient_pi on temp_dx_patient(patient_id);

update temp_dx_patient set patient_primary_id = patient_identifier(patient_id, metadata_uuid('org.openmrs.module.emrapi', 'emr.primaryIdentifierType'));
update temp_dx_patient set dossierid = dosid(patient_id);
update temp_dx_patient set loc_registered = loc_registered(patient_id);
update temp_dx_patient set unknown_patient = unknown_patient(patient_id);
update temp_dx_patient set gender = gender(patient_id);

update temp_dx_patient t
inner join person p on p.person_id  = t.patient_id
set t.birthdate = p.birthdate,
	t.birthdate_estimated = t.birthdate_estimated
;

update temp_dx_patient set department = person_address_state_province(patient_id);
update temp_dx_patient set commune = person_address_city_village(patient_id);
update temp_dx_patient set section = person_address_three(patient_id);
update temp_dx_patient set locality = person_address_one(patient_id);
update temp_dx_patient set street_landmark = person_address_two(patient_id);
update temp_dx_patient set section_communale_CDC_ID = cdc_id(patient_id);

-- encounter level information
DROP TEMPORARY TABLE IF EXISTS temp_dx_encounter;
CREATE TEMPORARY TABLE temp_dx_encounter
(
    	patient_id					int(11),
	encounter_id					int(11),
	
    	age_at_encounter				int(3),
	
	date_created					datetime,
	
	visit_id					int(11),
	birthdate					datetime,
	birthdate_estimated				boolean,
	encounter_type					varchar(255)
    );
   
insert into temp_dx_encounter(patient_id,encounter_id)
select distinct patient_id, encounter_id from temp_mch_diagnoses;

create index temp_dx_encounter_ei on temp_dx_encounter(encounter_id);


update temp_dx_encounter set age_at_encounter = age_at_enc(patient_id, encounter_id);


update temp_dx_encounter t
inner join encounter e on e.encounter_id  = t.encounter_id
inner join users u on u.user_id = e.creator 
set t.entered_by = person_name(u.person_id),
	t.visit_id = e.visit_id,
	t.encounter_type = encounterName(e.encounter_type);


       
 -- diagnosis info
DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.value_coded_name_id ,o.comments 
from obs o
inner join temp_mch_diagnoses t on t.obs_id = o.obs_group_id
where o.voided = 0;

create index temp_obs_concept_id on temp_obs(concept_id);
create index temp_obs_ogi on temp_obs(obs_group_id);
create index temp_obs_ci1 on temp_obs(obs_group_id, concept_id);

       
 
update temp_mch_diagnoses t
inner join temp_obs o on o.obs_group_id = t.obs_id and o.concept_id = concept_from_mapping( 'PIH','7537')
set t.dx_order = concept_name(o.value_coded, @locale);

update temp_mch_diagnoses t
inner join temp_obs o on o.obs_group_id = t.obs_id and o.concept_id = concept_from_mapping( 'PIH','1379')
set t.certainty = concept_name(o.value_coded, @locale);

-- diagnosis concept-level info
DROP TEMPORARY TABLE IF EXISTS temp_dx_concept;
CREATE TEMPORARY TABLE temp_dx_concept
(
	diagnosis_concept				int(11),				
	
	notifiable					int(1),
	urgent						int(1),
	santeFamn					int(1),
	psychological					int(1),
	pediatric					int(1),
	outpatient					int(1),
	ncd						int(1),
	non_diagnosis					int(1),	
	ed						int(1),	
	age_restricted					int(1),
	oncology					int(1)
    );
   
insert into temp_dx_concept(diagnosis_concept)
select distinct diagnosis_concept from temp_mch_diagnoses;

create index temp_dx_patient_dc on temp_dx_concept(diagnosis_concept);



    
select concept_id into @non_diagnoses from concept where uuid = 'a2d2124b-fc2e-4aa2-ac87-792d4205dd8d';    
update temp_dx_concept set notifiable = concept_in_set(diagnosis_concept, concept_from_mapping('PIH','8612'));
update temp_dx_concept set santeFamn = concept_in_set(diagnosis_concept, concept_from_mapping('PIH','7957'));
update temp_dx_concept set urgent = concept_in_set(diagnosis_concept, concept_from_mapping('PIH','7679'));
update temp_dx_concept set psychological = concept_in_set(diagnosis_concept, concept_from_mapping('PIH','7942'));
update temp_dx_concept set pediatric = concept_in_set(diagnosis_concept, concept_from_mapping('PIH','7933'));
update temp_dx_concept set outpatient = concept_in_set(diagnosis_concept, concept_from_mapping('PIH','7936'));
update temp_dx_concept set ncd = concept_in_set(diagnosis_concept, concept_from_mapping('PIH','7935'));
update temp_dx_concept set non_diagnosis = concept_in_set(diagnosis_concept, @non_diagnoses);
update temp_dx_concept set ed = concept_in_set(diagnosis_concept, concept_from_mapping('PIH','7934'));
update temp_dx_concept set age_restricted = concept_in_set(diagnosis_concept, concept_from_mapping('PIH','7677'));
update temp_dx_concept set oncology = concept_in_set(diagnosis_concept, concept_from_mapping('PIH','8934'));
    
-- select final output
select 
p.patient_id,
p.dossierId,
p.patient_primary_id,
p.loc_registered,
p.unknown_patient,
p.gender,
e.age_at_encounter,
p.department,
p.commune,
p.section,
p.locality,
p.street_landmark,
e.encounter_id,
e.encounter_location,
d.obs_id,
d.obs_datetime,
e.entered_by,
e.provider,
d.diagnosis_entered,
d.dx_order,
d.certainty,
d.coded,
d.diagnosis_concept,
d.diagnosis_coded_fr,
dc.icd10_code,
dc.notifiable,
dc.urgent,
dc.santeFamn,
dc.psychological,
dc.pediatric,
dc.outpatient,
dc.ncd,
dc.non_diagnosis,
dc.ed,
dc.age_restricted,
dc.oncology,
e.date_created,

p.birthdate,
p.birthdate_estimated,
e.encounter_type,
p.section_communale_CDC_ID
from temp_mch_diagnoses d
inner join temp_dx_patient p on p.patient_id = d.patient_id
inner join temp_dx_encounter e on e.encounter_id = d.encounter_id
inner join temp_dx_concept dc on dc.diagnosis_concept = d.diagnosis_concept
;