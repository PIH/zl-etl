SELECT encounter_type_id  INTO @enc_type FROM encounter_type et WHERE uuid='a936ae01-6d10-455d-befc-b2d1828dad04';
SET @partition = '${partitionNum}';

DROP TABLE IF EXISTS oncology_intake;
CREATE TEMPORARY TABLE oncology_intake (
patient_id int,
emr_id varchar(50),
encounter_id int,
encounter_datetime datetime,
encounter_location varchar(100),
facility varchar(255),
visit_id int,
visit_location varchar(100),
date_entered date,
user_entered varchar(30),
encounter_provider varchar(30),
smoking varchar(30),
alcohol varchar(30),
drugs varchar(30),
hiv_test boolean,
hiv_test_date date,
hiv_test_result varchar(50),
diabetes boolean,
type_1_diabetes boolean,
type_2_diabetes boolean,
hypertension boolean,
asthma boolean,
referal varchar(500),
ecog_obs_group_id int, 
zldsi_obs_group_id int, 
ecog_status int,
ecog_date datetime,
ecog_evaluated varchar(50),
zldsi_status int,
zldsi_date datetime,
zldsi_evaluated varchar(50),
psych_referral boolean,
disposition varchar(100),
comment text,
next_visit_date date);

INSERT INTO oncology_intake(patient_id,emr_id,encounter_id,encounter_datetime,encounter_location,visit_id,date_entered,user_entered,encounter_provider)
SELECT
patient_id,
zlemr(patient_id),
encounter_id,
encounter_datetime ,
encounter_location_name(encounter_id),
visit_id,
date_created,
encounter_creator(encounter_id),
provider(encounter_id)
FROM encounter e
WHERE encounter_type = @enc_type
AND voided = 0;

-- Sets facility as the Visit Location ancestor of the encounter location (fallback for rows with no visit).
UPDATE oncology_intake t
INNER JOIN encounter e ON e.encounter_id = t.encounter_id
INNER JOIN locations l ON l.location_id = e.location_id
SET t.facility = l.facility;

-- Sets visit_location from the visit's location.
-- Overrides facility with visit_location when a visit exists, since visits are
-- associated directly with the Visit Location — more accurate than the ancestor walk.
UPDATE oncology_intake t
INNER JOIN visit v ON v.visit_id = t.visit_id
INNER JOIN locations l ON l.location_id = v.location_id
SET t.visit_location = l.location_name,
    t.facility = l.location_name;

-- Falls back to 'Unknown Location' if facility is still NULL after both location lookups.
UPDATE oncology_intake t
INNER JOIN location loc ON loc.uuid = '8d6c993e-c2cc-11de-8d13-0010c6dffd0f'
SET t.facility = loc.name
WHERE t.facility IS NULL;

-- Type 1
UPDATE oncology_intake SET type_1_diabetes = answer_exists_in_encounter(encounter_id, 'PIH','10140', 'PIH', '6691');

-- Type 2
UPDATE oncology_intake SET type_2_diabetes = answer_exists_in_encounter(encounter_id, 'PIH','10140', 'PIH', '6692');

-- diabetes
UPDATE oncology_intake SET diabetes = answer_exists_in_encounter(encounter_id, 'PIH','10140', 'PIH', '3720');

-- hypertension
UPDATE oncology_intake SET hypertension = answer_exists_in_encounter(encounter_id, 'PIH','10140', 'PIH', '903');

-- asthma
UPDATE oncology_intake SET asthma = answer_exists_in_encounter(encounter_id, 'PIH','10140', 'PIH', '5');

-- asthma
UPDATE oncology_intake SET referal = obs_value_coded_list(encounter_id,'PIH','7454','en');

-- psych_referral
-- UPDATE oncology_intake oi INNER JOIN obs o 
-- ON o.encounter_id =oi.encounter_id
-- AND o.concept_id =  concept_from_mapping('PIH','5490')
-- AND o.voided =0
-- SET psych_referral= CASE WHEN upper(value_coded_name(o.obs_id,'en'))='YES' THEN TRUE ELSE FALSE END ;

UPDATE oncology_intake SET psych_referral= obs_value_coded_as_boolean(encounter_id,'PIH','5490');

-- smoking
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.concept_id = concept_from_mapping('PIH','2545')
AND o.voided =0
SET smoking= value_coded_name(o.obs_id,'en');

-- alcohol
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.concept_id = concept_from_mapping('PIH','1552')
AND o.voided =0
SET alcohol= value_coded_name(o.obs_id,'en');

-- drugs
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.concept_id = concept_from_mapping('PIH','2546')
AND o.voided =0
SET drugs= value_coded_name(o.obs_id,'en');

-- hiv_test_performed
-- UPDATE oncology_intake oi INNER JOIN obs o 
-- ON o.encounter_id =oi.encounter_id
-- AND o.concept_id =  concept_from_mapping('PIH','11672')
-- AND o.voided =0
-- SET hiv_test= CASE WHEN upper(value_coded_name(o.obs_id,'en'))='YES' THEN TRUE ELSE FALSE END ;
UPDATE oncology_intake SET hiv_test= obs_value_coded_as_boolean(encounter_id,'PIH','11672');


-- hiv_test_date
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.concept_id = concept_from_mapping('PIH','1837')
AND o.voided =0
SET hiv_test_date= cast(value_datetime AS date) ;

-- hiv_test_result
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.concept_id = concept_from_mapping('PIH','2169')
AND o.voided =0
SET hiv_test_result= value_coded_name(obs_id,'en') ;



-- disposition
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.concept_id = concept_from_mapping('PIH','8620')
AND o.voided =0
SET disposition= value_coded_name(obs_id,'en') ;


-- comment
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.concept_id =  concept_from_mapping('PIH','10578')
AND o.voided =0
SET comment= value_text ;


-- return_visit_date
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.concept_id = concept_from_mapping('PIH','5096')
AND o.voided =0
SET next_visit_date= cast(value_datetime AS date);

-- SELECT concept_from_mapping('PIH','10584') -- zldsi 2995
-- SELECT concept_from_mapping('PIH','10358') -- ecog 2513

UPDATE oncology_intake tgt
SET ecog_obs_group_id = (
	SELECT obs_group_id
	FROM obs 
	WHERE encounter_id = tgt.encounter_id
	AND patient_id = tgt.patient_id
	AND concept_id=concept_from_mapping('PIH','10358')
	ORDER BY obs_id
	LIMIT 1
);

-- ecog_status
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
-- AND o.concept_id = concept_from_mapping('PIH','10358')
AND o.voided =0
SET ecog_status = obs_from_group_id_value_numeric(ecog_obs_group_id, 'PIH','10358');


-- ecog_date
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.voided =0
SET ecog_date = obs_from_group_id_value_datetime(ecog_obs_group_id,'PIH','11780');

-- ecog_not_evaluated
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.voided =0
SET ecog_evaluated = obs_from_group_id_value_coded(ecog_obs_group_id,'PIH','11778','en');


UPDATE oncology_intake tgt
SET zldsi_obs_group_id = (
	SELECT obs_group_id
	FROM obs 
	WHERE encounter_id = tgt.encounter_id
	AND patient_id = tgt.patient_id
	AND concept_id=concept_from_mapping('PIH','10584')
	ORDER BY obs_id
	LIMIT 1
);

-- zldsi_status
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
-- AND o.concept_id = concept_from_mapping('PIH','10584')
AND o.voided =0
SET zldsi_status =  obs_from_group_id_value_numeric(zldsi_obs_group_id, 'PIH','10584');


-- zldsi_date
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.voided =0
SET zldsi_date = obs_from_group_id_value_datetime(zldsi_obs_group_id,'PIH','11780');

-- ecog_not_evaluated
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.voided =0
SET zldsi_evaluated = obs_from_group_id_value_coded(zldsi_obs_group_id,'PIH','11778','en');

SELECT
emr_id,
CONCAT(@partition,'-',encounter_id) "encounter_id",
encounter_datetime ,
encounter_location ,
facility ,
CONCAT(@partition,'-',visit_id) "visit_id",
visit_location,
date_entered ,
user_entered ,
encounter_provider ,
smoking ,
alcohol ,
drugs ,
hiv_test ,
hiv_test_date ,
hiv_test_result,
diabetes ,
type_1_diabetes ,
type_2_diabetes ,
hypertension ,
asthma ,
referal,
ecog_status ,
ecog_date ,
ecog_evaluated ,
zldsi_status ,
zldsi_date ,
zldsi_evaluated ,
psych_referral ,
disposition ,
comment ,
next_visit_date 
FROM oncology_intake;