CREATE TABLE data_quality_log_details
(
execution_id INT NOT NULL AUTO_INCREMENT,
quality_rule_id INT,
source varchar(20),
issue_category varchar(50),
patient_id int,
emr_id varchar(50),
table_names varchar(200),
column_names varchar(200),
quality_issue_desc text,
issue_start_date date,
last_checked_date date,
fixed bit,
modified_date date
);