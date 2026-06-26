SELECT encounter_type_id  INTO @enc_type_intake FROM encounter_type et WHERE uuid='a936ae01-6d10-455d-befc-b2d1828dad04';
SELECT encounter_type_id  INTO @enc_type_tp FROM encounter_type et WHERE uuid='f9cfdf8b-d086-4658-9b9d-45a62896da03';
SET @partition = '${partitionNum}';

DROP TABLE IF EXISTS oncology_diagnosis;
CREATE TEMPORARY TABLE oncology_diagnosis (
patient_id int,
emr_id varchar(50),
encounter_id int,
visit_id int,
location_id int,
visit_location varchar(255),
encounter_datetime datetime,
encounter_location varchar(100),
facility varchar(255),
date_entered date,
user_entered varchar(30),
encounter_provider varchar(30),
encounter_type varchar(30),
diagnosis_order varchar(20),
diagnosis varchar(100)
);


INSERT INTO oncology_diagnosis(patient_id,emr_id,encounter_id,visit_id,encounter_datetime,location_id,
							date_entered,user_entered,encounter_provider,encounter_type,diagnosis_order,diagnosis)
SELECT
patient_id,
zlemr(e.patient_id),
e.encounter_id,
e.visit_id,
e.encounter_datetime ,
e.location_id,
e.date_created,
encounter_creator(e.encounter_id),
provider(e.encounter_id),
encounter_type_name_from_id(@enc_type_intake),
obs_from_group_id_value_coded(o.obs_group_id,'PIH','7537','en') diagnosis_order, value_coded_name(o.obs_id,'en')
FROM obs o
INNER JOIN encounter e ON o.encounter_id = e.encounter_id AND e.encounter_type = @enc_type_intake
WHERE  o.concept_id = concept_from_mapping('PIH','3064')
AND o.voided =0
AND e.voided =0
ORDER BY obs_id ASC;


INSERT INTO oncology_diagnosis(patient_id,emr_id,encounter_id,visit_id,encounter_datetime,location_id,
							date_entered,user_entered,encounter_provider,encounter_type,diagnosis_order,diagnosis)
SELECT
patient_id,
zlemr(e.patient_id),
e.encounter_id,
e.visit_id,
e.encounter_datetime ,
e.location_id,
e.date_created,
encounter_creator(e.encounter_id),
provider(e.encounter_id),
encounter_type_name_from_id(@enc_type_tp),
obs_from_group_id_value_coded(o.obs_group_id,'PIH','7537','en') diagnosis_order, value_coded_name(o.obs_id,'en')
FROM obs o
INNER JOIN encounter e ON o.encounter_id = e.encounter_id AND e.encounter_type = @enc_type_tp
WHERE  o.concept_id = concept_from_mapping('PIH','3064')
AND o.voided =0
AND e.voided =0
ORDER BY obs_id ASC;

create index oncology_diagnosis_li on oncology_diagnosis(location_id);
-- Sets encounter_location from the encounter's location.
-- Sets facility as the Visit Location ancestor of the encounter location (fallback for rows with no visit).
update oncology_diagnosis t
inner join locations ls on ls.location_id = t.location_id
set t.encounter_location = ls.location_name,
    t.facility = ls.facility;

create index oncology_diagnosis_vi on oncology_diagnosis(visit_id);
-- Sets visit_location from the visit's location.
-- Overrides facility with visit_location when a visit exists, since visits are
-- associated directly with the Visit Location — more accurate than the ancestor walk.
update oncology_diagnosis t
inner join visit v on v.visit_id = t.visit_id
inner join locations ls on ls.location_id = v.location_id
set t.visit_location = ls.location_name,
    t.facility = ls.location_name;

-- Falls back to 'Unknown Location' if facility is still NULL after both location lookups.
update oncology_diagnosis t
inner join location loc on loc.uuid = '8d6c993e-c2cc-11de-8d13-0010c6dffd0f'
set t.facility = loc.name
where t.facility is null;

SELECT
emr_id,
CONCAT(@partition,'-',encounter_id) "encounter_id",
CONCAT(@partition,'-',visit_id) "visit_id",
visit_location,
encounter_datetime ,
encounter_location ,
facility ,
date_entered ,
user_entered ,
encounter_provider ,
encounter_type,
diagnosis_order ,
diagnosis
FROM oncology_diagnosis;