-- =====================================================================================
-- hiv_monthly_reporting (SQL Server, derived job)
-- One row per patient per month enrolled in the HIV program.
--
-- Approach:
--   1. Copy only the needed columns of each source table into a small #temp table
--      with a clustered index on (emr_id, date), so every "latest as of month-end"
--      lookup is an index seek.
--   2. Build the whole staging table in ONE INSERT ... SELECT, using OUTER APPLY
--      (TOP 1 ... ORDER BY date DESC) per patient-month, instead of ~30 UPDATEs.
--   The all_reporting_* views multiplied every visit/dispense by every later month
--   and then grouped; they are no longer used here (still created, in case other
--   jobs or reports read them).
-- =====================================================================================

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
    latest_expected_pmtct_visit_date      DATETIME,
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

-- ---------------------------------------------------------------------------------
-- Views (unchanged; no longer used by this job, kept for any other consumers)
-- (no GO separators, same as the original script, for your job runner)
-- ---------------------------------------------------------------------------------
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
    OR arv_3_med IS NOT NULL);
CREATE OR ALTER VIEW all_reporting_reg AS
SELECT hr.encounter_id ,hr.emr_id ,x.reporting_date ,hr.encounter_datetime ,hr.art_treatment_line
FROM hiv_regimens hr  INNER JOIN (
    SELECT DISTINCT dd.LastDayofMonth reporting_date  FROM Dim_Date dd) x
                                 on EOMONTH(hr.encounter_datetime) <= x.reporting_date
                                     AND x.reporting_date <= EOMONTH(CAST(GETDATE() AS date))
                                     AND upper(hr.order_action) ='NEW' AND upper(hr.drug_category)='ART';
CREATE OR ALTER VIEW hiv_patient_modified AS
SELECT x.*
FROM (
         SELECT hpp.*, lead(date_enrolled) over(PARTITION BY emr_id ORDER BY date_enrolled) next_date_enrolled
         FROM hiv_patient_program hpp
     ) x
WHERE CASE WHEN next_date_enrolled=date_completed THEN 0 ELSE 1 END=1;

-- ---------------------------------------------------------------------------------
-- 1. Narrow, indexed copies of the source tables
-- ---------------------------------------------------------------------------------
DROP TABLE IF EXISTS #hv;
SELECT emr_id, encounter_id, visit_date, next_visit_date,
       referral_transfer_in, referral_transfer_location_in, reason_not_on_ARV,
       breastfeeding_status, last_breastfeeding_date
INTO #hv
FROM hiv_visit
WHERE visit_date IS NOT NULL;
CREATE CLUSTERED INDEX hv_ci ON #hv(emr_id, visit_date);

DROP TABLE IF EXISTS #pv;
SELECT emr_id, encounter_id, visit_date, next_visit_date, breastfeeding_status, last_breastfeeding_date
INTO #pv
FROM pmtct_visits
WHERE visit_date IS NOT NULL;
CREATE CLUSTERED INDEX pv_ci ON #pv(emr_id, visit_date);

DROP TABLE IF EXISTS #hd;
SELECT emr_id, encounter_id, dispense_date, next_dispense_date, months_dispensed, days_late_to_pickup,
       current_art_treatment_line,
       CASE WHEN arv_1_med IS NOT NULL OR arv_2_med IS NOT NULL OR arv_3_med IS NOT NULL THEN 1 ELSE 0 END AS has_arv
INTO #hd
FROM hiv_dispensing
WHERE dispense_date IS NOT NULL;
CREATE CLUSTERED INDEX hd_ci ON #hd(emr_id, dispense_date);

DROP TABLE IF EXISTS #hr;
SELECT emr_id, encounter_id, encounter_datetime, art_treatment_line
INTO #hr
FROM hiv_regimens
WHERE upper(order_action) = 'NEW' AND upper(drug_category) = 'ART'
  AND encounter_datetime IS NOT NULL;
CREATE CLUSTERED INDEX hr_ci ON #hr(emr_id, encounter_datetime);

DROP TABLE IF EXISTS #vl;
SELECT hiv_vl_id, emr_id, vl_sample_taken_date, date_entered, vl_result_date, order_date, status, vl_coded_results
INTO #vl
FROM hiv_viral_load;
CREATE CLUSTERED INDEX vl_ci ON #vl(emr_id, vl_sample_taken_date, date_entered);

DROP TABLE IF EXISTS #tbs;
SELECT emr_id, tb_screening_date, tb_screening_result
INTO #tbs
FROM tb_screening;
CREATE CLUSTERED INDEX tbs_ci ON #tbs(emr_id, tb_screening_date);

DROP TABLE IF EXISTS #tbl;
SELECT emr_id, specimen_collection_date, test_type, test_result_text, index_desc,
       CASE WHEN (test_type = 'genxpert' AND test_result_text = 'Detected') OR
                 (test_type = 'smear'    AND test_result_text IN ('1+','++','+++')) OR
                 (test_type = 'culture'  AND test_result_text IN ('Scanty','++','+++'))
            THEN 1 ELSE 0 END AS is_coinfection
INTO #tbl
FROM tb_lab_results;
CREATE CLUSTERED INDEX tbl_ci ON #tbl(emr_id, specimen_collection_date);

DROP TABLE IF EXISTS #av;
SELECT emr_id, encounter_datetime, date_entered, bp_systolic, bp_diastolic
INTO #av
FROM all_vitals
WHERE bp_systolic IS NOT NULL OR bp_diastolic IS NOT NULL;
CREATE CLUSTERED INDEX av_ci ON #av(emr_id, encounter_datetime);

-- hypertension diagnoses: the LIKE '%HYPERTENSION' filter runs once here,
-- instead of once per patient-month
DROP TABLE IF EXISTS #htn;
SELECT patient_primary_id AS emr_id, obs_datetime, date_created
INTO #htn
FROM all_diagnosis
WHERE diagnosis_entered LIKE '%HYPERTENSION';
CREATE CLUSTERED INDEX htn_ci ON #htn(emr_id, obs_datetime);

DROP TABLE IF EXISTS #hs;
SELECT emr_id, start_date, end_date, status_outcome
INTO #hs
FROM hiv_status;
CREATE CLUSTERED INDEX hs_ci ON #hs(emr_id, start_date);

-- earliest ARV start, per patient (unchanged logic)
DROP TABLE IF EXISTS #temp_min_arv_date;
SELECT emr_id, MIN(hr.start_date) min_arv_start_date
INTO #temp_min_arv_date
FROM hiv_regimens hr
WHERE order_action = 'NEW'
  AND drug_category = 'ART'
GROUP BY emr_id;
CREATE CLUSTERED INDEX temp_min_arv_date_ei ON #temp_min_arv_date(emr_id);

DROP TABLE IF EXISTS #temp_min_dispensing;
SELECT emr_id, MIN(dispense_date) min_dispense_date
INTO #temp_min_dispensing
FROM hiv_dispensing hd
WHERE (arv_1_med IS NOT NULL OR arv_2_med IS NOT NULL OR arv_3_med IS NOT NULL)
GROUP BY emr_id;
CREATE CLUSTERED INDEX temp_min_dispensing_ei ON #temp_min_dispensing(emr_id);

-- ---------------------------------------------------------------------------------
-- 2. Patient-months (unchanged logic)
-- ---------------------------------------------------------------------------------
DROP TABLE IF EXISTS #base;
SELECT DISTINCT emr_id, date_enrolled, date_completed, dd.LastDayofMonth reporting_date,
       DATEADD(DAY, 1, CAST(dd.LastDayofMonth AS DATETIME)) AS next_day   -- for "in or before this month"
INTO #base
FROM hiv_patient_modified hpp
inner join Dim_Date dd
        on dd.LastDayofMonth  >= EOMONTH(hpp.date_enrolled)
       and (EOMONTH(hpp.date_completed) >= dd.LastDayofMonth or hpp.date_completed is null)
       and dd.LastDayofMonth <= CAST(GETDATE() AS date)  -- include end of month dates for all prior months only
       and dd.LastDayofMonth > '2022-01-01';             -- include only data since 2022

-- ---------------------------------------------------------------------------------
-- 3. Build the staging table in ONE pass
--    "latest as of the month" = TOP 1 ... ORDER BY date DESC, with the same
--    date condition and ordering as the original statement for that column.
--    The view-based columns used EOMONTH(date) <= reporting_date, which is the
--    same as date < reporting_date + 1 day (b.next_day).
-- ---------------------------------------------------------------------------------
INSERT INTO hiv_monthly_reporting_staging
(emr_id, date_enrolled, date_completed, reporting_date,
 latest_program_status_outcome, latest_program_status_outcome_date,
 latest_hiv_visit_date, latest_expected_hiv_visit_date, latest_expected_pmtct_visit_date,
 hiv_visit_days_late, second_to_latest_hiv_visit_date,
 latest_transfer_in_date, latest_transfer_in_location,
 latest_dispensing_date, latest_expected_dispensing_date, dispensing_days_late, latest_months_dispensed,
 latest_hiv_vl_id, latest_hiv_viral_load_order_date, latest_hiv_viral_load_status,
 latest_hiv_viral_load_collection_date, latest_hiv_viral_load_results_date, latest_hiv_viral_load_coded,
 latest_arv_regimen_date, latest_arv_regimen_line,
 latest_arv_dispensed_date, latest_arv_dispensed_line, days_late_at_latest_pickup,
 latest_reason_not_on_ARV_date, latest_reason_not_on_ARV,
 latest_tb_screening_date, latest_tb_screening_result,
 latest_tb_test_date, latest_tb_test_type, latest_tb_test_result, latest_tb_coinfection_date,
 date_of_last_breastfeeding_status, latest_breastfeeding_status, latest_breastfeeding_date,
 arv_start_date, monthly_arv_status, latest_status,
 latest_bp_diastolic, latest_bp_diastolic_date, latest_bp_systolic, latest_bp_systolic_date,
 htn_diagnosis, latest_htn_diagnosis_date)
SELECT
    b.emr_id, b.date_enrolled, b.date_completed, b.reporting_date,
    hs.status_outcome, hs.start_date,
    -- HIV visits
    lv.visit_date, lv.next_visit_date,
    pm.next_visit_date,
    IIF(DATEDIFF(DAY, ISNULL(lv.next_visit_date, ISNULL(lv.visit_date, b.date_enrolled)), b.reporting_date) > 0,
        DATEDIFF(DAY, ISNULL(lv.next_visit_date, ISNULL(lv.visit_date, b.date_enrolled)), b.reporting_date), 0),
    s2.visit_date,
    ti.visit_date, ti.referral_transfer_location_in,
    -- dispensing
    ld.dispense_date, ld.next_dispense_date, calc.dispensing_days_late, ld.months_dispensed,
    -- viral load
    vl.hiv_vl_id, vl.order_date, vl.status, vl.vl_sample_taken_date, vl.vl_result_date, vl.vl_coded_results,
    -- regimens / ARV dispensing
    rg.encounter_datetime, rg.art_treatment_line,
    da.dispense_date, da.current_art_treatment_line, ld.days_late_to_pickup,
    rn.visit_date, rn.reason_not_on_ARV,
    -- TB
    tbs.tb_screening_date, tbs.tb_screening_result,
    tbl.specimen_collection_date, tbl.test_type, tbl.test_result_text,
    tbc.specimen_collection_date,
    -- breastfeeding: HIV visit first, then the PMTCT visit replaces it under the
    -- same condition as the original second UPDATE (see note in the reply)
    IIF(bfp.visit_date IS NOT NULL AND (bfh.visit_date IS NULL OR bfp.visit_date < bfh.visit_date), bfp.visit_date,              bfh.visit_date),
    IIF(bfp.visit_date IS NOT NULL AND (bfh.visit_date IS NULL OR bfp.visit_date < bfh.visit_date), bfp.breastfeeding_status,    bfh.breastfeeding_status),
    IIF(bfp.visit_date IS NOT NULL AND (bfh.visit_date IS NULL OR bfp.visit_date < bfh.visit_date), bfp.last_breastfeeding_date, bfh.last_breastfeeding_date),
    -- ARV status
    arv.arv_start_date,
    CASE
        WHEN YEAR(arv.arv_start_date) = YEAR(b.reporting_date) AND MONTH(arv.arv_start_date) = MONTH(b.reporting_date) THEN 'new'
        WHEN (YEAR(arv.arv_start_date) < YEAR(b.reporting_date)) OR
             (YEAR(arv.arv_start_date) = YEAR(b.reporting_date) AND MONTH(arv.arv_start_date) < MONTH(b.reporting_date)) THEN 'existing'
        ELSE 'not on ART'
    END,
    -- combined status (note that "pregnant" statuses are ignored)
    CASE
        WHEN b.date_completed IS NOT NULL AND b.date_completed < b.reporting_date THEN hs.status_outcome
        WHEN calc.dispensing_days_late <= 28 THEN 'active - on arvs'
        WHEN hs.status_outcome IS NOT NULL AND hs.status_outcome NOT LIKE '%pregnant%' THEN hs.status_outcome
        ELSE 'Lost to followup'
    END,
    -- BP / hypertension
    bpd.bp_diastolic, bpd.encounter_datetime,
    bps.bp_systolic,  bps.encounter_datetime,
    IIF(htn.obs_datetime IS NOT NULL, 1, 0), htn.obs_datetime
FROM #base b
-- latest HIV visit in or before the month, with its next visit date
OUTER APPLY (SELECT TOP 1 v.visit_date, v.next_visit_date FROM #hv v
             WHERE v.emr_id = b.emr_id AND v.visit_date < b.next_day
             ORDER BY v.visit_date DESC, v.encounter_id DESC) lv
-- second-to-latest HIV visit
OUTER APPLY (SELECT TOP 1 v.visit_date FROM #hv v
             WHERE v.emr_id = b.emr_id AND v.visit_date < lv.visit_date
             ORDER BY v.visit_date DESC) s2
-- latest transfer in
OUTER APPLY (SELECT TOP 1 v.visit_date, v.referral_transfer_location_in FROM #hv v
             WHERE v.emr_id = b.emr_id AND v.referral_transfer_in = 'Transfer' AND v.visit_date <= b.reporting_date
             ORDER BY v.visit_date DESC) ti
-- latest reason not on ARV
OUTER APPLY (SELECT TOP 1 v.visit_date, v.reason_not_on_ARV FROM #hv v
             WHERE v.emr_id = b.emr_id AND v.reason_not_on_ARV IS NOT NULL AND v.visit_date <= b.reporting_date
             ORDER BY v.visit_date DESC) rn
-- latest PMTCT visit -> expected PMTCT visit date (see note in the reply)
OUTER APPLY (SELECT TOP 1 p.next_visit_date FROM #pv p
             WHERE p.emr_id = b.emr_id AND p.visit_date <= b.reporting_date
             ORDER BY p.visit_date DESC, p.encounter_id DESC) pm
-- breastfeeding from HIV and PMTCT visits
OUTER APPLY (SELECT TOP 1 v.visit_date, v.breastfeeding_status, v.last_breastfeeding_date FROM #hv v
             WHERE v.emr_id = b.emr_id AND v.visit_date <= b.reporting_date AND v.breastfeeding_status IS NOT NULL
             ORDER BY v.visit_date DESC) bfh
OUTER APPLY (SELECT TOP 1 p.visit_date, p.breastfeeding_status, p.last_breastfeeding_date FROM #pv p
             WHERE p.emr_id = b.emr_id AND p.visit_date <= b.reporting_date AND p.breastfeeding_status IS NOT NULL
             ORDER BY p.visit_date DESC) bfp
-- latest dispensing in or before the month
-- (ties on the same dispense_date: highest encounter_id, i.e. the most recently created)
OUTER APPLY (SELECT TOP 1 d.dispense_date, d.next_dispense_date, d.months_dispensed, d.days_late_to_pickup FROM #hd d
             WHERE d.emr_id = b.emr_id AND d.dispense_date < b.next_day
             ORDER BY d.dispense_date DESC, d.encounter_id DESC) ld
-- latest ARV dispensing in or before the month
OUTER APPLY (SELECT TOP 1 d.dispense_date, d.current_art_treatment_line FROM #hd d
             WHERE d.emr_id = b.emr_id AND d.has_arv = 1 AND d.dispense_date < b.next_day
             ORDER BY d.dispense_date DESC, d.encounter_id DESC) da
-- latest ART regimen in or before the month
OUTER APPLY (SELECT TOP 1 r.encounter_datetime, r.art_treatment_line FROM #hr r
             WHERE r.emr_id = b.emr_id AND r.encounter_datetime < b.next_day
             ORDER BY r.encounter_datetime DESC, r.encounter_id DESC) rg
-- latest viral load (same condition and ordering as before)
OUTER APPLY (SELECT TOP 1 x.hiv_vl_id, x.order_date, x.status, x.vl_sample_taken_date, x.vl_result_date, x.vl_coded_results
             FROM #vl x
             WHERE x.emr_id = b.emr_id AND COALESCE(x.vl_sample_taken_date, x.date_entered) <= b.reporting_date
             ORDER BY x.vl_sample_taken_date DESC, x.date_entered DESC) vl
-- TB
OUTER APPLY (SELECT TOP 1 t.tb_screening_date, t.tb_screening_result FROM #tbs t
             WHERE t.emr_id = b.emr_id AND t.tb_screening_date <= b.reporting_date
             ORDER BY t.tb_screening_date DESC) tbs
-- ties on the same collection date: index_desc decides (same as the coinfection lookup)
OUTER APPLY (SELECT TOP 1 t.specimen_collection_date, t.test_type, t.test_result_text FROM #tbl t
             WHERE t.emr_id = b.emr_id AND t.specimen_collection_date <= b.reporting_date
             ORDER BY t.specimen_collection_date DESC, t.index_desc) tbl
OUTER APPLY (SELECT TOP 1 t.specimen_collection_date FROM #tbl t
             WHERE t.emr_id = b.emr_id AND t.is_coinfection = 1 AND t.specimen_collection_date <= b.reporting_date
             ORDER BY t.specimen_collection_date DESC, t.index_desc) tbc
-- program status
OUTER APPLY (SELECT TOP 1 h.start_date, h.status_outcome FROM #hs h
             WHERE h.emr_id = b.emr_id AND h.start_date <= b.reporting_date
             ORDER BY h.start_date DESC, COALESCE(h.end_date, CAST('9999-12-31' AS date)) DESC,
                      IIF(h.status_outcome IS NULL, 1, 0)) hs   -- ties: prefer a non-NULL outcome
-- BP
OUTER APPLY (SELECT TOP 1 a.bp_diastolic, a.encounter_datetime FROM #av a
             WHERE a.emr_id = b.emr_id AND a.bp_diastolic IS NOT NULL AND a.encounter_datetime <= b.reporting_date
             ORDER BY a.encounter_datetime DESC, a.date_entered DESC) bpd
OUTER APPLY (SELECT TOP 1 a.bp_systolic, a.encounter_datetime FROM #av a
             WHERE a.emr_id = b.emr_id AND a.bp_systolic IS NOT NULL AND a.encounter_datetime <= b.reporting_date
             ORDER BY a.encounter_datetime DESC, a.date_entered DESC) bps
-- hypertension
OUTER APPLY (SELECT TOP 1 d.obs_datetime FROM #htn d
             WHERE d.emr_id = b.emr_id AND d.obs_datetime <= b.reporting_date
             ORDER BY d.obs_datetime DESC, d.date_created DESC) htn
-- ARV start date (unchanged logic)
LEFT JOIN #temp_min_dispensing tmd ON tmd.emr_id = b.emr_id
LEFT JOIN #temp_min_arv_date   tad ON tad.emr_id = b.emr_id
CROSS APPLY (SELECT CAST(CASE
                 WHEN ISNULL(tmd.min_dispense_date,'9999-12-31') < ISNULL(tad.min_arv_start_date,'9999-12-31') THEN tmd.min_dispense_date
                 ELSE tad.min_arv_start_date
             END AS DATE) AS arv_start_date) arv
-- dispensing days late (used twice: its own column and latest_status)
CROSS APPLY (SELECT CAST(IIF(
                 DATEDIFF(DAY, ISNULL(ld.next_dispense_date, ISNULL(ld.dispense_date, b.date_enrolled)), b.reporting_date) > 0,
                 DATEDIFF(DAY, ISNULL(ld.next_dispense_date, ISNULL(ld.dispense_date, b.date_enrolled)), b.reporting_date),
                 0) AS INT) AS dispensing_days_late) calc;

CREATE INDEX hiv_monthly_reporting_staging_ei ON hiv_monthly_reporting_staging(emr_id, reporting_date);

-- ---------------------------------------------------------------------------------
-- 4. Rename table (unchanged)
-- ---------------------------------------------------------------------------------
ALTER TABLE hiv_monthly_reporting_staging DROP COLUMN latest_hiv_vl_id;
DROP TABLE IF EXISTS hiv_monthly_reporting;
EXEC sp_rename 'hiv_monthly_reporting_staging', 'hiv_monthly_reporting';
