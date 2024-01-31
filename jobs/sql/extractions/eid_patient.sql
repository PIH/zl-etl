SET sql_safe_updates = 0;
set @locale = 'en';

SELECT patient_identifier_type_id INTO @zl_emr_id FROM patient_identifier_type WHERE uuid = 'a541af1e-105c-40bf-b345-ba1fd6a59b85';
SELECT patient_identifier_type_id INTO @dossier FROM patient_identifier_type WHERE uuid = '3B954DB1-0D41-498E-A3F9-1E20CCC47323';
SELECT program_workflow_id into @eid_treatment_status_id from program_workflow pw where uuid = '7e35b35e-5f40-4652-b2f2-b4afcb8e683a' ;

SET @eid_program_id = (SELECT program_id FROM program WHERE retired = 0 AND uuid = '7e06bf82-9f1a-4218-b68f-823082ef519b');
SET @telephone_number = (SELECT person_attribute_type_id FROM person_attribute_type p WHERE p.name = 'Telephone Number');


DROP TEMPORARY TABLE IF EXISTS temp_patient;
CREATE TEMPORARY TABLE temp_patient
(
    patient_id                  INT(11),
    zl_emr_id                   VARCHAR(255),
    hivemr_v1_id                VARCHAR(255),
    hiv_dossier_id              VARCHAR(255),
    gender                      VARCHAR(50),
    birthdate                   DATE,
    telephone_number            VARCHAR(100),
    current_age                 FLOAT,
    initial_enrollment_date     DATE,
    initial_enrollment_location VARCHAR(100),
    latest_program_id           INT(11),
    program_location_id         INT,
    latest_enrollment_location  VARCHAR(100),
    current_treatment_status    VARCHAR(255),
    completion_date             DATE,
    outcome                     VARCHAR(255)
 );

INSERT INTO temp_patient (patient_id)
SELECT distinct patient_id FROM patient_program 
WHERE voided=0
and program_id = @eid_program_id;

CREATE INDEX temp_patient_patient_id ON temp_patient (patient_id);


## Delete test patients
DELETE FROM temp_patient WHERE
patient_id IN (
               SELECT
                      a.person_id
                      FROM person_attribute a
                      INNER JOIN person_attribute_type t ON a.person_attribute_type_id = t.person_attribute_type_id
                      AND a.value = 'true' AND t.name = 'Test Patient'
               );

-- identifiers 
UPDATE temp_patient t
set zl_emr_id = zlemr(t.patient_id);             
              
UPDATE temp_patient t
set hivemr_v1_id = patient_identifier(t.patient_id, '139766e8-15f5-102d-96e4-000c29c2a5d7');

UPDATE temp_patient t
set hiv_dossier_id = patient_identifier(t.patient_id, '3B954DB1-0D41-498E-A3F9-1E20CCC47323');

-- demographics
UPDATE temp_patient
SET gender = GENDER(patient_id);

UPDATE temp_patient
SET birthdate = BIRTHDATE(patient_id);

update temp_patient t
SET telephone_number = phone_number(patient_id);
    
update temp_patient t set current_age =  ROUND(DATEDIFF(NOW(),t.birthdate) / 365.25 , 1);

-- program detauls
UPDATE temp_patient t SET initial_enrollment_date = initialEnrollmentDate(t.patient_id, @eid_program_id);
UPDATE temp_patient t SET initial_enrollment_location = initialProgramLocation(t.patient_id, @eid_program_id);
UPDATE temp_patient t set latest_program_id = mostRecentPatientProgramId(t.patient_id, @eid_program_id);

UPDATE temp_patient t SET program_location_id = PROGRAMLOCATIONID(t.latest_program_id);
UPDATE temp_patient t SET latest_enrollment_location = currentProgramLocation(t.patient_id, @eid_program_id);
UPDATE temp_patient t SET current_treatment_status = currentProgramState(t.latest_program_id, @eid_treatment_status_id, @locale);

UPDATE temp_patient t SET completion_date = programCompletionDate(latest_program_id);
UPDATE temp_patient t SET outcome = programOutcome(latest_program_id, @locale);

select 
zl_emr_id,
hivemr_v1_id,
hiv_dossier_id,
gender,
birthdate,
telephone_number,
current_age,
initial_enrollment_date,
initial_enrollment_location,
latest_enrollment_location,
current_treatment_status,
completion_date,
outcome
from temp_patient;
