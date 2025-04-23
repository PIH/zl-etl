#### This query returns a row per encounter (VL construct per encounter)

SET sql_safe_updates = 0;

SET @detected_viral_load = CONCEPT_FROM_MAPPING("CIEL", "1301");
set @partition = '${partitionNum}';

DROP TEMPORARY TABLE IF EXISTS temp_hiv_vl;
### hiv vl constructs table
CREATE TEMPORARY TABLE temp_hiv_vl
(
    hiv_vl_id                       INT(11) NOT NULL AUTO_INCREMENT,
    emr_id                          VARCHAR(30),
	patient_id                      INT(11),
    order_encounter_id              INT(11),
    specimen_encounter_id           INT(11),
    order_number                    TEXT,
    visit_id                        INT,
    location_id                     INT(11), 
    visit_location                  VARCHAR(255),
    status                          VARCHAR(255),
    date_activated                  DATETIME,
    date_stopped                    DATETIME,
    auto_expire_date                DATETIME,
    fulfiller_status                VARCHAR(255),
    vl_sample_taken_date            DATETIME,
    date_entered                    DATETIME,
    creator                         INT(11),
    user_entered                    VARCHAR(50),
    vl_sample_taken_date_estimated  VARCHAR(11),
    vl_result_date                  DATE,
    specimen_number                 VARCHAR(255),
    vl_coded_results                VARCHAR(255),
    vl_result_detectable            INT,
    viral_load                      INT,
    ldl_value                       INT,
    vl_type_concept_id              INT(11),
    vl_type                         VARCHAR(50),
    days_since_vl                   INT,
    index_desc                      INT,
    index_asc                       INT,
PRIMARY KEY (hiv_vl_id)    
);

-- -------------------------------------------------------------------- add rows from orders
set @VL_panel = concept_from_mapping('PIH','15124');
INSERT INTO temp_hiv_vl (patient_id, order_encounter_id, order_number, date_activated, date_stopped, auto_expire_date, fulfiller_status, vl_type_concept_id)
select ord.patient_id, ord.encounter_id, ord.order_number, date_activated, date_stopped, auto_expire_date, fulfiller_status, order_reason 
from orders ord
where ord.concept_id = @VL_panel;

create index temp_hiv_vl_oei on temp_hiv_vl(order_encounter_id);

update temp_hiv_vl t
set t.vl_type = concept_name(vl_type_concept_id, @locale);

set @order_num = concept_from_mapping('PIH','10781');
update temp_hiv_vl t
inner join obs o on o.concept_id = @order_num and o.value_text = t.order_number and o.voided = 0
set t.specimen_encounter_id = o.encounter_id;

-- -------------------------------------------------------------------- add rows from non-orders
set @vl_construct = CONCEPT_FROM_MAPPING("PIH", "HIV viral load construct");
INSERT INTO temp_hiv_vl (patient_id, specimen_encounter_id)
SELECT person_id, encounter_id FROM obs WHERE voided = 0 AND concept_id = @vl_construct;

create index temp_hiv_vl_sei on temp_hiv_vl(specimen_encounter_id);

-- -------------------------------------------------------------------- specimen, result details
update temp_hiv_vl t
inner join encounter e on e.encounter_id = t.specimen_encounter_id
set t.location_id = e.location_id,
	t.date_entered = e.date_created,
	t.creator = e.creator,
    t.vl_sample_taken_date = e.encounter_datetime, 
    t.visit_id = e.visit_id;

update temp_hiv_vl t
inner join encounter e on e.encounter_id = t.order_encounter_id
set t.location_id = e.location_id,
	t.date_entered = e.date_created,
	t.creator = e.creator
where t.specimen_encounter_id is null;

DROP TABLE IF EXISTS temp_obs;
CREATE TEMPORARY TABLE temp_obs AS
SELECT o.person_id, o.obs_id , o.obs_datetime , o.encounter_id, o.voided, o.value_coded, o.concept_id, o.value_numeric, o.value_datetime, o.date_created
FROM obs o 
INNER JOIN temp_hiv_vl tvl ON tvl.specimen_encounter_id=o.encounter_id
WHERE o.voided =0;

create index temp_obs_c1 on temp_obs(encounter_id, concept_id);

-- is specimen collection date estimated
set @collDateEst = concept_from_mapping('PIH','11781');
UPDATE temp_hiv_vl 
SET vl_sample_taken_date_estimated =  obs_value_coded_list_from_temp_using_concept_id(specimen_encounter_id, @collDateEst, @locale);

-- lab result date
set @testResultsDate = concept_from_mapping('PIH', 'Date of test results');
UPDATE temp_hiv_vl  
SET vl_result_date =  obs_value_datetime_from_temp_using_concept_id(specimen_encounter_id, @testResultsDate);

-- specimen number
set @specNumber = concept_from_mapping('CIEL', '162086');
UPDATE temp_hiv_vl  
SET specimen_number =  obs_value_datetime_from_temp_using_concept_id(specimen_encounter_id, @specNumber);

-- viral load results (coded, concept name)
set @vlCoded = concept_from_mapping('CIEL', '1305');
UPDATE temp_hiv_vl 
SET vl_coded_results =  obs_value_coded_list_from_temp_using_concept_id(specimen_encounter_id, @vlCoded, @locale);

-- viral load results (numeric)
set @vlNumeric = concept_from_mapping('CIEL', '856');
UPDATE temp_hiv_vl  
SET viral_load =  obs_value_numeric_from_temp_using_concept_id(specimen_encounter_id, @vlNumeric);


-- detected lower limit
set @lowLimit = concept_from_mapping('PIH', '11548');
UPDATE temp_hiv_vl  
SET ldl_value =  obs_value_numeric_from_temp_using_concept_id(specimen_encounter_id, @lowLimit);


-- -------------------------------------------------------------------- updates to shared columns
update temp_hiv_vl t
set t.visit_location = location_name(location_id);
 
update temp_hiv_vl t
set t.user_entered = person_name_of_user(creator);

update temp_hiv_vl t
set t.days_since_vl = DATEDIFF(NOW(), COALESCE(vl_sample_taken_date,date_activated));

UPDATE temp_hiv_vl t SET status =
    CASE
       WHEN t.vl_result_date is not null then 'Reported'
	   WHEN t.date_stopped IS NOT NULL AND specimen_encounter_id IS NULL THEN 'Cancelled'
       WHEN t.auto_expire_date < CURDATE() AND specimen_encounter_id IS NULL THEN 'Expired'
       WHEN t.fulfiller_status = 'COMPLETED' THEN 'Reported'
       WHEN t.fulfiller_status = 'IN_PROGRESS' THEN 'Collected'
       WHEN t.fulfiller_status = 'EXCEPTION' THEN 'Not Performed'
       ELSE 'Ordered'
    END 
;

update temp_hiv_vl t SET emr_id = zlemr(patient_id);



### Final query
SELECT
        concat(@partition,'-',hiv_vl_id) hiv_vl_id, 
        emr_id,
        concat(@partition,'-',patient_id) patient_id,  
        concat(@partition,'-',tvl.order_encounter_id) order_encounter_id,        
        concat(@partition,'-',tvl.specimen_encounter_id) specimen_encounter_id,
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
        days_since_vl,
        index_desc,
        index_asc
FROM temp_hiv_vl tvl;
