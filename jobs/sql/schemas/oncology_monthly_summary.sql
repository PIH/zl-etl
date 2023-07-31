CREATE TEMPORARY TABLE oncology_monthly_summary (
report_month date,
emr_id varchar(50),
enrollment_date date,
enrollment_location varchar(100),
program_completion_date date,
program_outcome varchar(50),
latest_stage varchar(100),
latest_intake_date date,
latest_treatment_plan_date date,
latest_chemotherapy_date date,
latest_consult_note varchar(100),
latest_oncology_program_status varchar(100),
latest_oncology_treatment_status varchar(100)
);