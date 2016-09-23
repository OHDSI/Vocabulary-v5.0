Update of SNOMED

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- Schema UMLS
- Working directory SNOMED.

1. Run create_source_tables.sql
2. Download the international SNOMED file SnomedCT_Release_INT_YYYYMMDD.zip (RF2 Release) from http://www.nlm.nih.gov/research/umls/licensedcontent/snomedctfiles.html.
2. Extract the release date from the file name.
3. Extract the following files from the folder SnomedCT_Release_INT_YYYYMMDD\Full\Terminology:
- sct2_Concept_Full_INT_YYYYMMDD.txt
- sct2_Description_Full-en_INT_YYYYMMDD.txt
- sct2_Relationship_Full_INT_YYYYMMDD.txt
Remove date from file name.
4. Load them into SCT2_CONCEPT_FULL_INT, SCT2_DESC_FULL_EN_INT and SCT2_RELA_FULL_INT. Use the control files of the same name.

5. Download the British SNOMED file uk_sct2clfull_xx.x.x__YYYYMMDD000001.zip from https://isd.hscic.gov.uk/trud3/user/authenticated/group/0/pack/26/subpack/102/releases.
6. Extract the release date from the file name.
7. Extract the following files from the folder SnomedCT_RF2Release_GB1000000_YYYYMMDD\Full\Terminology into a working folder:
- sct2_Concept_Full_GB1000000_YYYYMMDD.txt
- sct2_Description_Full-en-GB_GB1000000_YYYYMMDD.txt
- sct2_Relationship_Full-GB_GB1000000_YYYYMMDD.txt

Remove date from file name and rename to sct2_Concept_Full-UK.txt, sct2_Description_Full-UK.txt, sct2_Relationship_Full-UK.txt
8. Load them into SCT2_CONCEPT_FULL_UK, SCT2_DESC_FULL_UK, SCT2_RELA_FULL_UK. Use the control files in Vocabulary-v5.0\SNOMED

9. Extract der2_cRefset_AssociationReferenceFull_INT_YYYYMMDD.txt from SnomedCT_RF2Release_INT_YYYYMMDD\Full\Refset\Content 
and der2_cRefset_AssociationReferenceFull_GB1000000_YYYYMMDD.txt from SnomedCT_RF2Release_GB1000000_YYYYMMDD\Full\Refset\Content

Remove date from file name and rename to der2_cRefset_AssociationReferenceFull_UK.txt, der2_cRefset_AssociationReferenceFull_INT.txt
10. Load them into der2_cRefset_AssRefFull_INT and der2_cRefset_AssRefFull_UK.

11. Add DM+D: Download nhsbsa_dmd_X.X.X_xxxxxxxxxxxxxx.zip from https://isd.hscic.gov.uk/trud3/user/authenticated/group/0/pack/6/subpack/24/releases
12. Extract f_ampp2_xxxxxxx.xml, f_amp2_xxxxxxx.xml, f_vmpp2_xxxxxxx.xml, f_vmp2_xxxxxxx.xml, f_lookup2_xxxxxxx.xml, f_vtm2_xxxxxxx.xml and f_ingredient2_xxxxxxx.xml
13. Remove date and from dile name and load them into f_ampp2, f_amp2, f_vmpp2, f_vmp2, f_lookup2, f_vtm2 and f_ingredient2. Use the control files of the same name.
14. Download nhsbsa_dmdbonus_X.X.X_YYYYMMDDXXXXXX.zip from https://isd.hscic.gov.uk/trud3/user/authenticated/group/0/pack/6/subpack/25/releases
15. Extract weekXXYYYY-rX_X-BNF.zip/f_bnf1_XXXXXXX.xml and rename him to dmdbonus.xml
16. Load dmdbonus.xml using dmdbonus.ctl

17. Run load_stage.sql (with updated pVocabularyDate = latest update of vocabulary)
18. Run generic_update.sql (from working directory)

 