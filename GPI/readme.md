Update of GPI

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed. 
- RxNorm must be loaded first.
- Fresh concept_ancestor.
- Working directory GPI.

1. Run create_source_tables.sql
2. Unzip ndw_v_product and gpi_name from the gpi.zip
3. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('GPI',TO_DATE('20150506','YYYYMMDD'),'RXNORM CROSS REFERENCE 15.2.1.002');
4. Run load_stage.sql
5. Run generic_update: devv5.GenericUpdate();