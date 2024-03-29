create table ed_triage
(
encounter_id             varchar(100),
date_entered             date,
user_entered             varchar(100),
visit_id                 varchar(100),      
zlemr_id                 varchar(50),  
dossier_id               varchar(50),  
loc_registered           varchar(255),   
unknown_patient          varchar(255),        
ed_visit_start_datetime  datetime,     
triage_datetime          datetime,       
encounter_location       text,         
provider                 varchar(255), 
triage_queue_status      varchar(255), 
triage_color             varchar(255), 
triage_score             int,          
chief_complaint          text,         
weight_kg                float, 
mobility                 text,         
respiratory_rate         float,       
blood_oxygen_saturation  float,       
pulse                    float,       
systolic_blood_pressure  float,       
diastolic_blood_pressure float,       
temperature_c            float, 
response                 text,         
trauma_present           text,         
neurological             text,         
burn                     text,         
glucose                  text,         
trauma_type              text,         
digestive                text,         
pregnancy                text,         
respiratory              text,         
pain                     text,         
other_symptom            text,         
clinical_impression      text,         
pregnancy_test           text,         
glucose_value            float,       
paracetamol_dose         float,       
treatment_administered   text,         
wait_minutes             float,       
index_asc                int,
index_desc               int     
);