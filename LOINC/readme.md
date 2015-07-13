Update of LOINC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Working directory LOINC.

1. Run create_source_tables.sql
2. Download full set (http://loinc.org/downloads/files/loinc-table-csv-text-format/loinc-table-file-csv-text-format/download)
and multiaxial hierarchy (http://loinc.org/downloads/files/loinc-multiaxial-hierarchy/loinc-multiaxial-hierarchy-file/download)
3. Extract loinc.csv, map_to.csv, source_organization.csv and LOINC_250_MULTI-AXIAL_HIERARCHY.CSV
4. Load them into LOINC, MAP_TO, SOURCE_ORGANIZATION and LOINC_HIERARCHY. Use the control files of the same name.
5. Load LOINC Answers and LOINC Forms - Load LOINC_XXX_PanelsAndForms.zip from http://loinc.org/downloads/files/loinc-panels-and-forms-file/loinc-panels-and-forms-file-all-selected-panels-and-forms/download
6. Open LOINC_XXX_PanelsAndForms.xlsx and load worksheet "ANSWERS" to table LOINC_ANSWERS (clear columns after DisplayText, save as Unicode text (UTF-8 w/o BOM) and use loinc_answers.ctl),
worksheet "FORMS" to table LOINC_FORMS (clear columns after Loinc, save as Unicode text (UTF-8 w/o BOM) and use loinc_forms.ctl)
7. Open loinc_class.csv and load him into table loinc_class
8. Download SnomedCT_LOINC_TechnologyPreview_INT_xxxxxxxx.zip from https://loinc.org/news/draft-loinc-snomed-ct-mappings-and-expression-associations-now-available.html
9. Extract \RF2Release\Full\Refset\Content\xder2_scccRefset_MapCorrelationOriginFull_INT_xxxxxxxx.txt
10. Load him into scccRefset_MapCorrOrFull_INT using xder2_scccRefset_MapCorrelationOriginFull_INT.ctl
11. Download LNCxxx_TO_CPT2005_MAPPINGS.zip from http://www.nlm.nih.gov/research/umls/mapping_projects/loinc_to_cpt_map.html
12. Extract MRSMAP.RRF and load into CPT_MRSMAP using CPT_MRSMAP.ctl
13. Run load_stage.sql
14. Run generic_update.sql (from working directory)

 