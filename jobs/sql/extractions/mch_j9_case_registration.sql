-- set @maxMonthsEnrolled = null;
SET @partition = '${partitionNum}';

set @minEnrollmentDate = if(@maxMonthsEnrolled is null, null, date_sub(now(), INTERVAL @maxMonthsEnrolled MONTH));

select program_workflow_id into @MCH_treatment from program_workflow pw where uuid = '41a277d0-8a14-11e8-9a94-a6cf71072f73';
select program_id into @matHealthProgram from program where uuid = '41a2715e-8a14-11e8-9a94-a6cf71072f73';
select concept_id into @mothersGroup from concept where uuid = 'c1b2db38-8f72-4290-b6ad-99826734e37e';
select concept_id into @edd from concept where uuid = '3cee56a6-26fe-102b-80cb-0017a47871b2';
select concept_id into @add from concept where uuid = '5599AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
select relationship_type_id into @aParentToB from relationship_type  where uuid = '8d91a210-c2cc-11de-8d13-0010c6dffd0f' ;
select person_attribute_type_id into @tele from person_attribute_type pat where pat.uuid =  '14d4f066-15f5-102d-96e4-000c29c2a5d7';
select encounter_type_id into @obgynEncId from encounter_type et where uuid = 'd83e98fd-dc7b-420f-aa3f-36f648b4483d' ;
select encounter_type_id into @delEncId from encounter_type et  where uuid = '00e5ebb2-90ec-11e8-9eb6-529269fb1459' ;
-- SET @locale = ifnull(@locale, GLOBAL_PROPERTY_VALUE('default_locale', 'en'));

drop TEMPORARY TABLE IF EXISTS temp_J9_patients;
create temporary table temp_J9_patients
(
    patient_id int(11),
    patient_program_id int(11),
    patient_uuid char(38),
    given_name varchar(50),
    family_name varchar(50),
    ZL_identifier varchar(50),
    Dossier_identifier varchar(50),
    J9_group text,
    J9_program varchar(50),
    telephone varchar(50),
    birthdate date,
    age int(3),
    estimated_delivery_date date,
    actual_delivery_date date,
    mama_dossier varchar(50),
    department varchar(255),
    commune varchar(255),
    section_communal varchar(255),
    locality varchar(255),
    street_landmark varchar(255),
    j9_enrollment_date date
);

insert into temp_J9_patients (patient_id, patient_program_id, j9_enrollment_date)
select pp.patient_id, pp.patient_program_id , date(pp.date_enrolled)  from patient_program pp
where pp.patient_program_id =
         	(select pp2.patient_program_id from patient_program pp2
         	where pp2.patient_id = pp.patient_id 
         	and pp2.program_id = @matHealthProgram 
         	and pp2.voided = 0  
         	and pp2.date_completed is null
         	and (@minEnrollmentDate is null or pp2.date_enrolled >= @minEnrollmentDate)
         	order by pp2.date_enrolled desc limit 1);

create index temp_J9_patients_pi on temp_J9_patients(patient_id);

-- delete patients who are dead
delete t from temp_J9_patients t
inner join person p on p.person_id = t.patient_id
where p.dead = 1;

-- load all relevant encounters (for use later to narrow down observations)
drop temporary table if exists temp_j9_enc;
create temporary table temp_j9_enc
select e.encounter_id  from encounter e
inner join temp_J9_patients t on t.patient_id = e.patient_id 
where e.encounter_type in ( @obgynEncId, @delEncId)
and e.voided = 0;

-- uuid, age,  birthdate
update temp_J9_patients t
inner join person p on p.person_id = t.patient_id
	set t.patient_uuid = p.uuid,
		t.birthdate = p.birthdate;

update temp_J9_patients t
set t.age = TIMESTAMPDIFF(YEAR,t.birthdate, now());

-- program state
update temp_J9_patients t
set t.J9_program = currentProgramState(t.patient_program_id,@MCH_treatment,'en');

-- telephone number
update temp_J9_patients t
set t.telephone = phone_number(t.patient_id);

-- patient address
update temp_J9_patients t
set department = person_address_state_province(t.patient_id);

update temp_J9_patients t
set commune = person_address_city_village(t.patient_id);

update temp_J9_patients t
set section_communal = person_address_three(t.patient_id);

update temp_J9_patients t
set locality = person_address_one(t.patient_id);

update temp_J9_patients t
set street_landmark = person_address_two(t.patient_id);

-- identifiers
update temp_J9_patients t
set t.ZL_identifier =  zlEMR(t.patient_id);

update temp_J9_patients t
set t.Dossier_identifier =  dosId(t.patient_id);

-- patient name
update temp_J9_patients t
set given_name = person_given_name(t.patient_id);

update temp_J9_patients t
set family_name = person_family_name(t.patient_id);

   
-- ------------- latest mothers group -------------------------
DROP TEMPORARY TABLE IF EXISTS temp_mg_obs;
create temporary table temp_mg_obs 
select o.obs_id, o.person_id, o.obs_datetime 
from obs o
inner join temp_j9_enc t on t.encounter_id = o.encounter_id
where o.voided = 0
and o.concept_id = @mothersGroup; 

create index temp_mg_obs_ci on temp_mg_obs(person_id, obs_datetime);

update temp_J9_patients t
inner join obs o on o.obs_id =
	(select o2.obs_id from temp_mg_obs o2
	where o2.person_id = t.patient_id
	order by o2.obs_datetime desc limit 1)
set t.J9_group = o.value_text;

-- ------------- latest expected delivery date -------------------------
DROP TEMPORARY TABLE IF EXISTS temp_edd_obs;
create temporary table temp_edd_obs 
select o.obs_id, o.person_id, o.obs_datetime 
from obs o
inner join temp_j9_enc t on t.encounter_id = o.encounter_id
where o.voided = 0
and o.concept_id = @edd;

create index temp_edd_obs_ci on temp_edd_obs(person_id, obs_datetime);

update temp_J9_patients t
inner join obs o on o.obs_id =
	(select o2.obs_id from temp_edd_obs o2
	where o2.person_id = t.patient_id
	order by o2.obs_datetime desc limit 1)
set t.estimated_delivery_date = date(o.value_datetime);

-- ------------- latest actual delivery date -------------------------
DROP TEMPORARY TABLE IF EXISTS temp_add_obs;
create temporary table temp_add_obs 
select o.obs_id, o.person_id, o.obs_datetime 
from obs o
inner join temp_j9_enc t on t.encounter_id = o.encounter_id
where o.voided = 0
and o.concept_id = @add;

create index temp_add_obs_ci on temp_add_obs(person_id, obs_datetime);

update temp_J9_patients t
inner join obs o on o.obs_id =
	(select o2.obs_id from temp_add_obs o2
	where o2.person_id = t.patient_id
	order by o2.obs_datetime desc limit 1)
set t.actual_delivery_date = date(o.value_datetime);

-- Baby's mother: return dossier id of mother (parent who is female) if the patient is < 1 year
update temp_J9_patients t
    left outer join relationship rm on rm.person_b = t.patient_id and rm.voided = 0 and rm.relationship = @aParentToB
        and gender(rm.person_a) = 'F'
        and  TIMESTAMPDIFF(YEAR,t.birthdate, now()) < 1
-- mother's dossier id
set t.mama_dossier = dosId(rm.person_a);

select
    if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',patient_id),patient_id) "patient_id",
    patient_uuid,
    given_name,
    family_name,
    ZL_identifier,
    Dossier_identifier,
    J9_group,
    J9_program,
    telephone,
    birthdate,
    age,
    estimated_delivery_date,
    actual_delivery_date,
    mama_dossier,
    department,
    commune,
    section_communal,
    locality,
    street_landmark,
    j9_enrollment_date
from temp_J9_patients;
