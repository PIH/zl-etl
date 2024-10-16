set @partition = '${partitionNum}';
SELECT encounter_type_id into @HIV_dispensing from encounter_type where uuid = 'cc1720c9-3e4c-4fa8-a7ec-40eeaad1958c';

drop temporary table if exists temp_HIV_dispensing;
create temporary table temp_HIV_dispensing
(
patient_id int(11),
encounter_id int(11),
visit_id int(11),
dispense_date datetime,
encounter_location_id  int(11),
date_entered DATETIME,
user_entered VARCHAR(50),
dispense_site  varchar(255),
age_at_dispense_date int,
dispense_date_ascending int,
dispense_date_descending int,
dispensed_to  varchar(100),
dispensed_accompagnateur text,
current_art_treatment_line  varchar(255),
current_art_line_start_date datetime,
months_dispensed int,
is_current_mmd char(1),
next_dispense_date datetime,
arv_1_med varchar(255),
arv_1_med_short_name varchar(255),
arv_1_quantity int,
arv_2_med varchar(255),
arv_2_med_short_name varchar(255),
arv_2_quantity int,
arv_3_med varchar(255),
arv_3_med_short_name varchar(255),
arv_3_quantity int,
tms_1_med varchar(255),
tms_1_med_short_name varchar(255),
tms_1_quantity int,
inh_1_obs_group_id int(11),
inh_1_med varchar(255),
inh_1_med_short_name varchar(255),
inh_1_sequence	varchar(255),
inh_1_quantity int,
inh_2_obs_group_id int(11),
inh_2_med varchar(255),
inh_2_med_short_name varchar(255),
inh_2_sequence	varchar(255),
inh_2_quantity int,
b6_med varchar(255),
b6_med_short_name varchar(255),
b6_quantity int,
regimen_change char(1),
days_late_to_pickup int,
regimen_match char(1)
 );

 create index temp_HIV_dispensing_patient_index on temp_HIV_dispensing (patient_id);
 create index temp_HIV_dispensing_dispense_date on temp_HIV_dispensing (dispense_date);
 create index temp_HIV_dispensing_encounter_id on temp_HIV_dispensing (encounter_id);

 insert into temp_HIV_dispensing (patient_id, encounter_id, visit_id, dispense_date, date_entered, user_entered, encounter_location_id)
 select patient_id, encounter_id, visit_id, encounter_datetime, date_created, username(creator), e.location_id  from encounter e
 where encounter_type = @HIV_dispensing and voided = 0;

DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs 
select o.obs_id, o.voided ,o.obs_group_id , o.encounter_id, o.person_id, o.concept_id, o.value_coded, o.value_numeric, o.value_text,o.value_datetime, o.value_coded_name_id ,o.comments,o.date_created, o.value_drug, o.obs_datetime  
from obs o
inner join temp_HIV_dispensing t on t.encounter_id = o.encounter_id 
where o.voided = 0
;
-- create index temp_obs_concept_id on temp_obs(concept_id);
create index temp_obs_oi on temp_obs(obs_id);
create index temp_obs_ci1 on temp_obs(encounter_id, concept_id);
create index temp_obs_ci2 on temp_obs(obs_group_id, concept_id);

update temp_HIV_dispensing t
set dispense_site = location_name(encounter_location_id);

update temp_HIV_dispensing t
inner join person p on p.person_id = t.patient_id
set age_at_dispense_date = TIMESTAMPDIFF(YEAR, birthdate, dispense_date) ;

-- The ascending/descending indexes are calculated ordering on the dispense date
-- new temp tables are used to build them and then joined into the main temp table.
### index ascending
drop temporary table if exists temp_dispensing_index_asc;
CREATE TEMPORARY TABLE temp_dispensing_index_asc
(
    SELECT
            patient_id,
            dispense_date,
            encounter_id,
            index_asc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_asc,
            dispense_date,
            encounter_id,
            patient_id,
            @u:= patient_id
      FROM temp_HIV_dispensing,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id, dispense_date ASC, encounter_id ASC
        ) index_ascending );

update temp_HIV_dispensing t
inner join temp_dispensing_index_asc tdia on tdia.encounter_id = t.encounter_id
set dispense_date_ascending = tdia.index_asc;

drop temporary table if exists temp_dispensing_index_desc;
CREATE TEMPORARY TABLE temp_dispensing_index_desc
(
    SELECT
            patient_id,
            dispense_date,
            encounter_id,
            index_desc
FROM (SELECT
            @r:= IF(@u = patient_id, @r + 1,1) index_desc,
            dispense_date,
            encounter_id,
            patient_id,
            @u:= patient_id
      FROM temp_HIV_dispensing,
                    (SELECT @r:= 1) AS r,
                    (SELECT @u:= 0) AS u
            ORDER BY patient_id, dispense_date DESC, encounter_id DESC
        ) index_descending );

update temp_HIV_dispensing t
inner join temp_dispensing_index_desc tdid on tdid.encounter_id = t.encounter_id
set dispense_date_descending = tdid.index_desc;

update temp_HIV_dispensing t
inner join temp_obs o on o.encounter_id = t.encounter_id 
and o.concept_id =concept_from_mapping('PIH',12071)
set t.dispensed_to = concept_name(o.value_coded,'en');

update temp_HIV_dispensing t
inner join temp_obs o on o.encounter_id = t.encounter_id 
and o.concept_id =concept_from_mapping('PIH','13276')
set t.dispensed_accompagnateur = value_text;

update temp_HIV_dispensing t
inner join temp_obs o on o.encounter_id = t.encounter_id
and o.concept_id =concept_from_mapping('CIEL',166073)
set t.current_art_treatment_line = concept_name(o.value_coded,'en');

update temp_HIV_dispensing t
inner join temp_obs o on o.encounter_id = t.encounter_id
and o.concept_id =concept_from_mapping('CIEL',5096)
set t.next_dispense_date = value_datetime;

update temp_HIV_dispensing t
inner join temp_obs o on o.encounter_id = t.encounter_id
and o.concept_id =concept_from_mapping('PIH',3102)
set t.months_dispensed = value_numeric;

update temp_HIV_dispensing
set is_current_mmd = if(months_dispensed >= 3, 'Y','N');

update temp_HIV_dispensing t
inner join temp_obs o on o.encounter_id = t.encounter_id
and o.concept_id =concept_from_mapping('PIH',3277)
set t.regimen_match = if(concept_name(o.value_coded,'en') = 'Yes',1,0);

-- to calculate the art line start date, a new temp table is created to keep track of the start date of the line
-- the results are then joined in with the main temp table
drop temporary table if exists temp_dispensing_line_start;
CREATE TEMPORARY TABLE temp_dispensing_line_start
SELECT
            @ts:= IF(@u = patient_id and @tl = current_art_treatment_line ,@ts,@ts:=dispense_date) treatment_start_date,
            dispense_date,
            encounter_id,
            patient_id,
            current_art_treatment_line,
            @u:= patient_id,
            @tl:=current_art_treatment_line
      FROM temp_HIV_dispensing,
                    (SELECT @ts:= '1900-01-01') AS ts,
                    (SELECT @u:= 0) AS u,
                    (SELECT @tl:='1900-01-01') as tl
            ORDER BY patient_id, dispense_date ASC, encounter_id ASC; -- add indexes?

create index temp_dispensing_line_start_encounter_id on temp_dispensing_line_start (encounter_id);

update temp_HIV_dispensing t
inner join temp_dispensing_line_start ts on ts.encounter_id = t.encounter_id
set t.current_art_line_start_date = ts.treatment_start_date;

DROP TEMPORARY TABLE IF EXISTS temp_obs2;
create temporary table temp_obs2 
select * from temp_obs o;

create index temp_obs2_ci1 on temp_obs2(encounter_id, value_coded);
create index temp_obs2_ci2 on temp_obs2(encounter_id, concept_id, value_coded);

-- ARV#1 med and quantity
update temp_HIV_dispensing t
inner join temp_obs2 og on og.encounter_id = t.encounter_id
  and og.value_coded =concept_from_mapping('PIH',3013)
inner join temp_obs o on o.obs_group_id = og.obs_group_id
  and  o.concept_id =concept_from_mapping('CIEL',1282)
set arv_1_med_short_name = concept_name(o.value_coded,'en'),
    arv_1_med = drugName(o.value_drug);

update temp_HIV_dispensing t
inner join temp_obs2 og on og.encounter_id = t.encounter_id
  and og.value_coded =concept_from_mapping('PIH',3013)
inner join temp_obs o on o.obs_group_id = og.obs_group_id
  and  o.concept_id =concept_from_mapping('CIEL',1443)
set arv_1_quantity = o.value_numeric;

-- ARV#2 med and quantity
update temp_HIV_dispensing t
inner join temp_obs2 og on og.encounter_id = t.encounter_id
  and og.value_coded =concept_from_mapping('PIH',2848)
inner join temp_obs o on o.obs_group_id = og.obs_group_id
  and  o.concept_id =concept_from_mapping('CIEL',1282)
set arv_2_med_short_name = concept_name(o.value_coded,'en'),
    arv_2_med = drugName(o.value_drug);

update temp_HIV_dispensing t
inner join temp_obs2 og on og.encounter_id = t.encounter_id
  and og.value_coded =concept_from_mapping('PIH',2848)
inner join temp_obs o on o.obs_group_id = og.obs_group_id
  and  o.concept_id =concept_from_mapping('CIEL',1443)
set arv_2_quantity = o.value_numeric;

-- ARV#3 med and quantity
update temp_HIV_dispensing t
inner join temp_obs2 og on og.encounter_id = t.encounter_id
  and og.value_coded =concept_from_mapping('PIH',13960)
inner join temp_obs o on o.obs_group_id = og.obs_group_id
  and  o.concept_id =concept_from_mapping('CIEL',1282)
set arv_3_med_short_name = concept_name(o.value_coded,'en'),
    arv_3_med = drugName(o.value_drug);

update temp_HIV_dispensing t
inner join temp_obs2 og on og.encounter_id = t.encounter_id
  and og.value_coded =concept_from_mapping('PIH',13960)
inner join temp_obs o on o.obs_group_id = og.obs_group_id
  and  o.concept_id =concept_from_mapping('CIEL',1443)
set arv_3_quantity = o.value_numeric;

-- ARV#3 med and quantity
update temp_HIV_dispensing t
inner join temp_obs2 og on og.encounter_id = t.encounter_id
  and og.value_coded =concept_from_mapping('PIH',766)
inner join temp_obs o on o.obs_group_id = og.obs_group_id
  and  o.concept_id =concept_from_mapping('CIEL',1282)
set b6_med_short_name = concept_name(o.value_coded,'en'),
    b6_med = drugName(o.value_drug);

update temp_HIV_dispensing t
inner join temp_obs2 og on og.encounter_id = t.encounter_id
  and og.value_coded =concept_from_mapping('PIH',766)
inner join temp_obs o on o.obs_group_id = og.obs_group_id
  and  o.concept_id =concept_from_mapping('CIEL',1443)
set b6_quantity = o.value_numeric;

-- TMS med and quantity
update temp_HIV_dispensing t
inner join temp_obs2 og on og.encounter_id = t.encounter_id
  and og.value_coded =concept_from_mapping('PIH',3120)
inner join temp_obs o ON o.obs_group_id = og.obs_group_id
  and  o.concept_id =concept_from_mapping('CIEL',1282)
set tms_1_med_short_name = concept_name(o.value_coded,'en'),
    tms_1_med = drugName(o.value_drug);

update temp_HIV_dispensing t
inner join temp_obs2 og on og.encounter_id = t.encounter_id
  and og.value_coded =concept_from_mapping('PIH',3120)
inner join temp_obs o on o.obs_group_id = og.obs_group_id
  and  o.concept_id =concept_from_mapping('CIEL',1443)
set tms_1_quantity = o.value_numeric;

-- INH 1
update temp_HIV_dispensing t
inner join temp_obs o on obs_id = 
	(select obs_id from temp_obs2 o2
	where o2.encounter_id = t.encounter_id 
	and o2.concept_id  = concept_from_mapping('PIH','1535')
	and o2.value_coded = concept_from_mapping('PIH','656')
	order by o2.obs_datetime asc, o2.obs_id asc 
	limit 1 offset 0)
set t.inh_1_obs_group_id = o.obs_group_id ;
	
update temp_HIV_dispensing t
inner join temp_obs o on o.obs_group_id = t.inh_1_obs_group_id
	and o.concept_id =concept_from_mapping('CIEL',1282)
set inh_1_med_short_name = concept_name(o.value_coded,'en'),
    inh_1_med = drugName(o.value_drug);

update temp_HIV_dispensing t
inner join temp_obs o on o.obs_group_id = t.inh_1_obs_group_id
	and o.concept_id =concept_from_mapping('CIEL',1443)
set inh_1_quantity = o.value_numeric ;

update temp_HIV_dispensing t
inner join temp_obs o on o.obs_group_id = t.inh_1_obs_group_id
	and o.concept_id =concept_from_mapping('PIH','13786')
set inh_1_sequence = concept_name(o.value_coded,@locale) ;

-- INH 2
update temp_HIV_dispensing t
inner join temp_obs o on obs_id = 
	(select obs_id from temp_obs2 o2
	where o2.encounter_id = t.encounter_id 
	and o2.concept_id  = concept_from_mapping('PIH','1535')
	and o2.value_coded = concept_from_mapping('PIH','656')
	order by o2.obs_datetime asc, o2.obs_id asc 
	limit 1 offset 1)
set t.inh_2_obs_group_id = o.obs_group_id ;
	
update temp_HIV_dispensing t
inner join temp_obs o on o.obs_group_id = t.inh_2_obs_group_id
	and o.concept_id =concept_from_mapping('CIEL',1282)
set inh_2_med_short_name = concept_name(o.value_coded,'en'),
    inh_2_med = drugName(o.value_drug);

update temp_HIV_dispensing t
inner join temp_obs o on o.obs_group_id = t.inh_2_obs_group_id
	and o.concept_id =concept_from_mapping('CIEL',1443)
set inh_2_quantity = o.value_numeric ;

update temp_HIV_dispensing t
inner join temp_obs o on o.obs_group_id = t.inh_2_obs_group_id
	and o.concept_id =concept_from_mapping('PIH','13786')
set inh_2_sequence = concept_name(o.value_coded,@locale) ;


-- to calculate the days late and regimen change (whether the current regimen changed since the first one),
-- the temp table is duplicated since MYSQL does not allow joining in the table that is being updated.
drop temporary table if exists dup_HIV_dispensing;
CREATE TEMPORARY TABLE dup_HIV_dispensing SELECT * FROM temp_HIV_dispensing;

 create index dup_HIV_dispensing_patient_index on dup_HIV_dispensing (patient_id);
 create index dup_HIV_dispensing_dispense_date on dup_HIV_dispensing (dispense_date);
 create index dup_HIV_dispensing_encounter_id on dup_HIV_dispensing (encounter_id);


update temp_HIV_dispensing t
left outer join dup_HIV_dispensing d on d.patient_id=t.patient_id and d.dispense_date_ascending = 1
set t.regimen_change = if(d.arv_1_med_short_name = t.arv_1_med_short_name,0,1)  -- need to change this to FULL NAME when drugs are captured?
where t.dispense_date_descending = 1;

update temp_HIV_dispensing t
left outer join dup_HIV_dispensing d on d.patient_id=t.patient_id and d.dispense_date_descending = 2
set t.days_late_to_pickup = if(t.dispense_date>d.next_dispense_date,datediff(t.dispense_date,d.next_dispense_date),0)
where t.dispense_date_descending = 1;

# final query
Select
zlemr(t.patient_id),
concat(@partition,'-',t.encounter_id),
concat(@partition,'-',t.visit_id),
t.dispense_date,
t.dispense_site,
t.date_entered,
t.user_entered,
t.age_at_dispense_date,
t.dispensed_to,
t.dispensed_accompagnateur,
t.current_art_treatment_line,
t.current_art_line_start_date,
t.months_dispensed,
t.is_current_mmd,
t.next_dispense_date,
t.arv_1_med_short_name,
t.arv_1_med,
t.arv_1_quantity,
t.arv_2_med_short_name,
t.arv_2_med,
t.arv_2_quantity,
t.arv_3_med_short_name,
t.arv_3_med,
t.arv_3_quantity,
t.tms_1_med_short_name,
t.tms_1_med,
t.tms_1_quantity,
t.inh_1_med,
t.inh_1_med_short_name,
t.inh_1_sequence,
t.inh_1_quantity,
t.inh_2_med,
t.inh_2_med_short_name,
t.inh_2_sequence,
t.inh_2_quantity,
t.b6_med_short_name,
t.b6_med,
t.b6_quantity,
t.regimen_change,
t.days_late_to_pickup,
t.regimen_match,
dispense_date_ascending,
dispense_date_descending
from temp_HIV_dispensing t
order by patient_id, dispense_date asc, encounter_id asc;
