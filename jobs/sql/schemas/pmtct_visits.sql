CREATE TABLE pmtct_visits
(
    visit_id                INT,
    encounter_id            VARCHAR(25),
    hiv_program_id          VARCHAR(25),
    emr_id                  VARCHAR(25),
    visit_date              DATE,
    health_facility         VARCHAR(100),
    date_entered            DATETIME,
    user_entered            VARCHAR(50),
    hiv_test_date           DATE,
    expected_delivery_date  DATE,
    tb_screening_date       DATE,
    has_provided_contact    BIT,
    breastfeeding_status	VARCHAR(255),
    last_breastfeeding_date	DATETIME,
    next_visit_date		    DATETIME,
    delivery                BIT,
    delivery_datetime       DATETIME,
    index_asc               INT,
    index_desc              INT,
    index_program_asc       INT,
    index_program_desc      INT
);
