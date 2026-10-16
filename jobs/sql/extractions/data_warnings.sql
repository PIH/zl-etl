set @partition = '${partitionNum}';

select encounter_type_id into @registrationEncType from encounter_type where uuid = '873f968a-73a8-4f9c-ac78-9f4778b751b6';
select encounter_type_id into @anc_intake from encounter_type where uuid = '00e5e810-90ec-11e8-9eb6-529269fb1459';
select encounter_type_id into @anc_followup from encounter_type where uuid = '00e5e946-90ec-11e8-9eb6-529269fb1459';
select encounter_type_id into @mch_delivery from encounter_type where uuid = '00e5ebb2-90ec-11e8-9eb6-529269fb1459';
select encounter_type_id into @obgyn from encounter_type where uuid = 'd83e98fd-dc7b-420f-aa3f-36f648b4483d';
select encounter_type_id into @prenatal_home_assessment from encounter_type where uuid = '91DDF969-A2D4-4603-B979-F2D6F777F4AF';
select encounter_type_id into @maternal_post_partum_home_assessment from encounter_type where uuid = '0E7160DF-2DD1-4728-B951-641BBE4136B8';
select encounter_type_id into @maternal_follow_up_home_assessment from encounter_type where uuid = '690670E2-A0CC-452B-854D-B95E2EAB75C9';
select encounter_type_id into @pmtct_intake from encounter_type where uuid = '584124b9-1f10-4757-ba09-91fc9075af92';
select encounter_type_id into @pmtct_followup from encounter_type where uuid = '95e03e7d-9aeb-4a99-bd7a-94e8591ec2c5';
select encounter_type_id into @maternity_and_delivery_register from encounter_type where uuid = '9cc89b83-e32f-410a-947d-aeb3bda37571';
select encounter_type_id into @labour_progress from encounter_type where uuid = 'ac5ec970-31b7-4659-9141-284bfbc13c69';
select encounter_type_id into @labor_and_delivery_summary from encounter_type where uuid = 'fec2cc56-e35f-42e1-8ae3-017142c1ca59';
select encounter_type_id into @sierra_leone_maternal_check_in from encounter_type where uuid = '251c03fa-a9dc-4157-855f-b016f4fae9ab';
select encounter_type_id into @maternal_discharge from encounter_type where uuid = '2110a810-db62-4914-ba95-604b96010164';
select encounter_type_id into @sierra_leone_maternal_triage from encounter_type where uuid = 'f1652c4a-6f24-432f-9441-e58641f9c01a';
select encounter_type_id into @sierra_leone_mch_triage from encounter_type where uuid = '41911448-71a1-43d7-bba8-dc86339850da';
select encounter_type_id into @postpartum_progress from encounter_type where uuid = '37f04ddf-9653-4a02-98b4-1c23734c2f15';
select encounter_type_id into @sierra_leone_maternal_admission from encounter_type where uuid = '0ef67d23-0cf4-4a3e-8617-ac9d55bdd005';
select encounter_type_id into @admission from encounter_type where uuid = '260566e1-c909-4d61-a96f-c1019291a09d';
select encounter_type_id into @bed_assignment from encounter_type where uuid = 'caa222d6-d7d0-408f-a104-320e7556e9ff';
select encounter_type_id into @drug_order from encounter_type where uuid = '0b242b71-5b60-11eb-8f5a-0242ac110002';
select encounter_type_id into @discharge from encounter_type where uuid = 'b6631959-2105-49dd-b154-e1249e0fbcd7';
select encounter_type_id into @rad_order from encounter_type where uuid = '1b3d1e13-f0b1-4b83-86ea-b1b1e2fb4efa';
select encounter_type_id into @test_order from encounter_type where uuid = 'b3a0e3ad-b80c-4f3f-9626-ace1ced7e2dd';
select encounter_type_id into @transfer from encounter_type where uuid = '436cfe33-6b81-40ef-a455-f134a9f7e580';
select encounter_type_id into @check_in from encounter_type where uuid = '55a0d3ea-a4d7-4e88-8f01-5aceb2d3c61b';
drop temporary table if exists temp_warnings;
create temporary table temp_warnings
(
data_warning_id int(11) NOT NULL AUTO_INCREMENT, 
warning_type       varchar(50),  
event_type         varchar(255), 
event_datetime     datetime,
patient_id         int(11),      
emr_id             varchar(50), 
visit_id           int(11),
encounter_id       int(11),      
patient_program_id int(11),      
encounter_datetime datetime,     
datetime_entered   datetime,  
creator            int(11),
user_entered       text,
visit_date_started datetime,
visit_date_stopped datetime,
other_details      text,         
PRIMARY KEY (data_warning_id));

-- --------------------------------------------------------- registration field warnings
drop temporary table if exists temp_reg;
create temporary table temp_reg
(patient_id      int(11),
warning_type     varchar(255),
datetime_entered datetime, 
creator          int(11),  
encounter_id     int(11),
encounter_datetime datetime);    

insert into temp_reg (patient_id,datetime_entered, creator, warning_type)
select patient_id,date_created, creator, 'blank emr_id'
from patient p 
where p.voided = 0 and patient_identifier(patient_id, metadata_uuid('org.openmrs.module.emrapi', 'emr.primaryIdentifierType')) is null;

insert into temp_reg (patient_id, datetime_entered, creator, warning_type)
select patient_id, p.date_created, p.creator, 'blank birthdate'
from patient p
inner join person ps on ps.person_id = p.patient_id
where p.voided = 0 
and birthdate is null
and unknown_patient(p.patient_id) is null;

insert into temp_reg (patient_id, datetime_entered, creator, warning_type)
select patient_id, p.date_created, p.creator, 'blank gender'
from patient p
inner join person ps on ps.person_id = p.patient_id
where p.voided = 0 and gender is null;

insert into temp_reg (patient_id, datetime_entered, creator, warning_type)
select patient_id, p.date_created, p.creator, 'death date before birthdate'
from patient p
inner join person ps on ps.person_id = p.patient_id
where p.voided = 0 
and ps.death_date < birthdate;

insert into temp_reg (patient_id, datetime_entered, creator, warning_type)
select patient_id, p.date_created, p.creator, 'blank address'
from patient p
where p.voided = 0 
and not exists 
	(select 1 from person_address pa 
	where pa.person_id = p.patient_id
	and pa.voided = 0)
and unknown_patient(p.patient_id) is null;

insert into temp_reg (patient_id, datetime_entered, creator, warning_type)
select patient_id, p.date_created, p.creator, 'blank name'
from patient p
where p.voided = 0 
and not exists 
	(select 1 from person_name pn 
	where pn.person_id = p.patient_id
	and pn.voided = 0)
and unknown_patient(p.patient_id) is null;

insert into temp_reg (patient_id, datetime_entered, creator, warning_type)
select patient_id, p.date_created, p.creator, 'unknown patient > 10 days'
from patient p 
inner join person_attribute pa on 
	pa.person_id = p.patient_id and person_attribute_type_id = 11 and value = 'true'
where p.voided = 0
and datediff(now(), p.date_created) > 10;

create index temp_reg_pi on temp_reg(patient_id);

-- encounter fields
drop temporary table if exists temp_reg_encounters;
create temporary table temp_reg_encounters 
select e.patient_id, e.encounter_id, e.encounter_datetime from encounter e
inner join temp_reg t on t.patient_id = e.patient_id
where e.encounter_type = @registrationEncType;

update temp_reg t 
inner join encounter e on e.encounter_id = 
	(select e2.encounter_id from temp_reg_encounters e2
	where e2.patient_id = t.patient_id
	order by encounter_datetime asc, encounter_id asc
	limit 1)
set t.encounter_id = e.encounter_id,
	t.encounter_datetime = e.encounter_datetime;

insert into temp_warnings (patient_id,datetime_entered, encounter_id, encounter_datetime, creator, warning_type, event_type)
select patient_id,datetime_entered, encounter_id, encounter_datetime, creator, warning_type, 'patient registration' 
from temp_reg;

-- --------------------------------------------------------- visits no encounters
insert into temp_warnings (warning_type, event_type, patient_id, visit_id, creator, visit_date_started, visit_date_stopped)
select 'visit with no encounters', 'patient_visit', patient_id, visit_id, creator, date_started, date_stopped  from visit v
where v.voided = 0 
and not exists
	(select 1 from encounter e
	where e.visit_id = v.visit_id
	and e.voided = 0);

-- --------------------------------------------------------- encounters with no obs
insert into temp_warnings (warning_type, event_type, encounter_id, encounter_datetime, datetime_entered, patient_id, visit_id, creator, visit_date_started, visit_date_stopped)
select 'encounters with no observations', et.name, e.encounter_id, e.encounter_datetime, e.date_created, e.patient_id, e.visit_id, e.creator, v.date_started, v.date_stopped  
from visit v
inner join encounter e on e.visit_id = v.visit_id and e.voided = 0
inner join encounter_type et on et.encounter_type_id = e.encounter_type 
	and et.encounter_type_id not in (@admission, @bed_assignment, @drug_order, @discharge, @rad_order, @test_order, @transfer, @check_in)
where v.voided = 0 
and not exists
	(select 1 from obs o
	where e.encounter_id = o.encounter_id 
	and o.voided = 0)
and not exists
	(select 1 from orders od 
	where e.encounter_id = od.encounter_id
	and od.voided = 0);

-- --------------------------------------------------------- visits > 10 days
insert into temp_warnings (warning_type, event_type, patient_id, visit_id, creator, visit_date_started, visit_date_stopped)
select 'visit > 10 days', 'patient_visit', patient_id, visit_id, creator, date_started, date_stopped  from visit v
where v.voided = 0 
and datediff(coalesce(date_stopped, now()), date_started) > 10;

-- --------------------------------------------------------- age at encounter > 105
drop temporary table if exists temp_latest_encounter;
create temporary table temp_latest_encounter
(select patient_id, max(encounter_datetime) "latest_datetime"
	from encounter e 
	where e.voided = 0
	group by patient_id);

create index temp_latest_encounter_p on temp_latest_encounter(patient_id);
create index temp_latest_encounter_c1 on temp_latest_encounter(patient_id, latest_datetime);

insert into temp_warnings (event_type, warning_type, patient_id, datetime_entered, creator, encounter_id, encounter_datetime,  other_details)
select 'patient_registration', 'age at encounter > 105', p.person_id, p.date_created, p.creator, e.encounter_id, e.encounter_datetime,
concat('patient birthdate =',p.birthdate)
from person p 
inner join temp_latest_encounter le on le.patient_id = p.person_id
inner join encounter e on e.patient_id = le.patient_id and le.latest_datetime = e.encounter_datetime
where timestampdiff(YEAR, p.birthdate , encounter_datetime) >105
;

-- --------------------------------------------------------- invalid encounters for male
insert into temp_warnings (event_type, warning_type, patient_id, datetime_entered, creator, encounter_id, encounter_datetime)
select  et.name, 'invalid encounter for male',p.person_id, e.date_created, e.creator, e.encounter_id, e.encounter_datetime 
from person p 
inner join encounter e on p.person_id = e.patient_id 
	and e.encounter_type in (
		@anc_intake,
		@anc_followup,
		@mch_delivery,
		@obgyn,
		@prenatal_home_assessment,
		@maternal_post_partum_home_assessment,
		@maternal_follow_up_home_assessment,
		@pmtct_intake,
		@pmtct_followup,
		@maternity_and_delivery_register,
		@labour_progress,
		@labor_and_delivery_summary,
		@sierra_leone_maternal_check_in,
		@maternal_discharge,
		@sierra_leone_maternal_triage,
		@sierra_leone_mch_triage,
		@postpartum_progress,
		@sierra_leone_maternal_admission)
	and e.voided = 0
inner join encounter_type et on et.encounter_type_id = e.encounter_type 	
where p.voided = 0
and p.gender = 'M';

-- --------------------------------------------------------- exclude voided patients (LIB-427)
-- all_patients only includes non-voided patients (patient.voided = 0), so remove any
-- warning whose patient is voided or missing. Covers every warning type above.
delete t from temp_warnings t
where not exists
	(select 1 from patient p
	where p.patient_id = t.patient_id
	and p.voided = 0);

-- ------------------------ common fields
-- emr_id
set @primary_emr_id_type_uuid =  metadata_uuid('org.openmrs.module.emrapi', 'emr.primaryIdentifierType');
update temp_warnings t 
set emr_id = patient_identifier(patient_id, @primary_emr_id_type_uuid)
where t.warning_type <> 'blank emr_id';

-- visit details
update temp_warnings t 
inner join encounter e on e.encounter_id = t.encounter_id
inner join visit v on v.visit_id = e.visit_id
set t.visit_id = v.visit_id,
	t.visit_date_started = v.date_started,
	t.visit_date_stopped = v.date_stopped
where t.encounter_id is not null;

-- user entered from creator
update temp_warnings t 
set user_entered = person_name_of_user(creator);

-- event datetime
update temp_warnings t 
set event_datetime = coalesce(encounter_datetime, visit_date_started, datetime_entered);

-- final select
select
	data_warning_id,
	warning_type,
	event_type,
	event_datetime,
	concat(@partition, '-', patient_id) as patient_id,
	emr_id,
	concat(@partition, '-', visit_id) as visit_id,
	concat(@partition, '-', encounter_id) as encounter_id,
	concat(@partition, '-', patient_program_id) as patient_program_id,
	encounter_datetime,
	datetime_entered,
	visit_date_started,
	visit_date_stopped,
	user_entered,
	other_details 
from temp_warnings;
