CREATE TABLE eid_patient
(
emr_id                        varchar(50),   
hiv_emr_id                    varchar(50),   
dossier_id                    varchar(50),   
gender                        varchar(50),   
birthdate                     date,          
telephone_number              varchar(100),  
current_age                   float,         
initial_enrollment_date       date,          
initial_enrollment_location   varchar(255),  
latest_enrollment_location    varchar(255),  
current_treatment_status      varchar(255),  
completion_date               date,          
outcome                       varchar(255),   
latest_hiv_test_date          date,         
latest_hiv_test_type          varchar(255), 
latest_hiv_test_result        varchar(255), 
art_start_date                date,         
mother_emr_id                 varchar(50)
);
