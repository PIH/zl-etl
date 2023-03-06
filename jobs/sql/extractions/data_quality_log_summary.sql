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
PRIMARY KEY (quality_rule_id,source,site)
);

	


-- blank emr_id -----------------------------------------------------------------------

DROP TABLE IF EXISTS tmp_blank_emr;
CREATE TABLE tmp_blank_emr AS 
SELECT patient_id 
from patient p 
where p.voided = 0 and zlemr(p.patient_id) is NULL;

SELECT count(*) INTO @vCount FROM tmp_blank_emr;

INSERT INTO data_quality_log_summary(quality_rule_id, source, issue_category, table_names, column_names, quality_issue_desc, issue_log_date, number_of_cases)
values(
		100,
		'mysql' ,
		'Completness' ,
		'patient' ,
		'emr_id' ,
		'emr id is null' ,
		CURRENT_DATE() ,
		@vCount);


-- blank birthdate
DROP TABLE IF EXISTS tmp_blank_birthdate;
CREATE TABLE tmp_blank_birthdate AS 
select pt.patient_id ,
zlemr(pt.patient_id),
'blank birthdate'
from patient pt
inner join person p on p.person_id = pt.patient_id and p.birthdate  is null
where pt.voided = 0
and unknown_patient(patient_id) is not null;

SELECT count(*) INTO @vCount FROM tmp_blank_birthdate;

INSERT INTO data_quality_log_summary(quality_rule_id, source, site, issue_category, table_names, column_names, quality_issue_desc, issue_log_date, number_of_cases)
values(
		200,
		'mysql' ,
		@sitename,
		'Completness' ,
		'patient, person' ,
		'birthdate' ,
		'birthdate is null' ,
		CURRENT_DATE() ,
		@vCount);

SELECT 
quality_rule_id,
source,
issue_category,
table_names,
column_names,
quality_issue_desc,
issue_log_date,
number_of_cases
FROM data_quality_log_summary;