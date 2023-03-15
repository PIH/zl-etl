SET @partition = '${partitionNum}';
SELECT CONCAT(@partition, '-', patient_id) as patient_id, last_updated, deleted from dbevent_patient;