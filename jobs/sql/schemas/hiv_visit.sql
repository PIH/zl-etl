CREATE TABLE hiv_visit
(
        encounter_id                VARCHAR(25),
        emr_id                      VARCHAR(25),
        hivemr_v1                   VARCHAR(25),
        encounter_type              VARCHAR(255),
        date_entered                DATETIME,
        user_entered                VARCHAR(50),
        chw                         VARCHAR(255),
        pregnant                    BIT,
        referral_transfer           VARCHAR(255),
        internal_external           VARCHAR(255),
        referral_transfer_location  VARCHAR(255),
        referred_by_womens_health   BIT,
        referral_transfer_pepfar_partner    BIT,
        reason_not_on_ARV           VARCHAR(255),
        visit_date                  DATE,
        next_visit_date             DATE,
        visit_location              VARCHAR(255),
        index_asc                   INT,
        index_desc                  INT
);
