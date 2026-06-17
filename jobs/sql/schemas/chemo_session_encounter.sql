CREATE TABLE chemo_session_encounter 
(emr_id                    varchar(25),   
encounter_id               varchar(25),   
visit_id                   varchar(25),   
encounter_datetime         datetime,      
provider_name              varchar(255),  
user_entered               varchar(255),  
date_created               varchar(255),  
encounter_location         varchar(255),  
cycle_number               int,           
planned_chemo_sessions     int,           
treatment_plan             varchar(255),  
visit_information_comments text,          
index_asc                  int,           
index_desc                 int            
);
