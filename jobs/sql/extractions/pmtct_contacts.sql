-- set @locale = 'en';  -- uncomment for testing

select program_id into @hivProgram from program where uuid = 'b1cb1fc1-5190-4f7a-af08-48870975dafc';

select program_workflow_state_id into @patientPregnantState 
from program_workflow_state where uuid = '5da5fa62-ef9f-4f15-9b58-d23136c2907b';

drop temporary table if exists temp_contacts;

create temporary table temp_contacts
(
patient_id int,
zlemrid varchar(255),
concept_obs_group_id int,
age int,
latest_patient_program_id int, 
latest_pmtct_patient_state_id int,
hiv_enrollment_date datetime,
pmtct_initiation_date datetime,
art_start_date datetime,
reference_date datetime,
contact_index int,
contact_type varchar(255),
contact_gender varchar(50),
contact_age int,
date_entered DATETIME,
user_entered VARCHAR(50)
);

create index temp_contacts_pp_id on temp_contacts (latest_patient_program_id);

-- loads temp table with all contacts entered
-- note that the contact_index numbers the contacts within patients 
insert into temp_contacts (contact_index,patient_id,concept_obs_group_id,reference_date)
select @r:= IF(@u = person_id, @r + 1,1),@u:=person_id, obs_id, obs_datetime 
from obs o 
where o.voided = 0
and concept_id = concept_from_mapping('PIH','13182')
order by person_id, o.obs_datetime asc, obs_id asc
;

update temp_contacts t
set latest_patient_program_id = mostRecentPatientProgramId(t.patient_id, @hivProgram);

update temp_contacts t
set hiv_enrollment_date = programStartDate(latest_patient_program_id);

update temp_contacts t
set t.latest_pmtct_patient_state_id = mostRecentPatientStateId(t.latest_patient_program_id,@patientPregnantState);

update temp_contacts t
set t.pmtct_initiation_date = patientStateStartDate(latest_pmtct_patient_state_id);


-- zl emr id
update temp_contacts
set zlemrid = zlemr(patient_id);

-- current age
update temp_contacts
set age = current_age_in_years(patient_id);

-- art start date as the start date of orders with order reason of hiv
update temp_contacts t
set art_start_date = orderReasonStartDate(t.patient_id,'PIH','11197');

-- contact type
update temp_contacts t 
set contact_type = obs_from_group_id_value_coded_list(t.concept_obs_group_id, 'PIH','13265',@locale);

-- contact gender
update temp_contacts t 
set contact_gender = obs_from_group_id_value_coded_list(t.concept_obs_group_id, 'PIH','2845',@locale);

-- contact age
update temp_contacts t 
set contact_age= obs_from_group_id_value_numeric(t.concept_obs_group_id, 'PIH','3467');

-- date_entered and user_entered
update temp_contacts t inner join obs o on t.concept_obs_group_id = o.obs_id
set t.date_entered = o.date_created, t.user_entered = username(o.creator);

select 
patient_id,
zlemrid,
age,
hiv_enrollment_date,
pmtct_initiation_date,
art_start_date,
reference_date,
contact_index,
contact_type,
contact_gender,
contact_age,
date_entered,
user_entered
from temp_contacts
;
