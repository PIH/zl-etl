create table all_encounters
(
encounter_id        int,
encounter_datetime  datetime, 
encounter_type      int,
location_id         int,
patient_id          int, 
visit_id            int, 
creator             int,
user_entered        varchar(255),
encounter_location  varchar(255),
encounter_type_name varchar(150),
entered_datetime    datetime,
emr_id              varchar(50),
next_appt_date      date,
index_asc           int,
index_desc          int		
);
