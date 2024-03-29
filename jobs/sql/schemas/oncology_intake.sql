CREATE TABLE oncology_intake 
(
emr_id varchar(50),
encounter_id varchar(50),
encounter_datetime datetime,
encounter_location varchar(100),
date_entered date,
user_entered varchar(30),
encounter_provider varchar(30),
smoking varchar(30),
alcohol varchar(30),
drugs varchar(30),
hiv_test bit,
hiv_test_date date,
hiv_test_result varchar(50),
diabetes bit,
type_1_diabetes bit,
type_2_diabetes bit,
hypertension bit,
asthma bit,
referal varchar(500),
ecog_status int,
ecog_date datetime,
ecog_evaluated varchar(50),
zldsi_status int,
zldsi_date datetime,
zldsi_evaluated varchar(50),
psych_referral bit,
disposition varchar(100),
comment text,
next_visit_date date
);