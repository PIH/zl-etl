-- update index asc/desc on all_visits table
select visit_id, emr_id, visit_date_started, 
ROW_NUMBER() over (PARTITION by emr_id order by visit_date_started asc, visit_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by visit_date_started desc, visit_id desc) "index_desc"
into #all_visits_indexes
from all_visits av ;

update  av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from all_visits av	
inner join #all_visits_indexes avi on avi.visit_id = av.visit_id ; 

-- update index asc/desc on all_encounters table
select encounter_id, emr_id, encounter_datetime, 
ROW_NUMBER() over (PARTITION by emr_id order by encounter_datetime asc, visit_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by encounter_datetime desc, visit_id desc) "index_desc"
into #all_encounters_indexes
from all_encounters ae ;

update  ae
set ae.index_asc = aei.index_asc,
	ae.index_desc = aei.index_desc 
from all_encounters ae
inner join #all_encounters_indexes aei on aei.encounter_id = ae.encounter_id; 



-- update index asc/desc on all_vitals table
select  emr_id, encounter_datetime, date_entered, 
ROW_NUMBER() over (PARTITION by emr_id order by encounter_datetime asc, date_entered asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by encounter_datetime desc, date_entered desc) "index_desc"
into #all_vitals_indexes
from all_vitals av ;

update  av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from all_vitals av
inner join #all_vitals_indexes avi on avi.emr_id = av.emr_id
and avi.encounter_datetime = av.encounter_datetime
and avi.date_entered = av.date_entered; 

-- update index asc/desc on covid_disposition table
select  emr_id, encounter_id, 
ROW_NUMBER() over (PARTITION by emr_id order by encounter_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by encounter_id desc) "index_desc"
into #covid_disposition_indexes
from covid_disposition av ;

update  av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from covid_disposition av
inner join #covid_disposition_indexes avi on avi.emr_id = av.emr_id
and avi.encounter_id = av.encounter_id; 


-- update index asc/desc on covid_visit table
select  emr_id, encounter_id, 
ROW_NUMBER() over (PARTITION by emr_id order by encounter_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by encounter_id desc) "index_desc"
into #covid_visit_indexes
from covid_visit av ;

update  av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from covid_visit av
inner join #covid_visit_indexes avi on avi.emr_id = av.emr_id
and avi.encounter_id = av.encounter_id; 

-- update index asc/desc on datakind_encounter table
/* select  patient_id, encounter_id, 
ROW_NUMBER() over (PARTITION by patient_id order by encounter_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by patient_id order by encounter_id desc) "index_desc"
into #datakind_encounter_indexes
from datakind_encounter av ;

update  av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from datakind_encounter av
inner join #datakind_encounter_indexes avi on avi.patient_id = av.patient_id
and avi.encounter_id = av.encounter_id;  */


-- update index asc/desc on eid_visit table
select  emr_id, encounter_id, 
ROW_NUMBER() over (PARTITION by emr_id order by encounter_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by encounter_id desc) "index_desc"
into #eid_visit_indexes
from eid_visit av ;

update  av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from eid_visit av
inner join #eid_visit_indexes avi on avi.emr_id = av.emr_id
and avi.encounter_id = av.encounter_id; 


-- update index asc/desc on hiv_regimens table
select  emr_id, order_id, drug_category,start_date,
ROW_NUMBER() over (PARTITION by emr_id order by order_id asc,drug_category asc, start_date asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id  order by order_id desc, drug_category desc, start_date desc) "index_desc"
into #hiv_regimens_catg_indexes
from hiv_regimens av ;

update  av
set av.index_ascending_category = avi.index_asc,
	av.index_descending_category = avi.index_desc 
from hiv_regimens av
inner join #hiv_regimens_catg_indexes avi on avi.emr_id = av.emr_id
and avi.order_id = av.order_id
and avi.drug_category = av.drug_category
and avi.start_date = av.start_date; 


select  emr_id, order_id, start_date,
ROW_NUMBER() over (PARTITION by emr_id order by order_id asc,start_date asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id  order by order_id desc, start_date desc) "index_desc"
into #hiv_regimens_catg_indexes
from hiv_regimens av ;

update  av
set av.index_ascending_patient = avi.index_asc,
	av.index_descending_patient = avi.index_desc 
from hiv_regimens av
inner join #hiv_regimens_catg_indexes avi on avi.emr_id = av.emr_id
and avi.order_id = av.order_id
and avi.start_date = av.start_date; 


-- update index asc/desc on hiv_status table
select  patient_program_id, start_date, status_id,
ROW_NUMBER() over (PARTITION by patient_program_id order by start_date asc, status_id asc ) "index_asc",
ROW_NUMBER() over (PARTITION by patient_program_id order by start_date desc, status_id desc ) "index_desc"
into #hiv_status_prog_indexes
from hiv_status av ;

update  av
set av.index_program_ascending = avi.index_asc,
	av.index_program_descending = avi.index_desc 
from hiv_status av
inner join #hiv_status_prog_indexes avi on avi.patient_program_id = av.patient_program_id
and avi.start_date = av.start_date
and avi.status_id = av.status_id; 


select  emr_id, start_date, patient_program_id, status_id,
ROW_NUMBER() over (PARTITION by emr_id order by start_date ASC, patient_program_id ASC,  status_id ASC) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by start_date desc, patient_program_id desc,  status_id desc) "index_desc"
into #hiv_status_pat_indexes
from hiv_status av ;

update  av
set av.index_patient_ascending = avi.index_asc,
	av.index_patient_descending = avi.index_desc 
from hiv_status av
inner join #hiv_status_pat_indexes avi on avi.emr_id = av.emr_id
and avi.patient_program_id = av.patient_program_id
and avi.start_date = av.start_date
and avi.status_id = av.status_id; 


-- update index asc/desc on hiv_tests table
select  emr_id, encounter_id, specimen_collection_date, test_type, date_created,
ROW_NUMBER() over (PARTITION by emr_id order by encounter_id asc, specimen_collection_date asc, date_created asc, test_type asc ) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by encounter_id DESC, specimen_collection_date DESC, date_created DESC, test_type DESC ) "index_desc"
into #hiv_tests_indexes
from hiv_tests av ;

update  av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from hiv_tests av
inner join #hiv_tests_indexes avi on avi.emr_id = av.emr_id
and avi.encounter_id = av.encounter_id
and avi.specimen_collection_date = av.specimen_collection_date
and avi.test_type = av.test_type
and avi.date_created = av.date_created
; 

-- update index asc/desc on hiv_viral_load table
select  emr_id, vl_sample_taken_date, date_entered, encounter_id,
ROW_NUMBER() over (PARTITION by emr_id order by vl_sample_taken_date asc, date_entered asc ) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by vl_sample_taken_date DESC, date_entered DESC ) "index_desc"
into #hiv_viral_load_indexes
from hiv_viral_load av ;

update av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from hiv_viral_load av
inner join #hiv_viral_load_indexes avi on avi.emr_id = av.emr_id
and avi.encounter_id = av.encounter_id
and avi.vl_sample_taken_date = av.vl_sample_taken_date
and avi.date_entered = av.date_entered
; 

-- update index asc/desc on hiv_visit table

select  emr_id, visit_date, encounter_id,
ROW_NUMBER() over (PARTITION by emr_id order by visit_date ASC, encounter_id ASC) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by visit_date desc, encounter_id desc ) "index_desc"
into #hiv_visit_indexes
from hiv_visit av ;

update av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from hiv_visit av
inner join #hiv_visit_indexes avi on avi.emr_id = av.emr_id
and avi.encounter_id = av.encounter_id
and avi.visit_date = av.visit_date; 

-- update index asc/desc on mch_status table
select  emr_id, start_date, patient_program_id,
ROW_NUMBER() over (PARTITION by emr_id order by start_date asc, patient_program_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by start_date DESC, patient_program_id DESC) "index_desc"
into #mch_status_indexes
from mch_status av ;

update av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from mch_status av
inner join #mch_status_indexes avi on avi.emr_id = av.emr_id
and avi.start_date = av.start_date
and avi.patient_program_id = av.patient_program_id; 


-- update index asc/desc on mch_visit table
select  emr_id, visit_date, encounter_id,
ROW_NUMBER() over (PARTITION by emr_id order by visit_date asc, encounter_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by visit_date DESC, encounter_id DESC) "index_desc"
into #mch_visit_indexes
from mch_visit av ;

update av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from mch_visit av
inner join #mch_status_indexes avi on avi.emr_id = av.emr_id
and avi.visit_date = av.visit_date
and avi.encounter_id = av.encounter_id; 


-- update index asc/desc on pmtct_pregnancy table
select  emr_id, pmtct_enrollment_date,
ROW_NUMBER() over (PARTITION by emr_id order by pmtct_enrollment_date asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by pmtct_enrollment_date DESC) "index_desc"
into #pmtct_pregnancy_indexes
from pmtct_pregnancy av ;

update av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from pmtct_pregnancy av
inner join #pmtct_pregnancy_indexes avi on avi.emr_id = av.emr_id
and avi.pmtct_enrollment_date = av.pmtct_enrollment_date; 

-- update index asc/desc on pmtct_visits table
select  emr_id, visit_date,visit_id,encounter_id,
ROW_NUMBER() over (PARTITION by emr_id order by visit_date asc, visit_id asc, encounter_id asc) "index_asc",
ROW_NUMBER() over (PARTITION by emr_id order by visit_date DESC, visit_id DESC, encounter_id DESC) "index_desc"
into #pmtct_visits_indexes
from pmtct_visits av ;

update av
set av.index_asc = avi.index_asc,
	av.index_desc = avi.index_desc 
from pmtct_visits av
inner join #pmtct_visits_indexes avi on avi.emr_id = av.emr_id
and avi.visit_date = av.visit_date
and avi.visit_id = av.visit_id
and avi.encounter_id = av.encounter_id
; 
