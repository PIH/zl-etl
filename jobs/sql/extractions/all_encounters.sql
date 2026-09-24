SET @partition = '${partitionNum}';
set sql_safe_updates = 0;
set @next_appt_date_concept_id = CONCEPT_FROM_MAPPING('PIH', 5096);
set @disposition_concept_id    = CONCEPT_FROM_MAPPING('PIH', 8620);

-- ---------------------------------------------------------------
-- 1. Build the small lookup tables FIRST (each keyed by a primary key)
-- ---------------------------------------------------------------

-- user names (~1k rows)
drop temporary table if exists user_names;
create temporary table user_names
(
    user_id   int(11) primary key,
    user_name varchar(511)
);
insert into user_names(user_id, user_name)
select user_id, person_name_of_user(user_id)
from users;

-- next appointment + disposition, one row per encounter (~1.3M rows)
-- (goes straight from obs; the intermediate temp_obs table isn't needed)
drop temporary table if exists temp_obs_collated;
create temporary table temp_obs_collated
(
    encounter_id   int(11) primary key,
    next_appt_date datetime,
    disposition    varchar(255)
);
insert into temp_obs_collated(encounter_id, next_appt_date, disposition)
select encounter_id,
       max(case when concept_id = @next_appt_date_concept_id then value_datetime end),
       max(case when concept_id = @disposition_concept_id then concept_name(value_coded, @locale) end)
from obs
where concept_id in (@next_appt_date_concept_id, @disposition_concept_id)
  and voided = 0
group by encounter_id;

-- EMR ids, one row per patient (~59k rows) -- the function runs once per patient
drop temporary table if exists temp_emrids;
create temporary table temp_emrids
(
    patient_id int(11) primary key,
    emr_id     varchar(50)
);
insert into temp_emrids(patient_id, emr_id)
select p.patient_id, patient_identifier(p.patient_id, 'ZL EMR ID')
from (select distinct patient_id from encounter where voided = 0) p;

-- other modifiers: users (other than the encounter creator) who created obs
-- on the encounter, and the dates they did it
-- (a) usernames looked up once per user (~1k calls) instead of once per obs row
drop temporary table if exists temp_user_logins;
create temporary table temp_user_logins	
(
    user_id  int(11) primary key,
    username varchar(255)
);
insert into temp_user_logins(user_id, username)
select user_id, username(user_id)
from users;

-- (b) collapse obs down to distinct (encounter, creator, date) first
--     joins to encounter directly, so it doesn't depend on temp_all_encounters
--     straight_join forces obs to be the driving table (sequential scan of obs,
--     cheap primary-key lookups into encounter)
drop temporary table if exists temp_obs_modifiers;
create temporary table temp_obs_modifiers
(
    encounter_id  int(11),
    creator       int(11),
    date_modified date,
    index temp_obs_modifiers_ei (encounter_id)
);
insert into temp_obs_modifiers(encounter_id, creator, date_modified)
select distinct o.encounter_id, o.creator, date(o.date_created)
from obs o
straight_join encounter e on e.encounter_id = o.encounter_id
where e.voided = 0
  and o.creator <> e.creator
  -- and o.voided = 0   -- optional: uncomment to ignore voided obs (fewer rows, faster)
;

-- (c) one row per encounter
-- optional: raise the 1024-char default if long lists are getting cut off
-- set session group_concat_max_len = 10000;
drop temporary table if exists temp_other_modifiers;
create temporary table temp_other_modifiers
(
    encounter_id   int(11) primary key,
    users_modified text,
    dates_modified text
);
insert into temp_other_modifiers(encounter_id, users_modified, dates_modified)
select m.encounter_id,
       group_concat(distinct ul.username order by ul.username separator ', '),
       group_concat(distinct m.date_modified order by m.date_modified separator ', ')
from temp_obs_modifiers m
left join temp_user_logins ul on ul.user_id = m.creator
group by m.encounter_id;

-- ---------------------------------------------------------------
-- 2. Build the big table in ONE pass (replaces 7 full-table UPDATEs
--    and 6 secondary indexes on the 3.5M-row temp table)
-- ---------------------------------------------------------------
drop temporary table if exists temp_all_encounters;
create temporary table temp_all_encounters
(
    encounter_id        int(11) primary key,
    encounter_datetime  datetime,
    patient_id          int(11),
    visit_id            int(11),
    visit_location      varchar(255),
    creator             int(11),
    user_entered        varchar(255),
    location_id         int(11),
    encounter_location  varchar(255),
    site                varchar(255),
    encounter_type_id   int(11),
    encounter_type_name varchar(50),
    entered_datetime    datetime,
    emr_id              varchar(50),
    next_appt_date      date,
    disposition         varchar(255),
    voided              bit,
    users_modified      text,
    dates_modified      text,
    index_asc           int(11),
    index_desc          int(11)
);

insert into temp_all_encounters
(
    encounter_id, encounter_datetime, patient_id, visit_id, visit_location,
    creator, user_entered, location_id, encounter_location, site,
    encounter_type_id, encounter_type_name, entered_datetime, emr_id,
    next_appt_date, disposition, voided, users_modified, dates_modified
)
select e.encounter_id,
       e.encounter_datetime,
       e.patient_id,
       e.visit_id,
       vl.location_name,                          -- visit_location
       e.creator,
       u.user_name,                               -- user_entered
       e.location_id,
       el.location_name,                          -- encounter_location
       -- site: visit's location when there is one, otherwise the
       -- Visit Location ancestor of the encounter location (same as before)
       coalesce(vl.location_name, el.site),
       e.encounter_type,
       et.name,                                   -- encounter_type_name
       e.date_created,
       em.emr_id,
       o.next_appt_date,
       o.disposition,
       e.voided,
       om.users_modified,
       om.dates_modified
from encounter e
left join encounter_type    et on et.encounter_type_id = e.encounter_type
left join locations         el on el.location_id       = e.location_id
left join visit             v  on v.visit_id           = e.visit_id
left join locations         vl on vl.location_id       = v.location_id
left join user_names        u  on u.user_id            = e.creator
left join temp_obs_collated o  on o.encounter_id       = e.encounter_id
left join temp_emrids       em on em.patient_id        = e.patient_id
left join temp_other_modifiers om on om.encounter_id   = e.encounter_id
where e.voided = 0;

-- ---------------------------------------------------------------
-- 3. Final query (unchanged output columns)
-- ---------------------------------------------------------------
select emr_id,
       CONCAT(@partition, '-', encounter_id) as encounter_id,
       CONCAT(@partition, '-', patient_id)   as patient_id,
       CONCAT(@partition, '-', visit_id)     as visit_id,
       visit_location,
       encounter_type_name,
       encounter_location,
       site,
       encounter_datetime,
       entered_datetime,
       user_entered,
       next_appt_date,
       disposition,
       users_modified,
       dates_modified,
       index_asc,
       index_desc
from temp_all_encounters t
ORDER BY t.patient_id, t.encounter_id;
