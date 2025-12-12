-- set @startDate = '2024-02-14';
-- set @endDate = '2024-02-16';
SET sql_safe_updates = 0;
set @locale = 'en';
set @partition = '${partitionNum}';

SET @socioeconomics_enc_id = (SELECT encounter_type_id FROM encounter_type WHERE uuid = 'de844e58-11e1-11e8-b642-0ed5f89f718b');

DROP TEMPORARY TABLE IF EXISTS temp_soc;
CREATE TEMPORARY TABLE temp_soc
(
 patient_id                            int(11),      
 emr_id                                VARCHAR(25),  
 encounter_id                          int(11),      
 visit_id                              int(11),      
 encounter_location                    varchar(255), 
 encounter_datetime                    datetime,     
 encounter_provider                    VARCHAR(255), 
 date_entered                          datetime,     
 user_entered                          varchar(255), 
 education                             varchar(255), 
 read_and_write                        boolean,      
 people_living_in_house                double,       
 number_of_children_living             double,       
 number_of_rooms                       double,       
 radio                                 boolean,      
 television                            boolean,      
 fridge                                boolean,      
 bank_account                          boolean,      
 toilet                                boolean,      
 latrine                               boolean,      
 floor                                 varchar(255), 
 roof                                  varchar(255), 
 walls                                 varchar(255), 
 money_avail_transport                 boolean,      
 transport_method_to_clinic            varchar(255), 
 cost_of_transport                     double,       
 travel_time_to_clinic                 varchar(255), 
 transportation_comment                text,         
 main_daily_activities                 text,         
 ability_to_perform_activity           text,         
 currently_employed                    varchar(255), 
 receive_alternate_care                boolean,
 alternate_care_source                 varchar(255),
 provides_financial_support            varchar(255),
 provides_nonfinancial_support         varchar(255),
 transport_assistance_received         boolean,      
 transport_assistance_recommended      boolean,      
 nutritional_assistance_received       boolean,      
 nutritional_assistance_recommended    boolean,      
 food_package_received                 boolean,      
 food_package_recommended              boolean,      
 school_assistance_received            boolean,      
 school_assistance_recommended         boolean,      
 housing_assistance_received           boolean,      
 housing_assistance_recommended        boolean,      
 home_care_kit_received                boolean,      
 home_care_kit_recommended             boolean,      
 cash_transfer_received                boolean,      
 cash_transfer_recommended             boolean,      
 other_assistance_received             boolean,      
 other_assistance_recommended          boolean,      
 other_assistance                      text,         
 socio_economic_assistance_comment     text,
 family_support_received               boolean,
 household_supports_anc                boolean,
 undernourishment                      varchar(255), 
 infant_mortality                      varchar(255), 
 less_than_6yrs_school                 varchar(255), 
 not_attending_school                  varchar(255), 
 cooks_with_dung_wood_charcoal_or_coal varchar(255), 
 no_sanitation_improvement             varchar(255), 
 no_water                              varchar(255), 
 no_electricity                        varchar(255), 
 inadequate_housing_materials          varchar(255), 
 household_no_assets                   varchar(255)  
);
   
insert into temp_soc(patient_id, encounter_id, visit_id, encounter_datetime, date_entered)   
select e.patient_id,  e.encounter_id, e.visit_id, e.encounter_datetime, e.date_created from encounter e
where e.encounter_type = @socioeconomics_enc_id
AND ((date(e.encounter_datetime) >=@startDate) or @startDate is null)
AND ((date(e.encounter_datetime) <=@endDate)  or @endDate is null)
and e.voided = 0;

create index temp_soc_ei on temp_soc(encounter_id);

-- emr_id
DROP TEMPORARY TABLE IF EXISTS temp_identifiers;
CREATE TEMPORARY TABLE temp_identifiers
(
patient_id						INT(11),
emr_id							VARCHAR(25)
);

INSERT INTO temp_identifiers(patient_id)
select distinct patient_id from temp_soc;

update temp_identifiers t set emr_id  = zlemr(patient_id);	

CREATE INDEX temp_identifiers_p ON temp_identifiers (patient_id);

update temp_soc tv 
inner join temp_identifiers ti on ti.patient_id = tv.patient_id
set tv.emr_id = ti.emr_id;

update temp_soc tv 
set encounter_provider = provider(encounter_id);

update temp_soc tv 
set encounter_location = encounter_location_name(encounter_id); 

update  temp_soc tv 
set user_entered = encounter_creator_name(encounter_id);

-- observations
update  temp_soc tv 
set education = obs_value_coded_list(encounter_id, 'CIEL','1712',@locale);

update  temp_soc tv 
set read_and_write = obs_value_coded_as_boolean(encounter_id, 'PIH','13736');

update  temp_soc tv 
set people_living_in_house = obs_value_numeric(encounter_id, 'CIEL','1474');

update  temp_soc tv 
set number_of_children_living = obs_value_numeric(encounter_id, 'CIEL','1825');

update  temp_soc tv 
set number_of_rooms = obs_value_numeric(encounter_id, 'CIEL','1475');

update  temp_soc tv 
set radio = obs_value_coded_as_boolean(encounter_id, 'PIH','1318');

update  temp_soc tv 
set television = obs_value_coded_as_boolean(encounter_id, 'CIEL','159746');

update  temp_soc tv 
set fridge = obs_value_coded_as_boolean(encounter_id, 'PIH','13736');

update  temp_soc tv 
set bank_account = obs_value_coded_as_boolean(encounter_id, 'PIH','11936');

update  temp_soc tv 
set toilet = obs_value_coded_as_boolean(encounter_id, 'CIEL','159389');

update  temp_soc tv 
set latrine = obs_value_coded_as_boolean(encounter_id, 'PIH','Latrine');

update  temp_soc tv 
set floor = obs_value_coded_list(encounter_id, 'CIEL','159387',@locale);

update  temp_soc tv 
set roof = obs_value_coded_list(encounter_id, 'CIEL','1290',@locale);

update  temp_soc tv 
set walls = obs_value_coded_list(encounter_id, 'PIH','1668',@locale);

update  temp_soc tv 
set money_avail_transport = obs_value_coded_as_boolean(encounter_id, 'PIH','13746');

update  temp_soc tv 
set transport_method_to_clinic = obs_value_coded_list(encounter_id, 'PIH','975',@locale);

update  temp_soc tv 
set cost_of_transport = obs_value_numeric(encounter_id, 'CIEL','159470');

update  temp_soc tv 
set travel_time_to_clinic = obs_value_coded_list(encounter_id, 'PIH','CLINIC TRAVEL TIME', @locale);

update  temp_soc tv 
set transportation_comment = obs_value_text(encounter_id, 'PIH','1301');

update  temp_soc tv 
set main_daily_activities = obs_value_text(encounter_id, 'PIH','1402');

update  temp_soc tv 
set ability_to_perform_activity = obs_value_text(encounter_id, 'PIH','11543');

update  temp_soc tv 
set currently_employed = obs_value_coded_as_boolean(encounter_id, 'PIH','3395');

update  temp_soc tv 
set transport_assistance_received = answer_exists_in_encounter(encounter_id, 'PIH','2156','PIH','990');

update  temp_soc tv 
set transport_assistance_recommended = answer_exists_in_encounter(encounter_id, 'PIH','2157','PIH','990');

update  temp_soc tv 
set nutritional_assistance_received = answer_exists_in_encounter(encounter_id, 'PIH','2156','PIH','1400');

update  temp_soc tv 
set nutritional_assistance_recommended = answer_exists_in_encounter(encounter_id, 'PIH','2157','PIH','1400');


update  temp_soc tv 
set food_package_received = answer_exists_in_encounter(encounter_id, 'PIH','2156','PIH','1847');

update  temp_soc tv 
set food_package_recommended = answer_exists_in_encounter(encounter_id, 'PIH','2157','PIH','1847');


update  temp_soc tv 
set school_assistance_received = answer_exists_in_encounter(encounter_id, 'PIH','2156','PIH','2863');

update  temp_soc tv 
set school_assistance_recommended = answer_exists_in_encounter(encounter_id, 'PIH','2157','PIH','2863');


update  temp_soc tv 
set housing_assistance_received = answer_exists_in_encounter(encounter_id, 'PIH','2156','PIH','2864');

update  temp_soc tv 
set housing_assistance_recommended = answer_exists_in_encounter(encounter_id, 'PIH','2157','PIH','2864');


update  temp_soc tv 
set home_care_kit_received = answer_exists_in_encounter(encounter_id, 'PIH','2156','PIH','12886');

update  temp_soc tv 
set home_care_kit_recommended = answer_exists_in_encounter(encounter_id, 'PIH','2157','PIH','12886');


update  temp_soc tv 
set cash_transfer_received = answer_exists_in_encounter(encounter_id, 'PIH','2156','PIH','12885');

update  temp_soc tv 
set cash_transfer_recommended = answer_exists_in_encounter(encounter_id, 'PIH','2157','PIH','12885');

update  temp_soc tv 
set other_assistance_received = answer_exists_in_encounter(encounter_id, 'PIH','2156','PIH','5622');

update  temp_soc tv 
set other_assistance_recommended = answer_exists_in_encounter(encounter_id, 'PIH','2157','PIH','5622');

update  temp_soc tv 
set other_assistance = obs_value_text(encounter_id, 'PIH','2923');

update  temp_soc tv 
set socio_economic_assistance_comment = obs_value_text(encounter_id, 'PIH','1399');

-- prenatal columns

update  temp_soc tv 
set receive_alternate_care = obs_value_coded_as_boolean(encounter_id, 'PIH','3315');

update  temp_soc tv 
set alternate_care_source = obs_value_coded_list(encounter_id, 'PIH','13781', @locale);

update  temp_soc tv 
set provides_financial_support = obs_value_coded_list(encounter_id, 'PIH','13967', @locale);

update  temp_soc tv 
set provides_nonfinancial_support = obs_value_coded_list(encounter_id, 'PIH','13969', @locale);

update  temp_soc tv 
set family_support_received = answer_exists_in_encounter(encounter_id, 'PIH','2156','PIH','10642');

update  temp_soc tv 
set household_supports_anc = obs_value_coded_as_boolean(encounter_id, 'PIH','13747');
 
-- GMPI columns
update  temp_soc tv 
set undernourishment = obs_value_coded_list(encounter_id, 'CIEL', '165491', @locale);

update  temp_soc tv 
set infant_mortality = obs_value_coded_list(encounter_id, 'CIEL', '165492', @locale);

update  temp_soc tv 
set less_than_6yrs_school = obs_value_coded_list(encounter_id, 'CIEL', '165493', @locale);

update  temp_soc tv 
set not_attending_school = obs_value_coded_list(encounter_id, 'CIEL', '165494', @locale);

update  temp_soc tv 
set cooks_with_dung_wood_charcoal_or_coal = obs_value_coded_list(encounter_id, 'CIEL', '165495', @locale);

update  temp_soc tv 
set no_sanitation_improvement = obs_value_coded_list(encounter_id, 'CIEL', '165496', @locale);

update  temp_soc tv 
set no_water = obs_value_coded_list(encounter_id, 'CIEL', '165497', @locale);

update  temp_soc tv 
set no_electricity = obs_value_coded_list(encounter_id, 'CIEL', '165498', @locale);

update  temp_soc tv 
set inadequate_housing_materials = obs_value_coded_list(encounter_id, 'CIEL', '165499', @locale);

update  temp_soc tv 
set household_no_assets = obs_value_coded_list(encounter_id, 'CIEL', '165500', @locale);

select 
	emr_id,
	if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',encounter_id),encounter_id) "encounter_id",
	if(@partition REGEXP '^[0-9]+$' = 1,concat(@partition,'-',visit_id),visit_id) "visit_id",
	encounter_location,
	encounter_datetime,
	encounter_provider,
	date_entered,
	user_entered,
	education,
	read_and_write,
	people_living_in_house,
	number_of_children_living,
	number_of_rooms,
	radio,
	television,
	fridge,
	bank_account,
	toilet,
	latrine,
	floor,
	roof,
	walls,
	money_avail_transport,
	transport_method_to_clinic,
	cost_of_transport,
	travel_time_to_clinic,
	transportation_comment,
	main_daily_activities,
	ability_to_perform_activity,
	currently_employed,
	receive_alternate_care,
	alternate_care_source,
	provides_financial_support,
	provides_nonfinancial_support,
	transport_assistance_received,
	transport_assistance_recommended,
	nutritional_assistance_received,
	nutritional_assistance_recommended,
	food_package_received,
	food_package_recommended,
	school_assistance_received,
	school_assistance_recommended,
	housing_assistance_received,
	housing_assistance_recommended,
	home_care_kit_received,
	home_care_kit_recommended,
	cash_transfer_received,
	cash_transfer_recommended,
	other_assistance_received,
	other_assistance_recommended,
	other_assistance,
	socio_economic_assistance_comment,
    family_support_received,
    household_supports_anc,
	undernourishment,
	infant_mortality,
	less_than_6yrs_school,
	not_attending_school,
	cooks_with_dung_wood_charcoal_or_coal,
	no_sanitation_improvement,
	no_water,
	no_electricity,
	inadequate_housing_materials,
	household_no_assets
from temp_soc;
