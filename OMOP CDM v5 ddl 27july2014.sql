
/************************

script to create OMOP data model, version 5.0 for SQL Server database

last revised: 27 July 2014

author:  Patrick Ryan


*************************/


/************************

Standardized vocabulary

************************/


CREATE TABLE concept (
  concept_id			INTEGER			NOT NULL,
  concept_name		VARCHAR(255)	NOT NULL,
  primary_domain_id	VARCHAR(20)		NOT NULL,
  concept_class_id		VARCHAR(20)		NOT NULL,
  vocabulary_id		VARCHAR(20)		NOT NULL,
  standard_concept		VARCHAR(1)		NULL,
  concept_code		VARCHAR(50)		NOT NULL,
  valid_start_date		DATE			NOT NULL,
  valid_end_date	DATE			NOT NULL,
  invalid_reason	VARCHAR(1)		NULL
)
;

ALTER TABLE concept 
	ADD CONSTRAINT XPKconcept PRIMARY KEY (concept_id)
;




CREATE TABLE vocabulary (
  vocabulary_id			VARCHAR(20)		NOT NULL,
  vocabulary_name		VARCHAR(255)	NOT NULL,
  vocabulary_concept_id INTEGER NOT NULL,
  vocabulary_reference VARCHAR(255),
  vocabulary_version VARCHAR(255))
;

ALTER TABLE vocabulary 
	ADD CONSTRAINT XPKvocabulary_REF PRIMARY KEY (vocabulary_id)
;

CREATE TABLE domain (
  domain_id			VARCHAR(20)		NOT NULL,
  domain_name		VARCHAR(255)	NOT NULL,
  domain_concept_id INTEGER NOT NULL)
;

ALTER TABLE vocabulary 
	ADD CONSTRAINT XPKdomain_REF PRIMARY KEY (domain_id)
;

CREATE TABLE concept_class (
  concept_class_id			VARCHAR(20)		NOT NULL,
  concept_class_name		VARCHAR(255)	NOT NULL,
  concept_class_concept_id INTEGER NOT NULL)
;

ALTER TABLE concept_class 
	ADD CONSTRAINT XPKconcept_class_REF PRIMARY KEY (concept_class_id)
;



CREATE TABLE concept_relationship (
  concept_id_1			INTEGER		NOT NULL,
  concept_id_2			INTEGER		NOT NULL,
  relationship_id		INTEGER		NOT NULL,
  valid_start_date		DATE		NOT NULL,
  valid_end_date		DATE			NOT NULL,
  invalid_reason		VARCHAR(1)		NULL)
;

ALTER TABLE concept_relationship 
	ADD CONSTRAINT XPKconcept_relationship PRIMARY KEY (concept_id_1,concept_id_2,relationship_id)
;




CREATE TABLE relationship (
  relationship_id		INTEGER			NOT NULL,
  relationship_name		VARCHAR(255)	NOT NULL,
  is_hierarchical		VARCHAR(1)		NULL,
  defines_ancestry		VARCHAR(1)		NULL,
  relations_concept_id INTEGER NOT NULL)
;

ALTER TABLE relationship 
	ADD CONSTRAINT XPKrelationship_TYPE PRIMARY KEY (relationship_id)
;


CREATE TABLE concept_synonym (
  concept_synonym_id	INTEGER	NOT NULL,
  concept_id			INTEGER			NOT NULL,
  concept_synonym_name	VARCHAR(1000)	NOT NULL,
  language_concept_id	INTEGER			NOT NULL
)
;

ALTER TABLE concept_synonym
	ADD CONSTRAINT XPKconcept_synonym PRIMARY KEY (concept_synonym_id)
;



CREATE TABLE concept_ancestor (
  ancestor_concept_id		INTEGER		NOT NULL,
  descendant_concept_id		INTEGER	NOT NULL,
  min_levels_of_separation	INTEGER		NULL,
  max_levels_of_separation	INTEGER		NULL)
;

ALTER TABLE concept_ancestor 
	ADD CONSTRAINT XPKconcept_ancestor PRIMARY KEY (ancestor_concept_id,descendant_concept_id)
;



CREATE TABLE source_to_concept_map (
  source_code				VARCHAR(20)		NOT NULL,
  source_vocabulary_id		INTEGER	NOT NULL,
  source_code_description	VARCHAR(255) NULL,
  target_concept_id			INTEGER			NOT NULL,
  target_vocabulary_id		INTEGER		NOT NULL,
  mapping_type				VARCHAR(20)		NULL,
  primary_map				VARCHAR(1)		  NULL,
  valid_start_date			DATE			  NOT NULL,
  valid_end_date			DATE			    NOT NULL,
  invalid_reason			VARCHAR(1)		NULL)
;


ALTER TABLE source_to_concept_map 
	ADD CONSTRAINT XPKsource_to_concept_map PRIMARY KEY (source_vocabulary_id,target_concept_id,source_code,valid_end_date)
;



CREATE TABLE drug_strength (
  drug_concept_id			INTEGER		 NOT NULL,
  ingredient_concept_id		INTEGER	NOT NULL,
  amount_value				FLOAT		 NULL,
  amount_unit				VARCHAR(6)	NULL,
  concentration_value		FLOAT		NULL,
  concentration_enum_unit	 VARCHAR(60)	NULL,
  concentration_denom_unit	VARCHAR(60)	NULL,
  valid_start_date			    DATE		NOT NULL,
  valid_end_date			      DATE		NOT NULL,
  invalid_reason			      VARCHAR(1)	NULL)
;

ALTER TABLE drug_strength
	ADD CONSTRAINT XPKdrug_strength PRIMARY KEY (drug_concept_id, ingredient_concept_id)
;


CREATE TABLE cohort_definition (
  cohort_definition_id				INTEGER			 NOT NULL,
  cohort_definition_name			VARCHAR(255) NOT NULL,
  cohort_definition_description		        CLOB	NULL,
  definition_type_concept_id		INTEGER			NOT NULL,
  cohort_definition_syntax			           CLOB	NULL,
  execution_date					DATE			            NULL)
;

ALTER TABLE cohort_definition
	ADD CONSTRAINT XPKcohort_definition PRIMARY KEY (cohort_definition_id)
;



/**************************

Standardized meta-data

***************************/


CREATE TABLE cdm_source 
    (  
     cdm_source_name					VARCHAR(255)	NOT NULL,
	 cdm_source_abbreviation		VARCHAR(25)		NULL,
	 cdm_holder							    VARCHAR(255)	NULL,
	 source_description					CLOB	NULL,
	 source_documentation_reference		VARCHAR(255)	NULL,
	 cdm_etl_reference					VARCHAR(255)	NULL,
	 source_release_date				DATE			NULL,
	 cdm_release_date					  DATE			NULL,
	 cdm_version						    VARCHAR(10)		NULL,
	 vocabulary_version					VARCHAR(10)		NULL
    ) 
;







/************************

Standardized clinical data

************************/


CREATE TABLE person 
    (
     person_id						INTEGER		NOT NULL , 
     gender_concept_id		INTEGER		NOT NULL , 
     year_of_birth				INTEGER		NOT NULL , 
     month_of_birth				INTEGER		NULL, 
     day_of_birth					INTEGER		NULL, 
	 time_of_birth					TIME	NULL,
     race_concept_id			INTEGER		NULL, 
     ethnicity_concept_id			INTEGER		NULL, 
     location_id					INTEGER		NULL, 
     provider_id					INTEGER		NULL, 
     care_site_id					INTEGER		NULL, 
     person_source_value			VARCHAR(50) NULL, 
     gender_source_value			VARCHAR(50) NULL,
	 gender_source_concept_id		INTEGER		NULL, 
     race_source_value				VARCHAR(50) NULL, 
	 race_source_concept_id			INTEGER		NULL, 
     ethnicity_source_value			VARCHAR(50) NULL,
	 ethnicity_source_concept_id	INTEGER		NULL
    ) 
;

ALTER TABLE person 
    ADD CONSTRAINT PERSON_PK PRIMARY KEY ( person_id ) ;





CREATE TABLE observation_period 
    ( 
     observation_period_id				INTEGER		NOT NULL , 
     person_id							INTEGER		NOT NULL , 
     observation_period_start_date		DATE		NOT NULL , 
     observation_period_end_date		DATE		NOT NULL ,
	 period_type_concept_id				INTEGER		NOT NULL
    ) 
;

ALTER TABLE observation_period 
    ADD CONSTRAINT observation_period_PK PRIMARY KEY ( observation_period_id ) ;




CREATE TABLE specimen
    ( 
     specimen_id					INTEGER		NOT NULL ,
	 person_id							INTEGER		NOT NULL ,
	 specimen_concept_id		INTEGER		NOT NULL ,
	 specimen_type_concept_id			INTEGER		NOT NULL ,
	 specimen_date					DATE		NOT NULL ,
	 specimen_time					TIME		NULL ,
	 quantity							  FLOAT			NULL ,
	 unit_concept_id					INTEGER			NULL ,
	 anatomic_site_concept_id			INTEGER			NULL ,
	 disease_status_concept_id			INTEGER			NULL ,
	 specimen_source_id					VARCHAR(50)		NULL ,
	 specimen_source_value			VARCHAR(50)		NULL ,
	 unit_source_value					VARCHAR(50)		NULL ,
	 anatomic_site_source_value			VARCHAR(50)		NULL ,
	 disease_status_source_value		VARCHAR(50)		NULL
	)
;

ALTER TABLE specimen
	ADD CONSTRAINT specimen_PK PRIMARY KEY ( specimen_id ) ;



CREATE TABLE death 
    ( 
     person_id							INTEGER			NOT NULL , 
     death_date							DATE			NOT NULL , 
     death_type_concept_id	INTEGER			NOT NULL , 
     cause_concept_id				INTEGER			NULL , 
     cause_source_value			VARCHAR(50)		NULL,
	 cause_source_concept_id	INTEGER			NULL
    ) 
;

ALTER TABLE death 
    ADD CONSTRAINT death_PK PRIMARY KEY ( person_id, death_type_concept_id ) ;



CREATE TABLE visit_occurrence 
    ( 
     visit_occurrence_id	INTEGER			NOT NULL , 
     person_id						INTEGER			NOT NULL , 
     visit_concept_id			INTEGER			NOT NULL , 
	 visit_start_date				DATE			NOT NULL , 
	 visit_start_time				TIME		NULL ,
     visit_end_date				DATE			NOT NULL ,
	 visit_end_time					TIME 		NULL , 
	 visit_type_concept_id	INTEGER			NOT NULL ,
	 provider_id					  INTEGER			NULL,
     care_site_id					INTEGER			NULL, 
     visit_source_value		VARCHAR(50)		NULL,
	 visit_source_concept_id		INTEGER			NULL
    ) 
;

ALTER TABLE visit_occurrence 
    ADD CONSTRAINT visit_occurrence_PK PRIMARY KEY ( visit_occurrence_id ) ;





CREATE TABLE procedure_occurrence 
    ( 
     procedure_occurrence_id		INTEGER			NOT NULL , 
     person_id						      INTEGER			NOT NULL , 
     procedure_concept_id			  INTEGER			NOT NULL , 
     procedure_date					    DATE			NOT NULL , 
     procedure_type_concept_id	INTEGER			NOT NULL ,
	 qualifier_concept_id			    INTEGER			NULL ,
	 quantity						          INTEGER			NULL , 
     provider_id					      INTEGER			NULL , 
     visit_occurrence_id			  INTEGER			NULL , 
     procedure_source_value			VARCHAR(50)		NULL ,
	 procedure_source_concept_id	INTEGER			NULL ,
	 qualifier_source_value			VARCHAR(50)		NULL
    ) 
;

ALTER TABLE procedure_occurrence 
    ADD CONSTRAINT procedure_occurrence_PK PRIMARY KEY ( procedure_occurrence_id ) ;




CREATE TABLE drug_exposure 
    ( 
     drug_exposure_id				INTEGER			NOT NULL , 
     person_id						  INTEGER			NOT NULL , 
     drug_concept_id				INTEGER			NOT NULL , 
     drug_exposure_start_date		DATE			NOT NULL , 
     drug_exposure_end_date			DATE			NULL , 
     drug_type_concept_id			INTEGER			NOT NULL , 
     stop_reason					  VARCHAR(20)		NULL , 
     refills						    INTEGER			NULL , 
     quantity						    FLOAT 			NULL , 
     days_supply					  INTEGER			NULL , 
     sig							      VARCHAR(100)	NULL , 
	 route_concept_id				  INTEGER			NULL ,
	 effective_drug_dose			FLOAT			NULL ,
	 dose_unit_concept_id			INTEGER			NULL ,
	 lot_number						    VARCHAR(50)		NULL ,
     provider_id					  INTEGER			NULL , 
     visit_occurrence_id		INTEGER			NULL , 
     drug_source_value			VARCHAR(50)		NULL ,
	 drug_source_concept_id		INTEGER			NULL ,
	 route_source_value				VARCHAR(50)		NULL ,
	 dose_unit_source_value		VARCHAR(50)		NULL
    ) 
;

ALTER TABLE drug_exposure 
    ADD CONSTRAINT drug_exposure_PK PRIMARY KEY ( drug_exposure_id ) ;



CREATE TABLE device_exposure 
    ( 
     device_exposure_id		INTEGER			NOT NULL , 
     person_id						INTEGER			NOT NULL , 
     device_concept_id		INTEGER			NOT NULL , 
     device_exposure_start_date		DATE			NOT NULL , 
     device_exposure_end_date		  DATE			NULL , 
     device_type_concept_id			  INTEGER			NOT NULL , 
	 unique_device_id				VARCHAR(50)		NULL ,
	 quantity						    INTEGER			NULL ,
     provider_id					INTEGER			NULL , 
     visit_occurrence_id	INTEGER			NULL ,
     Condition_concept_id INTEGER NULL, 
     device_source_value			VARCHAR(50)	NULL ,
	 device_source_concept_id		INTEGER			NULL
    ) 
;

ALTER TABLE device_exposure 
    ADD CONSTRAINT device_exposure_PK PRIMARY KEY ( device_exposure_id ) ;



CREATE TABLE condition_occurrence 
    ( 
     condition_occurrence_id		INTEGER			NOT NULL , 
     person_id						      INTEGER			NOT NULL , 
     condition_concept_id			  INTEGER			NOT NULL , 
     condition_start_date			  DATE			NOT NULL , 
     condition_end_date				  DATE			NULL , 
     condition_type_concept_id	INTEGER			NOT NULL , 
     stop_reason					      VARCHAR(20)		NULL , 
     provider_id					      INTEGER			NULL , 
     visit_occurrence_id			  INTEGER			NULL , 
     condition_source_value			VARCHAR(50)		NULL ,
	 condition_source_concept_id	INTEGER			NULL
    ) 
;

ALTER TABLE condition_occurrence 
    ADD CONSTRAINT condition_occurrence_PK PRIMARY KEY ( condition_occurrence_id ) ;




CREATE TABLE measurement 
    ( 
     measurement_id					INTEGER			NOT NULL , 
     person_id						  INTEGER			NOT NULL , 
     measurement_concept_id			INTEGER			NOT NULL , 
     measurement_date				DATE			NOT NULL , 
     measurement_time				TIME		NULL ,
	 measurement_type_concept_id	INTEGER			NOT NULL ,
	 operator_concept_id			INTEGER		NULL , 
     value_as_number				FLOAT			NULL , 
     value_as_concept_id		INTEGER			NULL , 
     unit_concept_id				INTEGER			NULL , 
     range_low						  FLOAT			NULL , 
     range_high						  FLOAT			NULL ,
     abnormal_value         CHAR(1)   NULL, 
     provider_id					  INTEGER			NULL , 
     visit_occurrence_id		INTEGER			NULL ,  
     measurement_source_value		VARCHAR(50)		NULL , 
	 measurement_source_concept_id	INTEGER			NULL ,
     unit_source_value			VARCHAR(50)		NULL ,
	 value_source_value				VARCHAR(50)		NULL
    ) 
;

ALTER TABLE measurement 
    ADD CONSTRAINT measurement_PK PRIMARY KEY ( measurement_id ) ;




CREATE TABLE note 
    ( 
     note_id						INTEGER			NOT NULL , 
     person_id					INTEGER			NOT NULL , 
     note_date					DATE			NOT NULL ,
	 note_time						TIME  	NULL ,
	 note_concept_id			INTEGER			NOT NULL ,
	 note_text						CLOB	NOT NULL ,
     provider_id				INTEGER			NULL ,
      note_source_value	VARCHAR(50)		NULL, 
	 visit_occurrence_id	INTEGER			NULL 	
    ) 
;

ALTER TABLE note 
    ADD CONSTRAINT note_PK PRIMARY KEY ( note_id ) ;



CREATE TABLE observation 
    ( 
     observation_id				INTEGER			NOT NULL , 
     person_id						INTEGER			NOT NULL , 
     observation_concept_id			INTEGER			NOT NULL , 
     observation_date			DATE			NOT NULL , 
     observation_time			TIME 		NULL , 
     observation_type_concept_id	INTEGER			NOT NULL , 
	 value_as_number				FLOAT			NULL , 
     value_as_string			VARCHAR(60)		NULL , 
     value_as_concept_id	INTEGER			NULL , 
	 qualifier_concept_id		INTEGER			NULL ,
     unit_concept_id			INTEGER			NULL , 
     provider_id					INTEGER			NULL , 
     visit_occurrence_id			INTEGER			NULL , 
     observation_source_value		VARCHAR(50)		NULL ,
	 observation_source_concept_id	INTEGER			NULL , 
     unit_source_value				VARCHAR(50)		NULL ,
	 qualifier_source_value			VARCHAR(50)		NULL
    ) 
;

ALTER TABLE observation 
    ADD CONSTRAINT observation_PK PRIMARY KEY ( observation_id ) ;


CREATE TABLE fact_relationship 
    ( 
     domain_concept_id_1		INTEGER			NOT NULL , 
	 fact_id_1						    INTEGER			NOT NULL ,
	 domain_concept_id_2			INTEGER			NOT NULL ,
	 fact_id_2						    INTEGER			NOT NULL ,
	 relationship_concept_id	 INTEGER			NOT NULL
	)
;




/************************

Standardized health system data

************************/



CREATE TABLE location 
    ( 
     location_id			INTEGER			NOT NULL , 
     address_1				VARCHAR(50)		NULL , 
     address_2				VARCHAR(50)		NULL , 
     city							VARCHAR(50)		NULL , 
     state						VARCHAR(2)		NULL , 
     zip							VARCHAR(9)		NULL , 
     county						VARCHAR(20)		NULL , 
     location_source_value			VARCHAR(50)		NULL
    ) 
;

ALTER TABLE location 
    ADD CONSTRAINT location_PK PRIMARY KEY ( location_id ) ;



CREATE TABLE care_site 
    ( 
     care_site_id						        INTEGER			NOT NULL , 
     care_site_name                 VARCHAR(50) NULL, 
     place_of_service_concept_id		INTEGER			NULL ,
     location_id						INTEGER			NULL , 
     care_site_source_value				  VARCHAR(50)		NULL , 
     place_of_service_source_value	VARCHAR(50)		NULL
    ) 
;

ALTER TABLE care_site 
    ADD CONSTRAINT care_site_PK PRIMARY KEY ( care_site_id ) ;



	
CREATE TABLE provider 
    ( 
     provider_id					INTEGER			NOT NULL , 
     provider_name        VARCHAR(50) NULL, 
     NPI							    VARCHAR(20)		NULL , 
     DEA							    VARCHAR(20)		NULL , 
     specialty_concept_id			INTEGER			NULL , 
     care_site_id					INTEGER			NULL , 
	 year_of_birth					INTEGER			NULL ,
	 gender_concept_id			INTEGER			NULL ,
     provider_source_value			VARCHAR(50)		NULL , 
     specialty_source_value			VARCHAR(50)		NULL , 
     speciality_source_concept_id INTEGER NULL, 
	 gender_source_value			VARCHAR(50)		NULL, 
   gender_source_concept_id INTEGER NULL
    ) 
;

ALTER TABLE provider 
    ADD CONSTRAINT provider_PK PRIMARY KEY ( provider_id ) ;





/************************

Standardized health economics

************************/


CREATE TABLE payer_plan_period 
    ( 
     payer_plan_period_id			INTEGER			NOT NULL , 
     person_id						INTEGER			NOT NULL , 
     payer_plan_period_start_date	DATE			NOT NULL , 
     payer_plan_period_end_date		DATE			NOT NULL , 
     payer_source_value				VARCHAR (50)	NULL , 
     plan_source_value				VARCHAR (50)	NULL , 
     family_source_value			VARCHAR (50)	NULL 
    ) 
;

ALTER TABLE payer_plan_period 
    ADD CONSTRAINT payer_plan_period_PK PRIMARY KEY ( payer_plan_period_id ) ;



CREATE TABLE visit_cost 
    ( 
     visit_cost_id					INTEGER			NOT NULL , 
     visit_occurrence_id		INTEGER			NOT NULL , 
	 currency_concept_id			INTEGER			NULL ,
     paid_copay						  FLOAT			NULL , 
     paid_coinsurance				FLOAT			NULL , 
     paid_toward_deductible	FLOAT			NULL , 
     paid_by_payer					FLOAT			NULL , 
     paid_by_coordination_benefits	FLOAT			NULL , 
     total_out_of_pocket		FLOAT			NULL , 
     total_paid						  FLOAT			NULL ,  
     payer_plan_period_id		 INTEGER			NULL
    ) 
;

ALTER TABLE visit_cost 
    ADD CONSTRAINT visit_cost_PK PRIMARY KEY ( visit_cost_id ) ;




CREATE TABLE procedure_cost 
    ( 
     procedure_cost_id				INTEGER			NOT NULL , 
     procedure_occurrence_id		INTEGER			NOT NULL , 
     currency_concept_id			INTEGER			NULL ,
     paid_copay						    FLOAT			NULL , 
     paid_coinsurance				  FLOAT			NULL , 
     paid_toward_deductible		FLOAT			NULL , 
     paid_by_payer					  FLOAT			NULL , 
     paid_by_coordination_benefits	FLOAT			NULL , 
     total_out_of_pocket			FLOAT			NULL , 
     total_paid						    FLOAT			NULL , 
     revenue_code_concept_id INTEGER NULL, 
     payer_plan_period_id			INTEGER			NULL,
     revenue_code_source_value VARCHAR(50) NULL
	) 
;

ALTER TABLE procedure_cost 
    ADD CONSTRAINT procedure_cost_PK PRIMARY KEY ( procedure_cost_id ) ;


CREATE TABLE drug_cost 
    (
     drug_cost_id					  INTEGER			NOT NULL , 
     drug_exposure_id				INTEGER			NOT NULL , 
     currency_concept_id		INTEGER			NULL ,
     paid_copay						  FLOAT			NULL , 
     paid_coinsurance				FLOAT			NULL , 
     paid_toward_deductible	FLOAT			NULL , 
     paid_by_payer					FLOAT			NULL , 
     paid_by_coordination_benefits	FLOAT			NULL , 
     total_out_of_pocket		FLOAT			NULL , 
     total_paid						  FLOAT			NULL , 
     ingredient_cost				FLOAT			NULL , 
     dispensing_fee					FLOAT			NULL , 
     average_wholesale_price		FLOAT			NULL , 
     payer_plan_period_id			INTEGER			NULL
    ) 
;


ALTER TABLE drug_cost 
    ADD CONSTRAINT drug_cost_PK PRIMARY KEY ( drug_cost_id ) ;





CREATE TABLE device_cost 
    (
     device_cost_id					INTEGER			NOT NULL , 
     device_exposure_id			INTEGER			NOT NULL , 
     currency_concept_id		INTEGER			NULL ,
     paid_copay						  FLOAT			NULL , 
     paid_coinsurance				FLOAT			NULL , 
     paid_toward_deductible			FLOAT			NULL , 
     paid_by_payer					FLOAT			NULL , 
     paid_by_coordination_benefits	FLOAT			NULL , 
     total_out_of_pocket		FLOAT			NULL , 
     total_paid						FLOAT			NULL , 
     payer_plan_period_id			INTEGER			NULL
    ) 
;


ALTER TABLE device_cost 
    ADD CONSTRAINT device_cost_PK PRIMARY KEY ( device_cost_id ) ;




/************************

Standardized derived elements

************************/

CREATE TABLE cohort 
    ( 
     cohort_id						INTEGER			NOT NULL , 
     cohort_definition_id			INTEGER			NOT NULL , 
     cohort_start_date				DATE			NOT NULL , 
     cohort_end_date				DATE			NULL , 
     subject_id						INTEGER			NOT NULL , 
     stop_reason					VARCHAR (20)	NULL
    ) 
;

ALTER TABLE cohort 
    ADD CONSTRAINT cohort_PK PRIMARY KEY ( cohort_id ) ;




CREATE TABLE drug_era 
    ( 
     drug_era_id					  INTEGER			NOT NULL , 
     person_id						  INTEGER			NOT NULL , 
     drug_concept_id				INTEGER			NOT NULL , 
     drug_era_start_date			DATE			NOT NULL , 
     drug_era_end_date				DATE			NOT NULL , 
     drug_exposure_count			INTEGER			NULL ,
	 gap_days						INTEGER			NULL
    ) 
;

ALTER TABLE drug_era 
    ADD CONSTRAINT drug_era_PK PRIMARY KEY ( drug_era_id ) ;



CREATE TABLE dose_era 
    (
     dose_era_id					INTEGER			NOT NULL , 
     person_id						INTEGER			NOT NULL , 
     drug_concept_id			INTEGER			NOT NULL , 
	 unit_concept_id				INTEGER			NOT NULL ,
	 dose_value						  FLOAT			NOT NULL ,
     dose_era_start_date			DATE			NOT NULL , 
     dose_era_end_date				DATE			NOT NULL 
    ) 
;

ALTER TABLE dose_era 
    ADD CONSTRAINT dose_era_PK PRIMARY KEY ( dose_era_id ) ;




CREATE TABLE condition_era 
    ( 
     condition_era_id				INTEGER			NOT NULL , 
     person_id						INTEGER			NOT NULL , 
     condition_concept_id			INTEGER			NOT NULL , 
     condition_era_start_date		DATE			NOT NULL , 
     condition_era_end_date			DATE			NOT NULL , 
     condition_occurrence_count		INTEGER			NULL
    ) 
;

ALTER TABLE condition_era 
    ADD CONSTRAINT condition_era_PK PRIMARY KEY ( condition_era_id ) ;








