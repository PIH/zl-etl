DROP TABLE IF EXISTS #temp_export;
CREATE TABLE #temp_export
(
emr_id								varchar(255),
legacy_emr_id						varchar(255),
first_name							varchar(255),
last_name							varchar(255),
gender								varchar(255),
birthdate							date,
age									int,
last_pickup_accompagnateur			varchar(255),
hiv_note_accompagnateur				varchar(255),
address 							varchar(1000),
locality							varchar(255),
phone_number 						varchar(255),
arv_start_date						date,
initial_arv_regimen 				varchar(255),
arv_regimen							varchar(255),
months_on_art 						int,
site								varchar(255),
last_visit_date 					date,
last_med_pickup_date 				date,
last_med_pickup_months_dispensed 	int,
last_med_pickup_treatment_line 		varchar(255),
next_visit_date 					date,
next_med_pickup_date 				date,
days_late_for_next_visit 			int,
days_late_for_next_med_pickup 		int,
last_viral_load_date 				date,
last_viral_load_numeric 			int,
last_viral_load_undetected 			varchar(255),
months_since_last_viral_load 		int,
last_tb_coinfection_date			date,
last_weight							float,
last_weight_date					date,
last_height							float,
last_height_date					date,
enrollment_date						date,
current_treatment_status			varchar(255),
current_treatment_status_date		date,
current_outcome						varchar(255),
current_outcome_date				date,
latest_next_dispense_date			date,
med_pickup_status					varchar(255),
med_pickup_status_date				date,
combined_status						varchar(255),
combined_status_date				date
);

insert into #temp_export (emr_id)
select distinct emr_id from hiv_patient_program 
where emr_id is not null
;

update t
set legacy_emr_id = hp.hivemr_v1_id 
from #temp_export t
inner join hiv_patient hp on hp.emr_id = t.emr_id ;


update t 
	set first_name = p.given_name, 
	last_name = p.family_name ,
	gender = p.gender ,
	birthdate = p.birthdate ,
	age = p.age,
	address = CONCAT(p.address,' ', p.department,' ',p.commune,' ',section_communal) ,
	locality = p.locality,
  	phone_number = p.telephone_number,
	site = p.latest_enrollment_location 
from #temp_export t
inner join hiv_patient p on p.emr_id = t.emr_id 
 ;

update t 
set arv_start_date = hr.start_date 
from #temp_export t
inner join hiv_regimens hr on hr.order_id  = 
	(select top 1 order_id from hiv_regimens hr2 
	where order_action = 'NEW'	
	and drug_category = 'ART'
	and hr2.emr_id = t.emr_id 
	order by hr2.start_date asc, hr2.end_date asc );

update t
set months_on_art = DATEDIFF(month, arv_start_date, GETDATE())
from #temp_export t;

-- updating current drugs patient is on
-- all of the STUFF nonsense is what you have to do in this version of SQL Server to do the 
-- equivalent of group_concat or string_agg
update t
set initial_arv_regimen = reg.drugs
from #temp_export t
inner join 
	(SELECT emr_id, STUFF(
	         (SELECT DISTINCT ',' + drug_short_name
	          FROM hiv_regimens r
   	          inner join #temp_export t on t.emr_id = r.emr_id and t.arv_start_date = r.start_date 
	          WHERE r.emr_id = r2.emr_id
	          and order_action = 'NEW'	
			  and drug_category = 'ART'
			  FOR XML PATH (''))
	          , 1, 1, '')  AS drugs
	FROM hiv_regimens AS r2
	GROUP BY emr_id) reg on reg.emr_id = t.emr_id;

update t
set arv_regimen = reg.drugs
from #temp_export t
inner join 
	(SELECT emr_id, STUFF(
	         (SELECT DISTINCT ',' + drug_short_name
	          FROM hiv_regimens r
--   	          inner join #temp_export t on t.emr_id = r.emr_id and t.arv_start_date = r.start_date 
	          WHERE r.emr_id = r2.emr_id
	          and order_action = 'NEW'	
			  and drug_category = 'ART'
			  and end_date is null
	          FOR XML PATH (''))
	          , 1, 1, '')  AS drugs
	FROM hiv_regimens AS r2
	GROUP BY emr_id) reg on reg.emr_id = t.emr_id;


update t 
set last_visit_date = hv.visit_date,
	next_visit_date = hv.next_visit_date 
from #temp_export t
inner join hiv_visit hv on hv.emr_id = t.emr_id and hv.index_desc = 1;

update t 
set last_med_pickup_date = hd.dispense_date,
	last_med_pickup_months_dispensed = hd.months_dispensed ,
	last_med_pickup_treatment_line = hd.current_art_treatment_line, 
	next_med_pickup_date = hd.next_dispense_date 
from #temp_export t
inner join hiv_dispensing hd on hd.emr_id = t.emr_id and hd.dispense_date_descending = 1
;


update t
set days_late_for_next_visit = 
	CASE
		when DATEDIFF(day, next_visit_date, GETDATE())>0 then DATEDIFF(day, next_visit_date, GETDATE())
		else 0
	END
from #temp_export t
;	

update t
set days_late_for_next_med_pickup = 
	CASE
		when DATEDIFF(day, next_med_pickup_date, GETDATE())>0 then DATEDIFF(day, next_med_pickup_date, GETDATE())
		else 0
	END
from #temp_export t
;	


update t 
set last_viral_load_date = hv.vl_sample_taken_date ,
	last_viral_load_numeric = hv.viral_load ,
	last_viral_load_undetected = IIF(hv.vl_coded_results <> 'Detected','t',null) 
from #temp_export t
inner join hiv_viral_load hv on hv.emr_id = t.emr_id and hv.order_desc  = 1
;

update t 
set months_since_last_viral_load = DATEDIFF(month, t.last_viral_load_date , GETDATE())
from #temp_export t

update t
set last_tb_coinfection_date = l.specimen_collection_date 
from #temp_export t
inner join tb_lab_results l on l.encounter_id = 
	(select top 1 l2.encounter_id from tb_lab_results l2 
	where l2.emr_id = t.emr_id
	and ((l2.test_type = 'genxpert' and l2.test_result_text = ('Detected')) OR 
		 (l2.test_type = 'smear' and l2.test_result_text in ('1+','++','+++')))
	order by l2.specimen_collection_date  desc, l2.date_entered desc );

-- last weight
update t 
set last_weight = v.weight ,
	last_weight_date = v.encounter_datetime  
from #temp_export t
inner join all_vitals v on v.all_vitals_id = 
	(select top 1 all_vitals_id from all_vitals av2 
	where av2.emr_id = t.emr_id
	and av2.weight is not null
	order by av2.encounter_datetime desc, av2.date_entered desc );

-- last height
update t 
set last_height = v.height ,
	last_height_date = v.encounter_datetime  
from #temp_export t
inner join all_vitals v on v.all_vitals_id = 
	(select top 1 all_vitals_id from all_vitals av2 
	where av2.emr_id = t.emr_id
	and av2.height is not null
	order by av2.encounter_datetime desc, av2.date_entered desc );

update t 
set current_treatment_status = s.status_outcome,
	current_treatment_status_date = s.start_date  
from #temp_export t
inner join hiv_status s on s.status_id = 
	(select top 1 status_id  from hiv_status s2 
	where s2.emr_id = t.emr_id
	order by s2.start_date desc, s2.end_date  desc)
where  s.start_date <= GETDATE() 
	and (s.end_date >= GETDATE() or s.end_date is null);

update t 
set current_outcome = pp.outcome,
	current_outcome_date = pp.date_completed,
	enrollment_date = pp.date_enrolled 
from #temp_export t
inner join hiv_patient_program pp on pp.patient_program_id  = 
	(select top 1 patient_program_id from hiv_patient_program pp2 
	where pp2.emr_id = t.emr_id
	and pp2.date_enrolled <= GETDATE() 
	order by pp2.date_enrolled desc, pp2.date_completed  desc)
where pp.date_completed is not null;

update t 
set enrollment_date = pp.date_enrolled 
from #temp_export t
inner join hiv_patient_program pp on pp.patient_program_id  = 
	(select top 1 patient_program_id from hiv_patient_program pp2 
	where pp2.emr_id = t.emr_id
	and pp2.date_enrolled <= GETDATE() 
	order by pp2.date_enrolled desc, pp2.date_completed  desc)
;	

update t
set latest_next_dispense_date = d.next_dispense_date
from #temp_export t
left outer join hiv_dispensing d on d.emr_id = t.emr_id  and d.dispense_date_descending = 1
;

update t 
set med_pickup_status = 
	CASE
		when DATEDIFF(day, COALESCE(t.latest_next_dispense_date,t.enrollment_date),GETDATE()) <= 28 
			then 'active - on arvs'
		else 'ltfu'	
	END
from #temp_export t;


-- need to fix this:
update t 
set med_pickup_status_date = 
	CASE
		when DATEDIFF(day, COALESCE(t.latest_next_dispense_date,t.enrollment_date),GETDATE()) <= 28 
			then  COALESCE(t.last_med_pickup_date,t.enrollment_date)
		else 
			CASE 
				when t.latest_next_dispense_date is not null then DATEADD(day,28,t.latest_next_dispense_date)
				else DATEADD(day,28,t.enrollment_date)
			END
	END
from #temp_export t;

update t
set combined_status =
	CASE 
		when current_outcome is not null then current_outcome
		when med_pickup_status = 'active - on arvs' then 'active - on arvs'
		when current_treatment_status is not null then current_treatment_status
		else 'ltfu'
	END	
from #temp_export t; 

update t
set combined_status_date =
	CASE 
		when current_outcome is not null then current_outcome_date
		when med_pickup_status = 'active - on arvs' then med_pickup_status_date
		when current_treatment_status is not null then current_treatment_status_date
		else med_pickup_status_date
	END	
from #temp_export t;

update t
set last_pickup_accompagnateur = d.dispensed_accompagnateur
from #temp_export t
inner join hiv_dispensing d on d.encounter_id =
	(select top 1 encounter_id from hiv_dispensing d2
	where d2.emr_id = t.emr_id
	and d2.dispensed_accompagnateur is not NULL 
	order by d2.dispense_date desc)
;

update t
set hiv_note_accompagnateur = v.chw
from #temp_export t
inner join hiv_visit v on v.encounter_id =
	(select top 1 encounter_id from hiv_visit v2
	where v2.emr_id = t.emr_id
	and v2.chw is not NULL 
	order by v2.visit_date desc)
;

select 
emr_id,
legacy_emr_id,
first_name,
last_name,
gender,
birthdate,
age,
last_pickup_accompagnateur,
hiv_note_accompagnateur,
address ,
locality,
phone_number ,
arv_start_date,
initial_arv_regimen ,
arv_regimen,
months_on_art ,
site,
last_visit_date ,
last_med_pickup_date ,
last_med_pickup_months_dispensed ,
last_med_pickup_treatment_line ,
next_visit_date ,
next_med_pickup_date ,
days_late_for_next_visit ,
days_late_for_next_med_pickup ,
last_viral_load_date ,
last_viral_load_numeric ,
last_viral_load_undetected ,
months_since_last_viral_load ,
last_tb_coinfection_date,
last_weight,
last_weight_date,
last_height,
last_height_date,
combined_status "status",
combined_status_date "status_date"
from #temp_export
;
