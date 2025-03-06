drop table if exists census_staging;
create table census_staging (
site varchar(255),
reporting_year int,
reporting_month int,
FirstDayOfMonth date,
LastDayOfMonth date,
indicator varchar(255),
clinical_category varchar(255),
total int)
;

drop table if exists #location_mapping;
create table #location_mapping (
site varchar(255),
location varchar(255),
clinical_category varchar(255));

insert into #location_mapping (site, location, clinical_category)
values
('humci','Sal Avan Akouchman','maternity'),
('humci','Onkoloji','other'),
('humci','Swen Entansif','other'),
('humci','Sal Izolman','other'),
('humci','Travay e Akouchman','maternity'),
('humci','Sal Gason','internal_medicine'),
('humci','Swen Entansif Neonatal','pediatric'),
('humci','Sal Timoun','pediatric'),
('humci','Sal Aprè Operasyon | Sante Fanm','surgery'),
('humci','Sal Aprè Akouchman','maternity'),
('humci','Sal Reyabilitasyon','other'),
('humci','Sal Aprè Operasyon','surgery'),
('humci','Sal Fanm','internal_medicine'),
('humci','COVID-19 | Izolman','other'),
('humci','UMI','other'),
('humci','S-NICU','pediatric'),
('humci','Suites de Couches','maternity'),
('humci','Sal Avan Operasyon | PACU','pediatric') -- not this is not currently tagged as an admin location
;

insert into census_staging(site, reporting_year, reporting_month, FirstDayOfMonth, LastDayOfMonth, indicator, clinical_category)
select site, year, month, FirstDayOfMonth,LastDayOfMonth,clinical_indicator, clinical_category from
	(select distinct year, month, FirstDayOfMonth, LastDayOfMonth  from dim_date dd
	where dd.Date <= current_timestamp and dd.Date >= dateadd(year, -1, getdate())) d
cross join
	(select 'pediatric' as clinical_category union 
	select 'internal_medicine' union
	select 'surgery' union 
	select 'maternity' union
	select 'mental_health' union 
	select 'other') c
cross join 
	(select 'patient_days' as clinical_indicator union 
	select 'hospitalizations' union
	select 'discharges' union
	select 'deaths_less_than_48_hours' union
	select 'deaths_greater_than_48_hours' union
	select 'days_hospitalized') i
cross join 
	(select distinct site from #location_mapping) s;
	
-- create table of each admission slotted into locations/categories
drop table if exists #admission_month_categories;
create table #admission_month_categories (
encounter_id varchar(50),
reporting_year int,
reporting_month int,
site varchar(255),
encounter_location varchar(255),
clinical_category varchar(255),
indicator varchar(255),
effective_start_datetime datetime,
effective_end_datetime datetime,
discharged int,
died_within_48hrs int,
died_greater_48hrs int,
total_patient_days int,
total_days_hospitalized int);

insert into #admission_month_categories(reporting_year, reporting_month, site, encounter_location, clinical_category, encounter_id,effective_start_datetime, effective_end_datetime)
select reporting_year, reporting_month, a.site, encounter_location,c.clinical_category, a.encounter_id,
iif(start_datetime < FirstDayOfMonth, FirstDayOfMonth, start_datetime) "effective_start_datetime",
iif(end_datetime > LastDayOfMonth or end_datetime is null, dateadd(day,1,iif(LastDayOfMonth < getdate(), LastDayOfMonth, getdate())), end_datetime) "effective_end_datetime"
	from (select distinct cs.site, cs.reporting_year , cs.reporting_month, cs.FirstDayOfMonth, cs.LastDayOfMonth, cs.clinical_category from census_staging cs) c
inner join #location_mapping l on l.clinical_category = c.clinical_category
inner join all_admissions a on a.encounter_location = l.location and a.site = l.site
	and ((start_datetime >= FirstDayOfMonth and start_datetime <= LastDayOfMonth)
		or (end_datetime >= FirstDayOfMonth and end_datetime <= LastDayOfMonth)
		or (start_datetime < FirstDayOfMonth and end_datetime >= LastDayOfMonth)
		or (start_datetime < FirstDayOfMonth and end_datetime is null))
;

-- update columns on slotted table to enable summing totals
update a
set total_patient_days = datediff(day, effective_start_datetime, effective_end_datetime)
from #admission_month_categories a;

-- note difference between days hospitalized and patient days is a same day admission/discharge = 1 hospital day but 0 patient days
update a
set total_days_hospitalized = iif(total_patient_days = 0,1,total_patient_days)
from #admission_month_categories a ;

update a 
set discharged = 1 
from #admission_month_categories a
inner join all_admissions aa on aa.encounter_id = a.encounter_id
where month(end_datetime) = a.reporting_month 
and year(end_datetime) = a.reporting_year
and aa.ending_disposition in ('Transfer out of hospital','Discharged');

update a 
set died_within_48hrs = 1 
from #admission_month_categories a
inner join all_admissions aa on aa.encounter_id = a.encounter_id
where month(end_datetime) = a.reporting_month 
and year(end_datetime) = a.reporting_year 
and aa.ending_disposition = 'Death'
and datediff(day, effective_start_datetime, effective_end_datetime) <= 2;

update a 
set died_greater_48hrs = 1 
from #admission_month_categories a
inner join all_admissions aa on aa.encounter_id = a.encounter_id
where month(end_datetime) = a.reporting_month 
and year(end_datetime) = a.reporting_year 
and aa.ending_disposition = 'Death'
and datediff(day, effective_start_datetime, effective_end_datetime) > 2;

-- sum up rows to derive the results
update c
set c.total = i.sum_patient_days
from census_staging c 
inner join 
	(select site, reporting_year, reporting_month, clinical_category, indicator, SUM(total_patient_days) "sum_patient_days"
	from #admission_month_categories 
	group by site, reporting_year, reporting_month, clinical_category, indicator) i
	on c.site = i.site 
	and c.reporting_year = i.reporting_year
	and c.reporting_month = i.reporting_month
	and c.clinical_category = i.clinical_category
 where c.indicator = 'patient_days';

update c
set c.total = i.sum_days_hospitalized
from census_staging c 
inner join 
	(select site, reporting_year, reporting_month, clinical_category, indicator, SUM(total_days_hospitalized) "sum_days_hospitalized"
	from #admission_month_categories 
	group by site, reporting_year, reporting_month, clinical_category, indicator) i
	on c.site = i.site 
	and c.reporting_year = i.reporting_year
	and c.reporting_month = i.reporting_month
	and c.clinical_category = i.clinical_category
 where c.indicator = 'days_hospitalized';

update c
set c.total = i.sum_hospitalizations
from census_staging c 
inner join 
	(select site, reporting_year, reporting_month, clinical_category, indicator, count(*) "sum_hospitalizations"
	from #admission_month_categories 
	group by site, reporting_year, reporting_month, clinical_category, indicator) i
	on c.site = i.site 
	and c.reporting_year = i.reporting_year
	and c.reporting_month = i.reporting_month
	and c.clinical_category = i.clinical_category
 where c.indicator = 'hospitalizations';

update c
set c.total = i.sum_discharges
from census_staging c 
inner join 
	(select site, reporting_year, reporting_month, clinical_category, indicator, sum(discharged) "sum_discharges"
	from #admission_month_categories 
	group by site, reporting_year, reporting_month, clinical_category, indicator) i
	on c.site = i.site 
	and c.reporting_year = i.reporting_year
	and c.reporting_month = i.reporting_month
	and c.clinical_category = i.clinical_category
 where c.indicator = 'discharges';

update c
set c.total = i.sum_died_within_48hrs
from census_staging c 
inner join 
	(select site, reporting_year, reporting_month, clinical_category, indicator, sum(died_within_48hrs) "sum_died_within_48hrs"
	from #admission_month_categories 
	group by site, reporting_year, reporting_month, clinical_category, indicator) i
	on c.site = i.site 
	and c.reporting_year = i.reporting_year
	and c.reporting_month = i.reporting_month
	and c.clinical_category = i.clinical_category
 where c.indicator = 'deaths_less_than_48_hours';

update c
set c.total = i.sum_died_greater_48hrs
from census_staging c 
inner join 
	(select site, reporting_year, reporting_month, clinical_category, indicator, sum(died_greater_48hrs) "sum_died_greater_48hrs"
	from #admission_month_categories 
	group by site, reporting_year, reporting_month, clinical_category, indicator) i
	on c.site = i.site 
	and c.reporting_year = i.reporting_year
	and c.reporting_month = i.reporting_month
	and c.clinical_category = i.clinical_category
 where c.indicator = 'deaths_greater_than_48_hours';

-- update to 0 if there are no results in a row
update c 
set c.total = 0
from census_staging c
where c.total is null;

-- ------------------------------------------------------------------------------------
ALTER TABLE census_staging DROP COLUMN FirstDayOfMonth, LastDayOfMOnth;

DROP TABLE IF EXISTS inpatient_census;
EXEC sp_rename 'census_staging', 'inpatient_census';
