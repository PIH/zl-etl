create table mch_delivery
(
    dossierId                            varchar(50),
    emr_id                               varchar(50),
    loc_registered                       varchar(255),
    encounter_datetime                   datetime,
    encounter_location                   varchar(255),
    encounter_type                       varchar(255),
    date_entered                         datetime,
    provider                             varchar(255),
    encounter_id                         varchar(25),
    delivery_datetime                    datetime,
    partogram_completed                  bit,
    dystocia                             varchar(255),
    prolapsed_cord                       varchar(255),
    Postpartum_hemorrhage                varchar(10),
    Intrapartum_hemorrhage               varchar(10),
    Placental_abruption                  varchar(10),
    Placenta_praevia                     varchar(10),
    Rupture_of_uterus                    varchar(10),
    Other_hemorrhage                     varchar(10),
    Other_hemorrhage_details             varchar(255),
    late_cord_clamping                   varchar(255),
    placenta_delivery                    varchar(255),
    AMTSL                                varchar(255),
    Placenta_completeness                varchar(255),
    Intact_membranes                     varchar(255),
    Retained_placenta                    varchar(255),
    Perineal_laceration                  varchar(255),
    Perineal_suture                      varchar(255),
    Episiotomy                           varchar(255),
    Postpartum_blood_loss                varchar(255),
    Transfusion                          varchar(255),
    Type_of_delivery                     TEXT,
    c_section_maternal_reasons           varchar(300),
    other_c_section_maternal_reasons     text,
    c_section_fetal_reasons              varchar(255),
    other_c_section_fetal_reason         text,
    c_section_obstetrical_reasons        varchar(255),
    other_c_section_obstetrical_reason   text,
    Caesarean_hysterectomy               varchar(10),
    C_section_with_tubal_ligation        varchar(10),
    baby_Malpresentation_of_fetus        varchar(10),
    baby_Cephalopelvic_disproportion     varchar(10),
    baby_Extreme_premature               varchar(10),
    baby_Very_premature                  varchar(10),
    baby_Moderate_to_late_preterm        varchar(10),
    baby_Respiratory_distress            varchar(10),
    baby_Birth_asphyxia                  varchar(10),
    baby_Acute_fetal_distress            varchar(10),
    baby_Intrauterine_growth_retardation varchar(10),
    baby_Congenital_malformation         varchar(10),
    baby_Meconium_aspiration             varchar(10),
    mom_Premature_rupture_of_membranes   varchar(10),
    mom_Chorioamnionitis                 varchar(10),
    mom_Placental_abnormality            varchar(10),
    mom_Hypertension                     varchar(10),
    mom_Severe_pre_eclampsia             varchar(10),
    mom_Eclampsia                        varchar(10),
    mom_Acute_pulmonary_edema            varchar(10),
    mom_Puerperal_infection              varchar(10),
    mom_Victim_of_GBV                    varchar(10),
    mom_Herpes_simplex                   varchar(10),
    mom_Syphilis                         varchar(10),
    mom_Other_STI                        varchar(10),
    mom_Other_finding                    varchar(10),
    mom_Other_finding_details            varchar(255),
    Mental_health_assessment             TEXT,
    Birth_1_outcome                      varchar(255),
    Birth_1_weight                       decimal(12, 10),
    Birth_1_APGAR                        int,
    Birth_1_neonatal_resuscitation       varchar(255),
    Birth_1_macerated_fetus              varchar(255),
    Birth_2_outcome                      varchar(255),
    Birth_2_weight                       decimal(12, 10),
    Birth_2_APGAR                        int,
    Birth_2_neonatal_resuscitation       varchar(255),
    Birth_2_macerated_fetus              varchar(255),
    Birth_3_outcome                      varchar(255),
    Birth_3_weight                       decimal(12, 10),
    Birth_3_APGAR                        int,
    Birth_3_neonatal_resuscitation       varchar(255),
    Birth_3_macerated_fetus              varchar(255),
    Birth_4_outcome                      varchar(255),
    Birth_4_weight                       decimal(12, 10),
    Birth_4_APGAR                        int,
    Birth_4_neonatal_resuscitation       varchar(255),
    Birth_4_macerated_fetus              varchar(255),
    number_prenatal_visits               int,
    referred_by                          TEXT,
    referred_by_other_details            varchar(255),
    nutrition_newborn_counseling         varchar(255),
    family_planning_after_delivery       varchar(255),
    diagnosis_1                          varchar(255),
    diagnosis_1_confirmed                varchar(255),
    diagnosis_1_primary                  varchar(255),
    diagnosis_2                          varchar(255),
    diagnosis_2_confirmed                varchar(255),
    diagnosis_2_primary                  varchar(255),
    diagnosis_3                          varchar(255),
    diagnosis_3_confirmed                varchar(255),
    diagnosis_3_primary                  varchar(255),
    diagnosis_4                          varchar(255),
    diagnosis_4_confirmed                varchar(255),
    diagnosis_4_primary                  varchar(255),
    diagnosis_5                          varchar(255),
    diagnosis_5_confirmed                varchar(255),
    diagnosis_5_primary                  varchar(255),
    diagnosis_6                          varchar(255),
    diagnosis_6_confirmed                varchar(255),
    diagnosis_6_primary                  varchar(255),
    diagnosis_7                          varchar(255),
    diagnosis_7_confirmed                varchar(255),
    diagnosis_7_primary                  varchar(255),
    diagnosis_8                          varchar(255),
    diagnosis_8_confirmed                varchar(255),
    diagnosis_8_primary                  varchar(255),
    diagnosis_9                          varchar(255),
    diagnosis_9_confirmed                varchar(255),
    diagnosis_9_primary                  varchar(255),
    diagnosis_10                         varchar(255),
    diagnosis_10_confirmed               varchar(255),
    diagnosis_10_primary                 varchar(255),
    disposition                          varchar(255),
    disposition_comment                  text,
    return_visit_date                    datetime
);
