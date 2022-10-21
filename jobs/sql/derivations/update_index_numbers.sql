
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
inner join 	#all_visits_indexes avi on avi.visit_id = av.visit_id ; 
