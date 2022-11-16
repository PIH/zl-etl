-- --------------- Variables ----------------------------
SELECT patient_identifier_type_id INTO @identifier_type FROM patient_identifier_type pit WHERE uuid ='a541af1e-105c-40bf-b345-ba1fd6a59b85';
SELECT patient_identifier_type_id INTO @doss_identifier_type FROM patient_identifier_type pit WHERE uuid ='e66645eb-03a8-4991-b4ce-e87318e37566';
SELECT patient_identifier_type_id INTO @hiv_identifier_type FROM patient_identifier_type pit WHERE uuid ='139766e8-15f5-102d-96e4-000c29c2a5d7';
select encounter_type_id into @reg_type_id from encounter_type et where uuid='873f968a-73a8-4f9c-ac78-9f4778b751b6';

SELECT name  INTO @etype_echo_name FROM encounter_type et WHERE et.uuid ='fdee591e-78ba-11e9-8f9e-2a86e4085a59';
SELECT encounter_type_id  INTO @etype_echo_id FROM encounter_type et WHERE et.uuid ='fdee591e-78ba-11e9-8f9e-2a86e4085a59';

SELECT name  INTO @etype_ncdinit_name FROM encounter_type et WHERE et.uuid ='ae06d311-1866-455b-8a64-126a9bd74171';
SELECT encounter_type_id  INTO @etype_ncdinit_id FROM encounter_type et WHERE et.uuid ='ae06d311-1866-455b-8a64-126a9bd74171';
SELECT name  INTO @etype_ncdf_name FROM encounter_type et WHERE et.uuid ='5cbfd6a2-92d9-4ad0-b526-9d29bfe1d10c';
SELECT encounter_type_id  INTO @etype_ncdf_id FROM encounter_type et WHERE et.uuid ='5cbfd6a2-92d9-4ad0-b526-9d29bfe1d10c';

SELECT name  INTO @etype_hivinit_name FROM encounter_type et WHERE et.uuid ='c31d306a-40c4-11e7-a919-92ebcb67fe33';
SELECT encounter_type_id  INTO @etype_hivinit_id FROM encounter_type et WHERE et.uuid ='c31d306a-40c4-11e7-a919-92ebcb67fe33';
SELECT name  INTO @etype_hivf_name FROM encounter_type et WHERE et.uuid ='c31d3312-40c4-11e7-a919-92ebcb67fe33';
SELECT encounter_type_id  INTO @etype_hivf_id FROM encounter_type et WHERE et.uuid ='c31d3312-40c4-11e7-a919-92ebcb67fe33';

-- ------------------------- Get Fresh Data ---------------------------------------

DROP TABLE IF EXISTS dim_patients;
CREATE TABLE  dim_patients (
emr_id varchar(50),
hiv_emr_id varchar(50),
dossier_number varchar(50),
patient_id int, 
reg_location varchar(50),
reg_date date,
fist_encounter_date date,
last_encounter_date date, 
name varchar(50),
family_name varchar(50),
dob date,
dob_estimated bit,
gender varchar(2),
dead bit,
death_date date,
cause_of_death varchar(100),
ncd_enrolled bit,
ncd_last_encounter_date date,
echo_enrolled bit,
echo_last_encounter_date date,
hiv_enrolled bit,
hiv_last_encounter_date date
);

-- ---------- Temp tables ----------------
drop table if exists tbl_first_enc;
create temporary table tbl_first_enc
SELECT
    `e`.`patient_id` AS `patient_id`,
    min(`e`.`encounter_datetime`) AS `encounter_datetime`
FROM
    `openmrs`.`encounter` `e`
GROUP BY
    `e`.`patient_id`;
 
drop table if exists tbl_first_enc_details;
create temporary table tbl_first_enc_details
SELECT
    DISTINCT `e`.`patient_id` AS `patient_id`,
    `e`.`encounter_datetime` AS `encounter_datetime`,
    `e`.`encounter_id` AS `encounter_id`,
    `e`.`encounter_type` AS `encounter_type`,
    `l`.`name` AS `name`
FROM
    ((`openmrs`.`encounter` `e`
JOIN `openmrs`.`first_enc` `X` ON
    (((`X`.`patient_id` = `e`.`patient_id`)
        AND (`X`.`encounter_datetime` = `e`.`encounter_datetime`))))
JOIN `openmrs`.`location` `l` ON
    ((`l`.`location_id` = `e`.`location_id`)));
   
-- --------- Identifications --------------------------------------------------------

INSERT INTO dim_patients (patient_id) 
SELECT DISTINCT  p.patient_id
FROM patient p
where p.voided=0
GROUP BY p.patient_id ;

UPDATE dim_patients dp 
SET dp.emr_id= (
 SELECT identifier
 FROM patient_identifier 
 WHERE identifier_type =@identifier_type
 AND patient_id=dp.patient_id
 AND voided=0
 ORDER BY preferred desc, date_created desc limit 1
);

UPDATE dim_patients dp 
SET dp.hiv_emr_id= (
 SELECT identifier
 FROM patient_identifier 
 WHERE identifier_type =@hiv_identifier_type
 AND patient_id=dp.patient_id
 AND voided=0
 ORDER BY preferred desc, date_created desc limit 1
);

UPDATE dim_patients dp 
SET dp.dossier_number= (
 SELECT identifier
 FROM patient_identifier 
 WHERE identifier_type =@doss_identifier_type
 AND patient_id=dp.patient_id
 AND voided=0
 ORDER BY preferred desc, date_created desc limit 1
);

-- --------- Registeration --------------------------------------------------------

UPDATE dim_patients dp
SET dp.reg_location=loc_registered(patient_id),
dp.reg_date=CAST(registration_date(patient_id) AS date);

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

UPDATE dim_patients dp
set fist_encounter_date = (
	select encounter_date
	from tmp_first_enc_date
	where patient_id= dp.patient_id
);


UPDATE dim_patients dp
set last_encounter_date = (
	select encounter_date
	from tmp_last_enc_date
	where patient_id= dp.patient_id
);

update dim_patients dp 
set reg_location = (
	select name 
	from tbl_first_enc_details 
	where patient_id=dp.patient_id
	order by encounter_id asc 
	limit 1
)
where dp.reg_location is null;

update dim_patients dp 
set reg_date = (
	select cast(encounter_datetime as date) 
	from tbl_first_enc_details 
	where patient_id=dp.patient_id
     order by encounter_id asc 
	limit 1
)
where dp.reg_date is null;

-- --------- Demographical ---------------------------------------------------------

UPDATE dim_patients de 
INNER JOIN (
SELECT person_id,given_name,family_name FROM person_name 
WHERE voided=0 
) pn ON de.patient_id =pn.person_id 
SET de.name=pn.given_name, 
	de.family_name=pn.family_name;

-- -------------------- Bio Information -----------------------

UPDATE dim_patients tt
SET tt.dob= birthdate(tt.patient_id),
tt.gender=gender(tt.patient_id);

UPDATE dim_patients tt INNER JOIN (
SELECT person_id, dead , death_date, cause_of_death, birthdate_estimated 
FROM person p WHERE voided=0
) st 
on  st.person_id =tt.patient_id 
SET tt.dead = st.dead,
	tt.death_date = CAST(st.death_date AS date),
tt.cause_of_death=st.cause_of_death,
tt.dob_estimated=st.birthdate_estimated;


-- --------------------- Patient Status Information --------------------------------------

UPDATE dim_patients de 
INNER JOIN (
	SELECT patient_id, max(encounter_datetime)  encounter_datetime FROM encounter e 
	WHERE encounter_type IN (@etype_ncdinit_id,@etype_ncdf_id)
	-- AND encounter_id > @encounter_last_id
	GROUP BY patient_id
) x
ON de.patient_id =x.patient_id
SET de.ncd_last_encounter_date= cast(x.encounter_datetime AS date);

UPDATE dim_patients de 
INNER JOIN (
	SELECT patient_id, max(encounter_datetime)  encounter_datetime FROM encounter e 
	WHERE encounter_type IN (@etype_echo_id)
	-- AND encounter_id > @encounter_last_id
	GROUP BY patient_id
) x
ON de.patient_id =x.patient_id
SET de.echo_last_encounter_date= cast(x.encounter_datetime AS date);


UPDATE dim_patients de 
INNER JOIN (
	SELECT patient_id, max(encounter_datetime)  encounter_datetime FROM encounter e 
	WHERE encounter_type IN (@etype_hivinit_id,@etype_hivf_id)
	-- AND encounter_id > @encounter_last_id
	GROUP BY patient_id
) x
ON de.patient_id =x.patient_id
SET de.hiv_last_encounter_date= cast(x.encounter_datetime AS date);

UPDATE dim_patients de 
SET de.ncd_enrolled = CASE WHEN de.ncd_last_encounter_date IS NOT NULL THEN TRUE ELSE FALSE END,
de.echo_enrolled = CASE WHEN de.echo_last_encounter_date IS NOT NULL THEN TRUE ELSE FALSE END,
de.hiv_enrolled = CASE WHEN de.hiv_last_encounter_date IS NOT NULL THEN TRUE ELSE FALSE END;

SELECT 
patient_id,
emr_id,
hiv_emr_id,
dossier_number, 
reg_location,
reg_date,
fist_encounter_date,
name,
family_name,
dob,
dob_estimated,
gender,
dead,
death_date,
cause_of_death,
ncd_enrolled,
ncd_last_encounter_date,
echo_enrolled,
echo_last_encounter_date,
hiv_enrolled,
hiv_last_encounter_date
FROM dim_patients dp
where emr_id is not null;
