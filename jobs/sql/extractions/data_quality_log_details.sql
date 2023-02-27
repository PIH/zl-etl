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
issue_start_date date,
last_checked_date date,
fixed bit,
modified_date date,
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
AND table_names='patient'
AND column_names='emr_id'
AND site=@sitename
AND quality_rule_id=100;

INSERT INTO data_quality_log_details(quality_rule_id, source, site, issue_category, patient_id,
emr_id, table_names, column_names, quality_issue_desc, issue_start_date, last_checked_date, fixed, modified_date)
SELECT  
	100 quality_rule_id,
	'mysql' source,
	@sitename site,
	'Completness' issue_category,
	p.patient_id,
	zlemr(p.patient_id) emr_id,
	'patient' table_names,
	'emr_id' column_names,
	'emr id is null' quality_issue_desc,
	CURRENT_DATE() issue_start_date,
	CURRENT_DATE() last_checked_date,
	FALSE fixed,
	CURRENT_DATE() modified_date
FROM tmp_blank_emr p;


SELECT 
execution_id,
quality_rule_id ,
source ,
issue_category ,
patient_id ,
emr_id ,
table_names, 
column_names ,
quality_issue_desc ,
issue_start_date ,
last_checked_date,
fixed ,
modified_date 
FROM data_quality_log_details;