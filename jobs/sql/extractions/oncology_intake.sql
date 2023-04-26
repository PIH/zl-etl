SELECT encounter_type_id  INTO @enc_type FROM encounter_type et WHERE uuid='a936ae01-6d10-455d-befc-b2d1828dad04';
SET @partition = '${partitionNum}';

DROP TABLE IF EXISTS oncology_intake;
CREATE TEMPORARY TABLE oncology_intake (
emr_id varchar(50),
encounter_id int,
encounter_datetime datetime,
encounter_location varchar(100),
date_entered date,
user_entered varchar(30),
encounter_provider varchar(30),
smoking varchar(30),
alcohol varchar(30),
drugs varchar(30),
hiv_test boolean,
hiv_test_date date,
diabetes boolean,
type_1_diabetes boolean,
type_2_diabetes boolean,
hypertension boolean,
asthma boolean,
referal varchar(500),
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

INSERT INTO oncology_intake(emr_id,encounter_id,encounter_datetime,encounter_location,date_entered,user_entered,encounter_provider)
SELECT 
zlemr(patient_id),
encounter_id,
encounter_datetime ,
encounter_location_name(encounter_id),
date_created,
encounter_creator(encounter_id),
provider(encounter_id)
FROM encounter e 
WHERE encounter_type = @enc_type
AND voided = 0;

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

-- ecog_status
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
-- AND o.concept_id = concept_from_mapping('PIH','10358')
AND o.voided =0
SET ecog_status = obs_from_group_id_value_numeric(1594231, 'PIH','10358');

-- ecog_date
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.voided =0
SET ecog_date = obs_from_group_id_value_datetime(1594231,'PIH','11780');

-- ecog_not_evaluated
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.voided =0
SET ecog_evaluated = obs_from_group_id_value_coded(1594231,'PIH','11778','en');



-- zldsi_status
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
-- AND o.concept_id = concept_from_mapping('PIH','10584')
AND o.voided =0
SET zldsi_status =  obs_from_group_id_value_numeric(1594235, 'PIH','10584');


-- zldsi_date
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.voided =0
SET zldsi_date = obs_from_group_id_value_datetime(1594235,'PIH','11780');

-- ecog_not_evaluated
UPDATE oncology_intake oi INNER JOIN obs o 
ON o.encounter_id =oi.encounter_id
AND o.voided =0
SET zldsi_evaluated = obs_from_group_id_value_coded(1594235,'PIH','11778','en');

SELECT 
CONCAT(@partition,'-',emr_id) "emr_id",
encounter_id ,
encounter_datetime ,
encounter_location ,
date_entered ,
user_entered ,
encounter_provider ,
smoking ,
alcohol ,
drugs ,
hiv_test ,
hiv_test_date ,
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