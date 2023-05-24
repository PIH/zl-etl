CREATE TABLE all_vitals
(                                          
all_vitals_id      int,                    
emr_id             varchar(25),            
encounter_id       varchar(25),            
visit_id           varchar(25),            
encounter_location varchar(255),           
encounter_datetime datetime,               
encounter_provider VARCHAR(255),           
date_entered       datetime,               
user_entered       varchar(255),           
height             float,                  
weight             float,                  
temperature        float,                  
heart_rate         float,                  
respiratory_rate   float,                  
bp_systolic        float,                  
bp_diastolic       float,                  
o2_saturation      float,                  
muac_mm            float,                  
chief_complaint    text,                   
index_asc          int,                    
index_desc         int                     
);  
