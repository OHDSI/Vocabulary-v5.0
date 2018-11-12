Update of CDM

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory CDM.

1. Run create_source_tables.sql
2. Go to https://api.github.com/repos/OHDSI/CommonDataModel/releases and select the release
3. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('CDM',current_date, json_build_object('version','CDM v5.0.0','published_at','2014-11-11T02:10:58'::timestamp,'node_id','MDc6UmVsZWFzZTY5MzgzMw==')::text);
4. Run load_stage.sql
5. Run generic_update.sql (from working directory)