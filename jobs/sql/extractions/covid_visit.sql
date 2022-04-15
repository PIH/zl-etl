#### This report covid visit report
#### observation comes from the covid admission and covid followup forms

## sql updates
SET sql_safe_updates = 0;
SET SESSION group_concat_max_len = 100000;

-- Delete temporary covid encounter table if exists
DROP TEMPORARY TABLE IF EXISTS temp_covid_visit;

-- create temporary tale temp_covid_encounters
CREATE TEMPORARY TABLE temp_covid_visit
(
	encounter_id                  INT PRIMARY KEY,
	encounter_type_id             INT,
	patient_id                    INT,
	encounter_date                DATE,
	encounter_type                VARCHAR(255),
	location                      TEXT,
    date_entered                  DATETIME,
    user_entered                  VARCHAR(50),
	case_condition                VARCHAR(255),
	overall_condition             VARCHAR(255),
	fever                         VARCHAR(11),
	cough                         VARCHAR(11),
	productive_cough              VARCHAR(11),
	shortness_of_breath           VARCHAR(11),
	sore_throat                   VARCHAR(11),
	rhinorrhea                    VARCHAR(11),
	headache                      VARCHAR(11),
	chest_pain                    VARCHAR(11),
	muscle_pain                   VARCHAR(11),
	fatigue                       VARCHAR(11),
	vomiting                      VARCHAR(11),
	diarrhea                      VARCHAR(11),
	loss_of_taste                 VARCHAR(11),
	sense_of_smell_loss           VARCHAR(11),
	confusion                     VARCHAR(11),
	panic_attack                  VARCHAR(11),
	suicidal_thoughts             VARCHAR(11),
	attempted_suicide             VARCHAR(11),
	other_symptom                 TEXT,
	temp                          DOUBLE,
	heart_rate                    DOUBLE,
	respiratory_rate              DOUBLE,
	bp_systolic                   DOUBLE,
	bp_diastolic                  DOUBLE,
	SpO2                          DOUBLE,
	room_air                      VARCHAR(11),
	cap_refill                    VARCHAR(100),
	cap_refill_time               DOUBLE,
	pain                          VARCHAR(50),
	general_exam                  VARCHAR(11),
	general_findings              TEXT,
	heent                         VARCHAR(11),
	heent_findings                TEXT,
	neck                          VARCHAR(11),
	neck_findings                 TEXT,
	chest                         VARCHAR(11),
	chest_findings                TEXT,
	cardiac                       VARCHAR(11),
	cardiac_findings              TEXT,
	abdominal                     VARCHAR(11),
	abdominal_findings            TEXT,
	urogenital                    VARCHAR(11),
	urogenital_findings           TEXT,
	rectal                        VARCHAR(11),
	rectal_findings               TEXT,
	musculoskeletal               VARCHAR(11),
  	musculoskeletal_findings      TEXT,
  	lymph                         VARCHAR(11),
  	lymph_findings                TEXT,
  	skin                          VARCHAR(11),
  	skin_findings                 TEXT,
  	neuro                         VARCHAR(11),
  	neuro_findings                TEXT,
 	avpu                          VARCHAR(255),
  	other_findings                TEXT,
  	medications                   VARCHAR(255),
  	medication_comments           TEXT,
  	supportive_care               TEXT,
  	o2therapy                     DOUBLE,
  	analgesic_specified           VARCHAR(255),
  	awake                         VARCHAR(11),
	pain_response                 VARCHAR(11),
	voice_response                VARCHAR(11),
	unresponsive                  VARCHAR(11),
	dexamethasone                 VARCHAR(11),
	remdesivir                    VARCHAR(11),
	lpv_r                         VARCHAR(11),
	ceftriaxone                   VARCHAR(11),
	amoxicillin                   VARCHAR(11),
	doxycycline                   VARCHAR(11),
	other_medication              TEXT,
	oxygen                        VARCHAR(11),
	ventilator                    VARCHAR(11),
	mask                          VARCHAR(11),
	mask_with_nonbreather         VARCHAR(11),
	nasal_cannula                 VARCHAR(11),
	cpap                          VARCHAR(11),
	bpap                          VARCHAR(11),
	fio2                          VARCHAR(11),
	ivf_fluid                     VARCHAR(11),
	hemoglobin                    DOUBLE,
	hematocrit                    DOUBLE,
	wbc                           DOUBLE,
	platelets                     DOUBLE,
	lymphocyte                    DOUBLE,
	neutrophil                    DOUBLE,
	crp                           DOUBLE,
	sodium                        DOUBLE,
	potassium                     DOUBLE,
	urea                          DOUBLE,
	creatinine                    DOUBLE,
	glucose                       DOUBLE,
	bilirubin                     DOUBLE,
	sgpt                          DOUBLE,
	sgot                          DOUBLE,
	pH                            DOUBLE,
	pcO2                          DOUBLE,
	pO2                           DOUBLE,
	tcO2                          DOUBLE,
	hcO3                          DOUBLE,
	be                            DOUBLE,
	sO2                           DOUBLE,
	lactate                       DOUBLE,
	x_ray                         VARCHAR(11),
	cardiac_ultrasound            VARCHAR(11),
	abdominal_ultrasound          VARCHAR(11),
	clinical_management_plan      TEXT,
	nursing_note                  TEXT,
	mh_referral                   VARCHAR(11),
	mh_note_obs_group_id		  INT(11),
	mh_note                       TEXT
);

-- insert into temp_covid_visit
INSERT INTO temp_covid_visit
(
	encounter_id,
	encounter_type_id,
	patient_id,
	encounter_date,
	location,
    date_entered,
    user_entered
)
SELECT
	encounter_id,
	encounter_type,
	patient_id,
	DATE(encounter_datetime),
	ENCOUNTER_LOCATION_NAME(encounter_id),
    date_created,
    creator
FROM
	encounter
WHERE
	voided = 0
	AND encounter_type IN (ENCOUNTER_TYPE('COVID-19 Admission'), ENCOUNTER_TYPE('COVID-19 Progress'))
;

DROP TEMPORARY TABLE IF EXISTS temp_covid_obs;
create temporary table temp_covid_obs 
select o.obs_id, o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime
from obs o
inner join temp_covid_visit t on t.encounter_id = o.encounter_id
where o.voided = 0;

create index temp_covid_obs_concept_id on temp_covid_obs(concept_id);
create index temp_covid_obs_ei on temp_covid_obs(encounter_id);

UPDATE temp_covid_visit tc LEFT JOIN encounter_type et ON tc.encounter_type_id = et.encounter_type_id
SET encounter_type = et.name;

## Delet test patients
DELETE FROM temp_covid_visit
WHERE
patient_id IN (SELECT
a.person_id
FROM
person_attribute a
INNER JOIN
person_attribute_type t ON a.person_attribute_type_id = t.person_attribute_type_id
WHERE
a.value = 'true'
AND t.name = 'Test Patient');

### COVID 19 admission
-- case condition
-- UPDATE temp_covid_visit SET case_condition = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '159640', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '159640')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.case_condition = i.ret;


### COVID 19 Progress FORM
-- overall_condition
-- UPDATE temp_covid_visit SET overall_condition = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '159640', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '159640')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.overall_condition = i.ret;

-- Fever
-- UPDATE temp_covid_visit SET fever = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'PIH', 'FEVER');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('PIH', 'FEVER')
set fever = if(o.concept_id is null, null,'1' );

-- cough
-- UPDATE temp_covid_visit SET cough = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'PIH', 'COUGH');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('PIH', 'COUGH')
set cough = if(o.concept_id is null, null,'1' );

-- cough
-- UPDATE temp_covid_visit SET productive_cough = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'PIH', 'PRODUCTIVE COUGH');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('PIH', 'PRODUCTIVE COUGH')
set productive_cough = if(o.concept_id is null, null,'1' );

-- shortness of breath
-- UPDATE temp_covid_visit SET shortness_of_breath = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'CIEL', '141600');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping( 'CIEL', '141600')
set shortness_of_breath = if(o.concept_id is null, null,'1' );

-- sore_throat
-- UPDATE temp_covid_visit SET sore_throat = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'CIEL', '158843');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('CIEL', '158843')
set sore_throat = if(o.concept_id is null, null,'1' );

-- rhinorrhea
-- UPDATE temp_covid_visit SET rhinorrhea = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'CIEL', '165501');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('CIEL', '165501')
set rhinorrhea = if(o.concept_id is null, null,'1' );

-- headache
-- UPDATE temp_covid_visit SET headache = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'PIH', 'HEADACHE');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('PIH', 'HEADACHE')
set headache = if(o.concept_id is null, null,'1' );

-- chest pain
-- UPDATE temp_covid_visit SET chest_pain = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'PIH', 'CHEST PAIN');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('PIH', 'FEVER')
set fever = if(o.concept_id is null, null,'1' );

-- muscle pain
-- UPDATE temp_covid_visit SET muscle_pain = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'PIH', 'MUSCLE PAIN');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('PIH', 'MUSCLE PAIN')
set muscle_pain = if(o.concept_id is null, null,'1' );

-- fatigue
-- UPDATE temp_covid_visit SET fatigue = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'PIH', 'FATIGUE');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('PIH', 'FATIGUE')
set fatigue = if(o.concept_id is null, null,'1' );

-- nausea and vomiting concept_id 3318 instead of 2530
-- UPDATE temp_covid_visit SET vomiting = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'CIEL', '133473');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('CIEL', '133473')
set vomiting = if(o.concept_id is null, null,'1' );

-- diarrhea
-- UPDATE temp_covid_visit SET diarrhea = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'PIH', 'DIARRHEA');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('PIH', 'DIARRHEA')
set diarrhea = if(o.concept_id is null, null,'1' );

-- loss of taste
-- UPDATE temp_covid_visit SET loss_of_taste = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'CIEL', '135588');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('CIEL', '135588')
set loss_of_taste = if(o.concept_id is null, null,'1' );

-- loss of sense of smell
-- UPDATE temp_covid_visit SET sense_of_smell_loss = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'CIEL', '135589');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('CIEL', '135589')
set sense_of_smell_loss = if(o.concept_id is null, null,'1' );

-- loss of sense of smell
-- UPDATE temp_covid_visit SET sense_of_smell_loss = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'CIEL', '135589');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('CIEL', '135589')
set sense_of_smell_loss = if(o.concept_id is null, null,'1' );

-- confusion
-- UPDATE temp_covid_visit SET confusion = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'PIH', 'CONFUSION');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('PIH', 'CONFUSION')
set confusion = if(o.concept_id is null, null,'1' );

-- panic attack
-- UPDATE temp_covid_visit SET panic_attack  = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'CIEL', '130967');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping( 'CIEL', '130967')
set panic_attack = if(o.concept_id is null, null,'1' );

-- suicidal thoughts
-- UPDATE temp_covid_visit SET suicidal_thoughts = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'CIEL', '125562');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping('CIEL', '125562')
set suicidal_thoughts = if(o.concept_id is null, null,'1' );

-- attempted suicide
-- UPDATE temp_covid_visit SET attempted_suicide  = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1728', 'CIEL', '148143');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '1728')
	and o.value_coded = concept_from_mapping( 'CIEL', '148143')
set attempted_suicide = if(o.concept_id is null, null,'1' );



-- Symptom name, uncoded (text)
-- UPDATE temp_covid_visit SET other_symptom = OBS_VALUE_TEXT(encounter_id, 'CIEL', '165996');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '165996')
set t.other_symptom = o.value_text
;


-- vitals
-- UPDATE temp_covid_visit SET temp = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '5088');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '5088')
set t.temp = o.value_numeric
;

-- UPDATE temp_covid_visit SET heart_rate = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '5087');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '5087')
set t.heart_rate = o.value_numeric
;

-- UPDATE temp_covid_visit SET respiratory_rate = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '5242');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '5242')
set t.respiratory_rate = o.value_numeric
;

-- UPDATE temp_covid_visit SET bp_systolic = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '5085');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '5085')
set t.bp_systolic = o.value_numeric
;

-- UPDATE temp_covid_visit SET bp_diastolic = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '5086');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '5086')
set t.bp_diastolic = o.value_numeric
;

-- UPDATE temp_covid_visit SET SpO2 = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '5092');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '5092')
set t.SpO2 = o.value_numeric
;

-- room air
-- UPDATE temp_covid_visit SET room_air = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '162739', 'CIEL', '162735');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '162739')
	and o.value_coded = concept_from_mapping('CIEL', '162735')
set room_air = if(o.concept_id is null, null,'1' );


-- Cap refill and Cap refill time
-- UPDATE temp_covid_visit SET cap_refill = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '165890', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '165890')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.cap_refill = i.ret;

-- UPDATE temp_covid_visit SET cap_refill_time = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '162513');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '162513')
set t.cap_refill_time = o.value_numeric
;

-- Pain
-- UPDATE temp_covid_visit SET pain = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '166000', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '166000')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.pain = i.ret;


########## Phyical Exams
-- UPDATE temp_covid_visit SET general_exam = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '1119', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '1119')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.general_exam = i.ret;

-- UPDATE temp_covid_visit SET general_findings = OBS_VALUE_TEXT(encounter_id, 'CIEL', '163042');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '163042')
set t.general_findings = o.value_text;

-- HEENT
-- UPDATE temp_covid_visit SET heent = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '1122', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '1122')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.heent = i.ret;

-- UPDATE temp_covid_visit SET heent_findings = OBS_VALUE_TEXT(encounter_id, 'CIEL', '163045');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '163045')
set t.heent_findings = o.value_text;

-- Neck
-- UPDATE temp_covid_visit SET neck = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '163388', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '163388')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.neck = i.ret;

-- UPDATE temp_covid_visit SET neck_findings = OBS_VALUE_TEXT(encounter_id, 'CIEL', '165983');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '165983')
set t.neck_findings = o.value_text
;

-- chest
-- UPDATE temp_covid_visit SET chest = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '1123', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '1123')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.chest = i.ret;

-- UPDATE temp_covid_visit SET chest_findings = OBS_VALUE_TEXT(encounter_id, 'CIEL', '160689');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '160689')
set t.chest_findings = o.value_text
;

-- cardiac
-- UPDATE temp_covid_visit SET cardiac = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '1124', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '1124')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.cardiac = i.ret;

-- UPDATE temp_covid_visit SET cardiac_findings = OBS_VALUE_TEXT(encounter_id, 'CIEL', '163046');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '163046')
set t.cardiac_findings = o.value_text
;

-- abdominal
-- UPDATE temp_covid_visit SET abdominal = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '1125', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '1125')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.abdominal = i.ret;

-- UPDATE temp_covid_visit SET abdominal_findings = OBS_VALUE_TEXT(encounter_id, 'CIEL', '160947');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '160947')
set t.abdominal_findings = o.value_text
;

-- urogenital
-- UPDATE temp_covid_visit SET urogenital = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '1126', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '1126')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.urogenital = i.ret;

-- UPDATE temp_covid_visit SET urogenital_findings = OBS_VALUE_TEXT(encounter_id, 'CIEL', '163047');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '163047')
set t.urogenital_findings = o.value_text
;

-- rectal
-- UPDATE temp_covid_visit SET rectal = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '163746', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '163746')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.rectal = i.ret;

-- UPDATE temp_covid_visit SET rectal_findings = OBS_VALUE_TEXT(encounter_id, 'CIEL', '160961');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '160961')
set t.rectal_findings = o.value_text
;

-- musculoskeletal
-- UPDATE temp_covid_visit SET musculoskeletal = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '1128', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '1128')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.musculoskeletal = i.ret;

-- UPDATE temp_covid_visit SET musculoskeletal_findings = OBS_VALUE_TEXT(encounter_id, 'CIEL', '163048');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '163048')
set t.musculoskeletal_findings = o.value_text
;

-- lymph
-- UPDATE temp_covid_visit SET lymph = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '1121', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '1121')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.lymph = i.ret;

-- UPDATE temp_covid_visit SET lymph_findings = OBS_VALUE_TEXT(encounter_id, 'CIEL', '166005');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '166005')
set t.lymph_findings = o.value_text
;

-- skin
-- UPDATE temp_covid_visit SET skin = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '1120', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '1120')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.skin = i.ret;

-- UPDATE temp_covid_visit SET skin_findings = OBS_VALUE_TEXT(encounter_id, 'CIEL', '160981');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '160981')
set t.skin_findings = o.value_text
;

-- neuro
-- UPDATE temp_covid_visit SET neuro = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '1129', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '1129')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.neuro = i.ret;

-- UPDATE temp_covid_visit SET neuro_findings = OBS_VALUE_TEXT(encounter_id, 'CIEL', '163109');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '163109')
set t.neuro_findings = o.value_text
;

-- avpu
-- UPDATE temp_covid_visit SET avpu = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '162643', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '162643')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.avpu = i.ret;

-- other
-- UPDATE temp_covid_visit SET other_findings = OBS_VALUE_TEXT(encounter_id, 'CIEL', '163042');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '163045')
set t.heent_findings = o.value_text
;

-- Awake
-- UPDATE temp_covid_visit SET awake = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '162643', 'CIEL', '160282');

update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '162643')
	and o.value_coded = concept_from_mapping('CIEL', '160282')
set awake = if(o.concept_id is null, null,'1' );


-- Responds to pain
-- UPDATE temp_covid_visit SET pain_response = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '162643', 'CIEL', '162644');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '162643')
	and o.value_coded = concept_from_mapping('CIEL', '162644')
set pain_response = if(o.concept_id is null, null,'1' )
;


-- Responds to voice
-- UPDATE temp_covid_visit SET voice_response = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '162643', 'CIEL', '162645');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '162643')
	and o.value_coded = concept_from_mapping('CIEL', '162645')
set voice_response = if(o.concept_id is null, null,'1' )
;

-- Unresponsive
-- UPDATE temp_covid_visit SET unresponsive = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '162643', 'CIEL', '159508');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('CIEL', '162643')
	and o.value_coded = concept_from_mapping('CIEL', '159508')
set unresponsive = if(o.concept_id is null, null,'1' )
;

-- dexamethasone
-- UPDATE temp_covid_visit SET dexamethasone = OBS_SINGLE_VALUE_CODED(encounter_id, 'PIH', 'Medication Orders', 'PIH', 'Dexamethasone');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('PIH', 'Medication Orders')
	and o.value_coded = concept_from_mapping('PIH', 'Dexamethasone')
set dexamethasone = if(o.concept_id is null, null,'1' )
;

-- lpv/r
-- UPDATE temp_covid_visit SET lpv_r = OBS_SINGLE_VALUE_CODED(encounter_id, 'PIH', 'Medication Orders', 'CIEL', '794');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('PIH', 'Medication Orders')
	and o.value_coded = concept_from_mapping('CIEL', '794')
set lpv_r = if(o.concept_id is null, null,'1' )
;

-- remdesivir
-- UPDATE temp_covid_visit SET remdesivir = OBS_SINGLE_VALUE_CODED(encounter_id, 'PIH', 'Medication Orders', 'CIEL', '165878');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('PIH', 'Medication Orders')
	and o.value_coded = concept_from_mapping('CIEL', '165878')
set remdesivir = if(o.concept_id is null, null,'1' )
;

-- ceftriaxone
-- UPDATE temp_covid_visit SET ceftriaxone = OBS_SINGLE_VALUE_CODED(encounter_id, 'PIH', 'Medication Orders', 'PIH', 'CEFTRIAXONE');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('PIH', 'Medication Orders')
	and o.value_coded = concept_from_mapping('PIH', 'CEFTRIAXONE')
set ceftriaxone = if(o.concept_id is null, null,'1' )
;

-- amoxicillin
-- UPDATE temp_covid_visit SET amoxicillin = OBS_SINGLE_VALUE_CODED(encounter_id, 'PIH', 'Medication Orders', 'PIH', 'AMOXICILLIN');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('PIH', 'Medication Orders')
	and o.value_coded = concept_from_mapping('PIH', 'AMOXICILLIN')
set amoxicillin = if(o.concept_id is null, null,'1' )
;
-- doxycycline
-- UPDATE temp_covid_visit SET doxycycline = OBS_SINGLE_VALUE_CODED(encounter_id, 'PIH', 'Medication Orders', 'PIH', 'DOXYCYCLINE');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('PIH', 'Medication Orders')
	and o.value_coded = concept_from_mapping('PIH', 'DOXYCYCLINE')
set doxycycline = if(o.concept_id is null, null,'1' )
;
-- other_medication
-- UPDATE temp_covid_visit SET other_medication = OBS_VALUE_TEXT(encounter_id, 'PIH', 'Medication comments (text)');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('PIH', 'Medication comments (text)')
set t.other_medication = o.value_text
;

-- supportive care
-- UPDATE temp_covid_visit SET supportive_care = OBS_VALUE_CODED_LIST(encounter_id, 'CIEL', '165995', 'en');
update temp_covid_visit t 
inner join 
	(select o.encounter_id, GROUP_CONCAT(distinct  concept_name(o.value_coded,'en') separator ' | ') as ret
	from temp_covid_obs o
	where o.concept_id = concept_from_mapping('CIEL', '165995')
	group by o.encounter_id) i on i.encounter_id = t.encounter_id
set t.supportive_care = i.ret;

-- o2therapy value
-- UPDATE temp_covid_visit SET o2therapy = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '165986');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping( 'CIEL', '165986')
set t.o2therapy = o.value_numeric
;


-- analgesic comments/description
-- UPDATE temp_covid_visit SET analgesic_specified = OBS_VALUE_TEXT(encounter_id, 'CIEL', '163206');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping( 'CIEL', '163206')
set t.analgesic_specified = o.value_numeric
;

-- oxygen
-- UPDATE temp_covid_visit SET oxygen = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '165995', 'CIEL', '81341');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping( 'CIEL', '165995')
	and o.value_coded = concept_from_mapping('CIEL', '81341')
set oxygen = if(o.concept_id is null, null,'1' )
;


-- ventilator
-- UPDATE temp_covid_visit SET ventilator = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '165995', 'CIEL', '165998');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping( 'CIEL', '165995')
	and o.value_coded = concept_from_mapping('CIEL', '165998')
set ventilator = if(o.concept_id is null, null,'1' )
;

-- mask
-- UPDATE temp_covid_visit SET mask = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '165995', 'CIEL', '165989');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping( 'CIEL', '165995')
	and o.value_coded = concept_from_mapping('CIEL', '165989')
set mask = if(o.concept_id is null, null,'1' )
;
-- mask with non breather
-- UPDATE temp_covid_visit SET mask_with_nonbreather = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '165995', 'CIEL', '165990');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping( 'CIEL', '165995')
	and o.value_coded = concept_from_mapping('CIEL', '165990')
set mask_with_nonbreather = if(o.concept_id is null, null,'1' )
;
-- nasal cannula
-- UPDATE temp_covid_visit SET nasal_cannula = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '165995', 'CIEL', '165893');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping( 'CIEL', '165995')
	and o.value_coded = concept_from_mapping('CIEL', '165893')
set nasal_cannula = if(o.concept_id is null, null,'1' )
;
-- cpap
-- UPDATE temp_covid_visit SET cpap = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '165995', 'CIEL', '165944');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping( 'CIEL', '165995')
	and o.value_coded = concept_from_mapping('CIEL', '165944')
set cpap = if(o.concept_id is null, null,'1' )
;
-- bpap
-- UPDATE temp_covid_visit SET bpap = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '165995', 'CIEL', '165988');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping( 'CIEL', '165995')
	and o.value_coded = concept_from_mapping('CIEL', '165988')
set bpap = if(o.concept_id is null, null,'1' )
;
-- fio2
-- UPDATE temp_covid_visit SET fio2 = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '165995', 'CIEL', '165927');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping( 'CIEL', '165995')
	and o.value_coded = concept_from_mapping('CIEL', '165927')
set fio2 = if(o.concept_id is null, null,'1' )
;
-- ivf fluid
-- UPDATE temp_covid_visit SET ivf_fluid = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '165995', 'CIEL', '161911');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping( 'CIEL', '165995')
	and o.value_coded = concept_from_mapping('CIEL', '161911')
set ivf_fluid = if(o.concept_id is null, null,'1' )
;
##### Lab Results 
-- UPDATE temp_covid_visit SET hemoglobin = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '21');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '21')
set t.hemoglobin = o.value_numeric
;

-- UPDATE temp_covid_visit SET hematocrit = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '1015');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '1015')
set t.hematocrit = o.value_numeric
;
-- UPDATE temp_covid_visit SET wbc = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '678');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '678')
set t.wbc = o.value_numeric
;
-- UPDATE temp_covid_visit SET platelets = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '729');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '729')
set t.platelets = o.value_numeric
;
-- UPDATE temp_covid_visit SET lymphocyte = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '952');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '952')
set t.lymphocyte = o.value_numeric
;
-- UPDATE temp_covid_visit SET neutrophil = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '1330');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '1330')
set t.neutrophil = o.value_numeric
;
-- UPDATE temp_covid_visit SET crp = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '161500');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '161500')
set t.crp = o.value_numeric
;
-- UPDATE temp_covid_visit SET sodium = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '1132');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '1132')
set t.sodium = o.value_numeric
;
-- UPDATE temp_covid_visit SET potassium = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '1133');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '1133')
set t.potassium = o.value_numeric
;
-- UPDATE temp_covid_visit SET urea = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '857'); 
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '857')
set t.urea = o.value_numeric
;
-- UPDATE temp_covid_visit SET creatinine = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '790');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '790')
set t.creatinine = o.value_numeric
;
-- UPDATE temp_covid_visit SET glucose = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '887');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '887')
set t.temp = o.value_numeric
;
-- UPDATE temp_covid_visit SET bilirubin = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '655');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '655')
set t.glucose = o.value_numeric
;
-- UPDATE temp_covid_visit SET sgpt = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '654');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '654')
set t.sgpt = o.value_numeric
;
-- UPDATE temp_covid_visit SET sgot = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '653');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '653')
set t.sgot = o.value_numeric
;
-- UPDATE temp_covid_visit SET pH = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '165984');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '165984')
set t.pH = o.value_numeric
;
-- UPDATE temp_covid_visit SET pcO2 = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '163595');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '163595')
set t.pcO2 = o.value_numeric
;
-- UPDATE temp_covid_visit SET pO2 = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '163598');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '163598')
set t.pO2 = o.value_numeric
;
-- UPDATE temp_covid_visit SET tcO2 = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '166002');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '166002')
set t.tcO2 = o.value_numeric
;
-- UPDATE temp_covid_visit SET hcO3 = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '163596');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '163596')
set t.hcO3 = o.value_numeric
;
-- UPDATE temp_covid_visit SET be = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '163599');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '163599')
set t.be = o.value_numeric
;
-- UPDATE temp_covid_visit SET sO2 = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '163597');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '163597')
set t.sO2 = o.value_numeric
;
-- UPDATE temp_covid_visit SET lactate = OBS_VALUE_NUMERIC(encounter_id, 'CIEL', '165997');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '165997')
set t.lactate = o.value_numeric
;
-- clinical management plan
-- UPDATE temp_covid_visit te SET clinical_management_plan = OBS_VALUE_TEXT(encounter_id, 'CIEL', '162749');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '162749')
set t.clinical_management_plan = o.value_text
;
-- nursing note
-- UPDATE temp_covid_visit SET nursing_note = OBS_VALUE_TEXT(encounter_id, 'CIEL', '166021');
update temp_covid_visit t 
inner join temp_covid_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('CIEL', '166021')
set t.nursing_note = o.value_text
;
-- mh referral
-- UPDATE temp_covid_visit SET mh_referral = OBS_SINGLE_VALUE_CODED(encounter_id, 'CIEL', '1272', 'PIH', '5489');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping( 'CIEL', '1272')
	and o.value_coded = concept_from_mapping('PIH', '5489')
set mh_referral = if(o.concept_id is null, null,'1' )
;
-- mh note
-- UPDATE temp_covid_visit SET mh_note =  OBS_FROM_GROUP_ID_VALUE_TEXT(OBS_ID(encounter_id,'PIH','12837',0), 'CIEL', '161011');

update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id
	and o.concept_id = concept_from_mapping('PIH','12837')
set t.mh_note_obs_group_id = o.obs_id;

update temp_covid_visit t
inner join temp_covid_obs o on o.obs_group_id = t.mh_note_obs_group_id
	and o.concept_id = concept_from_mapping('PIH','161011')
set t.mh_note = o.value_text
;
-- Chest x-ray
-- UPDATE temp_covid_visit SET x_ray = OBS_SINGLE_VALUE_CODED(encounter_id, 'PIH', '9485', 'PIH', 'Chest 1 view (XRay)');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('PIH', '9485')
	and o.value_coded = concept_from_mapping('PIH', 'Chest 1 view (XRay)')
set x_ray = if(o.concept_id is null, null,'1' )
;
-- Cardiac ultrasound
-- UPDATE temp_covid_visit SET cardiac_ultrasound = OBS_SINGLE_VALUE_CODED(encounter_id, 'PIH', '9485', 'PIH', 'Transthoracic echocardiogram');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('PIH', '9485')
	and o.value_coded = concept_from_mapping('PIH', 'Transthoracic echocardiogram')
set cardiac_ultrasound = if(o.concept_id is null, null,'1' )
;

-- Abdominal ultrasound
-- UPDATE temp_covid_visit SET abdominal_ultrasound = OBS_SINGLE_VALUE_CODED(encounter_id, 'PIH', '9485', 'PIH', 'Abdomen (US)');
update temp_covid_visit t
inner join temp_covid_obs o on o.encounter_id = t.encounter_id 
	and o.concept_id = concept_from_mapping('PIH', '9485')
	and o.value_coded = concept_from_mapping('PIH', 'Abdomen (US)')
set abdominal_ultrasound = if(o.concept_id is null, null,'1' )
;
-- index ascending
DROP TEMPORARY TABLE IF EXISTS temp_index_asc;
CREATE TEMPORARY TABLE temp_index_asc
(
			SELECT  
            patient_id,
			encounter_id,
			index_asc
FROM (SELECT  
             @r:= IF(@u = patient_id, @r + 1,1) index_asc,
             encounter_id,
             patient_id,
			 @u:= patient_id
            FROM temp_covid_visit,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id, encounter_id ASC
        ) index_ascending );
  
-- index descending
DROP TEMPORARY TABLE IF EXISTS temp_index_desc;
CREATE TEMPORARY TABLE temp_index_desc
(
			SELECT  
            patient_id,
			encounter_id,
			index_desc 
FROM (SELECT  
             @r:= IF(@u = patient_id, @r + 1,1) index_desc,
             encounter_id,
             patient_id,
			 @u:= patient_id
            FROM temp_covid_visit,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id, encounter_id DESC
        ) index_descending );
       
create index temp_index_asc_ei on temp_index_asc(encounter_id);
create index temp_index_desc_ei on temp_index_desc(encounter_id);

#### Final query
SELECT
        tcv.patient_id patient_id,
        tcv.encounter_id encounter_id,
        encounter_date,
        location,
        encounter_type,
        date_entered,
        user_entered,
        case_condition,
	      overall_condition,
        IF(fever like "%Yes%", 1, NULL)	                fever,
        IF(cough like "%Yes%", 1, NULL)	                cough,
        IF(productive_cough	like "%Yes%", 1, NULL)      productive_cough,
        IF(shortness_of_breath like "%Yes%", 1, NULL)   shortness_of_breath,
        IF(sore_throat like "%Yes%", 1, NULL)           sore_throat,
        IF(rhinorrhea like "%Yes%", 1, NULL)            rhinorrhea,
        IF(headache like "%Yes%", 1, NULL)              headache,
        IF(chest_pain like "%Yes%", 1, NULL)            chest_pain,
        IF(muscle_pain like "%Yes%", 1, NULL)           muscle_pain,
        IF(fatigue like "%Yes%", 1, NULL)               fatigue,
        IF(vomiting like "%Yes%", 1, NULL)              vomiting,
        IF(diarrhea like "%Yes%", 1, NULL)              diarrhea,
        IF(loss_of_taste like "%Yes%", 1, NULL)         loss_of_taste,
        IF(sense_of_smell_loss like "%Yes%", 1, NULL)   sense_of_smell_loss,
        IF(confusion like "%Yes%", 1, NULL)             confusion,
        IF(panic_attack like "%Yes%", 1, NULL)          panic_attack,
        IF(suicidal_thoughts like "%Yes%", 1, NULL)     suicidal_thoughts,
        IF(attempted_suicide like "%Yes%", 1, NULL)     attempted_suicide,
        other_symptom,
        temp,
        heart_rate,
        respiratory_rate,
        bp_systolic,
        bp_diastolic,
        SpO2,
        IF(room_air like "%Yes%", 1, NULL)              room_air,
        cap_refill,
        cap_refill_time,
        pain,
        general_exam,
        general_findings,
        heent,
        heent_findings,
        neck,
        neck_findings,
        chest,
        chest_findings,
        cardiac,
        cardiac_findings,
        abdominal,
        abdominal_findings,
        urogenital,
        urogenital_findings,
        rectal,
        rectal_findings,
        musculoskeletal,
        musculoskeletal_findings,
        lymph,
        lymph_findings,
        skin,
        skin_findings,
        neuro,
        neuro_findings,
        avpu,
        IF(awake like "%Yes%", 1, NULL) awake,
        IF(pain_response like "%Yes%", 1, NULL)             pain_response,
        IF(voice_response like "%Yes%", 1, NULL)            voice_response,
        IF(unresponsive like "%Yes%", 1, NULL)              unresponsive,
        IF(other_findings like "%Yes%", 1, NULL)            other_findings,
        IF(dexamethasone like "%Yes%", 1, NULL)             dexamethasone,
        IF(remdesivir like "%Yes%", 1, NULL)                remdesivir,
        IF(lpv_r like "%Yes%", 1, NULL)                     lpv_r,
        IF(ceftriaxone like "%Yes%", 1, NULL)               ceftriaxone,
        IF(amoxicillin like "%Yes%", 1, NULL)               amoxicillin,
        IF(doxycycline like "%Yes%", 1, NULL)               doxycycline,
        other_medication,
        IF(oxygen like "%Yes%", 1, NULL)                    oxygen,
        IF(ventilator like "%Yes%", 1, NULL)                ventilator,
        IF(mask like "%Yes%", 1, NULL)                      mask,
        IF(mask_with_nonbreather like "%Yes%", 1, NULL)     mask_with_nonbreather,
        IF(nasal_cannula like "%Yes%", 1, NULL)             nasal_cannula,
        IF(cpap like "%Yes%", 1, NULL)                      cpap,
        IF(bpap like "%Yes%", 1, NULL)                      bpap,
        IF(fio2 like "%Yes%", 1, NULL)                      fio2,
        IF(ivf_fluid like "%Yes%", 1, NULL)                 ivf_fluid,
        hemoglobin,
        hematocrit,
        wbc,
        platelets,
        lymphocyte,
        neutrophil,
        crp,
        sodium,
        potassium,
        urea,
        creatinine,
        glucose,
        bilirubin,
        sgpt,
        sgot,
        pH,
        pcO2,
        pO2,
        tcO2,
        hcO3,
        be,
        sO2,
        lactate,
        IF(x_ray like "%Yes%", 1, NULL)                     x_ray,
        IF(cardiac_ultrasound like "%Yes%", 1, NULL)        cardiac_ultrasound,
        IF(abdominal_ultrasound like "%Yes%", 1, NULL)      abdominal_ultrasound,
        clinical_management_plan,
        nursing_note,
        IF(mh_referral like "%Yes%", 1, NULL)               mh_referral,
        mh_note,
        index_asc,
        index_desc
FROM temp_covid_visit tcv
-- index ascending
LEFT JOIN temp_index_asc on tcv.encounter_id = temp_index_asc.encounter_id
-- index descending
LEFT JOIN temp_index_desc on tcv.encounter_id = temp_index_desc.encounter_id
order by tcv.patient_id, tcv.encounter_id ASC;
