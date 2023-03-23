create table all_procedures
(
patient_id int,
emr_id varchar(25),
encounter_id int,
obs_id int,
visit_id int,
creator varchar(150),
encounter_datetime datetime,
obs_datetime datetime,
encounter_location text,
encounter_type text,
entered_by varchar(150),
provider varchar(150),
procedures text,
procedure_coded bit,
date_created bit,
retrospective bit,
oophorectomy bit,
biopsy bit,
hysterectomy bit, 
caesarean_section bit,
colposcopy bit,
cryotherapy bit,
instrumental_deliveries bit,
leep bit,
myomectomy bit
);
