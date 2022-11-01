
-- delete all of the updated rows, which should be on the all_encounter_staging table  
delete from all_encounters 
where encounter_id in
(select encounter_id from all_encounters_staging);

-- insert all of the updated rows, except for those that have been voided
insert into all_encounters 
(emr_id,
encounter_id,
visit_id,
encounter_type_name,
encounter_location,
encounter_datetime,
entered_datetime,
user_entered,
next_appt_date,
site,
partition_num)
select 
emr_id,
encounter_id,
visit_id,
encounter_type_name,
encounter_location,
encounter_datetime,
entered_datetime,
user_entered,
next_appt_date,
site,
partition_num 
from all_encounters_staging
where voided = 0
;
