CREATE TABLE chemo_session_regimens
(emr_id                    varchar(25),   
obs_id                     varchar(25),  
encounter_id               varchar(25),
encounter_datetime         datetime,
chemo_regimen_name         varchar(255),
other_regimen              text
);
