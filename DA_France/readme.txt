1. Run manual_tables.sql to get source table and tables we created munualy (translation France concepts to English or mapping tables);

2. Run non_drug_concept_stage.sql to get list of non-drug concepts we need to exclude from standard tables;

3. Run standard_tables_creation.sql to get standard tables such as:
DRUG_CONCEPT_STAGE, RELATIONSHIP_TO_CONCEPT, INTERNAL_RELATIONSHIP_STAGE, DRUG_STRENGTH_STAGE.
Additional information about these tables you can get from http://www.ohdsi.org/web/wiki/doku.php?id=documentation:international_drugs;

4. Run complete_concept_stage_name.sql
Using tables with all generated classes create full names for concepts we have

!!! need script refactoring and manual tables work
