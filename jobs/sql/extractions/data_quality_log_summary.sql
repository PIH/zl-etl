set @partition = '${partitionNum}';
set @sitename = '${siteName}';

set @hiv_exposed_infant_enrollment_program =  program('EID'); -- exposed infant enrollment
set @hiv_program = program('HIV'); -- HIV enrollment

set @hiv_dispensing = encounter_type('cc1720c9-3e4c-4fa8-a7ec-40eeaad1958c');
set @hiv_initial = encounter_type('c31d306a-40c4-11e7-a919-92ebcb67fe33');
set @hiv_followup = encounter_type('c31d3312-40c4-11e7-a919-92ebcb67fe33');
set @exposed_infant_followup = encounter_type('0f070640-279e-4ec0-9e6c-6ef1f6567030');


DROP TABLE IF EXISTS data_quality_log_summary;
CREATE TEMPORARY TABLE data_quality_log_summary
(
quality_rule_id INT,
source varchar(20),
site varchar(20),
issue_category varchar(50),
table_names varchar(200),
column_names varchar(200),
quality_issue_desc text,
issue_log_date date,
number_of_cases int,
total_count int,
percentage double,
PRIMARY KEY (quality_rule_id,source,site)
);

	


-- blank emr_id -----------------------------------------------------------------------

DROP TABLE IF EXISTS tmp_blank_emr;
CREATE TABLE tmp_blank_emr AS 
SELECT patient_id 
from patient p 
where p.voided = 0 and zlemr(p.patient_id) is NULL;


SELECT count(*) INTO @tCount 
from patient p
where p.voided = 0;

SELECT count(*) INTO @vCount FROM tmp_blank_emr;

INSERT INTO data_quality_log_summary(quality_rule_id, source, site, issue_category, table_names, column_names, 
						quality_issue_desc, issue_log_date, number_of_cases,total_count , percentage)
values(
		1,
		'mysql' ,
		@sitename,
		'Completness' ,
		'patient' ,
		'emr_id' ,
		'emr id is null' ,
		CURRENT_DATE() ,
		@vCount,
		@tCount,
		(@vCount/@tCount)*100);


-- blank birthdate --------------------------------------
DROP TABLE IF EXISTS tmp_blank_birthdate;
CREATE TABLE tmp_blank_birthdate AS 
select pt.patient_id ,
zlemr(pt.patient_id),
'blank birthdate'
from patient pt
inner join person p on p.person_id = pt.patient_id and p.birthdate  is null
where pt.voided = 0
and unknown_patient(patient_id) is not null;

select count(*) INTO @tCount
from patient pt
inner join person p on p.person_id = pt.patient_id
where pt.voided = 0;

SELECT count(*) INTO @vCount FROM tmp_blank_birthdate;

INSERT INTO data_quality_log_summary(quality_rule_id, source, site, issue_category, table_names, column_names, 
						quality_issue_desc, issue_log_date, number_of_cases,total_count , percentage)
values(
		2,
		'mysql' ,
		@sitename,
		'Completness' ,
		'patient, person' ,
		'birthdate' ,
		'birthdate is null' ,
		CURRENT_DATE(),
		@vCount,
		@tCount,
		(@vCount/@tCount)*100);

-- blank gender ------------------------------------------
DROP TABLE IF EXISTS tmp_blank_gender;
CREATE TABLE tmp_blank_gender AS 
select pt.patient_id ,
zlemr(pt.patient_id),
'blank gender'
from patient pt
inner join person p on p.person_id = pt.patient_id and p.gender is null
where pt.voided = 0
and unknown_patient(patient_id) is not null;

select  count(*) INTO @tCount
from patient pt
inner join person p on p.person_id = pt.patient_id
where pt.voided = 0;

SELECT count(*) INTO @vCount FROM tmp_blank_gender;

INSERT INTO data_quality_log_summary(quality_rule_id, source, site, issue_category, table_names, column_names, 
quality_issue_desc, issue_log_date, number_of_cases,total_count,percentage)
values(
		3,
		'mysql' ,
		@sitename,
		'Completness' ,
		'patient, person' ,
		'gender' ,
		'gender is null' ,
		CURRENT_DATE() ,
		@vCount,
		@tCount,
		(@vCount/@tCount)*100);
	
-- blank Family Name -----------------------------------------------------
DROP TABLE IF EXISTS tmp_blank_family_name;
CREATE TABLE tmp_blank_family_name AS 
select pt.patient_id ,
zlemr(pt.patient_id)
from patient pt
inner join person_name pn on pn.person_id = pt.patient_id and (pn.given_name is null or pn.family_name is null)
where pt.voided = 0
and unknown_patient(patient_id) is not null;

select count(*) INTO @tCount
from patient pt
inner join person_name pn on pn.person_id = pt.patient_id
where pt.voided = 0;


SELECT count(*) INTO @vCount FROM tmp_blank_family_name;

INSERT INTO data_quality_log_summary(quality_rule_id, source, site, issue_category, table_names, column_names, 
quality_issue_desc, issue_log_date, number_of_cases,total_count,percentage)
values(
		4,
		'mysql' ,
		@sitename,
		'Completness' ,
	    'patient, person_name' ,
	    'given_name, family_name' ,
	    'given_name is null or family_name is null' ,
		CURRENT_DATE() ,
		@vCount,
		@tCount,
		(@vCount/@tCount)*100);

-- overlapping program segments --------------------------- 
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

select count(*) INTO @tCount
from patient_program pp
inner join program p on p.program_id  = pp.program_id 
inner join patient_program pp2 on pp2.voided = 0 
	and pp2.patient_id = pp.patient_id 
	and pp2.program_id = pp.program_id
	and pp2.patient_program_id <> pp.patient_program_id 
where pp.voided = 0;


SELECT count(*) INTO @vCount FROM tmp_overlap_segments;

INSERT INTO data_quality_log_summary(quality_rule_id, source, site, issue_category, table_names, column_names, 
quality_issue_desc, issue_log_date, number_of_cases,total_count,percentage)
values(
		5,
		'mysql' ,
		@sitename,
		'Consistency' ,
		'patient_program, program' ,
		'date_enrolled, date_completed' ,
		'overlapping program enrollments' ,
		CURRENT_DATE() ,
		@vCount,
		@tCount,
		(@vCount/@tCount)*100);

-- death date before birthdate ----------------------------------
DROP TABLE IF EXISTS tmp_overlap_death_birth_date;
CREATE TABLE tmp_overlap_death_birth_date AS 
select pt.patient_id ,
zlemr(pt.patient_id)
from patient pt 
inner join person p on p.person_id = pt.patient_id and p.death_date < p.birthdate  
where p.voided = 0;

select count(*) INTO @tCount
from patient pt 
inner join person p on p.person_id = pt.patient_id
where p.voided = 0;

SELECT count(*) INTO @vCount FROM tmp_overlap_death_birth_date;

INSERT INTO data_quality_log_summary(quality_rule_id, source, site, issue_category, table_names, column_names, 
quality_issue_desc, issue_log_date, number_of_cases,total_count,percentage)
values(
		6,
		'mysql' ,
		@sitename,
		'Validity' ,
		'patient, person' ,
		'death_date, birthdate' ,
		'death date before birthdate' ,
		CURRENT_DATE() ,
		@vCount,
		@tCount,
		(@vCount/@tCount)*100);

SELECT 
quality_rule_id,
source,
issue_category,
table_names,
column_names,
quality_issue_desc,
issue_log_date,
number_of_cases,
total_count ,
percentage
FROM data_quality_log_summary
WHERE number_of_cases <> 0 ;