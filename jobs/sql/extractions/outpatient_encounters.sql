SET @partition = '${partitionNum}';
set sql_safe_updates = 0;
SELECT encounter_type_id INTO @adult_initial FROM encounter_type et WHERE et.uuid='27d3a180-031b-11e6-a837-0800200c9a66';
SELECT encounter_type_id INTO @adult_followup FROM encounter_type et WHERE et.uuid='27d3a181-031b-11e6-a837-0800200c9a66';
SELECT encounter_type_id INTO @peds_initial FROM encounter_type et WHERE et.uuid='5b812660-0262-11e6-a837-0800200c9a66';
SELECT encounter_type_id INTO @peds_followup FROM encounter_type et WHERE et.uuid='229e5160-031b-11e6-a837-0800200c9a66';


drop temporary table if exists temp_encounter;
create temporary table temp_encounter
(
    encounter_id         int,
    emr_id               varchar(15),
    encounter_datetime   datetime,
    patient_id           int,
    visit_id             int,
    visit_location       varchar(255),
    creator              int(11),
    user_entered         varchar(255),
    location_id 		 int,
    encounter_location   varchar(255),
    facility             varchar(255),
    encounter_type 		 int,
    encounter_type_name  varchar(255),
    date_created     datetime,
    provider			varchar(255),
    voided               bit,
    index_asc 			int,
    index_desc 			int
);


-- If there is a previous watermark, initialize with only those encounters since that watermark
insert into temp_encounter (encounter_id, encounter_datetime, encounter_type, location_id, patient_id, visit_id, creator, date_created, voided  )
select encounter_id, encounter_datetime, 
encounter_type, location_id, patient_id, visit_id, creator, date_created, voided
from encounter
where voided = 0 
and encounter_type  IN (@adult_initial, @adult_followup, @peds_initial, @peds_followup);


CREATE INDEX temp_all_encounters_encounterId ON temp_encounter (encounter_id);
CREATE INDEX temp_all_encounters_patientId ON temp_encounter (patient_id);

UPDATE temp_encounter t SET t.encounter_type_name = encounter_type_name_from_id(t.encounter_type);
create index temp_encounter_li on temp_encounter(location_id);
-- Sets encounter_location from the encounter's location.
-- Sets facility as the Visit Location ancestor of the encounter location (fallback for rows with no visit).
update temp_encounter t
inner join locations ls on ls.location_id = t.location_id
set t.encounter_location = ls.location_name,
    t.facility = ls.facility;
UPDATE temp_encounter t SET t.user_entered = person_name_of_user(t.creator);
UPDATE temp_encounter t SET t.emr_id = patient_identifier(t.patient_id, 'ZL EMR ID');
UPDATE temp_encounter t SET t.provider = provider(t.encounter_id);

create index temp_encounter_vi on temp_encounter(visit_id);
-- Sets visit_location from the visit's location.
-- Overrides facility with visit_location when a visit exists, since visits are
-- associated directly with the Visit Location — more accurate than the ancestor walk.
update temp_encounter t
inner join visit v on v.visit_id = t.visit_id
inner join locations ls on ls.location_id = v.location_id
set t.visit_location = ls.location_name,
    t.facility = ls.location_name;

-- Falls back to 'Unknown Location' if facility is still NULL after both location lookups.
update temp_encounter t
inner join location loc on loc.uuid = '8d6c993e-c2cc-11de-8d13-0010c6dffd0f'
set t.facility = loc.name
where t.facility is null;

SELECT
emr_id,
CONCAT(@partition, '-', encounter_id) as encounter_id,
CONCAT(@partition, '-', visit_id) as visit_id,
visit_location,
encounter_location,
facility,
encounter_datetime,
date_created,
encounter_type_name AS encounter_type,
user_entered,
provider,
index_asc,
index_desc
FROM temp_encounter;