/* =====================================================================
   ZL data_warnings: before/after comparison (SQL Server / DWH)

   Setup (run once BEFORE deploying the new extract):
       drop table if exists data_warnings_old;
       select * into data_warnings_old from data_warnings;
   Then run the ZL refresh with the new extract, so data_warnings holds the new version.

   Only the warning types that existed in the old version are compared.
   Two were renamed, so the mapping below lines the old names up with the new ones.
   ===================================================================== */

drop table if exists #warning_map;
create table #warning_map (old_warning_type varchar(255), new_warning_type varchar(255), expect_change varchar(255));
insert into #warning_map values
('blank emr_id',                     'blank emr_id',                    null),
('blank gender',                     'blank gender',                    'yes - now skips unknown patients (old only flagged unknown patients)'),
('blank birthdate',                  'blank birthdate',                 'yes - now skips unknown patients (old only flagged unknown patients)'),
('blank given or family name',       'blank given or family name',      'yes - now skips unknown patients; ignores voided names; catches empty strings'),
('death date before birth date',     'death date before birthdate',     'renamed only'),
('overlapping program enrollments',  'overlapping program enrollments', null),
('HIV dispensing without any prescriptions', 'HIV dispensing without any prescriptions', 'possible - now ignores voided encounters/orders and uses the drug order type uuid'),
('HIV initial encounter without any HIV or exposed infant enrollment',  'HIV initial encounter without any HIV or exposed infant enrollment',  null),
('HIV followup encounter without any HIV or exposed infant enrollment', 'HIV followup encounter without any HIV or exposed infant enrollment', null),
('HIV exposed infant followup without any HIV or exposed infant enrollment', 'HIV exposed infant followup without any HIV or exposed infant enrollment', null),
('HIV dispensing encounter without any HIV or exposed infant enrollment',    'HIV dispensing encounter without any HIV or exposed infant enrollment',    null);

-- ---------------------------------------------------------------------
-- 1. Counts by warning type and server, old vs new
-- ---------------------------------------------------------------------
with old_counts as (
	select m.new_warning_type, o.server, count(*) as old_rows, count(distinct o.patient_id) as old_patients
	from data_warnings_old o
	inner join #warning_map m on m.old_warning_type = o.warning_type
	group by m.new_warning_type, o.server),
new_counts as (
	select n.warning_type as new_warning_type, n.server, count(*) as new_rows, count(distinct n.patient_id) as new_patients
	from data_warnings n
	inner join #warning_map m on m.new_warning_type = n.warning_type
	group by n.warning_type, n.server)
select
	coalesce(o.new_warning_type, n.new_warning_type) as warning_type,
	coalesce(o.server, n.server) as server,
	isnull(o.old_rows, 0)     as old_rows,
	isnull(n.new_rows, 0)     as new_rows,
	isnull(o.old_patients, 0) as old_patients,
	isnull(n.new_patients, 0) as new_patients,
	case when isnull(o.old_patients, 0) = isnull(n.new_patients, 0) then 'match' else 'DIFFERENT' end as patient_check,
	m.expect_change
from old_counts o
full outer join new_counts n on n.new_warning_type = o.new_warning_type and n.server = o.server
inner join #warning_map m on m.new_warning_type = coalesce(o.new_warning_type, n.new_warning_type)
order by warning_type, server;

-- ---------------------------------------------------------------------
-- 2. Patient-level differences: who dropped out, who is new
--    (patient_id is partition-prefixed, so it is unique across sites)
-- ---------------------------------------------------------------------
with old_pts as (
	select distinct m.new_warning_type, o.patient_id, o.emr_id, o.server
	from data_warnings_old o
	inner join #warning_map m on m.old_warning_type = o.warning_type),
new_pts as (
	select distinct n.warning_type as new_warning_type, n.patient_id, n.emr_id, n.server
	from data_warnings n
	inner join #warning_map m on m.new_warning_type = n.warning_type)
select 'in old only' as difference, o.new_warning_type as warning_type, o.patient_id, o.emr_id, o.server
from old_pts o
where not exists (select 1 from new_pts n where n.new_warning_type = o.new_warning_type and n.patient_id = o.patient_id)
union all
select 'in new only', n.new_warning_type, n.patient_id, n.emr_id, n.server
from new_pts n
where not exists (select 1 from old_pts o where o.new_warning_type = n.new_warning_type and o.patient_id = n.patient_id)
order by warning_type, difference, server, patient_id;

-- ---------------------------------------------------------------------
-- 3. Overview of everything in the new table (including the new warning types)
-- ---------------------------------------------------------------------
select warning_type, count(*) as row_count, count(distinct patient_id) as patients,
	sum(case when encounter_id is not null then 1 else 0 end) as with_encounter,
	sum(case when user_entered is null then 1 else 0 end) as missing_user_entered,
	min(event_datetime) as earliest_event, max(event_datetime) as latest_event
from data_warnings
group by warning_type
order by row_count desc;
