set @partition = '${partitionNum}';
select et.encounter_type_id into @chemo_form from encounter_type et where uuid = '828964fa-17eb-446e-aba4-e940b0f4be5b';

drop temporary table if exists chemo_regimens;
create temporary table chemo_regimens
(emr_id varchar(25),
obs_id int(11),
encounter_id int(11),
patient_id int(11),
chemo_regimen_id int(11),
chemo_regimen_name varchar(255),
other_regimen text
);

set @chemo_regimen_id = concept_from_mapping('PIH','10506');

insert into chemo_regimens(obs_id, encounter_id, patient_id,chemo_regimen_id)
select o.obs_id, o.encounter_id,person_id, value_coded from obs o
inner join encounter e on e.encounter_id = o.encounter_id and e.encounter_type  = @chemo_form
where o.voided = 0
and o.concept_id = @chemo_regimen_id
;

create index chemo_regimens_oi on chemo_regimens(obs_id);

-- emr_id
drop temporary table if exists temp_emrids;
create temporary table temp_emrids
(
    patient_id int(11),
    emr_id     varchar(50)
);

insert into temp_emrids(patient_id)
select DISTINCT patient_id
from chemo_regimens
;
create index temp_emrids_patient_id on temp_emrids (patient_id);

update temp_emrids t
set emr_id = patient_identifier(patient_id, 'ZL EMR ID');

update chemo_regimens t
set t.emr_id = zlemrid_from_temp(t.patient_id);

-- regimens
update chemo_regimens 
set chemo_regimen_name = concept_name(chemo_regimen_id, 'en');

update chemo_regimens
set other_regimen = obs_comments(encounter_id, 'PIH','10506','PIH','5622');

select 
emr_id,
concat(@partition, '-', obs_id),
concat(@partition, '-', encounter_id),
chemo_regimen_name
from chemo_regimens;
