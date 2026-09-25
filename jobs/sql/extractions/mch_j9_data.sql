SET sql_safe_updates = 0;
set @partition = '${partitionNum}';
-- NOTE: @locale is not set in this script (same as the original); names come out
-- in whatever locale the session already has. Add SET @locale = 'fr'; (or 'en') to pin it.

-- ---------------------------------------------------------------
-- 0. Resolve every lookup ONCE up front
--    (the *_from_temp functions called concept_from_mapping() on every call)
-- ---------------------------------------------------------------
select program_id into @mchProgram from program where uuid = '41a2715e-8a14-11e8-9a94-a6cf71072f73';
select encounter_type('d83e98fd-dc7b-420f-aa3f-36f648b4483d') into @ob_gyn_enc_id;
select encounter_type('873f968a-73a8-4f9c-ac78-9f4778b751b6') into @reg_enc_id;
select program_workflow_id into @mchWorkflow from program_workflow where uuid = '41a277d0-8a14-11e8-9a94-a6cf71072f73';

set @ms_id                     = concept_from_mapping('CIEL','1054');
set @r_id                      = concept_from_mapping('PIH','10154');
set @mothers_group_id          = concept_from_mapping('PIH','11665');
set @living_children_id        = concept_from_mapping('PIH','11117');
set @trad_healer_id            = concept_from_mapping('PIH','13242');
set @prenatal_teas_id          = concept_from_mapping('PIH','13737');
set @edd_id                    = concept_from_mapping('PIH','5596');
set @del_order_id              = concept_from_mapping('PIH','13126');
set @deliveryTypeId            = concept_from_mapping('PIH','11663');
set @neonatal_status_id        = concept_from_mapping('PIH','12899');
set @history_q                 = concept_from_mapping('PIH','10140');
set @current_risk_q            = concept_from_mapping('PIH','11673');
set @a_pre_eclampsia           = concept_from_mapping('PIH','47');
set @a_eclampsia               = concept_from_mapping('PIH','7696');
set @a_gbv                     = concept_from_mapping('PIH','11550');
set @a_type1_diabetes          = concept_from_mapping('PIH','6691');
set @a_type2_diabetes          = concept_from_mapping('PIH','6692');
set @a_gest_diabetes           = concept_from_mapping('PIH','6693');
set @a_pph                     = concept_from_mapping('PIH','49');
set @a_hypertension            = concept_from_mapping('PIH','903');
set @a_gest_hypertension       = concept_from_mapping('PIH','9752');
set @type_opd_visit            = concept_from_mapping('PIH','8879');
set @anc_visit                 = concept_from_mapping('PIH','6259');
set @obgyn_visit               = concept_from_mapping('PIH','13254');
set @pnc_visit                 = concept_from_mapping('PIH','6261');
set @fp_visit                  = concept_from_mapping('PIH','5483');
set @referral_type_id          = concept_from_mapping('PIH','Type of referring service');
set @other_id                  = concept_from_mapping('PIH','OTHER');
set @referred_from_facility_id = concept_from_mapping('CIEL','160535');
set @now                       = now();

-- ---------------------------------------------------------------
-- 1. One row per MCH program enrollment
-- ---------------------------------------------------------------
drop temporary table if exists temp_j9;
create temporary table temp_j9
(
patient_id                      int,
mch_program_id                  int primary key,
patient_age                     int,
date_enrolled                   datetime,
date_completed                  datetime,
program_state                   varchar(255),
mothers_group_obs_id            int(11),
mothers_group                   text,
expected_delivery_date_obs_id   int(11),
expected_delivery_date          datetime,
highest_birth_number_obs_group  int,
highest_birth_number            int,
prior_birth_delivery_type       varchar(255),
prior_birth_neonatal_status     varchar(255),
history_pre_eclampsia           boolean,
history_eclampsia               boolean,
history_post_partum_hemorrhage  boolean,
history_gender_based_violence   boolean,
history_type_1_diabetes         boolean,
history_type_2_diabetes         boolean,
history_gestational_diabetes    boolean,
history_hypertension            boolean,
history_gestational_hypertenson boolean,
current_hypertension_risk       boolean,
number_anc_visit                int,
number_obGyn_visits             int,
number_postpartum_visits        int,
number_family_planning_visits   int,
marital_status_obs_id           int(11),
marital_status                  varchar(255),
religion_obs_id                 int(11),
religion                        varchar(255),
family_support                  boolean,
partner_support_anc_obs_id      int(11),
partner_support_anc             boolean,
number_living_children_obs_id   int(11),
number_living_children          int,
number_household_members_obs_id int(11),
number_household_members        int,
address_department              varchar(255),
address_commune                 varchar(255),
address_section_communale       varchar(255),
address_locality                varchar(255),
address_street_landmark         varchar(255),
traditional_healer_obs_id       int(11),
traditional_healer              varchar(255),
prenatal_teas_obs_id            int(11),
prenatal_teas                   varchar(255),
referral_type                   VARCHAR(255),
referral_type_other             VARCHAR(255),
referred_from_facility          VARCHAR(100),
index temp_j9_pid (patient_id)
);

-- program_state inlined from currentProgramState() (same joins, filters and ORDER BY)
insert into temp_j9 (patient_id, mch_program_id, date_enrolled, date_completed, program_state)
select pp.patient_id, pp.patient_program_id, pp.date_enrolled, pp.date_completed,
       concept_name(
         (select pws.concept_id
          from patient_state ps
          inner join program_workflow_state pws on ps.state = pws.program_workflow_state_id
                 and pws.program_workflow_id = @mchWorkflow
          inner join patient_program pp2 on pp2.voided = 0 and pp2.patient_program_id = ps.patient_program_id
          where ps.patient_program_id = pp.patient_program_id
            and (ps.end_date is null or ps.end_date = pp2.date_completed)
            and ps.voided = 0
          order by ps.start_date desc limit 1),
         @locale)
from patient_program pp
where pp.program_id = @mchProgram
  and pp.voided = 0;

-- enrollment keys, used by the grouped queries below
-- (MySQL can't read temp_j9 inside a query that updates temp_j9)
drop temporary table if exists temp_j9_keys;
create temporary table temp_j9_keys
(mch_program_id int primary key,
 patient_id     int,
 date_enrolled  datetime,
 end_date       datetime,
 index temp_j9_keys_pid (patient_id));
insert into temp_j9_keys
select mch_program_id, patient_id, date_enrolled, ifnull(date_completed, @now)
from temp_j9;

-- ---------------------------------------------------------------
-- 2. Patient-level fields, ONE insert, no functions per row:
--    - age:      current_age_in_years() inlined
--    - address:  one join to the preferred non-voided address
--                (the 5 person_address_* functions each picked this same row)
--    - marital status / religion: latest obs on a registration encounter,
--                read straight from obs (no registration temp_obs needed)
--    - emr_id:   zlemr() inlined, used in the final select
-- ---------------------------------------------------------------
drop temporary table if exists temp_j9_patients;
create temporary table temp_j9_patients
(patient_id                int(11) primary key,
 emr_id                    varchar(255),
 patient_age               int,
 address_department        varchar(255),
 address_commune           varchar(255),
 address_section_communale varchar(255),
 address_locality          varchar(255),
 address_street_landmark   varchar(255),
 marital_status            varchar(255),
 religion                  varchar(255));

insert into temp_j9_patients
select p.patient_id,
       (select i.identifier from patient_identifier i
         inner join patient_identifier_type it on it.patient_identifier_type_id = i.identifier_type
         where (it.name = 'ZL EMR ID' or it.uuid = 'ZL EMR ID')
           and i.voided = 0 and i.patient_id = p.patient_id
         order by i.preferred desc, i.date_created desc limit 1),
       TIMESTAMPDIFF(YEAR, pe.birthdate, @now),
       a.state_province,
       a.city_village,
       a.address3,
       a.address1,
       a.address2,
       concept_name(
         (select o.value_coded from obs o
           inner join encounter e on e.encounter_id = o.encounter_id
                  and e.encounter_type = @reg_enc_id and e.voided = 0
           where o.voided = 0 and o.person_id = p.patient_id and o.concept_id = @ms_id
           order by o.obs_datetime desc limit 1),
         @locale),
       -- BUG kept from the original so outputs match: religion was always NULL
       -- (its update targeted temp_j9 instead of temp_j9_patients).
       -- To fix, replace NULL with the same expression as marital status, using @r_id.
       NULL
from (select distinct patient_id from temp_j9) p
left join person pe on pe.person_id = p.patient_id
left join person_address a on a.person_address_id =
      (select a2.person_address_id from person_address a2
       where a2.voided = 0 and a2.person_id = p.patient_id
       order by a2.preferred desc, a2.date_created desc limit 1);

update temp_j9 t
inner join temp_j9_patients p on p.patient_id = t.patient_id
set t.patient_age               = p.patient_age,
    t.address_department        = p.address_department,
    t.address_commune           = p.address_commune,
    t.address_section_communale = p.address_section_communale,
    t.address_locality          = p.address_locality,
    t.address_street_landmark   = p.address_street_landmark,
    t.marital_status            = p.marital_status,
    t.religion                  = p.religion;

-- ---------------------------------------------------------------
-- 3. OB/GYN obs for these patients
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_obs;
create temporary table temp_obs
select o.obs_id, o.obs_group_id, o.encounter_id, o.person_id, o.concept_id, o.value_coded,
       o.value_numeric, o.value_text, o.value_datetime, o.comments, o.obs_datetime
from obs o
inner join encounter e on e.encounter_id = o.encounter_id
       and e.encounter_type = @ob_gyn_enc_id
       and e.voided = 0
inner join (select distinct patient_id from temp_j9) p on p.patient_id = e.patient_id
where o.voided = 0;

create index temp_obs_pc  on temp_obs(person_id, concept_id, obs_datetime);
create index temp_obs_ci6 on temp_obs(obs_group_id, concept_id);
create index temp_obs_oi  on temp_obs(obs_id);

-- latest obs inside each enrollment window (replaces latest_obs_from_temp_between_dates
-- + value_*_from_temp: same filters and ORDER BY obs_datetime desc LIMIT 1).
-- One statement each, because MySQL can't reference a temp table twice in one query.
update temp_j9 t set mothers_group =
  (select o.value_text from temp_obs o
   where o.person_id = t.patient_id and o.concept_id = @mothers_group_id
     and o.obs_datetime >= t.date_enrolled and o.obs_datetime <= ifnull(t.date_completed, @now)
   order by o.obs_datetime desc limit 1);

update temp_j9 t set number_living_children =
  (select o.value_numeric from temp_obs o
   where o.person_id = t.patient_id and o.concept_id = @living_children_id
     and o.obs_datetime >= t.date_enrolled and o.obs_datetime <= ifnull(t.date_completed, @now)
   order by o.obs_datetime desc limit 1);

-- value_coded_name_from_temp() uses the session @locale, so this does too
update temp_j9 t set traditional_healer = concept_name(
  (select o.value_coded from temp_obs o
   where o.person_id = t.patient_id and o.concept_id = @trad_healer_id
     and o.obs_datetime >= t.date_enrolled and o.obs_datetime <= ifnull(t.date_completed, @now)
   order by o.obs_datetime desc limit 1), @locale);

update temp_j9 t set prenatal_teas = concept_name(
  (select o.value_coded from temp_obs o
   where o.person_id = t.patient_id and o.concept_id = @prenatal_teas_id
     and o.obs_datetime >= t.date_enrolled and o.obs_datetime <= ifnull(t.date_completed, @now)
   order by o.obs_datetime desc limit 1), @locale);

update temp_j9 t set expected_delivery_date =
  (select o.value_datetime from temp_obs o
   where o.person_id = t.patient_id and o.concept_id = @edd_id
     and o.obs_datetime >= t.date_enrolled and o.obs_datetime <= ifnull(t.date_completed, @now)
   order by o.obs_datetime desc limit 1);

-- highest birth number from prior births (on or before the end of the enrollment)
drop temporary table if exists temp_j9_birth;
create temporary table temp_j9_birth
(mch_program_id       int primary key,
 highest_birth_number double);
insert into temp_j9_birth
select k.mch_program_id, max(o.value_numeric)
from temp_j9_keys k
inner join temp_obs o on o.person_id = k.patient_id
where o.concept_id = @del_order_id
  and o.obs_datetime <= k.end_date
group by k.mch_program_id;

update temp_j9 t
inner join temp_j9_birth b on b.mch_program_id = t.mch_program_id
set t.highest_birth_number = b.highest_birth_number;

-- obs group of the highest birth number (unchanged logic)
update temp_j9 t set t.highest_birth_number_obs_group =
  (select o2.obs_group_id from temp_obs o2
   where o2.concept_id = @del_order_id
     and o2.value_numeric = t.highest_birth_number
     and o2.person_id = t.patient_id
   order by o2.obs_datetime desc limit 1);

-- prior birth delivery type (unchanged)
update temp_j9 t
inner join temp_obs o on o.obs_group_id = t.highest_birth_number_obs_group
      and o.concept_id = @deliveryTypeId
set t.prior_birth_delivery_type = concept_name(o.value_coded, @locale);

-- prior birth neonatal status: one grouped pass per obs group
-- (replaces obs_from_group_id_value_coded_list_from_temp per row)
drop temporary table if exists temp_j9_neonatal;
create temporary table temp_j9_neonatal
(obs_group_id int primary key,
 status_list  text);
insert into temp_j9_neonatal
select o.obs_group_id,
       group_concat(distinct concept_name(o.value_coded, @locale) separator ' | ')
from temp_obs o
where o.concept_id = @neonatal_status_id
  and o.obs_group_id is not null
group by o.obs_group_id;

update temp_j9 t
inner join temp_j9_neonatal n on n.obs_group_id = t.highest_birth_number_obs_group
set t.prior_birth_neonatal_status = n.status_list;

-- history checkboxes ever checked: one grouped pass per patient
-- (replaces 9 answerEverExists_from_temp calls per row; like the function,
--  the result is 1 when found and NULL when not)
drop temporary table if exists temp_j9_history;
create temporary table temp_j9_history
(patient_id                      int primary key,
 history_pre_eclampsia           boolean,
 history_eclampsia               boolean,
 history_gender_based_violence   boolean,
 history_type_1_diabetes         boolean,
 history_type_2_diabetes         boolean,
 history_gestational_diabetes    boolean,
 history_post_partum_hemorrhage  boolean,
 history_hypertension            boolean,
 history_gestational_hypertenson boolean);
insert into temp_j9_history
select o.person_id,
       max(case when o.value_coded = @a_pre_eclampsia     then 1 end),
       max(case when o.value_coded = @a_eclampsia         then 1 end),
       max(case when o.value_coded = @a_gbv               then 1 end),
       max(case when o.value_coded = @a_type1_diabetes    then 1 end),
       max(case when o.value_coded = @a_type2_diabetes    then 1 end),
       max(case when o.value_coded = @a_gest_diabetes     then 1 end),
       max(case when o.value_coded = @a_pph               then 1 end),
       max(case when o.value_coded = @a_hypertension      then 1 end),
       max(case when o.value_coded = @a_gest_hypertension then 1 end)
from temp_obs o
where o.concept_id = @history_q
group by o.person_id;

-- current hypertension risk: recorded on or after the enrollment date
drop temporary table if exists temp_j9_risk;
create temporary table temp_j9_risk
(mch_program_id int primary key);
insert into temp_j9_risk
select distinct k.mch_program_id
from temp_j9_keys k
inner join temp_obs o on o.person_id = k.patient_id
where o.concept_id = @current_risk_q
  and o.value_coded = @a_hypertension
  and o.obs_datetime >= k.date_enrolled;

update temp_j9 t
left join temp_j9_history h on h.patient_id     = t.patient_id
left join temp_j9_risk    r on r.mch_program_id = t.mch_program_id
set t.history_pre_eclampsia           = h.history_pre_eclampsia,
    t.history_eclampsia               = h.history_eclampsia,
    t.history_gender_based_violence   = h.history_gender_based_violence,
    t.history_type_1_diabetes         = h.history_type_1_diabetes,
    t.history_type_2_diabetes         = h.history_type_2_diabetes,
    t.history_gestational_diabetes    = h.history_gestational_diabetes,
    t.history_post_partum_hemorrhage  = h.history_post_partum_hemorrhage,
    t.history_hypertension            = h.history_hypertension,
    t.history_gestational_hypertenson = h.history_gestational_hypertenson,
    t.current_hypertension_risk       = case when r.mch_program_id is not null then 1 end;

-- visit counts + referral answers during the enrollment window:
-- one grouped pass over temp_obs (was 7 correlated subqueries per row)
drop temporary table if exists temp_j9_window;
create temporary table temp_j9_window
(mch_program_id                int primary key,
 number_anc_visit              int,
 number_obGyn_visits           int,
 number_postpartum_visits      int,
 number_family_planning_visits int,
 referral_type                 text,
 referral_type_other           text,
 referred_from_facility        text);
insert into temp_j9_window
select k.mch_program_id,
       sum(o.concept_id = @type_opd_visit and o.value_coded = @anc_visit),
       sum(o.concept_id = @type_opd_visit and o.value_coded = @obgyn_visit),
       sum(o.concept_id = @type_opd_visit and o.value_coded = @pnc_visit),
       sum(o.concept_id = @type_opd_visit and o.value_coded = @fp_visit),
       group_concat(distinct case when o.concept_id = @referral_type_id
                                  then concept_name(o.value_coded, @locale) end separator ' | '),
       group_concat(distinct case when o.concept_id = @referral_type_id and o.value_coded = @other_id
                                  then o.comments end separator ' | '),
       group_concat(distinct case when o.concept_id = @referred_from_facility_id
                                  then location_name(o.value_text) end separator ' | ')
from temp_j9_keys k
inner join temp_obs o on o.person_id = k.patient_id
where o.concept_id in (@type_opd_visit, @referral_type_id, @referred_from_facility_id)
  and o.obs_datetime >= k.date_enrolled
  and o.obs_datetime <= k.end_date
group by k.mch_program_id;

-- counts are 0 (not NULL) when there are no visits, as before
update temp_j9 t
left join temp_j9_window w on w.mch_program_id = t.mch_program_id
set t.number_anc_visit              = ifnull(w.number_anc_visit, 0),
    t.number_obGyn_visits           = ifnull(w.number_obGyn_visits, 0),
    t.number_postpartum_visits      = ifnull(w.number_postpartum_visits, 0),
    t.number_family_planning_visits = ifnull(w.number_family_planning_visits, 0),
    t.referral_type                 = w.referral_type,
    t.referral_type_other           = w.referral_type_other,
    t.referred_from_facility        = w.referred_from_facility;

-- ---------------------------------------------------------------
-- 4. Final output (emr_id now comes from the lookup instead of zlemr() per row)
-- ---------------------------------------------------------------
Select
concat(@partition,'-',t.mch_program_id) "mch_program_id",
p.emr_id "emr_id",
t.patient_age,
t.date_enrolled,
t.date_completed,
t.program_state,
t.mothers_group,
t.expected_delivery_date,
t.prior_birth_delivery_type,
t.prior_birth_neonatal_status,
t.history_pre_eclampsia,
t.history_eclampsia,
t.history_post_partum_hemorrhage,
t.history_gender_based_violence,
t.history_type_1_diabetes,
t.history_type_2_diabetes,
t.history_gestational_diabetes,
t.history_hypertension,
t.history_gestational_hypertenson,
t.current_hypertension_risk,
t.number_anc_visit,
t.number_obGyn_visits,
t.number_postpartum_visits,
t.number_family_planning_visits,
t.marital_status,
t.religion,
t.family_support,
t.partner_support_anc,
t.number_living_children,
t.number_household_members,
t.address_department,
t.address_commune,
t.address_section_communale,
t.address_locality,
t.address_street_landmark,
t.traditional_healer,
t.prenatal_teas,
t.referral_type,
t.referral_type_other,
t.referred_from_facility
from temp_j9 t
left join temp_j9_patients p on p.patient_id = t.patient_id
;
