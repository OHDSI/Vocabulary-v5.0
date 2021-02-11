
A. If you are gonna to ingest RxE concepts with their relationships and synonyms  manually use mini_load_stage with appropriate descriptions located in readme_for_manual_tables.md
B. If you are performing RxNorm_cleanup follow the steps below:

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

What this script does:
1. Clean up supplier names
2. Change non-valid forms and units (IU, precise forms that aren't used in RxNorm)
3. Remove close-dose duplicates (0.005 and 0.0053)
4. Add missing attributes
5. Fix issues like Aspirin / Aspirin Oral Tablet
Minor:
1. Remove all where there is less than total of 0.05 mL (occurred due to the previous wrong entries),
2. Delete wrong ingredients and brand names
3. Fix solid forms with denominator, % in amount etc.
4. Fix complicated dosages for specific forms (e.g. ACTUAT, cm)
