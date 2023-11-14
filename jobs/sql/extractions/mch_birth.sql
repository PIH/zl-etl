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
birth_macerated_fetus        VARCHAR(5)   
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

-- UPDATE temp_mch_birth1 SET birth_number = 1;
UPDATE temp_mch_birth SET birth_outcome = OBS_FROM_GROUP_ID_VALUE_CODED_LIST(birth_obs_group_id,'CIEL','161033',@locale);
UPDATE temp_mch_birth SET birth_weight = OBS_FROM_GROUP_ID_VALUE_NUMERIC(birth_obs_group_id,'CIEL','5916');
UPDATE temp_mch_birth SET birth_apgar = OBS_FROM_GROUP_ID_VALUE_NUMERIC(birth_obs_group_id,'CIEL','1504');
UPDATE temp_mch_birth SET birth_neonatal_resuscitation = OBS_FROM_GROUP_ID_VALUE_CODED_LIST(birth_obs_group_id,'CIEL','162131',@locale);
UPDATE temp_mch_birth SET birth_macerated_fetus = OBS_FROM_GROUP_ID_VALUE_CODED_LIST(birth_obs_group_id,'CIEL','135437',@locale);

DROP TEMPORARY TABLE IF EXISTS temp_mch_birth_dup;
CREATE TEMPORARY TABLE temp_mch_birth_dup
select * from temp_mch_birth;

create index temp_mch_birth_dup_ei on temp_mch_birth_dup(encounter_id);
create index temp_mch_birth_dup_c1 on temp_mch_birth_dup(encounter_id,birth_obs_group_id);

UPDATE temp_mch_birth t SET multiples = (SELECT COUNT(birth_obs_group_id) FROM temp_mch_birth_dup t2 WHERE t2.encounter_id = t.encounter_id);
UPDATE temp_mch_birth t SET birth_number = t.multiples - (select count(*) from temp_mch_birth_dup t2 where t2.encounter_id = t.encounter_id and t2.birth_obs_group_id > t.birth_obs_group_id);

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
birth_macerated_fetus
FROM temp_mch_birth ORDER BY patient_id, encounter_id, birth_number;
