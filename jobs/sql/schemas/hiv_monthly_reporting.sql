create table hiv_monthly_reporting
(
emr_id                          varchar(255),
date_enrolled                   datetime,
date_completed                  datetime,
reporting_date                  date,
latest_hiv_note_encounter_id    int,
latest_hiv_visit_date           datetime,
latest_expected_hiv_visit_date  datetime,
hiv_visit_days_late             int,
latest_dispensing_encounter_id  int,
latest_dispensing_date          datetime,
latest_expected_dispensing_date datetime,
dispensing_days_late            int,
latest_hiv_viral_load_date      datetime,
latest_hiv_viral_load_coded     varchar(255),
latest_hiv_viral_load           int,
latest_arv_regimen_date         datetime,
latest_arv_regimen_line         varchar(255), 
latest_arv_dispensed_date       datetime,
latest_arv_dispensed_line       varchar(255)  
); 
