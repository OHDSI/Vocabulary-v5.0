Update of JMDC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.

1. Run create_source_tables.sql and additional_DDL.sql
2. Upload the source file in the JMDC table 
4. Run load_stage_1.sql. Before running the script, manually identify new packs and add them to aut_pc_stage table (ingredients,dose forms and dosages; brand names and suplliers if applicable)
Note, this script will create mappings of attributes using OHDSI vocabulary, if some attribure don't have equivalent by name (or some trick like precise ingrdient) it will pop up as a condidate for mapping even if was mapped in the previous release.
"_mapped" tables keep the mapping from the previous run, the load_stage_1.sql will delete/update target ingredients which become non-standard
5. Manually fill *_to_map tables and re-upload them as *_mm: ingredient_mm, bn_mm, supplier_mm 
Set precedence = -1 to make source drugs NOT to be linked to this attribure, and it will not be added as an OMOP concept
6. Run load_stage_2.sql
7. Run build_RxE.sql and generic_update: devv5.GenericUpdate();
