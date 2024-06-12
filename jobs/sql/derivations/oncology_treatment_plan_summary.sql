
DROP TABLE  IF EXISTS oncology_treatment_plan_summary_staging;
create table oncology_treatment_plan_summary_staging
(emr_id varchar(50),
encounter_id varchar(50),
visit_id varchar(50),
dob	date,
age_at_encounter int,
gender varchar(2),
encounter_datetime datetime,
encounter_provider varchar(255),
user_entered varchar(255),
date_entered datetime,
cancer_stage varchar(255),
treatment_intent varchar(255),
diagnosis_1 varchar(255),
diagnosis_1_primary bit,
diagnosis_2 varchar(255),
diagnosis_2_primary bit,
diagnosis_3 varchar(255),
diagnosis_3_primary bit,
index_asc int,
index_desc int
);

insert into oncology_treatment_plan_summary_staging
	(emr_id,
	encounter_id,
	visit_id,
	encounter_datetime ,
	encounter_provider, 
	user_entered,
	date_entered,
	cancer_stage,
	treatment_intent)
select 
	emr_id,
	encounter_id,
	visit_id,
	encounter_datetime ,
	encounter_provider, 
	user_entered,
	date_entered,
	cancer_stage,
	treatment_intent
from oncology_treatment_plan o;

update o
	set o.gender = p.gender,
	    o.dob = p.dob,
	    o.age_at_encounter = CEILING(DATEDIFF(YEAR,p.dob ,o.encounter_datetime))
from oncology_treatment_plan_summary_staging o
inner join all_patients p on p.emr_id = o.emr_id;

update o
	set o.diagnosis_1 = d.diagnosis_coded_fr,
	    o.diagnosis_1_primary = IIF(dx_order ='Primaire',1,0)
from oncology_treatment_plan_summary_staging o
inner join all_diagnosis d on d.obs_id = 
	(select top 1 d2.obs_id from all_diagnosis d2
	where d2.encounter_id = o.encounter_id
	and d2.oncology = 1
	order by IIF(dx_order ='Primaire',0,1) asc, obs_id asc);

update o
	set o.diagnosis_2 = d.diagnosis_coded_fr,
	    o.diagnosis_2_primary = IIF(dx_order ='Primaire',1,0)
from oncology_treatment_plan_summary_staging o
inner join all_diagnosis d on d.obs_id = 
	(select top 1 d2.obs_id from all_diagnosis d2
	where d2.encounter_id = o.encounter_id
	and d2.oncology = 1
	and d2.diagnosis_coded_fr <> o.diagnosis_1
	order by IIF(dx_order ='Primaire',0,1) asc, obs_id asc);
	
update o
	set o.diagnosis_3 = d.diagnosis_coded_fr,
	    o.diagnosis_3_primary = IIF(dx_order ='Primaire',1,0)
from oncology_treatment_plan_summary_staging o
inner join all_diagnosis d on d.obs_id = 
	(select top 1 d2.obs_id from all_diagnosis d2
	where d2.encounter_id = o.encounter_id
	and d2.oncology = 1
	and d2.diagnosis_coded_fr not in (o.diagnosis_1, o.diagnosis_2)
	order by IIF(dx_order ='Primaire',0,1) asc, obs_id asc);

-- update index asc/desc on 
drop table if exists #otp_indexes;
select  emr_id, encounter_id,
ROW_NUMBER() over (PARTITION by emr_id order by encounter_datetime asc, encounter_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by encounter_datetime desc, encounter_id desc) "index_desc"
into #otp_indexes
from oncology_treatment_plan_summary_staging;

update otp
set otp.index_asc = oi.index_asc,
	otp.index_desc = oi.index_desc 
from oncology_treatment_plan_summary_staging otp
inner join #otp_indexes oi on oi.encounter_id = otp.encounter_id; 

-- ------------------------------------------------------------------------------------
DROP TABLE IF EXISTS oncology_treatment_plan_summary;
EXEC sp_rename 'oncology_treatment_plan_summary_staging', 'oncology_treatment_plan_summary';
