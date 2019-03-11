1.Run fast_recreate_schema.sql in dev_rxe schema

2.Run Create_Rxfix.sql

3.Run create_unput_t(vN).sql

4.Run drug_stage_tables_QA.sql from working directory

5.Run Build_RxE.sql 
 
6.Run CreateNewVocabulary_QA.sql

7.Run Attribute_repl.sql (if needed)

8.Run After_Build_RxE.sql

9.Run generic_update: devv5.GenericUpdate();

10.Run
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.pConceptAncestor(IS_SMALL=>TRUE);
END $_$;

11.Run Basic_tables_QA.sql
