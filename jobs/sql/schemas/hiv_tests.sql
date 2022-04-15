CREATE TABLE hiv_tests (
    emr_id                      VARCHAR(25),
    hivemr_v1_id                VARCHAR(25),
    encounter_id                INT,
    specimen_collection_date    DATE,
    result_date                 DATE,
    test_type                   VARCHAR(100),
    test_result                 VARCHAR(100),
    index_asc                   INT,
    index_desc                  INT
);
