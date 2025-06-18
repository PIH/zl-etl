create table mch_j9_case_registration
(   
 patient_id              varchar(50),  
 patient_uuid            varchar(38),  
 given_name              varchar(255), 
 family_name             varchar(255), 
 zl_identifier           varchar(50),  
 dossier_identifier      varchar(50),  
 j9_group                text,         
 j9_program              varchar(255), 
 telephone               varchar(255), 
 birthdate               date,         
 age                     float,        
 estimated_delivery_date date,         
 actual_delivery_date    date,         
 mama_dossier            varchar(255), 
 department              varchar(255), 
 commune                 varchar(255), 
 section_communal        varchar(255), 
 locality                varchar(255), 
 street_landmark         varchar(255), 
 j9_enrollment_date      date          
);
