SET sql_safe_updates = 0;
set @partition = '${partitionNum}';
SET @mch_emr_id = (SELECT patient_identifier_type_id FROM patient_identifier_type WHERE uuid = 'a541af1e-105c-40bf-b345-ba1fd6a59b85');
SET @mch_patient_program_id = (SELECT program_id FROM program WHERE uuid = '41a2715e-8a14-11e8-9a94-a6cf71072f73');
SET @obgyn_encounter = (SELECT encounter_type_id FROM encounter_type WHERE uuid = 'd83e98fd-dc7b-420f-aa3f-36f648b4483d');

## patient
DROP TEMPORARY TABLE IF EXISTS temp_mch_status;
CREATE TEMPORARY TABLE temp_mch_status
(
    patient_state_id            INT(11) NOT NULL AUTO_INCREMENT,
    patient_id                  INT(11),
    patient_program_id          INT(11),
    emr_id                      VARCHAR(15),
    location_id                 INT(11),
    enrollment_location         VARCHAR(255),
    program_date_enrolled       DATE,
    program_date_completed      DATE,
    status_start_date           DATE,
    status_end_date             DATE,
    state_id                    INT(11),
    treatment_status            varchar(255),    
    outcome_concept_id          INT(11),
    outcome                     VARCHAR(255),
    index_asc                   INT(11),
    index_desc                  INT(11),
PRIMARY KEY (patient_state_id)
);

insert into temp_mch_status
	(patient_id,
	patient_program_id,
	state_id,
	program_date_enrolled,
	program_date_completed,
	status_start_date,
	status_end_date,
	outcome_concept_id,
	location_id)
select
	pp.patient_id,
	pp.patient_program_id,
	ps.state,
	pp.date_enrolled,
	pp.date_completed,
	ps.start_date,
	ps.end_date,
	pp.outcome_concept_id,
	pp.location_id
from patient_program pp 
left outer join patient_state ps on pp.patient_program_id = ps.patient_program_id and ps.voided = 0
where pp.program_id = @mch_patient_program_id 
and pp.voided = 0 ;

select * from patient_program pp ;

CREATE INDEX mch_patient_id ON temp_mch_status(patient_id);

## Delete test patients
DELETE FROM temp_mch_status WHERE
patient_id IN (
               SELECT
                      a.person_id
                      FROM person_attribute a
                      INNER JOIN person_attribute_type t ON a.person_attribute_type_id = t.person_attribute_type_id
                      AND a.value = 'true' AND t.name = 'Test Patient'
               );

UPDATE temp_mch_status t
SET t.emr_id = zlemr(t.patient_id);

UPDATE temp_mch_status t
SET t.enrollment_location = LOCATION_NAME(location_id);

UPDATE temp_mch_status t
inner join program_workflow_state pws on pws.program_workflow_state_id = t.state_id
SET t.treatment_status = concept_name(pws.concept_id , @locale);

UPDATE temp_mch_status t
SET t.outcome = concept_name(outcome_concept_id , @locale);

### Final Query
SELECT
	concat(@partition,'-',t.patient_state_id) "patient_state_id",
	concat(@partition,'-',t.patient_program_id) "patient_program_id",
	emr_id,
    enrollment_location,
    program_date_enrolled,
    program_date_completed,
    treatment_status,
    status_start_date,
    status_end_date,
    outcome,
    index_asc,
    index_desc
FROM temp_mch_status t;
