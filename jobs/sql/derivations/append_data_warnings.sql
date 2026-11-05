-- note that this script APPENDS to the data_warnings table that is created in an extract.
-- ported from sl-etl/jobs/sql/derivations/append_data_warnings.sql for ZL.
-- runs in the warehouse after every site has loaded (refresh-derived-tables.yml).
-- avoid semicolons inside comments and strings: petl splits this file on the semicolon delimiter
-- encounter types are matched on encounter_type_uuid, not encounter_type_name, because the names
-- are translated on some servers (e.g. French in Haiti). names are kept in comments for readability

-- --------------------------------------------------- remove any previously appended rows
-- each site refresh replaces its own partition of data_warnings, but if a site failed to refresh
-- its old appended rows would still be there, so clear them first to avoid duplicates
delete from data_warnings
where warning_type in (
	'Followup without Intake',
	'Intake after Followup',
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

-- -------------------------------------------------- first followup per program (or patient, for NCD)
-- computed once and reused by both 'Followup without Intake' and 'Intake after Followup'.
-- the earliest followup in a program is also the earliest followup before any intake that comes
-- after it, so 'Intake after Followup' becomes a plain join instead of a per-intake CROSS APPLY
-- (all_encounters has no indexes, so each CROSS APPLY iteration was a full table scan)

-- HIV (within HIV program enrollment)
drop table if exists #first_hiv_fu;
select x.encounter_type_name, x.patient_id, x.emr_id, x.visit_id, x.encounter_id, x.hiv_program_id,
x.encounter_datetime, x.entered_datetime, x.user_entered, x.server, x.partition_num
into #first_hiv_fu
from
	(select e.*, v.hiv_program_id,
		row_number() over (partition by v.hiv_program_id order by e.encounter_datetime, e.encounter_id) as rn
	from hiv_visit v
	inner join all_encounters e on e.encounter_id = v.encounter_id
	where v.encounter_type = 'HIV Followup'
	and v.hiv_program_id is not null) x
where x.rn = 1;

-- ANC (within MCH program enrollment)
drop table if exists #first_anc_fu;
select x.encounter_type_name, x.patient_id, x.emr_id, x.visit_id, x.encounter_id, x.mch_program_id,
x.encounter_datetime, x.entered_datetime, x.user_entered, x.server, x.partition_num
into #first_anc_fu
from
	(select e.*, v.mch_program_id,
		row_number() over (partition by v.mch_program_id order by e.encounter_datetime, e.encounter_id) as rn
	from mch_visit v
	inner join all_encounters e on e.encounter_id = v.encounter_id
	where e.encounter_type_uuid = '00e5e946-90ec-11e8-9eb6-529269fb1459' /* ANC Followup */
	and v.mch_program_id is not null) x
where x.rn = 1;

-- NCD (by patient, no program id available in all_encounters)
drop table if exists #first_ncd_fu;
select x.encounter_type_name, x.patient_id, x.emr_id, x.visit_id, x.encounter_id,
x.encounter_datetime, x.entered_datetime, x.user_entered, x.server, x.partition_num
into #first_ncd_fu
from
	(select e.*,
		row_number() over (partition by e.patient_id order by e.encounter_datetime, e.encounter_id) as rn
	from all_encounters e
	where e.encounter_type_uuid = '5cbfd6a2-92d9-4ad0-b526-9d29bfe1d10c' /* NCD Followup Consult */) x
where x.rn = 1;

-- -------------------------------------------------- followup without intake
-- flags the first followup in each program (or patient, for NCD) when there is no intake at all.
-- if the intake exists but came later, only the 'Intake after Followup' warning is raised

-- HIV
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, patient_program_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num)
select 'Followup without Intake', f.encounter_type_name, f.patient_id, f.emr_id, f.visit_id, f.encounter_id, f.hiv_program_id,
f.encounter_datetime, f.entered_datetime, f.user_entered, f.server, f.partition_num
from #first_hiv_fu f
where not exists
	(select 1 from hiv_visit v2
	inner join all_encounters e2 on e2.encounter_id = v2.encounter_id
	where v2.hiv_program_id = f.hiv_program_id
	and v2.encounter_type = 'HIV Intake');

-- ANC
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, patient_program_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num)
select 'Followup without Intake', f.encounter_type_name, f.patient_id, f.emr_id, f.visit_id, f.encounter_id, f.mch_program_id,
f.encounter_datetime, f.entered_datetime, f.user_entered, f.server, f.partition_num
from #first_anc_fu f
where not exists
	(select 1 from mch_visit v2
	inner join all_encounters e2 on e2.encounter_id = v2.encounter_id
	where v2.mch_program_id = f.mch_program_id
	and e2.encounter_type_uuid = '00e5e810-90ec-11e8-9eb6-529269fb1459' /* ANC Intake */);

-- NCD
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num)
select 'Followup without Intake', f.encounter_type_name, f.patient_id, f.emr_id, f.visit_id, f.encounter_id,
f.encounter_datetime, f.entered_datetime, f.user_entered, f.server, f.partition_num
from #first_ncd_fu f
where not exists
	(select 1 from all_encounters e2
	where e2.patient_id = f.patient_id
	and e2.encounter_type_uuid = 'ae06d311-1866-455b-8a64-126a9bd74171' /* NCD Initial Consult */);

-- -------------------------------------------------- intake after followup
-- every intake that has a followup before it in the same program (or patient, for NCD).
-- other_details shows the earliest followup that came before the intake

-- HIV
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, patient_program_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num, other_details)
select 'Intake after Followup', e.encounter_type_name, e.patient_id, e.emr_id, e.visit_id, e.encounter_id, v.hiv_program_id,
e.encounter_datetime, e.entered_datetime, e.user_entered, e.server, e.partition_num,
concat('earlier followup: ', f.encounter_datetime, ' (encounter_id ', f.encounter_id, ')')
from hiv_visit v
inner join all_encounters e on e.encounter_id = v.encounter_id
inner join #first_hiv_fu f on f.hiv_program_id = v.hiv_program_id
	and f.encounter_datetime < e.encounter_datetime
where v.encounter_type = 'HIV Intake'
and v.hiv_program_id is not null;

-- ANC
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, patient_program_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num, other_details)
select 'Intake after Followup', e.encounter_type_name, e.patient_id, e.emr_id, e.visit_id, e.encounter_id, v.mch_program_id,
e.encounter_datetime, e.entered_datetime, e.user_entered, e.server, e.partition_num,
concat('earlier followup: ', f.encounter_datetime, ' (encounter_id ', f.encounter_id, ')')
from mch_visit v
inner join all_encounters e on e.encounter_id = v.encounter_id
inner join #first_anc_fu f on f.mch_program_id = v.mch_program_id
	and f.encounter_datetime < e.encounter_datetime
where e.encounter_type_uuid = '00e5e810-90ec-11e8-9eb6-529269fb1459' /* ANC Intake */
and v.mch_program_id is not null;

-- NCD
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num, other_details)
select 'Intake after Followup', e.encounter_type_name, e.patient_id, e.emr_id, e.visit_id, e.encounter_id,
e.encounter_datetime, e.entered_datetime, e.user_entered, e.server, e.partition_num,
concat('earlier followup: ', f.encounter_datetime, ' (encounter_id ', f.encounter_id, ')')
from all_encounters e
inner join #first_ncd_fu f on f.patient_id = e.patient_id
	and f.encounter_datetime < e.encounter_datetime
where e.encounter_type_uuid = 'ae06d311-1866-455b-8a64-126a9bd74171' /* NCD Initial Consult */;

-- -------------------------------------------------- duplicate encounters within visit
-- one row per patient/visit/encounter type, pointing at the latest duplicate
drop table if exists #temp_dup_encounters;
select e.patient_id, e.visit_id, e.encounter_type_name, max(e.encounter_id) max_encounter_id, count(*) count
into #temp_dup_encounters
from all_encounters e
where e.visit_id is not null
and e.encounter_type_uuid in
('55a0d3ea-a4d7-4e88-8f01-5aceb2d3c61b' /* Check-in */,
'27d3a180-031b-11e6-a837-0800200c9a66' /* Primary Care Adult Initial Consult */,
'27d3a181-031b-11e6-a837-0800200c9a66' /* Primary Care Adult Followup Consult */,
'5b812660-0262-11e6-a837-0800200c9a66' /* Primary Care Pediatric Initial Consult */,
'229e5160-031b-11e6-a837-0800200c9a66' /* Primary Care Pediatric Followup Consult */,
'ae06d311-1866-455b-8a64-126a9bd74171' /* NCD Initial Consult */,
'5cbfd6a2-92d9-4ad0-b526-9d29bfe1d10c' /* NCD Followup Consult */,
'00e5e810-90ec-11e8-9eb6-529269fb1459' /* ANC Intake */,
'00e5e946-90ec-11e8-9eb6-529269fb1459' /* ANC Followup */,
'c31d306a-40c4-11e7-a919-92ebcb67fe33' /* HIV Intake */,
'c31d3312-40c4-11e7-a919-92ebcb67fe33' /* HIV Followup */,
'a8584ab8-cc2a-11e5-9956-625662870761' /* Mental Health Consult */,
'74cef0a6-2801-11e6-b67b-9e71128cae77' /* Emergency Triage */,
'260566e1-c909-4d61-a96f-c1019291a09d' /* Admission */,
'b6631959-2105-49dd-b154-e1249e0fbcd7' /* Exit from Inpatient Care */)
group by e.patient_id, e.visit_id, e.encounter_type_uuid, e.encounter_type_name
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
where e.encounter_type_uuid = '00e5e810-90ec-11e8-9eb6-529269fb1459' /* ANC Intake */
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
	and e.encounter_type_uuid in ('b6631959-2105-49dd-b154-e1249e0fbcd7' /* Exit from Inpatient Care */, '436cfe33-6b81-40ef-a455-f134a9f7e580' /* Transfer */))
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id,
encounter_datetime, datetime_entered, user_entered, server, partition_num)
select 'Inpatient encounters before admission', f.encounter_type_name, f.patient_id, f.emr_id, f.visit_id, f.encounter_id,
f.encounter_datetime, f.entered_datetime, f.user_entered, f.server, f.partition_num
from first_inpatient f
where f.rn = 1
and not exists
	(select 1 from all_encounters e2
	where e2.visit_id = f.visit_id
	and e2.encounter_type_uuid = '260566e1-c909-4d61-a96f-c1019291a09d' /* Admission */
	and e2.encounter_datetime <= f.encounter_datetime);

-- -------------------------------------------------- duplicate emr_id
-- compared within the same server only: the HIV server holds its own copy of patients
-- who are also on a site server, so the same emr_id across servers is expected
-- linked to the patient's most recent registration encounter, as in the extract.
-- the latest registration is computed once with row_number instead of a per-row OUTER APPLY
drop table if exists #latest_reg;
select x.patient_id, x.encounter_id, x.visit_id, x.encounter_datetime
into #latest_reg
from
	(select r1.patient_id, r1.encounter_id, r1.visit_id, r1.encounter_datetime,
		row_number() over (partition by r1.patient_id order by r1.encounter_datetime desc, r1.encounter_id desc) as rn
	from all_encounters r1
	where r1.encounter_type_uuid = '873f968a-73a8-4f9c-ac78-9f4778b751b6' /* Patient Registration */) x
where x.rn = 1;

insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, encounter_datetime, datetime_entered,
user_entered, server, partition_num, other_details)
select 'Duplicate emr_ids', 'patient_registration', p.patient_id, p.emr_id, r.visit_id, r.encounter_id,
coalesce(r.encounter_datetime, p.registration_date), p.date_registration_entered,
p.user_entered, p.server, p.partition_num, concat('other patient_id: ', p2.patient_id)
from all_patients p
inner join all_patients p2 on p2.emr_id = p.emr_id
	and p2.server = p.server
	and p2.patient_id <> p.patient_id
left join #latest_reg r on r.patient_id = p.patient_id
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
