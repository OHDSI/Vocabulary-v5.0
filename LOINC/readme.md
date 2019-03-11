Update of LOINC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Working directory LOINC.

1. Run create_source_tables.sql
2. Download full set (https://loinc.org/file-access/download-id/8960)
and multiaxial hierarchy (https://loinc.org/file-access/download-id/8991)
3. Extract loinc.csv, map_to.csv, source_organization.csv and LOINC_XXX_MULTI-AXIAL_HIERARCHY.CSV. LOINC_XXX_MULTI-AXIAL_HIERARCHY.CSV should be renamed to LOINC_MULTI-AXIAL_HIERARCHY.CSV
4. Download LOINC_XXX_PanelsAndForms.zip from https://loinc.org/file-access/download-id/8987/, extract LOINC_XXX_PanelsAndForms.csv and rename to LOINC_PanelsAndForms.csv
5. Download "LOINC/SNOMED CT Expression Association and Map Sets File" (xSnomedCT_LOINC_Beta_YYYYMMDDTXXXXXX.zip) from https://loinc.org/file-access/download-id/9516/
6. Extract \Full\Refset\Content\xder2_sscccRefset_LOINCExpressionAssociationFull_INT_xxxxxxxx.txt and rename to xder2_sscccRefset_LOINCExpressionAssociationFull_INT.txt
7. Download LNCxxx_TO_CPT2005_MAPPINGS.zip from http://www.nlm.nih.gov/research/umls/mapping_projects/loinc_to_cpt_map.html
8. Extract MRSMAP.RRF and rename to CPT_MRSMAP.RRF
9. Download "LOINC Answer File" from https://loinc.org/file-access/download-id/17950/, extract AnswerList.csv and LoincAnswerListLink.csv
10. Put loinc_class.csv from \vocabulary-v5.0\LOINC\ into your upload folder
11. Download "LOINC Document Ontology" https://loinc.org/file-access/download-id/8994/, extract DocumentOntology.csv
12. Download "LOINC Group File" https://loinc.org/file-access/download-id/17949/, extract Group.csv, GroupLoincTerms.csv and ParentGroupAttributes.csv
13. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('LOINC',TO_DATE('20180615','YYYYMMDD'),'LOINC 2.64');
14. Run load_stage.sql
15. Run generic_update: devv5.GenericUpdate();