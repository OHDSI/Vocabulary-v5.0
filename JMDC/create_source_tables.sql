
create table jmdc
(
	drug_code varchar(255),
	claim_code varchar(255),
	who_atc_code varchar(255),
	who_atc_name varchar(255),
	general_name varchar(255),
	brand_name varchar(255),
	standardized_unit varchar(100),
	frequency varchar(10),
	concept_id integer,
	concept_name varchar(255),
	concept_class_id varchar(20)
);
