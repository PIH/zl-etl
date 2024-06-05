SELECT encounter_type_id  INTO @hiv_psy_enc
FROM encounter_type et WHERE uuid='83081f7d-ffd7-4d43-9571-a86e1bc19d7f';


DROP temporary table if exists temp_hiv_encs;
create temporary table temp_hiv_encs
(
patient_id 			int,
emr_id				varchar(255),
encounter_id        int,
visit_id            int,
encounter_datetime  datetime,
datetime_created    datetime,
creator             int,	
user_entered        varchar(255),
provider            varchar(255),
return_to_care_follow_up boolean DEFAULT FALSE,
undetected_vl_follow_up boolean DEFAULT FALSE,
inadherence_to_treatment_follow_up boolean DEFAULT FALSE,
other_follow_up boolean DEFAULT FALSE,
other_follow_up_text varchar(500),
home_visit_monitoring boolean DEFAULT FALSE,
support_group_monitoring boolean DEFAULT FALSE,
food_support_monitoring boolean DEFAULT FALSE,
financial_support_monitoring boolean DEFAULT FALSE,
income_generator_monitoring boolean DEFAULT FALSE,
school_support_monitoring boolean DEFAULT FALSE,
other_monitoring boolean DEFAULT FALSE,
other_monitoring_text varchar(500),
index_asc INT,
index_desc INT
);

insert into temp_hiv_encs(patient_id, encounter_id, visit_id, encounter_datetime, 
datetime_created, creator)
select patient_id, encounter_id, visit_id, encounter_datetime, date_created, creator
from encounter e
where e.voided = 0
AND encounter_type IN (@hiv_psy_enc)
ORDER BY encounter_datetime desc;

create index temp_hiv_encs_ei on temp_hiv_encs(encounter_id);


UPDATE temp_hiv_encs
set user_entered = person_name_of_user(creator);

UPDATE temp_hiv_encs
SET provider = provider(encounter_id);

UPDATE temp_hiv_encs t
SET emr_id = patient_identifier(patient_id, 'a541af1e-105c-40bf-b345-ba1fd6a59b85');

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, 
o.value_text,o.value_datetime, o.comments, o.date_created, o.obs_datetime
from obs o
inner join temp_hiv_encs t on t.encounter_id = o.encounter_id
where o.voided = 0;

-- Follow Up ----- 

UPDATE temp_hiv_encs
SET return_to_care_follow_up=answerEverExists_from_temp(patient_id, 'PIH', '20105', 'PIH', '13161', null);

UPDATE temp_hiv_encs
SET undetected_vl_follow_up=answerEverExists_from_temp(patient_id, 'PIH', '20105', 'PIH', '11547', null);

UPDATE temp_hiv_encs
SET inadherence_to_treatment_follow_up=answerEverExists_from_temp(patient_id, 'PIH', '20105', 'PIH', '12416', null);

UPDATE temp_hiv_encs
SET other_follow_up=answerEverExists_from_temp(patient_id, 'PIH', '20105', 'PIH', '5622', null);

UPDATE temp_hiv_encs
SET other_follow_up_text=obs_comments_from_temp(encounter_id, 'PIH', '20105', 'PIH', '5622');


-- Monitoring ----- 

UPDATE temp_hiv_encs
SET home_visit_monitoring=answerEverExists_from_temp(patient_id, 'PIH', '20103', 'PIH', '13181',null);

UPDATE temp_hiv_encs
SET support_group_monitoring=answerEverExists_from_temp(patient_id, 'PIH', '20103', 'PIH', '2442',null);

UPDATE temp_hiv_encs
SET food_support_monitoring=answerEverExists_from_temp(patient_id, 'PIH', '20103', 'PIH', '1847',null);

UPDATE temp_hiv_encs
SET financial_support_monitoring=answerEverExists_from_temp(patient_id, 'PIH', '20103', 'PIH', '1398',null);

UPDATE temp_hiv_encs
SET income_generator_monitoring=answerEverExists_from_temp(patient_id, 'PIH', '20103', 'PIH', '13218',null);

UPDATE temp_hiv_encs
SET school_support_monitoring=answerEverExists_from_temp(patient_id, 'PIH', '20103', 'PIH', '2863',null);

UPDATE temp_hiv_encs
SET other_monitoring=answerEverExists_from_temp(patient_id, 'PIH', '20103', 'PIH', '2923',null);

UPDATE temp_hiv_encs
SET other_monitoring_text=obs_value_text_from_temp(encounter_id, 'PIH', '2923');


SELECT 
emr_id,
encounter_id,
visit_id,
encounter_datetime,
datetime_created,
user_entered,
provider,
return_to_care_follow_up,
undetected_vl_follow_up,
inadherence_to_treatment_follow_up,
other_follow_up,
other_follow_up_text,
home_visit_monitoring,
support_group_monitoring,
food_support_monitoring,
financial_support_monitoring,
income_generator_monitoring,
school_support_monitoring,
other_monitoring,
other_monitoring_text,
index_asc,
index_desc 
FROM temp_hiv_encs;

