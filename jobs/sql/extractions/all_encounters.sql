SET @partition = '${partitionNum}';
set sql_safe_updates = 0;
set @next_appt_date_concept_id = CONCEPT_FROM_MAPPING('PIH', 5096);

drop temporary table if exists temp_all_encounters;
create temporary table temp_all_encounters
(
encounter_id        int,
encounter_datetime	datetime, 
encounter_type      int,
location_id         int,
patient_id          int, 
visit_id            int, 
creator             int(11),
user_entered        varchar(255),
encounter_location  varchar(150),
encounter_type_name varchar(150),
entered_datetime    datetime,
emr_id              varchar(15),
next_appt_date      date,
index_asc           int,
index_desc          int		
);

Insert into temp_all_encounters (
encounter_id, encounter_datetime, encounter_type, location_id, patient_id, visit_id, creator, entered_datetime)
select encounter_id, encounter_datetime, encounter_type, location_id, patient_id, visit_id, creator, date_created 
from encounter 
where voided = 0
;

-- index
CREATE INDEX temp_all_encounters_patientId ON temp_all_encounters(patient_id);
CREATE INDEX temp_all_encounters_encounterId ON temp_all_encounters(encounter_id);
CREATE INDEX temp_all_encounters_encounterType ON temp_all_encounters(encounter_type);
CREATE INDEX temp_all_encounters_encounterLoc ON temp_all_encounters(location_id);
CREATE INDEX temp_all_encountersCreator ON temp_all_encounters(creator);

-- location name
update temp_all_encounters t set encounter_location = location_name(t.location_id);  

--  encounter type
update temp_all_encounters t set encounter_type_name = encounter_type_name_from_id(t.encounter_type);

-- user entered
update temp_all_encounters t 
inner join users u on t.creator  = u.user_id 
set user_entered =  person_name(u.person_id) ;

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
set t.emr_id = te.emr_id;

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

-- indexes
drop temporary table if exists temp_all_encounters_index_asc;
create temporary table temp_all_encounters_index_asc
(
	SELECT  
           patient_id,
           encounter_id,
           encounter_datetime,
		   index_asc
FROM (SELECT  
             @r:= IF(@u = patient_id, @r + 1,1) index_asc,
             patient_id,
             encounter_id,
             encounter_datetime,
			 @u:= patient_id
            FROM temp_all_encounters,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id, encounter_id ASC
            ) index_ascending );

CREATE INDEX teia_ei ON temp_all_encounters_index_asc (encounter_id);   

update temp_all_encounters t
inner join temp_all_encounters_index_asc teia on teia.encounter_id = t.encounter_id
set t.index_asc = teia.index_asc;

drop temporary table if exists temp_all_encounters_index_desc;
create temporary table temp_all_encounters_index_desc
(
			SELECT  
           patient_id,
           encounter_id,
           encounter_datetime,
  		   index_asc,
           index_desc
FROM (SELECT  
             @r:= IF(@u = patient_id, @r + 1,1) index_desc,
             patient_id,
             encounter_id,
             encounter_datetime,
             index_asc,
			 @u:= patient_id
            FROM temp_all_encounters,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id, encounter_id DESC
        ) index_descending );

CREATE INDEX teid_e1 ON temp_all_encounters_index_desc (encounter_id);   

update temp_all_encounters t
inner join temp_all_encounters_index_desc teid on teid.encounter_id = t.encounter_id
set t.index_desc = teid.index_desc;

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
