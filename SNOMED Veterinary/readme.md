Update of SNOMED Veterinary

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory SNOMED Veterinary.
- SNOMED must be loaded first.

1. Run create_source_tables.sql
2. Download the Veterinary Extension of SNOMED CT file SnomedCT_Release_VTSzzzzzzz_yyyymmdd.zip from https://vtsl.vetmed.vt.edu/extension/
3. Extract the following files from the folder \Full\Terminology:
- sct2_Concept_Full_VTS_YYYYMMDD.txt
- sct2_Description_Full_en_VTS_YYYYMMDD.txt
- sct2_Relationship_Full_VTS_YYYYMMDD.txt
Rename files to sct2_Concept_Full_VTS.txt, sct2_Description_Full_VTS.txt, sct2_Relationship_Full_VTS.txt

4. Extract der2_cRefset_AssociationReferenceFull_VTS_YYYYMMDD.txt from SnomedCT_Release_VTSzzzzzzz\Full\Refset\Content
Rename to der2_cRefset_AssociationFull_VTS.txt

5. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('SNOMED Veterinary',TO_DATE('20181001','YYYYMMDD'),'SNOMED Veterinary 20181001');
6. Run load_stage.sql
7. Run generic_update: devv5.GenericUpdate();