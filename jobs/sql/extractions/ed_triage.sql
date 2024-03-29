
SELECT encounter_type_id into @EDTriageEnc from encounter_type where uuid = '74cef0a6-2801-11e6-b67b-9e71128cae77';
SELECT encounter_type_id into @consEnc from encounter_type where uuid = '92fd09b4-5335-4f7e-9f63-b2a663fd09a6';
SELECT name into @consEncName from encounter_type where uuid = '92fd09b4-5335-4f7e-9f63-b2a663fd09a6';
select form_id into @consForm from form where uuid = 'a3fc5c38-eb32-11e2-981f-96c0fcb18276';
select form_id into @edNoteForm from form where uuid = '793915d6-f8d9-11e2-8ff2-fd54ab5fdb2a';

SET @partition = '${partitionNum}';

set @locale = global_property_value('default_locale', @locale);

drop temporary table if exists temp_ED_Triage;
create temporary table temp_ED_Triage
(
patient_id               int,
encounter_id             int,
date_entered 			    date,
user_entered 			    varchar(100),
visit_id                 int,      
zlemr_id                 varchar(50),  
dossier_id               varchar(50),  
loc_registered           varchar(255),   
unknown_patient          varchar(255),        
ED_Visit_Start_Datetime  datetime,     
Triage_datetime          datetime,       
encounter_location       text,         
provider                 varchar(255), 
Triage_queue_status      varchar(255), 
Triage_Color             varchar(255), 
Triage_Score             int,          
Chief_Complaint          text,         
Weight_KG                double, 
Mobility                 text,         
Respiratory_Rate         double,       
Blood_Oxygen_Saturation  double,       
Pulse                    double,       
Systolic_Blood_Pressure  double,       
Diastolic_Blood_Pressure double,       
Temperature_C            double, 
Response                 text,         
Trauma_Present           text,         
Neurological             text,         
Burn                     text,         
Glucose                  text,         
Trauma_type              text,         
Digestive                text,         
Pregnancy                text,         
Respiratory              text,         
Pain                     text,         
Other_Symptom            text,         
Clinical_Impression      text,         
Pregnancy_Test           text,         
Glucose_Value            double,       
Paracetamol_dose         double,       
Treatment_Administered   text,         
Wait_Minutes             double,       
EDNote_encounter_id      int,         
Consult_encounter_id     int,
index_asc                int,
index_desc               int        
);

insert into temp_ED_Triage (patient_id, encounter_id, visit_id, Triage_datetime, date_entered, user_entered)
select e.patient_id, e.encounter_id, e.visit_id,e.encounter_datetime,e.date_created, encounter_creator_name(e.encounter_id)
from encounter e
where e.encounter_type = @EDTriageEnc and e.voided = 0
;

-- patient level info
DROP TEMPORARY TABLE IF EXISTS temp_ed_patient;
CREATE TEMPORARY TABLE temp_ed_patient
(
patient_id      int(11),      
zlemr_id        varchar(50),  
dossier_id      varchar(50),  
loc_registered  varchar(255),  
unknown_patient varchar(255)
);
   
insert into temp_ed_patient(patient_id)
select distinct patient_id from temp_ED_Triage;

create index temp_ed_patient_pi on temp_ed_patient(patient_id);

-- Dossier number
UPDATE temp_ed_patient SET dossier_id = DOSID(patient_id);

-- zlemr_id
UPDATE temp_ed_patient SET zlemr_id = ZLEMR(patient_id);

-- unknown patient
UPDATE temp_ed_patient SET unknown_patient = unknown_patient(patient_id);


update temp_ED_Triage t
inner join temp_ed_patient p on p.patient_id = t.patient_id
set t.dossier_id = p.dossier_id,
	t.zlemr_id = p.zlemr_id,
	t.unknown_patient = p.unknown_patient;


-- Provider
UPDATE temp_ED_Triage SET provider = PROVIDER(encounter_id);

-- encounter location
UPDATE temp_ED_Triage SET encounter_location = ENCOUNTER_LOCATION_NAME(encounter_id);

-- location registered
UPDATE temp_ED_Triage SET loc_registered = loc_registered(patient_id);

-- ED Visit Start Datetime
UPDATE temp_ED_Triage t
inner join visit v on t.visit_id = v.visit_id
set t.ED_Visit_Start_Datetime = v.date_started;

set @queue_status = concept_from_mapping('PIH','Triage queue status');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id =@queue_status
set t.Triage_queue_status = concept_name(o.value_coded,@locale);

set @triage_color = concept_from_mapping('PIH','Triage color classification');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id =@triage_color
set t.Triage_Color = concept_name(o.value_coded,@locale);

set @triage_score = concept_from_mapping('PIH','Triage score');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id =@triage_score
set t.Triage_Score = o.value_numeric;

set @chief_complaint = concept_from_mapping('CIEL','160531');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id =@chief_complaint
set t.Chief_Complaint = o.value_text;

set @weight = concept_from_mapping('PIH','WEIGHT (KG)');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id =@weight
set t.Weight_KG = o.value_numeric;

set @mobility = concept_from_mapping('PIH','Mobility');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id =@mobility
set t.Mobility = concept_name(o.value_coded,@locale);

set @rr = concept_from_mapping('PIH','RESPIRATORY RATE');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id = @rr
set t.Respiratory_Rate = o.value_numeric;

set @o2 = concept_from_mapping('PIH','BLOOD OXYGEN SATURATION');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id =@o2
set t.Blood_Oxygen_Saturation = o.value_numeric;

set @pulse = concept_from_mapping('PIH','PULSE');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id =@pulse
set t.Pulse = o.value_numeric;

set @sbp = concept_from_mapping('PIH','SYSTOLIC BLOOD PRESSURE');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id = @sbp
set t.Systolic_Blood_Pressure = o.value_numeric;

set @dbp = concept_from_mapping('PIH','DIASTOLIC BLOOD PRESSURE');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id =@dbp
set t.Diastolic_Blood_Pressure = o.value_numeric;

set @temp = concept_from_mapping('PIH','TEMPERATURE (C)');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id =concept_from_mapping('PIH','TEMPERATURE (C)')
set t.Temperature_C = o.value_numeric;

set @triage_diagnosis =concept_from_mapping('PIH','Triage diagnosis');
set @response = concept_from_mapping('PIH','Response triage symptom');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
  and o.concept_id = @triage_diagnosis
inner join concept_set cs on cs.concept_id = o.value_coded and cs.concept_set = @response
set t.Response = concept_name(o.value_coded,@locale);


set @trauma = concept_from_mapping('PIH','Traumatic Injury');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
  and o.concept_id =concept_from_mapping('PIH','Triage diagnosis')
  and o.value_coded = @trauma
set t.Trauma_Present = concept_name(o.value_coded,@locale);

set @neuro = concept_from_mapping('PIH','Neurological triage symptom');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
  and o.concept_id = @triage_diagnosis
inner join concept_set cs on cs.concept_id = o.value_coded and cs.concept_set = @neuro
set t.Neurological = concept_name(o.value_coded,@locale);

set @burn = concept_from_mapping('PIH','Burn triage symptom');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
  and o.concept_id =@triage_diagnosis
inner join concept_set cs on cs.concept_id = o.value_coded and cs.concept_set = @burn
set t.Burn = concept_name(o.value_coded,@locale);

set @glucose = concept_from_mapping('PIH','Glucose triage symptom');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
  and o.concept_id =@triage_diagnosis
inner join concept_set cs on cs.concept_id = o.value_coded and cs.concept_set = @glucose
set t.Glucose = concept_name(o.value_coded,@locale);

set @tt =  concept_from_mapping('PIH','Trauma triage symptom');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
  and o.concept_id =@triage_diagnosis
inner join concept_set cs on cs.concept_id = o.value_coded and cs.concept_set = @tt
set t.Trauma_type = concept_name(o.value_coded,@locale);

set @digestive = concept_from_mapping('PIH','Digestive triage symptom');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
  and o.concept_id =@triage_diagnosis
inner join concept_set cs on cs.concept_id = o.value_coded and cs.concept_set = @digestive
set t.Digestive = concept_name(o.value_coded,@locale);

set @pregancy = concept_from_mapping('PIH','10721');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
  and o.concept_id =@triage_diagnosis
inner join concept_set cs on cs.concept_id = o.value_coded and cs.concept_set = @pregancy
set t.Pregnancy = concept_name(o.value_coded,@locale);

set @respiratory =  concept_from_mapping('PIH','Respiratory triage symptom');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
  and o.concept_id = @triage_diagnosis
inner join concept_set cs on cs.concept_id = o.value_coded and cs.concept_set =@respiratory 
set t.Respiratory = concept_name(o.value_coded,@locale);

set @pain = concept_from_mapping('PIH','Pain triage symptom');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
  and o.concept_id =@triage_diagnosis
inner join concept_set cs on cs.concept_id = o.value_coded and cs.concept_set = @pain
set t.Pain = concept_name(o.value_coded,@locale);

set @other = concept_from_mapping('PIH','Other triage symptom');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
  and o.concept_id =@triage_diagnosis
inner join concept_set cs on cs.concept_id = o.value_coded and cs.concept_set = @other
set t.Other_Symptom = concept_name(o.value_coded,@locale);

set @ci = concept_from_mapping('PIH','CLINICAL IMPRESSION COMMENTS');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id =@ci
set t.Clinical_Impression = o.value_text;

set @pregancy_test = concept_from_mapping('PIH','B-HCG');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id =@pregancy_test
set t.Pregnancy_Test = concept_name(o.value_coded,@locale);

set @gv = concept_from_mapping('PIH','SERUM GLUCOSE');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id = @gv
set t.Glucose_Value = o.value_numeric;

set @pd = concept_from_mapping('PIH','Paracetamol dose (mg)');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id =@pd
set t.Paracetamol_dose = o.value_numeric;

set @wait = concept_from_mapping('PIH','3077');
update temp_ED_Triage t
inner join obs o on o.encounter_id = t.encounter_id and o.voided =0
and o.concept_id = @wait
set t.Wait_Minutes = round(o.value_numeric/60,0);

-- since treatment administered will be a list of obs potentially, 
-- this is done with a grouped subquery 
set @emergency_treatment = concept_from_mapping('PIH','Emergency treatment');
update temp_ED_Triage t
inner join 
  (select o.encounter_id, group_concat(concept_name(o.value_coded,@locale) separator ',') "treatments"
   from obs o
   where o.voided =0
   and o.concept_id =@emergency_treatment
   group by o.encounter_id) et on et.encounter_id = t.encounter_id 
set t.Treatment_Administered = et.treatments
;

-- The following statements gather information on the last consult (non-ED note) from the ED triage visit
set @diagnosis = concept_from_mapping('CIEL', '1284');

update temp_ED_Triage t
set Consult_encounter_id = latestEncForminVisit(patient_id, @consEncName,visit_id, @consForm,null);

drop temporary table if exists temp_cons_obs;
create temporary table temp_cons_obs
select o.obs_id, o.encounter_id, concept_name(o.value_coded,@locale) "dx_name", o.obs_datetime,  count(o2.obs_id) "index_asc"
from temp_ED_Triage t
inner join obs o on o.concept_id = @diagnosis 
	and o.encounter_id  = t.Consult_encounter_id 
	and o.voided = 0
inner join obs o2 on o2.encounter_id  = o.encounter_id 
	and o2.voided = 0
	and o2.concept_id = @diagnosis
	and o2.obs_id <= o.obs_id 
group by o.obs_id, o.encounter_id, o.value_coded, o.obs_datetime 
order by o.encounter_id, o.obs_datetime , o.obs_id 	
;

create index temp_cons_obs_ei on temp_cons_obs(encounter_id);

-- The following statements gather information on the last ED note from the ED triage visit
update temp_ED_Triage t
set EDNote_encounter_id = latestEncForminVisit(patient_id, @consEncName,visit_id, @edNoteForm,null);

drop temporary table if exists temp_ed_obs;
create temporary table temp_ed_obs
select o.obs_id, o.encounter_id, concept_name(o.value_coded,@locale) "dx_name", o.obs_datetime,  count(o2.obs_id) "index_asc"
from temp_ED_Triage t
inner join obs o on o.concept_id = @diagnosis 
	and o.encounter_id  = t.EDNote_encounter_id
	and o.voided = 0
inner join obs o2 on o2.encounter_id  = o.encounter_id 
	and o2.voided = 0
	and o2.concept_id = @diagnosis
	and o2.obs_id <= o.obs_id 
group by o.obs_id, o.encounter_id, o.value_coded, o.obs_datetime 
order by o.encounter_id, o.obs_datetime , o.obs_id 	
;

create index temp_ed_obs_ei on temp_ed_obs(encounter_id);


-- final output of data
Select
CONCAT(@partition, '-', encounter_id) as encounter_id,
date_entered,
user_entered,
CONCAT(@partition, '-', visit_id) as visit_id,
zlemr_id,
dossier_id,  
loc_registered,   
unknown_patient,        
ed_visit_start_datetime,     
triage_datetime,       
encounter_location,         
provider, 
triage_queue_status, 
triage_color, 
triage_score,          
chief_complaint,         
weight_kg, 
mobility,         
respiratory_rate,       
blood_oxygen_saturation,       
pulse,       
systolic_blood_pressure,       
diastolic_blood_pressure,       
temperature_c, 
response,         
trauma_present,         
neurological,         
burn,         
glucose,         
trauma_type,         
digestive,         
pregnancy,         
respiratory,         
pain,         
other_symptom,         
clinical_impression,         
pregnancy_test,         
glucose_value,       
paracetamol_dose,       
treatment_administered,         
wait_minutes,       
index_asc,
index_desc
from temp_ED_Triage
;
