set @partition = '${partitionNum}';
set @sitename = '${siteName}';

set @hiv_exposed_infant_enrollment_program =  program('EID'); -- exposed infant enrollment
set @hiv_program = program('HIV'); -- HIV enrollment

set @hiv_dispensing = encounter_type('cc1720c9-3e4c-4fa8-a7ec-40eeaad1958c');
set @hiv_initial = encounter_type('c31d306a-40c4-11e7-a919-92ebcb67fe33');
set @hiv_followup = encounter_type('c31d3312-40c4-11e7-a919-92ebcb67fe33');
set @exposed_infant_followup = encounter_type('0f070640-279e-4ec0-9e6c-6ef1f6567030');


DROP TABLE IF EXISTS data_quality_log_details;
CREATE TEMPORARY TABLE data_quality_log_details
(
execution_id INT NOT NULL AUTO_INCREMENT,
quality_rule_id INT,
source varchar(20),
site varchar(20),
issue_category varchar(50),
patient_id int,
emr_id varchar(50),
table_names varchar(200),
column_names varchar(200),
quality_issue_desc text,
issue_log_date date,
PRIMARY KEY (execution_id)
);

	
-- blank emr_id -----------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_blank_emr;
CREATE TABLE tmp_blank_emr AS 
SELECT patient_id 
from patient p 
where p.voided = 0 and zlemr(p.patient_id) is NULL;

DELETE FROM data_quality_log_details
WHERE issue_category='Completness'
AND site=@sitename
AND quality_rule_id=1;

INSERT INTO data_quality_log_details(quality_rule_id, source, site, issue_category, patient_id, emr_id, table_names, column_names, quality_issue_desc, issue_log_date)
SELECT  
	1 quality_rule_id,
	'mysql' source,
	@sitename site,
	'Completness' issue_category,
	p.patient_id,
	zlemr(p.patient_id) emr_id,
	'patient' table_names,
	'emr_id' column_names,
	'emr id is null' quality_issue_desc,
	CURRENT_DATE() issue_log_date
FROM tmp_blank_emr p;

-- blank birthdate -------------
DROP TABLE IF EXISTS tmp_blank_birthdate;
CREATE TABLE tmp_blank_birthdate AS 
select pt.patient_id ,
zlemr(pt.patient_id),
'blank birthdate'
from patient pt
inner join person p on p.person_id = pt.patient_id and p.birthdate  is null
where pt.voided = 0
and unknown_patient(patient_id) is not null;

DELETE FROM data_quality_log_details
WHERE issue_category='Completness'
AND site=@sitename
AND quality_rule_id=2;

INSERT INTO data_quality_log_details(quality_rule_id, source, site, issue_category, patient_id, emr_id, table_names, column_names, quality_issue_desc, issue_log_date)
SELECT  
	2 quality_rule_id,
	'mysql' source,
	@sitename site,
	'Completness' issue_category,
	p.patient_id,
	zlemr(p.patient_id) emr_id,
	'patient, person' table_names,
	'birthdate' column_names,
	'birthdate is null' quality_issue_desc,
	CURRENT_DATE() issue_log_date
FROM tmp_blank_birthdate p;


-- blank gender ----------------
DROP TABLE IF EXISTS tmp_blank_gender;
CREATE TABLE tmp_blank_gender AS 
select pt.patient_id ,
zlemr(pt.patient_id),
'blank gender'
from patient pt
inner join person p on p.person_id = pt.patient_id and p.gender is null
where pt.voided = 0
and unknown_patient(patient_id) is not null;

DELETE FROM data_quality_log_details
WHERE issue_category='Completness'
AND site=@sitename
AND quality_rule_id=3;

INSERT INTO data_quality_log_details(quality_rule_id, source, site, issue_category, patient_id, emr_id, table_names, column_names, quality_issue_desc, issue_log_date)
SELECT  
	3 quality_rule_id,
	'mysql' source,
	@sitename site,
	'Completness' issue_category,
	p.patient_id,
	zlemr(p.patient_id) emr_id,
	'patient, person' table_names,
	'gender' column_names,
	'gender is null' quality_issue_desc,
	CURRENT_DATE() issue_log_date
FROM tmp_blank_gender p;

-- blank family name ----------
DROP TABLE IF EXISTS tmp_blank_family_name;
CREATE TABLE tmp_blank_family_name AS 
select pt.patient_id ,
zlemr(pt.patient_id)
from patient pt
inner join person_name pn on pn.person_id = pt.patient_id and (pn.given_name is null or pn.family_name is null)
where pt.voided = 0
and unknown_patient(patient_id) is not null;

DELETE FROM data_quality_log_details
WHERE issue_category='Completness'
AND site=@sitename
AND quality_rule_id=4;

INSERT INTO data_quality_log_details(quality_rule_id, source, site, issue_category, patient_id, emr_id, table_names, column_names, quality_issue_desc, issue_log_date)
SELECT  
	4 quality_rule_id,
	'mysql' source,
	@sitename site,
	'Completness' issue_category,
	p.patient_id,
	zlemr(p.patient_id) emr_id,
	'patient, person_name' table_names,
	'given_name, family_name' column_names,
	'given_name is null or family_name is null' quality_issue_desc,
	CURRENT_DATE() issue_log_date
FROM tmp_blank_family_name p;

-- overlapping program segments
DROP TABLE IF EXISTS tmp_overlap_segments;
CREATE TABLE tmp_overlap_segments AS 
select pp.patient_id ,zlemr(pp.patient_id)
from patient_program pp
inner join program p on p.program_id  = pp.program_id 
inner join patient_program pp2 on pp2.voided = 0 
	and pp2.patient_id = pp.patient_id 
	and pp2.program_id = pp.program_id
	and pp2.patient_program_id <> pp.patient_program_id 
	and (pp.date_enrolled < pp2.date_enrolled and ifnull(pp.date_completed,'9999-12-31') >pp2.date_enrolled)
where pp.voided = 0;

DELETE FROM data_quality_log_details
WHERE issue_category='Completness'
AND site=@sitename
AND quality_rule_id=5;

INSERT INTO data_quality_log_details(quality_rule_id, source, site, issue_category, patient_id, emr_id, table_names, column_names, quality_issue_desc, issue_log_date)
SELECT  
	5 quality_rule_id,
	'mysql' source,
	@sitename site,
	'Consistency' issue_category,
	p.patient_id,
	zlemr(p.patient_id) emr_id,
	'patient_program, program' table_names,
	'date_enrolled, date_completed' column_names,
	'overlapping program enrollments' quality_issue_desc,
	CURRENT_DATE() issue_log_date
FROM tmp_overlap_segments p;

-- death date before birthdate
DROP TABLE IF EXISTS tmp_overlap_death_birth_date;
CREATE TABLE tmp_overlap_death_birth_date AS 
select pt.patient_id ,
zlemr(pt.patient_id)
from patient pt 
inner join person p on p.person_id = pt.patient_id and p.death_date < p.birthdate  
where p.voided = 0;

DELETE FROM data_quality_log_details
WHERE issue_category='Validity'
AND site=@sitename
AND quality_rule_id=6;

INSERT INTO data_quality_log_details(quality_rule_id, source, site, issue_category, patient_id, emr_id, table_names, column_names, quality_issue_desc, issue_log_date)
SELECT  
	6 quality_rule_id,
	'mysql' source,
	@sitename site,
	'Validity' issue_category,
	p.patient_id,
	zlemr(p.patient_id) emr_id,
	'patient, person' table_names,
	'death_date, birthdate' column_names,
	'death date before birthdate' quality_issue_desc,
	CURRENT_DATE() issue_log_date
FROM tmp_overlap_death_birth_date p;

SELECT 
quality_rule_id ,
source ,
issue_category ,
patient_id ,
emr_id ,
table_names, 
column_names ,
quality_issue_desc ,
issue_log_date
FROM data_quality_log_details;