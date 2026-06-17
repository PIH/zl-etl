create table consult_encounters 
(                         
       emr_id             varchar(50),   
       encounter_id       varchar(50),   
       visit_id           varchar(50),   
       encounter_datetime datetime,      
       user_entered       varchar(255),  
       datetime_created   datetime,   
       encounter_location varchar(255),
       encounter_type     varchar(255),  
       provider           varchar(255),  
       trauma             bit,           
       trauma_type        varchar(255),  
       return_visit_date  date,          
       disposition        varchar(255),
       admission_location varchar(255),
       internal_transfer_location varchar(255),
       external_transfer_location varchar(255),
       index_asc          int,           
       index_desc         int            
 );
