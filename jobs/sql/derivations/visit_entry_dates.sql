DROP TABLE IF EXISTS #temp_summary;
CREATE TABLE #temp_summary
(
site                          varchar(255),
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
-- for hiv site, use individual locations, for non-hiv sites, don't 
insert into #temp_summary (site, visit_location)
	select DISTINCT site, case when site = 'hiv' then visit_location else site end from hiv_visit hv 
	union
	select DISTINCT site, case when site = 'hiv' then visit_site else site end from mch_visit
	union
	select DISTINCT site, case when site = 'hiv' then cast(location as varchar) else site end from covid_visit
	union
	select DISTINCT site, case when site = 'hiv' then health_facility else site end from pmtct_visits
 	union
 	select DISTINCT site, case when site = 'hiv' then encounter_location else site end from pathology_encounters
	union
	select DISTINCT site, case when site = 'hiv' then encounter_location else site end from all_vitals
	union
	select DISTINCT site, case when site = 'hiv' then encounter_location else site end from all_lab_results
;

-- update max date entered from each table, one-by-one
update t
set mch_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select site, case when site = 'hiv' then visit_site else site end as "visit_location", max(date_entered) "max_date"
	from mch_visit mv 
	group by site, case when site = 'hiv' then visit_site else site end) s on s.site = t.site and s.visit_location = t.visit_location 
;

update t
set hiv_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select site,  case when site = 'hiv' then visit_location else site end as "visit_location", max(date_entered) "max_date"
	from hiv_visit mv 
	group by site, case when site = 'hiv' then visit_location else site end) s on s.site = t.site and s.visit_location = t.visit_location
;

update t
set pmtct_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select site, case when site = 'hiv' then health_facility else site end as "visit_location", max(date_entered) "max_date"
	from pmtct_visits mv 
	group by site, case when site = 'hiv' then health_facility else site end ) s on s.site = t.site and s.visit_location = t.visit_location
;

update t
set covid_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select site, case when site = 'hiv' then cast(location as varchar) else site end as "visit_location", max(date_entered) "max_date"
	from covid_visit mv 
	group by site,  case when site = 'hiv' then cast(location as varchar) else site end ) s on s.site = t.site and s.visit_location = t.visit_location
;

update t
set pathology_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select site,  case when site = 'hiv' then encounter_location else site end as "visit_location", max(order_datetime) "max_date"
	from pathology_encounters
	group by site,  case when site = 'hiv' then encounter_location else site end) s on s.site = t.site and s.visit_location = t.visit_location 
;
 
update t
set vitals_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select site, case when site = 'hiv' then encounter_location else site end as "visit_location",  max(date_entered) "max_date"
	from all_vitals 
	group by site, case when site = 'hiv' then encounter_location else site end) s on s.site = t.site and s.visit_location = t.visit_location 
;

update t
set lab_results_max_date_entered = s.max_date
from  #temp_summary t
inner join
	(select site,  case when site = 'hiv' then encounter_location else site end as "visit_location", max(results_entry_date) "max_date"  -- --- ------ needs to change!
	from all_lab_results  
	group by site, case when site = 'hiv' then encounter_location else site end) s on s.site = t.site and s.visit_location = t.visit_location 
;

drop table if exists visit_entry_dates;

select t.* 
into visit_entry_dates
from #temp_summary t;
