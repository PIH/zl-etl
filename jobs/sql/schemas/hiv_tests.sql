CREATE TABLE hiv_tests (
    emr_id                      VARCHAR(50),
    hivemr_v1_id                VARCHAR(50),
    encounter_id                VARCHAR(25),
    encounter_type              VARCHAR(50),
    specimen_collection_date    DATE,
    result_date                 DATE,
    test_type                   VARCHAR(255),
    test_result                 VARCHAR(255),
    index_asc                   INT,
    index_desc                  INT
);
