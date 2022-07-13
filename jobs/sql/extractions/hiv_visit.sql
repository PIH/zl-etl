SET sql_safe_updates = 0;
set @partition = '${partitionNum}';
	
SET @hiv_intake = (SELECT encounter_type_id FROM encounter_type WHERE uuid = 'c31d306a-40c4-11e7-a919-92ebcb67fe33');
SET @hiv_followup = (SELECT encounter_type_id FROM encounter_type WHERE uuid = 'c31d3312-40c4-11e7-a919-92ebcb67fe33');
	
DROP TEMPORARY TABLE IF EXISTS temp_hiv_visit;

CREATE TEMPORARY TABLE temp_hiv_visit
(
encounter_id								INT,
patient_id									INT,
emr_id										VARCHAR(25),
hivemr_v1									VARCHAR(25),	
encounter_type								VARCHAR(255),
date_entered								DATETIME,
user_entered								VARCHAR(50),
chw											VARCHAR(255),
pregnant									BIT,
visit_date									DATE,
rt_in_obs_group_id							INT(11),
referral_transfer_in						VARCHAR(255),
internal_external_in						VARCHAR(255),
referral_transfer_location_in				VARCHAR(255),
referred_by_womens_health_in				BIT,
referral_transfer_pepfar_partner_in			BIT,
rt_out_obs_group_id							INT(11),
referral_transfer_out						VARCHAR(255),
internal_external_out						VARCHAR(255),
referral_transfer_location_out				VARCHAR(255),
referral_transfer_pepfar_partner_out		BIT,
reason_not_on_ARV							VARCHAR(255),
next_visit_date								DATE,
encounter_location_id						INT(11),
visit_location								VARCHAR(255),
index_asc									INT,
index_desc									INT
);

INSERT INTO temp_hiv_visit(patient_id, encounter_id, emr_id, visit_date,encounter_type, date_entered, user_entered, encounter_location_id)
SELECT patient_id, encounter_id, ZLEMR(patient_id),  DATE(encounter_datetime), encounter_type_name(encounter_id), date_created, username(creator), location_id  FROM encounter  WHERE voided = 0 AND encounter_type IN (@hiv_intake, @hiv_followup)
;

CREATE INDEX temp_hiv_visit_pid ON temp_hiv_visit (patient_id);
CREATE INDEX temp_hiv_visit_eid ON temp_hiv_visit (encounter_id);
	
DELETE FROM temp_hiv_visit 
WHERE patient_id IN (SELECT
        a.person_id
    FROM
        person_attribute a
            INNER JOIN
	        person_attribute_type t ON a.person_attribute_type_id = t.person_attribute_type_id
	            AND a.value = 'true'
	            AND t.name = 'Test Patient');
	  	
update temp_hiv_visit t set hivemr_v1  = patient_identifier(patient_id, '139766e8-15f5-102d-96e4-000c29c2a5d7');          
	
update temp_hiv_visit t set visit_location = location_name(encounter_location_id);   

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.comments, o.date_created  
from obs o
inner join temp_hiv_visit t on t.encounter_id = o.encounter_id
where o.voided = 0;

create index temp_obs_ci1 on temp_obs(encounter_id,concept_id);
create index temp_obs_ci3 on temp_obs(obs_group_id,concept_id);

update temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('PIH','11631') and o.voided = 0
set	chw = o.value_text;

update temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('PIH','PREGNANCY STATUS') and o.voided = 0
set	pregnant =	
	 CASE o.value_coded
		WHEN concept_from_mapping('PIH','YES') then 1
		WHEN concept_from_mapping('PIH','NO') then 0
	END;

UPDATE temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('PIH','RETURN VISIT DATE')	and o.voided = 0
set	next_visit_date = o.value_datetime;

-- transfers, referrals IN:
UPDATE 	temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('PIH','13169') and o.voided = 0
set	rt_in_obs_group_id = o.obs_id;

UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_in_obs_group_id and o.concept_id = concept_from_mapping('PIH','13712') and o.voided = 0
set	referral_transfer_in = concept_name(o.value_coded,@locale);

UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_in_obs_group_id and o.concept_id = concept_from_mapping('PIH','6401') and o.voided = 0
set	internal_external_in = concept_name(o.value_coded, @locale);

UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_in_obs_group_id and o.concept_id = concept_from_mapping('PIH','8621') and o.voided = 0
set referral_transfer_location_in = location_name(o.value_text)
where internal_external_in = concept_name(concept_from_mapping('PIH','8855'),@locale);

UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_in_obs_group_id and o.concept_id = concept_from_mapping('PIH','11483') and o.voided = 0
set referral_transfer_location_in = o.value_text
where internal_external_in <> concept_name(concept_from_mapping('PIH','8855'),@locale);

update temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('PIH','13679')	and o.voided = 0
set	referred_by_womens_health_in =	
	 CASE o.value_coded
		WHEN concept_from_mapping('PIH','YES') then 1
		WHEN concept_from_mapping('PIH','NO') then 0
	END;

update temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('PIH','13168')	and o.voided = 0
set referral_transfer_pepfar_partner_in =	
	 CASE o.value_coded
		WHEN concept_from_mapping('PIH','YES') then 1
		WHEN concept_from_mapping('PIH','NO') then 0
	END;

-- transfers, referrals OUT:
UPDATE 	temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('PIH','13170') and o.voided = 0
set rt_out_obs_group_id = o.obs_id;

UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_out_obs_group_id and o.concept_id = concept_from_mapping('PIH','13712') and o.voided = 0
set	referral_transfer_out = concept_name(o.value_coded,	@locale);

UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_out_obs_group_id and o.concept_id = concept_from_mapping('PIH','8854') and o.voided = 0
set	internal_external_out = concept_name(o.value_coded,	@locale);

UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_out_obs_group_id	and o.concept_id = concept_from_mapping('PIH','8621') and o.voided = 0
set referral_transfer_location_out = location_name(o.value_text)
where
	internal_external_out = concept_name(concept_from_mapping('PIH','8855'),@locale);

UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_out_obs_group_id and o.concept_id = concept_from_mapping('PIH','11483') and o.voided = 0
set	referral_transfer_location_out = o.value_text
where
	internal_external_out <> concept_name(concept_from_mapping('PIH','8855'),@locale);

update temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = concept_from_mapping('PIH',	'13168') and o.voided = 0
set	referral_transfer_pepfar_partner_out =	
	 CASE o.value_coded
		WHEN concept_from_mapping('PIH','YES') then 1
		WHEN concept_from_mapping('PIH','NO') then 0
	END;

UPDATE temp_hiv_visit t 
	inner join temp_obs tobs on tobs.encounter_id = t.encounter_id and concept_id = concept_from_mapping('PIH','11337') 
	and tobs.value_coded in 
		(concept_from_mapping('PIH','3580'),
		concept_from_mapping('PIH','7262'),
		concept_from_mapping('PIH','2222'))
set reason_not_on_ARV = concept_name(tobs.value_coded,@locale);


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

SELECT
	concat(@partition, '-', encounter_id),
	emr_id,
	hivemr_v1,
	encounter_type,
	date_entered,
	user_entered,
	chw,
	pregnant,
	referral_transfer_in,
	internal_external_in,
	referral_transfer_location_in,
	referred_by_womens_health_in,
	referral_transfer_pepfar_partner_in,
	referral_transfer_out,
	internal_external_out,
	referral_transfer_location_out,
	referral_transfer_pepfar_partner_out,
	reason_not_on_ARV,
	visit_date,
	next_visit_date,
	visit_location,
	index_asc,
	index_desc
FROM
	temp_hiv_visit t;
