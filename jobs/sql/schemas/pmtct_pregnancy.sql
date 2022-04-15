CREATE TABLE pmtct_pregnancy (
    emr_id                  VARCHAR(25),
    start_date              DATE,
    pmtct_enrollment_date   DATE,
    health_facility         VARCHAR(255),
    art_start_date          DATETIME,
    birthdate               DATE,
    age_at_pregnancy        FLOAT,
    age_at_pregnancy_cat    VARCHAR(10),
    has_birthplan           BIT,
    is_active_on_art        BIT,
    transfer_status         BIT,
    cd4_count_assessed      FLOAT,
    post_test_counseling_date           DATE,
    hiv_known_before_current_pregnancy  BIT,
    index_asc               INT,
    index_desc              INT
);
