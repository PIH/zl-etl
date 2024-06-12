DROP TABLE IF EXISTS all_admissions;
create table all_admissions
(
   emr_id               varchar(15),
   encounter_id         varchar(255),
   visit_id             varchar(255),
   encounter_type       varchar(50),
   start_date           datetime,
   end_date             datetime,
   creator              varchar(255),
   date_entered         date,
   encounter_location   varchar(255),
   provider             varchar(255),
   site                 varchar(255),
   partition_num        int
);

INSERT INTO all_admissions(emr_id, encounter_id, visit_id, encounter_type, start_date,
   end_date, creator, date_entered, encounter_location, provider, site, partition_num)
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

DELETE FROM all_admissions WHERE encounter_type='Sortie de soins hospitaliers';
