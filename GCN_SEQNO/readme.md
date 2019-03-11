Update of GCN_SEQNO

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- RxNorm must be loaded first.
- Working directory GCN_SEQNO.

1. Run create_source_tables.sql
2. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('GCNSEQNO',TO_DATE('20151119','YYYYMMDD'),'20151119 Release');
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();