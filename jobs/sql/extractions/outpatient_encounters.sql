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
    creator              int(11),
    user_entered         varchar(255),
    location_id 		 int,
    encounter_location   varchar(255),
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
UPDATE temp_encounter t SET t.encounter_location = location_name(t.location_id);
UPDATE temp_encounter t SET t.user_entered = person_name_of_user(t.creator);
UPDATE temp_encounter t SET t.emr_id = patient_identifier(t.patient_id, 'ZL EMR ID');
UPDATE temp_encounter t SET t.provider = provider(t.encounter_id);

SELECT  
emr_id,
CONCAT(@partition, '-', encounter_id) as encounter_id,
CONCAT(@partition, '-', visit_id) as visit_id,
encounter_datetime,
date_created,
encounter_type_name AS encounter_type,
user_entered,
provider,
index_asc,
index_desc
FROM temp_encounter;