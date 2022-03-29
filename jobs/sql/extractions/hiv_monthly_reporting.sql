SET sql_safe_updates = 0;

SET @hiv_program_id = (SELECT program_id FROM program WHERE retired = 0 AND uuid = 'b1cb1fc1-5190-4f7a-af08-48870975dafc');
select name into @hiv_Intake_Name from encounter_type where uuid = 'c31d306a-40c4-11e7-a919-92ebcb67fe33' ;
select name into @hiv_Followup_Name from encounter_type where uuid = 'c31d3312-40c4-11e7-a919-92ebcb67fe33' ;
select name into @hiv_Dispensing_Name from encounter_type where uuid = 'cc1720c9-3e4c-4fa8-a7ec-40eeaad1958c' ;
select encounter_type_id into @hiv_Dispensing_id from encounter_type where uuid = 'cc1720c9-3e4c-4fa8-a7ec-40eeaad1958c' ;

DROP TEMPORARY TABLE IF EXISTS temp_hiv_patient_programs;
CREATE TEMPORARY TABLE temp_hiv_patient_programs
SELECT patient_id, patient_program_id, date_enrolled, date_completed
FROM patient_program WHERE voided=0 AND program_id = @hiv_program_id;


DROP TEMPORARY TABLE IF EXISTS temp_eom_appts;
CREATE TEMPORARY TABLE temp_eom_appts
(
monthly_reporting_id		INT(11) AUTO_INCREMENT,
patient_id			INT(11),
patient_program_id		INT(11),
date_enrolled			DATETIME,
date_completed			DATETIME,
reporting_date			DATE,
latest_hiv_note_encounter_id	INT(11),
latest_hiv_visit_date		DATETIME,
latest_expected_hiv_visit_date	DATETIME,
hiv_visit_days_late		INT,
latest_dispensing_encounter_id	INT(11),
latest_dispensing_date		DATETIME,
latest_expected_dispensing_date	DATETIME,
dispensing_days_late		INT,
latest_hiv_viral_load_obs_group	INT(11),
latest_hiv_viral_load_date	DATETIME,
latest_hiv_viral_load_coded	VARCHAR(255),
latest_hiv_viral_load		INT,
latest_arv_regimen_encounter_id	INT(11),
latest_arv_regimen_date		DATETIME,
latest_arv_regimen_line		VARCHAR(255),
latest_arv_dispensed_id		INT(11),
latest_arv_dispensed_date	DATETIME,
latest_arv_dispensed_line	VARCHAR(255),
PRIMARY KEY (monthly_reporting_id)
);

create index eom_patient on temp_eom_appts(patient_id);

call load_end_of_month_dates('2020-01-01',CURRENT_DATE()) ;

-- insert end of month date rows for each patient for when they are active 
insert into temp_eom_appts (patient_id,patient_program_id,date_enrolled, date_completed, reporting_date)
select * from temp_hiv_patient_programs t
inner join END_OF_MONTH_DATES e 
	on e.reporting_date >= last_day(t.date_enrolled)  
	and (last_day(t.date_completed) >= e.reporting_date or t.date_completed is null)
	order by patient_program_id asc, e.reporting_date
	;

-- HIV notes dates/info
update temp_eom_appts t
set latest_hiv_note_encounter_id =
 latestEncBetweenDates(t.patient_id, CONCAT(@hiv_intake_name,',',@hiv_followup_name), null,t.reporting_date);

update temp_eom_appts t
set latest_hiv_visit_date = encounter_date(t.latest_hiv_note_encounter_id);

update temp_eom_appts t
set latest_expected_hiv_visit_date = obs_value_datetime(t.latest_hiv_note_encounter_id,'PIH','5096');

update temp_eom_appts t
set hiv_visit_days_late = DATEDIFF(t.reporting_date ,ifnull(latest_expected_hiv_visit_date,ifnull(latest_hiv_visit_date,date_enrolled)  )); 

-- HIV Dispensing dates/info
update temp_eom_appts t
set latest_dispensing_encounter_id =
 latestEncBetweenDates(t.patient_id, @hiv_Dispensing_Name, null,t.reporting_date);

update temp_eom_appts t
set latest_dispensing_date = encounter_date(t.latest_dispensing_encounter_id);

update temp_eom_appts t
set latest_expected_dispensing_date = obs_value_datetime(t.latest_dispensing_encounter_id,'PIH','5096');

update temp_eom_appts t
set dispensing_days_late = DATEDIFF(t.reporting_date ,ifnull(latest_expected_dispensing_date,ifnull(latest_dispensing_date,date_enrolled)  )); 

-- last viral load info
update temp_eom_appts t
inner join obs o on obs_id = 
	(select obs_id from obs o2
	where o2.voided = 0 
	and o2.person_id = t.patient_id 
	and o2.concept_id = CONCEPT_FROM_MAPPING("PIH", "HIV viral load construct")
	and o2.obs_datetime >= t.date_enrolled 
	and o2.obs_datetime <= t.reporting_date 
	order by obs_datetime desc, obs_id desc limit 1)
set latest_hiv_viral_load_obs_group = o.obs_id ;

update temp_eom_appts t
set latest_hiv_viral_load_date = obs_date(latest_hiv_viral_load_obs_group);

update temp_eom_appts t
set latest_hiv_viral_load_coded	= obs_from_group_id_value_coded_list(latest_hiv_viral_load_obs_group,'CIEL','1305',@locale);

update temp_eom_appts t
set latest_hiv_viral_load	= obs_from_group_id_value_numeric(latest_hiv_viral_load_obs_group,'CIEL','856');

-- latest arv treatment line 
-- a temp table is loaded with the most recent HIV order information for each row
-- this is used to update the main temp table
drop temporary table if exists temp_last_arv_order_id;
create temporary table temp_last_arv_order_id 
	select t.monthly_reporting_id, o.date_activated, o.encounter_id  
	from temp_eom_appts t 
	inner join 
		(select o2.patient_id ,  o2.date_activated, o2.encounter_id  
		from orders o2 
		where o2.voided = 0
		and o2.order_reason = concept_from_mapping('CIEL','138405') -- HIV order reason
		order by if(o2.date_stopped is null,0,1) asc, ifnull(o2.scheduled_date, o2.date_activated) desc) o on o.patient_id = t.patient_id and o.date_activated < t.reporting_date  
	group by t.monthly_reporting_id 
;

update temp_eom_appts t 
inner join temp_last_arv_order_id tlao on tlao.monthly_reporting_id = t.monthly_reporting_id 
set latest_arv_regimen_date = tlao.date_activated,
	latest_arv_regimen_encounter_id = tlao.encounter_id ;

update temp_eom_appts t 
set latest_arv_regimen_line = obs_value_coded_list(t.latest_arv_regimen_encounter_id, 'PIH','13115',@locale );

-- latest arv dispensing
-- a temp table is loaded with the most recent HIV dispensing encounter information for each row
-- this is used to update the main temp table
drop temporary table if exists temp_last_arv_dispensing_id;
create temporary table temp_last_arv_dispensing_id 
	select t.monthly_reporting_id, e.encounter_id, e.encounter_datetime  
	from temp_eom_appts t 
	inner join 
		(select e2.patient_id, e2.encounter_id, e2.encounter_datetime 
		from encounter e2
		inner join obs o on o.voided = 0 and o.encounter_id = e2.encounter_id and  o.concept_id =  concept_from_mapping('PIH','1535') -- medication name
			and o.value_coded in (concept_from_mapping('PIH','3013'),concept_from_mapping('PIH','2848'),concept_from_mapping('PIH','13960')) -- ARV1, ARV2 and ARV3
		where e2.voided = 0
		and e2.encounter_type = @hiv_Dispensing_id 
		order by e2.encounter_datetime desc, e2.encounter_id desc) e on e.patient_id  = t.patient_id and e.encounter_datetime <= t.reporting_date 
	group by t.monthly_reporting_id;		
		
update temp_eom_appts t 
inner join temp_last_arv_dispensing_id tlad on tlad.monthly_reporting_id = t.monthly_reporting_id 
set latest_arv_dispensed_id = tlad.encounter_id, 
	latest_arv_dispensed_date = tlad.encounter_datetime;

update temp_eom_appts t 
set latest_arv_dispensed_line = obs_value_coded_list(t.latest_arv_dispensed_id, 'PIH','13115',@locale );

SELECT
	patient_id,
	zlemr(patient_id),
	date_enrolled ,
	date_completed ,
	reporting_date,
	latest_hiv_note_encounter_id,
	latest_hiv_visit_date,
	latest_expected_hiv_visit_date,
	hiv_visit_days_late,
	latest_dispensing_encounter_id,
	latest_dispensing_date,
	latest_expected_dispensing_date,
	dispensing_days_late,
	latest_hiv_viral_load_date,
	latest_hiv_viral_load_coded,
	latest_hiv_viral_load,
	latest_arv_regimen_date,
	latest_arv_regimen_line,
	latest_arv_dispensed_date,
	latest_arv_dispensed_line
from temp_eom_appts;
