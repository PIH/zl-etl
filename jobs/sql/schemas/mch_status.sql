CREATE TABLE mch_status
(
 patient_state_id       varchar(50),  
 patient_program_id     varchar(50),  
 emr_id                 varchar(25),  
 enrollment_location    varchar(255), 
 program_date_enrolled  date,         
 program_date_completed date,         
 treatment_status       varchar(255), 
 status_start_date      date,         
 status_end_date        date,         
 outcome                varchar(255), 
 index_asc              int,          
 index_desc             int    
);
