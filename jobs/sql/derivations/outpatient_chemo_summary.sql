DROP TABLE  IF EXISTS outpatient_chemo_summary_staging;
create table outpatient_chemo_summary_staging
(outpatient_chemo_id int IDENTITY(1,1) PRIMARY KEY,
emr_id varchar(50),
encounter_id varchar(50),
dob date,
age_at_encounter int,
gender varchar(3),
encounter_datetime datetime,
encounter_provider varchar(255),
encounter_location varchar(255),
drug_name varchar(255)
)

insert into outpatient_chemo_summary_staging
(emr_id,
encounter_id,
dob,
age_at_encounter,
gender,
encounter_datetime,
encounter_provider,
encounter_location,
drug_name)
select
d.emr_id,
d.encounter_id,
p.dob,
CEILING(DATEDIFF(YEAR,p.dob ,d.encounter_datetime))  "age_at_encounter",
p.gender,
d.encounter_datetime,
d.encounter_provider,
d.encounter_location,
d.drug_name
from all_medication_dispensing d 
inner join all_patients p on p.emr_id = d.emr_id
where d.drug_name in -- need to include full list of outpatient chemo drugs
	('Tamoxifen, 10mg, tablet',
	'Tamoxifen, 20mg tablet');

ALTER TABLE outpatient_chemo_summary_staging ADD 
index_asc INT NULL, 
index_desc INT NULL;

-- update index asc/desc on chemo_session_encounter table
drop table if exists #chemo_summary_indexes;
select  emr_id, outpatient_chemo_id,
ROW_NUMBER() over (PARTITION by emr_id order by encounter_datetime asc, outpatient_chemo_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by encounter_datetime desc, outpatient_chemo_id desc) "index_desc"
into #chemo_summary_indexes
from outpatient_chemo_summary_staging ;

update cs
set cs.index_asc = csi.index_asc,
	cs.index_desc = csi.index_desc 
from outpatient_chemo_summary_staging cs
inner join #chemo_summary_indexes csi on csi.outpatient_chemo_id = cs.outpatient_chemo_id; 

-- ------------------------------------------------------------------------------------
DROP TABLE IF EXISTS outpatient_chemo_summary;
EXEC sp_rename 'outpatient_chemo_summary_staging', 'outpatient_chemo_summary';
