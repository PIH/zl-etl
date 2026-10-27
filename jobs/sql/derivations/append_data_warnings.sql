-- note that this script APPENDS to the data_warnings table that is created in an extract.
-- ported from sl-etl/jobs/sql/derivations/append_data_warnings.sql for ZL.
-- runs in the warehouse after every site has loaded (refresh-derived-tables.yml).
-- avoid semicolons inside comments and strings: petl splits this file on the semicolon delimiter

-- --------------------------------------------------- remove any previously appended rows
-- each site refresh replaces its own partition of data_warnings, but if a site failed to refresh
-- its old appended rows would still be there, so clear them first to avoid duplicates
delete from data_warnings
where warning_type in (
	'Followup without Intake',
	'Duplicate encounters within visit',
	'Duplicate encounters within program',
	'Inpatient encounters before admission',
	'Duplicate emr_ids',
	'return_visit_date not in future');

drop table if exists #temp_data_warnings;
create table #temp_data_warnings
(
data_warning_id    int IDENTITY(1,1) primary key,
warning_type       varchar(255),
event_type         varchar(255),
event_datetime     datetime,
location           varchar(255),
parent_location    varchar(255),
patient_id         varchar(50),
emr_id             varchar(50),
visit_id           varchar(50),
encounter_id       varchar(50),
patient_program_id varchar(50),
encounter_datetime datetime,
datetime_entered   datetime,
visit_date_started datetime,
visit_date_stopped datetime,
user_entered       text,
other_details      text,
server             varchar(100),
partition_num      int
);

-- -------------------------------------------------- followup without intake
-- flags the first followup in each program (or patient, for NCD) that has no intake on or before it

-- HIV (within HIV program enrollment)
with first_followup as (
	select e.*, v.hiv_program_id,
		row_number() over (partition by v.hiv_program_id order by e.encounter_datetime, e.encounter_id) as rn
	from hiv_visit v
	inner join all_encounters e on e.encounter_id = v.encounter_id
	where v.encounter_type = 'HIV Followup'
	and v.hiv_program_id is not null)
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, patient_program_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num)
select 'Followup without Intake', f.encounter_type_name, f.patient_id, f.emr_id, f.visit_id, f.encounter_id, f.hiv_program_id,
f.encounter_datetime, f.entered_datetime, f.user_entered, f.server, f.partition_num
from first_followup f
where f.rn = 1
and not exists
	(select 1 from hiv_visit v2
	inner join all_encounters e2 on e2.encounter_id = v2.encounter_id
	where v2.hiv_program_id = f.hiv_program_id
	and v2.encounter_type = 'HIV Intake'
	and e2.encounter_datetime <= f.encounter_datetime);

-- ANC (within MCH program enrollment)
with first_followup as (
	select e.*, v.mch_program_id,
		row_number() over (partition by v.mch_program_id order by e.encounter_datetime, e.encounter_id) as rn
	from mch_visit v
	inner join all_encounters e on e.encounter_id = v.encounter_id
	where e.encounter_type_name = 'ANC Followup'
	and v.mch_program_id is not null)
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, patient_program_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num)
select 'Followup without Intake', f.encounter_type_name, f.patient_id, f.emr_id, f.visit_id, f.encounter_id, f.mch_program_id,
f.encounter_datetime, f.entered_datetime, f.user_entered, f.server, f.partition_num
from first_followup f
where f.rn = 1
and not exists
	(select 1 from mch_visit v2
	inner join all_encounters e2 on e2.encounter_id = v2.encounter_id
	where v2.mch_program_id = f.mch_program_id
	and e2.encounter_type_name = 'ANC Intake'
	and e2.encounter_datetime <= f.encounter_datetime);

-- NCD (by patient, no program id available in all_encounters)
with first_followup as (
	select e.*,
		row_number() over (partition by e.patient_id order by e.encounter_datetime, e.encounter_id) as rn
	from all_encounters e
	where e.encounter_type_name = 'NCD Followup Consult')
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num)
select 'Followup without Intake', f.encounter_type_name, f.patient_id, f.emr_id, f.visit_id, f.encounter_id,
f.encounter_datetime, f.entered_datetime, f.user_entered, f.server, f.partition_num
from first_followup f
where f.rn = 1
and not exists
	(select 1 from all_encounters e2
	where e2.patient_id = f.patient_id
	and e2.encounter_type_name = 'NCD Initial Consult'
	and e2.encounter_datetime <= f.encounter_datetime);

-- -------------------------------------------------- duplicate encounters within visit
-- one row per patient/visit/encounter type, pointing at the latest duplicate
drop table if exists #temp_dup_encounters;
select e.patient_id, e.visit_id, e.encounter_type_name, max(e.encounter_id) max_encounter_id, count(*) count
into #temp_dup_encounters
from all_encounters e
where e.visit_id is not null
and e.encounter_type_name in
('Check-in',
'Primary Care Adult Initial Consult',
'Primary Care Adult Followup Consult',
'Primary Care Pediatric Initial Consult',
'Primary Care Pediatric Followup Consult',
'NCD Initial Consult',
'NCD Followup Consult',
'ANC Intake',
'ANC Followup',
'HIV Intake',
'HIV Followup',
'Mental Health Consult',
'Emergency Triage',
'Admission',
'Exit from Inpatient Care')
group by e.patient_id, e.visit_id, e.encounter_type_name
having count(*) > 1;

insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num, other_details)
select 'Duplicate encounters within visit', e.encounter_type_name, e.patient_id, e.emr_id, e.visit_id, e.encounter_id,
e.encounter_datetime, e.entered_datetime, e.user_entered, e.server, e.partition_num,
concat('number of encounters: ', t.count)
from all_encounters e
inner join #temp_dup_encounters t on t.max_encounter_id = e.encounter_id;

-- -------------------------------------------------- duplicate encounters within program
-- ANC intake (per MCH program enrollment)
drop table if exists #temp_dup_encounters;
select v.mch_program_id, max(e.encounter_id) max_encounter_id, count(*) count
into #temp_dup_encounters
from mch_visit v
inner join all_encounters e on e.encounter_id = v.encounter_id
where e.encounter_type_name = 'ANC Intake'
and v.mch_program_id is not null
group by v.mch_program_id
having count(*) > 1;

insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, patient_program_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num, other_details)
select 'Duplicate encounters within program', e.encounter_type_name, e.patient_id, e.emr_id, e.visit_id, e.encounter_id, t.mch_program_id,
e.encounter_datetime, e.entered_datetime, e.user_entered, e.server, e.partition_num,
concat('number of encounters: ', t.count)
from all_encounters e
inner join #temp_dup_encounters t on t.max_encounter_id = e.encounter_id;

-- HIV intake (per HIV program enrollment)
drop table if exists #temp_dup_encounters;
select v.hiv_program_id, max(e.encounter_id) max_encounter_id, count(*) count
into #temp_dup_encounters
from hiv_visit v
inner join all_encounters e on e.encounter_id = v.encounter_id
where v.encounter_type = 'HIV Intake'
and v.hiv_program_id is not null
group by v.hiv_program_id
having count(*) > 1;

insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, patient_program_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num, other_details)
select 'Duplicate encounters within program', e.encounter_type_name, e.patient_id, e.emr_id, e.visit_id, e.encounter_id, t.hiv_program_id,
e.encounter_datetime, e.entered_datetime, e.user_entered, e.server, e.partition_num,
concat('number of encounters: ', t.count)
from all_encounters e
inner join #temp_dup_encounters t on t.max_encounter_id = e.encounter_id;

-- MCH delivery (per MCH program enrollment)
drop table if exists #temp_dup_encounters;
select d.mch_program_id, max(d.encounter_id) max_encounter_id, count(*) count
into #temp_dup_encounters
from mch_delivery d
where d.mch_program_id is not null
group by d.mch_program_id
having count(*) > 1;

insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, patient_program_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num, other_details)
select 'Duplicate encounters within program', e.encounter_type_name, e.patient_id, e.emr_id, e.visit_id, e.encounter_id, t.mch_program_id,
e.encounter_datetime, e.entered_datetime, e.user_entered, e.server, e.partition_num,
concat('number of encounters: ', t.count)
from all_encounters e
inner join #temp_dup_encounters t on t.max_encounter_id = e.encounter_id;

-- -------------------------------------------------- inpatient encounters before admission
-- earliest discharge/transfer in each visit with no admission on or before it
with first_inpatient as (
	select e.*,
		row_number() over (partition by e.visit_id order by e.encounter_datetime, e.encounter_id) as rn
	from all_encounters e
	where e.visit_id is not null
	and e.encounter_type_name in ('Exit from Inpatient Care', 'Transfer'))
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num)
select 'Inpatient encounters before admission', f.encounter_type_name, f.patient_id, f.emr_id, f.visit_id, f.encounter_id,
f.encounter_datetime, f.entered_datetime, f.user_entered, f.server, f.partition_num
from first_inpatient f
where f.rn = 1
and not exists
	(select 1 from all_encounters e2
	where e2.visit_id = f.visit_id
	and e2.encounter_type_name = 'Admission'
	and e2.encounter_datetime <= f.encounter_datetime);

-- -------------------------------------------------- duplicate emr_id
-- compared within the same server only: the HIV server holds its own copy of patients
-- who are also on a site server, so the same emr_id across servers is expected
-- linked to the patient's most recent registration encounter, as in the extract
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, encounter_datetime, datetime_entered,
user_entered, server, partition_num, other_details)
select 'Duplicate emr_ids', 'patient_registration', p.patient_id, p.emr_id, r.visit_id, r.encounter_id,
coalesce(r.encounter_datetime, p.registration_date), p.date_registration_entered,
p.user_entered, p.server, p.partition_num, concat('other patient_id: ', p2.patient_id)
from all_patients p
inner join all_patients p2 on p2.emr_id = p.emr_id
	and p2.server = p.server
	and p2.patient_id <> p.patient_id
outer apply
	(select top 1 r1.encounter_id, r1.visit_id, r1.encounter_datetime
	from all_encounters r1
	where r1.patient_id = p.patient_id
	and r1.encounter_type_name = 'Patient Registration'
	order by r1.encounter_datetime desc, r1.encounter_id desc) r
where p.emr_id is not null;

-- --------------------------------------------------- return_visit_date not in future
-- all_encounters.next_appt_date covers every form that records a next appointment date
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num, other_details)
select 'return_visit_date not in future', e.encounter_type_name, e.patient_id, e.emr_id, e.visit_id, e.encounter_id,
e.encounter_datetime, e.entered_datetime, e.user_entered, e.server, e.partition_num,
concat('next appointment date: ', e.next_appt_date)
from all_encounters e
where e.next_appt_date <= cast(e.encounter_datetime as date);

-- -------------------------------------------------- visit details
update t
set t.visit_date_started = v.visit_date_started,
	t.visit_date_stopped = v.visit_date_stopped
from #temp_data_warnings t
inner join all_visits v on v.visit_id = t.visit_id;

-- -------------------------------------------------- location and parent location
-- location: encounter location, then visit location, then the patient's registration location.
-- parent location: the warehouse only stores location names, so this uses the visit location
-- (the facility the encounter belongs to), then all_encounters.site (the Visit Location ancestor
-- of the encounter location), then the location itself. site is skipped on the HIV server
-- because force_site_for_hiv_server sets it to 'hiv' there.
update t
set t.location = coalesce(e.encounter_location, v.visit_location, p.reg_location),
	t.parent_location = coalesce(
		e.visit_location,
		case when e.server <> 'hiv' then e.site end,
		v.visit_location,
		e.encounter_location,
		p.reg_location)
from #temp_data_warnings t
left join all_encounters e on e.encounter_id = t.encounter_id
left join all_visits v on v.visit_id = t.visit_id
left join all_patients p on p.patient_id = t.patient_id;

-- -------------------------------------------------- event datetime
update t
set t.event_datetime = coalesce(t.encounter_datetime, t.visit_date_started, t.datetime_entered)
from #temp_data_warnings t;

-- --------------------------------------------------- final insert
insert into data_warnings
	(data_warning_id,
	warning_type,
	event_type,
	event_datetime,
	location,
	parent_location,
	patient_id,
	emr_id,
	visit_id,
	encounter_id,
	patient_program_id,
	encounter_datetime,
	datetime_entered,
	visit_date_started,
	visit_date_stopped,
	user_entered,
	other_details,
	server,
	partition_num)
select
	(select isnull(max(data_warning_id), 0) from data_warnings) + data_warning_id,
	warning_type,
	event_type,
	event_datetime,
	location,
	parent_location,
	patient_id,
	emr_id,
	visit_id,
	encounter_id,
	patient_program_id,
	encounter_datetime,
	datetime_entered,
	visit_date_started,
	visit_date_stopped,
	user_entered,
	other_details,
	server,
	partition_num
from #temp_data_warnings;
