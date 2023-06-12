DROP TABLE IF EXISTS new_medication_dispensing;
CREATE TEMPORARY TABLE new_medication_dispensing
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
drug_openboxes_code int,
duration int,
duration_unit varchar(20),
quantity_per_dose int,
dose_unit varchar(50),
frequency varchar(50),
quantity_dispensed int,
prescription varchar(500)
);


INSERT INTO new_medication_dispensing(emr_id,date_entered,user_entered,drug_name,drug_openboxes_code,quantity_per_dose,
dose_unit,frequency,quantity_dispensed,prescription)
SELECT 
zlemr(patient_id) emr_id, 
md.date_created date_entered,
u.username user_entered,
drugName(drug_id) drug_name,
openboxesCode(drug_id) drug_openboxes_code,
dose quantity_per_dose,
concept_name(dose_units,'en') dose_units,
concept_name(of2.concept_id ,'en') frequency,
quantity quantity_dispensed,
dosing_instructions prescription
FROM medication_dispense md 
LEFT OUTER JOIN users u ON md.creator=u.user_id
LEFT OUTER JOIN order_frequency of2 ON of2.order_frequency_id = md.frequency;

SELECT 
emr_id,
encounter_id ,
encounter_datetime,
encounter_location,
date_entered,
user_entered,
encounter_provider,
drug_name,
drug_openboxes_code,
duration,
duration_unit,
quantity_per_dose,
dose_unit,
frequency,
quantity_dispensed,
prescription
FROM new_medication_dispensing;