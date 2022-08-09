SELECT name  INTO @encounter_type_name FROM encounter_type et WHERE et.uuid ='fdee591e-78ba-11e9-8f9e-2a86e4085a59';
SELECT encounter_type_id  INTO @encounter_type_id FROM encounter_type et WHERE et.uuid ='fdee591e-78ba-11e9-8f9e-2a86e4085a59';
SELECT encounter_type_id INTO @dis_encounter_id FROM encounter_type et2 WHERE et2.uuid ='8ff50dea-18a1-4609-b4c9-3f8f2d611b84';

DROP TEMPORARY TABLE IF EXISTS echo_summary_table;
CREATE TEMPORARY TABLE echo_summary_table (
patient_id integer, 
emrid varchar(50), 
age int,
sex char(1),
department varchar(50),
commune varchar(50),
section_communal varchar(50),
locality varchar(50),
heart_failure bit,
echo_date_most_recent date,
echo_date_prior date,
total_echos int,
lvsf_most_recent varchar(50),
lvsf_prior varchar(50),
lvsf_change varchar(30),
mitral_stenosis bit,
nyha_class_most_recent varchar(50),
cardiomyopathy bit,
beta_blocker_atenolol bit,
beta_blocker_metoprolol bit,
beta_blocker_carvedilol bit,
ace_inhibitor bit,
penicillin bit,
spironolactone bit,
hydralazine_hydrochloride bit,
isosorbide_dinitrate bit,
diuretic bit,
calcium_channel_blocker bit,
follow_up_echo bit,
bp_systolic_most_recent int,
bp_diastolic_most_recent int,
ncd_comorbidity bit,
dm1 bit,
dm2 bit,
hypertension bit,
asthma bit,
sickle_cell bit,
copd bit
);

-- ################# Views Defintions ##############################################################3

CREATE OR REPLACE VIEW patient_list AS
SELECT DISTINCT  p.patient_id, pi2.identifier emr_id
FROM patient p INNER JOIN patient_identifier pi2 ON p.patient_id =pi2.patient_id
GROUP BY p.patient_id ;

DROP TABLE IF EXISTS patient_echo_encounters;
CREATE TABLE  patient_echo_encounters AS 
SELECT patient_id, encounter_id , encounter_datetime , encounter_type 
FROM encounter e 
WHERE encounter_type = @encounter_type_id
ORDER BY patient_id , encounter_datetime DESC;

CREATE OR REPLACE VIEW v_encounter_rank AS 
SELECT t.*,(
    SELECT COUNT(*)
    FROM patient_echo_encounters AS x
    WHERE x.patient_id = t.patient_id
    AND x.encounter_datetime > t.encounter_datetime
) + 1 AS erank
FROM patient_echo_encounters t
ORDER BY t.patient_id, erank;

-- ################# Insert Patients List ##################################################
INSERT INTO echo_summary_table (patient_id, emrid, age, sex, department, commune, locality, section_communal,heart_failure)
SELECT p.patient_id,emr_id ,
             age_at_enc(patient_id,latestEnc(patient_id , @encounter_type_name,null)), 
             gender(patient_id),
             pa.state_province,
             pa.city_village,
             pa.address1,pa.address3,
             CASE WHEN answerEverExists(p.patient_id,'PIH','3064','PIH','3468',null)=1 THEN TRUE ELSE FALSE END AS heart_failure
FROM patient_list p
INNER JOIN (SELECT person_id, state_province, city_village, address1, address3 
						FROM person_address
						GROUP BY person_id) pa ON p.patient_id=pa.person_id 
WHERE latestEnc(patient_id , @encounter_type_name,null) IS NOT NULL;

-- ############ Most recent encounter 1,2, and total encounters ##############################

UPDATE echo_summary_table t
SET t.echo_date_most_recent = (
SELECT cast(encounter_datetime AS date) FROM v_encounter_rank 
WHERE erank=1
AND patient_id = t.patient_id 
);

UPDATE echo_summary_table t
SET t.echo_date_prior = (
SELECT cast(encounter_datetime AS date) FROM v_encounter_rank 
WHERE erank=2
AND patient_id = t.patient_id 
LIMIT 1
);

UPDATE echo_summary_table t
SET t.total_echos = (
SELECT count(*) AS total_echos FROM v_encounter_rank 
WHERE  patient_id = t.patient_id 
GROUP BY patient_id 
);

-- ################ lvsf data #####################################

UPDATE echo_summary_table t 
SET t.lvsf_most_recent =(
SELECT obs_value_coded_list(encounter_id, 'PIH','11994','en')
FROM v_encounter_rank ver  
WHERE erank = 1
AND patient_id=t.patient_id);

UPDATE echo_summary_table t 
SET t.lvsf_prior =(
SELECT obs_value_coded_list(encounter_id, 'PIH','11994','en')
FROM v_encounter_rank ver  
WHERE erank = 2
AND patient_id=t.patient_id
LIMIT 1);

UPDATE echo_summary_table t 
SET t.lvsf_change =(
			CASE WHEN lvsf_most_recent IS NULL OR lvsf_prior IS NULL THEN 'Not Available'
			WHEN lvsf_most_recent LIKE '%impossible%' OR lvsf_prior LIKE '%impossible%' THEN 'Impossible to evaluate'
			WHEN lvsf_most_recent = lvsf_prior THEN 'No Change'
			WHEN (lvsf_most_recent LIKE '%normal%' AND lvsf_prior like '%very%low%') OR
			(lvsf_most_recent LIKE '%normal%' AND lvsf_prior like '%mildly%depressed%') OR 
			(lvsf_most_recent LIKE '%mildly%depressed%' AND lvsf_prior like '%very%low%') 
			THEN 'Improved'
			WHEN (lvsf_most_recent  LIKE '%very%low%' AND lvsf_prior  like '%normal%') 
			OR  (lvsf_most_recent  LIKE '%mildly%depressed%' AND lvsf_prior  like '%normal%')
			OR 	(lvsf_most_recent LIKE '%very%low%' AND lvsf_prior like '%mildly%depressed%') 
			THEN 'Reduced'
			END);


-- ################# Mitral Valve ########################################

UPDATE echo_summary_table t 
SET t.mitral_stenosis = CASE WHEN answerEverExists(t.patient_id,'PIH','11998','PIH','3175',null)=1 THEN TRUE ELSE FALSE END;

-- ################# NYHA ########################################
UPDATE echo_summary_table t 
SET t.nyha_class_most_recent =(
SELECT obs_value_coded_list(encounter_id, 'PIH','3139','en')
FROM v_encounter_rank ver  
WHERE erank=1
AND patient_id=t.patient_id);

-- ########## cardiomyopathy #############################################

UPDATE echo_summary_table t 
SET t.cardiomyopathy = CASE WHEN answerEverExists(t.patient_id,'PIH','11499','PIH','5016',null)=1 THEN TRUE ELSE FALSE END;

-- ########### beta_blocker | Dispensing ################################
set @med_name = concept_from_mapping ('PIH','1282');

set @atenolol = concept_from_mapping ('PIH','3186');


UPDATE echo_summary_table t 
SET t.beta_blocker_atenolol= (
select if(obs_id is null,FALSE,TRUE)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = @med_name
	and o.value_coded  = @atenolol
	limit 1);

UPDATE echo_summary_table t 
SET t.beta_blocker_atenolol= FALSE WHERE t.beta_blocker_atenolol IS NULL;

set @metoprolol = concept_from_mapping ('PIH','12491');

UPDATE echo_summary_table t 
SET t.beta_blocker_metoprolol = (
select if(obs_id is null,FALSE,TRUE)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = @med_name
	and o.value_coded  = @metoprolol
	limit 1);
UPDATE echo_summary_table t 
SET t.beta_blocker_metoprolol= FALSE WHERE t.beta_blocker_metoprolol IS NULL;

set @carvedilol = concept_from_mapping ('PIH','3185');

UPDATE echo_summary_table t 
SET t.beta_blocker_carvedilol = (
select CASE WHEN obs_id is NOT NULL THEN TRUE ELSE FALSE END
from obs o where o.voided =0 
	AND o.person_id =  t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id= t.patient_id)
	and o.concept_id = @med_name
	and o.value_coded  = @carvedilol
	limit 1);
UPDATE echo_summary_table t 
SET t.beta_blocker_carvedilol= FALSE WHERE t.beta_blocker_carvedilol IS NULL;

set @lisinopril = concept_from_mapping ('PIH','3183');
set @benzylpenicillin = concept_from_mapping ('PIH','12345');
set @benzathine = concept_from_mapping ('PIH','4034');

UPDATE echo_summary_table t 
SET t.penicillin  = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = @med_name
	and (o.value_coded  = @lisinopril
			OR o.value_coded  =  @benzylpenicillin 
			OR o.value_coded  = @benzathine) 
	limit 1);
UPDATE echo_summary_table t 
SET t.penicillin= FALSE WHERE t.penicillin IS NULL;

set @Phenoxymethylpenicillin = concept_from_mapping ('PIH','9185');
set @Enalapril_maleate = concept_from_mapping ('PIH','9230');
set @Enalapril = concept_from_mapping ('PIH','1242');
set @Hydrochlorothiazide_Losartan = concept_from_mapping ('PIH','13740');
set @Losartan = concept_from_mapping ('PIH','6769');
set @Valsartan = concept_from_mapping ('PIH','10601');
set @Lisinopril = concept_from_mapping ('PIH','3183');

UPDATE echo_summary_table t 
SET t.ace_inhibitor = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = @med_name
	and (o.value_coded  = @Phenoxymethylpenicillin 
			OR o.value_coded  = @Enalapril_maleate
			OR o.value_coded  = @Enalapril
			OR o.value_coded  = @Hydrochlorothiazide_Losartan
			OR o.value_coded  = @Losartan
			OR o.value_coded  = @Lisinopril
			OR o.value_coded  = @Valsartan) 
	limit 1);
UPDATE echo_summary_table t 
SET t.ace_inhibitor= FALSE WHERE t.ace_inhibitor IS NULL;

set @Spironolactone = concept_from_mapping ('PIH','4061');

UPDATE echo_summary_table t 
SET t.spironolactone = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = @med_name
	AND o.value_coded  = @Spironolactone
	limit 1);
UPDATE echo_summary_table t 
SET t.spironolactone= FALSE WHERE t.spironolactone IS NULL;

set @Hydralazine_hydrochloride = concept_from_mapping ('PIH','9084');

UPDATE echo_summary_table t 
SET t.hydralazine_hydrochloride = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = @med_name
	AND o.value_coded  = @Hydralazine_hydrochloride
	limit 1);
UPDATE echo_summary_table t 
SET t.hydralazine_hydrochloride= FALSE WHERE t.hydralazine_hydrochloride IS NULL;

set @Isosorbide_dinitrate = concept_from_mapping ('PIH','3428');

UPDATE echo_summary_table t 
SET t.isosorbide_dinitrate = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = @med_name
	AND o.value_coded  = @Isosorbide_dinitrate
	limit 1);
UPDATE echo_summary_table t 
SET t.isosorbide_dinitrate= FALSE WHERE t.isosorbide_dinitrate IS NULL;

set @hydrochlorothiazide = concept_from_mapping ('PIH','1243');
set @LASIX = concept_from_mapping ('PIH','99');

UPDATE echo_summary_table t 
SET t.diuretic = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = @med_name
	AND (o.value_coded  = @hydrochlorothiazide
	OR o.value_coded  = @LASIX 
	)
	limit 1);
UPDATE echo_summary_table t 
SET t.diuretic= FALSE WHERE t.diuretic IS NULL;

set @Amlodipine_besylate = concept_from_mapping ('PIH','9083');
set @Nifedipine = concept_from_mapping ('PIH','250');

UPDATE echo_summary_table t 
SET t.calcium_channel_blocker = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = @med_name
	AND (o.value_coded  = @Amlodipine_besylate
	OR o.value_coded  = @Nifedipine
	)
	limit 1);
UPDATE echo_summary_table t 
SET t.calcium_channel_blocker= FALSE WHERE t.calcium_channel_blocker IS NULL;

-- ############## Follow Up Echo ################################

UPDATE echo_summary_table t 
SET t.follow_up_echo = CASE WHEN period_diff(date_format(echo_date_most_recent , '%Y%m'), date_format(echo_date_prior, '%Y%m')) < 24 THEN TRUE ELSE FALSE END;

-- ############## bp Symbolic most recent #######################################
UPDATE echo_summary_table t 
SET t.bp_systolic_most_recent =(
SELECT obs_value_numeric(encounter_id, 'PIH','5085')
FROM v_encounter_rank ver  
WHERE erank=1
AND patient_id=t.patient_id);

-- ############## bp diastolic most recent #######################################
UPDATE echo_summary_table t 
SET t.bp_diastolic_most_recent  =(
SELECT obs_value_numeric(encounter_id, 'PIH','5086')
FROM v_encounter_rank ver  
WHERE erank=1
AND patient_id=t.patient_id);

-- ############### dm1, dm2 #################################################################
set @type_1_diabetes = concept_from_mapping ('PIH','6691');
set @diagnosis = concept_from_mapping ('PIH','3064');
set @diabetes_set = concept_from_mapping ('PIH','11501');
set @type_2_diabetes = concept_from_mapping ('PIH','6692');
set @type_2_diabetes_oral_hypoglycemic = concept_from_mapping ('PIH','12228');
set @type_2_diabetes_insulin_dependant = concept_from_mapping ('PIH','11943');
set @type_2_diabetes_without_hypoglycemic = concept_from_mapping ('PIH','12227');
set @type_2_diabetes_requiring_insulin = concept_from_mapping ('PIH','12251');

UPDATE echo_summary_table t 
SET t.dm1 =(
		SELECT 
		CASE WHEN value_coded =@type_1_diabetes THEN TRUE ELSE FALSE END
						from obs o2
		            where o2.voided = 0
		          AND o2.person_id =  t.patient_id
		            and o2.concept_id = @diagnosis  -- diagnosis question
		                and concept_in_set(o2.value_coded, @diabetes_set)=1
		                LIMIT 1
		                );
		               
UPDATE echo_summary_table t 
SET t.dm2 =(
		SELECT 
				CASE WHEN value_coded IN (@type_2_diabetes,
													@type_2_diabetes_oral_hypoglycemic,
													@type_2_diabetes_insulin_dependant,
													@type_2_diabetes_without_hypoglycemic,
													@type_2_diabetes_requiring_insulin
													) THEN TRUE ELSE FALSE END 
					from obs o2
		            where o2.voided = 0
		          AND o2.person_id =  t.patient_id
		            and o2.concept_id = @diagnosis  -- diagnosis question
		                and concept_in_set(o2.value_coded, @diabetes_set)=1
		                LIMIT 1
		           );

		          
UPDATE echo_summary_table 
SET dm1=FALSE
WHERE dm1 IS NULL ;

UPDATE echo_summary_table 
SET dm2=FALSE
WHERE dm2 IS NULL ;

-- ################# Hypertension ####################################################

set @pre_hypertension = concept_from_mapping('PIH','12697');
set @mild_hypertension = concept_from_mapping('PIH','12698');
set @hypertensive_crisis = concept_from_mapping('PIH','8885');
set @hypertension = concept_from_mapping('PIH','903');
set @uncontrolled_hypertension = concept_from_mapping('PIH','12629');
set @severe_uncontrolled_hypertension= concept_from_mapping('PIH','12634');

UPDATE echo_summary_table t 
SET t.hypertension =(
			SELECT MAX(CASE WHEN value_coded in (@pre_hypertension,@mild_hypertension,@hypertensive_crisis,@hypertension,@uncontrolled_hypertension,@severe_uncontrolled_hypertension)
			      THEN TRUE ELSE FALSE END) AS 'Hypertension'
			from obs o
			where  o.voided = 0
			AND o.person_id =t.patient_id
			GROUP BY person_id
);

UPDATE echo_summary_table 
SET hypertension=FALSE WHERE hypertension IS NULL;

-- ################# asthma ####################################################

set @intermittent_asthma = concept_from_mapping('PIH','7401');
set @moderate_persistent_asthma = concept_from_mapping('PIH','7400');
set @severe_persistent_asthma = concept_from_mapping('PIH','7402');
set @mild_persistent_asthma = concept_from_mapping('PIH','7403');
set @severe_uncontrolled_asthma = concept_from_mapping('PIH','7404');
set @asthma = concept_from_mapping('PIH','5');
set @severe_asthma = concept_from_mapping('PIH','13541');
set @asthma_exacerbation = concept_from_mapping('PIH','4');
set @mild_intermittent_asthma = concept_from_mapping('PIH','7953');
set @asthma_night_symptoms = concept_from_mapping('PIH','11731');

UPDATE echo_summary_table t 
SET t.asthma =(
			SELECT MAX(CASE WHEN value_coded in (@intermittent_asthma,	@moderate_persistent_asthma,	@severe_persistent_asthma,	@mild_persistent_asthma,	@severe_uncontrolled_asthma,	@asthma,	@severe_asthma,	@asthma_exacerbation,	@mild_intermittent_asthma,	@asthma_night_symptoms)
			      THEN TRUE ELSE FALSE END) AS 'Hypertension'
			from obs o
			where  o.voided = 0
			AND o.person_id =t.patient_id
			GROUP BY person_id
);

UPDATE echo_summary_table 
SET asthma=FALSE WHERE asthma IS NULL;


-- ################# sickle_cell ####################################################
set @sickle_cell_anemia = concept_from_mapping('PIH','7908');
set @sickle_cell_anemia_with_crisis = concept_from_mapping('PIH','8573');
set @sickle_cell_anemia_without_crisis = concept_from_mapping('PIH','8570');

UPDATE echo_summary_table t 
SET t.sickle_cell =(
			SELECT MAX(CASE WHEN value_coded in ( @sickle_cell_anemia,  @sickle_cell_anemia_with_crisis, @sickle_cell_anemia_without_crisis)
			      THEN TRUE ELSE FALSE END) AS 'Hypertension'
			from obs o
			where  o.voided = 0
			AND o.person_id =t.patient_id
			GROUP BY person_id
);

UPDATE echo_summary_table 
SET sickle_cell=FALSE WHERE sickle_cell IS NULL;


-- ################# copd ####################################################
set @copd = concept_from_mapping('PIH','3716');

UPDATE echo_summary_table t 
SET t.copd =(
			SELECT MAX(CASE WHEN value_coded=@copd
			      THEN TRUE ELSE FALSE END) AS 'Hypertension'
			from obs o
			where  o.voided = 0
			AND o.person_id =t.patient_id
			GROUP BY person_id
);

UPDATE echo_summary_table 
SET copd=FALSE WHERE copd IS NULL;

-- ############ ncd_comorbidity ################################################
UPDATE echo_summary_table t 
SET t.ncd_comorbidity = CASE WHEN ( dm1 IS TRUE OR
                                                               dm2 IS TRUE OR
                                                               hypertension  IS TRUE OR
                                                               asthma  IS TRUE OR
                                                               sickle_cell  IS TRUE OR
                                                               copd  IS TRUE) THEN TRUE ELSE FALSE  END;
DROP TABLE patient_echo_encounters;

SELECT 
patient_id , 
emrid , 
age ,
sex ,
department ,
commune ,
section_communal ,
locality ,
heart_failure ,
echo_date_most_recent ,
echo_date_prior ,
total_echos ,
lvsf_most_recent ,
lvsf_prior ,
lvsf_change ,
mitral_stenosis,
nyha_class_most_recent ,
cardiomyopathy ,
beta_blocker_atenolol ,
beta_blocker_metoprolol ,
beta_blocker_carvedilol ,
ace_inhibitor ,
penicillin ,
spironolactone ,
hydralazine_hydrochloride ,
isosorbide_dinitrate ,
diuretic ,
calcium_channel_blocker ,
follow_up_echo ,
bp_systolic_most_recent ,
bp_diastolic_most_recent ,
ncd_comorbidity ,
dm1,
dm2,
hypertension ,
asthma ,
sickle_cell ,
copd
FROM echo_summary_table;
