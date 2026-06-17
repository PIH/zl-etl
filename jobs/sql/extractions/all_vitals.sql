SET sql_safe_updates = 0;
set @partition = '${partitionNum}';

SET @vitals_encounter = (SELECT encounter_type_id FROM encounter_type WHERE uuid = '4fb47712-34a6-40d2-8ed3-e153abbd25b7');

DROP TEMPORARY TABLE IF EXISTS temp_vitals;
CREATE TEMPORARY TABLE temp_vitals
(
    all_vitals_id		int(11) PRIMARY KEY AUTO_INCREMENT,
	patient_id			int(11),
	emr_id          	VARCHAR(25),
    encounter_id		int(11),
    visit_id			int(11),
    encounter_location_id	int(11),
    encounter_location	varchar(255),
    encounter_datetime	datetime,
    encounter_provider_id	int(11),
    encounter_provider 	VARCHAR(255),
    date_entered		datetime,
    creator				int(11),
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
   
insert into temp_vitals(patient_id, encounter_id, visit_id, encounter_datetime, date_entered, creator, encounter_location_id)   
select e.patient_id,  e.encounter_id, e.visit_id, e.encounter_datetime, e.date_created, e.creator, e.location_id  from encounter e
where e.encounter_type = @vitals_encounter
and e.voided = 0;

create index temp_vitals_ei on temp_vitals(encounter_id);

-- emr_id
DROP TEMPORARY TABLE IF EXISTS temp_identifiers;
CREATE TEMPORARY TABLE temp_identifiers
(
patient_id						INT(11),
emr_id							VARCHAR(25)
);

INSERT INTO temp_identifiers(patient_id)
select distinct patient_id from temp_vitals;

update temp_identifiers t set emr_id  = zlemr(patient_id);	

CREATE INDEX temp_identifiers_p ON temp_identifiers (patient_id);

update temp_vitals tv 
inner join temp_identifiers ti on ti.patient_id = tv.patient_id
set tv.emr_id = ti.emr_id;

-- provider name
update temp_vitals tv 
inner join encounter_provider ep on ep.encounter_id  = tv.encounter_id and ep.voided = 0
set tv.encounter_provider_id = ep.encounter_provider_id ;

DROP TEMPORARY TABLE IF EXISTS temp_providers;
CREATE TEMPORARY TABLE temp_providers
(
provider_id						INT(11),
provider_name					VARCHAR(255)
);

INSERT INTO temp_providers(provider_id)
select distinct provider_id from encounter_provider ep
inner join temp_vitals tv on ep.encounter_id = tv.encounter_id
where ep.voided = 0;

update temp_providers t set provider_name  = username(provider_id);	

CREATE INDEX temp_providers_p ON temp_providers (provider_id);

update temp_vitals tv 
inner join temp_providers tp on tp.provider_id = tv.encounter_provider_id
set tv.encounter_provider = tp.provider_name;

-- location name
DROP TEMPORARY TABLE IF EXISTS temp_locations;
CREATE TEMPORARY TABLE temp_locations
(
location_id						INT(11),
location_name					VARCHAR(255)
);

INSERT INTO temp_locations(location_id)
select distinct encounter_location_id from temp_vitals tv;

update temp_locations t set location_name  = location_name(location_id);	

CREATE INDEX temp_locations_l ON temp_locations (location_id);

update temp_vitals tv 
inner join temp_locations tl on tl.location_id = tv.encounter_location_id
set tv.encounter_location = tl.location_name;

-- user entered
DROP TEMPORARY TABLE IF EXISTS temp_creators;
CREATE TEMPORARY TABLE temp_creators
(
creator						INT(11),
user_entered				VARCHAR(255)
);

INSERT INTO temp_creators(creator)
select distinct creator from temp_vitals tv;

update temp_creators t set user_entered  = username(creator);	

CREATE INDEX temp_creators_c ON temp_creators (creator);

update temp_vitals tv 
inner join temp_creators tc on tc.creator = tv.creator
set tv.user_entered = tc.user_entered;

-- ---------------------------
set @weight =  CONCEPT_FROM_MAPPING('PIH', '5089');
set @height =  CONCEPT_FROM_MAPPING('PIH', '5090');
set @temp =  CONCEPT_FROM_MAPPING('PIH', '5088');
set @hr =  CONCEPT_FROM_MAPPING('PIH', '5087');
set @rr =  CONCEPT_FROM_MAPPING('PIH', '5242');
set @bps =  CONCEPT_FROM_MAPPING('PIH', '5085');
set @bpd =  CONCEPT_FROM_MAPPING('PIH', '5086');
set @o2 =  CONCEPT_FROM_MAPPING('PIH', '5092');
set @muac =  CONCEPT_FROM_MAPPING('PIH', '7956');
set @cc =  CONCEPT_FROM_MAPPING('PIH', '10137');

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.comments 
from obs o
inner join temp_vitals t on t.encounter_id = o.encounter_id
where o.voided = 0
and o.concept_id in (
@height,
@weight,
@temp,
@hr,
@rr,
@bps,
@bpd,
@o2,
@muac,
@cc);

create index temp_obs_concept_id on temp_obs(encounter_id,concept_id);
   
-- weight   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id =@weight
SET weight = o.value_numeric;

-- height   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = @height
SET height = o.value_numeric;

-- temp   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = @temp
SET temperature = o.value_numeric;

-- hr   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = @hr
SET heart_rate = o.value_numeric;

-- respiratory_rate   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = @rr
SET respiratory_rate = o.value_numeric;

-- bp_systolic   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = @bps 
SET bp_systolic = o.value_numeric;

-- bp_diastolic   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = @bpd
SET bp_diastolic = o.value_numeric;

-- o2_saturation   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = @o2
SET o2_saturation = o.value_numeric;

-- muac   
UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = @muac
SET muac_mm = o.value_numeric;


-- chief_complaint   

UPDATE temp_vitals t
inner join temp_obs o ON t.encounter_id = o.encounter_id
        AND o.concept_id = @cc 
SET chief_complaint = o.value_text;

-- The indexes are calculated using the ecnounter_date
/*
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
*/
select 
	all_vitals_id,
	emr_id ,
	concat(@partition,'-',encounter_id),
	concat(@partition,'-',visit_id),
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
