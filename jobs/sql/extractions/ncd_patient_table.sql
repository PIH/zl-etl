-- ---------------------- Variables ---------------------------------------------------
SELECT 'en' INTO @locale;
SET @ncd_init_enc = (SELECT encounter_type_id FROM encounter_type WHERE uuid = 'ae06d311-1866-455b-8a64-126a9bd74171');
SET @ncd_follow_enc = (SELECT encounter_type_id FROM encounter_type e WHERE uuid = '5cbfd6a2-92d9-4ad0-b526-9d29bfe1d10c');
select program_id into @ncd_program_id from program where uuid = '515796ec-bf3a-11e7-abc4-cec278b6b50a';

DROP TEMPORARY TABLE IF EXISTS ncd_patient_table;
CREATE TEMPORARY TABLE ncd_patient_table (
patient_id int,
emr_id varchar(50),
birthdate date,
sex char(1),
department varchar(50),
commune varchar(50),
ncd_enrollment_date date,
ncd_first_encounter_date date,
ncd_enrollment_location varchar(50),
htn bit,
diabetes bit,
respiratory bit,
epilepsy bit,
heart_failure bit,
cerebrovascular_accident bit,
renal_failure bit,
liver_failure bit,
rehabilitation bit,
sickle_cell bit,
other_ncd bit,
dm_type varchar(50),
heart_failure_category varchar(50),
cardiomyopathy varchar(50),
nyha_class varchar(50),
heart_failure_improbable bit,
ncd_status varchar(50),
ncd_status_date date,
deceased bit,
date_of_death date
);

-- -------------------- INSERT patients IN SCOPE OF NCD -----------------------------------------------------
insert into ncd_patient_table (patient_id)
SELECT patient_id  FROM (
	SELECT e2.patient_id , max(e2.encounter_id) encounter_id
	FROM encounter e2 INNER JOIN ( 
	SELECT patient_id, max(encounter_datetime) encounter_datetime
				from encounter e 
				WHERE
				encounter_type in (@ncd_init_enc,@ncd_follow_enc)
				GROUP BY patient_id) tmp ON tmp.patient_id=e2.patient_id AND tmp.encounter_datetime=e2.encounter_datetime
				WHERE e2.encounter_type in (@ncd_init_enc,@ncd_follow_enc) 
	GROUP BY  e2.patient_id
) x
;

-- -------------------------------------------------------- birth date, gender, state, city-----------------------

UPDATE ncd_patient_table tt
SET tt.birthdate= birthdate(tt.patient_id),
tt.sex=gender(tt.patient_id),
tt.department = person_address_state_province(tt.patient_id),
tt.commune =person_address_city_village(tt.patient_id);

-- -------------------------------------------------------- Enrolled date, location of enrollment -----------------------

DROP TABLE IF EXISTS first_enc;
CREATE TEMPORARY TABLE first_enc AS
		SELECT patient_id , min(encounter_id) encounter_id, location_id
		FROM encounter e 
		WHERE encounter_type IN (@ncd_init_enc, @ncd_follow_enc)
		GROUP BY patient_id;

DROP TABLE IF EXISTS first_enc_details;
CREATE TEMPORARY TABLE  first_enc_details AS 
	SELECT DISTINCT e.patient_id, e.encounter_datetime  , e.encounter_id,e.encounter_type
        FROM encounter e INNER JOIN first_enc X ON X.patient_id =e.patient_id AND X.encounter_id=e.encounter_id
        WHERE encounter_type IN (@ncd_init_enc, @ncd_follow_enc);

	
UPDATE 
ncd_patient_table tt INNER JOIN (
  SELECT patient_id,min(date_enrolled) date_enrolled
  FROM patient_program pp
  WHERE program_id=@ncd_program_id
  GROUP BY patient_id 
  ORDER BY date_enrolled ASC) st on st.patient_id = tt.patient_id
SET tt.ncd_enrollment_date=CAST(st.date_enrolled AS date);

UPDATE 
ncd_patient_table tt INNER JOIN (
  SELECT patient_id,CAST(encounter_datetime AS date) date_enrolled 
  FROM first_enc_details) fe on fe.patient_id = tt.patient_id
SET tt.ncd_first_encounter_date=fe.date_enrolled;

UPDATE 
ncd_patient_table tt INNER JOIN (
  SELECT patient_id,CAST(encounter_datetime AS date) date_enrolled 
  FROM first_enc_details) fe on fe.patient_id = tt.patient_id
SET tt.ncd_enrollment_date=fe.date_enrolled
	  WHERE tt.ncd_enrollment_date IS NULL;
	 
UPDATE ncd_patient_table tt JOIN first_enc fe 
ON fe.patient_id = tt.patient_id SET ncd_enrollment_location = LOCATION_NAME(fe.location_id);

-- -------------------------------------------------------- death flag, death date -----------------------
UPDATE ncd_patient_table tt INNER JOIN (
SELECT person_id, dead , death_date FROM person p WHERE voided=0) st on  st.person_id =tt.patient_id 
SET tt.deceased = dead,
	tt.date_of_death = CAST(st.death_date AS date);

-- -------------------------------------------------------- program state, last status date -----------------------

UPDATE ncd_patient_table tt 
SET tt.ncd_status = (
	SELECT concept_name(pws.concept_id , 'en') AS ncd_status
	from patient_state ps
	INNER JOIN patient_program pp ON pp.patient_program_id =ps.patient_program_id 
	inner join program_workflow_state pws on pws.program_workflow_state_id = ps.state 
	WHERE  pp.program_id =@ncd_program_id
	AND pp.patient_id = tt.patient_id 
	ORDER BY ps.start_date DESC , concept_name(pws.concept_id , 'en')   ASC 
	LIMIT 1
)
;

UPDATE ncd_patient_table tt 
SET tt.ncd_status_date = (
	SELECT  ps.start_date AS ncd_status_date
	from patient_state ps
	INNER JOIN patient_program pp ON pp.patient_program_id =ps.patient_program_id 
	inner join program_workflow_state pws on pws.program_workflow_state_id = ps.state 
	WHERE  pp.program_id =@ncd_program_id
	AND pp.patient_id = tt.patient_id 
	ORDER BY ps.start_date  DESC 
	LIMIT 1
) 
;
-- -------------------- Views Preparation ---------------------------------------------------------------------
DROP TABLE IF EXISTS ncd_encounters;
CREATE TEMPORARY TABLE ncd_encounters AS 
SELECT encounter_id FROM encounter e WHERE patient_id  IN (
SELECT DISTINCT patient_id FROM ncd_patient_table npt)
AND  encounter_type IN (@ncd_init_enc,@ncd_follow_enc)
;
-- -------------- NCD Flags ----------------------------------------------

DROP TABLE IF EXISTS ncd_obs;
CREATE TEMPORARY TABLE ncd_obs  AS
			select   person_id  AS patient_id,
			MAX(CASE WHEN value_coded=concept_from_mapping('PIH','903')  THEN TRUE ELSE FALSE END) AS 'Hypertension',
			MAX(CASE WHEN value_coded=concept_from_mapping('PIH','3720') THEN TRUE ELSE FALSE END) AS 'Diabetes',
			MAX(CASE WHEN value_coded=concept_from_mapping('PIH','6768') THEN TRUE ELSE FALSE END) AS 'respiratory',
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
		  AND o.encounter_id IN (SELECT encounter_id FROM ncd_encounters )
			AND o.concept_id = concept_from_mapping('PIH','10529')
			GROUP BY person_id;

UPDATE ncd_patient_table tt inner  JOIN (
	SELECT patient_id,Hypertension,
	Diabetes ,
	respiratory,
	Epilepsy,
	Heart_failure ,
	Cerebrovascular_accident ,
	Renal_failure ,
	Liver_failure ,
	Rehabilitation ,
	Sickle_cell ,
	Other
	FROM ncd_obs
			) st ON tt.patient_id = st.patient_id	
	
SET tt.htn=st.Hypertension,
tt.diabetes=st.Diabetes ,
tt.respiratory=st.respiratory,
tt.epilepsy=st.Epilepsy,
tt.heart_failure=st.Heart_failure ,
tt.cerebrovascular_accident = st.Cerebrovascular_accident ,
tt.renal_failure = st.Renal_failure ,
tt.liver_failure =st.Liver_failure ,
tt.rehabilitation = st.Rehabilitation ,
tt.sickle_cell=st.Sickle_cell ,
tt.other_ncd=st.Other
;

-- ----------------------------------------------------- Diabetes TYPE  ----------------------------------------------------------------------------------------------------
UPDATE ncd_patient_table tt 
SET  tt.dm_type =( 
		SELECT 
		CASE WHEN value_coded =concept_from_mapping ('PIH','6691') THEN 'Type-1'
				WHEN value_coded IN (concept_from_mapping ('PIH','6692'),
													concept_from_mapping('PIH','12228'),
													concept_from_mapping('PIH','11943'),
													concept_from_mapping('PIH','12227'),
													concept_from_mapping('PIH','12251')
													) THEN  'Type-2'
				WHEN value_coded =concept_from_mapping('PIH','7138') THEN 'hyperglycemia without diabetes'
				WHEN value_coded =concept_from_mapping('PIH','6693') THEN 'Gestational diabetes'
		END AS 'dm_type'
						from obs o2
		            where o2.voided = 0
		          AND o2.person_id =  tt.patient_id
		           AND o2.encounter_id IN (SELECT encounter_id FROM ncd_encounters )
		            and o2.concept_id = concept_from_mapping('PIH','3064')  -- diagnosis question
		                and concept_in_set(o2.value_coded, concept_from_mapping('PIH','11501'))=1 -- answer in diabetes set 
		order by o2.obs_datetime desc limit 1);

-- --------------------------------------------------  Heart Failure TYPE ------------------------------------------------------------------------------------------------------------------
UPDATE ncd_patient_table tt 
SET  tt.heart_failure_category =( 
select CASE WHEN value_coded=concept_from_mapping('PIH','5016')  THEN 'cardiomyopathy' 
					WHEN value_coded=concept_from_mapping('PIH','7955')  THEN 'mitral valve stenosis' 
					WHEN value_coded=concept_from_mapping('PIH','3071')  THEN 'hypertensive heart disease' 
					WHEN value_coded=concept_from_mapping('PIH','7497') OR  
					value_coded=concept_from_mapping('PIH','3131') THEN 'other heart valve disease/congenital heart disease ' 
					WHEN value_coded=concept_from_mapping('PIH','4000')  THEN 'isolated right heart failure'
					WHEN value_coded=concept_from_mapping('PIH','3307')  THEN 'pericardial effusion'
					ELSE 'other' END AS 'heart_failure_category'
				from obs o2				
               -- value_coded, concept_name(value_coded,@locale) AS 'heart_failure_category'
            where o2.voided = 0
            AND o2.person_id =tt.patient_id 
             AND o2.encounter_id IN (SELECT encounter_id FROM ncd_encounters )
            and o2.concept_id = concept_from_mapping('PIH','3064')  -- diagnosis question
            and concept_in_set(o2.value_coded, concept_from_mapping('PIH','11499'))=1 -- answer in heart failure diagnosis set 
order by o2.obs_datetime desc limit 1);

-- ----------------------------------------------------------- NYHA ----------------------------------------------------------
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
            AND o2.encounter_id IN (SELECT encounter_id FROM ncd_encounters )
            AND o2.person_id =  tt.patient_id 
            and o2.concept_id = concept_from_mapping('PIH','3139')  -- diagnosis question
order by o2.obs_datetime desc limit 1);



-- ------------------------------------- heart failure imoerdable ------------------------------------------------------------------------------------
 UPDATE ncd_patient_table tt 
SET  tt.heart_failure_improbable =( 
 SELECT CASE WHEN NOT obs_value_coded_list(tt.patient_id, 'PIH','11926',@locale) IS NULL THEN TRUE ELSE FALSE END AS heart_failure_improbable);

UPDATE ncd_patient_table tt 
SET  tt.heart_failure_improbable=FALSE 
WHERE tt.heart_failure=FALSE;
 
 -- ---------------------------------------------- Cardiomyopathy ------------------------------------------------------------------------------------------------
 UPDATE ncd_patient_table tt 
SET  tt.cardiomyopathy =( 
		select -- obs_id,value_coded ,value_text,concept_id,
		CASE 
		WHEN value_coded=concept_from_mapping('PIH','7940') THEN 'Ischemic cardiomyopathy'
		WHEN value_coded =concept_from_mapping('PIH','3129') THEN 'Peripartum cardiomyopathy'
		WHEN value_coded =concept_from_mapping('PIH','4002') THEN 'Alcoholic cardiomyopathy'
		WHEN value_coded =concept_from_mapping('PIH','3130') THEN 'Cardiomyopathy due to HIV'
		WHEN value_coded =concept_from_mapping('PIH','5016') THEN 'Other Cardiomyopathy'
		ELSE  concept_name(value_coded,@locale) 
		END AS cardiomyopathy
						from obs o2
		            where o2.voided = 0
		            AND o2.person_id = tt.patient_id 
		            and o2.concept_id = concept_from_mapping('PIH','3064') 
		            AND value_coded IN (
		            concept_from_mapping('PIH','7940'), concept_from_mapping('PIH','3129') , concept_from_mapping('PIH','4002') , concept_from_mapping('PIH','3130') ,
		            concept_from_mapping('PIH','5016') 
		            )
		            ORDER BY person_id,encounter_id DESC
		            LIMIT 1 
           );
          
          
SELECT
patient_id,
zlemr(patient_id) emr_id,
birthdate ,
sex,
department,
commune,
ncd_enrollment_date,
ncd_first_encounter_date,
ncd_enrollment_location,
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
FROM ncd_patient_table
WHERE (diabetes IS NOT NULL AND  respiratory IS NOT NULL AND htn IS NOT NULL AND epilepsy IS NOT NULL AND heart_failure IS NOT NULL 
AND cerebrovascular_accident IS NOT NULL AND renal_failure IS NOT NULL
AND liver_failure IS NOT NULL AND rehabilitation IS NOT NULL AND sickle_cell IS NOT NULL AND other_ncd IS NOT NULL);