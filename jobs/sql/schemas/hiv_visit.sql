CREATE TABLE hiv_visit
(
    encounter_id    INT,
    patient_id      INT,
    emr_id          VARCHAR(25),
    hivemr_v1       VARCHAR(25),
    encounter_type  varchar(255),
    date_entered    DATETIME,
    user_entered    VARCHAR(50),
    pregnant        BIT,
    visit_date      DATE,
    next_visit_date DATE,
    visit_location  varchar(255),
    index_asc       int,
    index_desc      int
);
