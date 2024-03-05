
-- --------------- Variables ----------------------------
set @partition = '${partitionNum}';
SELECT 'a541af1e-105c-40bf-b345-ba1fd6a59b85' INTO @emr_identifier_type;
SELECT 'e66645eb-03a8-4991-b4ce-e87318e37566' INTO @doss_identifier_type;
SELECT '3B954DB1-0D41-498E-A3F9-1E20CCC47323' INTO @hiv_identifier_type;

select encounter_type_id  into @reg_type_id 
from encounter_type et where uuid='873f968a-73a8-4f9c-ac78-9f4778b751b6';


-- ------------------------- Get Fresh Data ---------------------------------------

DROP TABLE IF EXISTS all_patients;
CREATE TEMPORARY TABLE  all_patients
(
patient_id int, 
emr_id varchar(50),
hiv_emr_id varchar(50),
dossier_id varchar(50),
reg_location varchar(50),
reg_date date,
user_entered varchar(50),
first_encounter_date date,
last_encounter_date date, 
name varchar(50),
family_name varchar(50),
dob date,
dob_estimated bit,
gender varchar(2),
dead bit,
death_date date,
cause_of_death varchar(100)
);

-- ---------- Temp tables ----------------
drop table if exists tbl_first_enc;
create temporary table tbl_first_enc
SELECT
    e.patient_id AS patient_id,
    min(e.encounter_datetime) AS encounter_datetime
FROM
    openmrs.encounter e
GROUP BY
    e.patient_id;
 
drop table if exists tbl_first_enc_details;
create temporary table tbl_first_enc_details
SELECT
    DISTINCT e.patient_id AS patient_id,
    e.encounter_datetime AS encounter_datetime,
    e.encounter_id AS encounter_id,
    e.encounter_type AS encounter_type,
    encounter_creator_name(encounter_id) AS username,
    encounter_location_name(encounter_id) AS name
FROM
    encounter e
INNER JOIN tbl_first_enc X ON
    X.patient_id = e.patient_id
        AND X.encounter_datetime = e.encounter_datetime;
        
-- --------- Identifications --------------------------------------------------------

INSERT INTO all_patients (patient_id) 
SELECT DISTINCT  p.patient_id
FROM patient p
where p.voided=0
;

UPDATE all_patients t
SET emr_id = patient_identifier(patient_id, @emr_identifier_type),
hiv_emr_id = patient_identifier(patient_id, @hiv_identifier_type),
dossier_id = patient_identifier(patient_id, @doss_identifier_type);


-- --------- Registeration --------------------------------------------------------

UPDATE all_patients
SET reg_location= loc_registered(patient_id),
reg_date=registration_date(patient_id);

drop table if exists tmp_first_enc_date;
create temporary table tmp_first_enc_date as
select min(cast(encounter_datetime as date)) as encounter_date, patient_id
from encounter e 
where encounter_type <>  @reg_type_id
group by patient_id;

drop table if exists tmp_last_enc_date;
create temporary table tmp_last_enc_date as
select max(cast(encounter_datetime as date)) as encounter_date, patient_id
from encounter e 
group by patient_id;

UPDATE all_patients dp
inner join
 (
	select patient_id,encounter_date
	from tmp_first_enc_date
) x
on dp.patient_id= x.patient_id
set first_encounter_date =x.encounter_date;


UPDATE all_patients dp
inner join 
 (
	select patient_id,encounter_date
	from tmp_last_enc_date
) x 
on dp.patient_id= x.patient_id
set dp.last_encounter_date=x.encounter_date;

update all_patients dp 
inner join
(
	select patient_id, name, cast(encounter_datetime as date) encdate
	from tbl_first_enc_details 
) x 
on dp.patient_id= x.patient_id
set dp.reg_location = x.name,
dp.reg_date = x.encdate
where dp.reg_location is null;

update all_patients dp 
inner join (
	select patient_id,username
	from tbl_first_enc_details 
) x 
on dp.patient_id= x.patient_id
set dp.user_entered = x.username;

-- --------- Demographical ---------------------------------------------------------

UPDATE all_patients t
INNER JOIN (
SELECT person_id,given_name,family_name FROM person_name 
WHERE voided=0 
) pn ON t.patient_id =pn.person_id 
SET t.name=pn.given_name, 
	t.family_name=pn.family_name;

-- -------------------- Bio Information -----------------------

UPDATE all_patients t
SET t.dob= birthdate(t.patient_id),
t.gender=gender(t.patient_id);


UPDATE all_patients t
SET t.dead=dead(patient_id),
t.death_date=death_date(patient_id),
t.cause_of_death=concept_name(cause_of_death(patient_id),'en');

UPDATE all_patients t
SET t.first_encounter_date=reg_date
WHERE t.first_encounter_date IS NULL AND t.reg_date IS NOT NULL;

UPDATE all_patients t
SET t.reg_date=first_encounter_date
WHERE t.first_encounter_date IS NOT NULL AND t.reg_date IS NULL;

SELECT 
emr_id,
hiv_emr_id,
dossier_id,
reg_location,
reg_date,
user_entered,
first_encounter_date,
last_encounter_date,
name,
family_name,
dob,
dob_estimated,
gender,
dead,
death_date,
cause_of_death
FROM all_patients;