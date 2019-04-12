1. Run script below for create relationship_to_concept_manual once:

create table relationship_to_concept_manual
	(
		source_attr_name varchar(255),
		source_attr_concept_class varchar(50),
		target_concept_id integer,
		target_concept_code varchar(50),
		target_concept_name varchar(255),
		precedence integer,
		conversion_factor float,
		indicator_rxe varchar(10)
	);

2. Insert to relationship_to_concept_manual with data after mannual mapping