SET @partition = '${partitionNum}';

drop temporary table if exists temp_visits;
create temporary table temp_visits
(patient_id			int(11),
emr_id				varchar(50),
visit_id			int(11),
visit_date_started	datetime,
visit_date_stopped	datetime,
visit_date_entered	datetime,
visit_creator		int(11),
visit_user_entered	varchar(50),
visit_type_id		int(11),
visit_type			varchar(255),
checkin_encounter_id	int(11),	
visit_checkin		bit,
visit_reason		varchar(255),
location_id			int(11),
visit_location		varchar(255),
index_asc			int,
index_desc			int);

insert into temp_visits(patient_id, visit_id, visit_date_started, visit_date_stopped, visit_date_entered, visit_type_id, visit_creator, location_id)
select patient_id, visit_id, date_started, date_stopped, date_created, visit_type_id, creator, location_id  
from visit v 
where v.voided = 0;

create index temp_visits_vi on temp_visits(visit_id);

-- emr_id
DROP TEMPORARY TABLE IF EXISTS temp_identifiers;
CREATE TEMPORARY TABLE temp_identifiers
(
patient_id						INT(11),
emr_id							VARCHAR(25)
);

INSERT INTO temp_identifiers(patient_id)
select distinct patient_id from temp_visits;

update temp_identifiers t set emr_id  = zlemr(patient_id);	

CREATE INDEX temp_identifiers_p ON temp_identifiers (patient_id);

update temp_visits tv 
inner join temp_identifiers ti on ti.patient_id = tv.patient_id
set tv.emr_id = ti.emr_id;

-- visit type
update temp_visits t
inner join visit_type vt on vt.visit_type_id = t.visit_type_id
set t.visit_type = vt.name;

-- locations
update temp_visits tv 
set tv.visit_location = location_name(location_id);

-- user entered
DROP TEMPORARY TABLE IF EXISTS temp_users;
CREATE TEMPORARY TABLE temp_users
(
creator						INT(11),
creator_name				VARCHAR(255)
);

INSERT INTO temp_users(creator)
select distinct visit_creator from temp_visits;

CREATE INDEX temp_users_c ON temp_users(creator);

update temp_users t set creator_name  = person_name_of_user(creator);	

update temp_visits tv 
inner join temp_users tu on tu.creator = tv.visit_creator
set tv.visit_user_entered = tu.creator_name;

-- checkin information
-- leaving commented out for performance reasons for now
/*
select name into @checkin_type_name from encounter_type where UUID = '55a0d3ea-a4d7-4e88-8f01-5aceb2d3c61b'; 
update temp_visits t 
set t.checkin_encounter_id = latestEncOfTypeInVisit(visit_id, @checkin_type_name);

update temp_visits t 
set visit_reason = obs_value_coded_list(checkin_encounter_id, 'PIH','8879',@locale );
*/

select 
emr_id,
CONCAT(@partition,'-',visit_id) "visit_id",
visit_date_started,
visit_date_stopped,
visit_date_entered,
visit_user_entered,
visit_type,
if(checkin_encounter_id is null, null, 1) "visit_checkin",
visit_reason,
visit_location,
index_asc,
index_desc
from temp_visits;
