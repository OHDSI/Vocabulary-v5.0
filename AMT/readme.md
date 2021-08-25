AMT readme
update of amt

1. Run fastRecreteSchema:
 SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5');
 This will create copies of tables concept, concept_relationship and concept_synonym in working schema
2. Run load_stage_1.sql
3. Run vaccines.sql. Vaccines should be removed and processed manually then reinserted back with valid mappings
3.1 To get a list of attributes and vaccine-related concepts for manual mapping run auxiliary code/concepts_to_map.sql
3.2 Check manual mapping validity using auxiliary code/mm_checks.sql
4. Run load_stage_1-2.sql - inserts manually mapped concepts into tables
5. Rerun load_stage_1.sql - in order to remove manually mapped devices and zero-mapped concepts rerun whole vocab assembly again from load_stage_1
6. Rerun vaccines.sql.
7. Run load_stage_2.sql
8. Run input tables checks: input_QA_integratable_E.sql
9. Run build_RxE.sql
10. Run stage_tables checks: drug_stage_tables_QA.sql
11. Run generic_update: devv5.GenericUpdate();
