SET sql_safe_updates = 0;
set @partition = '${partitionNum}';
set @locale = 'en';
SET @hiv_intake = (SELECT encounter_type_id FROM encounter_type WHERE uuid = 'c31d306a-40c4-11e7-a919-92ebcb67fe33');
SET @hiv_followup = (SELECT encounter_type_id FROM encounter_type WHERE uuid = 'c31d3312-40c4-11e7-a919-92ebcb67fe33');

DROP TEMPORARY TABLE IF EXISTS temp_hiv_visit;
CREATE TEMPORARY TABLE temp_hiv_visit
(
encounter_id                         INT(11),      
visit_id                             INT(11),      
patient_id                           INT(11),      
emr_id                               VARCHAR(25),  
hivemr_v1                            VARCHAR(25),  
encounter_type_id                    INT(11),      
encounter_type                       VARCHAR(255), 
date_entered                         DATETIME,     
creator                              INT(11),      
user_entered                         VARCHAR(50),  
chw                                  VARCHAR(255), 
who_stage                            VARCHAR(255), 
pregnant                             BIT,          
visit_date                           DATETIME,     
rt_in_obs_group_id                   INT(11),      
referral_transfer_in                 VARCHAR(255), 
internal_external_in                 VARCHAR(255), 
referral_transfer_location_in        VARCHAR(255), 
referred_by_womens_health_in         BIT,          
referral_transfer_pepfar_partner_in  BIT,          
rt_out_obs_group_id                  INT(11),      
referral_transfer_out                VARCHAR(255), 
internal_external_out                VARCHAR(255), 
referral_transfer_location_out       VARCHAR(255), 
referral_transfer_pepfar_partner_out BIT,          
reason_not_on_ARV                    VARCHAR(255), 
breastfeeding_status                 VARCHAR(255), 
last_breastfeeding_date              DATETIME,     
next_visit_date                      DATE,         
encounter_location_id                INT(11),      
visit_location                       VARCHAR(255), 
inh_line                             VARCHAR(50),  
inh_start_date                       DATE,         
inh_end_date                         DATE,         
sexually_active_with_men             BIT,          
sexually_active_with_women           BIT,          
intravenous_drug_use                 BIT,          
blood_transfusion                    BIT,          
maternal_to_fetal_transmission       BIT,          
accidental_exposure_to_blood         BIT,          
sex_with_infected                    BIT,          
sex_with_drug_user                   BIT,          
heterosexual_sex_bisexual            BIT,          
heterosexual_sex_blood_transfusion   BIT,          
other_mode_of_transmission           BIT,          
history_of_syphilis                  BIT,          
history_of_other_sti                 BIT,          
victim_of_gbv                        BIT,          
multiple_partners                    BIT,          
without_condom                       BIT,          
anal_sex                             BIT,          
with_sex_worker                      BIT,          
other_risk_factor                    BIT,          
index_asc                            INT,          
index_desc                           INT           
);

INSERT INTO temp_hiv_visit(patient_id, encounter_id, visit_id, visit_date, date_entered, creator, encounter_location_id, encounter_type_id)
SELECT patient_id, encounter_id, visit_id, encounter_datetime, date_created, creator, location_id, encounter_type  FROM encounter  WHERE voided = 0 AND encounter_type IN (@hiv_intake, @hiv_followup)
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

	           
update temp_hiv_visit t	
inner join encounter_type et on et.encounter_type_id = t.encounter_type_id  
set encounter_type = et.name ;	           
	           

DROP TEMPORARY TABLE IF EXISTS temp_identifiers;
CREATE TEMPORARY TABLE temp_identifiers
(
patient_id						INT(11),
emr_id							VARCHAR(25),
hivemr_v1						VARCHAR(25)
);

INSERT INTO temp_identifiers(patient_id)
select distinct patient_id from temp_hiv_visit;

update temp_identifiers t set hivemr_v1  = patient_identifier(patient_id, '139766e8-15f5-102d-96e4-000c29c2a5d7');          
update temp_identifiers t set emr_id  = zlemr(patient_id);	

CREATE INDEX temp_identifiers_p ON temp_identifiers (patient_id);

update temp_hiv_visit thv 
inner join temp_identifiers ti on ti.patient_id = thv.patient_id
set thv.emr_id = ti.emr_id,
	thv.hivemr_v1 = ti.hivemr_v1;

update temp_hiv_visit t set visit_location = location_name(encounter_location_id);   
update temp_hiv_visit t set user_entered = username(creator);   


drop temporary table if exists temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.comments, o.date_created  
from obs o
inner join temp_hiv_visit t on t.encounter_id = o.encounter_id
where o.voided = 0;

create index temp_obs_ci1 on temp_obs(concept_id, encounter_id);
create index temp_obs_ci2 on temp_obs(concept_id,obs_group_id);

set @chw = concept_from_mapping('PIH','11631');
update temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = @chw  and o.voided = 0
set	chw = o.value_text;

set @who_stage = concept_from_mapping('PIH','5356');
update temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = @who_stage  and o.voided = 0
set	who_stage = concept_name(o.value_coded,@locale);

set @pregStatus = concept_from_mapping('PIH','PREGNANCY STATUS') ;
set @yesID =concept_from_mapping('PIH','YES');
set @noID = concept_from_mapping('PIH','NO');
update temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = @pregStatus and o.voided = 0
set	pregnant =	
	 CASE o.value_coded
		WHEN @yesID then 1
		WHEN @noID then 0
	END;

set @returnVD = concept_from_mapping('PIH','RETURN VISIT DATE');
UPDATE temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = @returnVD	and o.voided = 0
set	next_visit_date = o.value_datetime;

-- transfers, referrals IN:
set @tranRefer = concept_from_mapping('PIH','13169');
UPDATE 	temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = @tranRefer and o.voided = 0
set	rt_in_obs_group_id = o.obs_id;

set @tranReferIn = concept_from_mapping('PIH','13712');
UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_in_obs_group_id and o.concept_id = @tranReferIn and o.voided = 0
set	referral_transfer_in = concept_name(o.value_coded,@locale);

set @inExIn = concept_from_mapping('PIH','6401');
UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_in_obs_group_id and o.concept_id = @inExIn and o.voided = 0
set	internal_external_in = concept_name(o.value_coded, @locale);

set @tranReferLoc = concept_from_mapping('PIH','8621');
set @zlSite = concept_from_mapping('PIH','8855');
UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_in_obs_group_id and o.concept_id = @tranReferLoc and o.voided = 0
set referral_transfer_location_in = location_name(o.value_text)
where internal_external_in = concept_name(@zlSite,@locale);

set @exLocName = concept_from_mapping('PIH','11483');
UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_in_obs_group_id and o.concept_id = @exLocName and o.voided = 0
set referral_transfer_location_in = o.value_text
where internal_external_in <> concept_name(@zlSite,@locale);

set @refWomensHealth = concept_from_mapping('PIH','13679');
update temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = @refWomensHealth and o.voided = 0
set	referred_by_womens_health_in =	
	 CASE o.value_coded
		WHEN @yesID then 1
		WHEN @noID then 0
	END;

set @pepfarSite = concept_from_mapping('PIH','13168');
update temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id =@pepfarSite and o.voided = 0
set referral_transfer_pepfar_partner_in =	
	 CASE o.value_coded
		WHEN @yesID then 1
		WHEN @noID then 0
	END;

-- transfers, referrals OUT:
set @tranOtherLoc = concept_from_mapping('PIH','13170');
UPDATE 	temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = @tranOtherLoc and o.voided = 0
set rt_out_obs_group_id = o.obs_id;

set @refTranOut = concept_from_mapping('PIH','13712');
UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_out_obs_group_id and o.concept_id = @refTranOut and o.voided = 0
set	referral_transfer_out = concept_name(o.value_coded,	@locale);

set @inExOut = concept_from_mapping('PIH','8854');
UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_out_obs_group_id and o.concept_id = @inExOut and o.voided = 0
set	internal_external_out = concept_name(o.value_coded,	@locale);

set @refTranLocOut = concept_from_mapping('PIH','8621');
UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_out_obs_group_id	and o.concept_id = @refTranLocOut and o.voided = 0
set referral_transfer_location_out = location_name(o.value_text)
where
	internal_external_out = concept_name(@zlSite,@locale);

set @exLocName = concept_from_mapping('PIH','11483');
UPDATE temp_hiv_visit t
inner join temp_obs o on o.obs_group_id = t.rt_out_obs_group_id and o.concept_id = @exLocName and o.voided = 0
set	referral_transfer_location_out = o.value_text
where
	internal_external_out <> concept_name(@zlSite,@locale);

update temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = @pepfarSite and o.voided = 0
set	referral_transfer_pepfar_partner_out =	
	 CASE o.value_coded
		WHEN @yesID then 1
		WHEN @noID then 0
	END;

set @eligART = concept_from_mapping('PIH','11337');
set @refTreat = concept_from_mapping('PIH','3580');
set @treatPostponed = concept_from_mapping('PIH','7262');
set @assignART = concept_from_mapping('PIH','2222');
set @denial = concept_from_mapping('PIH','14666');
UPDATE temp_hiv_visit t 
	inner join temp_obs tobs on tobs.encounter_id = t.encounter_id and concept_id = @eligART
	and tobs.value_coded in 
		(@refTreat,
		@treatPostponed,
		@assignART,
		@denial)
set reason_not_on_ARV = concept_name(tobs.value_coded,@locale);

set @feedPlan = concept_from_mapping('PIH','13642');
-- breastfeeding data
UPDATE 	temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = @feedPlan and o.voided = 0
set breastfeeding_status = concept_name(o.value_coded, @locale);

set @weanDate = concept_from_mapping('PIH','6889');
UPDATE 	temp_hiv_visit t
inner join temp_obs o on o.encounter_id = t.encounter_id and o.concept_id = @weanDate and o.voided = 0
set last_breastfeeding_date = o.value_datetime;

-- inh
drop temporary table if exists temp_hiv_inh;
create temporary table temp_hiv_inh(obs_group_id int, encounter_id int, inh_line varchar(50), inh_start_date date, inh_end_date date);
insert into temp_hiv_inh(obs_group_id, encounter_id)
select obs_group_id, encounter_id from obs o where voided = 0 and 
value_coded = concept_from_mapping('PIH','ISONIAZID')
and o.obs_group_id in
((select obs_id from obs where voided = 0 and concept_id in (
concept_from_mapping('PIH', 'PREVIOUS TREATMENT PROPHYLAXIS CONSTRUCT'),
concept_from_mapping('PIH', 'CURRENT PROPHYLAXIS TREATMENT CONSTRUCT'))
))
and encounter_id in (select encounter_id from temp_hiv_visit);


update temp_hiv_inh i set inh_line = (select concept_name(value_coded, @locale) from obs o where o.obs_group_id = i.obs_group_id and voided = 0 
and concept_id = concept_from_mapping('PIH', '13786'));
update temp_hiv_inh i join obs o on i.encounter_id = o.encounter_id and o.obs_group_id = i.obs_group_id and concept_id in (
concept_from_mapping('PIH', 'HISTORICAL DRUG START DATE'),
concept_from_mapping('PIH', '11131'))
set i.inh_start_date = date(value_datetime);

update temp_hiv_inh i set inh_line = (select concept_name(value_coded, @locale) from obs o where o.obs_group_id = i.obs_group_id and voided = 0 
and concept_id = concept_from_mapping('PIH', '13786'));
update temp_hiv_inh i join obs o on i.encounter_id = o.encounter_id and o.obs_group_id = i.obs_group_id and concept_id in (
concept_from_mapping('PIH', 'HISTORICAL DRUG STOP DATE'),
concept_from_mapping('PIH', '12748'))
set i.inh_end_date = date(value_datetime);

update temp_hiv_visit t  join temp_hiv_inh i on t.encounter_id = i.encounter_id
set t.inh_line = i.inh_line,
	t.inh_start_date = i.inh_start_date,
    t.inh_end_date = i.inh_end_date;
   
update temp_hiv_visit t
set sexually_active_with_men = if(obs_single_value_coded(t.encounter_id, 'PIH','11046','PIH','10870') is null,null,1);

update temp_hiv_visit t
set sexually_active_with_women = if(obs_single_value_coded(t.encounter_id, 'PIH','11046','PIH','10872') is null,null,1);

update temp_hiv_visit t
set intravenous_drug_use = if(obs_single_value_coded(t.encounter_id, 'PIH','11046','PIH','105') is null,null,1);

update temp_hiv_visit t
set blood_transfusion = if(obs_single_value_coded(t.encounter_id, 'PIH','11046','PIH','1063') is null,null,1);

update temp_hiv_visit t
set maternal_to_fetal_transmission = if(obs_single_value_coded(t.encounter_id, 'PIH','11046','PIH','11042') is null,null,1);

update temp_hiv_visit t
set accidental_exposure_to_blood = if(obs_single_value_coded(t.encounter_id, 'PIH','11046','PIH','11044') is null,null,1);

update temp_hiv_visit t
set sex_with_infected = if(obs_single_value_coded(t.encounter_id, 'PIH','11046','PIH','11060') is null,null,1);

update temp_hiv_visit t
set sex_with_drug_user = if(obs_single_value_coded(t.encounter_id, 'PIH','11046','PIH','11534') is null,null,1);

update temp_hiv_visit t
set heterosexual_sex_bisexual = if(obs_single_value_coded(t.encounter_id, 'PIH','11046','PIH','13001') is null,null,1);

update temp_hiv_visit t
set heterosexual_sex_blood_transfusion = if(obs_single_value_coded(t.encounter_id, 'PIH','11046','PIH','13000') is null,null,1);

update temp_hiv_visit t
set other_mode_of_transmission = if(obs_single_value_coded(t.encounter_id, 'PIH','11046','PIH','5622') is null,null,1);


update temp_hiv_visit t
set history_of_syphilis = obs_value_coded_as_boolean(t.encounter_id, 'PIH','11050');

update temp_hiv_visit t
set history_of_other_sti = obs_value_coded_as_boolean(t.encounter_id, 'PIH','11047');

update temp_hiv_visit t
set victim_of_gbv = obs_value_coded_as_boolean(t.encounter_id, 'PIH','11049');

update temp_hiv_visit t
set multiple_partners = obs_value_coded_as_boolean(t.encounter_id, 'PIH','5567');

update temp_hiv_visit t
set without_condom = obs_value_coded_as_boolean(t.encounter_id, 'PIH','11048');

update temp_hiv_visit t
set anal_sex = obs_value_coded_as_boolean(t.encounter_id, 'PIH','11051');

update temp_hiv_visit t
set with_sex_worker = obs_value_coded_as_boolean(t.encounter_id, 'CIEL','160580');

update temp_hiv_visit t
set other_risk_factor = if(obs_single_value_coded(t.encounter_id, 'PIH','11046','PIH','11406') is null,null,1);
   

/*
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
*/
SELECT
	concat(@partition, '-', encounter_id),
	concat(@partition, '-', visit_id),
	emr_id,
	hivemr_v1,
	encounter_type,
	date_entered,
	user_entered,
	chw,
	who_stage,
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
	breastfeeding_status,
	last_breastfeeding_date,
	inh_line,
	inh_start_date,
	inh_end_date,
	DATE(visit_date),
	next_visit_date,
	visit_location,
	sexually_active_with_men,
	sexually_active_with_women,
	intravenous_drug_use,
	blood_transfusion,
	maternal_to_fetal_transmission,
	accidental_exposure_to_blood,
	sex_with_infected,
	sex_with_drug_user,
	heterosexual_sex_bisexual,
	heterosexual_sex_blood_transfusion,
	other_mode_of_transmission,
	history_of_syphilis,
	history_of_other_sti,
	victim_of_gbv,
	multiple_partners,
	without_condom,
	anal_sex,
	with_sex_worker,
	other_risk_factor,
	index_asc,
	index_desc
FROM
	temp_hiv_visit t;
