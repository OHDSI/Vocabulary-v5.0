CREATE UNLOGGED TABLE cde_manual_group(
	sorce_code character varying(10),
	sorce_code_description character varying(255),
	sorce_vocabulary_id character varying(20),
	group_id integer,
	group_name character varying(255),
	group_code character varying []
	);
		
CREATE SEQUENCE seq_cde_manual_group_id INCREMENT 1 START 1 NO CYCLE;