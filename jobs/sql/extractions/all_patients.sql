set @partition = '${partitionNum}';
set @locale = 'en';

-- ---------------------------------------------------------------
-- 0. Resolve every lookup ONCE up front
-- ---------------------------------------------------------------
select person_attribute_type_id into @telephone        from person_attribute_type where name = 'Telephone Number';
select person_attribute_type_id into @motherName       from person_attribute_type where name = 'First Name of Mother';
select person_attribute_type_id into @healthCenterAttr from person_attribute_type where uuid = '8d87236c-c2cc-11de-8d13-0010c6dffd0f';
set @civilStatus = concept_from_mapping('PIH','1054');
set @occupation  = concept_from_mapping('PIH','1304');
set @patient_url = SUBSTRING_INDEX(global_property_value('host.url',null), "/", 3);

-- ---------------------------------------------------------------
-- 1. Main table (same column types as before)
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_patients;
CREATE TEMPORARY TABLE temp_patients
(
emr_id                            varchar(50),
hiv_emr_id                        varchar(50),
dossier_id                        varchar(50),
patient_id                        int primary key,
mothers_first_name                varchar(255),
country                           varchar(255),
registration_encounter_id         int(11),
department                        varchar(255),
commune                           varchar(255),
section_communale                 varchar(255),
locality                          varchar(255),
telephone_number                  varchar(255),
health_center                     varchar(255),
site                              varchar(255),
civil_status                      varchar(255),
occupation                        varchar(255),
reg_location                      varchar(50),
reg_location_id                   int(11),
registration_date                 date,
registration_entry_date           datetime,
creator                           int(11),
user_entered                      varchar(50),
first_encounter_date              date,
last_encounter_date               date,
name                              varchar(50),
family_name                       varchar(50),
dob                               date,
dob_estimated                     bit,
gender                            varchar(2),
dead                              bit,
death_date                        date,
cause_of_death_concept_id         int(11),
cause_of_death                    varchar(100),
last_modified_patient             datetime,
last_modified_datetime            datetime,
last_modified_person_datetime     datetime,
last_modified_name_datetime       datetime,
last_modified_address_datetime    datetime,
last_modified_attributes_datetime datetime,
last_modified_obs_datetime        datetime,
last_modified_registration_datetime datetime,
patient_uuid                      varchar(38),
patient_url                       text,
index temp_patients_pri (registration_encounter_id)
);

-- ONE pass over patients: person, preferred name, preferred address, and the
-- per-patient functions (identifiers, attributes, registration encounter).
-- Replaces 11 separate full-table UPDATEs.
insert into temp_patients
(patient_id, last_modified_patient,
 gender, dob, dob_estimated, dead, death_date, cause_of_death_concept_id, cause_of_death,
 last_modified_person_datetime, patient_uuid,
 name, family_name, last_modified_name_datetime,
 country, department, commune, section_communale, locality, last_modified_address_datetime,
 emr_id, hiv_emr_id, dossier_id,
 telephone_number, mothers_first_name,
 registration_encounter_id)
select
 pt.patient_id,
 COALESCE(pt.date_changed, pt.date_created),
 p.gender,
 p.birthdate,
 p.birthdate_estimated,
 p.dead,
 date(p.death_date),
 p.cause_of_death,
 case when p.cause_of_death is not null then concept_name(p.cause_of_death, @locale) end,
 COALESCE(p.date_changed, p.date_created),
 p.uuid,
 n.given_name,
 n.family_name,
 COALESCE(n.date_changed, n.date_created),
 a.country,
 a.state_province,
 a.city_village,
 a.address3,
 a.address1,
 COALESCE(a.date_changed, a.date_created),
 patient_identifier(pt.patient_id, 'a541af1e-105c-40bf-b345-ba1fd6a59b85'),
 patient_identifier(pt.patient_id, '139766e8-15f5-102d-96e4-000c29c2a5d7'),
 patient_identifier(pt.patient_id, 'e66645eb-03a8-4991-b4ce-e87318e37566'),
 person_attribute_value(pt.patient_id, 'Telephone Number'),
 person_attribute_value(pt.patient_id, 'First Name of Mother'),
 latestEnc(pt.patient_id, 'Enregistrement de patient', null)
from patient pt
left join person p on p.person_id = pt.patient_id
left join person_name n on n.person_name_id =
      (select n2.person_name_id from person_name n2
       where n2.person_id = pt.patient_id
       order by n2.preferred desc, n2.date_created desc limit 1)
left join person_address a on a.person_address_id =
      (select a2.person_address_id from person_address a2
       where a2.person_id = pt.patient_id
       order by a2.preferred desc, a2.date_created desc limit 1)
where pt.voided = 0;

-- ---------------------------------------------------------------
-- 2. Lookup tables, each keyed by a primary key
-- ---------------------------------------------------------------

-- user names (once per user)
drop temporary table if exists user_names;
create temporary table user_names
(user_id   int(11) primary key,
 user_name varchar(511));
insert into user_names
select user_id, person_name_of_user(user_id) from users;

-- location names (once per location, same location_name() function)
drop temporary table if exists temp_pt_location_names;
create temporary table temp_pt_location_names
(location_id   int(11) primary key,
 location_name varchar(255));
insert into temp_pt_location_names
select location_id, location_name(location_id) from location;

-- first / last encounter date: one grouped pass over encounter
-- (replaces two correlated subqueries per patient; voided encounters
--  are still counted, as before)
drop temporary table if exists temp_pt_enc_dates;
create temporary table temp_pt_enc_dates
(patient_id           int(11) primary key,
 first_encounter_date date,
 last_encounter_date  date);
insert into temp_pt_enc_dates
select patient_id, date(min(encounter_datetime)), date(max(encounter_datetime))
from encounter
group by patient_id;

-- last modified for telephone / mother's name attributes: one grouped pass
drop temporary table if exists temp_pt_attr_modified;
create temporary table temp_pt_attr_modified
(patient_id    int(11) primary key,
 last_modified datetime);
insert into temp_pt_attr_modified
select person_id, max(COALESCE(date_changed, date_created))
from person_attribute
where voided = 0
  and person_attribute_type_id in (@telephone, @motherName)
group by person_id;

-- health center attribute (a location reference), one row per patient.
-- If a patient has more than one, the most recent attribute wins.
drop temporary table if exists temp_pt_health_center;
create temporary table temp_pt_health_center
(patient_id    int(11) primary key,
 health_center varchar(255));
insert into temp_pt_health_center
select pa.person_id, l.name
from (select pa2.person_id, max(pa2.person_attribute_id) as person_attribute_id
      from person_attribute pa2
      inner join location l2 on l2.location_id = pa2.value
      where pa2.voided = 0
        and pa2.person_attribute_type_id = @healthCenterAttr
      group by pa2.person_id) m
inner join person_attribute pa on pa.person_attribute_id = m.person_attribute_id
inner join location l on l.location_id = pa.value;

-- registration obs, one row per registration encounter
drop temporary table if exists temp_obs_collated;
create temporary table temp_obs_collated
(encounter_id               int(11) primary key,
 civil_status               varchar(255),
 occupation                 varchar(255),
 last_modified_obs_datetime datetime);
insert into temp_obs_collated
select o.encounter_id,
       max(case when o.concept_id = @civilStatus then concept_name(o.value_coded, @locale) end),
       max(case when o.concept_id = @occupation  then concept_name(o.value_coded, @locale) end),
       max(o.date_created)
from temp_patients t
inner join obs o on o.encounter_id = t.registration_encounter_id
where o.voided = 0
group by o.encounter_id;

-- ---------------------------------------------------------------
-- 3. Fill in everything else in ONE update pass
-- ---------------------------------------------------------------
update temp_patients t
left join encounter e                 on e.encounter_id  = t.registration_encounter_id
left join user_names u                on u.user_id       = e.creator
left join temp_pt_location_names ln   on ln.location_id  = e.location_id
left join temp_obs_collated o         on o.encounter_id  = t.registration_encounter_id
left join temp_pt_enc_dates d         on d.patient_id    = t.patient_id
left join temp_pt_attr_modified am    on am.patient_id   = t.patient_id
left join temp_pt_health_center hc    on hc.patient_id   = t.patient_id
set t.reg_location_id                     = e.location_id,
    t.reg_location                        = ln.location_name,
    t.registration_entry_date             = e.date_created,
    t.registration_date                   = date(e.encounter_datetime),
    t.creator                             = e.creator,
    t.user_entered                        = u.user_name,
    t.last_modified_registration_datetime = e.date_changed,
    t.civil_status                        = o.civil_status,
    t.occupation                          = o.occupation,
    t.last_modified_obs_datetime          = o.last_modified_obs_datetime,
    t.first_encounter_date                = d.first_encounter_date,
    t.last_encounter_date                 = d.last_encounter_date,
    t.last_modified_attributes_datetime   = am.last_modified,
    -- health_center (and site for backwards compatibility)
    t.health_center                       = hc.health_center,
    t.site                                = hc.health_center,
    t.patient_url                         = @patient_url;

-- set last modified datetime to most recent of all the changes
-- (separate statement so it sees the values set above)
update temp_patients t set last_modified_datetime =
	greatest(ifnull(last_modified_person_datetime,last_modified_patient),
			ifnull(last_modified_name_datetime,last_modified_patient),
			ifnull(last_modified_address_datetime,last_modified_patient),
			ifnull(last_modified_attributes_datetime,last_modified_patient),
			ifnull(last_modified_obs_datetime,last_modified_patient),
			ifnull(last_modified_registration_datetime,last_modified_patient),
			last_modified_patient);

-- ---------------------------------------------------------------
-- 4. Final output 
-- ---------------------------------------------------------------
SELECT
emr_id,
hiv_emr_id,
dossier_id,
concat(@partition,"-",patient_id) patient_id,
mothers_first_name,
country,
department,
commune,
section_communale,
locality,
telephone_number,
civil_status,
occupation,
reg_location,
registration_date,
registration_entry_date,
user_entered,
first_encounter_date,
last_encounter_date,
name,
family_name,
dob,
dob_estimated,
gender,
dead,
death_date,
cause_of_death,
last_modified_datetime,
patient_uuid,
patient_url,
health_center,
site
FROM temp_patients;
