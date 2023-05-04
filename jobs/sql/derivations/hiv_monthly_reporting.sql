DROP TABLE IF EXISTS hiv_monthly_reporting_staging;

create table hiv_monthly_reporting_staging
(
emr_id				                  VARCHAR(20),
date_enrolled				            DATETIME,
date_completed				          DATETIME,
reporting_date				          DATE,
latest_program_status_outcome  VARCHAR(255),
latest_program_status_outcome_date DATE,
latest_hiv_visit_date			      DATETIME,
latest_expected_hiv_visit_date	DATETIME,
hiv_visit_days_late			        INT,
second_to_latest_hiv_visit_date DATE,
latest_transfer_in_date         DATE,
latest_transfer_in_location     VARCHAR(255),
latest_dispensing_date			    DATETIME,
latest_expected_dispensing_date	DATETIME,
dispensing_days_late            INT,
latest_months_dispensed         INT,
latest_hiv_viral_load_date		  DATETIME,
latest_hiv_viral_load_coded		  VARCHAR(255),
latest_hiv_viral_load			      INT,
latest_arv_regimen_date			    DATETIME,
latest_arv_regimen_line			    VARCHAR(255),
latest_arv_dispensed_id			    INT,
latest_arv_dispensed_date		    DATETIME,
latest_arv_dispensed_line		    VARCHAR(255),
days_late_at_latest_pickup      INT,
latest_reason_not_on_ARV_date   DATE,
latest_reason_not_on_ARV        VARCHAR(255),
latest_tb_screening_date        DATE,
latest_tb_screening_result      BIT,
latest_tb_test_date             DATE,
latest_tb_test_type             VARCHAR(255),
latest_tb_test_result           VARCHAR(255),
latest_tb_coinfection_date      DATE,
date_of_last_breastfeeding_status	DATETIME,
latest_breastfeeding_status		  VARCHAR(255),
latest_breastfeeding_date		    DATETIME,
arv_start_date					DATE,
monthly_arv_status				VARCHAR(255),
latest_status                   VARCHAR(255)
);


CREATE OR ALTER VIEW all_reporting_visits AS
SELECT hv.encounter_id ,hv.emr_id ,x.reporting_date ,hv.visit_date, hv.next_visit_date
FROM hiv_visit hv INNER JOIN (
    SELECT DISTINCT dd.LastDayofMonth reporting_date  FROM Dim_Date dd
    WHERE dd.[Year] BETWEEN 2020 AND YEAR(CAST(getdate() AS date))) x
                             on EOMONTH(hv.visit_date) <= x.reporting_date
                                 AND x.reporting_date <= EOMONTH(CAST(GETDATE() AS date));

CREATE OR ALTER VIEW all_reporting_dispense AS
SELECT hd.encounter_id ,hd.emr_id ,x.reporting_date ,hd.dispense_date,hd.next_dispense_date, hd.months_dispensed, hd.days_late_to_pickup
FROM hiv_dispensing hd INNER JOIN (
    SELECT DISTINCT dd.LastDayofMonth reporting_date  FROM Dim_Date dd
    WHERE dd.[Year] BETWEEN 2020 AND YEAR(CAST(getdate() AS date))) x
                                  on EOMONTH(hd.dispense_date) <= x.reporting_date
                                      AND x.reporting_date <= EOMONTH(CAST(GETDATE() AS date));

CREATE OR ALTER VIEW all_reporting_dispense_arv AS
SELECT hd.encounter_id ,hd.emr_id ,x.reporting_date ,hd.dispense_date,hd.next_dispense_date,hd.current_art_treatment_line, hd.arv_1_med , hd.arv_2_med ,hd.arv_3_med
FROM hiv_dispensing hd INNER JOIN (
    SELECT DISTINCT dd.LastDayofMonth reporting_date  FROM Dim_Date dd
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
    SELECT DISTINCT dd.LastDayofMonth reporting_date  FROM Dim_Date dd
    WHERE dd.[Year] BETWEEN 2020 AND YEAR(CAST(getdate() AS date))) x
                                   on EOMONTH(hvl.vl_sample_taken_date) <= x.reporting_date
                                       AND x.reporting_date <= EOMONTH(CAST(GETDATE() AS date));

CREATE OR ALTER VIEW all_reporting_reg AS
SELECT hr.encounter_id ,hr.emr_id ,x.reporting_date ,hr.encounter_datetime ,hr.art_treatment_line
FROM hiv_regimens hr  INNER JOIN (
    SELECT DISTINCT dd.LastDayofMonth reporting_date  FROM Dim_Date dd
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

INSERT INTO hiv_monthly_reporting_staging (emr_id, date_enrolled, date_completed,reporting_date )
SELECT DISTINCT emr_id AS patient_id, date_enrolled ,date_completed, dd.LastDayofMonth reporting_date
FROM hiv_patient_modified hpp
         inner join Dim_Date dd
                    on dd.LastDayofMonth  >= EOMONTH(hpp.date_enrolled)
                        and (EOMONTH(hpp.date_completed) >=dd.LastDayofMonth or hpp.date_completed is null)
                        and dd.LastDayofMonth <=  CAST(GETDATE() AS date);  -- include end of month dates for all prior months only


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

update t1
SET t1.latest_transfer_in_date = v.visit_date ,
    t1.latest_transfer_in_location = v.referral_transfer_location_in
    FROM hiv_monthly_reporting_staging t1 
INNER JOIN hiv_visit v on v.encounter_id =
    (select top 1 v2.encounter_id
    from hiv_visit v2
    where v2.emr_id = t1.emr_id
    and v2.referral_transfer_in = 'Transfer'
    and v2.visit_date <= t1.reporting_date
    order by v2.visit_date desc);

update t1
SET t1.latest_reason_not_on_ARV = v.reason_not_on_ARV,
    t1.latest_reason_not_on_ARV_date = v.visit_date
    FROM hiv_monthly_reporting_staging t1 
INNER JOIN hiv_visit v on v.encounter_id =
    (select top 1 v2.encounter_id
    from hiv_visit v2
    where v2.emr_id = t1.emr_id
    and v2.reason_not_on_ARV is not null
    and v2.visit_date <= t1.reporting_date
    order by v2.visit_date desc);

update t1
SET t1.second_to_latest_hiv_visit_date = v.visit_date
    FROM hiv_monthly_reporting_staging t1 
INNER JOIN hiv_visit v on v.encounter_id =
    (select top 1 v2.encounter_id
    from hiv_visit v2
    where v2.emr_id = t1.emr_id
    and v2.visit_date < t1.latest_hiv_visit_date
    order by v2.visit_date desc);

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
SET t1.latest_hiv_viral_load_date = x.vl_sample_taken_date
    FROM  hiv_monthly_reporting_staging t1 
LEFT OUTER JOIN 
(
	SELECT emr_id,reporting_date,max(vl_sample_taken_date)  vl_sample_taken_date FROM all_reporting_viral
	GROUP BY emr_id,reporting_date
) x
ON t1.emr_id =  x.emr_id AND t1.reporting_date=x.reporting_date;


UPDATE t1
SET t1.latest_hiv_viral_load_coded = avl.vl_coded_results,
    t1.latest_hiv_viral_load=avl.viral_load
    FROM  hiv_monthly_reporting_staging t1 
LEFT OUTER JOIN all_reporting_viral avl
ON t1.emr_id =  avl.emr_id
    AND t1.reporting_date=avl.reporting_date
    AND t1.latest_hiv_viral_load_date=avl.vl_sample_taken_date;

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

drop table if exists #temp_min_arv_date;
select emr_id, min(hr.start_date) "min_arv_start_date"
into #temp_min_arv_date
from hiv_regimens hr
where order_action = 'NEW'
  and drug_category = 'ART'
group by emr_id;

drop table if exists #temp_min_dispensing;
select emr_id, min(dispense_date) "min_dispense_date"
into #temp_min_dispensing
from hiv_dispensing hd
where (arv_1_med is not null or arv_2_med is not null or arv_3_med is not NULL)
group by emr_id;

update t
set arv_start_date =
	CASE
		WHEN ISNULL(min_dispense_date,'9999-12-31') < ISNULL(min_arv_start_date,'9999-12-31') THEN min_dispense_date
		ELSE min_arv_start_date
	END
from hiv_monthly_reporting_staging t
left outer join #temp_min_dispensing tmd on tmd.emr_id  = t.emr_id
left outer join #temp_min_arv_date tad on tad.emr_id  = t.emr_id
;

update t 
set monthly_arv_status =
	CASE
		WHEN YEAR(arv_start_date) = YEAR(reporting_date) and  MONTH(arv_start_date) = MONTH(reporting_date) then 'new'
		WHEN (YEAR(arv_start_date) < YEAR(reporting_date)) OR 
			(YEAR(arv_start_date) = YEAR(reporting_date) and  MONTH(arv_start_date) < MONTH(reporting_date)) then 'existing'
		ELSE 'not on ART'	
	END
from hiv_monthly_reporting_staging t
;	


   

-- ############################### TB screening data ##################################################################
update t1
SET t1.latest_tb_screening_result = tb.tb_screening_result,
    t1.latest_tb_screening_date = tb.tb_screening_date
    FROM hiv_monthly_reporting_staging t1 
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
    FROM hiv_monthly_reporting_staging t1 
INNER JOIN tb_lab_results tb on tb.tb_lab_results_id =
    (select top 1 tb2.tb_lab_results_id
    from tb_lab_results tb2
    where tb2.emr_id = t1.emr_id
    and tb2.specimen_collection_date <= t1.reporting_date
    order by tb2.specimen_collection_date desc);


update t
set latest_tb_coinfection_date = l.specimen_collection_date
    from hiv_monthly_reporting_staging t
inner join tb_lab_results l on l.tb_lab_results_id =
    (select top 1 l2.tb_lab_results_id from tb_lab_results l2
    where l2.emr_id = t.emr_id
    and ((l2.test_type = 'genxpert' and l2.test_result_text = ('Detected')) OR
    (l2.test_type = 'smear' and l2.test_result_text in ('1+','++','+++')) OR
    (l2.test_type = 'culture' and l2.test_result_text in ('Scanty','++','+++')))
    and l2.specimen_collection_date	<= t.reporting_date
    order by l2.specimen_collection_date  desc, l2.index_desc );


-- ############################### Breastfeeding data ##################################################################
update t1
SET t1.date_of_last_breastfeeding_status = hv.visit_date,
    t1.latest_breastfeeding_status = hv.breastfeeding_status,
    t1.latest_breastfeeding_date = hv.last_breastfeeding_date
    FROM hiv_monthly_reporting_staging t1 
INNER JOIN hiv_visit hv on hv.encounter_id =
    (select top 1 hv2.encounter_id
    from hiv_visit hv2
    where hv2.emr_id = t1.emr_id
    and hv2.visit_date <= t1.reporting_date
    and hv2.breastfeeding_status is not null
    order by hv2.visit_date desc);

update t1
SET t1.date_of_last_breastfeeding_status = pv.visit_date,
    t1.latest_breastfeeding_status = pv.breastfeeding_status,
    t1.latest_breastfeeding_date = pv.last_breastfeeding_date
    FROM hiv_monthly_reporting_staging t1 
INNER JOIN pmtct_visits pv on pv.encounter_id =
    (select top 1 pv2.encounter_id
    from pmtct_visits pv2
    where pv2.emr_id = t1.emr_id
    and pv2.visit_date <= t1.reporting_date
    and pv2.breastfeeding_status is not null
    order by pv2.visit_date desc)
where pv.visit_date < t1.date_of_last_breastfeeding_status or t1.date_of_last_breastfeeding_status is null
;
-- ############################### hiv status data ##################################################################
update t1
SET t1.latest_program_status_outcome_date = h.start_date,
    t1.latest_program_status_outcome = h.status_outcome
    FROM hiv_monthly_reporting_staging t1 
INNER JOIN hiv_status h on h.status_id  =
    (select top 1 h2.status_id
    from hiv_status h2
    where h2.emr_id = t1.emr_id
    and h2.start_date  <= t1.reporting_date
    order by h2.start_date desc, COALESCE(end_date,cast('9999-12-31' as date)) desc);

-- ################################## combined status #########################################################################
-- note that "pregnant" statuses are ignored with this combined status
update t
set latest_status =
        CASE
            when latest_program_status_outcome is not null
                and latest_program_status_outcome  not like '%pregnant%' then latest_program_status_outcome
            when dispensing_days_late <= 28  then 'active - on arvs'
            else 'Lost to followup'
            END
    from hiv_monthly_reporting_staging t;

-- ------------------------------------------------------------------------------------

DROP TABLE IF EXISTS hiv_monthly_reporting;
EXEC sp_rename 'hiv_monthly_reporting_staging', 'hiv_monthly_reporting';
