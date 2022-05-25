CREATE TABLE hiv_patient_summary_status
(
emr_id                            varchar(255),
legacy_emr_id                     varchar(255),
first_name                        varchar(255),
last_name                         varchar(255),
gender                            varchar(255),
birthdate                         date,
age                               int,
last_pickup_accompagnateur        varchar(255),
hiv_note_accompagnateur           varchar(255),
address                           varchar(255),
locality                          varchar(255),
phone_number                      varchar(255),
arv_start_date                    date,
initial_arv_regimen               varchar(255),
arv_regimen                       varchar(255),
months_on_art                     int,
site                              varchar(255),
last_visit_date                   date,
last_med_pickup_date              date,
last_med_pickup_months_dispensed  int,
last_med_pickup_treatment_line    varchar(255),
next_visit_date                   date,
next_med_pickup_date              date,
days_late_for_next_visit          int,
days_late_for_next_med_pickup     int,
last_viral_load_date              date,
last_viral_load_numeric           int,
last_viral_load_undetected        varchar(255),
months_since_last_viral_load      int,
last_weight                       float,
last_weight_date                  date,
last_height                       float,
last_height_date                  date,
status                            varchar(255),
status_date                       date
);