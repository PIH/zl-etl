set @locale =   if(@startDate is null, 'en', global_property_value('default_locale', 'en'));
set @mch_encounter = (select encounter_type_id from encounter_type where uuid = '00e5ebb2-90ec-11e8-9eb6-529269fb1459');
set sql_safe_updates = 0;
set @yes = 1;
set @non = 0;

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
    abortion_with_complication bit,
	abortion_with_sepsis bit,
	anemia bit,
	cervical_cancer bit,
	cervical_laceration bit,
	complete_abortion bit,
	diabetes bit,
	dystocia bit,
	eclampsia bit,
	hemorrhage bit,
	hypertension bit,
	incomplete_abortion bit,
	induced_abortion bit,
	intrapartum_hemorrhage bit,
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
and encounter_id in (select encounter_id from encounter e where voided = 0 and encounter_type = @mch_encounter);

update temp_mch_diagnoses tm set visit_id = (select visit_id from encounter e where e.voided = 0 and tm.encounter_id = e.encounter_id);

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

-- Categories
-- Abortion

set @complete_abortion = concept_from_mapping('PIH', '8001');
set @unspecified_abortion = concept_from_mapping('PIH', '7697');
set @abortion_complicated_by_hemorrhage = concept_from_mapping('PIH', '9334');
set @abortion_with_sepsis = concept_from_mapping('PIH', '8018');

update temp_mch_diagnoses tm set abortion = if(diagnosis_concept in 
(@complete_abortion, 
@unspecified_abortion, 
@abortion_complicated_by_hemorrhage), 
@yes, @non);

-- Abortion with complication
update temp_mch_diagnoses tm set abortion_with_complication = if(diagnosis_concept = @abortion_complicated_by_hemorrhage, @yes, @non);

-- Abortion with sepsis
update temp_mch_diagnoses tm set abortion_with_sepsis = if(diagnosis_concept = @abortion_with_sepsis, @yes, @non);

-- Anemia
set @acute_posthemorrhagic_anemia = concept_from_mapping('PIH', '9325');
set @anemia_in_pregnancy = concept_from_mapping('PIH', '3703');
set @anemia_iron_deficiency = concept_from_mapping('PIH', '1226');
set @idiopathic_aplastic_anemia = concept_from_mapping('PIH', '9052');
set @mild_anemia = concept_from_mapping('PIH', '9087');
set @moderate_anemia = concept_from_mapping('PIH', '9088');
set @severe_anemia = concept_from_mapping('PIH', '9089');
set @anemia = concept_from_mapping('PIH', '3');
set @congenital_anemia_from_fetal_blood_loss = concept_from_mapping('PIH', '9431');

update temp_mch_diagnoses tm set anemia = if(diagnosis_concept in (
@acute_posthemorrhagic_anemia,
@anemia_in_pregnancy,
@anemia_iron_deficiency,
@idiopathic_aplastic_anemia,
@mild_anemia,
@moderate_anemia,
@severe_anemia,
@anemia,
@congenital_anemia_from_fetal_blood_loss
), @yes, @non);

-- Cervical Cancer
set @cervical_cancer = concept_from_mapping('CIEL', '116023');
update temp_mch_diagnoses tm set cervical_cancer = if(diagnosis_concept = @cervical_cancer, @yes, @non);

-- Cervical Laceration
set @cervical_laceration = concept_from_mapping('CIEL', '145804');
update temp_mch_diagnoses tm set cervical_laceration = if(diagnosis_concept = @cervical_laceration, @yes, @non);

-- Complete Abortion
set @complete_abortion = concept_from_mapping('CIEL', '120295');
update temp_mch_diagnoses tm set complete_abortion = if(diagnosis_concept = @complete_abortion, @yes, @non);

-- Diabetes
set @pregestational_diabetes = concept_from_mapping('PIH', '7961');
set @gestational_diabetes = concept_from_mapping('PIH', '6693');
set @type_1_diabetes = concept_from_mapping('PIH', '6691');
set @type_2_diabetes = concept_from_mapping('PIH', '6692');
set @type_2_diabetes_mellitus_peripheral_circulatory = concept_from_mapping('PIH', '8538');
set @insulin_dependent_type_2_diabetes = concept_from_mapping('PIH', '11943');
set @non_insulin_dependent_type_2_diabetes = concept_from_mapping('PIH', '11944');
set @type_2_diabetes_followup_without_hypoglycemic_agents = concept_from_mapping('PIH', '12227');
set @type_2_diabetes_on_oral_agents = concept_from_mapping('PIH', '12228');
set @type_2_diabetes_requiring_insulin = concept_from_mapping('PIH', '12251');
set @diabetes_ketoacidosis = concept_from_mapping('PIH', '8574');
set @diabetic_foot = concept_from_mapping('PIH', '11441');
set @diabetic_arthropathy = concept_from_mapping('PIH', '9562');
set @uncontrolled_diabetes_mellitus = concept_from_mapping('PIH', '12632');
set @diabetes = concept_from_mapping('PIH', '3720');
set @diabetes_insipidus = concept_from_mapping('PIH', '225');

update temp_mch_diagnoses tm set diabetes = if(diagnosis_concept in (
@pregestational_diabetes, 
@gestational_diabetes,
@type_1_diabetes,
@type_2_diabetes,
@type_2_diabetes_mellitus_peripheral_circulatory, 
@insulin_dependent_type_2_diabetes,
@non_insulin_dependent_type_2_diabetes,
@type_2_diabetes_followup_without_hypoglycemic_agents,
@type_2_diabetes_on_oral_agents,
@type_2_diabetes_requiring_insulin,
@diabetes_ketoacidosis,
@diabetic_foot,
@diabetic_arthropathy,
@uncontrolled_diabetes_mellitus,
@diabetes,
@diabetes_insipidus
), @yes, @non);

-- Dystocia
set @labor_dystocia = concept_from_mapping('PIH', '8031');
set @shoulder_girdle_dystocia = concept_from_mapping('PIH', '8017');

update temp_mch_diagnoses tm set dystocia = if(diagnosis_concept in (
@shoulder_girdle_dystocia, 
@labor_dystocia
), @yes, @non);

-- Eclampsia
set @eclampsia = concept_from_mapping('PIH', '7696');
update temp_mch_diagnoses tm set eclampsia = if(diagnosis_concept = @eclampsia, @yes, @non);

-- Hemorrhage
set @antepartum_hemorrhage = concept_from_mapping('PIH', '228');
set @retained_placenta_without_hemorrhage = concept_from_mapping('PIH', '7235');
set @hemorrhage = concept_from_mapping('PIH', '7102');

update temp_mch_diagnoses tm set hemorrhage = if(diagnosis_concept in
(
@antepartum_hemorrhage,
@retained_placenta_without_hemorrhage,
@hemorrhage
), @yes, @non);

-- Hypertension
set @essential_hypertension = concept_from_mapping('PIH', '6847');
set @hypertension = concept_from_mapping('PIH', '903');
set @uncontrolled_hypertension = concept_from_mapping('PIH', '12629');
set @severe_uncontrolled_hypertension = concept_from_mapping('PIH', '12634');
set @secondary_hypertension = concept_from_mapping('PIH', '7166');
set @portal_hypertension = concept_from_mapping('PIH', '9058');

update temp_mch_diagnoses tm set hypertension = if(diagnosis_concept in
(
@essential_hypertension,
@hypertension,
@uncontrolled_hypertension,
@severe_uncontrolled_hypertension,
@secondary_hypertension,
@portal_hypertension
), @yes, @non);

-- Incomplete abortion
set @incomplete_spontaneous_abortion = concept_from_mapping('PIH', '9333');
set @incomplete_legally_induced_abortion = concept_from_mapping('PIH', '9727');
set @incomplete_abortion = concept_from_mapping('PIH', '905');
set @failed_medical_abortion = concept_from_mapping('PIH', '9335');
set @other_and_unspecified_failed_attempted_abortion = concept_from_mapping('PIH', '8319');
update temp_mch_diagnoses tm set incomplete_abortion = if(diagnosis_concept in
(
@incomplete_spontaneous_abortion,
@incomplete_legally_induced_abortion,
@incomplete_abortion,
@failed_medical_abortion,
@other_and_unspecified_failed_attempted_abortion
), @yes, @non);

-- Induced abortion
update temp_mch_diagnoses tm set induced_abortion = if(diagnosis_concept = @incomplete_legally_induced_abortion, @yes, @non);

-- Intrapartum hemorrhage
set @intrapartum_hemorrhage = concept_from_mapping('PIH', '13562');
update temp_mch_diagnoses tm set intrapartum_hemorrhage = if(diagnosis_concept = @intrapartum_hemorrhage, @yes, @non);

-- postpartum hemorrhage
set @postpartum_hemorrhage = concept_from_mapping('PIH', '49');
update temp_mch_diagnoses tm set postpartum_hemorrhage = if(diagnosis_concept = @postpartum_hemorrhage, @yes, @non);

-- Laceration of perineum
set @perineal_laceration_during_delivery = concept_from_mapping('PIH', '7230');
set @perineal_laceration = concept_from_mapping('PIH', '12372');
update temp_mch_diagnoses tm set laceration_of_perineum = if(diagnosis_concept in
(
@perineal_laceration_during_delivery,
@perineal_laceration
), @yes, @non);

-- Malaria
set @malaria_in_mother = concept_from_mapping('PIH', '7568');
set @cerebral_malaria = concept_from_mapping('CIEL', '11487');
set @severe_malaria = concept_from_mapping('PIH', '7134');
set @confirmed_malaria = concept_from_mapping('PIH', '7646');
set @malaria = concept_from_mapping('PIH', '123');
update temp_mch_diagnoses tm set malaria = if(diagnosis_concept in
(
@malaria_in_mother,
@cerebral_malaria,
@severe_malaria,
@confirmed_malaria,
@malaria
), @yes, @non);

-- Postnatal complication
set @postnatal_complication = concept_from_mapping('PIH', '7252');
update temp_mch_diagnoses tm set postnatal_complication = if(diagnosis_concept = @postnatal_complication, @yes, @non);

-- Preeclampsia
set @moderate_preeclampsia = concept_from_mapping('PIH', '8354');
set @severe_preeclampsia = concept_from_mapping('PIH', '9344');
set @preeclampsia = concept_from_mapping('PIH', '47');
update temp_mch_diagnoses tm set preeclampsia = if(diagnosis_concept in
(
@moderate_preeclampsia,
@severe_preeclampsia,
@preeclampsia
), @yes, @non);

--  Puerperal infection
set @puerperal_sepsis = concept_from_mapping('PIH', '130');
set @puerperal_infection = concept_from_mapping('PIH', '7252');
update temp_mch_diagnoses tm set puerperal_infection = if(diagnosis_concept in
(
@puerperal_sepsis,
@puerperal_infection
), @yes, @non);

-- Spontaneous Abortion
set @incomplete_spontaneous_abortion = concept_from_mapping('PIH', '9333');
set @spontaneous_abortion = concept_from_mapping('PIH', '7238');
update temp_mch_diagnoses tm set spontaneous_abortion = if(diagnosis_concept in
(
@incomplete_spontaneous_abortion,
@spontaneous_abortion
), @yes, @non);

-- Threatened Abortion
set @threatened_abortion = concept_from_mapping('PIH', '7993');
update temp_mch_diagnoses tm set threatened_abortion = if(diagnosis_concept
= @threatened_abortion, @yes, @non);

-- STI
set @sexually_transmitted_infection = concept_from_mapping('PIH', '174');
set @chlamydia = concept_from_mapping('PIH', '14363');
set @bacterial_vaginosis = concept_from_mapping('PIH', '2155');
set @gonorrhea = concept_from_mapping('PIH', '893');
set @sexually_transmitted_chlamydial = concept_from_mapping('PIH', '7247');
set @trichomoniasis = concept_from_mapping('PIH', '7120');
set @herpesvirus_infection = concept_from_mapping('PIH', '11194');
set @Herpes_simplex = concept_from_mapping('PIH', '3728');
update temp_mch_diagnoses tm set sti = if(diagnosis_concept in (
@sexually_transmitted_infection,
@chlamydia,
@bacterial_vaginosis,
@gonorrhea,
@sexually_transmitted_chlamydial,
@trichomoniasis,
@herpesvirus_infection,
@Herpes_simplex
), @yes, @non);

-- final query
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
       abortion_with_complication,
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
       intrapartum_hemorrhage,
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