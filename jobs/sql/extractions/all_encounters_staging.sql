SET @partition = '${partitionNum}';
set sql_safe_updates = 0;
set @next_appt_date_concept_id = CONCEPT_FROM_MAPPING('PIH', 5096);

drop temporary table if exists temp_all_encounters;
create temporary table temp_all_encounters
(
encounter_id        int unique,
encounter_datetime	datetime, 
patient_id          int, 
visit_id            int, 
creator				int(11),
user_entered        varchar(255),
encounter_location  varchar(255),
encounter_type_name varchar(50),
entered_datetime    datetime,
combined_date_changed	datetime,
emr_id              varchar(15),
next_appt_date      date,
voided				bit
);

set @last_loaded_max_time = null;
select max(loaded_max_datetime) into @last_loaded_max_time from petl_load_times where loaded_domain = 'encounter' and status = 'complete';

insert into temp_all_encounters (
encounter_id, encounter_datetime, encounter_type_name, encounter_location, patient_id, visit_id, user_entered, entered_datetime, voided, combined_date_changed)
select encounter_id, encounter_datetime, encounter_type_name_from_id(encounter_type), location_name(location_id), patient_id, visit_id, person_name_of_user(creator), date_created, voided,
CASE 
	when ifnull(date_created,'1000-01-01') >= ifnull(date_changed,'1000-01-01') and ifnull(date_created,'1000-01-01') >= ifnull(date_voided,'1000-01-01') then date_created
	when ifnull(date_changed,'1000-01-01') >= ifnull(date_created,'1000-01-01') and ifnull(date_changed,'1000-01-01') >= ifnull(date_voided,'1000-01-01') then date_changed
	else date_voided
END 
from encounter 
where (ifnull(date_created,'1000-01-01') > @last_loaded_max_time or 
	 ifnull(date_changed,'1000-01-01') > @last_loaded_max_time or 
	 ifnull(date_voided,'1000-01-01') > @last_loaded_max_time or 
	@last_loaded_max_time is null)
order by 
CASE 
	when ifnull(date_created,'1000-01-01') >= ifnull(date_changed,'1000-01-01') and ifnull(date_created,'1000-01-01') >= ifnull(date_voided,'1000-01-01') then date_created
	when ifnull(date_changed,'1000-01-01') >= ifnull(date_created,'1000-01-01') and ifnull(date_changed,'1000-01-01') >= ifnull(date_voided,'1000-01-01') then date_changed
	else date_voided
END asc	
 limit 5000 -- <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< change
;

select now() into @current_loaded_time;
select max(combined_date_changed) into @loaded_max_time from temp_all_encounters;
select min(combined_date_changed) into @loaded_min_time from temp_all_encounters;
select count(*) into @number_updated_rows from temp_all_encounters;

-- insert ALL rows with the max load time (ignoring duplicates) to ensure that all rows with that datetime are loaded
insert ignore into temp_all_encounters (
encounter_id, encounter_datetime, encounter_type_name, encounter_location, patient_id, visit_id, user_entered, entered_datetime, voided)
select encounter_id, encounter_datetime, encounter_type_name_from_id(encounter_type), location_name(location_id), patient_id, visit_id, person_name_of_user(creator), date_created, voided 
from encounter
where encounter_datetime = @max_loaded_time
;

-- indexes
CREATE INDEX temp_all_encounters_patientId ON temp_all_encounters(patient_id);
CREATE INDEX temp_all_encounters_encounterId ON temp_all_encounters(encounter_id);

-- emr_id
-- unique patients loaded to temp table before looking up emr_id and joining back in to the temp_all_encounters table
drop temporary table if exists temp_emrids;
create temporary table temp_emrids
(patient_id		int(11),
emr_id			varchar(50));

insert into temp_emrids(patient_id)
select DISTINCT patient_id
from temp_all_encounters
;
create index temp_emrids_patient_id on temp_emrids(patient_id);

update temp_emrids t set emr_id = patient_identifier(patient_id, 'ZL EMR ID');
update temp_all_encounters t
inner join temp_emrids te on te.patient_id = t.patient_id
set t.emr_id = te.emr_id
where t.voided = 0;

-- final query
select 
   emr_id,
   CONCAT(@partition,'-',encounter_id) "encounter_id",
   CONCAT(@partition,'-',visit_id) "visit_id",
   encounter_type_name,
   encounter_location,
   encounter_datetime,
   entered_datetime,
   user_entered,
   voided	
from temp_all_encounters t
ORDER BY t.patient_id, t.encounter_id;

-- remove past pending rows to petl_load_times
delete from petl_load_times 
where loaded_domain = 'encounter'
and status = 'pending';

-- insert new pending row to petl_load_time
insert into petl_load_times(load_datetime, loaded_domain, loaded_min_datetime,loaded_max_datetime,number_updated_rows,status )
values (
@current_loaded_time,
'encounter',
@loaded_min_time,
@loaded_max_time,
@number_updated_rows,
'pending');
