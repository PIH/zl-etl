create table all_encounters
(
    emr_id              varchar(50),
    encounter_id        varchar(25),
    patient_id          varchar(25),
    visit_id            varchar(25),
    encounter_type_name varchar(50),
    encounter_location  varchar(255),
    encounter_datetime  datetime,
    entered_datetime    datetime,
    user_entered        varchar(255),
    next_appt_date      date,
    disposition         varchar(255),
    index_asc           int,
    index_desc          int
);
