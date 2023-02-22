set @locale =   if(@startDate is null, 'en', global_property_value('default_locale', 'en'));
set @mch_encounter = (select encounter_type_id from encounter_type where uuid = '00e5ebb2-90ec-11e8-9eb6-529269fb1459');
set sql_safe_updates = 0;

drop temporary table if exists temp_mch_diagnoses;
create temporary table temp_mch_diagnoses
(
	patient_id  int,
	encounter_id int,
	encounter_location  varchar(255),
	obs_id  int,
	obs_group_id int,
	obs_datetime datetime,
	visit_id int,
	encounter_type varchar(100),
	entered_by varchar(255),
	provider varchar(255),
	diagnosis_concept int,
	diagnosis_entered   text,
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
	sti bit,
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
if(o.value_coded is null, o.value_text, concept_name(o.value_coded,'en')),
concept_name(o.value_coded,'fr'),
if(o.value_coded is null, 0,1),
if(time_to_sec(date_created) - time_to_sec(obs_datetime) > 1800,1,0)
from obs o 
where 
concept_id in (concept_from_mapping('PIH','DIAGNOSIS'), concept_from_mapping('PIH','Diagnosis or problem, non-coded'))
and obs_group_id in (select obs_id from obs o1 where voided = 0 and concept_id = concept_from_mapping('PIH','Visit Diagnoses'))
and encounter_id in (select encounter_id from encounter e where voided = 0 and encounter_type = @mch_encounter)
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

update temp_mch_diagnoses set encounter_location = encounter_location_name(encounter_id);
update temp_mch_diagnoses set entered_by = encounter_creator_name(encounter_id);
update temp_mch_diagnoses set provider = provider(encounter_id);

update temp_mch_diagnoses t set t.dx_order = (select concept_name(o.value_coded, @locale) 
from obs o where voided = 0 and o.concept_id = concept_from_mapping( 'PIH','7537') and t.obs_group_id = o.obs_group_id
);

update temp_mch_diagnoses t set t.certainty = (select concept_name(o.value_coded, @locale) 
from obs o where voided = 0 and o.concept_id = concept_from_mapping( 'PIH','1379') and t.obs_group_id = o.obs_group_id
);


update temp_mch_diagnoses set icd10_code = retrieveicd10(diagnosis_concept);

update temp_mch_diagnoses tm set sti = if(diagnosis_concept in (
concept_from_mapping('PIH', '893'), 
concept_from_mapping('PIH', '7247'), 
concept_from_mapping('PIH', '7120'),
concept_from_mapping('PIH', '174'),
concept_from_mapping('PIH', '14363'), 
concept_from_mapping('PIH', '11194'),
concept_from_mapping('PIH', '3728'),
concept_from_mapping('PIH', '2155'),
concept_from_mapping('CIEL', '112992'),
concept_from_mapping('CIEL', '120733')
), 1, 0);

select 
	   patient_id,
       encounter_id,
       encounter_location,
       obs_id,
       obs_datetime,
       visit_id,
       encounter_type,
       entered_by,
       provider,
       diagnosis_concept,
       diagnosis_entered,
       diagnosis_coded_fr,
       icd10_code,
       dx_order,
       certainty,
       coded,
       retrospective,
       date_created,
       abortion,
       abortion_with_sepsis,
       anemia,
       cervical_cancer,
       cervical_laceration,
       complete_abortion,
       diabetes,
       dystocia,
       eclampsia,
       hemorrhage,
       hypertension,
       incomplete_abortion,
       induced_abortion,
       postpartum_hemorrhage,
       laceration_of_perineum,
       malaria,
       postnatal_complication,
       preeclampsia,
       puerperal_infection,
       spontaneous_abortion,
       sti,
       threatened_abortion
 from temp_mch_diagnoses order by patient_id, encounter_id;