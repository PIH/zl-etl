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
myomectomy bit,
cervical_biopsy bit,
endometrial_biopsy bit,
breast_biopsy bit,
uterine_biopsy bit,
uterine_currettage bit,
caesarean_hysterectomy bit,
total_abdominal_hysterectomy bit,
iud_fp bit,
ccv_contraception bit
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
set @biopsy_of_cervix = concept_from_mapping('PIH', '8644');
set @biopsy_of_endometrium = concept_from_mapping('PIH', '8777');
set @cone_biopsy_of_cervix = concept_from_mapping('PIH', '9767');
set @cnb_of_both_breasts = concept_from_mapping('PIH', '10792');
set @cnb_of_breast  = concept_from_mapping('PIH', '8807');
set @cnb_of_cervix  = concept_from_mapping('PIH', '10800');
set @cnb_of_left_breast  = concept_from_mapping('PIH', '10837');
set @cnb_of_right_breast  = concept_from_mapping('PIH', '10798');
set @excisional_biopsy_of_both_breasts  = concept_from_mapping('PIH', '10803');
set @excisional_biopsy_of_breast  = concept_from_mapping('PIH', '9817');
set @incisional_biopsy_of_both_breasts   = concept_from_mapping('PIH', '10833');
set @incisional_biopsy_of_breast  = concept_from_mapping('PIH', '8753');
set @incisional_biopsy_of_left_breast  = concept_from_mapping('PIH', '10809');
set @incisional_biopsy_of_right_breast  = concept_from_mapping('PIH', '10791');
set @incisional_biopsy_of_uterine_cervix  = concept_from_mapping('PIH', '10790');
set @incisional_biopsy_of_uterus = concept_from_mapping('PIH', '10817');

update temp_procedure tp set biopsy = if(value_coded in 
(
@biopsy_of_cervix, 
@biopsy_of_endometrium, 
@cone_biopsy_of_cervix, 
@cnb_of_both_breasts,
@cnb_of_breast,
@cnb_of_cervix,
@cnb_of_left_breast,
@cnb_of_right_breast,
@excisional_biopsy_of_both_breasts,
@excisional_biopsy_of_breast,
@incisional_biopsy_of_both_breasts,
@incisional_biopsy_of_breast,
@incisional_biopsy_of_left_breast,
@incisional_biopsy_of_right_breast,
@incisional_biopsy_of_uterine_cervix,
@incisional_biopsy_of_uterus
), 
@yes, @non);

update temp_procedure tp set cervical_biopsy = if(value_coded in 
(
@biopsy_of_cervix, 
@cone_biopsy_of_cervix,
@cnb_of_cervix
), 
@yes, @non);

update temp_procedure tp set breast_biopsy = if(value_coded in
(
@cnb_of_both_breasts,
@cnb_of_breast,
@cnb_of_left_breast,
@cnb_of_right_breast,
@excisional_biopsy_of_both_breasts,
@excisional_biopsy_of_breast,
@incisional_biopsy_of_both_breasts,
@incisional_biopsy_of_breast,
@incisional_biopsy_of_left_breast,
@incisional_biopsy_of_right_breast
), 
@yes, @non);

update temp_procedure tp set uterine_biopsy = if(value_coded in 
(
@incisional_biopsy_of_uterine_cervix,
@incisional_biopsy_of_uterus
), 
@yes, @non);

update temp_procedure tp set endometrial_biopsy = if(value_coded = @biopsy_of_endometrium, 
@yes, @non);


#Hysterectomy 
set @total_abdominal_hysterectomy = concept_from_mapping('PIH',	'8784');
update temp_procedure tp set hysterectomy = if(value_coded = @total_abdominal_hysterectomy, @yes, @non);

set @caesarean_hysterectomy = concept_from_mapping('PIH', '8764');
update temp_procedure tp set caesarean_hysterectomy = if(value_coded = @caesarean_hysterectomy, @yes, @non);
 
set @total_abdominal_hysterectomy = concept_from_mapping('PIH', '8784');
update temp_procedure tp set total_abdominal_hysterectomy = if(value_coded = @total_abdominal_hysterectomy, @yes, @non);

# Uterine curettage
# Dilatation and curettage for incomplete spontaneous abortion
set @dilation_currettage_incomplete = concept_from_mapping('PIH', '8760');
#Dilation and curettage for removal of missed abortion
set @dilation_currettage_missed = concept_from_mapping('PIH', '8775');
update temp_procedure tp set uterine_currettage = if(value_coded in 
(@dilation_currettage_incomplete, 
@dilation_currettage_missed), 
@yes, @non);

# IUD - FP
set @insertion_of_iud = concept_from_mapping('PIH', '8870');
update temp_procedure tp set iud_fp = if(value_coded = @insertion_of_iud, @yes, @non);

# CCV - contraception
set @tubal_ligation = concept_from_mapping('PIH', '1719');
update temp_procedure tp set ccv_contraception = if(value_coded = @tubal_ligation, @yes, @non);

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

# Instrumental Deliveries
set @vacuum_delivery = concept_from_mapping('PIH', '10752');
set @forceps_delivery = concept_from_mapping('PIH', '10755');
update temp_procedure tp set instrumental_deliveries = if(value_coded in 
(
@vacuum_delivery,
@forceps_delivery
), @yes, @non);

#LEEP
set @leep = concept_from_mapping('PIH',	'9761');
update temp_procedure tp set leep = if(value_coded = @leep, @yes, @non);

# Myomectomy
set @uterine_myomectomy = concept_from_mapping('PIH', '8695');
update temp_procedure tp set myomectomy = if(value_coded = @uterine_myomectomy, @yes, @non);

update temp_procedure tp set retrospective = 
IF(TIMESTAMPDIFF(MINUTE, encounter_datetime, date_created) > 30, @yes, @non);

select 
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
cervical_biopsy,
endometrial_biopsy,
breast_biopsy,
uterine_biopsy,
uterine_currettage,
hysterectomy,
caesarean_hysterectomy,
total_abdominal_hysterectomy, 
caesarean_section,
colposcopy,
cryotherapy,
instrumental_deliveries,
leep,
myomectomy,
iud_fp,
ccv_contraception
from temp_procedure 
