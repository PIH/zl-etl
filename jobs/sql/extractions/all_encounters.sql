-- set @previousWater mark = null;  -- for testing
-- set @newWatermark = now(); -- for testing
SET @partition = '${partitionNum}';
set sql_safe_updates = 0;
set @next_appt_date_concept_id = CONCEPT_FROM_MAPPING('PIH', 5096);

drop temporary table if exists temp_all_encounters;
create temporary table temp_all_encounters
(
    encounter_id         int(11),
    encounter_datetime   datetime,
    patient_id           int(11),
    visit_id             int(11),
    creator              int(11),
    user_entered         varchar(255),
    location_id          int(11),
    encounter_location   varchar(255),
    encounter_type_id    int(11),
    encounter_type_name  varchar(50),
    entered_datetime     datetime,
    emr_id               varchar(15),
    next_appt_date       date,
    voided               bit
);

-- If there is not a previous watermark, initialize with all encounters
insert into temp_all_encounters (encounter_id)
select encounter_id from encounter
where voided = 0
and @previousWatermark is null;

-- If there is a previous watermark, initialize with only those encounters since that watermark
insert into temp_all_encounters (encounter_id)
select encounter_id from encounter
inner join dbevent_patient dp on encounter.patient_id = dp.patient_id
where voided = 0 
and @previousWatermark is not null
and dp.last_updated >= @previousWatermark
and dp.last_updated <= @newWatermark;

create index temp_all_encounters_encounterId ON temp_all_encounters (encounter_id);

-- Load the encounters
update temp_all_encounters t
inner join encounter e on t.encounter_id = e.encounter_id
set t.encounter_datetime = e.encounter_datetime,
    t.encounter_type_id = e.encounter_type, 
    t.location_id = e.location_id, 
    t.patient_id = e.patient_id,
    t.visit_id = e.visit_id,
    t.creator = e.creator, 
    t.entered_datetime = e.date_created,
    t.voided = e.voided
;

create index temp_all_encounters_et on temp_all_encounters(encounter_type_id);

-- update encounter type name
drop temporary table if exists encounter_types;
create temporary table encounter_types
(encounter_type_id int(11),
encounter_type_name varchar(511)
);

insert into encounter_types(encounter_type_id)
select distinct encounter_type_id from temp_all_encounters;

create index encounter_types_li on encounter_types(encounter_type_id);

update encounter_types et
inner join encounter_type l on l.encounter_type_id = et.encounter_type_id
set et.encounter_type_name = name;

update temp_all_encounters t
inner join encounter_types et on et.encounter_type_id = t.encounter_type_id
set t.encounter_type_name = et.encounter_type_name;

-- update location name
drop temporary table if exists locations;
create temporary table locations
(
	location_id  int(11),
	location_name varchar(511)
);

insert into locations(location_id)
select distinct location_id from temp_all_encounters;

create index locations_li on locations(location_id);

update locations ls
inner join location l on l.location_id = ls.location_id
set ls.location_name = name;

create index temp_all_encounters_li on temp_all_encounters(location_id);
update temp_all_encounters t
inner join locations ls on ls.location_id = t.location_id
set t.encounter_location = ls.location_name;

-- update user entered
drop temporary table if exists user_names;
create temporary table user_names
(
	user_id  int(11),
	user_name varchar(511)
);

insert into user_names(user_id, user_name)
select user_id,
person_name_of_user(user_id)
from users;

create index user_names_ui on user_names(user_id);
create index temp_all_encounters_ui on temp_all_encounters(creator);
update temp_all_encounters t 
inner join user_names u on t.creator = u.user_id
set t.user_entered = u.user_name;

-- get next appointment
CREATE INDEX temp_all_encounters_patientId ON temp_all_encounters (patient_id);

DROP TABLE IF EXISTS temp_next_appt_obs;
CREATE TEMPORARY TABLE temp_next_appt_obs
select encounter_id, max(value_datetime) "next_appt_date"
from obs
where concept_id = @next_appt_date_concept_id
  and voided = 0
group by encounter_id;

create index temp_next_appt_obs_ei on temp_next_appt_obs (encounter_id);

update temp_all_encounters te
    inner join temp_next_appt_obs tvo on tvo.encounter_id = te.encounter_id
set te.next_appt_date = tvo.next_appt_date
where te.voided = 0;

-- emr_id
drop temporary table if exists temp_emrids;
create temporary table temp_emrids
(
    patient_id int(11),
    emr_id     varchar(50)
);

insert into temp_emrids(patient_id)
select DISTINCT patient_id
from temp_all_encounters
;
create index temp_emrids_patient_id on temp_emrids (patient_id);

update temp_emrids t
set emr_id = patient_identifier(patient_id, 'ZL EMR ID');

update temp_all_encounters t
set t.emr_id = zlemrid_from_temp(t.patient_id);


-- final query
select emr_id,
       CONCAT(@partition, '-', encounter_id) as encounter_id,
       CONCAT(@partition, '-', patient_id) as patient_id,
       CONCAT(@partition, '-', visit_id) as visit_id,
       encounter_type_name,
       encounter_location,
       encounter_datetime,
       entered_datetime,
       user_entered,
       next_appt_date
from temp_all_encounters t
ORDER BY t.patient_id, t.encounter_id;
