SET sql_safe_updates = 0;
set @partition = '${partitionNum}';
SET @delivery_encounter_type = (SELECT encounter_type_id FROM encounter_type WHERE uuid = "00e5ebb2-90ec-11e8-9eb6-529269fb1459");

DROP TEMPORARY TABLE IF EXISTS temp_mch_birth;
CREATE TEMPORARY TABLE temp_mch_birth(
patient_id                   INT,         
emr_id                       VARCHAR(50), 
encounter_id                 INT,         
encounter_datetime           DATETIME,    
date_entered                 DATETIME,    
user_entered                 VARCHAR(50), 
delivery_datetime            DATETIME,    
birth_obs_group_id           INT(11),     
birth_number                 INT,         
multiples                    INT,         
birth_apgar                  INT,         
birth_outcome                VARCHAR(30), 
birth_weight                 DOUBLE,      
birth_neonatal_resuscitation VARCHAR(5),  
birth_macerated_fetus        VARCHAR(5),
Type_of_delivery                varchar(500),
c_section_maternal_reasons      varchar(500),
other_c_section_maternal_reasons    text,
c_section_fetal_reasons         varchar(255),
other_c_section_fetal_reason        text,
c_section_obstetrical_reasons   varchar(255),
other_c_section_obstetrical_reason  text
);

-- encounter level columms
DROP TEMPORARY TABLE IF EXISTS temp_mch_birth_encounter;
CREATE TEMPORARY TABLE temp_mch_birth_encounter
(
patient_id         INT,         
emr_id             VARCHAR(50), 
encounter_id       INT,         
encounter_datetime DATETIME,    
date_entered       DATETIME,    
user_entered       VARCHAR(50), 
delivery_datetime  DATETIME     
);

INSERT INTO temp_mch_birth_encounter(patient_id, encounter_id, encounter_datetime, date_entered, user_entered)
SELECT patient_id, encounter_id, encounter_datetime, date_created, username(creator)
FROM encounter WHERE voided = 0 AND encounter_type = @delivery_encounter_type;

update temp_mch_birth_encounter t
set emr_id = zlemr(t.patient_id);

update temp_mch_birth_encounter t
set delivery_datetime = obs_value_datetime(encounter_id, 'PIH','5599');

-- birth-level columns
insert into temp_mch_birth(
	patient_id,
	emr_id,
	encounter_id,
	encounter_datetime,
	date_entered,
	user_entered,
	delivery_datetime,
	birth_obs_group_id)
select 
	e.patient_id,
	e.emr_id,
	e.encounter_id,
	e.encounter_datetime,
	e.date_entered,
	e.user_entered,
	e.delivery_datetime,
	o.obs_id 
from obs o 
inner join temp_mch_birth_encounter e on e.encounter_id = o.encounter_id 
where concept_id = concept_from_mapping('PIH','13555')
and voided = 0;

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, 
o.value_text,o.value_datetime, o.comments, o.date_created
from obs o
inner join temp_mch_birth_encounter t on t.encounter_id = o.encounter_id
where o.voided = 0;

create index temp_obs_obs_oi on temp_obs(obs_id);
create index temp_obs_obs_ogi on temp_obs(obs_group_id);


DROP TEMPORARY TABLE IF EXISTS temp_mch_birth_dup;
CREATE TEMPORARY TABLE temp_mch_birth_dup
select * from temp_mch_birth;

create index temp_mch_birth_dup_ei on temp_mch_birth_dup(encounter_id);
create index temp_mch_birth_dup_c1 on temp_mch_birth_dup(encounter_id,birth_obs_group_id);

UPDATE temp_mch_birth t SET multiples = (SELECT COUNT(birth_obs_group_id) FROM temp_mch_birth_dup t2 WHERE t2.encounter_id = t.encounter_id);
UPDATE temp_mch_birth t SET birth_number = t.multiples - (select count(*) from temp_mch_birth_dup t2 where t2.encounter_id = t.encounter_id and t2.birth_obs_group_id > t.birth_obs_group_id);

UPDATE temp_mch_birth SET birth_outcome = obs_from_group_id_value_coded_list_from_temp(birth_obs_group_id,'CIEL','161033',@locale);
UPDATE temp_mch_birth SET birth_weight = obs_from_group_id_value_numeric_from_temp(birth_obs_group_id,'CIEL','5916');
UPDATE temp_mch_birth SET birth_apgar = obs_from_group_id_value_numeric_from_temp(birth_obs_group_id,'CIEL','1504');
UPDATE temp_mch_birth SET birth_neonatal_resuscitation = obs_from_group_id_value_coded_list_from_temp(birth_obs_group_id,'CIEL','162131',@locale);
UPDATE temp_mch_birth SET birth_macerated_fetus = obs_from_group_id_value_coded_list_from_temp(birth_obs_group_id,'CIEL','135437',@locale);

update temp_mch_birth set Type_of_delivery = obs_from_group_id_value_coded_list_from_temp(birth_obs_group_id,'PIH','11663',@locale);
update temp_mch_birth t set c_section_maternal_reasons = obs_from_group_id_value_coded_list_from_temp(birth_obs_group_id,'PIH','13571',@locale);

-- TO DO: the following could use obs_from_group_id_comment_from_temp function but that function needs to be rewritten
-- to pass in an answer in addition to the question.  this will involve changing wherever that function is used
update temp_mch_birth t 
inner join temp_obs o on o.obs_group_id = t.birth_obs_group_id
	and o.concept_id = concept_from_mapping('PIH','13571')
	and o.value_coded = concept_from_mapping('PIH','5622')
set  other_c_section_maternal_reasons = o.comments;

update temp_mch_birth t set c_section_fetal_reasons = obs_from_group_id_value_coded_list_from_temp(birth_obs_group_id,'PIH','13572',@locale);
update temp_mch_birth t 
inner join temp_obs o on o.obs_group_id = t.birth_obs_group_id
	and o.concept_id = concept_from_mapping('PIH','13572')
	and o.value_coded = concept_from_mapping('PIH','5622')
set  other_c_section_fetal_reason = o.comments;

update temp_mch_birth t set c_section_obstetrical_reasons   = obs_from_group_id_value_coded_list_from_temp(birth_obs_group_id,'PIH','13573',@locale);
update temp_mch_birth t 
inner join temp_obs o on o.obs_group_id = t.birth_obs_group_id
	and o.concept_id = concept_from_mapping('PIH','13573')
	and o.value_coded = concept_from_mapping('PIH','5622')
set  other_c_section_fetal_reason = o.comments;

SELECT
emr_id,
concat(@partition,'-',encounter_id),
date(encounter_datetime),
date_entered,
user_entered,
delivery_datetime,
birth_number,
multiples,
birth_apgar,
birth_outcome,
birth_weight,
birth_neonatal_resuscitation,
birth_macerated_fetus,
Type_of_delivery,
c_section_maternal_reasons,
other_c_section_maternal_reasons,
c_section_fetal_reasons,
other_c_section_fetal_reason,
c_section_obstetrical_reasons,
other_c_section_obstetrical_reason
FROM temp_mch_birth ORDER BY patient_id, encounter_id, birth_number;
