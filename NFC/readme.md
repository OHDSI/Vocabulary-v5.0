Update of NFC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory NFC.

1. Run create_source_tables.sql
2. Load file nfc.txt into NFC table. Use the control files of the same name.
3. Run load_stage.sql (with updated pVocabularyDate = latest update of vocabulary)
4. Run generic_update.sql (from working directory)

 