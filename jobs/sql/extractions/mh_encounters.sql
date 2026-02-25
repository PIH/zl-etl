-- set @startDate='2015-12-01';
-- set @endDate='2025-02-05';

SELECT encounter_type_id INTO @mhEncounterTypeId FROM encounter_type et WHERE et.uuid ='a8584ab8-cc2a-11e5-9956-625662870761';
set @answerExists = concept_name(concept_from_mapping('PIH','YES'), global_property_value('default_locale', 'en'));
set @mental_health_intervention = concept_from_mapping('PIH','10636');
set @interpersonal_psychotherapy = concept_from_mapping('PIH','10639');
set @interpersonal_inventory = concept_from_mapping('PIH','12045');
set @instilling_hope = concept_from_mapping('PIH','12048');
set @providing_the_sick_role = concept_from_mapping('PIH','12041');
set @informing_patient_of_diagnosis = concept_from_mapping('PIH','12044');
set @behavioral_activation_therapy = concept_from_mapping('PIH','10645');
set @cognitive_processing_therapy = concept_from_mapping('PIH','11970');
set @cognitive_behaviour_therapy = concept_from_mapping('PIH','12043');
set @psychotherapy = concept_from_mapping('PIH','10638');
set @supportive_psychotherapy = concept_from_mapping('PIH','12037');
set @progressive_muscle_relaxation = concept_from_mapping('PIH','12047');
set @hiv_aids_counseling = concept_from_mapping('PIH','12073');
set @other = concept_from_mapping('PIH','5622');

SET @partition = '${partitionNum}';


DROP TEMPORARY TABLE IF EXISTS temp_mh_encounters;
CREATE TEMPORARY TABLE temp_mh_encounters
(
emr_id                            varchar(50),  
dossier_id                        varchar(50),  
encounter_id                      int(11),      
encounter_datetime                datetime,       
patient_id                        int(11),      
visit_id                          int(11),      
creator                           int(11),      
user_entered                      text,         
location_id                       int(11),      
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
age_at_enc                        double,         
referred_from_community_by        varchar(255), 
other_referring_person            text,         
type_of_referral_role             VARCHAR(255), 
other_referring_role_type         text,         
referred_from_other_service       VARCHAR(255), 
referred_from_other_service_other text,         
visit_type                        varchar(255), 
consultation_method               varchar(255), 
chief_complaint                   text,         
new_patient                       tinyint,      
chw_for_mental_health             tinyint,      
patient_relapse                   tinyint,      
hospitalized_since_last_visit     tinyint,      
reason_for_hospitalization        text,         
adherence_to_appointment_day      varchar(255), 
hospitalized_at_time_of_visit     tinyint,      
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
appearance_normal                 tinyint,      
speech_normal                     tinyint,      
cognitive_function_normal         tinyint,      
mood_disorder                     tinyint,      
muscle_tone_normal                tinyint,      
traumatic_event                   tinyint,      
introspection_normal              tinyint,      
thought_content                   varchar(255), 
danger_to_self                    tinyint,      
anxiety_and_phobia                tinyint,      
psychosocial_evaluation           tinyint,      
judgement                         varchar(255), 
danger_to_others                  tinyint,      
affect                            tinyint,      
additional_comments               text,         
thought_process                   varchar(255), 
past_suicidal_ideation            tinyint,      
current_suicidal_ideation         tinyint,      
past_suicidal_attempts            tinyint,      
current_suicidal_attempts         tinyint,      
last_suicide_attempt_date         date,         
suicidal_screen_completed         VARCHAR(50),  
suicidal_screening_result         VARCHAR(255), 
discussed_patient_with_supervisor tinyint,      
safety_plan_completed             tinyint,      
hospitalize_due_to_suicide_risk   tinyint,   
psychological_intervention        text,
other_psychological_intervention  text,
medication_comments               text,
pregnant                          tinyint,      
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


INSERT INTO temp_mh_encounters (patient_id, encounter_id, visit_id, encounter_datetime, entered_datetime, creator, location_id)
SELECT  patient_id,
		encounter_id,
		visit_id,
		encounter_datetime,
		date_created,
		creator,
		location_id
FROM encounter e
where e.voided = 0
and e.encounter_type = @mhEncounterTypeId
and (DATE(encounter_datetime) >=  date(@startDate) or @startDate is null)
and (DATE(encounter_datetime) <=  date(@endDate) or @endDate is null);

update temp_mh_encounters set user_entered= person_name_of_user(creator);
update temp_mh_encounters set encounter_location = location_name(location_id);
update temp_mh_encounters set provider = provider(encounter_id);
update temp_mh_encounters set age_at_enc = age_at_enc(patient_id, encounter_id);

-- patient-level information  ------------------------------

DROP TEMPORARY TABLE IF EXISTS temp_mh_patient;
CREATE TEMPORARY TABLE temp_mh_patient
(
patient_id               int(11),      
dossier_id               varchar(50),  
emr_id                   varchar(50),  
loc_registered           varchar(255), 
unknown_patient          varchar(50),  
gender                   varchar(50),  
department               varchar(255), 
commune                  varchar(255), 
section                  varchar(255),  
locality                 varchar(255), 
street_landmark          varchar(255), 
section_communale_CDC_ID varchar(11)    
    );
   
insert into temp_mh_patient(patient_id)
select distinct patient_id from temp_mh_encounters;

create index temp_mh_patient_pi on temp_mh_patient(patient_id);

update temp_mh_patient set emr_id = zlemr(patient_id);
update temp_mh_patient set dossier_id = dosid(patient_id);
update temp_mh_patient set loc_registered = loc_registered(patient_id);
update temp_mh_patient set unknown_patient = unknown_patient(patient_id);
update temp_mh_patient set gender = gender(patient_id);

update temp_mh_patient t
inner join person_address a on a.person_address_id =
	(select a2.person_address_id from person_address a2
	where a2.person_id = t.patient_id
	order by preferred desc, date_created desc limit 1)
set 	t.department = a.state_province,
	t.commune = a.city_village,
	t.section = a.address3,
	t.locality = a.address1,
	t.street_landmark = a.address2;

update temp_mh_patient set section_communale_CDC_ID = cdc_id(patient_id);

update temp_mh_encounters t
inner join temp_mh_patient p on t.patient_id = p.patient_id
set t.dossier_id = p.dossier_id,
	t.emr_id = p.emr_id,
	t.loc_registered = p.loc_registered,
	t.unknown_patient = p.unknown_patient,
	t.gender = p.gender,
	t.department = p.department,
	t.commune = p.commune,
	t.section = p.section,
	t.locality = p.locality,
	t.street_landmark = p.street_landmark,
	t.section_communale_CDC_ID = p.section_communale_CDC_ID;

-- set up temporary obs table

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.comments,o.date_created 
from obs o
inner join temp_mh_encounters t on t.encounter_id = o.encounter_id
where o.voided = 0;

create index temp_obs_ei on temp_obs(encounter_id);
create index temp_obs_c1 on temp_obs(encounter_id, concept_id);

-- referral section ------------------------------------------------
SET @cid_10635 = concept_from_mapping('PIH','10635');
SET @cid_14415 = concept_from_mapping('PIH','14415');
SET @cid_7454  = concept_from_mapping('PIH','7454');
SET @cid_15027 = concept_from_mapping('PIH','15027');
SET @cid_13236 = concept_from_mapping('PIH','13236');
SET @cid_3589  = concept_from_mapping('PIH','3589');
SET @cid_10137 = concept_from_mapping('PIH','10137');
SET @cid_14986 = concept_from_mapping('PIH','14986');
SET @cid_14991 = concept_from_mapping('PIH','14991');
SET @cid_13724 = concept_from_mapping('PIH','13724');
SET @cid_1715  = concept_from_mapping('PIH','1715');
SET @cid_11065 = concept_from_mapping('PIH','11065');
SET @cid_10552 = concept_from_mapping('PIH','10552');
SET @cid_3289  = concept_from_mapping('PIH','3289');
SET @cid_1429  = concept_from_mapping('PIH','1429');
SET @cid_10647 = concept_from_mapping('PIH','10647');
SET @cid_6421  = concept_from_mapping('PIH','6421');

UPDATE temp_mh_encounters
SET referred_from_community_by =
  obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_10647, @locale);

UPDATE temp_mh_encounters
SET other_referring_person =
  obs_value_text_from_temp_using_concept_id(encounter_id, @cid_6421);

UPDATE temp_mh_encounters
SET type_of_referral_role = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_10635, @locale);

UPDATE temp_mh_encounters
SET other_referring_role_type = obs_value_text_from_temp_using_concept_id(encounter_id, @cid_14415);

UPDATE temp_mh_encounters
SET referred_from_other_service = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_7454, @locale);

UPDATE temp_mh_encounters
SET referred_from_other_service_other = obs_value_text_from_temp_using_concept_id(encounter_id, @cid_15027);

UPDATE temp_mh_encounters
SET visit_type = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_13236, @locale);

UPDATE temp_mh_encounters
SET consultation_method = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_3589, @locale);

UPDATE temp_mh_encounters
SET chief_complaint = obs_value_text_from_temp_using_concept_id(encounter_id, @cid_10137);

update temp_mh_encounters set new_patient =value_coded_as_boolean(obs_id_from_temp(encounter_id, 'PIH','14986',0));

UPDATE temp_mh_encounters
SET chw_for_mental_health = value_coded_as_boolean(obs_id_from_temp_using_concept_id(encounter_id, @cid_14991, 0));

UPDATE temp_mh_encounters
SET patient_relapse = value_coded_as_boolean(obs_id_from_temp_using_concept_id(encounter_id, @cid_13724, 0));

-- duplicate kept from your original list
UPDATE temp_mh_encounters
SET patient_relapse = value_coded_as_boolean(obs_id_from_temp_using_concept_id(encounter_id, @cid_13724, 0));

UPDATE temp_mh_encounters
SET hospitalized_since_last_visit = value_coded_as_boolean(obs_id_from_temp_using_concept_id(encounter_id, @cid_1715, 0));

UPDATE temp_mh_encounters
SET reason_for_hospitalization = obs_value_text_from_temp_using_concept_id(encounter_id, @cid_11065);

UPDATE temp_mh_encounters
SET adherence_to_appointment_day = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_10552, @locale);

UPDATE temp_mh_encounters
SET hospitalized_at_time_of_visit =
  IF(
    obs_single_value_coded_from_temp_using_concept_id(encounter_id, @cid_3289, @cid_1429) = @answerExists,
    1,
    NULL
  );

-- Scores section
SET @cid_10584 = concept_from_mapping('PIH','10584');
SET @cid_10590 = concept_from_mapping('PIH','10590');
SET @cid_12428 = concept_from_mapping('PIH','12428');
SET @cid_12422 = concept_from_mapping('PIH','12422');
SET @cid_10586 = concept_from_mapping('PIH','10586');
SET @cid_10587 = concept_from_mapping('PIH','10587');
SET @cid_10585 = concept_from_mapping('PIH','10585');
SET @cid_10589 = concept_from_mapping('PIH','10589');
SET @cid_10650 = concept_from_mapping('PIH','10650');
SET @cid_10651 = concept_from_mapping('PIH','10651');
SET @cid_10652 = concept_from_mapping('PIH','10652');
SET @cid_10591 = concept_from_mapping('PIH','10591');
SET @cid_6797  = concept_from_mapping('PIH','6797');

UPDATE temp_mh_encounters
SET zldsi_score = obs_value_numeric_from_temp_using_concept_id(encounter_id, @cid_10584);

UPDATE temp_mh_encounters
SET ces_dc_score = obs_value_numeric_from_temp_using_concept_id(encounter_id, @cid_10590);

UPDATE temp_mh_encounters
SET pcl_5_score = obs_value_numeric_from_temp_using_concept_id(encounter_id, @cid_12428);

UPDATE temp_mh_encounters
SET psc_35_score = obs_value_numeric_from_temp_using_concept_id(encounter_id, @cid_12422);

UPDATE temp_mh_encounters
SET cgi_s_score = obs_value_numeric_from_temp_using_concept_id(encounter_id, @cid_10586);

UPDATE temp_mh_encounters
SET cgi_i_score = obs_value_numeric_from_temp_using_concept_id(encounter_id, @cid_10587);

UPDATE temp_mh_encounters
SET cgi_e_score = obs_value_numeric_from_temp_using_concept_id(encounter_id, @cid_10585);

UPDATE temp_mh_encounters
SET whodas_score = obs_value_numeric_from_temp_using_concept_id(encounter_id, @cid_10589);

UPDATE temp_mh_encounters
SET days_with_difficulties = obs_value_numeric_from_temp_using_concept_id(encounter_id, @cid_10650);

UPDATE temp_mh_encounters
SET days_without_usual_activity = obs_value_numeric_from_temp_using_concept_id(encounter_id, @cid_10651);

UPDATE temp_mh_encounters
SET days_with_less_activity = obs_value_numeric_from_temp_using_concept_id(encounter_id, @cid_10652);

UPDATE temp_mh_encounters
SET aims = obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_10591, @locale);

UPDATE temp_mh_encounters
SET seizure_frequency = obs_value_numeric_from_temp_using_concept_id(encounter_id, @cid_6797);



-- status section ----------------------------------------------
SET @normal  = concept_name(concept_from_mapping('PIH','1115'), @locale);
SET @abnormal = concept_name(concept_from_mapping('PIH','1116'), @locale);
SET @yes     = concept_name(concept_from_mapping('PIH','1065'), @locale);
SET @no      = concept_name(concept_from_mapping('PIH','1066'), @locale);

SET @cid_14126 = concept_from_mapping('PIH','14126');
SET @cid_14286 = concept_from_mapping('PIH','14286');
SET @cid_20722 = concept_from_mapping('PIH','20722');
SET @cid_9527  = concept_from_mapping('PIH','9527');
SET @cid_15034 = concept_from_mapping('PIH','15034');
SET @cid_12362 = concept_from_mapping('PIH','12362');
SET @cid_13089 = concept_from_mapping('PIH','13089');
SET @cid_14157 = concept_from_mapping('PIH','14157');
SET @cid_10633 = concept_from_mapping('PIH','10633');
SET @cid_2719  = concept_from_mapping('PIH','2719');
SET @cid_13175 = concept_from_mapping('PIH','13175');
SET @cid_14110 = concept_from_mapping('PIH','14110');
SET @cid_15106 = concept_from_mapping('PIH','15106');
SET @cid_14155 = concept_from_mapping('PIH','14155');
SET @cid_10472 = concept_from_mapping('PIH','10472');
SET @cid_14156 = concept_from_mapping('PIH','14156');

UPDATE temp_mh_encounters
SET appearance_normal =
  CASE
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_14126, @locale) = @normal THEN 1
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_14126, @locale) = @abnormal THEN 0
  END;

UPDATE temp_mh_encounters
SET speech_normal =
  CASE
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_14286, @locale) = @normal THEN 1
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_14286, @locale) = @abnormal THEN 0
  END;

UPDATE temp_mh_encounters
SET cognitive_function_normal =
  CASE
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_20722, @locale) = @normal THEN 1
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_20722, @locale) = @abnormal THEN 0
  END;

UPDATE temp_mh_encounters
SET mood_disorder =
  CASE
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_9527, @locale) = @yes THEN 1
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_9527, @locale) = @no THEN 0
  END;

UPDATE temp_mh_encounters
SET muscle_tone_normal =
  CASE
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_15034, @locale) = @normal THEN 1
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_15034, @locale) = @abnormal THEN 0
  END;

UPDATE temp_mh_encounters
SET traumatic_event =
  CASE
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_12362, @locale) = @yes THEN 1
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_12362, @locale) = @no THEN 0
  END;

UPDATE temp_mh_encounters
SET introspection_normal =
  CASE
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_13089, @locale) = @normal THEN 1
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_13089, @locale) = @abnormal THEN 0
  END;

UPDATE temp_mh_encounters
SET thought_content =
  obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_14157, @locale);

UPDATE temp_mh_encounters
SET danger_to_self =
  CASE
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_10633, @locale) = @yes THEN 1
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_10633, @locale) = @no THEN 0
  END;

UPDATE temp_mh_encounters
SET anxiety_and_phobia =
  CASE
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_2719, @locale) = @yes THEN 1
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_2719, @locale) = @no THEN 0
  END;

UPDATE temp_mh_encounters
SET psychosocial_evaluation =
  CASE
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_13175, @locale) = @yes THEN 1
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_13175, @locale) = @no THEN 0
  END;

UPDATE temp_mh_encounters
SET judgement =
  obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_14110, @locale);

UPDATE temp_mh_encounters
SET danger_to_others =
  CASE
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_15106, @locale) = @yes THEN 1
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_15106, @locale) = @no THEN 0
  END;

UPDATE temp_mh_encounters
SET affect =
  CASE
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_14155, @locale) = @normal THEN 1
    WHEN obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_13089,  @locale) = @abnormal THEN 0
  END;

UPDATE temp_mh_encounters
SET additional_comments =
  obs_value_text_from_temp_using_concept_id(encounter_id, @cid_10472);

UPDATE temp_mh_encounters
SET thought_process =
  obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_14156, @locale);

-- suicidal evaluation ---------------------------------------------
SET @cid_10140 = concept_from_mapping('PIH','10140');
SET @cid_10633 = concept_from_mapping('PIH','10633');
SET @cid_7514  = concept_from_mapping('PIH','7514');
SET @cid_10594 = concept_from_mapping('PIH','10594');
SET @cid_12420 = concept_from_mapping('PIH','12420');
SET @cid_10648 = concept_from_mapping('PIH','10648');
SET @cid_12376 = concept_from_mapping('PIH','12376');
SET @cid_12421 = concept_from_mapping('PIH','12421');
SET @cid_12429 = concept_from_mapping('PIH','12429');
SET @cid_10646 = concept_from_mapping('PIH','10646');
SET @cid_12426 = concept_from_mapping('PIH','12426');

UPDATE temp_mh_encounters
SET past_suicidal_ideation =
  IF(
    obs_single_value_coded_from_temp_using_concept_id(encounter_id, @cid_10140, @cid_10633) = @answerExists,
    1,
    NULL
  );

UPDATE temp_mh_encounters
SET past_suicidal_attempts =
  IF(
    obs_single_value_coded_from_temp_using_concept_id(encounter_id, @cid_10140, @cid_7514) = @answerExists,
    1,
    NULL
  );

UPDATE temp_mh_encounters
SET current_suicidal_ideation =
  IF(
    obs_single_value_coded_from_temp_using_concept_id(encounter_id, @cid_10594, @cid_10633) = @answerExists,
    1,
    NULL
  );

UPDATE temp_mh_encounters
SET current_suicidal_attempts =
  IF(
    obs_single_value_coded_from_temp_using_concept_id(encounter_id, @cid_10594, @cid_7514) = @answerExists,
    1,
    NULL
  );

UPDATE temp_mh_encounters
SET last_suicide_attempt_date =
  DATE(obs_value_datetime_from_temp_using_concept_id(encounter_id, @cid_12420));

UPDATE temp_mh_encounters
SET suicidal_screen_completed =
  IF(
    obs_single_value_coded_from_temp_using_concept_id(encounter_id, @cid_10648, @cid_1065) = @answerExists,
    1,
    NULL
  );

UPDATE temp_mh_encounters
SET suicidal_screening_result =
  obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_12376, @locale);

UPDATE temp_mh_encounters
SET discussed_patient_with_supervisor =
  IF(
    obs_single_value_coded_from_temp_using_concept_id(encounter_id, @cid_12421, @cid_12429) = @answerExists,
    1,
    NULL
  );

UPDATE temp_mh_encounters
SET safety_plan_completed =
  IF(
    obs_single_value_coded_from_temp_using_concept_id(encounter_id, @cid_12421, @cid_10646) = @answerExists,
    1,
    NULL
  );

UPDATE temp_mh_encounters
SET hospitalize_due_to_suicide_risk =
  IF(
    obs_single_value_coded_from_temp_using_concept_id(encounter_id, @cid_12421, @cid_12426) = @answerExists,
    1,
    NULL
  );

-- Psychological interventions -----------------------------

-- note that this question is the same as used elsewhere on the form, hence the hardcoding of the answers here
update temp_mh_encounters t set psychological_intervention = 
    (select group_concat(distinct concept_name(o.value_coded, @locale) separator ' | ') 
    from temp_obs o
    where o.voided = 0
      and o.encounter_id = t.encounter_id
      and o.concept_id = @mental_health_intervention
      and o.value_coded in 
      (@mental_health_intervention,
		@interpersonal_psychotherapy,
		@interpersonal_inventory,
		@instilling_hope,
		@providing_the_sick_role,
		@informing_patient_of_diagnosis,
		@behavioral_activation_therapy,
		@cognitive_processing_therapy,
		@cognitive_behaviour_therapy,
		@psychotherapy,
		@supportive_psychotherapy,
		@progressive_muscle_relaxation,
		@hiv_aids_counseling,
		@other)
	group by o.encounter_id);

SET @cid_10636 = concept_from_mapping('PIH','10636');
SET @cid_5622  = concept_from_mapping('PIH','5622');
UPDATE temp_mh_encounters
SET other_psychological_intervention =
  obs_comments_from_temp_using_concept_id(encounter_id, @cid_10636, @cid_5622);

-- Medication Section ---------------------------------------------
-- actual medications included in another export/table
SET @cid_10637 = concept_from_mapping('PIH','10637');

UPDATE temp_mh_encounters
SET medication_comments =
  obs_value_text_from_temp_using_concept_id(encounter_id, @cid_10637);

-- Plan Section --------------------------------------------
SET @cid_5272  = concept_from_mapping('PIH','5272');
SET @cid_1065  = concept_from_mapping('PIH','1065');
SET @cid_968   = concept_from_mapping('PIH','968');
SET @cid_5596  = concept_from_mapping('PIH','5596');
SET @cid_10649 = concept_from_mapping('PIH','10649');
SET @cid_12553 = concept_from_mapping('PIH','12553');
SET @cid_8620  = concept_from_mapping('PIH','8620');
SET @cid_2881  = concept_from_mapping('PIH','2881');
SET @cid_5096  = concept_from_mapping('PIH','5096');

UPDATE temp_mh_encounters
SET pregnant =
  IF(
    obs_single_value_coded_from_temp_using_concept_id(encounter_id, @cid_5272, @cid_1065) = @answerExists,
    1,
    NULL
  );

UPDATE temp_mh_encounters
SET last_menstruation_date =
  DATE(obs_value_datetime_from_temp_using_concept_id(encounter_id, @cid_968));

UPDATE temp_mh_encounters
SET estimated_delivery_date =
  DATE(obs_value_datetime_from_temp_using_concept_id(encounter_id, @cid_5596));

UPDATE temp_mh_encounters
SET type_of_provider =
  obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_10649, @locale);

UPDATE temp_mh_encounters
SET referred_to_roles =
  obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_12553, @locale);

UPDATE temp_mh_encounters
SET disposition =
  obs_value_coded_list_from_temp_using_concept_id(encounter_id, @cid_8620, @locale);

UPDATE temp_mh_encounters
SET disposition_comment =
  obs_value_text_from_temp_using_concept_id(encounter_id, @cid_2881);

UPDATE temp_mh_encounters
SET return_date =
  DATE(obs_value_datetime_from_temp_using_concept_id(encounter_id, @cid_5096));

-- indexes -----------------------------------------

-- The ascending/descending indexes are calculated ordering on the encounter date
-- new temp tables are used to build them and then joined into the main temp table.
### index ascending
drop temporary table if exists temp_visit_index_asc;
CREATE TEMPORARY TABLE temp_visit_index_asc
(
    SELECT
            patient_id,
            encounter_datetime,
            encounter_id,
            index_asc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_asc,
            encounter_datetime,
            encounter_id,
            patient_id,
            @u:= patient_id
      FROM temp_mh_encounters,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id, encounter_datetime ASC, encounter_id ASC
        ) index_ascending );
CREATE INDEX tvia_e ON temp_visit_index_asc(encounter_id);
update temp_mh_encounters t
inner join temp_visit_index_asc tvia on tvia.encounter_id = t.encounter_id
set t.index_asc = tvia.index_asc;

drop temporary table if exists temp_visit_index_desc;
CREATE TEMPORARY TABLE temp_visit_index_desc
(
    SELECT
            patient_id,
            encounter_datetime,
            encounter_id,
            index_desc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_desc,
            encounter_datetime,
            encounter_id,
            patient_id,
            @u:= patient_id
      FROM temp_mh_encounters,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id, encounter_datetime DESC, encounter_id DESC
        ) index_descending );
       
 CREATE INDEX tvid_e ON temp_visit_index_desc(encounter_id);      
update temp_mh_encounters t
inner join temp_visit_index_desc tvid on tvid.encounter_id = t.encounter_id
set t.index_desc = tvid.index_desc;

-- final output ------------------------------------

select 
emr_id,
dossier_id,
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',encounter_id),encounter_id) "encounter_id",
encounter_datetime,
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',patient_id),patient_id) "patient_id",
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',visit_id),visit_id) "visit_id",
user_entered,
encounter_location,
entered_datetime,
provider,
loc_registered,
unknown_patient,
gender,
department,
commune,
section,
locality,
street_landmark,
section_communale_CDC_ID,
age_at_enc,
referred_from_community_by,
other_referring_person,
type_of_referral_role,
other_referring_role_type,
referred_from_other_service,
referred_from_other_service_other,
visit_type,
consultation_method,
chief_complaint,
new_patient,
chw_for_mental_health,
patient_relapse,
hospitalized_since_last_visit,
reason_for_hospitalization,
adherence_to_appointment_day,
hospitalized_at_time_of_visit,
zldsi_score,
ces_dc_score,
psc_35_score,
pcl_5_score,
cgi_s_score,
cgi_i_score,
cgi_e_score,
whodas_score,
days_with_difficulties,
days_without_usual_activity,
days_with_less_activity,
aims,
seizure_frequency,
appearance_normal,
speech_normal,
cognitive_function_normal,
mood_disorder,
muscle_tone_normal,
traumatic_event,
introspection_normal,
thought_content,
danger_to_self,
anxiety_and_phobia,
psychosocial_evaluation,
judgement,
danger_to_others,
affect,
additional_comments,
thought_process,
past_suicidal_ideation,
current_suicidal_ideation,
past_suicidal_attempts,
current_suicidal_attempts,
last_suicide_attempt_date,
suicidal_screen_completed,
suicidal_screening_result,
discussed_patient_with_supervisor,
safety_plan_completed,
hospitalize_due_to_suicide_risk,
pregnant,
psychological_intervention,
other_psychological_intervention,
medication_comments,
last_menstruation_date,
estimated_delivery_date,
type_of_provider,
referred_to_roles,
disposition,
disposition_comment,
return_date,
index_asc,
index_desc
from temp_mh_encounters;
