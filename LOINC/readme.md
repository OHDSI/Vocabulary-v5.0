### Update of LOINC

#### Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- SNOMED must be loaded first.
- Working directory LOINC.

#### Sequence of actions

##### Source filling
1. Run create_source_tables.sql.
2. Download full set https://loinc.org/download/loinc-complete/ (all accessory files are included in a single archive)
3. Extract  
\LoincTable\Loinc.csv and rename to loinc.csv  
\LoincTable\Mapto.csv and rename to mapto.csv  
\LoincTable\SourceOrganization.csv and rename to sourceorganization.csv  
\AccessoryFiles\ComponentHierarchyBySystem\ComponentHierarchyBySystem.csv and rename to componenthierarchybysystem.csv  
\AccessoryFiles\PanelsAndForms\PanelsAndForms.csv and rename to panelsandforms.csv  
\AccessoryFiles\PanelsAndForms\AnswerList.csv and rename to answerlist.csv  
\AccessoryFiles\PanelsAndForms\LoincAnswerListLink.csv and rename to loincanswerlistlink.csv  
\AccessoryFiles\DocumentOntology\DocumentOntology.csv and rename to documentontology.csv  
\AccessoryFiles\GroupFile\Group.csv and rename to group.csv  
\AccessoryFiles\GroupFile\GroupLoincTerms.csv and rename to grouploincterms.csv  
\AccessoryFiles\GroupFile\ParentGroupAttributes.csv and rename to parentgroupattributes.csv  
\AccessoryFiles\PartFile\Part.csv and rename to part.csv  
\AccessoryFiles\PartFile\LoincPartLink_Supplementary.csv and rename to loincpartlink_supplementary.csv  
\AccessoryFiles\PartFile\LoincPartLink_Primary.csv and rename to loincpartlink_primary.csv  
\AccessoryFiles\LoincRsnaRadiologyPlaybook\LoincRsnaRadiologyPlaybook.csv and rename to loincrsnaradiologyplaybook.csv  
4. Download "LOINC/SNOMED CT Expression Association and Map Sets File" (xSnomedCT_LOINC_Beta_YYYYMMDDTXXXXXX.zip) from https://loinc.org/file-access/download-id/9516/ (NOTE! The file is no longer available!).
5. Extract \Full\Refset\Content\der2_sscccRefset_LOINCExpressionAssociationFull_INT_xxxxxxxx.txt and rename to der2_sscccRefset_LOINCExpressionAssociationFull_INT.txt.
6. Extract \Full\Refset\Content\der2_scccRefset_LOINCMapCorrelationOriginFull_INT_xxxxxxxx.txt and rename to der2_scccRefset_LOINCMapCorrelationOriginFull_INT.txt.
7. Download LNCxxx_TO_CPT2005_MAPPINGS.zip from http://www.nlm.nih.gov/research/umls/mapping_projects/loinc_to_cpt_map.html.
8. Extract MRSMAP.RRF and rename to cpt_mrsmap.rrf.
9. Put loinc_class.csv from \vocabulary-v5.0\LOINC\ into your upload folder.
10. Run in devv5 (with fresh vocabulary date and version):
```sql
SELECT sources.load_input_tables('LOINC',TO_DATE('20180615','YYYYMMDD'),'LOINC 2.64');
```

##### Filling stage and basic tables
11. Run FULL FastRecreate:
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> true,
                                include_deprecated_rels=> true, include_synonyms=> true);
```
12. Run [load_stage.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/LOINC/load_stage.sql).
13. Run check_stage_tables function (should retrieve NULL):
```sql
SELECT * FROM qa_tests.check_stage_tables();
```
14. Run generic_update:
```sql
DO $_$
BEGIN
	PERFORM devv5.GenericUpdate();
END $_$;
```
15. Run basic tables check (should retrieve NULL):
```sql
SELECT * FROM qa_tests.get_checks();
```
16. Perform manual work described in the [readme.md](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/LOINC/manual_work/readme.md) file in the 'manual_work' folder.

17. Repeat steps 11-15.

18. Clear cache:
```sql
SELECT * FROM qa_tests.purge_cache();
```
19. Run scripts to get summary, and interpret the results:
```sql
SELECT DISTINCT * FROM qa_tests.get_summary('concept');
```
```sql
SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship');
```
20. Run scripts to collect statistics, and interpret the results:
```sql
SELECT DISTINCT * FROM qa_tests.get_domain_changes();
```
```sql
SELECT DISTINCT * FROM qa_tests.get_newly_concepts();
```
```sql
SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes();
```
```sql
SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status();
```
```sql
SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping();
```

21. Run [manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/working/manual_checks_after_generic.sql), and interpret the results.
22. Run [project_specific_manual_checks_after_generic.sql](https://github.com/OHDSI/Vocabulary-v5.0/blob/master/LOINC/manual_work/project_specific_manual_checks_after_generic.sql), and interpret the results.
23. If no problems, enjoy!
