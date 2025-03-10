DROP TABLE IF EXISTS hiv_patient_summary_status_staging;
CREATE TABLE hiv_patient_summary_status_staging
(
 emr_id                           varchar(255),  
 legacy_emr_id                    varchar(255),  
 first_name                       varchar(255),  
 last_name                        varchar(255),  
 gender                           varchar(255),  
 birthdate                        date,          
 age                              int,           
 last_pickup_accompagnateur       varchar(255),  
 hiv_note_accompagnateur          varchar(255),  
 address                          varchar(1000), 
 locality                         varchar(255),  
 phone_number                     varchar(255),
 user_entered	                  varchar(100),
 initial_enrollment_date          date,
 dispense_before_prescription     bit,           
 arv_start_date                   date,          
 initial_arv_regimen              varchar(255),  
 latest_arv_dispensed             varchar(1000), 
 months_on_art                    int,           
 inh_start_date                   date,
 inh_end_date					  date,
 site                             varchar(255),  
 last_visit_date                  date,          
 second_to_latest_hiv_visit_date  DATE, 
 last_med_pickup_date             date,          
 last_med_pickup_months_dispensed int,           
 last_med_pickup_treatment_line   varchar(255),  
 next_visit_date                  date,          
 next_med_pickup_date             date,          
 days_late_for_next_visit         int,           
 days_late_for_next_med_pickup    int,           
 last_viral_load_collection_date  date,         
 last_viral_load_results_date     date,          
 last_viral_load_numeric          int,           
 last_viral_load_undetected       varchar(255),  
 months_since_last_viral_load     int,           
 last_tb_coinfection_date         date,          
 last_weight                      float,         
 last_weight_date                 date,          
 last_height                      float,         
 last_height_date                 date,          
 enrollment_date                  date,          
 current_treatment_status         varchar(255),  
 current_treatment_status_date    date,          
 current_outcome                  varchar(255),  
 current_outcome_date             date,        
 tb_diag_date                     date,
 tb_diag_test                     varchar(255),
 tb_tx_start_date                 date,
 tb_tx_end_date                   date,
 latest_next_dispense_date        date,          
 med_pickup_status                varchar(255),  
 med_pickup_status_date           date,          
 status                           varchar(255),  
 status_date                      date,
 last_bp_diastolic                float,
 last_bp_diastolic_date           date,
 last_bp_systolic                 float,
 last_bp_systolic_date            date,
 last_htn_diag                    text,
 last_htn_diag_date               date,
 biometrics_collected             bit,    
 latest_biometrics_collection_date     datetime,
 biometrics_collector varchar(100)
);

insert into hiv_patient_summary_status_staging (emr_id)
select distinct emr_id from hiv_patient_program
where emr_id is not null
;

update t
set legacy_emr_id = hp.hivemr_v1_id
    from hiv_patient_summary_status_staging t
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
    user_entered=p.user_entered,
    site = p.latest_enrollment_location
    from hiv_patient_summary_status_staging t
inner join hiv_patient p on p.emr_id = t.emr_id
;

update t
set t.initial_enrollment_date = pp.min_date_enrolled
from hiv_patient_summary_status_staging t
inner join (select emr_id, min(date_enrolled) as min_date_enrolled from hiv_patient_program group by emr_id) pp on pp.emr_id = t.emr_id
;

DROP TABLE IF EXISTS #temp_min_dispensing;
CREATE TABLE #temp_min_dispensing
(
    emr_id 						varchar(255),
    min_dispense_date			datetime,
    initial_dispensed_regimen	varchar(1000)
);

insert into #temp_min_dispensing (emr_id, min_dispense_date)
select emr_id, min(dispense_date)
from hiv_dispensing hd
where (arv_1_med is not null or arv_2_med is not null or arv_3_med is not NULL)
group by emr_id;

update  #temp_min_dispensing
set initial_dispensed_regimen =
        CONCAT(arv_1_med,
               CASE when arv_1_med is not null and arv_2_med is not null then ',' END,
               arv_2_med,
               CASE when arv_2_med is not null and arv_3_med is not null then ',' END,
               arv_3_med)
    from #temp_min_dispensing t
inner join  hiv_dispensing hd on hd.encounter_id =
    (select top 1 hd2.encounter_id from hiv_dispensing hd2
    where hd2.emr_id = t.emr_id
    and hd2.dispense_date = t.min_dispense_date
    order by hd2.encounter_id desc )
;

drop table if exists #temp_min_arv_date;
select emr_id, min(hr.start_date) "min_arv_start_date"
into #temp_min_arv_date
from hiv_regimens hr
where order_action = 'NEW'
  and drug_category = 'ART'
group by emr_id;


update t
set arv_start_date =
        CASE
            WHEN ISNULL(min_dispense_date,'9999-12-31') < ISNULL(min_arv_start_date,'9999-12-31') THEN min_dispense_date
            ELSE min_arv_start_date
            END,
    dispense_before_prescription =
        CASE
            WHEN  ISNULL(min_dispense_date,'9999-12-31') < ISNULL(min_arv_start_date,'9999-12-31') THEN 1
            ELSE 0
            END
    from hiv_patient_summary_status_staging t
left outer join #temp_min_dispensing tmd on tmd.emr_id  = t.emr_id
    left outer join #temp_min_arv_date tad on tad.emr_id  = t.emr_id
;

update t
set months_on_art = DATEDIFF(month, arv_start_date, GETDATE())
    from hiv_patient_summary_status_staging t;

-- updating initial arv regimen when regimen prescription is prior to dispensing
-- all of the STUFF nonsense is what you have to do in this version of SQL Server to do the
-- equivalent of group_concat or string_agg
update t
set initial_arv_regimen = reg.drugs
    from hiv_patient_summary_status_staging t
inner join
	(SELECT emr_id, STUFF(
	         (SELECT DISTINCT ',' + drug_short_name
	          FROM hiv_regimens r
   	          inner join hiv_patient_summary_status_staging t2 on t2.emr_id = r.emr_id and t2.arv_start_date = format(r.start_date  , 'd')
	          WHERE r.emr_id = r2.emr_id
	          and order_action = 'NEW'
			  and drug_category = 'ART'
			  FOR XML PATH (''))
	          , 1, 1, '')  AS drugs
	FROM hiv_regimens AS r2
	GROUP BY emr_id) reg on reg.emr_id = t.emr_id
where t.dispense_before_prescription = 0;

update t
set initial_arv_regimen = tmd.initial_dispensed_regimen
    from hiv_patient_summary_status_staging t
inner join #temp_min_dispensing tmd on tmd.emr_id = t.emr_id
where t.dispense_before_prescription = 1;

-- latest arvs dispensed
update t
set t.latest_arv_dispensed = isnull(hd.arv_1_med,'') + iif(hd.arv_2_med is null, '',','+hd.arv_2_med) + iif(hd.arv_3_med is null, '',','+hd.arv_3_med) 
    from hiv_patient_summary_status_staging t
inner join hiv_dispensing hd on hd.encounter_id =
	(select top 1 hd2.encounter_id from hiv_dispensing hd2
	where hd2.emr_id = t.emr_id 
	and (hd2.arv_1_med is not null or hd2.arv_2_med is not null or hd2.arv_3_med is not null)
	order by hd2.dispense_date desc, hd2.encounter_id desc) 
	
-- inh_start_date
-- use inh_start_date from entered info on hiv visit,
-- otherwise use information from hiv regimens	
update t
set t.inh_start_date = l.inh_start_date
    from hiv_patient_summary_status_staging t
inner join hiv_visit l on l.encounter_id =
    (select top 1 l2.encounter_id from hiv_visit l2
    where l2.emr_id = t.emr_id and inh_start_date is not null
    order by l2.visit_date desc, l2.index_desc );

update t
set t.inh_start_date = 
	(select min(start_date) from hiv_regimens r
	where r.emr_id = t.emr_id
    and r.order_action = 'NEW'
    and r.drug_category = 'TB Prophylaxis')
from hiv_patient_summary_status_staging t   
where t.inh_start_date is null;
  
-- inh_end_date
-- use inh_end_date from entered info on hiv visit,
-- otherwise use information from hiv regimens	
update t
set t.inh_end_date = l.inh_end_date
    from hiv_patient_summary_status_staging t
inner join hiv_visit l on l.encounter_id =
    (select top 1 l2.encounter_id from hiv_visit l2
    where l2.emr_id = t.emr_id and inh_end_date is not null
    order by l2.visit_date desc, l2.index_desc );
   
update t
set t.inh_end_date = 
	(select max(end_date) from hiv_regimens r
	where r.emr_id = t.emr_id
    and r.order_action = 'NEW'
    and r.drug_category = 'TB Prophylaxis')
from hiv_patient_summary_status_staging t   
where t.inh_end_date is null;   

-- last_visit_date and next_visit_date should consider hiv, eid and pmtct notes
update t
set last_visit_date = 
		CASE
			when ISNULL(hv.visit_date, '1900-01-01') >= ISNULL(pv.visit_date,'1900-01-01') and ISNULL(hv.visit_date, '1900-01-01') >= ISNULL(ev.visit_date,'1900-01-01')  then hv.visit_date
			when ISNULL(pv.visit_date, '1900-01-01') >= ISNULL(hv.visit_date,'1900-01-01') and ISNULL(pv.visit_date, '1900-01-01') >= ISNULL(ev.visit_date,'1900-01-01')  then pv.visit_date
			else ev.visit_date
			END,
    next_visit_date = 
		CASE
			when ISNULL(hv.next_visit_date, '9999-12-31') <= ISNULL(pv.next_visit_date,'9999-12-31') and ISNULL(hv.next_visit_date, '9999-12-31') <= ISNULL(ev.next_visit_date,'9999-12-31')  then hv.next_visit_date
			when ISNULL(pv.next_visit_date, '9999-12-31') <= ISNULL(hv.next_visit_date,'9999-12-31') and ISNULL(pv.next_visit_date, '9999-12-31') <= ISNULL(ev.next_visit_date,'9999-12-31')  then hv.next_visit_date
			else ev.next_visit_date
		END
    from hiv_patient_summary_status_staging t
left outer join hiv_visit hv on hv.emr_id = t.emr_id and hv.index_desc = 1
left outer join pmtct_visits pv on pv.emr_id = t.emr_id and pv.index_desc = 1
left outer join eid_visit ev on ev.emr_id = t.emr_id and ev.index_desc = 1
;

update t
set last_med_pickup_date = hd.dispense_date,
    last_med_pickup_months_dispensed = hd.months_dispensed ,
    last_med_pickup_treatment_line = hd.current_art_treatment_line,
    next_med_pickup_date = hd.next_dispense_date
    from hiv_patient_summary_status_staging t
inner join hiv_dispensing hd on hd.emr_id = t.emr_id and hd.dispense_date_descending = 1
;


update t
set days_late_for_next_visit =
        CASE
            when DATEDIFF(day, next_visit_date, GETDATE())>0 then DATEDIFF(day, next_visit_date, GETDATE())
            else 0
            END
    from hiv_patient_summary_status_staging t
;

update t
set days_late_for_next_med_pickup =
        CASE
            when DATEDIFF(day, next_med_pickup_date, GETDATE())>0 then DATEDIFF(day, next_med_pickup_date, GETDATE())
            else 0
            END
    from hiv_patient_summary_status_staging t
;


update t
set last_viral_load_collection_date = hv.vl_sample_taken_date ,
	last_viral_load_results_date = hv.vl_result_date ,
    last_viral_load_numeric = hv.viral_load ,
    last_viral_load_undetected = IIF(hv.vl_coded_results <> 'Detected','t',null)
    from hiv_patient_summary_status_staging t
inner join hiv_viral_load hv on hv.emr_id = t.emr_id and hv.order_desc  = 1
;

update t
set months_since_last_viral_load = DATEDIFF(month, t.last_viral_load_collection_date , GETDATE())
    from hiv_patient_summary_status_staging t

update t
set last_tb_coinfection_date = l.specimen_collection_date
    from hiv_patient_summary_status_staging t
inner join tb_lab_results l on l.encounter_id =
    (select top 1 l2.encounter_id from tb_lab_results l2
    where l2.emr_id = t.emr_id
    and ((l2.test_type = 'genxpert' and l2.test_result_text = ('Detected')) OR
    (l2.test_type = 'smear' and l2.test_result_text in ('1+','++','+++')))
    order by l2.specimen_collection_date  desc, l2.index_desc );

-- last weight
update t
set last_weight = v.weight ,
    last_weight_date = v.encounter_datetime
    from hiv_patient_summary_status_staging t
inner join all_vitals v on v.all_vitals_id =
    (select top 1 all_vitals_id from all_vitals av2
    where av2.emr_id = t.emr_id
    and av2.weight is not null
    order by av2.encounter_datetime desc, av2.date_entered desc );

-- last height
update t
set last_height = v.height ,
    last_height_date = v.encounter_datetime
    from hiv_patient_summary_status_staging t
inner join all_vitals v on v.all_vitals_id =
    (select top 1 all_vitals_id from all_vitals av2
    where av2.emr_id = t.emr_id
    and av2.height is not null
    order by av2.encounter_datetime desc, av2.date_entered desc );

-- last bp diastolic
update t
set last_bp_diastolic = v.bp_diastolic ,
    last_bp_diastolic_date = v.encounter_datetime
    from hiv_patient_summary_status_staging t
inner join all_vitals v on v.all_vitals_id =
    (select top 1 all_vitals_id from all_vitals av2
    where av2.emr_id = t.emr_id
    and av2.bp_diastolic is not null
    order by av2.encounter_datetime desc, av2.date_entered desc );

-- last bp systolic
update t
set last_bp_systolic = v.bp_systolic ,
    last_bp_systolic_date = v.encounter_datetime
    from hiv_patient_summary_status_staging t
inner join all_vitals v on v.all_vitals_id =
    (select top 1 all_vitals_id from all_vitals av2
    where av2.emr_id = t.emr_id
    and av2.bp_systolic is not null
    order by av2.encounter_datetime desc, av2.date_entered desc );

-- last hypertension diagnosis
update t
set last_htn_diag = d.diagnosis_entered,
    last_htn_diag_date = d.obs_datetime
    from hiv_patient_summary_status_staging t
inner join all_diagnosis d on d.obs_id =
    (select top 1 obs_id from all_diagnosis ad2
    where ad2.patient_primary_id = t.emr_id
    and ad2.diagnosis_entered like '%HYPERTENSION'
    order by ad2.obs_datetime desc, ad2.date_created desc );

update t
set current_treatment_status = s.status_outcome,
    current_treatment_status_date = s.start_date
    from hiv_patient_summary_status_staging t
inner join hiv_status s on s.status_id =
    (select top 1 status_id  from hiv_status s2
    where s2.emr_id = t.emr_id
    and status_outcome not in ('Patient pregnant', 'Not pregnant')
    order by s2.start_date desc, s2.end_date  desc)
where  s.start_date <= GETDATE()
  and (s.end_date >= GETDATE() or s.end_date is null);

update t
set current_outcome = pp.outcome,
    current_outcome_date = pp.date_completed,
    enrollment_date = pp.date_enrolled
    from hiv_patient_summary_status_staging t
inner join hiv_patient_program pp on pp.patient_program_id  =
    (select top 1 patient_program_id from hiv_patient_program pp2
    where pp2.emr_id = t.emr_id
    and pp2.date_enrolled <= GETDATE()
    order by pp2.date_enrolled desc,  isnull(pp2.date_completed,'9999-12-31')  desc)
where pp.date_completed is not null;

update t
set enrollment_date = pp.date_enrolled
    from hiv_patient_summary_status_staging t
inner join hiv_patient_program pp on pp.patient_program_id  =
    (select top 1 patient_program_id from hiv_patient_program pp2
    where pp2.emr_id = t.emr_id
    and pp2.date_enrolled <= GETDATE()
    order by pp2.date_enrolled desc,  isnull(pp2.date_completed,'9999-12-31')  desc)
;

update t
set tb_diag_date =
	(select min(COALESCE(tb.test_result_date, specimen_collection_date))
	from tb_lab_results tb
	where tb.emr_id  = t.emr_id
	and ((tb.test_type = 'genxpert' and tb.test_result_text  = 'Detected')
		or (tb.test_type = 'skin test' and tb.test_result_text  = 'Positive')
		or (tb.test_type = 'smear' and tb.test_result_text  in ('1+','++','+++'))
		or (tb.test_type = 'culture' and tb.test_result_text  in ('1+','++','+++'))))
from hiv_patient_summary_status_staging t;
		
update t 
set tb_diag_test = tbl.test_type
from hiv_patient_summary_status_staging t
inner join tb_lab_results tbl  on tb_lab_results_id =
	(select top 1 tb_lab_results_id from tb_lab_results tbl2
	where tbl2.emr_id = t.emr_id
	and ((tbl2.test_type = 'genxpert' and tbl2.test_result_text  = 'Detected')
		or (tbl2.test_type = 'skin test' and tbl2.test_result_text  = 'Positive')
		or (tbl2.test_type = 'smear' and tbl2.test_result_text  in ('1+','++','+++'))
		or (tbl2.test_type = 'culture' and tbl2.test_result_text  in ('1+','++','+++')))
	and COALESCE(tbl2.test_result_date, specimen_collection_date) = t.tb_diag_date)
;

update t
set tb_tx_start_date = 	
	(select min(start_date) from hiv_regimens hr
	where hr.emr_id = t.emr_id
	and hr.drug_category = 'tb')
from hiv_patient_summary_status_staging t;

update t
set tb_tx_end_date = 	
	(select max(end_date) from hiv_regimens hr
	where hr.emr_id = t.emr_id
	and hr.drug_category = 'tb')
from hiv_patient_summary_status_staging t;

update t
set latest_next_dispense_date = d.next_dispense_date
    from hiv_patient_summary_status_staging t
left outer join hiv_dispensing d on d.emr_id = t.emr_id  and d.dispense_date_descending = 1
;

update t
set med_pickup_status =
        CASE
            when DATEDIFF(day, COALESCE(t.latest_next_dispense_date,t.enrollment_date),GETDATE()) <= 28
                then 'active - on arvs'
            else 'ltfu'
            END
    from hiv_patient_summary_status_staging t;


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
    from hiv_patient_summary_status_staging t;

update t
set status =
        CASE
            when current_outcome is not null then current_outcome
            when med_pickup_status = 'active - on arvs' then 'active - on arvs'
            when current_treatment_status is not null then current_treatment_status
            else 'ltfu'
            END
    from hiv_patient_summary_status_staging t;

update t
set status_date =
        CASE
            when current_outcome is not null then current_outcome_date
            when med_pickup_status = 'active - on arvs' then med_pickup_status_date
            when current_treatment_status is not null then current_treatment_status_date
            else med_pickup_status_date
            END
    from hiv_patient_summary_status_staging t;

update t
set last_pickup_accompagnateur = d.dispensed_accompagnateur
    from hiv_patient_summary_status_staging t
inner join hiv_dispensing d on d.encounter_id =
    (select top 1 encounter_id from hiv_dispensing d2
    where d2.emr_id = t.emr_id
    and d2.dispensed_accompagnateur is not NULL
    order by d2.dispense_date desc)
;

update t
set hiv_note_accompagnateur = v.chw
    from hiv_patient_summary_status_staging t
inner join hiv_visit v on v.encounter_id =
    (select top 1 encounter_id from hiv_visit v2
    where v2.emr_id = t.emr_id
    and v2.chw is not NULL
    order by v2.visit_date desc)
;

-- pull latest second_to_latest_hiv_visit_date from hiv_monthly_reporting table
DROP TABLE IF EXISTS #last_second_to_latest_visit;
SELECT emr_id, visit_date, dense_rank() OVER (PARTITION BY emr_id ORDER BY visit_date DESC ) AS rnk 
INTO #last_second_to_latest_visit       
FROM hiv_visit hmr;
   
update t
set second_to_latest_hiv_visit_date = v.visit_date
    from hiv_patient_summary_status_staging t
inner join #last_second_to_latest_visit v ON t.emr_id=v.emr_id AND v.rnk=2;

update t
set biometrics_collected = hp.biometrics_collected,
latest_biometrics_collection_date=hp.latest_biometrics_collection_date,
biometrics_collector=hp.biometrics_collector
    from hiv_patient_summary_status_staging t
inner join hiv_patient hp on hp.emr_id = t.emr_id ;

alter table hiv_patient_summary_status_staging drop column dispense_before_prescription;
alter table hiv_patient_summary_status_staging drop column enrollment_date;
alter table hiv_patient_summary_status_staging drop column current_treatment_status;
alter table hiv_patient_summary_status_staging drop column current_treatment_status_date;
alter table hiv_patient_summary_status_staging drop column current_outcome;
alter table hiv_patient_summary_status_staging drop column current_outcome_date;
alter table hiv_patient_summary_status_staging drop column latest_next_dispense_date;
alter table hiv_patient_summary_status_staging drop column med_pickup_status;
alter table hiv_patient_summary_status_staging drop column med_pickup_status_date;

-- ------------------------------------------------------------------------------------
DROP TABLE IF EXISTS hiv_patient_summary_status;
EXEC sp_rename 'hiv_patient_summary_status_staging', 'hiv_patient_summary_status';
