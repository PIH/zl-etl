SET @partition = '${partitionNum}';
set sql_safe_updates = 0;
set @next_appt_date_concept_id = CONCEPT_FROM_MAPPING('PIH', 5096);

drop temporary table if exists temp_all_encounters;
create temporary table temp_all_encounters
(
encounter_id        int,
encounter_datetime	datetime, 
patient_id          int, 
visit_id            int, 
creator				int(11),
user_entered        varchar(255),
encounter_location  varchar(255),
encounter_type_name varchar(50),
entered_datetime    datetime,
emr_id              varchar(15),
next_appt_date      date,
index_asc			int,
index_desc			int
);

Insert into temp_all_encounters (
encounter_id, encounter_datetime, encounter_type_name, encounter_location, patient_id, visit_id, user_entered, entered_datetime)
select encounter_id, encounter_datetime, encounter_type_name_from_id(encounter_type), location_name(location_id), patient_id, visit_id, person_name_of_user(creator), date_created 
from encounter 
where voided = 0
;

-- index
CREATE INDEX temp_all_encounters_patientId ON temp_all_encounters(patient_id);
CREATE INDEX temp_all_encounters_encounterId ON temp_all_encounters(encounter_id);
-- CREATE INDEX temp_all_encountersCreator ON temp_all_encounters(creator);

-- delete encounters for voided patients
delete t 
from temp_all_encounters t
inner join patient p on p.patient_id = t.patient_id
where p.voided = 1;

/*
-- creator 
-- unique creators loaded to temp table before looking up person_name and joining back in to the temp_all_encounters table
drop temporary table if exists temp_creators;
create temporary table temp_creators
(creator		int(11),
person_name		varchar(50));

insert into temp_creators(creator)
select DISTINCT creator
from temp_all_encounters
;
create index temp_creators_ci on temp_creators(creator);


update temp_creators t
inner join users u on u.user_id = t.creator 
set person_name = person_name(u.person_id);

update temp_all_encounters t
inner join temp_creators tc on tc.creator = t.creator 
set t.user_entered = tc.person_name;
*/

-- next visit date
-- all next appt date obs loaded to temp table before looking up for each encounter
-- this avoids having to access the full obs table for each encounter
DROP TABLE IF EXISTS temp_next_appt_obs;
CREATE TEMPORARY TABLE temp_next_appt_obs
select encounter_id, max(value_datetime) "next_appt_date"
from obs where concept_id = @next_appt_date_concept_id
and voided = 0
group by encounter_id;

create index temp_next_appt_obs_ei on temp_next_appt_obs(encounter_id);

update temp_all_encounters te 
inner join temp_next_appt_obs tvo on tvo.encounter_id = te.encounter_id
set te.next_appt_date = tvo.next_appt_date;

-- NOTE:  the index_asc, index_desc will be calculated in a later job in the pipeline

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
   next_appt_date,
   index_asc, 
   index_desc 
from temp_all_encounters t
ORDER BY t.patient_id, t.encounter_id;
