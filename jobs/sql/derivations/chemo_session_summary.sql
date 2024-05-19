DROP TABLE  IF EXISTS chemo_session_summary_staging;
select
p.emr_id,
r.obs_id,
e.encounter_id,
e.visit_id,
p.dob,
CEILING(DATEDIFF(YEAR,p.dob ,e.encounter_datetime))  "age_at_encounter",
p.gender,
e.encounter_datetime,
e.provider_name,
e.user_entered,
e.date_created,
e.encounter_location,
e.cycle_number,
e.planned_chemo_sessions,
e.treatment_plan,
e.visit_information_comments,
r.chemo_regimen_name
into chemo_session_summary_staging
from chemo_session_encounter e 
inner join chemo_session_regimens r on r.encounter_id = e.encounter_id
inner join all_patients p on p.emr_id = e.emr_id ;

ALTER TABLE chemo_session_summary_staging ADD 
index_asc INT NULL, 
index_desc INT NULL;

-- update index asc/desc on chemo_session_encounter table
drop table if exists #chemo_summary_indexes;
select  emr_id, obs_id,
ROW_NUMBER() over (PARTITION by emr_id order by encounter_datetime asc, obs_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by encounter_datetime desc, obs_id desc) "index_desc"
into #chemo_summary_indexes
from chemo_session_summary_staging ;

update cs
set cs.index_asc = csi.index_asc,
	cs.index_desc = csi.index_desc 
from chemo_session_summary_staging cs
inner join #chemo_summary_indexes csi on csi.obs_id = cs.obs_id; 
-- ------------------------------------------------------------------------------------
DROP TABLE IF EXISTS chemo_session_summary;
EXEC sp_rename 'chemo_session_summary_staging', 'chemo_session_summary';
