#### This query returns a row per encounter (VL construct per encounter)

SET sql_safe_updates = 0;
set @partition = '${partitionNum}';
-- NOTE: @locale is not set in this script (same as the original); vl_type,
-- vl_coded_results and vl_sample_taken_date_estimated use the session's locale.

-- ---------------------------------------------------------------
-- 0. Resolve every lookup ONCE up front
-- ---------------------------------------------------------------
SET @detected_viral_load   = CONCEPT_FROM_MAPPING("CIEL", "1301");   -- (unused, as before)
set @VL_panel              = concept_from_mapping('PIH','15124');
set @vl_construct          = CONCEPT_FROM_MAPPING("PIH", "HIV viral load construct");
set @collDateEst           = concept_from_mapping('PIH','11781');
set @testResultsDate       = concept_from_mapping('PIH', 'Date of test results');
set @specNumber            = concept_from_mapping('CIEL', '162086');
set @vlCoded               = concept_from_mapping('CIEL', '1305');
set @beyondDetectableLimit = concept_from_mapping('PIH','11547');
set @notDetected           = concept_from_mapping('PIH','11471');
set @vlNumeric             = concept_from_mapping('CIEL', '856');
set @lowLimit              = concept_from_mapping('PIH', '11548');
set @beyond_name_en        = concept_name(@beyondDetectableLimit, 'en');
set @not_detected_name_en  = concept_name(@notDetected, 'en');

-- ---------------------------------------------------------------
-- 1. Lookups, each keyed by a primary key
-- ---------------------------------------------------------------

-- specimen encounter of each VL order (the original UPDATE ... JOIN kept the
-- first matching obs; this takes the obs with the lowest obs_id)
drop temporary table if exists temp_vl_order_specimen;
create temporary table temp_vl_order_specimen
(order_id     int(11) primary key,
 encounter_id int(11));
insert into temp_vl_order_specimen
select o.order_id, o.encounter_id
from (select ob.order_id, min(ob.obs_id) as obs_id
      from obs ob
      inner join orders ord on ord.order_id = ob.order_id and ord.concept_id = @VL_panel and ord.voided = 0
      where ob.voided = 0
      group by ob.order_id) f
inner join obs o on o.obs_id = f.obs_id;

-- results per specimen encounter. The *_from_temp functions are inlined as
-- subqueries on obs (same filters and ORDER BY ... LIMIT 1), so the temp_obs
-- table and one function call per row per column are no longer needed.
drop temporary table if exists temp_vl_specimen;
create temporary table temp_vl_specimen
(encounter_id           int(11) primary key,
 sample_date_estimated  text,
 result_date            datetime,
 specimen_number        datetime,
 coded_results          varchar(255),
 coded_concept_id       int(11),
 viral_load             double,
 ldl_value              double);
insert into temp_vl_specimen
select x.encounter_id,
       (select group_concat(distinct concept_name(o.value_coded, @locale) separator ' | ')
          from obs o where o.voided = 0 and o.encounter_id = x.encounter_id and o.concept_id = @collDateEst),
       (select o.value_datetime from obs o
          where o.voided = 0 and o.encounter_id = x.encounter_id and o.concept_id = @testResultsDate
          order by o.date_created desc, o.obs_id desc limit 1),
       -- NOTE: kept as in the original, which reads value_datetime for the specimen
       -- number (obs_value_datetime_from_temp_...), so this is normally NULL
       (select o.value_datetime from obs o
          where o.voided = 0 and o.encounter_id = x.encounter_id and o.concept_id = @specNumber
          order by o.date_created desc, o.obs_id desc limit 1),
       concept_name(
         (select o.value_coded from obs o
            where o.voided = 0 and o.encounter_id = x.encounter_id and o.concept_id = @vlCoded
            order by o.obs_datetime desc, o.obs_id desc limit 1),
         @locale),
       (select o.value_coded from obs o
          where o.voided = 0 and o.encounter_id = x.encounter_id and o.concept_id = @vlCoded
          order by o.obs_datetime desc, o.obs_id desc limit 1),
       (select o.value_numeric from obs o
          where o.voided = 0 and o.encounter_id = x.encounter_id and o.concept_id = @vlNumeric
          order by o.date_created desc, o.obs_id desc limit 1),
       (select o.value_numeric from obs o
          where o.voided = 0 and o.encounter_id = x.encounter_id and o.concept_id = @lowLimit
          order by o.date_created desc, o.obs_id desc limit 1)
from (select encounter_id from temp_vl_order_specimen
      union
      select encounter_id from obs
      where voided = 0 and concept_id = @vl_construct and encounter_id is not null) x;

-- user names (once per user)
drop temporary table if exists temp_vl_users;
create temporary table temp_vl_users
(user_id   int(11) primary key,
 user_name text);
insert into temp_vl_users
select user_id, person_name_of_user(user_id) from users;

-- location names (once per location, same location_name() function)
drop temporary table if exists temp_vl_locations;
create temporary table temp_vl_locations
(location_id   int(11) primary key,
 location_name text);
insert into temp_vl_locations
select location_id, location_name(location_id) from location;

-- EMR ids (once per patient; patient_identifier() inlined)
drop temporary table if exists temp_emrids;
create temporary table temp_emrids
(patient_id int(11) primary key,
 emr_id     varchar(50));
insert into temp_emrids
select x.patient_id,
       (select i.identifier from patient_identifier i
         inner join patient_identifier_type it on it.patient_identifier_type_id = i.identifier_type
         where (it.name = 'ZL EMR ID' or it.uuid = 'ZL EMR ID')
           and i.voided = 0 and i.patient_id = x.patient_id
         order by i.preferred desc, i.date_created desc limit 1)
from (select patient_id from orders where concept_id = @VL_panel and voided = 0
      union
      select person_id from obs where voided = 0 and concept_id = @vl_construct) x;

-- ---------------------------------------------------------------
-- 2. Main table (same column types), each source inserted fully populated.
--    ORDER BY keeps hiv_vl_id in the same order as before
--    (orders by order_id, then VL constructs by obs_id).
-- ---------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS temp_hiv_vl;
CREATE TEMPORARY TABLE temp_hiv_vl
(
    hiv_vl_id                       INT(11) NOT NULL AUTO_INCREMENT,
    emr_id                          VARCHAR(30),
    patient_id                      INT(11),
    order_encounter_id              INT(11),
    specimen_encounter_id           INT(11),
    order_id                        INT(11),
    order_number                    TEXT,
    visit_id                        INT,
    location_id                     INT(11),
    visit_location                  VARCHAR(255),
    status                          VARCHAR(255),
    date_activated                  DATETIME,
    date_stopped                    DATETIME,
    auto_expire_date                DATETIME,
    fulfiller_status                VARCHAR(255),
    vl_sample_taken_date            DATETIME,
    date_entered                    DATETIME,
    creator                         INT(11),
    user_entered                    VARCHAR(50),
    vl_sample_taken_date_estimated  VARCHAR(11),
    vl_result_date                  DATE,
    specimen_number                 VARCHAR(255),
    vl_coded_results                VARCHAR(255),
    vl_result_detectable            INT,
    viral_load                      INT,
    ldl_value                       INT,
    vl_type_concept_id              INT(11),
    vl_type                         VARCHAR(50),
    days_since_vl                   INT,
    index_desc                      INT,
    index_asc                       INT,
PRIMARY KEY (hiv_vl_id)
);

-- rows from orders
-- location / date_entered / creator come from the specimen encounter when there
-- is one, otherwise from the order encounter (as before); visit and sample date
-- only from the specimen encounter
INSERT INTO temp_hiv_vl
(patient_id, order_encounter_id, order_id, order_number, date_activated, date_stopped,
 auto_expire_date, fulfiller_status, vl_type_concept_id, vl_type,
 specimen_encounter_id, location_id, date_entered, creator, vl_sample_taken_date, visit_id,
 vl_sample_taken_date_estimated, vl_result_date, specimen_number, vl_coded_results,
 viral_load, ldl_value, visit_location, user_entered, days_since_vl, status, emr_id)
select
 ord.patient_id,
 ord.encounter_id,
 ord.order_id,
 ord.order_number,
 ord.date_activated,
 ord.date_stopped,
 ord.auto_expire_date,
 ord.fulfiller_status,
 ord.order_reason,
 concept_name(ord.order_reason, @locale),
 sp.encounter_id,
 if(sp.encounter_id is not null, es.location_id,  eo.location_id),
 if(sp.encounter_id is not null, es.date_created, eo.date_created),
 if(sp.encounter_id is not null, es.creator,      eo.creator),
 es.encounter_datetime,
 es.visit_id,
 r.sample_date_estimated,
 r.result_date,
 r.specimen_number,
 case when r.coded_results = @beyond_name_en then @not_detected_name_en else r.coded_results end,
 r.viral_load,
 r.ldl_value,
 l.location_name,
 u.user_name,
 DATEDIFF(NOW(), COALESCE(es.encounter_datetime, ord.date_activated)),
 CASE
    WHEN r.result_date is not null then 'Reported'
    when sp.encounter_id is not null then 'Collected'
    WHEN ord.date_stopped IS NOT NULL THEN 'Cancelled'
    WHEN ord.auto_expire_date < CURDATE() AND sp.encounter_id IS NULL THEN 'Expired'
    WHEN ord.fulfiller_status = 'COMPLETED' THEN 'Reported'
    WHEN ord.fulfiller_status = 'IN_PROGRESS' THEN 'Collected'
    WHEN ord.fulfiller_status = 'EXCEPTION' THEN 'Not Performed'
    ELSE 'Ordered'
 END,
 em.emr_id
from orders ord
left join temp_vl_order_specimen sp on sp.order_id      = ord.order_id
left join encounter es              on es.encounter_id  = sp.encounter_id
left join encounter eo              on eo.encounter_id  = ord.encounter_id
left join temp_vl_specimen r        on r.encounter_id   = sp.encounter_id
left join temp_vl_locations l       on l.location_id    = if(sp.encounter_id is not null, es.location_id, eo.location_id)
left join temp_vl_users u           on u.user_id        = if(sp.encounter_id is not null, es.creator, eo.creator)
left join temp_emrids em            on em.patient_id    = ord.patient_id
where ord.concept_id = @VL_panel
  and ord.voided = 0
order by ord.order_id;

-- rows from VL constructs (no order)
INSERT INTO temp_hiv_vl
(patient_id, specimen_encounter_id, location_id, date_entered, creator, vl_sample_taken_date, visit_id,
 vl_sample_taken_date_estimated, vl_result_date, specimen_number, vl_coded_results,
 viral_load, ldl_value, visit_location, user_entered, days_since_vl, status, emr_id)
select
 g.person_id,
 g.encounter_id,
 es.location_id,
 es.date_created,
 es.creator,
 es.encounter_datetime,
 es.visit_id,
 r.sample_date_estimated,
 r.result_date,
 r.specimen_number,
 case when r.coded_results = @beyond_name_en then @not_detected_name_en else r.coded_results end,
 r.viral_load,
 r.ldl_value,
 l.location_name,
 u.user_name,
 DATEDIFF(NOW(), es.encounter_datetime),
 CASE
    WHEN r.result_date is not null then 'Reported'
    when g.encounter_id is not null then 'Collected'
    ELSE 'Ordered'
 END,
 em.emr_id
from obs g
left join encounter es          on es.encounter_id = g.encounter_id
left join temp_vl_specimen r    on r.encounter_id  = g.encounter_id
left join temp_vl_locations l   on l.location_id   = es.location_id
left join temp_vl_users u       on u.user_id       = es.creator
left join temp_emrids em        on em.patient_id   = g.person_id
where g.voided = 0
  and g.concept_id = @vl_construct
order by g.obs_id;

-- default lower detection limit: when the coded result is Not Detected or
-- Beyond Detectable Limit and no lower limit was recorded, use 839
-- (checked on the coded concept, so it works whatever @locale is)
update temp_hiv_vl t
inner join temp_vl_specimen r on r.encounter_id = t.specimen_encounter_id
set t.ldl_value = 839
where t.ldl_value is null
  and r.coded_concept_id in (@notDetected, @beyondDetectableLimit);

-- ---------------------------------------------------------------
-- 3. Final query (unchanged)
-- ---------------------------------------------------------------
SELECT
        concat(@partition,'-',hiv_vl_id) hiv_vl_id,
        emr_id,
        concat(@partition,'-',patient_id) patient_id,
        concat(@partition,'-',tvl.order_encounter_id) order_encounter_id,
        concat(@partition,'-',tvl.specimen_encounter_id) specimen_encounter_id,
        concat(@partition,'-',tvl.order_number) order_number,
        tvl.visit_location,
        tvl.date_entered,
        tvl.user_entered,
        status,
        date_activated order_date,
        DATE(tvl.vl_sample_taken_date) vl_sample_taken_date,
        vl_sample_taken_date_estimated,
        vl_result_date,
        specimen_number,
        vl_coded_results,
        viral_load,
        ldl_value,
        vl_type,
        days_since_vl,
        index_desc,
        index_asc
FROM temp_hiv_vl tvl;
