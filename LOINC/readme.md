Update of LOINC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Working directory LOINC.

1. Run create_source_tables.sql
2. Download full set (http://loinc.org/downloads/files/loinc-table-csv-text-format/loinc-table-file-csv-text-format/download)
and multiaxial hierarchy (http://loinc.org/downloads/files/loinc-multiaxial-hierarchy/loinc-multiaxial-hierarchy-file/download)
3. Extract loinc.csv, map_to.csv, source_organization.csv and LOINC_250_MULTI-AXIAL_HIERARCHY.CSV
4. Load them into LOINC, MAP_TO, SOURCE_ORGANIZATION and LOINC_HIERARCHY. Use the control files of the same name.
5. Load LOINC Answers - Load LOINC_XXX_SELECTED_FORMS.zip from http://loinc.org/downloads/files/loinc-panels-and-forms-file/loinc-panels-and-forms-file-all-selected-panels-and-forms/download
6. Open LOINC_XXX_SELECTED_FORMS.xlsx and load worksheet "ANSWERS" to table LOINC_ANSWERS
7. Open loinc_class.csv and load him into table loinc_class
8. Run load_stage.sql
9. Run generic_update.sql (from root directory)

 