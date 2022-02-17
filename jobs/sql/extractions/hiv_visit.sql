	SET sql_safe_updates = 0;
	SET @hiv_intake = (SELECT encounter_type_id FROM encounter_type WHERE uuid = 'c31d306a-40c4-11e7-a919-92ebcb67fe33');
	SET @hiv_followup = (SELECT encounter_type_id FROM encounter_type WHERE uuid = 'c31d3312-40c4-11e7-a919-92ebcb67fe33');
	
	DROP TEMPORARY TABLE IF EXISTS temp_hiv_visit;
	CREATE TEMPORARY TABLE temp_hiv_visit
	(
	encounter_id	INT,
	patient_id		INT,
	emr_id			VARCHAR(25),
	hivemr_v1		varchar(25),	
	encounter_type 	varchar(255),
	pregnant		BIT,
	visit_date		DATE,
	next_visit_date	DATE,
	visit_location	varchar(255),
	index_asc		int,
	index_desc		int
	);

CREATE INDEX temp_hiv_visit_pid ON temp_hiv_visit (patient_id);
CREATE INDEX temp_hiv_visit_eid ON temp_hiv_visit (encounter_id);
	
	INSERT INTO temp_hiv_visit(patient_id, encounter_id, emr_id, visit_date,encounter_type)
	SELECT patient_id, encounter_id, ZLEMR(patient_id),  DATE(encounter_datetime), encounter_type_name(encounter_id) FROM encounter WHERE voided = 0 AND encounter_type IN (@hiv_intake, @hiv_followup);
	
	DELETE FROM temp_hiv_visit
	WHERE
	    patient_id IN (SELECT
	        a.person_id
	    FROM
	        person_attribute a
	            INNER JOIN
	        person_attribute_type t ON a.person_attribute_type_id = t.person_attribute_type_id
	            AND a.value = 'true'
	            AND t.name = 'Test Patient');
	  	
	update temp_hiv_visit t set hivemr_v1  = patient_identifier(patient_id, '139766e8-15f5-102d-96e4-000c29c2a5d7');          
	
	update temp_hiv_visit t set visit_location = location_name(hivEncounterLocationId(encounter_id));           
	
	UPDATE temp_hiv_visit t SET pregnant = (SELECT value_coded FROM obs o WHERE voided = 0 AND concept_id = CONCEPT_FROM_MAPPING("PIH", "PREGNANCY STATUS") AND o.encounter_id = t.encounter_id);
	
	UPDATE temp_hiv_visit t SET next_visit_date = obs_value_datetime(t.encounter_id,'PIH','RETURN VISIT DATE');
	

-- The ascending/descending indexes are calculated ordering on the dispense date
-- new temp tables are used to build them and then joined into the main temp table.
### index ascending
drop temporary table if exists temp_visit_index_asc;
CREATE TEMPORARY TABLE temp_visit_index_asc
(
    SELECT
            patient_id,
            visit_date,
            encounter_id,
            index_asc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_asc,
            visit_date,
            encounter_id,
            patient_id,
            @u:= patient_id
      FROM temp_hiv_visit,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id, visit_date ASC, encounter_id ASC
        ) index_ascending );

CREATE INDEX tvia_e ON temp_visit_index_asc(encounter_id);

update temp_hiv_visit t
inner join temp_visit_index_asc tvia on tvia.encounter_id = t.encounter_id
set t.index_asc = tvia.index_asc;

drop temporary table if exists temp_visit_index_desc;
CREATE TEMPORARY TABLE temp_visit_index_desc
(
    SELECT
            patient_id,
            visit_date,
            encounter_id,
            index_desc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_desc,
            visit_date,
            encounter_id,
            patient_id,
            @u:= patient_id
      FROM temp_hiv_visit,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id, visit_date DESC, encounter_id DESC
        ) index_descending );
       
 CREATE INDEX tvid_e ON temp_visit_index_desc(encounter_id);      

update temp_hiv_visit t
inner join temp_visit_index_desc tvid on tvid.encounter_id = t.encounter_id
set t.index_desc = tvid.index_desc;

SELECT * FROM temp_hiv_visit;
