SET @locale = 'en';
SET @partition = '${partitionNum}';

-- ---------------------------------------------------------------
-- 0. Resolve every concept / metadata lookup ONCE up front.
--    (Calling concept_from_mapping() inside a WHERE clause or an UPDATE
--    can make MySQL evaluate it for every row and skip the concept_id index.)
-- ---------------------------------------------------------------
set @coded_dx_concept     = concept_from_mapping('PIH','3064');
set @noncoded_dx_concept  = concept_from_mapping('PIH','Diagnosis or problem, non-coded');
set @dx_order             = concept_from_mapping('PIH','7537');
set @certainty            = concept_from_mapping('PIH','1379');
set @set_weekly_notifiable = concept_from_mapping('PIH','7676');
set @set_santeFamn        = concept_from_mapping('PIH','7957');
set @set_urgent           = concept_from_mapping('PIH','7679');
set @set_psychological    = concept_from_mapping('PIH','7942');
set @set_pediatric        = concept_from_mapping('PIH','7933');
set @set_outpatient       = concept_from_mapping('PIH','7936');
set @set_ncd              = concept_from_mapping('PIH','7935');
set @set_ed               = concept_from_mapping('PIH','7934');
set @set_age_restricted   = concept_from_mapping('PIH','7677');
set @set_oncology         = concept_from_mapping('PIH','8934');
select concept_id into @non_diagnoses from concept where uuid = 'a2d2124b-fc2e-4aa2-ac87-792d4205dd8d';
set @primary_id_type      = metadata_uuid('org.openmrs.module.emrapi', 'emr.primaryIdentifierType');

-- date window: same meaning as date(obs_datetime) between @startDate and @endDate,
-- but written so the obs_datetime column isn't wrapped in a function
-- (assumes @startDate / @endDate are plain dates, as before)
set @startDateTime = @startDate;
set @endDateExcl   = date_add(@endDate, interval 1 day);

-- ---------------------------------------------------------------
-- 1. Base rows: one per diagnosis obs (narrow table)
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_dx_obs;
CREATE TEMPORARY TABLE temp_dx_obs
(
 obs_id             int(11) primary key,
 patient_id         int(11),
 encounter_id       int(11),
 obs_group_id       int(11),
 obs_datetime       datetime,
 date_created       datetime,
 diagnosis_concept  int(11),
 diagnosis_entered  text,
 coded              varchar(255)
);

-- coded diagnoses
insert into temp_dx_obs (obs_id, patient_id, encounter_id, obs_group_id, obs_datetime, date_created, diagnosis_concept, coded)
select o.obs_id, o.person_id, o.encounter_id, o.obs_group_id, o.obs_datetime, o.date_created, o.value_coded, 1
from obs o
where o.concept_id = @coded_dx_concept
  and o.voided = 0
  and (@startDateTime is null or o.obs_datetime >= @startDateTime)
  and (@endDateExcl   is null or o.obs_datetime <  @endDateExcl);

-- non-coded diagnoses (obs_group_id intentionally left NULL, as in the original,
-- so these rows get no dx_order / certainty)
insert into temp_dx_obs (obs_id, patient_id, encounter_id, obs_datetime, date_created, diagnosis_entered, coded)
select o.obs_id, o.person_id, o.encounter_id, o.obs_datetime, o.date_created, o.value_text, 0
from obs o
where o.concept_id = @noncoded_dx_concept
  and o.voided = 0
  and (@startDateTime is null or o.obs_datetime >= @startDateTime)
  and (@endDateExcl   is null or o.obs_datetime <  @endDateExcl);

-- ---------------------------------------------------------------
-- 2. Lookup tables, each keyed by a primary key
-- ---------------------------------------------------------------

-- dx order + certainty, one row per obs group (coded dxs only)
-- replaces the temp_obs table, whose OR join couldn't use an index
DROP TEMPORARY TABLE IF EXISTS temp_dx_group;
CREATE TEMPORARY TABLE temp_dx_group
(
 obs_group_id int(11) primary key,
 dx_order     varchar(255),
 certainty    varchar(255)
);
insert into temp_dx_group (obs_group_id, dx_order, certainty)
select o.obs_group_id,
       max(case when o.concept_id = @dx_order  then concept_name(o.value_coded, @locale) end),
       max(case when o.concept_id = @certainty then concept_name(o.value_coded, @locale) end)
from (select distinct obs_group_id from temp_dx_obs where obs_group_id is not null) g
inner join obs o on o.obs_group_id = g.obs_group_id
where o.concept_id in (@dx_order, @certainty)
  and o.voided = 0
group by o.obs_group_id;

-- first diagnosis: earliest date per (patient, concept) across the patient's
-- WHOLE history of coded dxs (not just the @startDate-@endDate window).
-- A row is "first" when its date equals that earliest date.
DROP TEMPORARY TABLE IF EXISTS temp_dx_first;
CREATE TEMPORARY TABLE temp_dx_first
(
 patient_id        int(11),
 diagnosis_concept int(11),
 first_date        date,
 primary key (patient_id, diagnosis_concept)
);
insert into temp_dx_first (patient_id, diagnosis_concept, first_date)
select o.person_id, o.value_coded, min(date(o.obs_datetime))
from (select distinct patient_id, diagnosis_concept
      from temp_dx_obs
      where coded = '1'
        and diagnosis_concept is not null) pc
inner join obs o on o.person_id   = pc.patient_id
                and o.value_coded = pc.diagnosis_concept
where o.concept_id = @coded_dx_concept
  and o.voided = 0
group by o.person_id, o.value_coded;

-- concept-level info: names, ICD10 and set membership, once per distinct concept
DROP TEMPORARY TABLE IF EXISTS temp_dx_concept;
CREATE TEMPORARY TABLE temp_dx_concept
(
 diagnosis_concept  int(11) primary key,
 diagnosis_coded_fr varchar(255),
 diagnosis_coded_en varchar(255),
 icd10_code         varchar(255),
 weekly_notifiable  int(1),
 urgent             int(1),
 santeFamn          int(1),
 psychological      int(1),
 pediatric          int(1),
 outpatient         int(1),
 ncd                int(1),
 non_diagnosis      int(1),
 ed                 int(1),
 age_restricted     int(1),
 oncology           int(1)
);
insert into temp_dx_concept
select c.diagnosis_concept,
       concept_name(c.diagnosis_concept, 'fr'),
       concept_name(c.diagnosis_concept, 'en'),
       retrieveICD10(c.diagnosis_concept),
       concept_in_set(c.diagnosis_concept, @set_weekly_notifiable),
       concept_in_set(c.diagnosis_concept, @set_urgent),
       concept_in_set(c.diagnosis_concept, @set_santeFamn),
       concept_in_set(c.diagnosis_concept, @set_psychological),
       concept_in_set(c.diagnosis_concept, @set_pediatric),
       concept_in_set(c.diagnosis_concept, @set_outpatient),
       concept_in_set(c.diagnosis_concept, @set_ncd),
       concept_in_set(c.diagnosis_concept, @non_diagnoses),
       concept_in_set(c.diagnosis_concept, @set_ed),
       concept_in_set(c.diagnosis_concept, @set_age_restricted),
       concept_in_set(c.diagnosis_concept, @set_oncology)
from (select distinct diagnosis_concept from temp_dx_obs where diagnosis_concept is not null) c;

-- patient-level info, once per distinct patient
DROP TEMPORARY TABLE IF EXISTS temp_dx_patient;
CREATE TEMPORARY TABLE temp_dx_patient
(
 patient_id               int(11) primary key,
 dossierId                varchar(50),
 patient_primary_id       varchar(50),
 loc_registered           varchar(255),
 unknown_patient          varchar(50),
 gender                   varchar(50),
 department               varchar(255),
 commune                  varchar(255),
 section                  varchar(255),
 locality                 varchar(255),
 street_landmark          varchar(255),
 birthdate                datetime,
 birthdate_estimated      boolean,
 section_communale_CDC_ID varchar(11)
);
insert into temp_dx_patient
select p.patient_id,
       dosid(p.patient_id),
       patient_identifier(p.patient_id, @primary_id_type),
       loc_registered(p.patient_id),
       unknown_patient(p.patient_id),
       gender(p.patient_id),
       a.state_province,
       a.city_village,
       a.address3,
       a.address1,
       a.address2,
       pe.birthdate,
       pe.birthdate_estimated,
       cdc_id(p.patient_id)
from (select distinct patient_id from temp_dx_obs) p
left join person pe on pe.person_id = p.patient_id
left join person_address a on a.person_address_id =
      (select a2.person_address_id from person_address a2
       where a2.person_id = p.patient_id
       order by a2.preferred desc, a2.date_created desc limit 1);

-- user names and encounter type names (small tables; function runs once per user / type)
DROP TEMPORARY TABLE IF EXISTS temp_dx_users;
CREATE TEMPORARY TABLE temp_dx_users
(
 user_id   int(11) primary key,
 user_name varchar(255)
);
insert into temp_dx_users
select user_id, person_name_of_user(user_id) from users;

DROP TEMPORARY TABLE IF EXISTS temp_dx_enc_types;
CREATE TEMPORARY TABLE temp_dx_enc_types
(
 encounter_type_id int(11) primary key,
 encounter_type    varchar(255)
);
insert into temp_dx_enc_types
select encounter_type_id, encounter_type_name_from_id(encounter_type_id) from encounter_type;

-- encounter-level info, once per distinct encounter
DROP TEMPORARY TABLE IF EXISTS temp_dx_encounter;
CREATE TEMPORARY TABLE temp_dx_encounter
(
 encounter_id       int(11) primary key,
 visit_id           int(11),
 date_created       datetime,
 encounter_location varchar(255),
 site               varchar(255),
 visit_location     varchar(255),
 encounter_type     varchar(255),
 entered_by         varchar(255),
 provider           varchar(255),
 age_at_encounter   int(3)
);
insert into temp_dx_encounter
select e.encounter_id,
       e.visit_id,
       e.date_created,
       el.location_name,
       -- site: visit's location when there is one, otherwise the
       -- Visit Location ancestor of the encounter location (same as before)
       coalesce(vl.location_name, el.site),
       vl.location_name,
       et.encounter_type,
       u.user_name,
       provider(e.encounter_id),
       age_at_enc(e.patient_id, e.encounter_id)
from (select distinct encounter_id from temp_dx_obs where encounter_id is not null) de
inner join encounter e          on e.encounter_id       = de.encounter_id
left join locations el          on el.location_id       = e.location_id
left join visit v               on v.visit_id           = e.visit_id
left join locations vl          on vl.location_id       = v.location_id
left join temp_dx_enc_types et  on et.encounter_type_id = e.encounter_type
left join temp_dx_users u       on u.user_id            = e.creator;

-- ---------------------------------------------------------------
-- 3. Final output: one pass joining everything (no full-table UPDATEs)
-- ---------------------------------------------------------------
select
CONCAT(@partition, '-', d.patient_id) as patient_id,
p.dossierId,
p.patient_primary_id,
p.loc_registered,
p.unknown_patient,
p.gender,
e.age_at_encounter,
p.department,
p.commune,
p.section,
p.locality,
p.street_landmark,
CONCAT(@partition, '-', d.encounter_id) as encounter_id,
e.encounter_location,
e.site,
CONCAT(@partition, '-', d.obs_id) as obs_id,
d.obs_datetime,
e.entered_by,
e.provider,
case when d.coded = '1' then dc.diagnosis_coded_fr else d.diagnosis_entered end as diagnosis_entered,
g.dx_order,
g.certainty,
d.coded,
d.diagnosis_concept,
dc.diagnosis_coded_fr,
dc.diagnosis_coded_en,
dc.icd10_code,
dc.weekly_notifiable,
dc.urgent,
dc.santeFamn,
dc.psychological,
dc.pediatric,
dc.outpatient,
dc.ncd,
dc.non_diagnosis,
dc.ed,
dc.age_restricted,
dc.oncology,
-- encounter's date_created overrides the obs date_created when there is an encounter (as before)
coalesce(e.date_created, d.date_created) as date_created,
-- retrospective: entered more than 30 minutes after the obs datetime
-- (full datetime difference, so entries on a later day are counted)
IF(TIMESTAMPDIFF(SECOND, d.obs_datetime, coalesce(e.date_created, d.date_created)) > 1800, 1, 0) as retrospective,
CONCAT(@partition, '-', e.visit_id) as visit_id,
e.visit_location,
p.birthdate,
p.birthdate_estimated,
e.encounter_type,
p.section_communale_CDC_ID,
case
  when d.coded <> '1' then null
  when d.diagnosis_concept is null then 1
  when date(d.obs_datetime) = f.first_date then 1
  else 0
end as first_diagnosis
from temp_dx_obs d
left join temp_dx_patient   p  on p.patient_id        = d.patient_id
left join temp_dx_encounter e  on e.encounter_id      = d.encounter_id
left join temp_dx_group     g  on g.obs_group_id      = d.obs_group_id
left join temp_dx_concept   dc on dc.diagnosis_concept = d.diagnosis_concept
left join temp_dx_first     f  on f.patient_id        = d.patient_id
                              and f.diagnosis_concept = d.diagnosis_concept
;
