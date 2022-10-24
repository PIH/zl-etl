set @partition = '${partitionNum}';
set @sitename = '${siteName}';

set @hiv_exposed_infant_enrollment_program =  program('EID'); -- exposed infant enrollment
set @hiv_program = program('HIV'); -- HIV enrollment

set @hiv_dispensing = encounter_type('cc1720c9-3e4c-4fa8-a7ec-40eeaad1958c');
set @hiv_initial = encounter_type('c31d306a-40c4-11e7-a919-92ebcb67fe33');
set @hiv_followup = encounter_type('c31d3312-40c4-11e7-a919-92ebcb67fe33');
set @exposed_infant_followup = encounter_type('0f070640-279e-4ec0-9e6c-6ef1f6567030');

drop temporary table if exists temp_warnings;
create temporary table temp_warnings
(
emr_id								varchar(255),
patient_id							int(11),
warning_type						text,
warning_details						text
);

-- blank emr_id
insert into temp_warnings (patient_id, warning_type, warning_details)
select patient_id,'blank emr_id',
concat('patient_id: ',patient_id,' on site: ',@sitename)
from patient p 
where p.voided = 0 and zlemr(p.patient_id) is null;

-- overlapping program segments
insert into temp_warnings (patient_id, emr_id,warning_type, warning_details)
select pp.patient_id ,zlemr(pp.patient_id),'overlapping program enrollments',
concat('program name: ',p.name, ' | ',
	'patient_program_ids: ',pp.patient_program_id ,',', pp2.patient_program_id)
from patient_program pp
inner join program p on p.program_id  = pp.program_id 
inner join patient_program pp2 on pp2.voided = 0 
	and pp2.patient_id = pp.patient_id 
	and pp2.program_id = pp.program_id
	and pp2.patient_program_id <> pp.patient_program_id 
	and (pp.date_enrolled < pp2.date_enrolled and ifnull(pp.date_completed,'9999-12-31') >pp2.date_enrolled)
where pp.voided = 0;	

-- blank demographics
insert into temp_warnings (patient_id, emr_id,warning_type)
select pt.patient_id ,
zlemr(pt.patient_id),
'blank gender'
from patient pt
inner join person p on p.person_id = pt.patient_id and p.gender is null
where pt.voided = 0
and unknown_patient(patient_id) is not null;

insert into temp_warnings (patient_id, emr_id,warning_type)
select pt.patient_id ,
zlemr(pt.patient_id),
'blank birthdate'
from patient pt
inner join person p on p.person_id = pt.patient_id and p.birthdate  is null
where pt.voided = 0
and unknown_patient(patient_id) is not null;

insert into temp_warnings (patient_id, emr_id,warning_type, warning_details)
select pt.patient_id ,
zlemr(pt.patient_id),
'blank given or family name',
concat('given name: ',pn.given_name,' | family name: ',pn.family_name)
from patient pt
inner join person_name pn on pn.person_id = pt.patient_id and (pn.given_name is null or pn.family_name is null)
where pt.voided = 0
and unknown_patient(patient_id) is not null;

-- death date before birthdate
insert into temp_warnings (patient_id, emr_id, warning_type, warning_details)
select pt.patient_id ,
zlemr(pt.patient_id),
'death date before birth date', 
concat('death date: ',p.death_date,' | birth date: ',p.birthdate, ' | unknown patient: ',ifnull(unknown_patient(1317),'0'))
from patient pt 
inner join person p on p.person_id = pt.patient_id and p.death_date < p.birthdate  
where p.voided = 0;

-- hiv dispensing without orders
insert into temp_warnings (patient_id, emr_id, warning_type, warning_details)
select patient_id, zlemr(patient_id), 
'HIV dispensing without any prescriptions',
concat('first HIV dispensing: ',min(e.encounter_datetime))
from encounter e 
where encounter_type = @hiv_dispensing
and not exists
	(select 1 from orders o
	where o.order_type_id = 2
	and o.patient_id = e.patient_id)
group by zlemr(patient_id), patient_id ;

-- hiv initial encounters without HIV or exposed infant enrollment
insert into temp_warnings (patient_id, emr_id, warning_type, warning_details)
select patient_id, zlemr(patient_id), 
'HIV initial encounter without any HIV or exposed infant enrollment' , 
concat('first HIV intake: ',min(e.encounter_datetime))
from encounter e 
where e.voided = 0
and e.encounter_type = @hiv_initial
and not exists
    (select 1 from patient_program pp
    where pp.voided = 0
    and pp.program_id in (@hiv_program, @hiv_exposed_infant_enrollment_program)
    and pp.patient_id = e.patient_id )
group by e.patient_id; 
 
-- hiv followup encounters without HIV or exposed infant enrollment    
insert into temp_warnings (patient_id, emr_id, warning_type, warning_details)
select patient_id, zlemr(patient_id), 
'HIV followup encounter without any HIV or exposed infant enrollment' , 
concat('first HIV followup: ',min(e.encounter_datetime))
from encounter e 
where e.voided = 0
and e.encounter_type = @hiv_followup
and not exists
    (select 1 from patient_program pp
    where pp.voided = 0
    and pp.program_id in (@hiv_program, @hiv_exposed_infant_enrollment_program)
    and pp.patient_id = e.patient_id )
group by e.patient_id;

-- hiv exposed infant followup encounters without HIV or exposed infant enrollment    
insert into temp_warnings (patient_id, emr_id, warning_type, warning_details)
select patient_id, zlemr(patient_id), 
'HIV exposed infant followup without any HIV or exposed infant enrollment' ,
concat('first HIV exposed infant followup: ',min(e.encounter_datetime))
from encounter e 
where e.voided = 0
and e.encounter_type = @exposed_infant_followup
and not exists
    (select 1 from patient_program pp
    where pp.voided = 0
    and pp.program_id in (@hiv_program, @hiv_exposed_infant_enrollment_program)
    and pp.patient_id = e.patient_id )
group by e.patient_id;

-- hiv dispensing encounters without HIV or exposed infant enrollment    
insert into temp_warnings (patient_id, emr_id, warning_type, warning_details)
select patient_id, zlemr(patient_id), 
'HIV dispensing encounter without any HIV or exposed infant enrollment' ,
concat('first HIV dispensing: ',min(e.encounter_datetime))
from encounter e 
where e.voided = 0
and e.encounter_type = @hiv_dispensing
and not exists
    (select 1 from patient_program pp
    where pp.voided = 0
    and pp.program_id in (@hiv_program, @hiv_exposed_infant_enrollment_program)
    and pp.patient_id = e.patient_id )
group by e.patient_id;

-- final select
select emr_id,
concat(@partition,'-',patient_id) "patient_id",
warning_type,
warning_details
from temp_warnings;