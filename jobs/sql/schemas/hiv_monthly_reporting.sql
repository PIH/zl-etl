create table hiv_monthly_reporting
(
emr_id				varchar(20),
date_enrolled				DATETIME,
date_completed				DATETIME,
reporting_date				DATE,
latest_hiv_visit_date			DATETIME,
latest_expected_hiv_visit_date		DATETIME,
hiv_visit_days_late			INT,
latest_dispensing_date			DATETIME,
latest_expected_dispensing_date		DATETIME,
dispensing_days_late			INT,
latest_hiv_viral_load_date		DATETIME,
latest_hiv_viral_load_coded		VARCHAR(255),
latest_hiv_viral_load			INT,
latest_arv_regimen_date			DATETIME,
latest_arv_regimen_line			VARCHAR(255),
latest_arv_dispensed_id			INT,
latest_arv_dispensed_date		DATETIME,
latest_arv_dispensed_line		VARCHAR(255)
); 
