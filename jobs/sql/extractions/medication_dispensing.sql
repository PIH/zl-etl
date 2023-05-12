SELECT encounter_type_id  INTO @enc_type FROM encounter_type et WHERE uuid='d83e98fd-dc7b-420f-aa3f-36f648b4483d';
SET @partition = '${partitionNum}';

DROP TABLE IF EXISTS medication_dispensing;
CREATE TEMPORARY TABLE medication_dispensing
(
patient_id int,
emr_id varchar(50),
encounter_id int,
encounter_datetime datetime,
encounter_location varchar(100),
date_entered date,
user_entered varchar(30),
encounter_provider varchar(30),
drug_name varchar(500),
dose int,
dose_units varchar(30),
quantity int,
quantity_units varchar(30),
refills int,
dosing_instructions varchar(500),
duration int,
duration_unit varchar(50),
frequency varchar(100)
);

INSERT INTO medication_dispensing(
patient_id,
emr_id,
encounter_id,
encounter_datetime,
encounter_location,
date_entered,
user_entered,
encounter_provider,
drug_name,
dose,
dose_units,
quantity,
quantity_units,
refills,
dosing_instructions,
duration,
duration_unit,
frequency
)
SELECT 
e.patient_id,
zlemr(e.patient_id),
e.encounter_id,
e.encounter_datetime ,
encounter_location_name(e.encounter_id) encounter_location,
e.date_created,
encounter_creator(e.encounter_id) user_entered,
provider(e.encounter_id) encounter_provider,
drugName(do.drug_inventory_id) drug_name,
do.dose,
concept_name(do.dose_units,'en') dose_units,
do.quantity,
concept_name(do.quantity_units,'en') quantity_units,
do.num_refills refills,
do.dosing_instructions,
do.duration,
concept_name(do.duration_units,'en') duration_unit,
concept_name(of2.concept_id,'en') frequency
FROM encounter e INNER JOIN orders o ON o.encounter_id =e.encounter_id AND e.encounter_type = @enc_type
INNER JOIN drug_order do ON do.order_id = o.order_id 
INNER JOIN order_frequency of2 ON of2.order_frequency_id = do.frequency;
-- WHERE e.patient_id =334794;

SELECT 
CONCAT(@partition,'-',emr_id) "emr_id",
CONCAT(@partition,'-',encounter_id) "encounter_id",
encounter_datetime,
encounter_location,
date_entered,
user_entered,
encounter_provider,
drug_name,
dose,
dose_units,
quantity,
quantity_units,
refills,
dosing_instructions,
duration,
duration_unit,
frequency
FROM medication_dispensing;