set sql_safe_updates = 0;
set @yes = 1;
set @non = 0;

drop temporary table if exists temp_procedure;
 
create temporary table temp_procedure ( 
patient_id int,
encounter_id int,
obs_id int,
visit_id int,
creator int,
concept_id int,
value_coded int,
encounter_datetime datetime,
encounter_location varchar(150),
encounter_type  varchar(150),
obs_datetime  datetime,
entered_by varchar(150),
provider varchar(150),
procedures text,
procedure_coded int,
date_created datetime,
retrospective bit,
oophorectomy bit,
biopsy bit,
hysterectomy bit, 
caesarean_section bit,
colposcopy bit,
cryotherapy bit,
instrumental_deliveries bit,
leep bit,
myomectomy bit
);

set @procedure1 = concept_from_mapping('PIH', '10751');
set @procedure2 = concept_from_mapping('PIH', '10484');
set @non_coded_procedure = concept_from_mapping('PIH', '12923');


insert into temp_procedure
(
patient_id, 
encounter_id,
obs_id,
obs_datetime,
concept_id,
value_coded,
date_created,
creator
)
select 
person_id, 
encounter_id,
obs_id,
obs_datetime,
concept_id,
value_coded,
date_created,
creator
from obs where voided = 0 and concept_id in (@procedure1, @procedure2, @non_coded_procedure);

update temp_procedure tp join encounter e on e.voided = 0 and e.encounter_id = tp.encounter_id
set tp.visit_id =  e.visit_id,
	tp.encounter_location = encounter_location_name(e.encounter_id),
    tp.encounter_type = encounter_type_name(e.encounter_id),
    tp.provider = provider(e.encounter_id),
    tp.encounter_datetime = e.encounter_datetime;

update temp_procedure tp set procedures = 
if(concept_id in (@procedure1, @procedure2), concept_name(tp.value_coded, 'en'), 
(select value_text from obs o where voided = 0 and o.encounter_id = tp.encounter_id and o.concept_id = @non_coded_procedure)
),
procedure_coded = if(concept_id in (@procedure1, @procedure2), 1, 0);

update temp_procedure tp set entered_by  = person_name_of_user(tp.creator);

#oophorectomy
set @bilateral_salpingo_oophorectomy = concept_from_mapping('PIH',	'10796');
set @oophorectomy = concept_from_mapping('PIH', '8721');
set @salpingo_oophorectomy = concept_from_mapping('PIH', '8796');

update temp_procedure tp set oophorectomy = if(value_coded in (@bilateral_salpingo_oophorectomy, @oophorectomy, @salpingo_oophorectomy), @yes, @non);

#Biopsy

#Hysterectomy 
set @total_abdominal_hysterectomy = concept_from_mapping('PIH',	'8784');
update temp_procedure tp set hysterectomy = if(value_coded = @total_abdominal_hysterectomy, @yes, @non);

# Caesarean Section
set @caesarean_section = concept_from_mapping('PIH', 'CESAREAN SECTION');	
set @caesarean_section_with_tubal_ligation = concept_from_mapping('PIH', '8892');
update temp_procedure tp set caesarean_section = if(value_coded in (
@caesarean_section,
@caesarean_section_with_tubal_ligation), @yes, @non);

# Colposcopy
set @colposcopy = concept_from_mapping('PIH', '8952');
set @colposcopy_of_cervix_with_acetic_acid = concept_from_mapping('PIH', '9759');

update temp_procedure tp set colposcopy = if(value_coded in
(
@colposcopy,
@colposcopy_of_cervix_with_acetic_acid
), @yes, @non);

#Cryotherapy
set @cryotherapy_of_lesion_of_cervix = concept_from_mapping('PIH', '9764');
update temp_procedure tp set cryotherapy = if(value_coded = @cryotherapy_of_lesion_of_cervix, @yes, @non);

# Instrumental Deliveries (doesn't exist in the concepts)

#LEEP
set @leep = concept_from_mapping('PIH',	'9761');
update temp_procedure tp set leep = if(value_coded = @leep, @yes, @non);

# Myomectomy
set @uterine_myomectomy = concept_from_mapping('PIH', '8695');
update temp_procedure tp set myomectomy = if(value_coded = @uterine_myomectomy, @yes, @non);

update temp_procedure tp set retrospective = IF(TIME_TO_SEC(date_created) - TIME_TO_SEC(encounter_datetime) > 1800, 1,0);

select 
patient_id,
zlemr(patient_id) emr_id,
encounter_id,
obs_id,
visit_id,
creator,
encounter_datetime,
obs_datetime,
encounter_location,
encounter_type,
entered_by,
provider,
procedures,
procedure_coded,
date_created,
retrospective,
oophorectomy,
biopsy,
hysterectomy, 
caesarean_section,
colposcopy,
cryotherapy,
instrumental_deliveries,
leep,
myomectomy
 from temp_procedure 
-- where value_coded is null;
-- desc  obs;