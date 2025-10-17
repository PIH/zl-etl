select site, 
cast(encounter_datetime as date) as date,
drug_name, 
drug_openboxes_code, 
sum(quantity_dispensed) "daily_quantity" 
into dispensed_medication_summary_staging
from all_medication_dispensing
group by site, cast(encounter_datetime as date), drug_name, drug_openboxes_code;

DROP TABLE IF EXISTS dispensed_medication_summary;
EXEC sp_rename 'dispensed_medication_summary_staging', 'dispensed_medication_summary';
