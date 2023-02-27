set @partition = '${partitionNum}';

drop temporary table if exists temp_eid_visit;
create temporary table temp_eid_visit as
select
patient_id,
zlemr(patient_id) emr_id, 
encounter_id, 
encounter_type_name_from_id(encounter_type) encounter_type, 
date(encounter_datetime) visit_date,  
encounter_location_name(encounter_id) visit_location,
date(date_created) date_entered,
encounter_creator_name(encounter_id) user_entered,
DATE(obs_value_datetime(encounter_id, 'CIEL', '5096')) next_visit_date
from encounter e where encounter_type = encounter_type('HIV-exposed Infant Followup') and e.voided = 0;

/*
-- index asc
DROP TEMPORARY TABLE IF EXISTS temp_eid_enc_index_asc;
CREATE TEMPORARY TABLE temp_eid_enc_index_asc
(
    SELECT
            patient_id,
            emr_id,
            encounter_id,
            encounter_type,
            visit_date,
            visit_location,
            date_entered,
            user_entered,
            next_visit_date,
            index_asc
            FROM (SELECT@r:= IF(@u = patient_id, @r + 1,1) index_asc,
            patient_id,
            emr_id,
            encounter_id,
            encounter_type,
            visit_date,
            visit_location,
            date_entered,
            user_entered,
            next_visit_date,
            @u:= patient_id
      FROM temp_eid_visit,
        (SELECT @r:= 1) AS r,
        (SELECT @u:= 0) AS u
      ORDER BY patient_id, encounter_id ASC
        ) index_ascending );

-- index desc
DROP TEMPORARY TABLE IF EXISTS temp_eid_enc_index_desc;
CREATE TEMPORARY TABLE temp_eid_enc_index_desc
(
    SELECT
            patient_id,
            emr_id,
            encounter_id,
            encounter_type,
            visit_date,
            visit_location,
            date_entered,
            user_entered,
            next_visit_date,
            index_asc,
            index_desc
            FROM (SELECT@r:= IF(@u = patient_id, @r + 1,1) index_desc,
            patient_id,
            emr_id,
            encounter_id,
            encounter_type,
            visit_date,
            visit_location,
            date_entered,
            user_entered,
            next_visit_date,
            index_asc,
            @u:= patient_id
      FROM temp_eid_enc_index_asc,
        (SELECT @r:= 1) AS r,
        (SELECT @u:= 0) AS u
      ORDER BY patient_id, encounter_id DESC
        ) index_descending );

        */

-- final query 
SELECT
    concat(@partition, '-', encounter_id),
    emr_id,
    encounter_type,
    visit_date,
    visit_location,
    date_entered,
    user_entered,
    next_visit_date
FROM
    temp_eid_visit
ORDER BY patient_id , encounter_id;