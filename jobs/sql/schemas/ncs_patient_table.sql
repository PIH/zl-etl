create table ncd_patient_table
(
patient_id int,
birthdate date,
sex char(1),
department varchar(50),
commune varchar(50),
ncd_enrollment_date date,
ncd_enrollment_location varchar(50),
htn boolean,
diabetes boolean,
respiratory boolean,
epilepsy boolean,
heart_failure boolean,
cerebrovascular_accident boolean,
renal_failure boolean,
liver_failure boolean,
rehabilitation boolean,
sickle_cell boolean,
other_ncd boolean,
dm_type varchar(50),
heart_failure_category varchar(50),
cardiomyopathy varchar(50),
nyha_class varchar(50),
heart_failure_improbable boolean,
ncd_status varchar(50),
ncd_status_date date,
deceased boolean,
date_of_death date
);