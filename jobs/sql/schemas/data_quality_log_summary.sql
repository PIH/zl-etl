CREATE TABLE data_quality_log_summary
(
quality_rule_id INT,
source varchar(20),
issue_category varchar(50),
table_names varchar(200),
column_names varchar(200),
quality_issue_desc text,
issue_log_date date,
number_of_cases int,
total_count int,
percentage float
);