create table hiv_psychosocial_encounter
(
emr_id                             varchar(255), 
encounter_id                       int,          
visit_id                           int,          
encounter_datetime                 datetime,     
datetime_created                   datetime,     
user_entered                       varchar(255), 
provider                           varchar(255), 
return_to_care_follow_up           bit,          
undetected_vl_follow_up            bit,          
inadherence_to_treatment_follow_up bit,          
other_follow_up                    bit,          
other_follow_up_text               text,         
home_visit_monitoring              bit,          
support_group_monitoring           bit,          
food_support_monitoring            bit,          
financial_support_monitoring       bit,          
income_generator_monitoring        bit,          
school_support_monitoring          bit,          
other_monitoring                   bit,          
other_monitoring_text              text,         
reasons_evaluation                 text,          
consequences_inadherence           text,          
willing_reenroll                   bit,       
action_reinforce_adherence         bit,       
index_asc                          INT,          
index_desc                         INT           
);
