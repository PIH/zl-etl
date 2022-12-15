-- set @locale = 'en';  -- uncomment for testing

select program_id into @mchProgram from program where uuid = '41a2715e-8a14-11e8-9a94-a6cf71072f73';
select name into @socioEncName from encounter_type where uuid = 'de844e58-11e1-11e8-b642-0ed5f89f718b' ;
select encounter_type('d83e98fd-dc7b-420f-aa3f-36f648b4483d') into @ob_gyn_enc_id;
select encounter_type('de844e58-11e1-11e8-b642-0ed5f89f718b') into @socio_enc_id;
select program_workflow_id into @mchWorkflow from program_workflow where uuid = '41a277d0-8a14-11e8-9a94-a6cf71072f73';
set @past_med_finding = concept_from_mapping('PIH','10140');

drop temporary table if exists temp_j9;

create temporary table temp_j9
(
patient_id int,
patient_program_id int,
patient_age int,
last_socio_encounter_id int,
education_level_obs_id int(11),
education_level varchar(255),
able_read_write_obs_id int(11),
able_read_write  boolean,
date_enrolled datetime,
date_completed datetime,
program_state varchar(255),
mothers_group_obs_id int(11),
mothers_group text,
expected_delivery_date_obs_id int(11),
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
history_hypertension boolean,
history_gestational_hypertenson boolean,
current_hypertension_risk boolean,
number_anc_visit int, 
number_obGyn_visits int,
number_postpartum_visits int,
number_family_planning_visits int,
marital_status_obs_id int(11),
marital_status varchar(255), 
employment_status_obs_id int(11),
employment_status varchar(255),
religion_obs_id int(11),
religion varchar(255),
family_support boolean,  
partner_support_anc_obs_id int(11),
partner_support_anc boolean,
number_living_children_obs_id int(11),
number_living_children int, 
number_household_members_obs_id int(11),
number_household_members int,
address_department varchar(255),
address_commune varchar(255),
address_section_communale varchar(255),
address_locality varchar(255),
address_street_landmark varchar(255),
access_transport_obs_id int(11),
access_transport boolean,
mode_transport_obs_id int(11),
mode_transport varchar(255), 
traditional_healer_obs_id int(11),
traditional_healer varchar(255),
prenatal_teas_obs_id int(11),
prenatal_teas varchar(255)
);

-- insert one row for every patient enrollment row 
insert into temp_j9 (patient_id)
select distinct patient_id
from patient_program pp 
where program_id = @mchProgram
and voided = 0
;
create index temp_j9_pi on temp_j9(patient_id);

update temp_j9 t
set patient_program_id = mostRecentPatientProgramId(t.patient_id,@mchProgram);

update temp_j9 t 
inner join patient_program pp on pp.patient_program_id = t.patient_program_id
set t.date_enrolled = pp.date_enrolled ,
	t.date_completed = pp.date_completed ;

DROP TEMPORARY TABLE IF EXISTS temp_encounter;
create temporary table temp_encounter 
select e.encounter_id, e.encounter_datetime , e.patient_id  , e.encounter_type 
from encounter e 
inner join temp_j9 t on t.patient_id = e.patient_id 
where e.encounter_type in (@ob_gyn_enc_id,@socio_enc_id) 
and e.voided = 0;

create index temp_encounter_ei on temp_encounter(encounter_id);
create index temp_encounter_ci1 on temp_encounter(patient_id, encounter_type);
create index temp_encounter_ci2 on temp_encounter(patient_id, encounter_datetime);

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.comments, o.date_created, o.obs_datetime  
from obs o
inner join temp_encounter t on o.encounter_id = t.encounter_id 
where o.voided = 0;

create index temp_obs_ci1 on temp_obs(encounter_id,concept_id);
create index temp_obs_ci2 on temp_obs(person_id,concept_id);
create index temp_obs_ci3 on temp_obs(date_created, obs_id);
create index temp_obs_ci4 on temp_obs(obs_group_id, concept_id);
create index temp_obs_ci5 on temp_obs(person_id, concept_id, obs_datetime);
create index temp_obs_oi on temp_obs(obs_id);

-- encounter_id of latest encounter_id (used in calculations below) 
update temp_j9 t
set last_socio_encounter_id = latest_enc_from_temp(patient_id, @socio_enc_id, null);

update temp_j9 t
set program_state = currentProgramState(t.patient_program_id, @mchWorkflow, @locale);

-- mothers group
set @m_group_concept_id = concept_from_mapping('PIH','11665');
update temp_j9 t 
set mothers_group_obs_id = latest_obs_from_temp_from_concept_id(patient_id,@m_group_concept_id);
update temp_j9 t 
set mothers_group = value_text_from_temp(mothers_group_obs_id);

-- patient age
update temp_j9
set patient_age = current_age_in_years(patient_id);

-- columns from socioeconomic form
-- education level
set @el_id = concept_from_mapping('CIEL','1712');
update temp_j9
set education_level_obs_id = latest_obs_from_temp_from_concept_id(patient_id,@el_id);
update temp_j9
set education_level = value_coded_name_from_temp(education_level_obs_id,@locale);

-- able to read or write
set @able_rw_id = concept_from_mapping('CIEL','166855');
update temp_j9
set able_read_write_obs_id =latest_obs_from_temp_from_concept_id(patient_id, @able_rw_id);
update temp_j9
set able_read_write = value_coded_as_boolean_from_temp(able_read_write_obs_id);

-- family support checkbox
update temp_j9 t
inner join temp_obs o on o.encounter_id = last_socio_encounter_id and o.voided = 0
	and o.concept_id = concept_from_mapping('PIH','2156') 
	and o.value_coded = concept_from_mapping('PIH','10642') 
set family_support = if(o.obs_id is null,null,1 );

-- partner support checkbox
set @partner_support_id = concept_from_mapping('PIH','13747');
update temp_j9 
set partner_support_anc_obs_id = latest_obs_from_temp_from_concept_id(patient_id, @partner_support_id);
update temp_j9 
set partner_support_anc = value_coded_as_boolean_from_temp(partner_support_anc_obs_id);

-- currently employed checkbox
set @employment_status_id = concept_from_mapping('PIH','3395');
update temp_j9
set employment_status_obs_id = latest_obs_from_temp_from_concept_id(patient_id, @employment_status_id);
update temp_j9
set employment_status = value_coded_as_boolean_from_temp(employment_status_obs_id);

-- number household members
set @number_hh_id = concept_from_mapping('CIEL','1474');
update temp_j9
set number_household_members_obs_id = latest_obs_from_temp_from_concept_id(patient_id, @number_hh_id);
update temp_j9
set number_household_members = value_numeric_from_temp(number_household_members_obs_id);

-- access to transpoirt
set @at_id= concept_from_mapping('PIH','13746');
update temp_j9
set access_transport_obs_id = latest_obs_from_temp_from_concept_id(patient_id, @at_id);
update temp_j9
set access_transport = value_coded_as_boolean_from_temp(access_transport_obs_id);

-- mode of transport
set @mt_id= concept_from_mapping('PIH','975');
update temp_j9
set mode_transport_obs_id = latest_obs_from_temp_from_concept_id(patient_id,@mt_id);
update temp_j9
set mode_transport = value_coded_name_from_temp(mode_transport_obs_id,@locale);

-- columns from obgyn form
-- expected delivery date
set @edd_id= concept_from_mapping('PIH','5596');
update temp_j9
set expected_delivery_date_obs_id = latest_obs_from_temp_from_concept_id(patient_id,@edd_id);
update temp_j9
set expected_delivery_date = value_datetime_from_temp(expected_delivery_date_obs_id);

-- need to retrieve the highest birth number from prior births entered
-- to derive prior birth columns 
update temp_j9 t
inner join (
	select person_id, max(value_numeric) as highest_birth_order
	from temp_obs o
	where concept_id = concept_from_mapping('PIH','13126')
	and o.voided = 0
	group by person_id) s on s.person_id = t.patient_id
set highest_birth_number = highest_birth_order 
;

-- retrieves the obs group of the highest birth number previously calculated
update temp_j9 t
inner join obs o on o.person_id = t.patient_id and o.obs_id =
	(select obs_id from temp_obs o2
	where o2.voided = 0
	and o2.concept_id = concept_from_mapping('PIH','13126')
	and o2.value_numeric = highest_birth_number
	and o2.person_id = patient_id
	order by o2.obs_datetime desc limit 1)
set highest_birth_number_obs_group = o.obs_group_id ;

set @deliveryTypeId = concept_from_mapping('PIH','11663');

-- prior birth delivery type (using 2 fields above) -- this is REALLY SLOW!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
update temp_j9 t
inner join temp_obs o on o.voided = 0
      and       o.obs_group_id= highest_birth_number_obs_group
      and       o.concept_id = @deliveryTypeId
set prior_birth_delivery_type =  concept_name(o.value_coded, @locale)     ;
/*
update temp_j9 t
set prior_birth_delivery_type = obs_from_group_id_value_coded_list_from_temp(t.highest_birth_number_obs_group, 'PIH','11663',@locale);
*/
-- prior birth delivery outcome (status) (using 2 fields above)
update temp_j9 t
set prior_birth_neonatal_status = obs_from_group_id_value_coded_list_from_temp(t.highest_birth_number_obs_group, 'PIH','12899',@locale);

-- checks if these history checkboxes have ever been checked  
update temp_j9 t
set history_pre_eclampsia = answerEverExists_from_temp(t.patient_id, 'PIH','10140','PIH','47',null);

update temp_j9 t
set history_eclampsia = answerEverExists_from_temp(t.patient_id, 'PIH','10140','PIH','7696',null);

update temp_j9 t
set history_gender_based_violence = answerEverExists_from_temp(t.patient_id, 'PIH','10140','PIH','11550',null);

update temp_j9 t
set history_type_1_diabetes = answerEverExists_from_temp(t.patient_id, 'PIH','10140','PIH','6691',null);

update temp_j9 t
set history_type_2_diabetes = answerEverExists_from_temp(t.patient_id, 'PIH','10140','PIH','6692',null);

update temp_j9 t
set history_gestational_diabetes = answerEverExists_from_temp(t.patient_id, 'PIH','10140','PIH','6693',null);

update temp_j9 t
set history_post_partum_hemorrhage = answerEverExists_from_temp(t.patient_id, 'PIH','10140','PIH','49',null);

update temp_j9 t
set history_hypertension = answerEverExists_from_temp(t.patient_id, 'PIH','10140','PIH','903',null);

update temp_j9 t
set history_gestational_hypertenson = answerEverExists_from_temp(t.patient_id, 'PIH','10140','PIH','9752',null);

update temp_j9 t
set current_hypertension_risk = answerEverExists_from_temp(t.patient_id, 'PIH','11673','PIH','903',date_enrolled);

-- Counts number of ANC visits (OBGYN visits with type = ANC)
update temp_j9 t
inner join
	(select e.patient_id, count(*) as count_visits from encounter e
	where e.encounter_type = @ob_gyn_enc_id
	and e.voided = 0
	and EXISTS 
		(select 1 from temp_obs o
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
		(select 1 from temp_obs o
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
		(select 1 from temp_obs o
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
		(select 1 from temp_obs o
		where o.voided =0
		and o.encounter_id  = e.encounter_id 
		and o.concept_id = concept_from_mapping('PIH','8879')
		and o.value_coded = concept_from_mapping('PIH','5483'))
	group by patient_id) s on s.patient_id = t.patient_id
set number_family_planning_visits = s.count_visits;

-- marital status
set @ms_id = concept_from_mapping('CIEL','1712');
update temp_j9 t 
set marital_status_obs_id = latest_obs_from_temp_from_concept_id(t.patient_id, @ms_id);
update temp_j9 t 
set marital_status = value_coded_name_from_temp(marital_status_obs_id,@locale);

-- religion
set @r_id = concept_from_mapping('PIH','10154');
update temp_j9 t 
set religion_obs_id = latest_obs_from_temp_from_concept_id(t.patient_id, @r_id);
update temp_j9 t 
set religion = value_coded_name_from_temp(religion_obs_id,@locale);

-- number of living children
SET @nlc_id = concept_from_mapping('PIH','11117');
update temp_j9 t 
set number_living_children_obs_id = latest_obs_from_temp_from_concept_id(t.patient_id, @nlc_id);
update temp_j9 t 
set number_living_children = value_numeric_from_temp(number_living_children_obs_id);

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
SET @tnh_id = concept_from_mapping('PIH','13242');
update temp_j9 t 
set traditional_healer_obs_id = latest_obs_from_temp_from_concept_id(t.patient_id, @tnh_id);
update temp_j9 t 
set traditional_healer = value_coded_name_from_temp(traditional_healer_obs_id,@locale);

-- used prenatal teas
SET @pt_id = concept_from_mapping('PIH','13737');
update temp_j9 t 
set prenatal_teas_obs_id = latest_obs_from_temp_from_concept_id(t.patient_id, @pt_id);
update temp_j9 t 
set prenatal_teas = value_coded_name_from_temp(prenatal_teas_obs_id,@locale);

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
history_hypertension,
history_gestational_hypertenson,
current_hypertension_risk,
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
