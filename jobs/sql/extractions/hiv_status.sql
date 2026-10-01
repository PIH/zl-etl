SELECT program_id INTO @hiv_program FROM program WHERE uuid = 'b1cb1fc1-5190-4f7a-af08-48870975dafc';
SELECT encounter_type_id INTO @hivDispensingEncType FROM encounter_type WHERE uuid = 'cc1720c9-3e4c-4fa8-a7ec-40eeaad1958c';

SET sql_safe_updates = 0;
SET @next_dispense_concept = CONCEPT_FROM_MAPPING('PIH','5096');
SET @ltfu_concept          = CONCEPT_FROM_MAPPING('PIH','LOST TO FOLLOWUP');
	
DROP TEMPORARY TABLE IF EXISTS temp_status;
CREATE TEMPORARY TABLE temp_status
(
status_id INT(11) AUTO_INCREMENT,
patient_id INT(11),
hiv_program_id INT(11),
location_id INT(11),
outcome INT(1),
status_concept_id INT(11),
start_date DATETIME,
end_date DATETIME,
return_to_care INT(1),
currently_late_for_pickup INT(1),
index_program_ascending INT(11),
index_program_descending INT(11),
index_patient_ascending INT(11),
index_patient_descending INT(11),
transfer_site VARCHAR(255),
transfer_external_sitename VARCHAR(255),
transfer_internal_sitename VARCHAR(255),
latest_encounter_id INT,
PRIMARY KEY (status_id)
);

CREATE INDEX temp_status_patient_id ON temp_status (patient_id);

-- ---------------------------------------------------------------
-- 1. Rows (unchanged): enrollments, status changes, outcomes
-- ---------------------------------------------------------------
-- load all enrollments into temp table
INSERT INTO temp_status (patient_id, hiv_program_id, location_id, start_date)
SELECT patient_id, patient_program_id, location_id, date_enrolled
FROM patient_program
WHERE program_id = @hiv_program
AND voided = 0;

-- load all status changes into temp table
INSERT INTO temp_status (patient_id, hiv_program_id, status_concept_id, location_id, start_date)
SELECT pp.patient_id, ps.patient_program_id, pws.concept_id, pp.location_id, ps.start_date
FROM patient_state ps
INNER JOIN patient_program pp ON pp.patient_program_id = ps.patient_program_id AND pp.program_id = @hiv_program
INNER JOIN program_workflow_state pws ON pws.program_workflow_state_id = ps.state
WHERE ps.voided = 0;

-- load all outcomes into temp table
INSERT INTO temp_status (patient_id, hiv_program_id, status_concept_id, location_id, start_date, end_date, outcome)
SELECT patient_id, patient_program_id, outcome_concept_id, location_id, date_completed, date_completed, 1
FROM patient_program
WHERE program_id = @hiv_program
AND date_completed IS NOT NULL
AND voided = 0;

-- ---------------------------------------------------------------
-- NOTE: the index_* columns are populated downstream, so they are left
-- NULL here. end_date (non-outcome rows) and transfer_internal_sitename
-- are not calculated (they always came out NULL in the original too).
-- ---------------------------------------------------------------

-- ---------------------------------------------------------------
-- Return to care: on any row that is not an outcome, set to 1 if an
-- EARLIER row for the same patient is "lost to followup".
-- "Earlier" uses the same ordering the original index_patient_ascending
-- was meant to use: start_date, then hiv_program_id, then status_id.
-- (The original compared against index_patient_ascending, which is NULL
--  in this script, so it never matched and return_to_care was always 0.)
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_status_ltfu;
CREATE TEMPORARY TABLE temp_status_ltfu
(patient_id     INT(11),
 start_date     DATETIME,
 hiv_program_id INT(11),
 status_id      INT(11),
 INDEX temp_status_ltfu_pi (patient_id, start_date));
-- (a separate copy, because MySQL can't read temp_status inside an UPDATE of temp_status)
INSERT INTO temp_status_ltfu
SELECT patient_id, start_date, hiv_program_id, status_id
FROM temp_status
WHERE status_concept_id = @ltfu_concept;

UPDATE temp_status t
SET t.return_to_care = 1
WHERE t.outcome IS NULL
  AND EXISTS
      (SELECT 1 FROM temp_status_ltfu l
       WHERE l.patient_id = t.patient_id
         AND (   l.start_date < t.start_date
              OR (l.start_date = t.start_date AND l.hiv_program_id < t.hiv_program_id)
              OR (l.start_date = t.start_date AND l.hiv_program_id = t.hiv_program_id AND l.status_id < t.status_id)));

-- ---------------------------------------------------------------
-- 2. Late for pickup, ONCE per patient (was LATESTENC() per status row)
--    latest HIV dispensing encounter -> its next dispensing date (PIH:5096);
--    late if >= 29 days ago, or if there is no next dispensing date
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_status_patients;
CREATE TEMPORARY TABLE temp_status_patients
(patient_id                INT(11) PRIMARY KEY,
 emr_id                    VARCHAR(255),
 latest_dispense_enc_id    INT(11),
 next_dispense_date        DATETIME,
 currently_late_for_pickup INT(1));

-- latestEnc() inlined: latest non-voided encounter of that type, by encounter_datetime
-- zlemr() inlined: patient_identifier(patient_id, 'ZL EMR ID')
INSERT INTO temp_status_patients (patient_id, emr_id, latest_dispense_enc_id)
SELECT p.patient_id,
       (SELECT i.identifier FROM patient_identifier i
         INNER JOIN patient_identifier_type it ON it.patient_identifier_type_id = i.identifier_type
         WHERE (it.name = 'ZL EMR ID' OR it.uuid = 'ZL EMR ID')
           AND i.voided = 0 AND i.patient_id = p.patient_id
         ORDER BY i.preferred DESC, i.date_created DESC LIMIT 1),
       (SELECT enc.encounter_id FROM encounter enc
         WHERE enc.voided = 0 AND enc.patient_id = p.patient_id
           AND enc.encounter_type = @hivDispensingEncType
         ORDER BY enc.encounter_datetime DESC LIMIT 1)
FROM (SELECT DISTINCT patient_id FROM temp_status) p;

-- next dispensing date from that encounter (first matching obs, as the original join did)
UPDATE temp_status_patients p
SET p.next_dispense_date =
    (SELECT o.value_datetime FROM obs o
     WHERE o.encounter_id = p.latest_dispense_enc_id
       AND o.voided = 0
       AND o.concept_id = @next_dispense_concept
     ORDER BY o.obs_id LIMIT 1);

UPDATE temp_status_patients p
SET p.currently_late_for_pickup =
    IF(TIMESTAMPDIFF(DAY, IFNULL(DATE(p.next_dispense_date),'1900-01-01'), CURRENT_DATE) >= 29, 1, NULL);

-- ---------------------------------------------------------------
-- 3. Name lookups, once per location / concept (were functions per row)
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_status_locations;
CREATE TEMPORARY TABLE temp_status_locations
(location_id   INT(11) PRIMARY KEY,
 location_name TEXT);
INSERT INTO temp_status_locations
SELECT l.location_id, LOCATION_NAME(l.location_id)
FROM (SELECT DISTINCT location_id FROM temp_status WHERE location_id IS NOT NULL) l;

DROP TEMPORARY TABLE IF EXISTS temp_status_concepts;
CREATE TEMPORARY TABLE temp_status_concepts
(concept_id   INT(11) PRIMARY KEY,
 concept_name VARCHAR(255));
INSERT INTO temp_status_concepts
SELECT c.status_concept_id, CONCEPT_NAME(c.status_concept_id, 'en')
FROM (SELECT DISTINCT status_concept_id FROM temp_status WHERE status_concept_id IS NOT NULL) c;

-- ---------------------------------------------------------------
-- 4. Final query (same columns, column names and order as before)
-- ---------------------------------------------------------------
SELECT
    t.status_id,
    p.emr_id AS `zlemr(patient_id)`,
    l.location_name AS `patient_location`,
    t.transfer_internal_sitename,
    c.concept_name AS `status_outcome`,
    DATE(t.start_date) AS `DATE(start_date)`,
    DATE(t.end_date) AS `DATE(end_date)`,
    IFNULL(t.return_to_care,0) AS `return_to_care`,
    IFNULL(p.currently_late_for_pickup,0) AS `currently_late_for_pickup`,
    t.hiv_program_id,
    t.index_program_ascending,
    t.index_program_descending,
    t.index_patient_ascending,
    t.index_patient_descending
FROM temp_status t
LEFT JOIN temp_status_patients p   ON p.patient_id  = t.patient_id
LEFT JOIN temp_status_locations l  ON l.location_id = t.location_id
LEFT JOIN temp_status_concepts c   ON c.concept_id  = t.status_concept_id
ORDER BY t.patient_id;
