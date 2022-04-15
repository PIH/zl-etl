-- set @locale = 'en';  -- uncomment for testing

select program_id into @mchProgram from program where uuid = '41a2715e-8a14-11e8-9a94-a6cf71072f73';
select name into @socioEncName from encounter_type where uuid = 'de844e58-11e1-11e8-b642-0ed5f89f718b' ;
select encounter_type('d83e98fd-dc7b-420f-aa3f-36f648b4483d') into @ob_gyn_enc_id;
select program_workflow_id into @mchWorkflow from program_workflow where uuid = '41a277d0-8a14-11e8-9a94-a6cf71072f73';
set @past_med_finding = concept_from_mapping('PIH','10140');

drop temporary table if exists temp_j9;

create temporary table temp_j9
(
patient_id int,
patient_program_id int,
patient_age int,
last_socio_encounter_id int,
education_level varchar(255),
able_read_write  boolean,
date_enrolled datetime,
date_completed datetime,
program_state varchar(255),
mothers_group text,
expected_delivery_date datetime,
highest_birth_number_obs_group int,
highest_birth_number int,
prior_birth_delivery_type varchar(255), 
prior_birth_neonatal_status varchar(255),
history_pre_eclampsia boolean,
history_eclampsia boolean,
history_post_partum_hemorrhage boolean,
history_gender_based_violence boolean, 
history_type_1_diabetes boolean,
history_type_2_diabetes boolean,
history_gestational_diabetes boolean,
number_anc_visit int, 
number_obGyn_visits int,
number_postpartum_visits int,
number_family_planning_visits int,
marital_status varchar(255), 
employment_status varchar(255),
religion varchar(255),
family_support boolean,  
partner_support_anc boolean,
number_living_children int, 
number_household_members int,
address_department varchar(255),
address_commune varchar(255),
address_section_communale varchar(255),
address_locality varchar(255),
address_street_landmark varchar(255),
access_transport boolean,
mode_transport varchar(255), 
traditional_healer varchar(255),
prenatal_teas varchar(255) 
);

-- insert one row for every patient enrollment row 
insert into temp_j9 (patient_id,patient_program_id,date_enrolled,date_completed)
select patient_id,patient_program_id,date_enrolled,date_completed 
from patient_program pp 
where program_id = @mchProgram
and voided = 0
;

-- encounter_id of latest encounter_id (used in calculations below) 
update temp_j9
set last_socio_encounter_id = latestEnc(patient_id, @socioEncName, null);

update temp_j9 t
set program_state = currentProgramState(t.patient_program_id, @mchWorkflow, @locale);

-- mothers group
update temp_j9 t 
set mothers_group = value_text(latest_obs(patient_id,'PIH','11665'));

-- patient age
update temp_j9
set patient_age = current_age_in_years(patient_id);

-- columns from socioeconomic form
-- education level
update temp_j9
set education_level = value_coded_name(latest_obs(patient_id,'CIEL','1712'),@locale);

-- able to read or write
update temp_j9
set able_read_write = value_coded_as_boolean(latest_obs(patient_id, 'CIEL','166855'));

-- family support checkbox
update temp_j9 t
inner join obs o on o.encounter_id = last_socio_encounter_id and o.voided = 0
	and o.concept_id = concept_from_mapping('PIH','2156') 
	and o.value_coded = concept_from_mapping('PIH','10642') 
set family_support = if(o.obs_id is null,null,1 );

-- partner support checkbox
update temp_j9 
set partner_support_anc = value_coded_as_boolean(latest_obs(patient_id, 'PIH','13747'));

-- currently employed checkbox
update temp_j9
set employment_status = value_coded_as_boolean(latest_obs(patient_id, 'PIH','3395'));

-- number household members
update temp_j9
set number_household_members = value_numeric(latest_obs(patient_id, 'CIEL','1474'));

-- access to transpoirt
update temp_j9
set access_transport = value_coded_as_boolean(latest_obs(patient_id, 'PIH','13746'));

-- mode of transport
update temp_j9
set mode_transport = value_coded_name(latest_obs(patient_id,'PIH','975'),@locale);

-- columns from obgyn form
-- expected delivery date
update temp_j9
set expected_delivery_date = value_datetime(latest_obs(patient_id,'PIH','5596'));

-- need to retrieve the highest birth number from prior births entered
-- to derive prior birth columns 
update temp_j9 t
inner join (
	select person_id, max(value_numeric) as highest_birth_order
	from obs o
	where concept_id = concept_from_mapping('PIH','13126')
	and o.voided = 0
	group by person_id) s on s.person_id = t.patient_id
set highest_birth_number = highest_birth_order 
;

-- retrieves the obs group of the highest birth number previously calculated
update temp_j9 t
inner join obs o on o.person_id = t.patient_id and o.obs_id =
	(select obs_id from obs o2
	where o2.voided = 0
	and o2.concept_id = concept_from_mapping('PIH','13126')
	and o2.value_numeric = highest_birth_number
	and o2.person_id = patient_id
	order by o2.obs_datetime desc limit 1)
set highest_birth_number_obs_group = o.obs_group_id ;

-- prior birth delivery type (using 2 fields above)
update temp_j9 t
set prior_birth_delivery_type = obs_from_group_id_value_coded_list(t.highest_birth_number_obs_group, 'PIH','11663',@locale);

-- prior birth delivery outcome (status) (using 2 fields above)
update temp_j9 t
set prior_birth_neonatal_status = obs_from_group_id_value_coded_list(t.highest_birth_number_obs_group, 'PIH','12899',@locale);

-- checks if these history checkboxes have ever been checked  
update temp_j9 t
set history_pre_eclampsia = answerEverExists(t.patient_id, 'PIH','10140','PIH','47',null);

update temp_j9 t
set history_eclampsia = answerEverExists(t.patient_id, 'PIH','10140','PIH','7696',null);

update temp_j9 t
set history_gender_based_violence = answerEverExists(t.patient_id, 'PIH','10140','PIH','11550',null);

update temp_j9 t
set history_type_1_diabetes = answerEverExists(t.patient_id, 'PIH','10140','PIH','6691',null);

update temp_j9 t
set history_type_2_diabetes = answerEverExists(t.patient_id, 'PIH','10140','PIH','6692',null);

update temp_j9 t
set history_gestational_diabetes = answerEverExists(t.patient_id, 'PIH','10140','PIH','6693',null);

update temp_j9 t
set history_post_partum_hemorrhage = answerEverExists(t.patient_id, 'PIH','10140','PIH','49',null);

-- Counts number of ANC visits (OBGYN visits with type = ANC)
update temp_j9 t
inner join
	(select e.patient_id, count(*) as count_visits from encounter e
	where e.encounter_type = @ob_gyn_enc_id
	and e.voided = 0
	and EXISTS 
		(select 1 from obs o
		where o.voided =0
		and o.encounter_id  = e.encounter_id 
		and o.concept_id = concept_from_mapping('PIH','8879')
		and o.value_coded = concept_from_mapping('PIH','6259'))
	group by patient_id) s on s.patient_id = t.patient_id
set number_anc_visit = s.count_visits;

-- Counts number of obgyn visits (OBGYN visits with type = OBGYN)
update temp_j9 t
inner join
	(select e.patient_id, count(*) as count_visits from encounter e
	where e.encounter_type = @ob_gyn_enc_id
	and e.voided = 0
	and EXISTS 
		(select 1 from obs o
		where o.voided =0
		and o.encounter_id  = e.encounter_id 
		and o.concept_id = concept_from_mapping('PIH','8879')
		and o.value_coded = concept_from_mapping('PIH','13254'))
	group by patient_id) s on s.patient_id = t.patient_id
set number_obGyn_visits = s.count_visits;

-- Counts number of post partum visits (OBGYN visits with type = POST PARTUM)
update temp_j9 t
inner join
	(select e.patient_id, count(*) as count_visits from encounter e
	where e.encounter_type = @ob_gyn_enc_id
	and e.voided = 0
	and EXISTS 
		(select 1 from obs o
		where o.voided =0
		and o.encounter_id  = e.encounter_id 
		and o.concept_id = concept_from_mapping('PIH','8879')
		and o.value_coded = concept_from_mapping('PIH','6261'))
	group by patient_id) s on s.patient_id = t.patient_id
set number_postpartum_visits = s.count_visits;

-- Counts number of Family Planning visits (OBGYN visits with type = Family Planning)
update temp_j9 t
inner join
	(select e.patient_id, count(*) as count_visits from encounter e
	where e.encounter_type = @ob_gyn_enc_id
	and e.voided = 0
	and EXISTS 
		(select 1 from obs o
		where o.voided =0
		and o.encounter_id  = e.encounter_id 
		and o.concept_id = concept_from_mapping('PIH','8879')
		and o.value_coded = concept_from_mapping('PIH','5483'))
	group by patient_id) s on s.patient_id = t.patient_id
set number_family_planning_visits = s.count_visits;

-- marital status
update temp_j9 t 
set marital_status = value_coded_name(latest_obs(t.patient_id, 'PIH','1054'),@locale);

-- religion
update temp_j9 t 
set religion = value_coded_name(latest_obs(t.patient_id, 'PIH','10154'),@locale);

-- number of living children
update temp_j9 t 
set number_living_children = value_numeric(latest_obs(t.patient_id, 'PIH','11117'));

-- patient's address
update temp_j9 t 
set address_department = person_address_state_province(patient_id);

update temp_j9 t 
set address_commune = person_address_city_village(patient_id);

update temp_j9 t 
set address_section_communale = person_address_three(patient_id);

update temp_j9 t 
set address_locality = person_address_one(patient_id);

update temp_j9 t 
set address_street_landmark = person_address_two(patient_id);

-- traditional healer
update temp_j9 t 
set traditional_healer = value_coded_name(latest_obs(t.patient_id, 'PIH','13242'),@locale);

-- used prenatal teas
update temp_j9 t 
set prenatal_teas = value_coded_name(latest_obs(t.patient_id, 'PIH','13737'),@locale);

-- final output
Select
zlemr(patient_id),
patient_age,
education_level,
able_read_write,
date_enrolled,
date_completed,
program_state,
mothers_group,
expected_delivery_date,
prior_birth_delivery_type,
prior_birth_neonatal_status,
history_pre_eclampsia,
history_eclampsia,
history_post_partum_hemorrhage,
history_gender_based_violence,
history_type_1_diabetes,
history_type_2_diabetes,
history_gestational_diabetes,
number_anc_visit,
number_obGyn_visits,
number_postpartum_visits,
number_family_planning_visits,
marital_status,
employment_status,
religion,
family_support,
partner_support_anc,
number_living_children,
number_household_members,
address_department,
address_commune,
address_section_communale,
address_locality,
address_street_landmark,
access_transport,
mode_transport,
traditional_healer,
prenatal_teas
from temp_j9 t 
;
