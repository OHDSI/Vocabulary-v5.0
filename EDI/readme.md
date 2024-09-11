Update of EDI

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory dev_edi.

1. Run create_source_tables.sql
2. Run edi_refresh.sql
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();