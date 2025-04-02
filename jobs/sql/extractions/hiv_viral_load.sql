#### This query returns a row per encounter (VL construct per encounter)

SET sql_safe_updates = 0;

SET @detected_viral_load = CONCEPT_FROM_MAPPING("CIEL", "1301");
set @partition = '${partitionNum}';

DROP TEMPORARY TABLE IF EXISTS temp_hiv_construct_encounters;
### hiv vl constructs table
CREATE TEMPORARY TABLE temp_hiv_construct_encounters
(
    patient_id                      INT,
    encounter_id                    INT,
    order_number                    TEXT,
    visit_id                        INT,
    visit_location                  VARCHAR(255),
    status                          VARCHAR(255),
    date_activated                  DATETIME,
    date_stopped                    DATETIME,
    auto_expire_date                DATETIME,
    fulfiller_status                VARCHAR(255),
    vl_sample_taken_date            DATETIME,
    date_entered                    DATETIME,
    user_entered                    VARCHAR(50),
    vl_sample_taken_date_estimated  VARCHAR(11),
    vl_result_date                  DATE,
    specimen_number                 VARCHAR(255),
    vl_coded_results                VARCHAR(255),
    vl_result_detectable            INT,
    viral_load                      INT,
    ldl_value                       INT,
    vl_type                         VARCHAR(50),
    index_desc                      INT,
    index_asc                       INT
);

-- add patient and encounter IDs 
set @vl_construct = CONCEPT_FROM_MAPPING("PIH", "HIV viral load construct");
INSERT INTO temp_hiv_construct_encounters (patient_id, encounter_id)
SELECT person_id, encounter_id FROM obs WHERE voided = 0 AND concept_id = @vl_construct;

-- add VL orders from lab module
set @VL_panel = concept_from_mapping('PIH','15124');
INSERT INTO temp_hiv_construct_encounters (patient_id, order_number, date_activated, date_stopped, auto_expire_date, fulfiller_status)
select ord.patient_id, ord.order_number, date_activated, date_stopped, auto_expire_date, fulfiller_status from orders ord
where ord.concept_id = @VL_panel;

set @order_num = concept_from_mapping('PIH','10781');
update temp_hiv_construct_encounters t
inner join obs o on o.concept_id = @order_num and o.value_text = t.order_number and o.voided = 0
set t.encounter_id = o.encounter_id;


-- specimen collection date, visit id
UPDATE temp_hiv_construct_encounters tvl INNER JOIN encounter e ON tvl.encounter_id = e.encounter_id
SET	vl_sample_taken_date = e.encounter_datetime, 
    tvl.visit_id = e.visit_id;

-- date encounter was created
UPDATE temp_hiv_construct_encounters tvl JOIN encounter e ON tvl.encounter_id = e.encounter_id
SET	tvl.date_entered = e.date_created, tvl.user_entered = username(e.creator);

## Delete test patients
DELETE FROM temp_hiv_construct_encounters WHERE
patient_id IN (
               SELECT
                      a.person_id
                      FROM person_attribute a
                      INNER JOIN person_attribute_type t ON a.person_attribute_type_id = t.person_attribute_type_id
                      AND a.value = 'true' AND t.name = 'Test Patient'
               );

-- visit location
update temp_hiv_construct_encounters tvl
set visit_location = location_name(hivEncounterLocationId(encounter_id));

-- is specimen collection date estimated
set @collDateEst = concept_from_mapping('PIH','11781');
UPDATE temp_hiv_construct_encounters tvl INNER JOIN obs o ON o.voided = 0 AND tvl.encounter_id = o.encounter_id AND concept_id = @collDateEst
SET vl_sample_taken_date_estimated =  concept_name(o.value_coded , 'en');

-- lab result date
set @testResultsDate = concept_from_mapping('PIH', 'Date of test results');
UPDATE temp_hiv_construct_encounters tvl INNER JOIN obs o ON o.voided = 0 AND tvl.encounter_id = o.encounter_id AND concept_id = @testResultsDate
SET vl_result_date =  DATE(o.value_datetime);

-- specimen number
set @specNumber = concept_from_mapping('CIEL', '162086');
UPDATE temp_hiv_construct_encounters tvl INNER JOIN obs o ON o.voided = 0 AND tvl.encounter_id = o.encounter_id AND concept_id =  @specNumber 
 SET specimen_number =  o.value_text;

-- viral load results (coded, concept name)
set @vlCoded = concept_from_mapping('CIEL', '1305');
UPDATE temp_hiv_construct_encounters tvl INNER JOIN obs o ON o.voided = 0 AND tvl.encounter_id = o.encounter_id AND concept_id = @vlCoded 
SET vl_coded_results =  concept_name(o.value_coded, 'en');

-- viral load results (numeric)
set @vlNumeric = concept_from_mapping('CIEL', '856');
UPDATE temp_hiv_construct_encounters tvl INNER JOIN obs o ON o.voided = 0 AND tvl.encounter_id = o.encounter_id AND concept_id = @vlNumeric
SET viral_load =  o.value_numeric;

-- detected lower limit
set @lowLimit = concept_from_mapping('PIH', '11548');
UPDATE temp_hiv_construct_encounters tvl INNER JOIN obs o ON o.voided = 0 AND tvl.encounter_id = o.encounter_id AND concept_id = @lowLimit
SET ldl_value  =  o.value_numeric;

-- viral load type
set @vlType = concept_from_mapping('CIEL', '164126');
UPDATE temp_hiv_construct_encounters tvl INNER JOIN obs o ON o.voided = 0 AND tvl.encounter_id = o.encounter_id AND concept_id = @vlType
SET vl_type = concept_name(o.value_coded, 'en');

UPDATE temp_hiv_construct_encounters t SET status =
    CASE
       WHEN t.date_stopped IS NOT NULL AND encounter_id IS NULL THEN 'Cancelled'
       WHEN t.auto_expire_date < CURDATE() AND encounter_id IS NULL THEN 'Expired'
       WHEN t.fulfiller_status = 'COMPLETED' THEN 'Reported'
       WHEN t.fulfiller_status = 'IN_PROGRESS' THEN 'Collected'
       WHEN t.fulfiller_status = 'EXCEPTION' THEN 'Not Performed'
       ELSE 'Ordered'
    END 
where order_number is not null;

### Final query
SELECT
        zlemr(tvl.patient_id),
        concat(@partition,'-',tvl.encounter_id) encounter_id,
        concat(@partition,'-',tvl.order_number) order_number,
        tvl.visit_location,
        tvl.date_entered,
        tvl.user_entered,
        status,
        date_activated order_date,
        DATE(tvl.vl_sample_taken_date) vl_sample_taken_date,
        vl_sample_taken_date_estimated,
        vl_result_date,
        specimen_number,
        vl_coded_results,
        viral_load,
        ldl_value,
        vl_type,
        DATEDIFF(NOW(), tvl.vl_sample_taken_date) days_since_vl,
        index_desc,
        index_asc
FROM temp_hiv_construct_encounters tvl;
