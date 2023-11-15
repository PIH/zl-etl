-- -------------- deduplicate ncd_patient_table -------------------
drop table if exists ncd_patient_table;
create table ncd_patient_table
(
emr_id                    varchar(50),  
birthdate                 date,         
sex                       char(1),      
department                varchar(50),  
commune                   varchar(50),  
ncd_enrollment_date       date,         
ncd_first_encounter_date  date,         
ncd_latest_encounter_date date,         
ncd_enrollment_location   varchar(50),  
ncd_current_location      varchar(50),   
htn                       bit,          
diabetes                  bit,          
respiratory               bit,          
epilepsy                  bit,          
heart_failure             bit,          
cerebrovascular_accident  bit,          
renal_failure             bit,          
liver_failure             bit,          
rehabilitation            bit,          
sickle_cell               bit,          
other_ncd                 bit,          
dm_type                   varchar(50),  
heart_failure_category    varchar(50),  
cardiomyopathy            varchar(50),  
nyha_class                varchar(50),  
heart_failure_improbable  bit,          
ncd_status                varchar(50),  
ncd_status_date           date,         
deceased                  bit,          
date_of_death             date,         
site                      varchar(100), 
partition_num             int           
);

insert into ncd_patient_table 
(emr_id, 
ncd_latest_encounter_date,
htn,
diabetes,
respiratory,
epilepsy,
heart_failure,
cerebrovascular_accident,
renal_failure,
liver_failure,
rehabilitation,
sickle_cell,
other_ncd)
select emr_id, 
max(ncd_latest_encounter_date) ,
MAX(CONVERT(tinyint, ISNULL(htn,0))),
MAX(CONVERT(tinyint, ISNULL(diabetes,0))),
MAX(CONVERT(tinyint, ISNULL(respiratory,0))),
MAX(CONVERT(tinyint, ISNULL(epilepsy,0))),
MAX(CONVERT(tinyint, ISNULL(heart_failure,0))),
MAX(CONVERT(tinyint, ISNULL(cerebrovascular_accident,0))),
MAX(CONVERT(tinyint, ISNULL(renal_failure,0))),
MAX(CONVERT(tinyint, ISNULL(liver_failure,0))),
MAX(CONVERT(tinyint, ISNULL(rehabilitation,0))),
MAX(CONVERT(tinyint, ISNULL(sickle_cell,0))),
MAX(CONVERT(tinyint, ISNULL(other_ncd,0)))
from ncd_patient_table_staging
group by emr_id;

update t 
set 
t.birthdate = n.birthdate,
t.sex = n.sex,
t.department = n.department,
t.commune = n.commune,
t.ncd_enrollment_date = n.ncd_enrollment_date,
t.ncd_first_encounter_date = n.ncd_first_encounter_date,
t.ncd_latest_encounter_date = n.ncd_latest_encounter_date, 
t.ncd_enrollment_location = n.ncd_enrollment_location,
t.ncd_current_location = n.ncd_current_location,
t.dm_type = n.dm_type,
t.heart_failure_category = n.heart_failure_category,
t.cardiomyopathy = n.cardiomyopathy,
t.nyha_class = n.nyha_class,
t.heart_failure_improbable = n.heart_failure_improbable,
t.ncd_status = n.ncd_status,
t.ncd_status_date = n.ncd_status_date,
t.deceased = n.deceased,
t.date_of_death = n.date_of_death,
t.site = n.site,
t.partition_num = n.partition_num
from ncd_patient_table t
inner join ncd_patient_table_staging n on n.emr_id = t.emr_id and n.ncd_latest_encounter_date  = t.ncd_latest_encounter_date 
;

-- -------------- deduplicate ncd_patient_table -------------------
drop table if exists ncd_heart_failure_patient;
CREATE TABLE ncd_heart_failure_patient
(emr_id            VARCHAR(10),  
sex               VARCHAR(2),   
birthdate         DATE,         
hf_diagnosis_date DATE,         
ncd_enrolled      BIT,          
hf_ncd            BIT,          
hf_broad          BIT,          
hf_left           BIT,          
hf_isolated_right BIT,          
hf_congestive     BIT,          
hf_rheumatic      BIT,          
last_visit_date   DATE,         
deceased          BIT,          
site              varchar(100), 
partition_num     int           
);

insert into ncd_heart_failure_patient 
(emr_id,
ncd_enrolled,
hf_ncd,
hf_broad,
hf_left,
hf_isolated_right,
hf_congestive,
hf_rheumatic)
select emr_id ,
MAX(CONVERT(tinyint, ISNULL(ncd_enrolled,0))),
MAX(CONVERT(tinyint, ISNULL(hf_ncd,0))),
MAX(CONVERT(tinyint, ISNULL(hf_broad,0))),
MAX(CONVERT(tinyint, ISNULL(hf_left,0))),
MAX(CONVERT(tinyint, ISNULL(hf_isolated_right,0))),
MAX(CONVERT(tinyint, ISNULL(hf_congestive,0))),
MAX(CONVERT(tinyint, ISNULL(hf_rheumatic,0)))
from ncd_heart_failure_patient_staging
group by emr_id;

update t
set t.sex = nhfp.sex,
t.birthdate = nhfp.birthdate,
t.hf_diagnosis_date = nhfp.hf_diagnosis_date,
t.last_visit_date = nhfp.last_visit_date,
t.deceased = nhfp.deceased,
t.site = nhfp.site,
t.partition_num = nhfp.partition_num
from ncd_heart_failure_patient t
inner join ncd_patient_table npt on npt.emr_id = t.emr_id
inner join ncd_heart_failure_patient_staging nhfp on nhfp.emr_id = npt.emr_id and nhfp.site = npt.site
;
