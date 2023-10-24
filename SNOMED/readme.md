Update of SNOMED

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- Working directory SNOMED.

1. Run create_source_tables.sql
2. Download the international SNOMED file SnomedCT_InternationalRF2_Production_YYYYMMDDTzzzzzz.zip (RF2 Release) from https://www.nlm.nih.gov/healthit/snomedct/international.html.
3. Extract the following files from the folder \Full\Terminology:  
sct2_Concept_Full_INT_YYYYMMDD.txt  
sct2_Description_Full-en_INT_YYYYMMDD.txt  
sct2_Relationship_Full_INT_YYYYMMDD.txt  

from the folder \Full\Refset\Map  
der2_sRefset_SimpleMapFull_INT_YYYYMMDD.txt

from the folder \Full\Refset\Language  
der2_cRefset_LanguageFull-en_INT_YYYYMMDD.txt

from the folder \Full\Refset\Metadata  
der2_ssRefset_ModuleDependencyFull_INT_YYYYMMDD.txt

Rename files to sct2_Concept_Full_INT.txt, sct2_Description_Full-en_INT.txt, sct2_Relationship_Full_INT.txt, der2_sRefset_SimpleMapFull_INT.txt, der2_cRefset_LanguageFull_INT.txt, der2_ssRefset_ModuleDependencyFull_INT.txt

4. Download the British SNOMED file uk_sct2cl_xx.x.x__YYYYMMDD000001.zip from https://isd.digital.nhs.uk/trud3/user/authenticated/group/0/pack/26/subpack/101/releases.
5. Extract the following files from the folder SnomedCT_UKClinicalRF2_Production_YYYYMMDDTzzzzzz\Full\Terminology into a working folder:  
sct2_Concept_Full_GB1000000_YYYYMMDD.txt  
sct2_Description_Full-en-GB_GB1000000_YYYYMMDD.txt  
sct2_Relationship_Full-GB_GB1000000_YYYYMMDD.txt  

from the folder \Full\Refset\Language  
der2_cRefset_LanguageFull-en-GB_GB1000000_YYYYMMDD.txt

from the folder \Full\Refset\Metadata  
der2_ssRefset_ModuleDependencyFull_GB1000000_YYYYMMDD.txt

Rename files to sct2_Concept_Full-UK.txt, sct2_Description_Full-UK.txt, sct2_Relationship_Full-UK.txt, der2_cRefset_LanguageFull_UK.txt, der2_ssRefset_ModuleDependencyFull_UK.txt

6. Download the US SNOMED file SnomedCT_ManagedServiceUS_PRODUCTION_USxxxxxxx_YYYYMMDDT120000Z.zip from https://www.nlm.nih.gov/healthit/snomedct/us_edition.html
7. Extract the following files from the folder \Full\Terminology\ into a working folder:  
sct2_Concept_Full_US1000124_YYYYMMDD.txt  
sct2_Description_Full-en_US1000124_YYYYMMDD.txt  
sct2_Relationship_Full_US1000124_YYYYMMDD.txt  

from the folder \Full\Refset\Language  
der2_cRefset_LanguageFull-en_US1000124_YYYYMMDD.txt

from the folder \Full\Refset\Metadata  
der2_ssRefset_ModuleDependencyFull_US1000124_YYYYMMDD.txt

from the folder \Full\Refset\Map  
der2_iisssccRefset_ExtendedMapFull_US1000124_YYYYMMDD.txt

Remove date from file name and rename to sct2_Concept_Full_US.txt, sct2_Description_Full-en_US.txt, sct2_Relationship_Full_US.txt, der2_cRefset_LanguageFull_US.txt, der2_ssRefset_ModuleDependencyFull_US.txt, der2_iisssccRefset_ExtendedMapFull_US.txt

8. Download the UK SNOMED CT Drug Extension, RF2 file uk_sct2dr_xx.x.x__YYYYMMDD000001.zip from https://isd.digital.nhs.uk/trud3/user/authenticated/group/0/pack/26/subpack/105/releases
9. Extract the following files from the folder SnomedCT_UKDrugRF2_Production_20180516T000001Z\Full\Terminology\ into a working folder:  
sct2_Concept_Full_GB1000000_YYYYMMDD.txt  
sct2_Description_Full-en-GB_GB1000000_YYYYMMDD.txt  
sct2_Relationship_Full_GB1000000_YYYYMMDD.txt  

from the folder \Full\Refset\Language  
der2_cRefset_LanguageFull-en-GB_GB1000001_YYYYMMDD.txt

from the folder \Full\Refset\Metadata  
der2_ssRefset_ModuleDependencyFull_GB1000001_YYYYMMDD.txt

Rename files to sct2_Concept_Full_GB_DE.txt, sct2_Description_Full-en-GB_DE.txt, sct2_Relationship_Full_GB_DE.txt, der2_cRefset_LanguageFull_GB_DE.txt, der2_ssRefset_ModuleDependencyFull_GB_DE.txt

10. Extract
- der2_cRefset_AssociationFull_INT_YYYYMMDD.txt from SnomedCT_InternationalRF2_Production_YYYYMMDDTzzzzzz\Full\Refset\Content
- der2_cRefset_AssociationUKCLFull_GBxxxxxxx_YYYYMMDD.txt from uk_sct2cl_xx.x.x__YYYYMMDD000001\SnomedCT_UKClinicalRF2_Production_YYYYMMDDTzzzzzz\Full\Refset\Content
- der2_cRefset_AssociationFull_USxxxxxxx_YYYYMMDD.txt from SnomedCT_USEditionRF2_PRODUCTION_YYYYMMDDTzzzzzz\Full\Refset\Content
- der2_cRefset_AssociationUKDGFull_GBxxxxxxx_YYYYMMDD.txt from SnomedCT_UKDrugRF2_Production_YYYYMMDDTzzzzzz\Full\Refset\Content
Rename to der2_cRefset_AssociationFull_INT.txt, der2_cRefset_AssociationFull_UK.txt, der2_cRefset_AssociationFull_US.txt and der2_cRefset_AssociationFull_GB_DE.txt

11. Extract
- der2_cRefset_AttributeValueFull_INT_YYYYMMDD.txt from SnomedCT_InternationalRF2_Production_YYYYMMDDTzzzzzz\Full\Refset\Content
- der2_cRefset_AttributeValueUKCLFull_GBxxxxxxx_YYYYMMDD.txt from uk_sct2cl_xx.x.x__YYYYMMDD000001\SnomedCT_UKClinicalRF2_Production_YYYYMMDDTzzzzzz\Full\Refset\Content
- der2_cRefset_AttributeValueFull_USxxxxxxx_YYYYMMDD.txt from SnomedCT_USEditionRF2_PRODUCTION_YYYYMMDDTzzzzzz\Full\Refset\Content
- der2_cRefset_AttributeValueUKDGFull_GBxxxxxxx_YYYYMMDD.txt from SnomedCT_UKDrugRF2_Production_YYYYMMDDTzzzzzz\Full\Refset\Content
Rename to der2_cRefset_AttributeValueFull_INT.txt, der2_cRefset_AttributeValueFull_UK.txt, der2_cRefset_AttributeValueFull_US.txt and der2_cRefset_AttributeValue_GB_DE.txt

12. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('SNOMED',TO_DATE('20180131','YYYYMMDD'),'Snomed Release 20180131');
13. Run 
```sql
SELECT devv5.FastRecreateSchema(main_schema_name=>'devv5', include_concept_ancestor=> true, include_deprecated_rels=> true, include_synonyms=> true);
   ```
14. Run AddPeaks.sql if any changes in peaks are necessary.

15. Run load_stage.sql
```sql

DO $$
BEGIN
	PERFORM sources_archive.ResetArchiveParams();
END $$;

DO $$
BEGIN
	PERFORM sources_archive.SetArchiveParams(
		'SNOMED',
		TO_DATE('20220128','yyyymmdd')
	);
END $$;

SELECT * FROM sources_archive.ShowArchiveParams();

SELECT admin_pack.VirtualLogIn('dev_mkhitrun','MKh_388646467');
   ```
16. Run generic_update:
   ```sql
   DO $_$
   BEGIN
       PERFORM devv5.GenericUpdate();
   END $_$;
   ```
17. Run basic tables check (should retrieve NULL):
   ```sql
    SELECT * FROM qa_tests.get_checks();
```
18. Perform manual work described in the readme.md file in the 'manual_work' folder.

Repeat steps 13-18.

19. Run vocabulary-specific QA from 'specific_qa' folder.

20. Run scripts to get summary, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_summary('concept')
    where vocabulary_id_1 = 'SNOMED';
    SELECT DISTINCT * FROM qa_tests.get_summary('concept_relationship')
    where vocabulary_id_1 in ('SNOMED', 'dm+d')
    and vocabulary_id_2 in ('SNOMED', 'dm+d');
    ```
21. Run scripts to collect statistics, and interpret the results:
    ```sql
    SELECT DISTINCT * FROM qa_tests.get_domain_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts();
    SELECT DISTINCT * FROM qa_tests.get_standard_concept_changes();
    SELECT DISTINCT * FROM qa_tests.get_newly_concepts_standard_concept_status();
    SELECT DISTINCT * FROM qa_tests.get_changes_concept_mapping();
    ```
22. If no problems, enjoy!