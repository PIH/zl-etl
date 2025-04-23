CREATE TABLE hiv_viral_load
(
    hiv_vl_id                      INT,
    emr_id                         VARCHAR(255),
    order_encounter_id             VARCHAR(25),
    specimen_encounter_id          VARCHAR(25),
    order_number                   VARCHAR(50),
    visit_location                 VARCHAR(255),
    date_entered                   DATETIME,
    user_entered                   VARCHAR(50),
    status                         VARCHAR(255),
    order_date                     DATETIME,
    vl_sample_taken_date           DATE,
    vl_sample_taken_date_estimated VARCHAR(255),
    vl_result_date                 DATE,
    specimen_number                VARCHAR(255),
    vl_coded_results               VARCHAR(255),
    viral_load                     INT,
    ldl_value                      INT,
    vl_type                        VARCHAR(255),
    days_since_vl                  INT,
    order_desc                     INT,
    order_asc                      INT
);
