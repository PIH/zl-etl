SELECT name  INTO @encounter_type_name FROM encounter_type et WHERE et.uuid ='fdee591e-78ba-11e9-8f9e-2a86e4085a59';
SELECT encounter_type_id  INTO @encounter_type_id FROM encounter_type et WHERE et.uuid ='fdee591e-78ba-11e9-8f9e-2a86e4085a59';
SELECT encounter_type_id INTO @dis_encounter_id FROM encounter_type et2 WHERE et2.uuid ='8ff50dea-18a1-4609-b4c9-3f8f2d611b84';

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
			(lvsf_most_recent LIKE '%normal%' AND lvsf_prior like '%mildly%depressed%')
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

UPDATE echo_summary_table t 
SET t.beta_blocker_atenolol= (
select if(obs_id is null,FALSE,TRUE)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = concept_from_mapping('PIH','1282')
	and o.value_coded  = concept_from_mapping('PIH','3186') 
	limit 1);

UPDATE echo_summary_table t 
SET t.beta_blocker_atenolol= FALSE WHERE t.beta_blocker_atenolol IS NULL;


UPDATE echo_summary_table t 
SET t.beta_blocker_metoprolol = (
select if(obs_id is null,FALSE,TRUE)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = concept_from_mapping('PIH','1282')
	and o.value_coded  = concept_from_mapping('PIH','12491')
	limit 1);
UPDATE echo_summary_table t 
SET t.beta_blocker_metoprolol= FALSE WHERE t.beta_blocker_metoprolol IS NULL;

UPDATE echo_summary_table t 
SET t.beta_blocker_carvedilol = (
select CASE WHEN obs_id is NOT NULL THEN TRUE ELSE FALSE END
from obs o where o.voided =0 
	AND o.person_id =  t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id= t.patient_id)
	and o.concept_id = concept_from_mapping('PIH','1282')
	and o.value_coded  = concept_from_mapping('PIH','3185')
	limit 1);
UPDATE echo_summary_table t 
SET t.beta_blocker_carvedilol= FALSE WHERE t.beta_blocker_carvedilol IS NULL;


UPDATE echo_summary_table t 
SET t.penicillin  = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = concept_from_mapping('PIH','1282')
	and (o.value_coded  = concept_from_mapping('PIH','3183') 
			OR o.value_coded  = concept_from_mapping('PIH','12345')
			OR o.value_coded  = concept_from_mapping('PIH','4034')) 
	limit 1);
UPDATE echo_summary_table t 
SET t.penicillin= FALSE WHERE t.penicillin IS NULL;


UPDATE echo_summary_table t 
SET t.ace_inhibitor = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = concept_from_mapping('PIH','1282')
	and (o.value_coded  = concept_from_mapping('PIH','9185') 
			OR o.value_coded  = concept_from_mapping('PIH','9230')
			OR o.value_coded  = concept_from_mapping('PIH','1242')
			OR o.value_coded  = concept_from_mapping('PIH','13740')
			OR o.value_coded  = concept_from_mapping('PIH','10601')
			OR o.value_coded  = concept_from_mapping('PIH','6769')
			OR o.value_coded  = concept_from_mapping('PIH','10601')) 
	limit 1);
UPDATE echo_summary_table t 
SET t.ace_inhibitor= FALSE WHERE t.ace_inhibitor IS NULL;


UPDATE echo_summary_table t 
SET t.spironolactone = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = concept_from_mapping('PIH','1282')
	AND o.value_coded  = concept_from_mapping('PIH','4061') 
	limit 1);
UPDATE echo_summary_table t 
SET t.spironolactone= FALSE WHERE t.spironolactone IS NULL;


UPDATE echo_summary_table t 
SET t.hydralazine_hydrochloride = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = concept_from_mapping('PIH','1282')
	AND o.value_coded  = concept_from_mapping('PIH','9084') 
	limit 1);
UPDATE echo_summary_table t 
SET t.hydralazine_hydrochloride= FALSE WHERE t.hydralazine_hydrochloride IS NULL;


UPDATE echo_summary_table t 
SET t.isosorbide_dinitrate = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = concept_from_mapping('PIH','1282')
	AND o.value_coded  = concept_from_mapping('PIH','3428') 
	limit 1);
UPDATE echo_summary_table t 
SET t.isosorbide_dinitrate= FALSE WHERE t.isosorbide_dinitrate IS NULL;

UPDATE echo_summary_table t 
SET t.diuretic = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = concept_from_mapping('PIH','1282')
	AND (o.value_coded  = concept_from_mapping('PIH','1243') 
	OR o.value_coded  = concept_from_mapping('PIH','99') 
	)
	limit 1);
UPDATE echo_summary_table t 
SET t.diuretic= FALSE WHERE t.diuretic IS NULL;


UPDATE echo_summary_table t 
SET t.calcium_channel_blocker = (
select if(obs_id is null,0,1)
from obs o where o.voided =0 
	AND o.person_id = t.patient_id 
	AND o.encounter_id IN (SELECT encounter_id FROM encounter e WHERE encounter_type =@dis_encounter_id AND patient_id=t.patient_id)
	and o.concept_id = concept_from_mapping('PIH','1282')
	AND (o.value_coded  = concept_from_mapping('PIH','9083') 
	OR o.value_coded  = concept_from_mapping('PIH','250') 
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
UPDATE echo_summary_table t 
SET t.dm1 =(
		SELECT 
		CASE WHEN value_coded =concept_from_mapping ('PIH','6691') THEN TRUE ELSE FALSE END
						from obs o2
		            where o2.voided = 0
		          AND o2.person_id =  t.patient_id
		            and o2.concept_id = concept_from_mapping('PIH','3064')  -- diagnosis question
		                and concept_in_set(o2.value_coded, concept_from_mapping('PIH','11501'))=1
		                LIMIT 1
		                );
		               
UPDATE echo_summary_table t 
SET t.dm2 =(
		SELECT 
				CASE WHEN value_coded IN (concept_from_mapping ('PIH','6692'),
													concept_from_mapping('PIH','12228'),
													concept_from_mapping('PIH','11943'),
													concept_from_mapping('PIH','12227'),
													concept_from_mapping('PIH','12251')
													) THEN TRUE ELSE FALSE END 
					from obs o2
		            where o2.voided = 0
		          AND o2.person_id =  t.patient_id
		            and o2.concept_id = concept_from_mapping('PIH','3064')  -- diagnosis question
		                and concept_in_set(o2.value_coded, concept_from_mapping('PIH','11501'))=1
		                LIMIT 1
		           );

		          
UPDATE echo_summary_table 
SET dm1=FALSE
WHERE dm1 IS NULL ;

UPDATE echo_summary_table 
SET dm2=FALSE
WHERE dm2 IS NULL ;

-- ################# Hypertension ####################################################

UPDATE echo_summary_table t 
SET t.hypertension =(
			SELECT MAX(CASE WHEN (
			                                             value_coded=concept_from_mapping('PIH','12697')  OR
			                                             value_coded=concept_from_mapping('PIH','12698')  OR
			                                             value_coded=concept_from_mapping('PIH','8885')  OR
			                                             value_coded=concept_from_mapping('PIH','903')  OR
			                                             value_coded=concept_from_mapping('PIH','12629')  OR
			                                             value_coded=concept_from_mapping('PIH','12634')
			                                             )
			      THEN TRUE ELSE FALSE END) AS 'Hypertension'
			from obs o
			where  o.voided = 0
			AND o.person_id =t.patient_id
			GROUP BY person_id
);

UPDATE echo_summary_table 
SET hypertension=FALSE WHERE hypertension IS NULL;

-- ################# asthma ####################################################

UPDATE echo_summary_table t 
SET t.asthma =(
			SELECT MAX(CASE WHEN (
			                                             value_coded=concept_from_mapping('PIH','7401')  OR
			                                             value_coded=concept_from_mapping('PIH','7403')  OR
			                                             value_coded=concept_from_mapping('PIH','7400')  OR
			                                             value_coded=concept_from_mapping('PIH','7402')  OR
			                                             value_coded=concept_from_mapping('PIH','7404')  OR
			                                             value_coded=concept_from_mapping('PIH','5') OR
			                                             value_coded=concept_from_mapping('PIH','13541') OR
			                                              value_coded=concept_from_mapping('PIH','4') OR
			                                              value_coded=concept_from_mapping('PIH','7403') OR
			                                              value_coded=concept_from_mapping('PIH','7953') OR 
			                                               value_coded=concept_from_mapping('PIH','11731')
			                                             )
			      THEN TRUE ELSE FALSE END) AS 'Hypertension'
			from obs o
			where  o.voided = 0
			AND o.person_id =t.patient_id
			GROUP BY person_id
);

UPDATE echo_summary_table 
SET asthma=FALSE WHERE asthma IS NULL;


-- ################# sickle_cell ####################################################

UPDATE echo_summary_table t 
SET t.sickle_cell =(
			SELECT MAX(CASE WHEN (
			                                             value_coded=concept_from_mapping('PIH','7908')  OR
			                                             value_coded=concept_from_mapping('PIH','8573')  OR
			                                             value_coded=concept_from_mapping('PIH','8570')
			                                             )
			      THEN TRUE ELSE FALSE END) AS 'Hypertension'
			from obs o
			where  o.voided = 0
			AND o.person_id =t.patient_id
			GROUP BY person_id
);

UPDATE echo_summary_table 
SET sickle_cell=FALSE WHERE sickle_cell IS NULL;


-- ################# copd ####################################################

UPDATE echo_summary_table t 
SET t.copd =(
			SELECT MAX(CASE WHEN (
			                                             value_coded=concept_from_mapping('PIH','3716')
			                                             )
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
