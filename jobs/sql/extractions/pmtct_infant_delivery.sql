set sql_safe_updates = 0;
set session group_concat_max_len = 100000;

select program_id into @eidProgram from program where uuid = '7e06bf82-9f1a-4218-b68f-823082ef519b';
select encounter_type_id into @labResultsEnc from encounter_type where uuid = '4d77916a-0620-11e5-a6c0-1697f925ec7b';
select name into @hivDispEncName from encounter_type where uuid = 'cc1720c9-3e4c-4fa8-a7ec-40eeaad1958c';

drop temporary table if exists temp_eid;

create temporary table temp_eid
(
patient_id int,
infant_age_in_months int,
age_cat_infant varchar(50),
eid_date_enrolled	datetime,
eid_date_completed	datetime,
mom_hiv_emr_id int,
mom_age_at_delivery int,
delivery_date date,
delivery_with_partograph_obs int,
delivery_with_partograph boolean,
delivery_location_cat  varchar(255),
maternity_clinic_type_obs int, 
maternity_clinic_type  varchar(255),
breastfeeding_status  varchar(255),
hiv_rapid_test_obs int(11),
hiv_rapid_test_date date,
hiv_test_result varchar(255),
pcr_test_obs int(11),
pcr_test_date date,
pcr_result varchar(255),
art_start_date date,
PMTCT_enrollment_date date,
is_active_on_art boolean,
next_dispensing_date date,
is_LTFU boolean,
is_exposed boolean,
is_lab_specimen_rejected boolean,
health_facility_obs int,
health_facility varchar(255)
);

insert into temp_eid (patient_id,eid_date_enrolled,eid_date_completed)
select patient_id,date_enrolled,date_completed 
from patient_program pp 
where program_id = @eidProgram
and voided = 0
;

-- current age, category
update temp_eid t 
set infant_age_in_months = current_age_in_months(patient_id);

update temp_eid t 
set age_cat_infant = 
case 
	when infant_age_in_months<2 then '<2 mo'
	when infant_age_in_months>=2 and infant_age_in_months<=12 then '2-12 mo'
	else '> 2 mo'	
end;	

-- hiv rapid testing info
update temp_eid t
set hiv_rapid_test_obs = latestObs(t.patient_id, concept_from_mapping('PIH','13135'),null );

update temp_eid t
set hiv_rapid_test_date = obs_date(t.hiv_rapid_test_obs);

update temp_eid t
set hiv_test_result = obs_from_group_id_value_coded_list(hiv_rapid_test_obs,'PIH','1040',@locale);

-- pcr testing info
update temp_eid t
set pcr_test_obs = latestObs(t.patient_id, concept_from_mapping('PIH','1030'),null );

update temp_eid t
set pcr_test_date = obs_date(t.pcr_test_obs);

update temp_eid t
inner join obs o on o.obs_id = t.pcr_test_obs
set pcr_result = concept_name(o.value_coded,@locale);

-- art start date
update temp_eid t
set art_start_date = 
	(select min(ifnull(o.scheduled_date, o.date_activated)) from orders o
	where o.patient_id  = t.patient_id
	and o.order_reason = concept_from_mapping('PIH','11197'));

-- active on art
update temp_eid t
inner join orders o on o.patient_id = t.patient_id  and o.order_reason = concept_from_mapping('PIH','11197')
	and ifnull(o.scheduled_date, o.date_activated) <= NOW()
	and (ifnull(o.date_stopped, o.auto_expire_date) is null 
		or (ifnull(o.date_stopped, o.auto_expire_date) > now()))
set is_active_on_art = 1 
;

-- is ltfu
update temp_eid t 
set next_dispensing_date = date(obs_value_datetime(latestEnc(patient_id, @hivDispEncName, null),'PIH','5096'));

update temp_eid t 
set is_LTFU = if(date_add(next_dispensing_date, interval 28 day) > CURRENT_DATE(),'0','1' ); 

-- delivery with partograph
update temp_eid t
set delivery_with_partograph_obs = latestObs(t.patient_id, concept_from_mapping('PIH','13964'), null);

update temp_eid t
set delivery_with_partograph = value_coded_as_boolean(delivery_with_partograph_obs);

-- maternity clinic type
update temp_eid t
set maternity_clinic_type_obs = latestObs(t.patient_id, concept_from_mapping('CIEL', '164851'), null);
update temp_eid t
set maternity_clinic_type = (select concept_name(value_coded, 'en') from obs where voided = 0 and obs_id = t.maternity_clinic_type_obs);

update temp_eid t
set health_facility_obs = latestObs(t.patient_id, concept_from_mapping('CIEL', '163529'), null);
update temp_eid t
set health_facility = (select location_name(value_text) from obs where voided = 0 and obs_id = t.health_facility_obs);

update temp_eid t set t.breastfeeding_status = value_coded_name(latest_obs(t.patient_id, 'CIEL', '1151'), 'en');

select  
zlemr(patient_id),
infant_age_in_months,
age_cat_infant,
eid_date_enrolled,
eid_date_completed,
mom_hiv_emr_id,
mom_age_at_delivery,
delivery_date,
delivery_with_partograph,
delivery_location_cat,
maternity_clinic_type,
breastfeeding_status,
hiv_rapid_test_date,
hiv_test_result,
pcr_test_date,
pcr_result,
art_start_date,
is_active_on_art,
next_dispensing_date,
is_LTFU,
1 "is_exposed",
is_lab_specimen_rejected,
health_facility
from temp_eid;
