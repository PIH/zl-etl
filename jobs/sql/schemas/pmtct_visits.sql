CREATE TABLE pmtct_visits
(
    visit_id             INT,
    encounter_id         INT,
    patient_id           INT,
    emr_id               VARCHAR(25),
    visit_date           DATE,
    health_facility      VARCHAR(100),
    date_entered         DATETIME,
    user_entered         VARCHAR(50),
    hiv_test_date        DATE,
    tb_screening_date    DATE,
    has_provided_contact BIT,
    -- hiv_test_result varchar(255),
    -- maternity_clinic_type varchar(100),
    index_asc            INT,
    index_desc           INT
);