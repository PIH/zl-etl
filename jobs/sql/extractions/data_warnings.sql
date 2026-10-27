-- ZL data_warnings extraction
-- Ported from sl-etl/jobs/sql/extractions/data_warnings.sql (15-column layout),
-- with the existing ZL program/HIV warnings carried over.

set @partition = '${partitionNum}';
set @sitename = '${siteName}';

-- --------------------------------------------------------- metadata
set @registration_enc     = encounter_type('873f968a-73a8-4f9c-ac78-9f4778b751b6');

-- maternal / women's health encounter types (used for "invalid encounter for male")
set @anc_intake           = encounter_type('00e5e810-90ec-11e8-9eb6-529269fb1459');
set @anc_followup         = encounter_type('00e5e946-90ec-11e8-9eb6-529269fb1459');
set @mch_delivery         = encounter_type('00e5ebb2-90ec-11e8-9eb6-529269fb1459');
set @obgyn                = encounter_type('d83e98fd-dc7b-420f-aa3f-36f648b4483d');
set @pmtct_intake         = encounter_type('584124b9-1f10-4757-ba09-91fc9075af92');
set @pmtct_followup       = encounter_type('95e03e7d-9aeb-4a99-bd7a-94e8591ec2c5');

-- HIV
set @hiv_exposed_infant_enrollment_program = program('EID');
set @hiv_program          = program('HIV');
set @hiv_dispensing       = encounter_type('cc1720c9-3e4c-4fa8-a7ec-40eeaad1958c');
set @hiv_initial          = encounter_type('c31d306a-40c4-11e7-a919-92ebcb67fe33');
set @hiv_followup         = encounter_type('c31d3312-40c4-11e7-a919-92ebcb67fe33');
set @exposed_infant_followup = encounter_type('0f070640-279e-4ec0-9e6c-6ef1f6567030');
set @drug_order_type      = (select order_type_id from order_type where uuid = '131168f4-15f5-102d-96e4-000c29c2a5d7');

-- encounter types that are not expected to have obs (excluded from "encounters with no observations").
-- held in a table rather than a NOT IN list so a type missing on a server (null id) doesn't wipe out the check
drop temporary table if exists temp_no_obs_expected;
create temporary table temp_no_obs_expected (encounter_type_id int(11) primary key);
insert ignore into temp_no_obs_expected (encounter_type_id)
select encounter_type_id from encounter_type
where uuid in (
	'260566e1-c909-4d61-a96f-c1019291a09d', -- admission
	'caa222d6-d7d0-408f-a104-320e7556e9ff', -- bed assignment
	'0b242b71-5b60-11eb-8f5a-0242ac110002', -- drug order
	'b6631959-2105-49dd-b154-e1249e0fbcd7', -- exit from inpatient care / discharge
	'1b3d1e13-f0b1-4b83-86ea-b1b1e2fb4efa', -- radiology order
	'b3a0e3ad-b80c-4f3f-9626-ace1ced7e2dd', -- test order
	'436cfe33-6b81-40ef-a455-f134a9f7e580', -- transfer
	'55a0d3ea-a4d7-4e88-8f01-5aceb2d3c61b'  -- check-in
	);

drop temporary table if exists temp_warnings;
create temporary table temp_warnings
(
data_warning_id    int(11) NOT NULL AUTO_INCREMENT,
warning_type       varchar(255),
event_type         varchar(255),
event_datetime     datetime,
location_id        int(11),
location           varchar(255),
parent_location    varchar(255),
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
(patient_id         int(11),
warning_type        varchar(255),
datetime_entered    datetime,
creator             int(11),
encounter_id        int(11),
encounter_datetime  datetime,
other_details       text);

insert into temp_reg (patient_id, datetime_entered, creator, warning_type, other_details)
select patient_id, date_created, creator, 'blank emr_id', concat('site: ', @sitename)
from patient p
where p.voided = 0
and zlemr(p.patient_id) is null;

insert into temp_reg (patient_id, datetime_entered, creator, warning_type)
select patient_id, p.date_created, p.creator, 'blank birthdate'
from patient p
inner join person ps on ps.person_id = p.patient_id
where p.voided = 0
and ps.birthdate is null
and unknown_patient(p.patient_id) is null;

insert into temp_reg (patient_id, datetime_entered, creator, warning_type)
select patient_id, p.date_created, p.creator, 'blank gender'
from patient p
inner join person ps on ps.person_id = p.patient_id
where p.voided = 0
and ps.gender is null
and unknown_patient(p.patient_id) is null;

insert into temp_reg (patient_id, datetime_entered, creator, warning_type, other_details)
select patient_id, p.date_created, p.creator, 'death date before birthdate',
concat('death date: ', ps.death_date, ' | birth date: ', ps.birthdate)
from patient p
inner join person ps on ps.person_id = p.patient_id
where p.voided = 0
and ps.death_date < ps.birthdate;

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

-- kept from ZL: catches a name record that exists but is missing the given or family name
insert into temp_reg (patient_id, datetime_entered, creator, warning_type, other_details)
select p.patient_id, p.date_created, p.creator, 'blank given or family name',
concat('given name: ', ifnull(pn.given_name, ''), ' | family name: ', ifnull(pn.family_name, ''))
from patient p
inner join person_name pn on pn.person_id = p.patient_id
	and pn.voided = 0
	and (nullif(trim(pn.given_name), '') is null or nullif(trim(pn.family_name), '') is null)
where p.voided = 0
and unknown_patient(p.patient_id) is null;

insert into temp_reg (patient_id, datetime_entered, creator, warning_type)
select patient_id, p.date_created, p.creator, 'unknown patient > 10 days'
from patient p
where p.voided = 0
and unknown_patient(p.patient_id) is not null
and datediff(now(), p.date_created) > 10;

create index temp_reg_pi on temp_reg(patient_id);

-- link each registration warning to the patient's registration encounter
-- (a patient should have only one; if there are several, use the most recent)
drop temporary table if exists temp_reg_encounters;
create temporary table temp_reg_encounters
select e.patient_id, e.encounter_id, e.encounter_datetime
from encounter e
where e.voided = 0
and e.encounter_type = @registration_enc
and e.patient_id in (select patient_id from temp_reg);

create index temp_reg_encounters_pi on temp_reg_encounters(patient_id);

update temp_reg t
inner join encounter e on e.encounter_id =
	(select e2.encounter_id from temp_reg_encounters e2
	where e2.patient_id = t.patient_id
	order by e2.encounter_datetime desc, e2.encounter_id desc
	limit 1)
set t.encounter_id = e.encounter_id,
	t.encounter_datetime = e.encounter_datetime;

insert into temp_warnings (patient_id, datetime_entered, encounter_id, encounter_datetime, creator, warning_type, event_type, other_details)
select patient_id, datetime_entered, encounter_id, encounter_datetime, creator, warning_type, 'patient_registration', other_details
from temp_reg;

-- --------------------------------------------------------- visits with no encounters
insert into temp_warnings (warning_type, event_type, patient_id, visit_id, creator, datetime_entered, visit_date_started, visit_date_stopped)
select 'visit with no encounters', 'patient_visit', patient_id, visit_id, creator, date_created, date_started, date_stopped
from visit v
where v.voided = 0
and not exists
	(select 1 from encounter e
	where e.visit_id = v.visit_id
	and e.voided = 0);

-- --------------------------------------------------------- encounters with no obs (and no orders)
insert into temp_warnings (warning_type, event_type, encounter_id, encounter_datetime, datetime_entered, patient_id, visit_id, creator, visit_date_started, visit_date_stopped)
select 'encounters with no observations', et.name, e.encounter_id, e.encounter_datetime, e.date_created, e.patient_id, e.visit_id, e.creator, v.date_started, v.date_stopped
from visit v
inner join encounter e on e.visit_id = v.visit_id and e.voided = 0
inner join encounter_type et on et.encounter_type_id = e.encounter_type
where v.voided = 0
and not exists
	(select 1 from temp_no_obs_expected x
	where x.encounter_type_id = e.encounter_type)
and not exists
	(select 1 from obs o
	where o.encounter_id = e.encounter_id
	and o.voided = 0)
and not exists
	(select 1 from orders od
	where od.encounter_id = e.encounter_id
	and od.voided = 0);

-- --------------------------------------------------------- visits > 10 days
insert into temp_warnings (warning_type, event_type, patient_id, visit_id, creator, datetime_entered, visit_date_started, visit_date_stopped)
select 'visit > 10 days', 'patient_visit', patient_id, visit_id, creator, date_created, date_started, date_stopped
from visit v
where v.voided = 0
and datediff(coalesce(date_stopped, now()), date_started) > 10;

-- --------------------------------------------------------- age at encounter > 105
drop temporary table if exists temp_latest_encounter;
create temporary table temp_latest_encounter
(select patient_id, max(encounter_datetime) "latest_datetime"
	from encounter e
	where e.voided = 0
	group by patient_id);

create index temp_latest_encounter_c1 on temp_latest_encounter(patient_id, latest_datetime);

insert into temp_warnings (event_type, warning_type, patient_id, datetime_entered, creator, encounter_id, encounter_datetime, other_details)
select 'patient_registration', 'age at encounter > 105', p.person_id, p.date_created, p.creator, max(e.encounter_id), le.latest_datetime,
concat('patient birthdate: ', p.birthdate)
from person p
inner join temp_latest_encounter le on le.patient_id = p.person_id
inner join encounter e on e.patient_id = le.patient_id and e.encounter_datetime = le.latest_datetime and e.voided = 0
where timestampdiff(YEAR, p.birthdate, le.latest_datetime) > 105
group by p.person_id, p.date_created, p.creator, le.latest_datetime, p.birthdate;

-- --------------------------------------------------------- invalid encounters for male
insert into temp_warnings (event_type, warning_type, patient_id, datetime_entered, creator, encounter_id, encounter_datetime)
select et.name, 'invalid encounter for male', p.person_id, e.date_created, e.creator, e.encounter_id, e.encounter_datetime
from person p
inner join encounter e on p.person_id = e.patient_id
	and e.encounter_type in (
		@anc_intake,
		@anc_followup,
		@mch_delivery,
		@obgyn,
		@pmtct_intake,
		@pmtct_followup)
	and e.voided = 0
inner join encounter_type et on et.encounter_type_id = e.encounter_type
where p.voided = 0
and p.gender = 'M';

-- --------------------------------------------------------- overlapping program enrollments (from ZL)
insert into temp_warnings (warning_type, event_type, event_datetime, patient_id, patient_program_id, datetime_entered, creator, other_details)
select 'overlapping program enrollments', p.name, pp.date_enrolled, pp.patient_id, pp.patient_program_id, pp.date_created, pp.creator,
concat('overlaps patient_program_id: ', pp2.patient_program_id,
	' | enrolled: ', date(pp.date_enrolled), ' to ', ifnull(date(pp.date_completed), 'active'),
	' | other enrolled: ', date(pp2.date_enrolled), ' to ', ifnull(date(pp2.date_completed), 'active'))
from patient_program pp
inner join program p on p.program_id = pp.program_id
inner join patient_program pp2 on pp2.voided = 0
	and pp2.patient_id = pp.patient_id
	and pp2.program_id = pp.program_id
	and pp2.patient_program_id <> pp.patient_program_id
	and pp.date_enrolled < pp2.date_enrolled
	and ifnull(pp.date_completed, '9999-12-31') > pp2.date_enrolled
where pp.voided = 0;

-- --------------------------------------------------------- HIV encounters without HIV or EID enrollment (from ZL)
-- one warning per patient per encounter type, pointing at the first such encounter
drop temporary table if exists temp_hiv_no_enrollment;
create temporary table temp_hiv_no_enrollment
select e.patient_id, e.encounter_type, min(e.encounter_datetime) first_datetime
from encounter e
where e.voided = 0
and e.encounter_type in (@hiv_initial, @hiv_followup, @exposed_infant_followup, @hiv_dispensing)
and not exists
	(select 1 from patient_program pp
	where pp.voided = 0
	and pp.program_id in (@hiv_program, @hiv_exposed_infant_enrollment_program)
	and pp.patient_id = e.patient_id)
group by e.patient_id, e.encounter_type;

insert into temp_warnings (warning_type, event_type, patient_id, encounter_id, encounter_datetime, datetime_entered, creator)
select
	case t.encounter_type
		when @hiv_initial then 'HIV initial encounter without any HIV or exposed infant enrollment'
		when @hiv_followup then 'HIV followup encounter without any HIV or exposed infant enrollment'
		when @exposed_infant_followup then 'HIV exposed infant followup without any HIV or exposed infant enrollment'
		when @hiv_dispensing then 'HIV dispensing encounter without any HIV or exposed infant enrollment'
	end,
	et.name, e.patient_id, e.encounter_id, e.encounter_datetime, e.date_created, e.creator
from temp_hiv_no_enrollment t
inner join encounter e on e.encounter_id =
	(select e2.encounter_id from encounter e2
	where e2.patient_id = t.patient_id
	and e2.encounter_type = t.encounter_type
	and e2.encounter_datetime = t.first_datetime
	and e2.voided = 0
	order by e2.encounter_id asc
	limit 1)
inner join encounter_type et on et.encounter_type_id = e.encounter_type;

-- --------------------------------------------------------- HIV dispensing without any prescriptions (from ZL)
drop temporary table if exists temp_hiv_disp_no_orders;
create temporary table temp_hiv_disp_no_orders
select e.patient_id, min(e.encounter_datetime) first_datetime
from encounter e
where e.voided = 0
and e.encounter_type = @hiv_dispensing
and not exists
	(select 1 from orders o
	where o.order_type_id = @drug_order_type
	and o.voided = 0
	and o.patient_id = e.patient_id)
group by e.patient_id;

insert into temp_warnings (warning_type, event_type, patient_id, encounter_id, encounter_datetime, datetime_entered, creator)
select 'HIV dispensing without any prescriptions', et.name, e.patient_id, e.encounter_id, e.encounter_datetime, e.date_created, e.creator
from temp_hiv_disp_no_orders t
inner join encounter e on e.encounter_id =
	(select e2.encounter_id from encounter e2
	where e2.patient_id = t.patient_id
	and e2.encounter_type = @hiv_dispensing
	and e2.encounter_datetime = t.first_datetime
	and e2.voided = 0
	order by e2.encounter_id asc
	limit 1)
inner join encounter_type et on et.encounter_type_id = e.encounter_type;

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
update temp_warnings t
set emr_id = zlemr(t.patient_id)
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

-- location: encounter location, then visit location, then program enrollment location
update temp_warnings t
left join encounter e on e.encounter_id = t.encounter_id
left join visit v on v.visit_id = t.visit_id
left join patient_program pp on pp.patient_program_id = t.patient_program_id
set t.location_id = coalesce(e.location_id, v.location_id, pp.location_id);

-- fallback for patient-level warnings with no encounter, visit or program: location of the patient's ZL EMR ID
update temp_warnings t
set t.location_id =
	(select pi.location_id from patient_identifier pi
	inner join patient_identifier_type pit on pit.patient_identifier_type_id = pi.identifier_type
		and pit.name = 'ZL EMR ID'
	where pi.patient_id = t.patient_id
	and pi.voided = 0
	order by pi.preferred desc, pi.date_created asc
	limit 1)
where t.location_id is null;

-- location name, and parent location using the same logic as encounter_parent_location_name()
-- (the location itself if it has no parent, otherwise its parent, otherwise its grandparent)
update temp_warnings t
inner join location l on l.location_id = t.location_id
left outer join location lp on lp.location_id = l.parent_location
left outer join location lp2 on lp2.location_id = lp.parent_location
set t.location = l.name,
	t.parent_location = if(l.parent_location is null, l.name, if(lp.parent_location is null, lp.name, lp2.name));

-- event datetime (program warnings set their own above)
update temp_warnings t
set event_datetime = coalesce(event_datetime, encounter_datetime, visit_date_started, datetime_entered);

-- final select
select
	data_warning_id,
	warning_type,
	event_type,
	event_datetime,
	location,
	parent_location,
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
