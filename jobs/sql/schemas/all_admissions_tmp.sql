create table all_admissions_tmp
(
	emr_id                varchar(15),
   encounter_id         int,
   visit_id              int,
   start_date           datetime,
   end_date             datetime,
   creator              varchar(255),
   date_entered         date,
   encounter_location   varchar(255),
   provider             varchar(255),
   encounter_type       int,
   encounter_type_name  varchar(50),
   outcome_disposition	 varchar(255),
   voided               bit
);