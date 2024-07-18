Update of EORTC

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory EORTC.

1. Run create_source_tables.sql
1. Run the EORTC_IL_SCRAPER
   1. The Item Library Web-Site version dated Spring-2024 was used for Scraper set-up;
   2. The Credentials are linked to OHDSI Vocabulary Account (permission from EORTC team was recieved via e-mail)
3. Run load_stage.sql
4. Run generic_update: devv5.GenericUpdate();