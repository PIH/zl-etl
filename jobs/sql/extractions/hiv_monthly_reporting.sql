DROP TABLE IF EXISTS #temp_eom_appts;
CREATE TABLE #temp_eom_appts
(
emr_id				varchar(20),
date_enrolled				DATETIME,
date_completed				DATETIME,
reporting_date				DATE,
latest_hiv_visit_date			DATETIME,
latest_expected_hiv_visit_date		DATETIME,
hiv_visit_days_late			INT,
latest_dispensing_date			DATETIME,
latest_expected_dispensing_date		DATETIME,
dispensing_days_late			INT,
latest_hiv_viral_load_date		DATETIME,
latest_hiv_viral_load_coded		VARCHAR(255),
latest_hiv_viral_load			INT,
latest_arv_regimen_date			DATETIME,
latest_arv_regimen_line			VARCHAR(255),
latest_arv_dispensed_id			INT,
latest_arv_dispensed_date		DATETIME,
latest_arv_dispensed_line		VARCHAR(255)
);

CREATE OR ALTER VIEW all_reporting_visits AS
	SELECT hv.encounter_id ,hv.emr_id ,x.reporting_date ,hv.visit_date, hv.next_visit_date 
	FROM hiv_visit hv INNER JOIN (
	SELECT DISTINCT dd.LastDateofMonth reporting_date  FROM Dim_Date dd
	WHERE dd.[Year] BETWEEN 2020 AND YEAR(CAST(getdate() AS date))) x
	on EOMONTH(hv.visit_date) <= x.reporting_date 
	AND x.reporting_date <= EOMONTH(CAST(GETDATE() AS date));

CREATE OR ALTER VIEW all_reporting_dispense AS
	SELECT hd.encounter_id ,hd.emr_id ,x.reporting_date ,hd.dispense_date,hd.next_dispense_date  
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
t1.hiv_visit_days_late=DATEDIFF(DAY,isnull(av.next_visit_date,isnull(t1.latest_hiv_visit_date,t1.date_enrolled)),t1.reporting_date)
FROM  #temp_eom_appts t1 
LEFT OUTER JOIN all_reporting_visits av
ON t1.emr_id =  av.emr_id 
AND t1.reporting_date=av.reporting_date
AND t1.latest_hiv_visit_date=av.visit_date;

-- ############################### HIV Despensing Data ##################################################################

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
t1.dispensing_days_late=DATEDIFF(DAY,isnull(ad.next_dispense_date,isnull(t1.latest_dispensing_date,t1.date_enrolled)),t1.reporting_date)
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

-- ############################### HIV Despense ARV ##################################################################

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

-- ###########################################################################################################

SELECT 
emr_id,
date_enrolled,
date_completed,
reporting_date,
latest_hiv_visit_date,
latest_expected_hiv_visit_date,
hiv_visit_days_late,
latest_dispensing_date,
latest_expected_dispensing_date,
dispensing_days_late,
latest_hiv_viral_load_date,
latest_hiv_viral_load_coded,
latest_hiv_viral_load,
latest_arv_regimen_date,
latest_arv_regimen_line,
latest_arv_dispensed_id,
latest_arv_dispensed_date,
latest_arv_dispensed_line
FROM #temp_eom_appts;
