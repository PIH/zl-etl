CREATE TABLE eid_visit
(
    encounter_id    VARCHAR(25),
    emr_id          VARCHAR(25),
    encounter_type  VARCHAR(50),
    visit_date      DATE,
    visit_location  VARCHAR(100),
    date_entered    DATE,
    user_entered    VARCHAR(255),
    next_visit_date DATE,
    index_asc       INT,
    index_desc      INT
 );
