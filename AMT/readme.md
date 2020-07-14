AMT readme
update of amt

1. Run fastRecreteSchema:
 SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5');
 This will create copies of tables concept, concept_relationship and concept_synonym in working schema
2. Run load_stage_1.sql
3. Run load_stage_1-2.sql
4. Rerun load_stage_1.sql
5. Run load_stage_2.sql
6. Run input tables checks: input_QA_integratable_E.sql
7. Run build_RxE.sql
8. Run stage_tables checks: drug_stage_tables_QA.sql
9. Run generic_update: devv5.GenericUpdate();
