create table adt_encounters
(
	emr_id               varchar(15),
    encounter_id         varchar(255),
    visit_id             varchar(255),
    encounter_datetime   datetime,
    user_entered         varchar(255),
    datetime_created     datetime,
    encounter_type       varchar(255),
    encounter_location   varchar(255),
    provider             varchar(255),
    index_asc            int,
    index_desc           int
);
