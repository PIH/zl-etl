CREATE TABLE mch_diagnoses
(
	patient_id  int,
	encounter_id int,
	encounter_location  varchar(255),
	obs_id  int,
	obs_datetime datetime,
	visit_id int,
	encounter_type varchar(100),
	entered_by varchar(255),
	provider varchar(255),
	diagnosis_concept int,
	diagnosis_entered   text,
	diagnosis_coded_fr	varchar(255),
	icd10_code			varchar(255),
	dx_order			varchar(255),
	certainty			varchar(255),
	coded				varchar(255),
	retrospective		int(1),
	date_created		datetime,
	abortion bit,
	abortion_with_sepsis bit,
	anemia bit,
	cervical_cancer bit,
	cervical_laceration bit,
	complete_abortion bit,
	diabetes int,
	dystocia bit,
	eclampsia bit,
	hemorrhage bit,
	hypertension bit,
	incomplete_abortion bit,
	induced_abortion bit,
	postpartum_hemorrhage bit,
	laceration_of_perineum bit,
	malaria bit,
	postnatal_complication bit,
	preeclampsia bit,
	puerperal_infection bit,
	spontaneous_abortion bit,
	sti bit,
	threatened_abortion bit
);