Update of Nebraska Lexicon

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory Nebraska Lexicon.

1. Run create_source_tables.sql
2. Download the Nebraska Lexicon Publication_Files_YYYYMMDD.zip from https://www.unmc.edu/pathology-research/bioinformatics/campbell/tdc.html
3. Extract the following files from the folder \RF2Release\Terminology\:
- sct2_Concept_Snapshot_1000004_YYYYMMDD.txt
- sct2_Description_Snapshot-en_1000004_YYYYMMDD.txt
- sct2_Relationship_Snapshot_1000004_YYYYMMDD.txt
Rename files to sct2_Concept.txt, sct2_Description.txt, sct2_Relationship.txt

4. Extract der2_cRefset_AssociationSnapshot_1000004_YYYYMMDD.txt from \RF2Release\Refset\Content\
Rename to der2_cRefset_Association.txt

5. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('Nebraska Lexicon',TO_DATE('20190816','YYYYMMDD'),'Nebraska Lexicon 20190816');
6. Run load_stage.sql
7. Run generic_update: devv5.GenericUpdate();