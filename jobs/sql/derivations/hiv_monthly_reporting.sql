DROP TABLE IF EXISTS hiv_monthly_reporting_staging;

create table hiv_monthly_reporting_staging
(
    emr_id                                VARCHAR(20),
    date_enrolled                         DATETIME,
    date_completed                        DATETIME,
    reporting_date                        DATE,
    latest_program_status_outcome         VARCHAR(255),
    latest_program_status_outcome_date    DATE,
    latest_hiv_visit_date                 DATETIME,
    latest_expected_hiv_visit_date        DATETIME,
    hiv_visit_days_late                   INT,
    second_to_latest_hiv_visit_date       DATE,
    latest_transfer_in_date               DATE,
    latest_transfer_in_location           VARCHAR(255),
    latest_dispensing_date                DATETIME,
    latest_expected_dispensing_date       DATETIME,
    dispensing_days_late                  INT,
    latest_months_dispensed               INT,
    latest_hiv_vl_id                      VARCHAR(50),
    latest_hiv_viral_load_order_date      DATE,
    latest_hiv_viral_load_status          VARCHAR(50),
    latest_hiv_viral_load_collection_date DATETIME,
    latest_hiv_viral_load_results_date    DATETIME,
    latest_hiv_viral_load_coded           VARCHAR(255),
    latest_hiv_viral_load                 INT,
    latest_arv_regimen_date               DATETIME,
    latest_arv_regimen_line               VARCHAR(255),
    latest_arv_dispensed_id               INT,
    latest_arv_dispensed_date             DATETIME,
    latest_arv_dispensed_line             VARCHAR(255),
    days_late_at_latest_pickup            INT,
    latest_reason_not_on_ARV_date         DATE,
    latest_reason_not_on_ARV              VARCHAR(255),
    latest_tb_screening_date              DATE,
    latest_tb_screening_result            BIT,
    latest_tb_test_date                   DATE,
    latest_tb_test_type                   VARCHAR(255),
    latest_tb_test_result                 VARCHAR(255),
    latest_tb_coinfection_date            DATE,
    date_of_last_breastfeeding_status     DATETIME,
    latest_breastfeeding_status           VARCHAR(255),
    latest_breastfeeding_date             DATETIME,
    arv_start_date                        DATE,
    monthly_arv_status                    VARCHAR(255),
    latest_status                         VARCHAR(255),
    latest_bp_diastolic                   FLOAT,
    latest_bp_diastolic_date              DATE,
    latest_bp_systolic                    FLOAT,
    latest_bp_systolic_date               DATE,
    htn_diagnosis                         BIT,
    latest_htn_diagnosis_date             DATE
);


CREATE OR ALTER VIEW all_reporting_visits AS
SELECT hv.encounter_id ,hv.emr_id ,x.reporting_date ,hv.visit_date, hv.next_visit_date
FROM hiv_visit hv INNER JOIN (
    SELECT DISTINCT dd.LastDayofMonth reporting_date  FROM Dim_Date dd) x
                             on EOMONTH(hv.visit_date) <= x.reporting_date
                                 AND x.reporting_date <= EOMONTH(CAST(GETDATE() AS date));

CREATE OR ALTER VIEW all_reporting_dispense AS
SELECT hd.encounter_id ,hd.emr_id ,x.reporting_date ,hd.dispense_date,hd.next_dispense_date, hd.months_dispensed, hd.days_late_to_pickup
FROM hiv_dispensing hd INNER JOIN (
    SELECT DISTINCT dd.LastDayofMonth reporting_date  FROM Dim_Date dd) x
                                  on EOMONTH(hd.dispense_date) <= x.reporting_date
                                      AND x.reporting_date <= EOMONTH(CAST(GETDATE() AS date));

CREATE OR ALTER VIEW all_reporting_dispense_arv AS
SELECT hd.encounter_id ,hd.emr_id ,x.reporting_date ,hd.dispense_date,hd.next_dispense_date,hd.current_art_treatment_line, hd.arv_1_med , hd.arv_2_med ,hd.arv_3_med
FROM hiv_dispensing hd INNER JOIN (
    SELECT DISTINCT dd.LastDayofMonth reporting_date  FROM Dim_Date dd) x
                                  on EOMONTH(hd.dispense_date) <= x.reporting_date
                                      AND x.reporting_date <= EOMONTH(CAST(GETDATE() AS date))
WHERE  ( arv_1_med IS NOT NULL
    OR  arv_2_med IS NOT NULL
    OR arv_3_med IS NOT NULL)
;

CREATE OR ALTER VIEW all_reporting_reg AS
SELECT hr.encounter_id ,hr.emr_id ,x.reporting_date ,hr.encounter_datetime ,hr.art_treatment_line
FROM hiv_regimens hr  INNER JOIN (
    SELECT DISTINCT dd.LastDayofMonth reporting_date  FROM Dim_Date dd) x
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

INSERT INTO hiv_monthly_reporting_staging (emr_id, date_enrolled, date_completed,reporting_date )
SELECT DISTINCT emr_id AS patient_id, date_enrolled ,date_completed, dd.LastDayofMonth reporting_date
FROM hiv_patient_modified hpp
         inner join Dim_Date dd
                    on dd.LastDayofMonth  >= EOMONTH(hpp.date_enrolled)
                        and (EOMONTH(hpp.date_completed) >=dd.LastDayofMonth or hpp.date_completed is null)
                        and dd.LastDayofMonth <=  CAST(GETDATE() AS date)  -- include end of month dates for all prior months only
                        and dd.LastDayofMonth > '2022-01-01'; -- include only data since 2022 (earlier data is not regularly needed)

CREATE INDEX hiv_monthly_reporting_staging_ei ON hiv_monthly_reporting_staging(emr_id, reporting_date);


-- ############################### HIV Visit Data ##################################################################
UPDATE t1
SET t1.latest_hiv_visit_date = x.visit_date
    FROM  hiv_monthly_reporting_staging t1
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
    FROM  hiv_monthly_reporting_staging t1
LEFT OUTER JOIN all_reporting_visits av
ON t1.emr_id =  av.emr_id
    AND t1.reporting_date=av.reporting_date
    AND t1.latest_hiv_visit_date=av.visit_date;

UPDATE t1
SET t1.latest_transfer_in_date = v.visit_date,
    t1.latest_transfer_in_location = v.referral_transfer_location_in
FROM hiv_monthly_reporting_staging t1
CROSS APPLY (
    SELECT TOP 1 v2.visit_date, v2.referral_transfer_location_in
    FROM hiv_visit v2
    WHERE v2.emr_id = t1.emr_id
      AND v2.referral_transfer_in = 'Transfer'
      AND v2.visit_date <= t1.reporting_date
    ORDER BY v2.visit_date DESC
) v;

UPDATE t1
SET t1.latest_reason_not_on_ARV = v.reason_not_on_ARV,
    t1.latest_reason_not_on_ARV_date = v.visit_date
FROM hiv_monthly_reporting_staging t1
CROSS APPLY (
    SELECT TOP 1 v2.reason_not_on_ARV, v2.visit_date
    FROM hiv_visit v2
    WHERE v2.emr_id = t1.emr_id
      AND v2.reason_not_on_ARV IS NOT NULL
      AND v2.visit_date <= t1.reporting_date
    ORDER BY v2.visit_date DESC
) v;

UPDATE t1
SET t1.second_to_latest_hiv_visit_date = v.visit_date
FROM hiv_monthly_reporting_staging t1
CROSS APPLY (
    SELECT TOP 1 v2.visit_date
    FROM hiv_visit v2
    WHERE v2.emr_id = t1.emr_id
      AND v2.visit_date < t1.latest_hiv_visit_date
    ORDER BY v2.visit_date DESC
) v;

-- ############################### HIV Dispensing Data ##################################################################

UPDATE t1
SET t1.latest_dispensing_date = x.dispense_date
    FROM  hiv_monthly_reporting_staging t1
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
    FROM  hiv_monthly_reporting_staging t1
LEFT OUTER JOIN all_reporting_dispense ad
ON t1.emr_id =  ad.emr_id
    AND t1.reporting_date=ad.reporting_date
    AND t1.latest_dispensing_date=ad.dispense_date;

-- ############################### HIV Viral Data ##################################################################
UPDATE t1
SET t1.latest_hiv_vl_id = vl.hiv_vl_id
FROM hiv_monthly_reporting_staging t1
CROSS APPLY (
    SELECT TOP 1 vl2.hiv_vl_id
    FROM hiv_viral_load vl2
    WHERE vl2.emr_id = t1.emr_id
      AND COALESCE(vl2.vl_sample_taken_date, vl2.date_entered) <= t1.reporting_date
    ORDER BY vl2.vl_sample_taken_date DESC, vl2.date_entered DESC
) vl;

UPDATE t1
SET t1.latest_hiv_viral_load_collection_date = vl.vl_sample_taken_date,
	t1.latest_hiv_viral_load_results_date = vl.vl_result_date,
	t1.latest_hiv_viral_load_order_date = vl.order_date,
	t1.latest_hiv_viral_load_status = vl.status
FROM hiv_monthly_reporting_staging t1
INNER JOIN hiv_viral_load vl ON vl.hiv_vl_id = t1.latest_hiv_vl_id;

-- ############################### HIV Regimens ##################################################################

UPDATE t1
SET t1.latest_arv_regimen_date = x.encounter_datetime
    FROM  hiv_monthly_reporting_staging t1
LEFT OUTER JOIN
(
	SELECT emr_id,reporting_date,max(encounter_datetime)  encounter_datetime
	FROM all_reporting_reg
	GROUP BY emr_id ,reporting_date
) x
ON t1.emr_id =  x.emr_id AND t1.reporting_date=x.reporting_date;


UPDATE t1
SET t1.latest_arv_regimen_line = r.art_treatment_line
    FROM  hiv_monthly_reporting_staging t1
LEFT OUTER JOIN all_reporting_reg r
ON t1.emr_id =  r.emr_id
    AND t1.reporting_date=r.reporting_date
    AND t1.latest_arv_regimen_date=r.encounter_datetime;


-- ############################### HIV Dispense ARV ##################################################################

UPDATE t1
SET t1.latest_arv_dispensed_date = x.dispense_date
    FROM  hiv_monthly_reporting_staging t1
LEFT OUTER JOIN
(
	SELECT emr_id,reporting_date,max(dispense_date)  dispense_date
	FROM all_reporting_dispense_arv
	GROUP BY emr_id,reporting_date
) x
ON t1.emr_id =  x.emr_id AND t1.reporting_date=x.reporting_date;

UPDATE t1
SET t1.latest_arv_dispensed_line = ad.current_art_treatment_line
    FROM  hiv_monthly_reporting_staging t1
LEFT OUTER JOIN all_reporting_dispense_arv ad
ON t1.emr_id =  ad.emr_id
    AND t1.reporting_date=ad.reporting_date
    AND t1.latest_arv_dispensed_date=ad.dispense_date;

-- ############################### monthly_arv_status ##################################################################

DROP TABLE IF EXISTS #temp_min_arv_date;
SELECT emr_id, MIN(hr.start_date) "min_arv_start_date"
INTO #temp_min_arv_date
FROM hiv_regimens hr
WHERE order_action = 'NEW'
  AND drug_category = 'ART'
GROUP BY emr_id;

CREATE INDEX temp_min_arv_date_ei ON #temp_min_arv_date(emr_id);

DROP TABLE IF EXISTS #temp_min_dispensing;
SELECT emr_id, MIN(dispense_date) "min_dispense_date"
INTO #temp_min_dispensing
FROM hiv_dispensing hd
WHERE (arv_1_med IS NOT NULL OR arv_2_med IS NOT NULL OR arv_3_med IS NOT NULL)
GROUP BY emr_id;

CREATE INDEX temp_min_dispensing_ei ON #temp_min_dispensing(emr_id);

UPDATE t
SET arv_start_date =
	CASE
		WHEN ISNULL(min_dispense_date,'9999-12-31') < ISNULL(min_arv_start_date,'9999-12-31') THEN min_dispense_date
		ELSE min_arv_start_date
	END
FROM hiv_monthly_reporting_staging t
LEFT OUTER JOIN #temp_min_dispensing tmd ON tmd.emr_id = t.emr_id
LEFT OUTER JOIN #temp_min_arv_date tad ON tad.emr_id = t.emr_id;

UPDATE t
SET monthly_arv_status =
	CASE
		WHEN YEAR(arv_start_date) = YEAR(reporting_date) AND MONTH(arv_start_date) = MONTH(reporting_date) THEN 'new'
		WHEN (YEAR(arv_start_date) < YEAR(reporting_date)) OR
			(YEAR(arv_start_date) = YEAR(reporting_date) AND MONTH(arv_start_date) < MONTH(reporting_date)) THEN 'existing'
		ELSE 'not on ART'
	END
FROM hiv_monthly_reporting_staging t;

-- ############################### TB screening data ##################################################################
UPDATE t1
SET t1.latest_tb_screening_result = tb.tb_screening_result,
    t1.latest_tb_screening_date = tb.tb_screening_date
FROM hiv_monthly_reporting_staging t1
CROSS APPLY (
    SELECT TOP 1 tb2.tb_screening_result, tb2.tb_screening_date
    FROM tb_screening tb2
    WHERE tb2.emr_id = t1.emr_id
      AND tb2.tb_screening_date <= t1.reporting_date
    ORDER BY tb2.tb_screening_date DESC
) tb;


-- ############################### TB testing data ##################################################################
UPDATE t1
SET t1.latest_tb_test_date = tb.specimen_collection_date,
    t1.latest_tb_test_type = tb.test_type,
    t1.latest_tb_test_result = tb.test_result_text
FROM hiv_monthly_reporting_staging t1
CROSS APPLY (
    SELECT TOP 1 tb2.specimen_collection_date, tb2.test_type, tb2.test_result_text
    FROM tb_lab_results tb2
    WHERE tb2.emr_id = t1.emr_id
      AND tb2.specimen_collection_date <= t1.reporting_date
    ORDER BY tb2.specimen_collection_date DESC
) tb;


UPDATE t
SET latest_tb_coinfection_date = l.specimen_collection_date
FROM hiv_monthly_reporting_staging t
CROSS APPLY (
    SELECT TOP 1 l2.specimen_collection_date
    FROM tb_lab_results l2
    WHERE l2.emr_id = t.emr_id
      AND ((l2.test_type = 'genxpert' AND l2.test_result_text = 'Detected') OR
           (l2.test_type = 'smear'    AND l2.test_result_text IN ('1+','++','+++')) OR
           (l2.test_type = 'culture'  AND l2.test_result_text IN ('Scanty','++','+++')))
      AND l2.specimen_collection_date <= t.reporting_date
    ORDER BY l2.specimen_collection_date DESC, l2.index_desc
) l;


-- ############################### Breastfeeding data ##################################################################
UPDATE t1
SET t1.date_of_last_breastfeeding_status = hv.visit_date,
    t1.latest_breastfeeding_status = hv.breastfeeding_status,
    t1.latest_breastfeeding_date = hv.last_breastfeeding_date
FROM hiv_monthly_reporting_staging t1
CROSS APPLY (
    SELECT TOP 1 hv2.visit_date, hv2.breastfeeding_status, hv2.last_breastfeeding_date
    FROM hiv_visit hv2
    WHERE hv2.emr_id = t1.emr_id
      AND hv2.visit_date <= t1.reporting_date
      AND hv2.breastfeeding_status IS NOT NULL
    ORDER BY hv2.visit_date DESC
) hv;

UPDATE t1
SET t1.date_of_last_breastfeeding_status = pv.visit_date,
    t1.latest_breastfeeding_status = pv.breastfeeding_status,
    t1.latest_breastfeeding_date = pv.last_breastfeeding_date
FROM hiv_monthly_reporting_staging t1
CROSS APPLY (
    SELECT TOP 1 pv2.visit_date, pv2.breastfeeding_status, pv2.last_breastfeeding_date
    FROM pmtct_visits pv2
    WHERE pv2.emr_id = t1.emr_id
      AND pv2.visit_date <= t1.reporting_date
      AND pv2.breastfeeding_status IS NOT NULL
    ORDER BY pv2.visit_date DESC
) pv
WHERE pv.visit_date < t1.date_of_last_breastfeeding_status
   OR t1.date_of_last_breastfeeding_status IS NULL;

-- ############################### hiv status data ##################################################################
UPDATE t1
SET t1.latest_program_status_outcome_date = h.start_date,
    t1.latest_program_status_outcome = h.status_outcome
FROM hiv_monthly_reporting_staging t1
CROSS APPLY (
    SELECT TOP 1 h2.start_date, h2.status_outcome
    FROM hiv_status h2
    WHERE h2.emr_id = t1.emr_id
      AND h2.start_date <= t1.reporting_date
    ORDER BY h2.start_date DESC, COALESCE(h2.end_date, CAST('9999-12-31' AS date)) DESC
) h;

-- ################################## combined status #########################################################################
-- note that "pregnant" statuses are ignored with this combined status
UPDATE t
SET latest_status =
        CASE
            WHEN date_completed IS NOT NULL AND date_completed < reporting_date THEN latest_program_status_outcome
            WHEN dispensing_days_late <= 28 THEN 'active - on arvs'
	        WHEN latest_program_status_outcome IS NOT NULL
                AND latest_program_status_outcome NOT LIKE '%pregnant%' THEN latest_program_status_outcome
            ELSE 'Lost to followup'
            END
FROM hiv_monthly_reporting_staging t;

-- ############################### bp systolic/diastolic ##########################################################

UPDATE t
SET latest_bp_diastolic = v.bp_diastolic,
    latest_bp_diastolic_date = v.encounter_datetime
FROM hiv_monthly_reporting_staging t
CROSS APPLY (
    SELECT TOP 1 av2.bp_diastolic, av2.encounter_datetime
    FROM all_vitals av2
    WHERE av2.emr_id = t.emr_id
      AND av2.bp_diastolic IS NOT NULL
      AND av2.encounter_datetime <= t.reporting_date
    ORDER BY av2.encounter_datetime DESC, av2.date_entered DESC
) v;

UPDATE t
SET latest_bp_systolic = v.bp_systolic,
    latest_bp_systolic_date = v.encounter_datetime
FROM hiv_monthly_reporting_staging t
CROSS APPLY (
    SELECT TOP 1 av2.bp_systolic, av2.encounter_datetime
    FROM all_vitals av2
    WHERE av2.emr_id = t.emr_id
      AND av2.bp_systolic IS NOT NULL
      AND av2.encounter_datetime <= t.reporting_date
    ORDER BY av2.encounter_datetime DESC, av2.date_entered DESC
) v;

-- ############################### hypertension ##################################################################

UPDATE t
SET latest_htn_diagnosis_date = d.obs_datetime
FROM hiv_monthly_reporting_staging t
CROSS APPLY (
    SELECT TOP 1 ad2.obs_datetime
    FROM all_diagnosis ad2
    WHERE ad2.patient_primary_id = t.emr_id
      AND ad2.diagnosis_entered LIKE '%HYPERTENSION'
      AND ad2.obs_datetime <= t.reporting_date
    ORDER BY ad2.obs_datetime DESC, ad2.date_created DESC
) d;

UPDATE hiv_monthly_reporting_staging SET htn_diagnosis = 0;
UPDATE hiv_monthly_reporting_staging SET htn_diagnosis = 1 WHERE latest_htn_diagnosis_date IS NOT NULL;

-- ############################### rename table ##################################################################
ALTER TABLE hiv_monthly_reporting_staging DROP COLUMN latest_hiv_vl_id;
DROP TABLE IF EXISTS hiv_monthly_reporting;
EXEC sp_rename 'hiv_monthly_reporting_staging', 'hiv_monthly_reporting';
