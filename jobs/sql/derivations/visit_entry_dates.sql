DROP TABLE IF EXISTS #temp_summary;
CREATE TABLE #temp_summary
(
server                          varchar(255),
visit_location                varchar(255),
mch_max_date_entered          datetime,
hiv_max_date_entered          datetime,
pmtct_max_date_entered        datetime,
covid_max_date_entered        datetime,
pathology_max_date_entered    datetime,
vitals_max_date_entered       datetime,
lab_results_max_date_entered  datetime
);
	
-- insert sites and locations into the table
-- for hiv server, use individual locations, for non-hiv sites, don't 
insert into #temp_summary (server, visit_location)
	select DISTINCT server, case when server = 'hiv' then visit_location else server end from hiv_visit hv 
	union
	select DISTINCT server, case when server = 'hiv' then encounter_location else server end from mch_visit
	union
	select DISTINCT server, case when server = 'hiv' then cast(location as varchar) else server end from covid_visit
	union
	select DISTINCT server, case when server = 'hiv' then health_facility else server end from pmtct_visits
 	union
 	select DISTINCT server, case when server = 'hiv' then encounter_location else server end from pathology_encounters
	union
	select DISTINCT server, case when server = 'hiv' then encounter_location else server end from all_vitals
	union
	select DISTINCT server, case when server = 'hiv' then encounter_location else server end from all_lab_results
;

-- update max date entered from each table, one-by-one
update t
set mch_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select server, case when server = 'hiv' then encounter_location else server end as "visit_location", max(date_entered) "max_date"
	from mch_visit mv
	group by server, case when server = 'hiv' then encounter_location else server end) s on s.server = t.server and s.visit_location = t.visit_location 
;

update t
set hiv_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select server,  case when server = 'hiv' then visit_location else server end as "visit_location", max(date_entered) "max_date"
	from hiv_visit mv 
	group by server, case when server = 'hiv' then visit_location else server end) s on s.server = t.server and s.visit_location = t.visit_location
;

update t
set pmtct_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select server, case when server = 'hiv' then health_facility else server end as "visit_location", max(date_entered) "max_date"
	from pmtct_visits mv 
	group by server, case when server = 'hiv' then health_facility else server end ) s on s.server = t.server and s.visit_location = t.visit_location
;

update t
set covid_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select server, case when server = 'hiv' then cast(location as varchar) else server end as "visit_location", max(date_entered) "max_date"
	from covid_visit mv 
	group by server,  case when server = 'hiv' then cast(location as varchar) else server end ) s on s.server = t.server and s.visit_location = t.visit_location
;

update t
set pathology_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select server,  case when server = 'hiv' then encounter_location else server end as "visit_location", max(order_datetime) "max_date"
	from pathology_encounters
	group by server,  case when server = 'hiv' then encounter_location else server end) s on s.server = t.server and s.visit_location = t.visit_location 
;
 
update t
set vitals_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select server, case when server = 'hiv' then encounter_location else server end as "visit_location",  max(date_entered) "max_date"
	from all_vitals 
	group by server, case when server = 'hiv' then encounter_location else server end) s on s.server = t.server and s.visit_location = t.visit_location 
;

update t
set lab_results_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select server,  case when server = 'hiv' then encounter_location else server end as "visit_location", max(results_entry_date) "max_date"  -- --- ------ needs to change!
	from all_lab_results  
	group by server, case when server = 'hiv' then encounter_location else server end) s on s.server = t.server and s.visit_location = t.visit_location 
;

drop table if exists visit_entry_dates;

select t.* 
into visit_entry_dates
from #temp_summary t;
