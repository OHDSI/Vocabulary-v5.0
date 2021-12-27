### Update of LOINC

#### Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- SNOMED must be loaded first
- Working directory LOINC.

#### Sequence of actions

##### Source filling
1. Run create_source_tables.sql
2. Download full set (https://loinc.org/file-access/download-id/8960)
and multiaxial hierarchy (https://loinc.org/file-access/download-id/8991)
3. Extract loinc.csv, map_to.csv, source_organization.csv and LOINC_XXX_MULTI-AXIAL_HIERARCHY.CSV. LOINC_XXX_MULTI-AXIAL_HIERARCHY.CSV should be renamed to LOINC_MULTI-AXIAL_HIERARCHY.CSV
4. Download LOINC_XXX_PanelsAndForms.zip from https://loinc.org/file-access/download-id/8987/, extract LOINC_XXX_PanelsAndForms.csv and rename to LOINC_PanelsAndForms.csv
5. Download "LOINC/SNOMED CT Expression Association and Map Sets File" (xSnomedCT_LOINC_Beta_YYYYMMDDTXXXXXX.zip) from https://loinc.org/file-access/download-id/9516/ (NOTE! The file is no longer available!)
6. Extract \Full\Refset\Content\der2_sscccRefset_LOINCExpressionAssociationFull_INT_xxxxxxxx.txt and rename to der2_sscccRefset_LOINCExpressionAssociationFull_INT.txt
7. Extract \Full\Refset\Content\der2_scccRefset_LOINCMapCorrelationOriginFull_INT_xxxxxxxx.txt and rename to der2_scccRefset_LOINCMapCorrelationOriginFull_INT.txt
8. Download LNCxxx_TO_CPT2005_MAPPINGS.zip from http://www.nlm.nih.gov/research/umls/mapping_projects/loinc_to_cpt_map.html
9. Extract MRSMAP.RRF and rename to CPT_MRSMAP.RRF
10. Download "LOINC Answer File" from https://loinc.org/file-access/download-id/17950/, extract AnswerList.csv and LoincAnswerListLink.csv
11. Put loinc_class.csv from \vocabulary-v5.0\LOINC\ into your upload folder
12. Download "LOINC Document Ontology" https://loinc.org/file-access/download-id/8994/, extract DocumentOntology.csv
13. Download "LOINC Group File" https://loinc.org/file-access/download-id/17949/, extract Group.csv, GroupLoincTerms.csv and ParentGroupAttributes.csv
14. Download "LOINC Part File" https://loinc.org/file-access/download-id/17948/, extract LoincPartLink_Supplementary.csv, LoincPartLink_Primary.csv and Part.csv
15. Download "LOINC/RSNA Radiology Playbook File" https://loinc.org/file-access/download-id/9526/, extract LoincRsnaRadiologyPlaybook.csv
16. Run in devv5 (with fresh vocabulary date and version):
```sql
SELECT sources.load_input_tables('LOINC',TO_DATE('20180615','YYYYMMDD'),'LOINC 2.64');
```

##### Filling stage and basic tables
17. Run the FULL FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> true,
                                include_deprecated_rels=> true, include_synonyms=> true);
```
18. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/LOINC/load_stage.sql)
19. Run check_stage_tables function (should retrieve NULL):
```sql
SELECT * FROM qa_tests.check_stage_tables();
```
20. Run generic_update:
```sql
SELECT devv5.GenericUpdate();
```
21. Run basic tables check (should retrieve NULL):
```sql
SELECT * FROM qa_tests.get_checks();
```
22. Perform manual work described in the [readme.md](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/LOINC/manual_work/readme.md) in the manual_work folder
23. Repeat 1 - 6 steps
24. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql)
25. Run [project_specific_manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/LOINC/manual_work/project_specific_manual_checks_after_generic.sql)
26. Run all standard checks after generic to collect statistics and summary.
27. If no problems, enjoy!