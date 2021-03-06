CREATE TABLE echo_summary_table (
patient_id integer, 
emrid varchar(50), 
age int,
sex char(1),
department varchar(50),
commune varchar(50),
section_communal varchar(50),
locality varchar(50),
heart_failure bit,
echo_date_most_recent date,
echo_date_prior date,
total_echos int,
lvsf_most_recent varchar(50),
lvsf_prior varchar(50),
lvsf_change varchar(30),
mitral_stenosis bit,
nyha_class_most_recent varchar(50),
cardiomyopathy bit,
beta_blocker_atenolol bit,
beta_blocker_metoprolol bit,
beta_blocker_carvedilol bit,
ace_inhibitor bit,
penicillin bit,
spironolactone bit,
hydralazine_hydrochloride bit,
isosorbide_dinitrate bit,
diuretic bit,
calcium_channel_blocker bit,
follow_up_echo bit,
bp_systolic_most_recent int,
bp_diastolic_most_recent int,
ncd_comorbidity bit,
dm1 bit,
dm2 bit,
hypertension bit,
asthma bit,
sickle_cell bit,
copd bit
);
