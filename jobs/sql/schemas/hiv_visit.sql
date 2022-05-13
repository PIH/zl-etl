CREATE TABLE hiv_visit
(
    encounter_id    VARCHAR(25),
    emr_id          VARCHAR(25),
    hivemr_v1       VARCHAR(25),
    encounter_type  varchar(255),
    date_entered    DATETIME,
    user_entered    VARCHAR(50),
    chw             VARCHAR(255),
    pregnant        BIT,
    visit_date      DATE,
    next_visit_date DATE,
    visit_location  varchar(255),
    index_asc       int,
    index_desc      int
);
