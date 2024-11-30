## ------------------------ Variables ---------------------------------------------------
SELECT 'en' INTO @locale;
SET @ncd_init_enc = (SELECT encounter_type_id FROM encounter_type WHERE uuid = 'ae06d311-1866-455b-8a64-126a9bd74171');
SET @ncd_follow_enc = (SELECT encounter_type_id FROM encounter_type WHERE uuid = '5cbfd6a2-92d9-4ad0-b526-9d29bfe1d10c');
SET @ncd_program_id='5263f849-ba6d-45b5-85d1-482382fbcf3f';

select encounter_id INTO @encounterid  
			from encounter e 
			WHERE
			patient_id = @patient_id  and 
			encounter_type in (@ncd_init_enc,@ncd_follow_enc)
			ORDER BY encounter_datetime desc
			LIMIT 1;

drop temporary table if exists ncd_patient_table;

create temporary table ncd_patient_table
(
patient_id int,
birthdate date,
sex char(1),
department varchar(50),
commune varchar(50),
ncd_enrollment_date date,
ncd_enrollment_location varchar(50),
htn boolean,
diabetes boolean,
respiratory boolean,
epilepsy boolean,
heart_failure boolean,
cerebrovascular_accident boolean,
renal_failure boolean,
liver_failure boolean,
rehabilitation boolean,
sickle_cell boolean,
other_ncd boolean,
dm_type varchar(50),
heart_failure_category varchar(50),
cardiomyopathy varchar(50),
nyha_class varchar(50),
heart_failure_improbable boolean,
ncd_status varchar(50),
ncd_status_date date,
deceased boolean,
date_of_death date
);
## ---------------------- INSERT patients IN SCOPE OF NCD -----------------------------------------------------
insert into ncd_patient_table (patient_id)
SELECT patient_id  FROM (
	SELECT e2.patient_id , e2.encounter_id  
	FROM encounter e2 INNER JOIN ( 
	SELECT patient_id, max(encounter_datetime) encounter_datetime
				from encounter e 
				WHERE
				encounter_type in (@ncd_init_enc,@ncd_follow_enc)
				GROUP BY patient_id) tmp ON tmp.patient_id=e2.patient_id AND tmp.encounter_datetime=e2.encounter_datetime
				WHERE e2.encounter_type in (@ncd_init_enc,@ncd_follow_enc) 
) x
;

## ---------------------------------------------------------- birth date, gender, state, city-----------------------

UPDATE ncd_patient_table tt
SET tt.birthdate= birthdate(tt.patient_id),
tt.sex=gender(tt.patient_id),
tt.department = person_address_state_province(tt.patient_id),
tt.commune =person_address_city_village(tt.patient_id) ;

## ---------------------------------------------------------- Enrolled date, location of enrollment -----------------------
UPDATE 
ncd_patient_table tt INNER JOIN (
  SELECT patient_id,date_enrolled ,location_name(location_id) AS location_name 
  FROM patient_program pp ) st on st.patient_id = tt.patient_id
SET tt.ncd_enrollment_location=st.location_name,
	   tt.ncd_enrollment_date=st.date_enrolled;
	  

	
## ---------------------------------------------------------- death flag, death date -----------------------
UPDATE ncd_patient_table tt INNER JOIN (
SELECT person_id, dead , death_date FROM person p) st on  st.person_id =tt.patient_id 
SET tt.deceased = dead,
	tt.date_of_death = st.death_date;

## ---------------------------------------------------------- program state, las status date -----------------------
UPDATE ncd_patient_table tt INNER JOIN (
select patient_id,concept_name(pws.concept_id , 'en') AS ncd_status, ps.start_date AS ncd_status_date
from patient_state ps
inner join program_workflow_state pws on pws.program_workflow_state_id = ps.state 
INNER JOIN patient_program pp ON pp.patient_program_id =ps.patient_program_id 
WHERE  pp.uuid =@ncd_program_id
) st 
on tt.patient_id = st.patient_id 

SET tt.ncd_status=st.ncd_status,
      tt.ncd_status_date =st.ncd_status_date
;
## ---------------- NCD Flags ----------------------------------------------

UPDATE ncd_patient_table tt inner  JOIN (
			select   person_id  AS patient_id,
			MAX(CASE WHEN value_coded=concept_from_mapping('PIH','903')  THEN TRUE ELSE FALSE END) AS 'Hypertension',
			MAX(CASE WHEN value_coded=concept_from_mapping('PIH','3720') THEN TRUE ELSE FALSE END) AS 'Diabetes',
			MAX(CASE WHEN value_coded=concept_from_mapping('PIH','155') THEN TRUE ELSE FALSE END) AS 'Epilepsy',
			MAX(CASE WHEN value_coded=concept_from_mapping('PIH','3468') THEN TRUE ELSE FALSE END) AS 'Heart_failure',
			MAX(CASE WHEN value_coded=concept_from_mapping('PIH','7314') THEN TRUE ELSE FALSE END) AS 'Cerebrovascular_accident',
			MAX(CASE WHEN value_coded=concept_from_mapping('PIH','3681') THEN TRUE ELSE FALSE END) AS 'Renal_failure',
			MAX(CASE WHEN value_coded=concept_from_mapping('PIH','3682') THEN TRUE ELSE FALSE END) AS 'Liver_failure',
			MAX(CASE WHEN value_coded=concept_from_mapping('PIH','7263') THEN TRUE ELSE FALSE END) AS 'Rehabilitation',
			MAX(CASE WHEN value_coded=concept_from_mapping('PIH','7908') THEN TRUE ELSE FALSE END) AS 'Sickle_cell',
			MAX(CASE WHEN value_coded=concept_from_mapping('PIH','5622') THEN TRUE ELSE FALSE END) AS 'Other'
			from obs o
			where  o.voided = 0
			AND o.encounter_id in (SELECT encounter_id  FROM (
										SELECT e2.patient_id , e2.encounter_id  
										FROM encounter e2 INNER JOIN ( 
										SELECT patient_id, max(encounter_datetime) encounter_datetime
													from encounter e 
													WHERE
													encounter_type in (@ncd_init_enc,@ncd_follow_enc)
													GROUP BY patient_id) tmp ON tmp.patient_id=e2.patient_id AND tmp.encounter_datetime=e2.encounter_datetime
													WHERE e2.encounter_type in (@ncd_init_enc,@ncd_follow_enc) 
									)x ) 
			AND o.concept_id = concept_from_mapping('PIH','10529')
			GROUP BY person_id
			) st ON tt.patient_id = st.patient_id

SET tt.htn=st.Hypertension,
tt.diabetes=st.Diabetes ,
tt.epilepsy=st.Epilepsy,
tt.heart_failure=st.Heart_failure ,
tt.cerebrovascular_accident = st.Cerebrovascular_accident ,
tt.renal_failure = st.Renal_failure ,
tt.liver_failure =st.Liver_failure ,
tt.rehabilitation = st.Rehabilitation ,
tt.sickle_cell=st.Sickle_cell ,
tt.other_ncd=st.Other
;

## ------------------------------------------------------- Diabetes TYPE  ----------------------------------------------------------------------------------------------------
UPDATE ncd_patient_table tt 
SET  tt.dm_type =( 
		select
		CASE WHEN value_coded =concept_from_mapping ('PIH','6691') THEN 'Type-1'
				WHEN value_coded IN (concept_from_mapping ('PIH','6692'),
													concept_from_mapping('PIH','12228'),
													concept_from_mapping('PIH','11943'),
													concept_from_mapping('PIH','12227'),
													concept_from_mapping('PIH','12251')) THEN  'Type-2'
				WHEN value_coded =concept_from_mapping('PIH','7138') THEN 'Hyperglycemia'
				WHEN value_coded =concept_from_mapping('PIH','6693') THEN 'Gestational diabetes'
		END AS 'dm_type'
						from obs o2
		            where o2.voided = 0
		            AND o2.person_id =tt.patient_id
		            and o2.concept_id = concept_from_mapping('PIH','3064')  -- diagnosis question
		                and concept_in_set(o2.value_coded, concept_from_mapping('PIH','11501'))=1 -- answer in diabetes set 
		order by o2.obs_datetime desc limit 1);

## ----------------------------------------------------  Heart Failure TYPE ------------------------------------------------------------------------------------------------------------------
UPDATE ncd_patient_table tt 
SET  tt.heart_failure_category =( 
select concept_name(value_coded,@locale) AS 'heart_failure_category'
				from obs o2
            where o2.voided = 0
            AND o2.person_id = tt.patient_id 
            and o2.concept_id = concept_from_mapping('PIH','3064')  -- diagnosis question
            and concept_in_set(o2.value_coded, concept_from_mapping('PIH','11499'))=1 -- answer in diabetes set 
order by o2.obs_datetime desc limit 1);

## ------------------------------------------------------------- NYHA ----------------------------------------------------------
UPDATE ncd_patient_table tt 
SET  tt.nyha_class =( 
select 
CASE WHEN value_coded =concept_from_mapping('PIH','3135') THEN 'NYHA Class I'
WHEN value_coded =concept_from_mapping('PIH','3137') THEN 'NYHA Class III'
WHEN value_coded =concept_from_mapping('PIH','3136') THEN 'NYHA Class II'
WHEN value_coded =concept_from_mapping('PIH','3138') THEN 'NYHA Class IV'
ELSE null
END AS 'nyha_class'
				from obs o2
            where o2.voided = 0
            AND o2.person_id = tt.patient_id 
            and o2.concept_id = concept_from_mapping('PIH','3139')  -- diagnosis question
order by o2.obs_datetime desc limit 1);



-- ------------------------------------- heart failure imoerdable ------------------------------------------------------------------------------------
 UPDATE ncd_patient_table tt 
SET  tt.heart_failure_improbable =( 
 SELECT CASE WHEN NOT obs_value_coded_list(tt.patient_id, 'PIH','11926',@locale) IS NULL THEN TRUE ELSE FALSE END AS heart_failure_improbable);
 
 -- ---------------------------------------------- Cardiomyopathy ------------------------------------------------------------------------------------------------
 UPDATE ncd_patient_table tt 
SET  tt.cardiomyopathy =( 
  SELECT cardiomyopathy FROM (
		select obs_id,value_coded ,value_text,concept_id,
		CASE 
		WHEN value_coded=concept_from_mapping('PIH','7940') THEN 'Ischemic cardiomyopathy'
		WHEN value_coded =concept_from_mapping('PIH','3129') THEN 'Peripartum cardiomyopathy'
		WHEN value_coded =concept_from_mapping('PIH','4002') THEN 'Alcoholic cardiomyopathy'
		WHEN value_coded =concept_from_mapping('PIH','3130') THEN 'Cardiomyopathy due to HIV'
		WHEN value_coded =concept_from_mapping('PIH','5016') THEN 'Other Cardiomyopathy'
		ELSE null
		END AS 'cardiomyopathy'
						from obs o2
		            where o2.voided = 0
		            AND o2.person_id = @patient_id 
		            and o2.concept_id = concept_from_mapping('PIH','3064') ) x 
		 WHERE NOT cardiomyopathy IS null
           );
          
SELECT 
 patient_id,
birthdate ,
sex,
department,
commune,
ncd_enrollment_date,
ncd_enrollment_location ,
htn ,
diabetes ,
respiratory ,
epilepsy ,
heart_failure ,
cerebrovascular_accident ,
renal_failure ,
liver_failure ,
rehabilitation ,
sickle_cell ,
other_ncd ,
dm_type ,
heart_failure_category ,
cardiomyopathy ,
nyha_class ,
heart_failure_improbable ,
ncd_status ,
ncd_status_date ,
deceased ,
date_of_death 
FROM ncd_patient_table;
            