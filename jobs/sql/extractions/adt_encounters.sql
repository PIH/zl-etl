SET @partition = '${partitionNum}';
SET sql_safe_updates = 0;

select encounter_type_id  into @trf_type_id 
from encounter_type et where uuid='436cfe33-6b81-40ef-a455-f134a9f7e580';

select encounter_type_id  into @adm_type_id 
from encounter_type et where uuid='260566e1-c909-4d61-a96f-c1019291a09d';

select encounter_type_id  into @sort_type_id 
from encounter_type et where uuid='b6631959-2105-49dd-b154-e1249e0fbcd7';

select encounter_type_id  into @cons_type_id 
from encounter_type et where uuid='92fd09b4-5335-4f7e-9f63-b2a663fd09a6';
SELECT 'a541af1e-105c-40bf-b345-ba1fd6a59b85' INTO @emr_identifier_type;

drop temporary table if exists adt_encounters;
create temporary table adt_encounters
(
    patient_id           int,
	 emr_id               varchar(15),
    encounter_id         int,
    visit_id             int,
    visit_location       varchar(255),
    encounter_datetime           datetime,
    creator              varchar(255),
    datetime_created     datetime,
    location_id          int(11),
    encounter_location   varchar(255),
    facility             varchar(255),
    provider 			 varchar(255),
    encounter_type 		 int,
    encounter_type_name  varchar(50),
    index_asc			int,
    index_desc			int
);


insert into adt_encounters (patient_id, encounter_id, visit_id, encounter_datetime, datetime_created, encounter_type, location_id)
select patient_id, encounter_id, visit_id, encounter_datetime, date_created, encounter_type, location_id
from encounter e
where e.voided = 0
AND encounter_type IN (@adm_type_id , @trf_type_id , @sort_type_id)
ORDER BY encounter_datetime desc;

UPDATE adt_encounters
SET encounter_type_name = encounter_type_name_from_id(encounter_type);

UPDATE adt_encounters
SET creator = encounter_creator_name(encounter_id);

create index adt_encounters_li on adt_encounters(location_id);
-- Sets encounter_location from the encounter's location.
-- Sets facility as the Visit Location ancestor of the encounter location (fallback for rows with no visit).
update adt_encounters t
inner join locations ls on ls.location_id = t.location_id
set t.encounter_location = ls.location_name,
    t.facility = ls.facility;

UPDATE adt_encounters
SET provider = provider(encounter_id);

UPDATE adt_encounters t
SET emr_id = patient_identifier(patient_id, @emr_identifier_type);


create index adt_encounters_vi on adt_encounters(visit_id);
-- Sets visit_location from the visit's location.
-- Overrides facility with visit_location when a visit exists, since visits are
-- associated directly with the Visit Location — more accurate than the ancestor walk.
update adt_encounters t
inner join visit v on v.visit_id = t.visit_id
inner join locations ls on ls.location_id = v.location_id
set t.visit_location = ls.location_name,
    t.facility = ls.location_name;

-- Falls back to 'Unknown Location' if facility is still NULL after both location lookups.
update adt_encounters t
inner join location loc on loc.uuid = '8d6c993e-c2cc-11de-8d13-0010c6dffd0f'
set t.facility = loc.name
where t.facility is null;

SELECT
emr_id,
CONCAT(@partition,'-',encounter_id) "encounter_id",
CONCAT(@partition,'-',visit_id) "visit_id",
visit_location,
encounter_datetime,
creator AS user_entered,
datetime_created,
encounter_type_name AS encounter_type,
encounter_location,
facility,
provider,
index_asc,
index_desc
FROM adt_encounters;
