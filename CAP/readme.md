Update of CAP

Prerequisites:
- Schema DevV5 with copies of tables concept, concept_relationship and concept_synonym from ProdV5, fully indexed.
- Working directory CAP.

1. Run create_source_tables.sql
2. Get the latest CAP eCC zip-file, extract all xml files from the folder "eCC - All Current Files"
3. Create index file cap_allxmlfilelist.dat:
cd /path/to/input/folder/
find . -maxdepth 1 -name "*.xml" > cap_allxmlfilelist.dat

4. Run in devv5 (with fresh vocabulary date and version): SELECT sources.load_input_tables('CAP',TO_DATE('20200226','YYYYMMDD'),'CAP eCC release 20200226');
5. Run load_stage.sql
6. Run generic_update: devv5.GenericUpdate();