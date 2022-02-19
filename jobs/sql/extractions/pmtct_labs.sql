-- set @locale = 'en';  -- uncomment for testing

select encounter_type_id into @labResults from encounter_type et where uuid = '4d77916a-0620-11e5-a6c0-1697f925ec7b';
select encounter_type_id into @labSpecimen from encounter_type et where uuid = '39C09928-0CAB-4DBA-8E48-39C631FA4286';
select program_id into @hivProgram from program where uuid = 'b1cb1fc1-5190-4f7a-af08-48870975dafc';
select program_workflow_state_id into @patientPregnantState 
from program_workflow_state where uuid = '5da5fa62-ef9f-4f15-9b58-d23136c2907b';

select concept_class_id into @testClass from concept_class cc where uuid = '8d4907b2-c2cc-11de-8d13-0010c6dffd0f';

/*
 This creates a reference table of patients in the PMTCT program 
 and the dates they were in that program
*/
drop temporary table if exists temp_pmtct_patients;
create temporary table temp_pmtct_patients
select pp.patient_id, ps.start_date, ps.end_date from patient_program pp 
inner join patient_state ps on ps.patient_program_id = pp.patient_program_id 
where pp.program_id = @hivProgram
and ps.state = @patientPregnantState;

-- this pulls all lab encounters for patients in pmtct program
drop temporary table if exists temp_lab_encounters;
create temporary table temp_lab_encounters
select e.encounter_id from encounter e
inner join temp_pmtct_patients t 
	on t.patient_id = e.patient_id 
	and (t.start_date <= e.encounter_datetime and (e.encounter_datetime <= t.end_date or t.end_date is null))
where e.encounter_type in (@labResults,@labSpecimen)
and e.voided = 0;

-- this pulls all the obs for the encounters above
drop temporary table if exists temp_lab_obs;
create temporary table temp_lab_obs
select  o.obs_id , o.encounter_id ,o.person_id, o.obs_datetime ,o.concept_id, o.value_coded, o.value_numeric, o.value_text, o.date_created, o.creator from obs o
inner join temp_lab_encounters t on t.encounter_id = o.encounter_id 
where o.voided = 0
and concept_class_id(o.concept_id) = @testClass;

-- this creates a table with all of those obs decoded and the index_asc created
drop temporary table if exists temp_labs_1;
create temporary table temp_labs_1 (
patient_id int(11),
obs_id int(11),
encounter_id int(11),
test_type varchar(255),
test_date datetime,
test_result_date datetime,
coded_result varchar(255),
numeric_result double,
text_result text,
date_created datetime,
creator int,
index_asc int,
index_desc int)
;
set @r = 0;
insert into temp_labs_1(index_asc,patient_id,obs_id,encounter_id,test_type,test_date,coded_result, numeric_result,text_result,date_created,creator)
select 
@r:= IF(@p = person_id, @r + 1,1) 'index_asc',
@p:=t.person_id as patient_id,
t.obs_id,
t.encounter_id,
concept_name(t.concept_id,@locale),
t.obs_datetime,
concept_name(t.value_coded,'en'),
t.value_numeric, 
t.value_text,
t.date_created,
t.creator
from temp_lab_obs t
order by patient_id asc, obs_datetime asc, obs_id asc  ;

-- this updates the result date (if it exists)
update temp_labs_1 t 
set test_result_date = obs_value_datetime(encounter_id,'PIH','3267' );

-- this creates a new table with the index desc added
set @r = 0;
drop temporary table if exists temp_labs_2;
create temporary table temp_labs_2
select 
@r:= IF(@p = patient_id, @r + 1,1) as index_desc,
@p:=t.patient_id as patient_id,
t.obs_id,
t.encounter_id,
t.test_type,
t.test_date,
t.test_result_date,
COALESCE (coded_result, numeric_result, text_result) as test_result,
t.date_created,
t.creator,
t.index_asc
from temp_labs_1 t
order by patient_id asc, test_date desc, obs_id desc;

-- final output
select 
patient_id,
zlemr(patient_id),
test_date,
test_result_date,
test_type,
test_result,
date_created as date_entered,
username(creator) as user_entered,
index_asc,
index_desc
from temp_labs_2
order by patient_id asc, index_asc asc;
