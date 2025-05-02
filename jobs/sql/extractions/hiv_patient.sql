SET sql_safe_updates = 0;

SELECT patient_identifier_type_id INTO @zl_emr_id FROM patient_identifier_type WHERE uuid = 'a541af1e-105c-40bf-b345-ba1fd6a59b85';
SELECT patient_identifier_type_id INTO @dossier FROM patient_identifier_type WHERE uuid = '3B954DB1-0D41-498E-A3F9-1E20CCC47323';
SELECT patient_identifier_type_id INTO @hiv_id FROM patient_identifier_type WHERE uuid = '139766e8-15f5-102d-96e4-000c29c2a5d7';

SET @hiv_program_id = (SELECT program_id FROM program WHERE retired = 0 AND uuid = 'b1cb1fc1-5190-4f7a-af08-48870975dafc');
SET @ovc_baseline_encounter_type = ENCOUNTER_TYPE('OVC Intake');
SET @socio_economics_encounter_type = ENCOUNTER_TYPE('Socio-economics');
SET @hiv_initial_encounter_type = ENCOUNTER_TYPE('HIV Intake');
SET @hiv_followup_encounter_type = ENCOUNTER_TYPE('HIV Followup');
SET @hiv_dispensing_encounter = ENCOUNTER_TYPE('HIV drug dispensing');
SET @mothers_first_name = (SELECT person_attribute_type_id FROM person_attribute_type p WHERE p.name = 'First Name of Mother');
SET @telephone_number = (SELECT person_attribute_type_id FROM person_attribute_type p WHERE p.name = 'Telephone Number');
SET @transfer_to_zl=concept_from_mapping('PIH','13275');

DROP TEMPORARY TABLE IF EXISTS temp_patient;
CREATE TEMPORARY TABLE temp_patient
(
    patient_id                  INT(11),
    patient_program_id			INT(11),
    zl_emr_id                   VARCHAR(255),
    hivemr_v1_id                VARCHAR(255),
    hiv_dossier_id              VARCHAR(255),
    given_name                  VARCHAR(50),
    family_name                 VARCHAR(50),
    nickname					VARCHAR(50),
    gender                      VARCHAR(50),
    birthdate                   DATE,
    birthplace_commune          VARCHAR(100),
    birthplace_sc               VARCHAR(100),
    birthplace_locality         VARCHAR(100),
    birthplace_province         VARCHAR(100),
    patient_registration_date	DATE,
    user_entered	        VARCHAR(100),
    initial_enrollment_location VARCHAR(100),
    program_location_id         INT,
    latest_enrollment_location VARCHAR(100),
    dead                        VARCHAR(1),
    death_date                  DATE,
    cause_of_death              VARCHAR(255),
    cause_of_death_non_coded    VARCHAR(255),
    patient_msm                 VARCHAR(11),
    patient_sw                  VARCHAR(11),
    patient_pris                VARCHAR(11),
    patient_trans               VARCHAR(11),
    patient_idu                 VARCHAR(11),
    parent_firstname            VARCHAR(255),
    parent_lastname             VARCHAR(255),
    parent_relationship         VARCHAR(50),
    marital_status              VARCHAR(60),
    occupation                  VARCHAR(100),
    mothers_first_name          VARCHAR(50),
    telephone_number            VARCHAR(100),
    address                     TEXT,
    department                  VARCHAR(100),
    commune                     VARCHAR(100),
    section_communal            VARCHAR(100),
    locality                    VARCHAR(100),
    street_landmark             TEXT,
    age                         DOUBLE,
    partner_hiv_status			VARCHAR(255),
	art_dispensing_start_date	DATETIME,
	first_art_dispensing_regimen VARCHAR(1000),
	art_order_start_date		DATETIME,
	months_on_art				INT,
	initial_art_regimen_order	VARCHAR(1000),
	initial_art_regimen			VARCHAR(1000),
	art_regimen					VARCHAR(1000),
	art_start_date				DATETIME,
	biometrics_code             VARCHAR(50),
    biometrics_collected        BIT,    
    latest_biometrics_collection_date     DATETIME,
    biometrics_collector VARCHAR(100),
    transfer_from_location VARCHAR(100),
    transfer_from_date DATE
);

CREATE INDEX temp_patient_patient_id ON temp_patient (patient_id);

INSERT INTO temp_patient (patient_id)
SELECT patient_id FROM patient WHERE voided=0;

## Delete test patients
DELETE FROM temp_patient WHERE
patient_id IN (
               SELECT
                      a.person_id
                      FROM person_attribute a
                      INNER JOIN person_attribute_type t ON a.person_attribute_type_id = t.person_attribute_type_id
                      AND a.value = 'true' AND t.name = 'Test Patient'
               );

-- ZL EMR ID
UPDATE temp_patient t
set zl_emr_id = zlemr(t.patient_id);             
              
-- HIV EMR V1
UPDATE temp_patient t
INNER JOIN
   (SELECT patient_id, GROUP_CONCAT(identifier) 'ids'
    FROM patient_identifier pid
    WHERE pid.voided = 0
    AND pid.identifier_type = @hiv_id
    GROUP BY patient_id
   ) ids ON ids.patient_id = t.patient_id
SET t.hivemr_v1_id = ids.ids;    

-- DOSSIER ID
UPDATE temp_patient t
INNER JOIN
   (SELECT patient_id, GROUP_CONCAT(identifier) 'ids'
    FROM patient_identifier pid
    WHERE pid.voided = 0
    AND pid.identifier_type = @dossier
    GROUP BY patient_id
   ) ids ON ids.patient_id = t.patient_id
SET t.hiv_dossier_id = ids.ids;    

UPDATE temp_patient
SET gender = GENDER(patient_id),
    birthdate = BIRTHDATE(patient_id),
    given_name = PERSON_GIVEN_NAME(patient_id),
    family_name = PERSON_FAMILY_NAME(patient_id),
	nickname = PERSON_MIDDLE_NAME(patient_id);

UPDATE temp_patient t set department = person_address_state_province(patient_id);
UPDATE temp_patient t set commune = person_address_city_village(patient_id);
UPDATE temp_patient t set section_communal = person_address_three(patient_id);
UPDATE temp_patient t set locality = person_address_one(patient_id);
-- note that "street landmark" and "address" are the same data.  Note sure what downstream processes use it, so I left it like that
UPDATE temp_patient t set street_landmark = person_address_two(patient_id);
UPDATE temp_patient t set address = person_address_two(patient_id);

update temp_patient t set age =  ROUND(DATEDIFF(NOW(),t.birthdate) / 365.25 , 1);

## locations
-- initial_enrollment_location : The registration location for the patient
-- latest_enrollment_location:  The current location of the hiv program
UPDATE temp_patient t SET initial_enrollment_location = initialProgramLocation(t.patient_id, @hiv_program_id);
UPDATE temp_patient t set patient_program_id = mostRecentPatientProgramId(t.patient_id, @hiv_program_id);
UPDATE temp_patient t SET program_location_id = PROGRAMLOCATIONID(t.patient_program_id);
UPDATE temp_patient t SET latest_enrollment_location = currentProgramLocation(t.patient_id, @hiv_program_id);

## birth address
UPDATE temp_patient t JOIN obs o ON t.patient_id = o.person_id AND o.voided = 0 AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'City Village')
SET birthplace_commune = o.value_text;
UPDATE temp_patient t JOIN obs o ON t.patient_id = o.person_id AND o.voided = 0 AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'Address3')
SET birthplace_sc = o.value_text;
UPDATE temp_patient t JOIN obs o ON t.patient_id = o.person_id AND o.voided = 0 AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'Address1')
SET birthplace_locality = o.value_text;	
UPDATE temp_patient t JOIN obs o ON t.patient_id = o.person_id AND o.voided = 0 AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'State Province')
SET birthplace_province = o.value_text;

select encounter_type_id into @regEncId from encounter_type where uuid = '873f968a-73a8-4f9c-ac78-9f4778b751b6';
update temp_patient t 
set patient_registration_date =
	(select min(date(encounter_datetime)) from encounter e where e.patient_id = t.patient_id and e.voided = 0 and e.encounter_type = @regEncId limit 1);


update temp_patient t 
set user_entered =
	(select person_name_of_user(e.creator) from encounter e where e.patient_id = t.patient_id and e.voided = 0 and e.encounter_type = @regEncId limit 1);


set @civil_status = CONCEPT_FROM_MAPPING('PIH','CIVIL STATUS');
set @occupation = CONCEPT_FROM_MAPPING('PIH','Occupation');

UPDATE temp_patient t JOIN obs m ON t.patient_id = m.person_id AND 
m.voided = 0 AND concept_id = @civil_status 
SET marital_status = CONCEPT_NAME(value_coded, 'en');

UPDATE temp_patient t JOIN obs m ON t.patient_id = m.person_id AND 
m.voided = 0 AND concept_id = @occupation
SET occupation = CONCEPT_NAME(value_coded, 'en');

UPDATE temp_patient t JOIN person_attribute m ON t.patient_id = m.person_id AND 
m.voided = 0 AND  m.person_attribute_type_id = @mothers_first_name
SET mothers_first_name = m.value;

UPDATE temp_patient t JOIN person_attribute m ON t.patient_id = m.person_id AND 
m.voided = 0 AND  m.person_attribute_type_id = @telephone_number
SET telephone_number = m.value;

# key populations
DROP TEMPORARY TABLE IF EXISTS temp_key_popn_encounter;
CREATE TEMPORARY TABLE temp_key_popn_encounter
(
patient_id      INT,
encounter_id    INT,
encounter_date  DATE,
concept_id      INT,
value_coded     INT
);

CREATE INDEX temp_key_popn_encounter_patient_id ON temp_key_popn_encounter (patient_id);
CREATE INDEX temp_key_popn_encounter_encounter_id ON temp_key_popn_encounter (encounter_id);
CREATE INDEX temp_key_popn_encounter_concept_id ON temp_key_popn_encounter (concept_id);
CREATE INDEX temp_key_popn_encounter_value_coded ON temp_key_popn_encounter (value_coded);

INSERT INTO  temp_key_popn_encounter (patient_id, encounter_id, encounter_date, concept_id, value_coded)
SELECT patient_id, e.encounter_id, DATE(encounter_datetime), concept_id, value_coded
FROM encounter e
INNER JOIN obs o
	ON e.voided = 0
	AND o.voided = 0
	AND encounter_type = ENCOUNTER_TYPE('HIV Intake')
    AND o.concept_id IN (CONCEPT_FROM_MAPPING("CIEL", "160578"), CONCEPT_FROM_MAPPING("CIEL","160579"), CONCEPT_FROM_MAPPING("CIEL","156761"), CONCEPT_FROM_MAPPING("PIH","11561"), CONCEPT_FROM_MAPPING("CIEL","105"))
	AND e.encounter_id = o.encounter_id;

## create a staging table to hold the maximum encounter_dates per patient
##
DROP TEMPORARY TABLE IF EXISTS temp_stage_key_popn_msm;
CREATE TEMPORARY TABLE temp_stage_key_popn_msm
(
patient_id      INT,
encounter_date  DATE,
concept_id      INT,
patient_msm     VARCHAR(11)
);

CREATE INDEX temp_stage_key_popn_msm_patient_id ON temp_stage_key_popn_msm (patient_id);
CREATE INDEX temp_stage_key_popn_msm_concept_id ON temp_stage_key_popn_msm (concept_id);

INSERT INTO temp_stage_key_popn_msm(patient_id, encounter_date, concept_id)
SELECT patient_id, MAX(encounter_date), concept_id FROM temp_key_popn_encounter WHERE concept_id = CONCEPT_FROM_MAPPING("CIEL", "160578") GROUP BY patient_id;

UPDATE temp_stage_key_popn_msm msm INNER JOIN temp_key_popn_encounter tkpe ON msm.patient_id = tkpe.patient_id AND msm.encounter_date = tkpe.encounter_date AND tkpe.concept_id = CONCEPT_FROM_MAPPING("CIEL", "160578")
SET patient_msm = CONCEPT_NAME(value_coded, 'en');

##
DROP TEMPORARY TABLE IF EXISTS temp_stage_key_popn_sw;
CREATE TEMPORARY TABLE temp_stage_key_popn_sw
(
patient_id      INT,
encounter_date  DATE,
concept_id      INT,
patient_sw      VARCHAR(11)
);

CREATE INDEX temp_stage_key_popn_sw_patient_id ON temp_stage_key_popn_sw (patient_id);
CREATE INDEX temp_stage_key_popn_sw_concept_id ON temp_stage_key_popn_sw (concept_id);

INSERT INTO temp_stage_key_popn_sw(patient_id, encounter_date, concept_id)
SELECT patient_id, MAX(encounter_date), concept_id FROM temp_key_popn_encounter WHERE concept_id = CONCEPT_FROM_MAPPING("CIEL","160579") GROUP BY patient_id;

UPDATE temp_stage_key_popn_sw sw INNER JOIN temp_key_popn_encounter tkpe ON sw.patient_id = tkpe.patient_id AND sw.encounter_date = tkpe.encounter_date AND tkpe.concept_id = CONCEPT_FROM_MAPPING("CIEL","160579")
SET patient_sw = CONCEPT_NAME(value_coded, 'en');

##
DROP TEMPORARY TABLE IF EXISTS temp_stage_key_popn_pris;
CREATE TEMPORARY TABLE temp_stage_key_popn_pris
(
patient_id      INT,
encounter_date  DATE,
concept_id      INT,
patient_pris    VARCHAR(11)
);

CREATE INDEX temp_stage_key_popn_pris_patient_id ON temp_stage_key_popn_pris (patient_id);
CREATE INDEX temp_stage_key_popn_pris_concept_id ON temp_stage_key_popn_pris (concept_id);

INSERT INTO temp_stage_key_popn_pris(patient_id, encounter_date, concept_id)
SELECT patient_id, MAX(encounter_date), concept_id FROM temp_key_popn_encounter WHERE concept_id = CONCEPT_FROM_MAPPING("CIEL","156761") GROUP BY patient_id;

UPDATE temp_stage_key_popn_pris pris INNER JOIN temp_key_popn_encounter tkpe ON pris.patient_id = tkpe.patient_id AND pris.encounter_date = tkpe.encounter_date AND tkpe.concept_id = CONCEPT_FROM_MAPPING("CIEL","156761")
SET patient_pris = CONCEPT_NAME(value_coded, 'en');

####
DROP TEMPORARY TABLE IF EXISTS temp_stage_key_popn_trans;
CREATE TEMPORARY TABLE temp_stage_key_popn_trans
(
patient_id      INT,
encounter_date  DATE,
concept_id      INT,
patient_trans   VARCHAR(11)
);

CREATE INDEX temp_stage_key_popn_trans_patient_id ON temp_stage_key_popn_trans (patient_id);
CREATE INDEX temp_stage_key_popn_trans_concept_id ON temp_stage_key_popn_trans (concept_id);

INSERT INTO temp_stage_key_popn_trans(patient_id, encounter_date, concept_id)
SELECT patient_id, MAX(encounter_date), concept_id FROM temp_key_popn_encounter WHERE concept_id = CONCEPT_FROM_MAPPING("PIH","11561") GROUP BY patient_id;

UPDATE temp_stage_key_popn_trans trans INNER JOIN temp_key_popn_encounter tkpe ON trans.patient_id = tkpe.patient_id AND trans.encounter_date = tkpe.encounter_date AND tkpe.concept_id = CONCEPT_FROM_MAPPING("PIH","11561")
SET patient_trans = CONCEPT_NAME(value_coded, 'en');

###
DROP TEMPORARY TABLE IF EXISTS temp_stage_key_popn_iv;
CREATE TEMPORARY TABLE temp_stage_key_popn_iv
(
patient_id      INT,
encounter_date  DATE,
concept_id      INT,
patient_idu     VARCHAR(11)
);

CREATE INDEX temp_stage_key_popn_iv_patient_id ON temp_stage_key_popn_iv (patient_id);
CREATE INDEX temp_stage_key_popn_iv_concept_id ON temp_stage_key_popn_iv (concept_id);

INSERT INTO temp_stage_key_popn_iv(patient_id, encounter_date, concept_id)
SELECT patient_id, MAX(encounter_date), concept_id FROM temp_key_popn_encounter WHERE concept_id = CONCEPT_FROM_MAPPING("CIEL", "105") GROUP BY patient_id;

UPDATE temp_stage_key_popn_iv iv INNER JOIN temp_key_popn_encounter tkpe ON iv.patient_id = tkpe.patient_id AND iv.encounter_date = tkpe.encounter_date AND tkpe.concept_id = CONCEPT_FROM_MAPPING("CIEL", "105")
SET patient_idu = CONCEPT_NAME(value_coded, 'en');

## key population final table with the latest data
DROP TEMPORARY TABLE IF EXISTS temp_key_popn;
CREATE TEMPORARY TABLE temp_key_popn(
    patient_id      INT,
    patient_msm     VARCHAR(11),
    patient_sw      VARCHAR(11),
    patient_pris    VARCHAR(11),
    patient_trans   VARCHAR(11),
    patient_idu     VARCHAR(11)
);

CREATE INDEX temp_key_popn_patient_id ON temp_key_popn (patient_id);

INSERT INTO temp_key_popn (patient_id , patient_msm, patient_sw, patient_pris, patient_trans, patient_idu )
SELECT DISTINCT(tkpe.patient_id), patient_msm, patient_sw, patient_pris, patient_trans, patient_idu
FROM temp_key_popn_encounter tkpe
LEFT JOIN temp_stage_key_popn_msm 	msm ON tkpe.patient_id = msm.patient_id
LEFT JOIN temp_stage_key_popn_sw 	sw ON tkpe.patient_id = sw.patient_id
LEFT JOIN temp_stage_key_popn_pris 	pris ON tkpe.patient_id = pris.patient_id
LEFT JOIN temp_stage_key_popn_trans trans ON tkpe.patient_id = trans.patient_id
LEFT JOIN temp_stage_key_popn_iv iv ON tkpe.patient_id = iv.patient_id;

UPDATE temp_patient tp INNER JOIN temp_key_popn tkp ON tp.patient_id = tkp.patient_id
SET tp.patient_msm = tkp.patient_msm,
	tp.patient_sw = tkp.patient_sw,
	tp.patient_pris = tkp.patient_pris,
	tp.patient_trans = tkp.patient_trans,
	tp.patient_idu = tkp.patient_idu;

# Dead
UPDATE temp_patient tp INNER JOIN person p ON tp.patient_id = p.person_id
SET tp.dead = IF(p.dead = 1, "Y", NULL);

# Date of death
UPDATE temp_patient tp INNER JOIN person p ON tp.patient_id = p.person_id AND p.dead = 1
SET tp.death_date = DATE(p.death_date);

# Cause of death
UPDATE temp_patient tp INNER JOIN person p ON tp.patient_id = p.person_id AND p.dead = 1
SET tp.cause_of_death = CONCEPT_NAME(p.cause_of_death, 'en');

# Cause of death non coded
UPDATE temp_patient tp INNER JOIN person p ON tp.patient_id = p.person_id AND p.dead = 1
SET tp.cause_of_death_non_coded = p.cause_of_death_non_coded;

### ovc parent
DROP TEMPORARY TABLE IF EXISTS temp_ovc_parent;
CREATE TEMPORARY TABLE temp_ovc_parent(
    patient_id                  INT,
    encounter_id                INT,
    contact_construct_obs_id    INT,
    parent_firstname            VARCHAR(255),
    parent_lastname             VARCHAR(255),
    parent_relationship         VARCHAR(50)
);

CREATE INDEX temp_ovc_parent_patient_id ON temp_ovc_parent (patient_id);
CREATE INDEX temp_ovc_parent_encounter_id ON temp_ovc_parent (encounter_id);

INSERT INTO temp_ovc_parent(patient_id, contact_construct_obs_id) 
SELECT person_id, MAX(obs_id) FROM obs WHERE voided = 0
AND concept_id = CONCEPT_FROM_MAPPING('PIH', 'Contact construct') 
AND encounter_id IN (SELECT encounter_id FROM encounter WHERE voided = 0 AND encounter_type = @ovc_baseline_encounter_type)
GROUP BY person_id;

UPDATE temp_ovc_parent tp JOIN obs o ON obs_id = contact_construct_obs_id
SET tp.encounter_id = o.encounter_id;

UPDATE temp_ovc_parent ovc JOIN obs o ON ovc.encounter_id = o.encounter_id AND o.obs_group_id IN (contact_construct_obs_id) 
AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'FIRST NAME')
SET parent_firstname = value_text;

UPDATE temp_ovc_parent ovc JOIN obs o ON ovc.encounter_id = o.encounter_id AND o.obs_group_id IN (contact_construct_obs_id) 
AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'LAST NAME')
SET parent_lastname = value_text;

UPDATE temp_ovc_parent ovc JOIN obs o ON ovc.encounter_id = o.encounter_id AND o.obs_group_id IN (contact_construct_obs_id)
AND o.concept_id = CONCEPT_FROM_MAPPING('PIH', 'RELATIONSHIP OF RELATIVE TO PATIENT')
SET parent_relationship = CONCEPT_NAME(value_coded, 'en');

UPDATE temp_patient tp JOIN temp_ovc_parent o ON tp.patient_id = o.patient_id
SET
    tp.parent_firstname = o.parent_firstname,
    tp.parent_lastname = o.parent_lastname,
    tp.parent_relationship = o.parent_relationship;

DROP TEMPORARY TABLE IF EXISTS temp_socio_economics;
CREATE TEMPORARY TABLE temp_socio_economics(
	patient_id INT,
	emr_id VARCHAR(50),
	encounter_id INT,
	socio_people_in_house INT,
	socio_rooms_in_house INT,
	socio_roof_type VARCHAR(20),
	socio_floor_type VARCHAR(20),
	socio_has_latrine VARCHAR(20),
	socio_has_radio VARCHAR(20),
	socio_years_of_education VARCHAR(50),
	socio_transport_method VARCHAR(50),
	socio_transport_time VARCHAR(50),
	socio_transport_walking_time VARCHAR(50)
);

CREATE INDEX temp_socio_economics_patient_id ON temp_socio_economics (patient_id);
CREATE INDEX temp_socio_economics_encounter_id ON temp_socio_economics (encounter_id);

-- in cases where there are more than one socio economic form
-- return latest
INSERT INTO temp_socio_economics (patient_id, encounter_id)
SELECT patient_id, MAX(encounter_id) FROM encounter WHERE encounter_id IN
(SELECT encounter_id FROM encounter WHERE voided = 0 AND encounter_type = @socio_economics_encounter_type) 
AND voided = 0;

UPDATE temp_socio_economics t SET emr_id = PATIENT_IDENTIFIER(patient_id, METADATA_UUID('org.openmrs.module.emrapi', 'emr.primaryIdentifierType'));
UPDATE temp_socio_economics t SET socio_people_in_house = OBS_VALUE_NUMERIC(t.encounter_id, 'PIH', 'NUMBER OF PEOPLE WHO LIVE IN HOUSE INCLUDING PATIENT');
UPDATE temp_socio_economics t SET socio_rooms_in_house = OBS_VALUE_NUMERIC(t.encounter_id, 'PIH', 'NUMBER OF ROOMS IN HOUSE');
UPDATE temp_socio_economics t SET socio_roof_type = OBS_VALUE_CODED_LIST(t.encounter_id, 'PIH', 'ROOF MATERIAL', 'en');
UPDATE temp_socio_economics t SET socio_floor_type = OBS_VALUE_CODED_LIST(t.encounter_id, 'PIH', '1315', 'en');
UPDATE temp_socio_economics t SET socio_has_latrine = OBS_VALUE_CODED_LIST(t.encounter_id, 'PIH', 'Latrine', 'en');
UPDATE temp_socio_economics t SET socio_has_radio = OBS_VALUE_CODED_LIST(t.encounter_id, 'PIH', '1318', 'en');
UPDATE temp_socio_economics t SET socio_years_of_education = OBS_VALUE_CODED_LIST(t.encounter_id, 'PIH', 'HIGHEST LEVEL OF SCHOOL COMPLETED', 'en');
UPDATE temp_socio_economics t SET socio_transport_method = OBS_VALUE_CODED_LIST(t.encounter_id, 'PIH', '975', 'en');
UPDATE temp_socio_economics t SET socio_transport_time = OBS_VALUE_CODED_LIST(t.encounter_id, 'PIH', 'CLINIC TRAVEL TIME', 'en');

DROP TEMPORARY TABLE IF EXISTS temp_socio_hiv_intake;
CREATE TEMPORARY TABLE temp_socio_hiv_intake(
patient_id INT,
emr_id VARCHAR(50),
encounter_id INT,
socio_smoker VARCHAR(50),
socio_smoker_years DOUBLE,
socio_smoker_cigarette_per_day INT,
socio_alcohol VARCHAR(50),
socio_alcohol_type TEXT,
socio_alcohol_drinks_per_day INT,
socio_alcohol_days_per_week INT
);

CREATE INDEX temp_socio_hiv_intake_patient_id ON temp_socio_hiv_intake (patient_id);
CREATE INDEX temp_socio_hiv_intake_encounter_id ON temp_socio_hiv_intake (encounter_id);

INSERT INTO temp_socio_hiv_intake (patient_id, encounter_id)
SELECT patient_id, MAX(encounter_id) FROM encounter WHERE encounter_id IN (SELECT encounter_id FROM encounter WHERE voided = 0 AND encounter_type 
= @hiv_initial_encounter_type) AND voided = 0 GROUP BY patient_id;

UPDATE temp_socio_economics t SET emr_id = PATIENT_IDENTIFIER(patient_id, METADATA_UUID('org.openmrs.module.emrapi', 'emr.primaryIdentifierType'));

-- note that I noticed that the following statements for socio indicators in the intake form were very slow.
-- to alleviate this, I loaded all of the obs for the encounters in the "unhealthy habits" set into a smaller temp table.
-- all of the columns are populated from that table 
DROP TEMPORARY TABLE IF EXISTS temp_hiv_intake_obs;
create temporary table temp_hiv_intake_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.comments 
from obs o
inner join temp_socio_hiv_intake t on t.encounter_id = o.encounter_id
where o.voided = 0
and o.concept_id in
	(select concept_id from concept_set cs where cs.concept_set =  concept_from_mapping('PIH','11950'))
;

CREATE INDEX temp_hiv_intake_obs_ei ON temp_hiv_intake_obs (encounter_id);

update temp_socio_hiv_intake t
inner join temp_hiv_intake_obs o on o.encounter_id = t.encounter_id
	and o.concept_id = concept_from_mapping('PIH', 'HISTORY OF TOBACCO USE')
set socio_smoker = concept_name(o.value_coded, 'en');

update temp_socio_hiv_intake t
inner join temp_hiv_intake_obs o on o.encounter_id = t.encounter_id
	and o.concept_id = concept_from_mapping('CIEL', '159931')
set socio_smoker_years = o.value_numeric;

update temp_socio_hiv_intake t
inner join temp_hiv_intake_obs o on o.encounter_id = t.encounter_id
	and o.concept_id = concept_from_mapping('PIH', '11949')
set socio_smoker_cigarette_per_day = o.value_numeric;

update temp_socio_hiv_intake t
inner join temp_hiv_intake_obs o on o.encounter_id = t.encounter_id
	and o.concept_id = concept_from_mapping('PIH', 'HISTORY OF ALCOHOL USE')
set socio_alcohol = concept_name(o.value_coded, 'en');

update temp_socio_hiv_intake t
inner join temp_hiv_intake_obs o on o.encounter_id = t.encounter_id
	and o.concept_id = concept_from_mapping( 'PIH', '3342')
	and o.value_coded = concept_from_mapping('PIH', 'OTHER')
set socio_alcohol_type = o.comments;

update temp_socio_hiv_intake t
inner join temp_hiv_intake_obs o on o.encounter_id = t.encounter_id
	and o.concept_id = concept_from_mapping('PIH', 'ALCOHOLIC DRINKS PER DAY')
set socio_alcohol_drinks_per_day = o.value_numeric;

update temp_socio_hiv_intake t
inner join temp_hiv_intake_obs o on o.encounter_id = t.encounter_id
	and o.concept_id = concept_from_mapping('PIH', 'NUMBER OF DAYS PER WEEK ALCOHOL IS USED')
set socio_alcohol_days_per_week = o.value_numeric;

DROP TEMPORARY TABLE IF EXISTS temp_hiv_vitals_weight;
CREATE TEMPORARY TABLE temp_hiv_vitals_weight (
person_id INT,
encounter_id INT, 
last_weight DOUBLE,
last_weight_date DATE
); 

CREATE INDEX temp_hiv_vitals_weight_patient_id ON temp_hiv_vitals_weight (person_id);
CREATE INDEX temp_hiv_vitals_weight_encounter_id ON temp_hiv_vitals_weight (encounter_id);

INSERT INTO temp_hiv_vitals_weight (person_id, encounter_id)
SELECT person_id, MAX(encounter_id) FROM obs WHERE voided = 0 AND concept_id = CONCEPT_FROM_MAPPING('PIH', 'WEIGHT (KG)') GROUP BY person_id;  	

UPDATE temp_hiv_vitals_weight t SET last_weight = OBS_VALUE_NUMERIC(t.encounter_id, 'PIH', 'WEIGHT (KG)');
UPDATE temp_hiv_vitals_weight t SET last_weight_date = (SELECT DATE(encounter_datetime) FROM encounter e WHERE voided = 0 AND t.encounter_id = e.encounter_id );

DROP TEMPORARY TABLE IF EXISTS temp_hiv_vitals_height;
CREATE TEMPORARY TABLE temp_hiv_vitals_height (
person_id INT,
encounter_id INT, 
last_height DOUBLE,
last_height_date DATE
); 

CREATE INDEX temp_hiv_vitals_height_patient_id ON temp_hiv_vitals_height (person_id);
CREATE INDEX temp_hiv_vitals_height_encounter_id ON temp_hiv_vitals_height (encounter_id);

INSERT INTO temp_hiv_vitals_height (person_id, encounter_id)
SELECT person_id, MAX(encounter_id) FROM obs WHERE voided = 0 AND concept_id = CONCEPT_FROM_MAPPING('PIH', 'HEIGHT (CM)') GROUP BY person_id;  	

UPDATE temp_hiv_vitals_height t SET last_height = OBS_VALUE_NUMERIC(t.encounter_id, 'PIH', 'HEIGHT (CM)');
UPDATE temp_hiv_vitals_height t SET last_height_date = (SELECT DATE(encounter_datetime) FROM encounter e WHERE voided = 0 AND t.encounter_id = e.encounter_id );

-- last_visit_date
### For this section, putting into account restrospective data entry,
### thus using max(encounter_date) instead of max(encounter_id)
DROP TEMPORARY TABLE IF EXISTS temp_hiv_last_visits;
CREATE TEMPORARY TABLE temp_hiv_last_visits (
patient_id INT,
last_visit_date DATETIME
);

CREATE INDEX temp_hiv_last_visits_patient_id ON temp_hiv_last_visits (patient_id);

INSERT INTO temp_hiv_last_visits (patient_id, last_visit_date)
SELECT patient_id, MAX(encounter_datetime) FROM encounter WHERE voided = 0
AND encounter_id IN (SELECT encounter_id FROM encounter WHERE encounter_type IN (@hiv_initial_encounter_type, @hiv_followup_encounter_type) AND voided = 0)
GROUP BY patient_id;

-- next_visit_date
### For this section, putting into account restrospective data entry, 
### thus using max(encounter_date) instead of max(encounter_id)
DROP TEMPORARY TABLE IF EXISTS temp_hiv_next_visit_date;
CREATE TEMPORARY TABLE temp_hiv_next_visit_date
(
person_id INT,
next_visit_date DATETIME,
days_late_to_visit DOUBLE
);
INSERT INTO temp_hiv_next_visit_date (person_id, next_visit_date)
SELECT person_id, MAX(value_datetime) FROM obs WHERE voided = 0 AND concept_id = CONCEPT_FROM_MAPPING("PIH", "RETURN VISIT DATE")
AND encounter_id IN (SELECT encounter_id FROM encounter WHERE encounter_type IN (@hiv_initial_encounter_type, @hiv_followup_encounter_type) AND voided = 0) GROUP BY person_id;

UPDATE temp_hiv_next_visit_date t SET days_late_to_visit =  TIMESTAMPDIFF(DAY, next_visit_date, NOW());

--
DROP TABLE IF EXISTS temp_hiv_diagnosis_date;
CREATE TEMPORARY TABLE temp_hiv_diagnosis_date
(
person_id INT,
encounter_id INT,
hiv_diagnosis_date DATE
);

CREATE INDEX temp_hiv_diagnosis_date_person_id ON temp_hiv_diagnosis_date (person_id);
CREATE INDEX temp_hiv_diagnosis_date_encounter_id ON temp_hiv_diagnosis_date (encounter_id);

INSERT INTO temp_hiv_diagnosis_date (person_id, encounter_id, hiv_diagnosis_date)
SELECT person_id, encounter_id, DATE(MIN(value_datetime)) FROM obs WHERE voided = 0 AND
concept_id = CONCEPT_FROM_MAPPING('CIEL', '164400') GROUP BY person_id;

DROP TABLE IF EXISTS temp_hiv_dispensing;
CREATE TEMPORARY TABLE temp_hiv_dispensing
(
person_id INT,
latest_encounter INT,
last_pickup_date DATE,
last_pickup_months_dispensed DOUBLE,
last_pickup_treatment_line VARCHAR(5),
next_pickup_date DATE,
days_late_to_pickup DOUBLE,
agent TEXT
);

CREATE INDEX temp_hiv_dispensing_person_id ON temp_hiv_dispensing (person_id);
CREATE INDEX temp_hiv_dispensing_latest_encounter ON temp_hiv_dispensing (latest_encounter);

INSERT INTO temp_hiv_dispensing (person_id)
SELECT person_id FROM 
obs WHERE voided = 0 AND
concept_id = CONCEPT_FROM_MAPPING('PIH', '1535') AND encounter_id IN (SELECT encounter_id FROM encounter
WHERE voided = 0 AND encounter_type = @hiv_dispensing_encounter)
-- AND value_coded IN (CONCEPT_FROM_MAPPING('PIH', '3013') , CONCEPT_FROM_MAPPING('PIH', '2848'))
GROUP BY person_id;

UPDATE temp_hiv_dispensing t SET last_pickup_date = (SELECT max(encounter_datetime) FROM encounter e WHERE voided = 0 AND t.person_id = e.patient_id GROUP BY e.patient_id);

UPDATE temp_hiv_dispensing t SET latest_encounter = (SELECT encounter_id FROM encounter e WHERE encounter_type = @hiv_dispensing_encounter
AND voided = 0 AND t.person_id = patient_id and e.encounter_datetime = last_pickup_date limit 1);

UPDATE temp_hiv_dispensing t SET last_pickup_months_dispensed =  OBS_VALUE_NUMERIC(t.latest_encounter, 'PIH', '3102');

UPDATE temp_hiv_dispensing t SET last_pickup_treatment_line = OBS_VALUE_CODED_LIST(t.latest_encounter, 'CIEL', '166073', 'en');

UPDATE temp_hiv_dispensing t SET next_pickup_date = (SELECT DATE(value_datetime) FROM obs o WHERE voided = 0 AND o.encounter_id = t.latest_encounter 
AND concept_id = CONCEPT_FROM_MAPPING('CIEL', '5096'));
UPDATE temp_hiv_dispensing t SET days_late_to_pickup = TIMESTAMPDIFF(DAY, next_pickup_date, NOW());

UPDATE temp_hiv_dispensing t SET agent = OBS_VALUE_TEXT(t.latest_encounter, 'CIEL', '164141');

-- initial art dispensing info
set @arv1 = CONCEPT_FROM_MAPPING('PIH', '3013');
set @arv2 = CONCEPT_FROM_MAPPING('PIH', '2848');
set @arv3 = CONCEPT_FROM_MAPPING('PIH', '13960');
-- INSERT INTO temp_art_dispensing (person_id, art_dispensing_obs_id)
-- will be one row per dispensing construct 
DROP TEMPORARY TABLE IF EXISTS temp_art_obs;
create temporary table temp_art_obs
SELECT person_id, obs_group_id, value_coded ,obs_datetime FROM 
obs WHERE voided = 0 AND
concept_id = CONCEPT_FROM_MAPPING('PIH', '1535') AND encounter_id IN (SELECT encounter_id FROM encounter
WHERE voided = 0 AND encounter_type = @hiv_dispensing_encounter)
 AND value_coded IN (@arv1, @arv2, @arv3)
;

DROP TEMPORARY TABLE IF EXISTS temp_min_art_obs_dates;
CREATE TEMPORARY TABLE temp_min_art_obs_dates
select person_id, value_coded, min(obs_datetime) "min_obs_datetime"
from temp_art_obs
group by person_id,value_coded;

DROP TEMPORARY TABLE IF EXISTS temp_art_summary;
CREATE TEMPORARY TABLE temp_art_summary
(patient_id 		INT(11),
arv1_obs_group_id	INT(11),
arv1_obs_date		datetime,
arv1_drug			varchar(255),
arv2_obs_group_id	INT(11),
arv2_obs_date		datetime,
arv2_drug			varchar(255),
arv3_obs_group_id	INT(11),
arv3_obs_date		datetime,
arv3_drug			varchar(255)
);

insert into temp_art_summary(patient_id)
select distinct person_id from temp_min_art_obs_dates;

create index temp_min_art_obs_dates1 on temp_min_art_obs_dates(person_id, value_coded);
create index temp_art_obs1 on temp_art_obs(person_id, obs_datetime, value_coded);

update temp_art_summary t 
inner join temp_min_art_obs_dates mo on mo.person_id = t.patient_id and mo.value_coded = @arv1
inner join temp_art_obs o on t.patient_id = o.person_id 
	and o.obs_datetime = mo.min_obs_datetime
	and o.value_coded = @arv1
set t.arv1_obs_group_id = o.obs_group_id,
	t.arv1_obs_date = o.obs_datetime;

update temp_art_summary t 
inner join temp_min_art_obs_dates mo on mo.person_id = t.patient_id and mo.value_coded = @arv2
inner join temp_art_obs o on t.patient_id = o.person_id 
	and o.obs_datetime = mo.min_obs_datetime
	and o.value_coded = @arv2
set t.arv2_obs_group_id = o.obs_group_id,
	t.arv2_obs_date = o.obs_datetime;

update temp_art_summary t 
inner join temp_min_art_obs_dates mo on mo.person_id = t.patient_id and mo.value_coded = @arv3
inner join temp_art_obs o on t.patient_id = o.person_id 
	and o.obs_datetime = mo.min_obs_datetime
	and o.value_coded = @arv3
set t.arv3_obs_group_id = o.obs_group_id,
	t.arv3_obs_date = o.obs_datetime;

update temp_art_summary t 
set arv1_drug = obs_from_group_id_value_coded_list(arv1_obs_group_id, 'PIH','1282',@locale);

update temp_art_summary t 
set arv2_drug = obs_from_group_id_value_coded_list(arv2_obs_group_id, 'PIH','1282',@locale);

update temp_art_summary t 
set arv3_drug = obs_from_group_id_value_coded_list(arv3_obs_group_id, 'PIH','1282',@locale);

update temp_patient t 
inner join temp_art_summary tas on tas.patient_id = t.patient_id
set art_dispensing_start_date = COALESCE(arv1_obs_date, arv2_obs_date, arv3_obs_date),
	first_art_dispensing_regimen = CONCAT(ifnull(tas.arv1_drug,''),if(tas.arv2_drug is null, '',concat(',',tas.arv2_drug)),if(tas.arv3_drug is null, '',concat(',',tas.arv3_drug))) ;



-- hiv art orders
DROP TABLE IF EXISTS temp_hiv_art;
CREATE TEMPORARY TABLE temp_hiv_art
(
patient_id INT,
order_id INT,
art_start_date DATE,
initial_art_regimen TEXT,
art_regimen TEXT
);

CREATE INDEX temp_hiv_art_patient ON temp_hiv_art (patient_id);

set @ART_order_reason = concept_from_mapping( 'CIEL','138405');

-- the following will add the first row (sorted by date_activated, date_created, order_id) for each patient
INSERT INTO temp_hiv_art (patient_id,order_id,art_start_date,initial_art_regimen)
	SELECT o2.patient_id, o2.order_id, o2.date_activated , concept_name(o2.concept_id ,'en') FROM
		(SELECT o.* FROM orders o
		WHERE o.order_reason = @ART_order_reason 
		ORDER BY date_activated, date_created, order_id ) o2
	GROUP BY o2.patient_id
	ORDER BY patient_id 
;


UPDATE temp_hiv_art t set art_regimen = ActiveDrugConceptNameList(t.patient_id, 'CIEL','138405','en');

update temp_patient t 
inner join temp_hiv_art tha on tha.patient_id = t.patient_id 
set t.art_order_start_date = tha.art_start_date,
	t.initial_art_regimen_order = tha.initial_art_regimen,
	t.art_regimen = tha.art_regimen;

update temp_patient t
set art_start_date = 
	CASE WHEN art_order_start_date <= art_dispensing_start_date THEN art_order_start_date
		ELSE art_dispensing_start_date
	END ;

UPDATE temp_patient  t SET t.months_on_art = TIMESTAMPDIFF(MONTH, t.art_start_date, NOW());

update temp_patient t
set t.initial_art_regimen = 
	CASE WHEN art_order_start_date <= art_dispensing_start_date THEN initial_art_regimen_order
		ELSE first_art_dispensing_regimen
	END ;



-- 
-- partner's HIV status
-- 
drop temporary table if exists temp_partner_status;
create temporary table temp_partner_status
(tps_id							int(11) auto_increment,
patient_id						int(11),
status_datetime					datetime,
status							varchar(255),
contact_construct_obs_group_id	int(11),
PRIMARY KEY (tps_id)
);

-- add Partner HIV status observations (currently captured on HIV CT Form)
-- note that an answer of 'Partner Confirmed HIV+' is translated to 'positive' to match results from other observations below
insert into temp_partner_status(patient_id, status, status_datetime)
select person_id,
	CASE 
		when o.value_coded = concept_from_mapping('PIH','PARTNER CONFIRMED HIV+') then concept_name(concept_from_mapping('PIH','POSITIVE'), @locale)
		else concept_name(o.value_coded,@locale)
	END,
	o.obs_datetime  
from obs o 
where concept_id = concept_from_mapping('CIEL','1436')
and voided = 0
;

-- add contact constructs where contact = partner/spouse
insert into temp_partner_status(contact_construct_obs_group_id)
select obs_group_id from obs o
where concept_id = concept_from_mapping('PIH','13265')
and o.value_coded = concept_from_mapping('PIH','5617')
and voided = 0
;

-- update partner contact constructs for HIV result
update temp_partner_status t
inner join obs o on o.obs_group_id = t.contact_construct_obs_group_id
	and o.concept_id = concept_from_mapping('PIH','2169')
	and o.voided = 0
set t.patient_id = o.person_id,
	t.status_datetime = o.obs_datetime ,
	t.status = concept_name(o.value_coded,@locale)
;	


	-- join in most recent result into main patient temp table
drop temporary table if exists temp_partner_status2;
create temporary table temp_partner_status2
select tps_id, patient_id, status_datetime, status from temp_partner_status;

create index temp_partner_status2_c1 on temp_partner_status2(patient_id, status_datetime);

update temp_patient t 
inner join temp_partner_status tps on tps_id =
	(select tps2.tps_id from temp_partner_status2 tps2
	where tps2.patient_id = t.patient_id 
	order by tps2.status_datetime desc limit 1)
set t.partner_hiv_status = tps.status;

update temp_patient 
set biometrics_code = patient_identifier(patient_id, 'e26ca279-8f57-44a5-9ed8-8cc16e90e559');

update temp_patient 
inner join patient_identifier pid on pid.identifier = biometrics_code
set biometrics_collected = 1,
    latest_biometrics_collection_date = pid.date_created,
    biometrics_collector = person_name_of_user(pid.creator);
   
update temp_patient set  biometrics_collected = 0, biometrics_collector = null where biometrics_collected is null;


update temp_patient t
inner join patient_program pp on p.patient_id = t.patient_id 
    where pp.outcome_concept_id = @transfer_to_zl
    and pp.patient_program_id = t.patient_program_id
    and pp.voided = 0
    order by pp.date_enrolled DESC 
    limit 1
set transfer_from_location = location_name(pp.location_id),
    transfer_from_date = pp.date_enrolled;

### Final Query
SELECT 
t.zl_emr_id,
t.hivemr_v1_id,
t.hiv_dossier_id,
t.given_name,
t.family_name,
t.nickname,
t.gender,
t.birthdate,
t.age,
t.birthplace_commune,
t.birthplace_sc,
t.birthplace_locality,
t.birthplace_province,
t.patient_registration_date,
t.user_entered,
t.initial_enrollment_location,
t.latest_enrollment_location,
t.marital_status,
t.occupation,
tehd.agent,
t.mothers_first_name,
t.telephone_number,
t.address,
t.department,
t.commune,
t.section_communal,
t.locality,
t.street_landmark,
t.dead,
t.death_date,
t.cause_of_death,
t.cause_of_death_non_coded,
t.patient_msm,
t.patient_sw,
t.patient_pris,
t.patient_trans,
t.patient_idu,
t.parent_firstname,
t.parent_lastname,
t.parent_relationship,
t.partner_hiv_status,
tse.socio_people_in_house,
tse.socio_rooms_in_house,
tse.socio_roof_type,
tse.socio_floor_type,
tse.socio_has_latrine,
tse.socio_has_radio,
tse.socio_years_of_education,
tse.socio_transport_method,
tse.socio_transport_time,
tse.socio_transport_walking_time,
ts.socio_smoker,
ts.socio_smoker_years,
ts.socio_smoker_cigarette_per_day,
ts.socio_alcohol,
ts.socio_alcohol_type,
ts.socio_alcohol_drinks_per_day,
ts.socio_alcohol_days_per_week,
tsw.last_weight,
tsw.last_weight_date,
tsh.last_height,
tsh.last_height_date,
DATE(tsv.last_visit_date),
DATE(tsd.next_visit_date),
IF(tsd.days_late_to_visit > 0, days_late_to_visit, 0) days_late_to_visit, 
thd.hiv_diagnosis_date,
t.art_dispensing_start_date,
t.first_art_dispensing_regimen,
t.art_order_start_date,
t.initial_art_regimen_order,
t.art_start_date,
t.months_on_art,
t.initial_art_regimen,
t.art_regimen,
tehd.last_pickup_date,
tehd.last_pickup_months_dispensed,
tehd.last_pickup_treatment_line,
tehd.next_pickup_date,
IF(tehd.days_late_to_pickup > 0, tehd.days_late_to_pickup, 0) days_late_to_pickup,
t.biometrics_collected,
t.latest_biometrics_collection_date,
t.biometrics_collector,
t.transfer_from_location,
t.transfer_from_date
FROM temp_patient t 
LEFT JOIN temp_socio_economics tse ON t.patient_id = tse.patient_id
LEFT JOIN temp_socio_hiv_intake ts ON t.patient_id = ts.patient_id
LEFT JOIN temp_hiv_vitals_weight tsw ON t.patient_id = tsw.person_id
LEFT JOIN temp_hiv_vitals_height tsh ON t.patient_id = tsh.person_id
LEFT JOIN temp_hiv_last_visits tsv ON t.patient_id = tsv.patient_id
LEFT JOIN temp_hiv_next_visit_date tsd ON t.patient_id = tsd.person_id
LEFT JOIN temp_hiv_diagnosis_date thd ON t.patient_id = thd.person_id
LEFT JOIN temp_hiv_dispensing tehd ON tehd.person_id = t.patient_id
;
