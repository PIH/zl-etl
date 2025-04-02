DROP TABLE IF EXISTS all_admissions_staging;
create table all_admissions_staging
(
   emr_id               varchar(15),
   encounter_id         varchar(50),
   visit_id             varchar(255),
   encounter_type       varchar(50),
   start_datetime       datetime,
   end_datetime         datetime,
   user_entered         varchar(255),
   date_entered         date,
   encounter_location   varchar(255),
   provider             varchar(255),
   previous_disposition_encounter_id varchar(50),
   previous_disposition_datetime datetime,
   previous_disposition varchar(255),
   ending_disposition_encounter_id varchar(50),
   ending_disposition_datetime datetime,
   ending_disposition varchar(255),
   site                 varchar(255),
   partition_num        int
);

INSERT INTO all_admissions_staging(emr_id, encounter_id, visit_id, encounter_type, start_datetime,
   end_datetime, user_entered, date_entered, encounter_location, provider, site, partition_num)
SELECT emr_id,  
encounter_id,
visit_id,
encounter_type, 
encounter_datetime  AS start_date,
lag(encounter_datetime) OVER(PARTITION BY emr_id ORDER BY encounter_datetime desc ) AS end_date, 
user_entered  AS creator,
datetime_created  AS date_entered,
encounter_location,
provider,
site,
partition_num
FROM adt_encounters ae;

DELETE FROM all_admissions_staging WHERE encounter_type='Exit from Inpatient Care';

-- update end datetime based on visit end date
update a
set end_datetime = visit_date_stopped
from all_admissions_staging a
inner join all_visits v on v.visit_id = a.visit_id
where visit_date_stopped < end_datetime;

update a 
 set previous_disposition_datetime = e.encounter_datetime,
 	 previous_disposition = e.disposition,
 	 previous_disposition_encounter_id = e.encounter_id
from all_admissions_staging a
inner join all_encounters e on e.encounter_id = 
	(select top 1 e2.encounter_id from all_encounters e2
	where e2.emr_id = a.emr_id 
	and e2.encounter_datetime <= a.start_datetime
	and e2.disposition is not null
	order by e2.encounter_datetime desc, e2.encounter_id desc);	

update a 
 set ending_disposition_datetime = e.encounter_datetime,
 	 ending_disposition = e.disposition,
 	 ending_disposition_encounter_id = e.encounter_id
from all_admissions_staging a
inner join all_encounters e on e.encounter_id = 
	(select top 1 e2.encounter_id from all_encounters e2
	where e2.emr_id = a.emr_id 
	and e2.encounter_datetime <= a.end_datetime
	and e2.disposition is not null
	order by e2.encounter_datetime desc, e2.encounter_id desc);	

-- update rows based on closed visits.  Note that these won't have ending disposition info
update a
set end_datetime = v.visit_date_stopped
from all_admissions_staging a
inner join all_visits v on a.visit_id = v.visit_id
where end_datetime is null;

-- ------------------------------------------------------------------------------------
DROP TABLE IF EXISTS all_admissions;
EXEC sp_rename 'all_admissions_staging', 'all_admissions';
