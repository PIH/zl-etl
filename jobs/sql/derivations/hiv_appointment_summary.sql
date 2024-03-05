
DROP TABLE IF EXISTS hiv_appointment_summary;
CREATE TABLE hiv_appointment_summary
(
emr_id varchar(255),
appointment_scheduling_encounter_id varchar(255),
appointment_date date,
next_actual_visit date,
visit_location varchar(255),
encounter_type varchar(255),
encounter_id varchar(255),
index_asc int,
index_desc int
);

DROP TABLE IF EXISTS #next_appt_details;
SELECT emr_id, encounter_id AS appointment_scheduling_encounter_id, visit_date,  next_visit_date AS appointment_date,
index_asc , lead(visit_date,1) OVER (ORDER BY visit_date ASC) AS next_actual_visit, partition_num 
INTO #next_appt_details 
FROM hiv_visit hv 
ORDER BY emr_id, visit_date  ASC;

INSERT INTO hiv_appointment_summary
SELECT 
apd.emr_id,
apd.appointment_scheduling_encounter_id,
apd.appointment_date,
apd.next_actual_visit,
hv.visit_location  AS actual_visit_location,
hv.encounter_type AS actual_visit_encounter_type,
hv.encounter_id AS actual_visit_encounter_id,
NULL AS index_asc,
NULL AS index_desc
FROM #next_appt_details apd INNER JOIN hiv_visit hv ON hv.emr_id=apd.emr_id AND hv.visit_date=apd.next_actual_visit
WHERE apd.appointment_date IS NOT NULL
;

-- update index asc/desc on hiv_appointment_summary table
select  emr_id, appointment_date, 
ROW_NUMBER() over (PARTITION by emr_id order by appointment_date asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by appointment_date desc) "index_desc"
into #hiv_appointment_indexes
from hiv_appointment_summary et ;

update  et
set et.index_asc = avi.index_asc,
	et.index_desc = avi.index_desc 
from hiv_appointment_summary et 
inner join #hiv_appointment_indexes avi on avi.emr_id = et.emr_id
and avi.appointment_date = et.appointment_date;

DROP TABLE IF EXISTS #hiv_appointment_indexes;
