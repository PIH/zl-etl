-- set @startDate = '2000-03-28';
-- set @endDate = '2022-07-01';

CALL initialize_global_metadata();
set @partition = '${partitionNum}';

DROP TEMPORARY TABLE IF EXISTS temp_procedure;
CREATE TEMPORARY TABLE temp_procedure
(
patient_id					INT(11),
emr_id						VARCHAR(50),
encounter_id				INT(11),
order_id					INT(11),
order_number 				VARCHAR(50),
coded_procedure				VARCHAR(255),
noncoded_procedure			VARCHAR(255),
visit_id					INT(11),
visit_location				VARCHAR(255),
facility					VARCHAR(255)
);

set @codedProcedure = concept_from_mapping('PIH','10770');
set @nonCodedProcedure = concept_from_mapping('PIH','10772');

DROP TEMPORARY TABLE IF EXISTS temp_procedure_encounters;
create temporary table temp_procedure_encounters
select o.encounter_id, o.order_id , o.order_number  from orders o
where o.order_type_id = @pathologyTestOrder
and o.voided = 0
AND ((date(o.date_activated) >= @startDate) or  @startDate is null)
AND ((date(o.date_activated) <= @endDate) or @endDate is null)
;

insert into temp_procedure (patient_id, encounter_id, order_id, order_number, coded_procedure, noncoded_procedure)
select o.person_id , o.encounter_id , tpe.order_id, tpe.order_number,
if(o.concept_id = @codedProcedure, concept_name(o.value_coded, @locale),null), 
if(o.concept_id = @nonCodedProcedure, o.value_text,null) 
from obs o
inner join temp_procedure_encounters tpe on tpe.encounter_id = o.encounter_id 
where o.concept_id in (@codedProcedure,  @nonCodedProcedure)
and o.voided = 0;

update temp_procedure t
set emr_id = zlemr(patient_id);

-- Sets visit_id from the encounter.
update temp_procedure t
inner join encounter e on e.encounter_id = t.encounter_id
set t.visit_id = e.visit_id;

-- Sets facility as the Visit Location ancestor of the encounter location (fallback for rows with no visit).
update temp_procedure t
inner join encounter e on e.encounter_id = t.encounter_id
inner join locations l on l.location_id = e.location_id
set t.facility = l.facility;

-- Sets visit_location from the visit's location.
-- Overrides facility with visit_location when a visit exists, since visits are
-- associated directly with the Visit Location — more accurate than the ancestor walk.
update temp_procedure t
inner join visit v on v.visit_id = t.visit_id
inner join locations l on l.location_id = v.location_id
set t.visit_location = l.location_name,
    t.facility = l.location_name;

-- Falls back to 'Unknown Location' if facility is still NULL after both location lookups.
update temp_procedure t
inner join location loc on loc.uuid = '8d6c993e-c2cc-11de-8d13-0010c6dffd0f'
set t.facility = loc.name
where t.facility is null;

select
emr_id,
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',order_id),order_id) "order_id",
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',order_number),order_number) "order_number",
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',encounter_id),encounter_id) "encounter_id",
coded_procedure,
noncoded_procedure,
facility,
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',visit_id),visit_id) "visit_id",
visit_location
from temp_procedure;
