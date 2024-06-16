SET sql_safe_updates = 0;
set @partition = '${partitionNum}';
select program_id into @mchProgram from program where uuid = '41a2715e-8a14-11e8-9a94-a6cf71072f73';
select encounter_type('d83e98fd-dc7b-420f-aa3f-36f648b4483d') into @ob_gyn_enc_id;
select encounter_type('873f968a-73a8-4f9c-ac78-9f4778b751b6') into @reg_enc_id;
select program_workflow_id into @mchWorkflow from program_workflow where uuid = '41a277d0-8a14-11e8-9a94-a6cf71072f73';

drop temporary table if exists temp_j9;
create temporary table temp_j9
(
patient_id                      int,          
patient_program_id              int,          
patient_age                     int,          
date_enrolled                   datetime,     
date_completed                  datetime,     
program_state                   varchar(255), 
mothers_group_obs_id            int(11),      
mothers_group                   text,         
expected_delivery_date_obs_id   int(11),      
expected_delivery_date          datetime,     
highest_birth_number_obs_group  int,          
highest_birth_number            int,          
prior_birth_delivery_type       varchar(255),  
prior_birth_neonatal_status     varchar(255), 
history_pre_eclampsia           boolean,      
history_eclampsia               boolean,      
history_post_partum_hemorrhage  boolean,      
history_gender_based_violence   boolean,       
history_type_1_diabetes         boolean,      
history_type_2_diabetes         boolean,      
history_gestational_diabetes    boolean,      
history_hypertension            boolean,      
history_gestational_hypertenson boolean,      
current_hypertension_risk       boolean,      
number_anc_visit                int,           
number_obGyn_visits             int,          
number_postpartum_visits        int,          
number_family_planning_visits   int,          
marital_status_obs_id           int(11),      
marital_status                  varchar(255),  
religion_obs_id                 int(11),      
religion                        varchar(255), 
family_support                  boolean,       
partner_support_anc_obs_id      int(11),      
partner_support_anc             boolean,      
number_living_children_obs_id   int(11),      
number_living_children          int,           
number_household_members_obs_id int(11),      
number_household_members        int,          
address_department              varchar(255), 
address_commune                 varchar(255), 
address_section_communale       varchar(255), 
address_locality                varchar(255), 
address_street_landmark         varchar(255), 
traditional_healer_obs_id       int(11),      
traditional_healer              varchar(255), 
prenatal_teas_obs_id            int(11),      
prenatal_teas                   varchar(255)  
);

-- insert one row for every patient enrollment row 
insert into temp_j9 (patient_id,patient_program_id,date_enrolled,date_completed)
select patient_id,patient_program_id,date_enrolled,date_completed 
from patient_program pp 
where program_id = @mchProgram
and voided = 0
;

-- patient fields
drop temporary table if exists temp_j9_patients;
create temporary table temp_j9_patients
(patient_id               int(11),      
patient_age               int,          
address_department        varchar(255), 
address_commune           varchar(255), 
address_section_communale varchar(255), 
address_locality          varchar(255), 
address_street_landmark   varchar(255), 
marital_status_obs_id     int(11),      
marital_status            varchar(255),  
religion_obs_id           int(11),      
religion                  varchar(255)  
);

insert into temp_j9_patients(patient_id)
select distinct patient_id from temp_j9;

create index temp_j9_patients_pi on temp_j9_patients(patient_id);

-- patient age
update temp_j9_patients
set patient_age = current_age_in_years(patient_id);

-- patient's address
update temp_j9_patients t 
set address_department = person_address_state_province(patient_id);

update temp_j9_patients t 
set address_commune = person_address_city_village(patient_id);

update temp_j9_patients t 
set address_section_communale = person_address_three(patient_id);

update temp_j9_patients t 
set address_locality = person_address_one(patient_id);

update temp_j9_patients t 
set address_street_landmark = person_address_two(patient_id);

DROP TEMPORARY TABLE IF EXISTS temp_encounter;
create temporary table temp_encounter 
select e.encounter_id, e.patient_id
from encounter e 
inner join temp_j9_patients t on t.patient_id = e.patient_id 
where e.encounter_type in (@reg_enc_id) 
and e.voided = 0;

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.comments, o.date_created, o.obs_datetime  
from obs o
inner join temp_encounter t on o.encounter_id = t.encounter_id 
where o.voided = 0;

create index temp_obs_ci2 on temp_obs(person_id,concept_id);
create index temp_obs_pi on temp_obs(person_id);
create index temp_obs_oi on temp_obs(obs_id);

-- marital status
set @ms_id = concept_from_mapping('CIEL','1054');
update temp_j9_patients t 
set marital_status_obs_id = latest_obs_from_temp_from_concept_id(t.patient_id, @ms_id);
update temp_j9_patients t 
set marital_status = value_coded_name_from_temp(marital_status_obs_id,@locale);

-- religion
set @r_id = concept_from_mapping('PIH','10154');
update temp_j9_patients t 
set religion_obs_id = latest_obs_from_temp_from_concept_id(t.patient_id, @r_id);
update temp_j9 t 
set religion = value_coded_name_from_temp(religion_obs_id,@locale);

-- join patient fields back to main table
update temp_j9 t
inner join temp_j9_patients p on p.patient_id = t.patient_id
set t.patient_id=p.patient_id,
t.patient_age=p.patient_age,
t.address_department=p.address_department,
t.address_commune=p.address_commune,
t.address_section_communale=p.address_section_communale,
t.address_locality=p.address_locality,
t.address_street_landmark=p.address_street_landmark,
t.marital_status_obs_id=p.marital_status_obs_id,
t.marital_status=p.marital_status,
t.religion_obs_id=p.religion_obs_id,
t.religion=p.religion;


-- fields from obs gyn form
DROP TEMPORARY TABLE IF EXISTS temp_encounter;
create temporary table temp_encounter 
select distinct e.encounter_id 
from encounter e 
inner join temp_j9 t on t.patient_id = e.patient_id 
where e.encounter_type in (@ob_gyn_enc_id) 
and e.voided = 0;

create index temp_encounter_ei on temp_encounter(encounter_id);

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.comments, o.date_created, o.obs_datetime  
from obs o
inner join temp_encounter t on o.encounter_id = t.encounter_id 
where o.voided = 0;

create index temp_obs_ci1 on temp_obs(encounter_id,concept_id);
create index temp_obs_ci2 on temp_obs(person_id,concept_id);
create index temp_obs_ci3 on temp_obs(encounter_id, concept_id, value_coded);
create index temp_obs_ci4 on temp_obs(person_id, concept_id, value_coded,obs_datetime);
create index temp_obs_ci5 on temp_obs(person_id, concept_id,value_numeric, obs_datetime );
create index temp_obs_ci6 on temp_obs(obs_group_id, concept_id);
create index temp_obs_oi on temp_obs(obs_id);
 
update temp_j9 t
set program_state = currentProgramState(t.patient_program_id, @mchWorkflow, @locale);

-- mothers group
update temp_j9 t 
set mothers_group_obs_id 
	= latest_obs_from_temp_between_dates(patient_id,'PIH','11665',date_enrolled, ifnull(date_completed, now()));
update temp_j9 t 
set mothers_group = value_text_from_temp(mothers_group_obs_id);

-- number of living children
update temp_j9 t 
set number_living_children_obs_id 
	= latest_obs_from_temp_between_dates(patient_id,'PIH','11117',date_enrolled, ifnull(date_completed, now()));
 update temp_j9 t 
 set number_living_children = value_numeric_from_temp(number_living_children_obs_id);

-- traditional healer
update temp_j9 t 
set traditional_healer_obs_id  
	= latest_obs_from_temp_between_dates(patient_id,'PIH','13242',date_enrolled, ifnull(date_completed, now()));
update temp_j9 t 
set traditional_healer = value_coded_name_from_temp(traditional_healer_obs_id,@locale);

-- used prenatal teas
update temp_j9 t 
set prenatal_teas_obs_id  
	= latest_obs_from_temp_between_dates(patient_id,'PIH','13737',date_enrolled, ifnull(date_completed, now()));
update temp_j9 t 
set prenatal_teas = value_coded_name_from_temp(prenatal_teas_obs_id,@locale);

-- expected delivery date
update temp_j9
set expected_delivery_date_obs_id  
	= latest_obs_from_temp_between_dates(patient_id,'PIH','5596',date_enrolled, ifnull(date_completed, now()));
update temp_j9
set expected_delivery_date = value_datetime_from_temp(expected_delivery_date_obs_id);

-- retrieve the highest birth number from prior births entered
set @del_order_id = concept_from_mapping('PIH','13126');

update temp_j9 t
set t.highest_birth_number = 
	(select max(value_numeric)
	from temp_obs o 
	where o.concept_id = @del_order_id
	and o.person_id = t.patient_id
	and o.obs_datetime <= ifnull(t.date_completed,now()));

-- retrieves the obs group of the highest birth number previously calculated
update temp_j9 t
inner join obs o on o.person_id = t.patient_id and o.obs_id =
	(select obs_id from temp_obs o2
	where o2.concept_id = @del_order_id
	and o2.value_numeric = highest_birth_number
	and o2.person_id = patient_id
	order by o2.obs_datetime desc limit 1)
set highest_birth_number_obs_group = o.obs_group_id ;

-- prior birth delivery type (using 2 fields above)
set @deliveryTypeId = concept_from_mapping('PIH','11663');
update temp_j9 t
inner join temp_obs o on o.obs_group_id= highest_birth_number_obs_group
      and o.concept_id = @deliveryTypeId
set prior_birth_delivery_type =  concept_name(o.value_coded, @locale)     ;

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
set @type_opd_visit = concept_from_mapping('PIH','8879');
set @anc_visit = concept_from_mapping('PIH','6259');
update temp_j9 t
set number_anc_visit =
	(select count(*) from temp_obs o
	where o.person_id = t.patient_id 
	and o.concept_id = @type_opd_visit
	and o.value_coded = @anc_visit
	and o.obs_datetime >= date_enrolled
	and o.obs_datetime <= ifnull(date_completed,now()));

-- Counts number of obgyn visits (OBGYN visits with type = OBGYN)
set @obgyn_visit = concept_from_mapping('PIH','13254');
update temp_j9 t
set number_obGyn_visits =
	(select count(*) from temp_obs o
	where o.person_id = t.patient_id 
	and o.concept_id = @type_opd_visit
	and o.value_coded = @obgyn_visit
	and o.obs_datetime >= date_enrolled
	and o.obs_datetime <= ifnull(date_completed,now()));

-- Counts number of post partum visits (OBGYN visits with type = POST PARTUM)
set @pnc_visit = concept_from_mapping('PIH','6261');
update temp_j9 t
set number_postpartum_visits =
	(select count(*) from temp_obs o
	where o.person_id = t.patient_id 
	and o.concept_id = @type_opd_visit
	and o.value_coded = @pnc_visit
	and o.obs_datetime >= date_enrolled
	and o.obs_datetime <= ifnull(date_completed,now()));

-- Counts number of Family Planning visits (OBGYN visits with type = Family Planning)
set @fp_visit = concept_from_mapping('PIH','5483');
update temp_j9 t
set number_family_planning_visits =
	(select count(*) from temp_obs o
	where o.person_id = t.patient_id 
	and o.concept_id = @type_opd_visit
	and o.value_coded = @fp_visit
	and o.obs_datetime >= date_enrolled
	and o.obs_datetime <= ifnull(date_completed,now()));

-- final output
Select
concat(@partition,'-',t.patient_program_id) "patient_program_id",
zlemr(patient_id) "emr_id",
patient_age,
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
traditional_healer,
prenatal_teas
from temp_j9 t 
;
