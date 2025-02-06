CREATE TABLE mh_encounters 
(
	emr_id                            varchar(50),  
	dossier_id                        varchar(50),  
	encounter_id                      int,          
	encounter_datetime                datetime,     
	patient_id                        int,          
	visit_id                          int,          
	user_entered                      text,         
	encounter_location                varchar(255), 
	entered_datetime                  datetime,     
	provider                          text,         
	loc_registered                    varchar(255), 
	unknown_patient                   varchar(50),  
	gender                            varchar(50),  
	department                        varchar(255), 
	commune                           varchar(255), 
	section                           varchar(255), 
	locality                          varchar(255), 
	street_landmark                   varchar(255), 
	section_communale_CDC_ID          varchar(11),  
	age_at_enc                        float,        
	referred_from_community_by        varchar(255), 
	other_referring_person            text,         
	type_of_referral_role             VARCHAR(255), 
	other_referring_role_type         text,         
	referred_from_other_service       VARCHAR(255), 
	referred_from_other_service_other text,         
	visit_type                        varchar(255), 
	consultation_method               varchar(255), 
	chief_complaint                   text,         
	new_patient                       bit,          
	chw_for_mental_health             bit,          
	patient_relapse                   bit,          
	hospitalized_since_last_visit     bit,          
	reason_for_hospitalization        text,         
	adherence_to_appointment_day      varchar(255), 
	hospitalized_at_time_of_visit     bit,          
	zldsi_score                       int,          
	ces_dc_score                      int,          
	psc_35_score                      int,          
	pcl_5_score                       int,          
	cgi_s_score                       int,          
	cgi_i_score                       int,          
	cgi_e_score                       int,          
	whodas_score                      int,          
	days_with_difficulties            int,          
	days_without_usual_activity       int,          
	days_with_less_activity           int           , 
	aims                              varchar(20),  
	seizure_frequency                 int,          
	appearance_normal                 bit,          
	speech_normal                     bit,          
	cognitive_function_normal         bit,          
	mood_disorder                     bit,          
	muscle_tone_normal                bit,          
	traumatic_event                   bit,          
	introspection_normal              bit,          
	thought_content                   varchar(255), 
	danger_to_self                    bit,          
	anxiety_and_phobia                bit,          
	psychosocial_evaluation           bit,          
	judgement                         varchar(255), 
	danger_to_others                  bit,          
	affect                            bit,          
	additional_comments               text,         
	thought_process                   varchar(255), 
	past_suicidal_ideation            bit,          
	current_suicidal_ideation         bit,          
	past_suicidal_attempts            bit,          
	current_suicidal_attempts         bit,          
	last_suicide_attempt_date         date,         
	suicidal_screen_completed         VARCHAR(50),  
	suicidal_screening_result         VARCHAR(255), 
	discussed_patient_with_supervisor bit,          
	safety_plan_completed             bit,          
	hospitalize_due_to_suicide_risk   bit,          
	psychological_intervention        text,         
	other_psychological_intervention  text,         
	medication_comments               text,         
	pregnant                          bit,          
	last_menstruation_date            DATE,         
	estimated_delivery_date           DATE,         
	type_of_provider                  TEXT,         
	referred_to_roles                 TEXT,         
	disposition                       VARCHAR(255), 
	disposition_comment               TEXT,         
	return_date                       DATE,         
	index_asc                         int,          
	index_desc                        int           
);
