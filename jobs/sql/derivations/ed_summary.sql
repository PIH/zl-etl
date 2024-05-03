drop table if exists ed_summary_staging;
create table ed_summary_staging
(
emr_id                     varchar(50),  
encounter_id               varchar(50),  
triage_datetime            datetime,      
date_entered               date,         
user_entered               varchar(100), 
visit_id                   varchar(50),   
zlemr_id                   varchar(50),   
dossier_id                 varchar(50),   
loc_registered             varchar(255),  
unknown_patient            varchar(255),  
ed_visit_start_datetime    datetime,      
encounter_location         text,          
provider                   varchar(255),  
triage_queue_status        varchar(255),  
triage_Color               varchar(255),  
triage_score               int,           
index_asc                  int,          
index_desc                 int,           
ed_note_enc_id             varchar(50),  
ednote_datetime            datetime,     
ednote_disposition         varchar(255), 
ed_diagnosis1              varchar(255), 
ed_diagnosis2              varchar(255), 
ed_diagnosis3              varchar(255), 
ed_diagnosis_noncoded      varchar(255), 
consult_enc_id             varchar(50),  
consult_datetime           datetime,     
consult_disposition        varchar(255), 
consult_diagnosis1         varchar(255), 
consult_diagnosis2         varchar(255), 
consult_diagnosis3         varchar(255), 
consult_diagnosis_noncoded varchar(255)  
);

insert ed_summary_staging (
	emr_id,
	encounter_id,
	date_entered,
	user_entered,
	visit_id,
	zlemr_id,
	dossier_id,
	loc_registered,
	unknown_patient,
	ed_visit_start_datetime,
	triage_datetime,
	encounter_location,
	provider,
	triage_queue_status,
	triage_Color,
	triage_score,
	index_asc,
	index_desc)
select 	
	zlemr_id                 ,
	encounter_id,
	date_entered,
	user_entered,
	visit_id,
	zlemr_id,
	dossier_id,
	loc_registered,
	unknown_patient,
	ed_visit_start_datetime,
	triage_datetime,
	encounter_location,
	provider,
	triage_queue_status,
	triage_Color,
	triage_score,
	index_asc,
	index_desc
from ed_triage ;	

-- next ed note information
update es
set ed_note_enc_id = ce.encounter_id 
from ed_summary_staging es
inner join consult_encounters ce on ce.encounter_id =
	(select top 1 ce2.encounter_id
	from consult_encounters ce2
	where ce2.visit_id = es.visit_id
	and ce2.trauma is not nULL 
	and ce2.encounter_datetime >= es.triage_datetime
	order by ce2.encounter_datetime desc, ce2.encounter_id desc);

update es 
 set ednote_datetime = ce.encounter_datetime,
     ednote_disposition = ce.disposition
from ed_summary_staging es
inner join consult_encounters ce
	on ce.encounter_id = es.ed_note_enc_id;

update es 
 set ed_diagnosis1 = d.diagnosis_coded_fr
from ed_summary_staging es
inner join all_diagnosis_past_year d on d.obs_id = 
	(select top 1 d2.obs_id
	from all_diagnosis_past_year d2
	where d2.encounter_id = es.ed_note_enc_id
	and d2.coded = 1
	order by obs_id desc);

update es 
 set ed_diagnosis2 = d.diagnosis_coded_fr
from ed_summary_staging es
inner join all_diagnosis_past_year d on d.obs_id = 
	(select top 1 d2.obs_id
	from all_diagnosis_past_year d2
	where d2.encounter_id = es.ed_note_enc_id
	and d2.coded = 1
	and d2.diagnosis_coded_fr <> ed_diagnosis1
	order by obs_id desc);

update es 
 set ed_diagnosis3 = d.diagnosis_coded_fr
from ed_summary_staging es
inner join all_diagnosis_past_year d on d.obs_id = 
	(select top 1 d2.obs_id
	from all_diagnosis_past_year d2
	where d2.encounter_id = es.ed_note_enc_id
	and d2.coded = 1
	and d2.diagnosis_coded_fr not in (ed_diagnosis1, ed_diagnosis2)
	order by obs_id desc);

update es 
 set ed_diagnosis_noncoded = d.diagnosis_entered
from ed_summary_staging es
inner join all_diagnosis_past_year d on d.obs_id = 
	(select top 1 d2.obs_id
	from all_diagnosis_past_year d2
	where d2.encounter_id = es.ed_note_enc_id
	and d2.coded = 0
	order by obs_id desc);

-- next consult note information
update es
set consult_enc_id = ce.encounter_id 
from ed_summary_staging es
inner join consult_encounters ce on ce.encounter_id =
	(select top 1 ce2.encounter_id
	from consult_encounters ce2
	where ce2.visit_id = es.visit_id
	and ce2.trauma is null 
	and ce2.encounter_datetime >= es.triage_datetime
	order by ce2.encounter_datetime desc, ce2.encounter_id desc);

update es 
 set consult_datetime = ce.encounter_datetime,
     consult_disposition = ce.disposition
from ed_summary_staging es
inner join consult_encounters ce
	on ce.encounter_id = es.consult_enc_id;


update es 
 set consult_datetime = ce.encounter_datetime,
     consult_disposition = ce.disposition
from ed_summary_staging es
inner join consult_encounters ce
	on ce.encounter_id = es.consult_enc_id;


update es 
 set consult_diagnosis1 = d.diagnosis_coded_fr
from ed_summary_staging es
inner join all_diagnosis_past_year d on d.obs_id = 
	(select top 1 d2.obs_id
	from all_diagnosis_past_year d2
	where d2.encounter_id = es.consult_enc_id
	and d2.coded = 1
	order by obs_id desc);

update es 
 set consult_diagnosis2 = d.diagnosis_coded_fr
from ed_summary_staging es
inner join all_diagnosis_past_year d on d.obs_id = 
	(select top 1 d2.obs_id
	from all_diagnosis_past_year d2
	where d2.encounter_id = es.consult_enc_id
	and d2.coded = 1
	and d2.diagnosis_coded_fr <> consult_diagnosis1
	order by obs_id desc);

update es 
 set consult_diagnosis3 = d.diagnosis_coded_fr
from ed_summary_staging es
inner join all_diagnosis_past_year d on d.obs_id = 
	(select top 1 d2.obs_id
	from all_diagnosis_past_year d2
	where d2.encounter_id = es.consult_enc_id
	and d2.coded = 1
	and d2.diagnosis_coded_fr not in (consult_diagnosis1, consult_diagnosis2)
	order by obs_id desc);

update es 
 set consult_diagnosis_noncoded = d.diagnosis_entered
from ed_summary_staging es
inner join all_diagnosis_past_year d on d.obs_id = 
	(select top 1 d2.obs_id
	from all_diagnosis_past_year d2
	where d2.encounter_id = es.consult_enc_id
	and d2.coded = 0
	order by obs_id desc);

DROP TABLE IF EXISTS ed_summary;
EXEC sp_rename 'ed_summary_staging', 'ed_summary';
