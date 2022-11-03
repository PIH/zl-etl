-- update index asc/desc on all_visits table
select visit_id, emr_id, visit_date_started, 
ROW_NUMBER() over (PARTITION by emr_id order by visit_date_started asc, visit_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by visit_date_started desc, visit_id desc) "index_desc"
into #all_visits_indexes
from all_visits av ;

update  av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from all_visits av	
inner join #all_visits_indexes avi on avi.visit_id = av.visit_id ; 

-- update index asc/desc on all_encounters table
select encounter_id, emr_id, encounter_datetime, 
ROW_NUMBER() over (PARTITION by emr_id order by encounter_datetime asc, visit_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by encounter_datetime desc, visit_id desc) "index_desc"
into #all_encounters_indexes
from all_encounters ae ;

update  ae
set ae.index_asc = aei.index_asc,
	ae.index_desc = aei.index_desc 
from all_encounters ae
inner join #all_encounters_indexes aei on aei.encounter_id = ae.encounter_id; 
