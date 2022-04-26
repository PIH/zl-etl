SET sql_safe_updates = 0;

SET @vitals_encounter = (SELECT encounter_type_id FROM encounter_type WHERE uuid = '4fb47712-34a6-40d2-8ed3-e153abbd25b7');

DROP TEMPORARY TABLE IF EXISTS temp_vitals;
CREATE TEMPORARY TABLE temp_vitals
(
    all_vitals_id		int(11) PRIMARY KEY AUTO_INCREMENT,
	patient_id			int(11),
	emr_id          	VARCHAR(25),
    encounter_id		int(11),
    encounter_location	varchar(255),
    encounter_datetime	datetime,
    encounter_provider 	VARCHAR(255),
    date_entered		datetime,
    user_entered		varchar(255),
    height				double,
    weight				double,
    temperature			double,
    heart_rate			double,
    respiratory_rate	double,
    bp_systolic			double,
    bp_diastolic		double,
    o2_saturation		double,
    muac_mm				double,
    chief_complaint		text,
    index_asc			int,
    index_desc			int
    );

create index temp_vitals_ei on temp_vitals(encounter_id);
   
insert into temp_vitals(patient_id, emr_id, encounter_id, encounter_datetime, date_entered)   
select e.patient_id, zlemr(e.patient_id), e.encounter_id, e.encounter_datetime, e.date_created  from encounter e
where e.encounter_type = @vitals_encounter
and e.voided = 0;

update temp_vitals t
set t.encounter_location = encounter_location_name(encounter_id);

update temp_vitals t 
set t.encounter_provider = provider(encounter_id);

update temp_vitals t
set user_entered = encounter_creator(encounter_id);

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.comments 
from obs o
inner join temp_vitals t on t.encounter_id = o.encounter_id
where o.voided = 0;

create index temp_obs_concept_id on temp_obs(concept_id);
create index temp_obs_ei on temp_obs(encounter_id);
   
-- weight   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '5089') 
SET weight = o.value_numeric;

-- height   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '5090') 
SET height = o.value_numeric;

-- temp   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '5088') 
SET temperature = o.value_numeric;

-- hr   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = CONCEPT_FROM_MAPPING('CIEL', '5087') 
SET heart_rate = o.value_numeric;

-- respiratory_rate   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '5242') 
SET respiratory_rate = o.value_numeric;

-- bp_systolic   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '5085') 
SET bp_systolic = o.value_numeric;

-- bp_diastolic   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '5086') 
SET bp_diastolic = o.value_numeric;

-- o2_saturation   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '5092') 
SET o2_saturation = o.value_numeric;

-- muac   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '7956') 
SET muac_mm = o.value_numeric;


-- chief_complaint   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', '10137') 
SET chief_complaint = o.value_text;

-- The indexes are calculated using the ecnounter_date
### index ascending
DROP TEMPORARY TABLE IF EXISTS temp_vitals_index_asc;
CREATE TEMPORARY TABLE temp_vitals_index_asc
(
    SELECT
            all_vitals_id,
    		emr_id,
            encounter_datetime,
            date_entered,
            index_asc
FROM (SELECT
            @r:= IF(@u = emr_id, @r + 1,1) index_asc,
            encounter_datetime,
            date_entered,
            all_vitals_id,
            emr_id,
            @u:= emr_id
      FROM temp_vitals,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY emr_id, encounter_datetime ASC, date_entered ASC
        ) index_ascending );

create index temp_vitals_index_asc_avi on temp_vitals_index_asc(all_vitals_id);

update temp_vitals t
inner join temp_vitals_index_asc tvia on tvia.all_vitals_id = t.all_vitals_id
set t.index_asc = tvia.index_asc;

### index descending
DROP TEMPORARY TABLE IF EXISTS temp_vitals_index_desc;
CREATE TEMPORARY TABLE temp_vitals_index_desc
(
    SELECT
            all_vitals_id,
    		emr_id,
            encounter_datetime,
            date_entered,
            index_desc
FROM (SELECT
            @r:= IF(@u = emr_id, @r + 1,1) index_desc,
            encounter_datetime,
            date_entered,
            all_vitals_id,
            emr_id,
            @u:= emr_id
      FROM temp_vitals,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY emr_id, encounter_datetime desc, date_entered desc
        ) index_descending );

create index temp_vitals_index_desc_avi on temp_vitals_index_desc(all_vitals_id);

update temp_vitals t
inner join temp_vitals_index_desc tvid on tvid.all_vitals_id = t.all_vitals_id
set t.index_desc = tvid.index_desc;

select 
	all_vitals_id,
	emr_id ,
	encounter_id,
	encounter_location,
	encounter_datetime,
	encounter_provider,
	date_entered,
	user_entered,
	height,
	weight,
	temperature,
	heart_rate,
	respiratory_rate,
	bp_systolic,
	bp_diastolic,
	o2_saturation,
	muac_mm,
	chief_complaint,
	index_asc,
	index_desc
from temp_vitals; 
