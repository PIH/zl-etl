-- set @startDate='2020-01-01';
-- set @endDate='2021-08-14';
set @partition = '${partitionNum}';
SET @locale = GLOBAL_PROPERTY_VALUE('default_locale', 'en');
SET sql_safe_updates = 0;

-- ---------------------------------------------------------------
-- Resolve lookups once up front (several were being called per row)
-- ---------------------------------------------------------------
SELECT order_type_id INTO @testOrder FROM order_type WHERE uuid = '52a447d3-a64a-11e3-9aeb-50e549534c5e';
SELECT encounter_type_id INTO @specimenCollEnc FROM encounter_type WHERE uuid = '39C09928-0CAB-4DBA-8E48-39C631FA4286';
SET @primary_id_uuid      = METADATA_UUID('org.openmrs.module.emrapi', 'emr.primaryIdentifierType');
SET @order_number_c       = CONCEPT_FROM_MAPPING('PIH','10781');
SET @test_location_c      = CONCEPT_FROM_MAPPING('PIH','11791');
SET @result_date_c        = CONCEPT_FROM_MAPPING('PIH','Date of test results');
SET @coll_date_estimated_c = CONCEPT_FROM_MAPPING('PIH','11781');
SELECT encounter_type_id INTO @registration_enc_type FROM encounter_type WHERE uuid = '873f968a-73a8-4f9c-ac78-9f4778b751b6';

-- date window: same meaning as DATE(date_activated) between the two dates,
-- written so date_activated isn't wrapped in a function
SET @startDateTime = DATE(@startDate);
SET @endDateExcl   = DATE_ADD(DATE(@endDate), INTERVAL 1 DAY);

DROP TEMPORARY TABLE IF EXISTS temp_report;
CREATE TEMPORARY TABLE temp_report
(
    patient_id      INT,
    emr_id          VARCHAR(255),
    specimen_encounter_id INT,
    order_encounter_id INT,
    visit_id             INT,
    loc_registered  VARCHAR(255),
    unknown_patient CHAR(1),
    gender          CHAR(1),
    age_at_encounter      INT,
    order_number    VARCHAR(255),
    order_reason_concept_id INT(11),
    order_reason    VARCHAR(255),
    accession_number VARCHAR(255),
    order_concept_id INT,
    orderable       VARCHAR(255),
    status          VARCHAR(255),
    user_entered         VARCHAR(255),
    orderer_provider_type VARCHAR(255),
    order_datetime  DATETIME,
    date_stopped    DATETIME,
    auto_expire_date DATETIME,
    fulfiller_status VARCHAR(255),
    ordering_location VARCHAR(255),
    visit_location       VARCHAR(255),
    site             VARCHAR(255),
    urgency         VARCHAR(255),
    specimen_collection_datetime DATETIME,
    collection_date_estimated VARCHAR(255),
    test_location  VARCHAR(255),
    result_date     DATETIME
);

-- load temporary table with all lab test orders within the date range
INSERT INTO temp_report (
    patient_id,
    order_number,
    accession_number,
    order_concept_id,
    order_encounter_id,
    order_datetime,
    date_stopped,
    auto_expire_date,
    fulfiller_status,
    urgency,
    order_reason_concept_id
)
SELECT
    o.patient_id,
    o.order_number,
    o.accession_number,
    o.concept_id,
    o.encounter_id,
    o.date_activated,
    o.date_stopped,
    o.auto_expire_date,
    o.fulfiller_status,
    o.urgency,
    o.order_reason
FROM
    orders o
WHERE o.order_type_id =@testOrder
      AND order_action = 'NEW'
      AND (@startDateTime IS NULL OR o.date_activated >= @startDateTime)
      AND (@endDateExcl   IS NULL OR o.date_activated <  @endDateExcl);

## REMOVE TEST PATIENTS
DELETE
FROM temp_report
WHERE patient_id IN
      (
          SELECT a.person_id
          FROM person_attribute a
          INNER JOIN person_attribute_type t ON a.person_attribute_type_id = t.person_attribute_type_id
          WHERE a.value = 'true'
          AND t.name = 'Test Patient'
      );

CREATE INDEX temp_report_on  ON temp_report(order_number);
CREATE INDEX temp_report_oei ON temp_report(order_encounter_id);

-- ---------------------------------------------------------------
-- patient level columns (one row per patient, filled in one statement)
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_patient_columns;
CREATE TEMPORARY TABLE temp_patient_columns
(
    patient_id      INT PRIMARY KEY,
    emr_id          VARCHAR(255),
    loc_registered  VARCHAR(255),
    unknown_patient CHAR(1),
    gender          CHAR(1)
);

insert into temp_patient_columns (patient_id, emr_id, gender, loc_registered, unknown_patient)
select x.patient_id,
       PATIENT_IDENTIFIER(x.patient_id, @primary_id_uuid),
       (select p.gender from person p where p.person_id = x.patient_id and p.voided = 0),  -- GENDER() inlined
       -- CHANGED: location of the most recent registration encounter (LOC_REGISTERED() took an arbitrary one)
       (select location_name(r.location_id)
          from encounter r
         where r.patient_id = x.patient_id
           and r.encounter_type = @registration_enc_type
           and r.voided = 0
         order by r.encounter_datetime desc, r.encounter_id desc
         limit 1),
       IF(UNKNOWN_PATIENT(x.patient_id) IS NULL,NULL,'1')
from (select distinct patient_id from temp_report where patient_id is not null) x;

-- ---------------------------------------------------------------
-- specimen collection encounters: only those whose order number is in the report
-- (was every specimen encounter ever; the order-number concept was looked up per row)
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_spec;
CREATE TEMPORARY TABLE temp_spec
(
    specimen_encounter_id INT,
    order_number   VARCHAR(255),
    encounter_datetime DATETIME
   );

CREATE  INDEX order_number ON temp_spec(order_number);

INSERT INTO temp_spec (
    specimen_encounter_id,
    order_number,
    encounter_datetime
)
SELECT
    e.encounter_id,
    o.value_text,
    e.encounter_datetime
FROM
    encounter e
    INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.voided = 0 AND o.concept_id = @order_number_c
WHERE e.encounter_type = @specimenCollEnc
      AND e.voided = 0
      AND o.value_text IN (SELECT order_number FROM temp_report);

-- CHANGED: if an order has more than one specimen encounter, use the most recent one
-- (latest encounter_datetime, then highest encounter_id). Was an arbitrary one.
UPDATE temp_report t
  SET t.specimen_encounter_id =
      (SELECT ts.specimen_encounter_id
         FROM temp_spec ts
        WHERE ts.order_number = t.order_number
        ORDER BY ts.encounter_datetime DESC, ts.specimen_encounter_id DESC
        LIMIT 1);

-- ---------------------------------------------------------------
-- specimen-encounter level columns, once per specimen encounter
-- (same joins as before, but on one row per encounter instead of one per order)
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_spec_enc;
CREATE TEMPORARY TABLE temp_spec_enc
(
    encounter_id                 INT PRIMARY KEY,
    specimen_collection_datetime DATETIME,
    collection_date_estimated    VARCHAR(255),
    test_location                VARCHAR(255),
    result_date                  DATETIME
);

INSERT INTO temp_spec_enc (encounter_id, specimen_collection_datetime)
SELECT e.encounter_id, e.encounter_datetime
FROM (SELECT DISTINCT specimen_encounter_id FROM temp_report WHERE specimen_encounter_id IS NOT NULL) x
INNER JOIN encounter e ON e.encounter_id = x.specimen_encounter_id;

-- CHANGED: if a specimen encounter has more than one of these obs, use the most recent
-- (results date: latest results date; test location / date estimated: latest entered).
-- Was an arbitrary one.
update temp_spec_enc t
set t.test_location =
      (select concept_name(o.value_coded, @locale)
         from obs o
        where o.encounter_id = t.encounter_id and o.voided = 0 and o.concept_id = @test_location_c
        order by o.date_created desc, o.obs_id desc
        limit 1),
    t.result_date =
      (select o.value_datetime
         from obs o
        where o.encounter_id = t.encounter_id and o.voided = 0 and o.concept_id = @result_date_c
        order by o.value_datetime desc, o.date_created desc, o.obs_id desc
        limit 1),
    t.collection_date_estimated =
      (select concept_name(o.value_coded, @locale)
         from obs o
        where o.encounter_id = t.encounter_id and o.voided = 0 and o.concept_id = @coll_date_estimated_c
        order by o.date_created desc, o.obs_id desc
        limit 1);

-- ---------------------------------------------------------------
-- order-encounter level columns, once per order encounter
-- (an order encounter usually holds several orders)
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_order_enc;
CREATE TEMPORARY TABLE temp_order_enc
(
    encounter_id          INT PRIMARY KEY,
    patient_id            INT,
    visit_id              INT,
    age_at_encounter      INT,
    user_entered          VARCHAR(255),
    orderer_provider_type VARCHAR(255),
    ordering_location     VARCHAR(255),
    enc_site              VARCHAR(255),
    visit_location_found  INT,
    visit_location        VARCHAR(255)
);

INSERT INTO temp_order_enc
    (encounter_id, patient_id, visit_id, age_at_encounter, user_entered, orderer_provider_type,
     ordering_location, enc_site, visit_location_found, visit_location)
SELECT e.encounter_id,
       e.patient_id,
       e.visit_id,
       (select TIMESTAMPDIFF(YEAR, p.birthdate, e.encounter_datetime)
          from person p where p.person_id = e.patient_id),                                -- age_at_enc() inlined
       PROVIDER(e.encounter_id),
       PROVIDER_TYPE(e.encounter_id),
       (select l.name from location l where l.location_id = e.location_id),             -- ENCOUNTER_LOCATION_NAME() inlined
       (select ls.site from locations ls where ls.location_id = e.location_id limit 1),
       (select 1 from visit v inner join locations lv on lv.location_id = v.location_id
          where v.visit_id = e.visit_id limit 1),
       (select lv.location_name from visit v inner join locations lv on lv.location_id = v.location_id
          where v.visit_id = e.visit_id limit 1)
FROM (SELECT DISTINCT order_encounter_id FROM temp_report WHERE order_encounter_id IS NOT NULL) x
INNER JOIN encounter e ON e.encounter_id = x.order_encounter_id;

-- ---------------------------------------------------------------
-- concept names, once per concept
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_orderables;
CREATE TEMPORARY TABLE temp_orderables
(concept_id INT PRIMARY KEY,
 name       VARCHAR(255));
INSERT INTO temp_orderables
SELECT c.order_concept_id, IFNULL(CONCEPT_NAME(c.order_concept_id, @locale),CONCEPT_NAME(c.order_concept_id, 'en'))
FROM (SELECT DISTINCT order_concept_id FROM temp_report WHERE order_concept_id IS NOT NULL) c;

DROP TEMPORARY TABLE IF EXISTS temp_order_reasons;
CREATE TEMPORARY TABLE temp_order_reasons
(concept_id INT PRIMARY KEY,
 name       VARCHAR(255));
INSERT INTO temp_order_reasons
SELECT c.order_reason_concept_id, CONCEPT_NAME(c.order_reason_concept_id, @locale)
FROM (SELECT DISTINCT order_reason_concept_id FROM temp_report WHERE order_reason_concept_id IS NOT NULL) c;

-- ---------------------------------------------------------------
-- fill everything in one pass
-- ---------------------------------------------------------------
UPDATE temp_report t
LEFT JOIN temp_patient_columns p ON p.patient_id   = t.patient_id
LEFT JOIN temp_order_enc oe      ON oe.encounter_id = t.order_encounter_id
LEFT JOIN temp_spec_enc se       ON se.encounter_id = t.specimen_encounter_id
LEFT JOIN temp_orderables ob     ON ob.concept_id   = t.order_concept_id
LEFT JOIN temp_order_reasons r   ON r.concept_id    = t.order_reason_concept_id
SET t.emr_id                       = p.emr_id,
    t.gender                       = p.gender,
    t.loc_registered               = p.loc_registered,
    t.unknown_patient              = p.unknown_patient,
    -- age_at_enc() only returned a value when the order's patient is the encounter's patient
    t.age_at_encounter             = IF(oe.patient_id = t.patient_id, oe.age_at_encounter, NULL),
    t.orderable                    = ob.name,
    t.order_reason                 = r.name,
    t.user_entered                 = oe.user_entered,
    t.orderer_provider_type        = oe.orderer_provider_type,
    t.ordering_location            = oe.ordering_location,
    t.visit_id                     = oe.visit_id,
    -- site: Visit Location when the visit has one, otherwise the encounter location's site
    t.visit_location               = oe.visit_location,
    t.site                         = IF(oe.visit_location_found = 1, oe.visit_location, oe.enc_site),
    t.specimen_collection_datetime = se.specimen_collection_datetime,
    t.test_location                = se.test_location,
    t.result_date                  = se.result_date,
    t.collection_date_estimated    = se.collection_date_estimated,
    -- status is derived by the order fulfiller status and other fields
    t.status =
    CASE
       WHEN t.date_stopped IS NOT NULL AND t.specimen_encounter_id IS NULL THEN 'Cancelled'
       WHEN t.auto_expire_date < CURDATE() AND t.specimen_encounter_id IS NULL THEN 'Expired'
       WHEN t.fulfiller_status = 'COMPLETED' THEN 'Reported'
       WHEN t.fulfiller_status = 'IN_PROGRESS' THEN 'Collected'
       WHEN t.fulfiller_status = 'EXCEPTION' THEN 'Not Performed'
       ELSE 'Ordered'
    END;

-- final output
SELECT
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',patient_id),patient_id) "patient_id",
emr_id,
loc_registered,
unknown_patient,
gender,
age_at_encounter,
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',order_number),order_number) "order_number",
order_reason,
accession_number "Lab_ID",
orderable,
status,
user_entered,
orderer_provider_type,
order_datetime,
ordering_location,
if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',visit_id),visit_id) "visit_id",
visit_location,
site,
urgency,
specimen_collection_datetime,
collection_date_estimated,
test_location,
result_date
FROM temp_report;
