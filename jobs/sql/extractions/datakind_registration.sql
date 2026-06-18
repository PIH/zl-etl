set @reg_encounter_type = (select encounter_type_id from
encounter_type where uuid = '873f968a-73a8-4f9c-ac78-9f4778b751b6');

SELECT
    p.patient_id,
    encounter_datetime 'registration_date',
    d.death_date,
	p.date_created 'patient_date_created',
    p.date_changed 'patient_date_changed',
    e.date_created 'encouter_date_created',
    e.date_changed 'encounter_date_changed',
    -- Sets health_center from the patient's registered Health Center person attribute.
    pa.value 'health_center'
FROM
    patient p
        LEFT JOIN
    encounter e ON p.patient_id = e.patient_id
        AND e.voided = 0
        AND p.voided = 0
        AND e.encounter_type = @reg_encounter_type
        LEFT JOIN
    person d ON d.person_id = p.patient_id
        AND d.voided = 0
        LEFT JOIN
    person_attribute pa ON pa.person_id = p.patient_id
        AND pa.voided = 0
        AND pa.person_attribute_type_id = @healthCenterAttr
ORDER BY p.patient_id;