set sql_safe_updates = 0;

drop table if exists temp_medication_orders;
create table temp_medication_orders
(
encounter_id int,
visit_id int,
order_id int,
orderer int,
concept_id int,
location_id int,
order_drug text,
order_formulation text,
order_location varchar(255),
order_created_date date,
order_date_activated date,
user_entered varchar(255),
order_quantity int,
order_dose int,
order_dose_unit varchar(50),
order_route varchar(50),
order_frequency varchar(50),
order_reason text
);

insert into temp_medication_orders (
encounter_id, 
order_id,
concept_id,
order_created_date, 
order_date_activated
)
select 
encounter_id,
order_id,
concept_id,
date(date_created),
date(date_activated)
from orders where voided = 0 and date_created like "%2023-02-10%";

update temp_medication_orders tm set visit_id = (select visit_id from encounter e where voided = 0 and tm.encounter_id = e.encounter_id);
update temp_medication_orders tm set location_id = (select location_id from encounter e where voided = 0 and tm.encounter_id = e.encounter_id);
update temp_medication_orders tm set order_location = location_name(location_id);
update temp_medication_orders tm set user_entered = encounter_creator_name(encounter_id);
update temp_medication_orders tm set user_entered = encounter_creator_name(encounter_id);
update temp_medication_orders tm set order_drug = concept_name(concept_id, 'en');
update temp_medication_orders tm set order_formulation = (select name from drug d where d.concept_id = tm.concept_id);
/*
order_quantity
order_dose
order_dose_unit
order_route
order_frequency
order_reason
*/
select * from temp_medication_orders;
-- desc orders;
-- desc visit;
-- select * from obs where date_created like "%2023-02-10%";
-- encounter_id = 501667
