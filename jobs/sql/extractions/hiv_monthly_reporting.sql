use openmrs_haiti_warehouse;

DROP TABLE IF EXISTS #temp_eom_appts;
CREATE TABLE #temp_eom_appts
(
emr_id							varchar(20),
date_enrolled					DATETIME,
date_completed					DATETIME,
reporting_date					DATE,
latest_hiv_visit_date			DATETIME,
latest_expected_hiv_visit_date	DATETIME,
latest_transfer_in_date			DATE,
latest_transfer_in_location		VARCHAR(255),
hiv_visit_days_late				INT,
second_to_latest_hiv_visit_date	DATE,
lastest_program_status_outcome	VARCHAR(255),
lastest_program_status_outcome_date DATE,
latest_dispensing_date			DATETIME,
latest_expected_dispensing_date	DATETIME,
dispensing_days_late			INT,
latest_hiv_viral_load_date		DATETIME,
latest_hiv_viral_load_coded		VARCHAR(255),
latest_hiv_viral_load			INT,
latest_arv_regimen_date			DATETIME,
latest_arv_regimen_line			VARCHAR(255),
latest_arv_dispensed_id			INT,
latest_arv_dispensed_date		DATETIME,
latest_arv_dispensed_line		VARCHAR(255),
latest_months_dispensed			INT,
days_late_at_latest_pickup		INT,
latest_reason_not_on_ARV		VARCHAR(255),
latest_reason_not_on_ARV_date	DATE,
latest_tb_screening_date		DATE,
latest_tb_screening_result		BIT,
latest_tb_test_date				DATE,
latest_tb_test_type				VARCHAR(255),
latest_tb_test_result			VARCHAR(255),
latest_status					VARCHAR(255)
);

CREATE OR ALTER VIEW all_reporting_visits AS
	SELECT hv.encounter_id ,hv.emr_id ,x.reporting_date ,hv.visit_date, hv.next_visit_date 
	FROM hiv_visit hv INNER JOIN (
	SELECT DISTINCT dd.LastDateofMonth reporting_date  FROM Dim_Date dd
	WHERE dd.[Year] BETWEEN 2020 AND YEAR(CAST(getdate() AS date))) x
	on EOMONTH(hv.visit_date) <= x.reporting_date 
	AND x.reporting_date <= EOMONTH(CAST(GETDATE() AS date));

CREATE OR ALTER VIEW all_reporting_dispense AS
	SELECT hd.encounter_id ,hd.emr_id ,x.reporting_date ,hd.dispense_date,hd.next_dispense_date, hd.months_dispensed, hd.days_late_to_pickup  
	FROM hiv_dispensing hd INNER JOIN (
	SELECT DISTINCT dd.LastDateofMonth reporting_date  FROM Dim_Date dd
	WHERE dd.[Year] BETWEEN 2020 AND YEAR(CAST(getdate() AS date))) x
	on EOMONTH(hd.dispense_date) <= x.reporting_date 
	AND x.reporting_date <= EOMONTH(CAST(GETDATE() AS date));

CREATE OR ALTER VIEW all_reporting_dispense_arv AS
	SELECT hd.encounter_id ,hd.emr_id ,x.reporting_date ,hd.dispense_date,hd.next_dispense_date,hd.current_art_treatment_line, hd.arv_1_med , hd.arv_2_med ,hd.arv_3_med 
	FROM hiv_dispensing hd INNER JOIN (
	SELECT DISTINCT dd.LastDateofMonth reporting_date  FROM Dim_Date dd
	WHERE dd.[Year] BETWEEN 2020 AND YEAR(CAST(getdate() AS date))) x
	on EOMONTH(hd.dispense_date) <= x.reporting_date 
	AND x.reporting_date <= EOMONTH(CAST(GETDATE() AS date))
	WHERE  ( arv_1_med IS NOT NULL 
	OR  arv_2_med IS NOT NULL 
	OR arv_3_med IS NOT NULL)
	;

CREATE OR ALTER VIEW all_reporting_viral AS
	SELECT  hvl.encounter_id ,hvl.emr_id ,x.reporting_date ,hvl.vl_coded_results,hvl.viral_load,hvl.vl_sample_taken_date
	FROM hiv_viral_load hvl INNER JOIN (
	SELECT DISTINCT dd.LastDateofMonth reporting_date  FROM Dim_Date dd
	WHERE dd.[Year] BETWEEN 2020 AND YEAR(CAST(getdate() AS date))) x
	on EOMONTH(hvl.vl_sample_taken_date) <= x.reporting_date 
	AND x.reporting_date <= EOMONTH(CAST(GETDATE() AS date));

CREATE OR ALTER VIEW all_reporting_reg AS
	SELECT hr.encounter_id ,hr.emr_id ,x.reporting_date ,hr.encounter_datetime ,hr.art_treatment_line 
	FROM hiv_regimens hr  INNER JOIN (
	SELECT DISTINCT dd.LastDateofMonth reporting_date  FROM Dim_Date dd
	WHERE dd.[Year] BETWEEN 2020 AND YEAR(CAST(getdate() AS date))) x
	on EOMONTH(hr.encounter_datetime) <= x.reporting_date 
	AND x.reporting_date <= EOMONTH(CAST(GETDATE() AS date))
	AND upper(hr.order_action) ='NEW' AND upper(hr.drug_category)='ART';

-- ############## Load Initial Data ##############################################################
CREATE OR ALTER VIEW hiv_patient_modified AS 
SELECT x.*
FROM (
SELECT hpp.*, lead(date_enrolled) over(PARTITION BY emr_id ORDER BY date_enrolled) next_date_enrolled
FROM hiv_patient_program hpp
) x
WHERE CASE WHEN next_date_enrolled=date_completed THEN 0 ELSE 1 END=1;

INSERT INTO #temp_eom_appts (emr_id, date_enrolled, date_completed,reporting_date )
SELECT DISTINCT emr_id AS patient_id, date_enrolled ,date_completed, dd.LastDateofMonth reporting_date
FROM hiv_patient_modified hpp
inner join Dim_Date dd  
	on dd.LastDateofMonth  >= EOMONTH(hpp.date_enrolled)  
	and (EOMONTH(hpp.date_completed) >=dd.LastDateofMonth or hpp.date_completed is null)
    AND dd.LastDateofMonth <= EOMONTH(CAST(GETDATE() AS date));


-- ############################### HIV Visit Data ##################################################################
UPDATE t1
SET t1.latest_hiv_visit_date = x.visit_date
FROM  #temp_eom_appts t1 
LEFT OUTER JOIN 
(
	SELECT emr_id,reporting_date,max(visit_date) visit_date FROM all_reporting_visits
	GROUP BY emr_id,reporting_date
) x
ON t1.emr_id =  x.emr_id AND t1.reporting_date=x.reporting_date;

UPDATE t1
SET 
t1.latest_expected_hiv_visit_date =av.next_visit_date,
t1.hiv_visit_days_late=IIF(
	DATEDIFF(DAY,isnull(av.next_visit_date,isnull(t1.latest_hiv_visit_date,t1.date_enrolled)),t1.reporting_date) > 0,
	DATEDIFF(DAY,isnull(av.next_visit_date,isnull(t1.latest_hiv_visit_date,t1.date_enrolled)),t1.reporting_date),
	0)
FROM  #temp_eom_appts t1 
LEFT OUTER JOIN all_reporting_visits av
ON t1.emr_id =  av.emr_id 
AND t1.reporting_date=av.reporting_date
AND t1.latest_hiv_visit_date=av.visit_date;

update t1
SET t1.latest_transfer_in_date = v.visit_date ,
t1.latest_transfer_in_location = v.referral_transfer_location 
FROM #temp_eom_appts t1 
INNER JOIN hiv_visit v on v.encounter_id =
	(select top 1 v2.encounter_id
	from hiv_visit v2 
	where v2.emr_id = t1.emr_id 
	and v2.referral_transfer = 'Transfer'
	and v2.visit_date <= t1.reporting_date 
	order by v2.visit_date desc);

update t1
SET t1.latest_reason_not_on_ARV = v.reason_not_on_ARV, 
t1.latest_reason_not_on_ARV_date = v.visit_date 
FROM #temp_eom_appts t1 
INNER JOIN hiv_visit v on v.encounter_id =
	(select top 1 v2.encounter_id
	from hiv_visit v2 
	where v2.emr_id = t1.emr_id 
	and v2.reason_not_on_ARV is not null
	and v2.visit_date <= t1.reporting_date 	
	order by v2.visit_date desc);

update t1
SET t1.second_to_latest_hiv_visit_date = v.visit_date 
FROM #temp_eom_appts t1 
INNER JOIN hiv_visit v on v.encounter_id =
	(select top 1 v2.encounter_id
	from hiv_visit v2 
	where v2.emr_id = t1.emr_id 
	and v2.visit_date < t1.latest_hiv_visit_date 	
	order by v2.visit_date desc);

-- ############################### HIV Dispensing Data ##################################################################

UPDATE t1
SET t1.latest_dispensing_date = x.dispense_date
FROM  #temp_eom_appts t1 
LEFT OUTER JOIN 
(
	SELECT emr_id,reporting_date,max(dispense_date)  dispense_date FROM all_reporting_dispense
	GROUP BY emr_id,reporting_date
) x
ON t1.emr_id =  x.emr_id AND t1.reporting_date=x.reporting_date;

UPDATE t1
SET 
t1.latest_expected_dispensing_date=ad.next_dispense_date,
t1.dispensing_days_late=IIF(
	DATEDIFF(DAY,isnull(ad.next_dispense_date,isnull(t1.latest_dispensing_date,t1.date_enrolled)),t1.reporting_date) >0,
	DATEDIFF(DAY,isnull(ad.next_dispense_date,isnull(t1.latest_dispensing_date,t1.date_enrolled)),t1.reporting_date),
	0),
t1.latest_months_dispensed = ad.months_dispensed,
t1.days_late_at_latest_pickup = ad.days_late_to_pickup
FROM  #temp_eom_appts t1 
LEFT OUTER JOIN all_reporting_dispense ad
ON t1.emr_id =  ad.emr_id 
AND t1.reporting_date=ad.reporting_date
AND t1.latest_dispensing_date=ad.dispense_date;

-- ############################### HIV Viral Data ##################################################################

UPDATE t1
SET t1.latest_hiv_viral_load_date = x.vl_sample_taken_date
FROM  #temp_eom_appts t1 
LEFT OUTER JOIN 
(
	SELECT emr_id,reporting_date,max(vl_sample_taken_date)  vl_sample_taken_date FROM all_reporting_viral
	GROUP BY emr_id,reporting_date
) x
ON t1.emr_id =  x.emr_id AND t1.reporting_date=x.reporting_date;


UPDATE t1
SET t1.latest_hiv_viral_load_coded = avl.vl_coded_results,
t1.latest_hiv_viral_load=avl.viral_load
FROM  #temp_eom_appts t1 
LEFT OUTER JOIN all_reporting_viral avl
ON t1.emr_id =  avl.emr_id 
AND t1.reporting_date=avl.reporting_date
AND t1.latest_hiv_viral_load_date=avl.vl_sample_taken_date;

-- ############################### HIV Regimens ##################################################################

UPDATE t1
SET t1.latest_arv_regimen_date = x.encounter_datetime
FROM  #temp_eom_appts t1 
LEFT OUTER JOIN 
(
	SELECT emr_id,reporting_date,max(encounter_datetime)  encounter_datetime 
	FROM all_reporting_reg
	GROUP BY emr_id ,reporting_date
) x
ON t1.emr_id =  x.emr_id AND t1.reporting_date=x.reporting_date;


UPDATE t1
SET t1.latest_arv_regimen_line = r.art_treatment_line
FROM  #temp_eom_appts t1 
LEFT OUTER JOIN all_reporting_reg r
ON t1.emr_id =  r.emr_id 
AND t1.reporting_date=r.reporting_date
AND t1.latest_arv_regimen_date=r.encounter_datetime;


-- ############################### HIV Dispense ARV ##################################################################

UPDATE t1
SET t1.latest_arv_dispensed_date = x.dispense_date
FROM  #temp_eom_appts t1 
LEFT OUTER JOIN 
(
	SELECT emr_id,reporting_date,max(dispense_date)  dispense_date 
	FROM all_reporting_dispense_arv
	GROUP BY emr_id,reporting_date
) x
ON t1.emr_id =  x.emr_id AND t1.reporting_date=x.reporting_date;

UPDATE t1
SET t1.latest_arv_dispensed_line = ad.current_art_treatment_line
FROM  #temp_eom_appts t1 
LEFT OUTER JOIN all_reporting_dispense_arv ad
ON t1.emr_id =  ad.emr_id 
AND t1.reporting_date=ad.reporting_date
AND t1.latest_arv_dispensed_date=ad.dispense_date;

-- ############################### TB screening data ##################################################################
update t1
SET t1.latest_tb_screening_result = tb.tb_screening_result, 
t1.latest_tb_screening_date = tb.tb_screening_date 
FROM #temp_eom_appts t1 
INNER JOIN tb_screening tb on tb.encounter_id =
	(select top 1 tb2.encounter_id
	from tb_screening tb2 
	where tb2.emr_id = t1.emr_id 
	and tb2.tb_screening_date <= t1.reporting_date 	
	order by tb2.tb_screening_date desc);


-- ############################### TB testing data ##################################################################
update t1
SET t1.latest_tb_test_date = tb.specimen_collection_date, 
t1.latest_tb_test_type = tb.test_type,
t1.latest_tb_test_result = tb.test_result_text 
FROM #temp_eom_appts t1 
INNER JOIN tb_lab_results tb on tb.encounter_id =
	(select top 1 tb2.encounter_id
	from tb_lab_results tb2 
	where tb2.emr_id = t1.emr_id 
	and tb2.specimen_collection_date <= t1.reporting_date 	
	order by tb2.specimen_collection_date desc);

-- ############################### hiv status data ##################################################################
update t1
SET t1.lastest_program_status_outcome_date = h.start_date, 
t1.lastest_program_status_outcome = h.status_outcome 
FROM #temp_eom_appts t1 
INNER JOIN hiv_status h on h.status_id  =
	(select top 1 h2.status_id
	from hiv_status h2
	where h2.emr_id = t1.emr_id 
	and h2.status_outcome is not null
	and h2.start_date  <= t1.reporting_date 	
	order by h2.start_date desc);

-- ################################## combined status #########################################################################
update t
set latest_status =
	CASE 
		when lastest_program_status_outcome is not null then lastest_program_status_outcome
		when dispensing_days_late <= 28  then 'active - on arvs'
		else 'Lost to followup'
	END	
from #temp_eom_appts t; 

-- ###########################################################################################################

SELECT 
emr_id,
date_enrolled,
date_completed,
reporting_date,
lastest_program_status_outcome,
lastest_program_status_outcome_date,
latest_hiv_visit_date,
latest_expected_hiv_visit_date,
hiv_visit_days_late,
second_to_latest_hiv_visit_date,
latest_transfer_in_date,
latest_transfer_in_location,
latest_dispensing_date,
latest_expected_dispensing_date,
dispensing_days_late,
latest_months_dispensed,
latest_hiv_viral_load_date,
latest_hiv_viral_load_coded,
latest_hiv_viral_load,
latest_arv_regimen_date,
latest_arv_regimen_line,
latest_arv_dispensed_id,
latest_arv_dispensed_date,
latest_arv_dispensed_line,
days_late_at_latest_pickup,
latest_reason_not_on_ARV_date,
latest_reason_not_on_ARV,
latest_tb_screening_date,
latest_tb_screening_result,
latest_tb_test_date,
latest_tb_test_type,
latest_tb_test_result,
latest_status
FROM #temp_eom_appts;
