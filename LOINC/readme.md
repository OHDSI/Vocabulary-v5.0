Update of LOINC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Working directory LOINC.

1. Run create_source_tables.sql
2. Download full set (https://loinc.org/file-access/download-id/8960)
and multiaxial hierarchy (https://loinc.org/file-access/download-id/8991)
3. Extract loinc.csv, map_to.csv, source_organization.csv and LOINC_XXX_MULTI-AXIAL_HIERARCHY.CSV
4. Load them into LOINC, MAP_TO, SOURCE_ORGANIZATION and LOINC_HIERARCHY. Use the control files of the same name.
5. Load LOINC Answers and LOINC Forms - Load LOINC_XXX_PanelsAndForms.zip from https://loinc.org/file-access/download-id/8987/
6. Open LOINC_XXX_PanelsAndForms.xlsx and load worksheet "ANSWERS" to table LOINC_ANSWERS (clear columns after DisplayText, save as single xlsx-file, go to https://convertio.co/ and convert to unicode csv-file. Then load using LOINC_ANSWERS.ctl), worksheet "FORMS" to table LOINC_FORMS (clear columns after Loinc, save as Unicode text (UTF-8 w/o BOM) and use loinc_forms.ctl)
7. Open loinc_class.csv and load him into table loinc_class
8. Download "LOINC/SNOMED CT Expression Association and Map Sets File" (xSnomedCT_LOINC_Beta_YYYYMMDDTXXXXXX.zip) from https://loinc.org/file-access/download-id/9516/
9. Extract \Full\Refset\Content\xder2_sscccRefset_LOINCExpressionAssociationFull_INT_xxxxxxxx.txt and rename to xder2_sscccRefset_LOINCExpressionAssociationFull_INT.txt
10. Load him into scccRefset_MapCorrOrFull_INT using xder2_sscccRefset_LOINCExpressionAssociationFull_INT.ctl
11. Download LNCxxx_TO_CPT2005_MAPPINGS.zip from http://www.nlm.nih.gov/research/umls/mapping_projects/loinc_to_cpt_map.html
12. Extract MRSMAP.RRF and load into CPT_MRSMAP using CPT_MRSMAP.ctl
13. Run load_stage.sql (with updated pVocabularyDate = latest update of vocabulary)
14. Run generic_update.sql (from working directory)

 