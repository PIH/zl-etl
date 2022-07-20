create table hiv_dispensing
(
    emr_id                      varchar(255),
    encounter_id                varchar(25),
    dispense_date               datetime,
    dispense_site               varchar(255),
    date_entered                DATETIME,
    user_entered                VARCHAR(50),
    age_at_dispense_date        int,
    dac                         char(1),
    dispensed_to                varchar(100),
    dispensed_accompagnateur    text,
    current_art_treatment_line  varchar(255),
    current_art_line_start_date datetime,
    months_dispensed            int,
    is_current_mmd              char(1),
    next_dispense_date          datetime,
    arv_1_med                   varchar(255),
    arv_1_med_short_name        varchar(255),
    arv_1_quantity              int,
    arv_2_med                   varchar(255),
    arv_2_med_short_name        varchar(255),
    arv_2_quantity              int,
    arv_3_med                   varchar(255),
    arv_3_med_short_name        varchar(255),
    arv_3_quantity              int,
    tms_1_med                   varchar(255),
    tms_1_med_short_name        varchar(255),
    tms_1_quantity              int,
    inh_1_med                   varchar(255),
    inh_1_med_short_name        varchar(255),
    inh_1_sequence              varchar(255),
    inh_1_quantity              int,
    inh_2_med                   varchar(255),
    inh_2_med_short_name        varchar(255),
    inh_2_sequence              varchar(255),
    inh_2_quantity              int,
    b6_med                      varchar(255),
    b6_med_short_name           varchar(255),
    b6_quantity                 int,
    regimen_change              char(1),
    days_late_to_pickup         int,
    regimen_match               char(1),
    dispense_date_ascending     int,
    dispense_date_descending    int
);
