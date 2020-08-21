Update of UMLS

Prerequisites:
- Created SOURCES schema.
- Working directory UMLS.

1. Run create_source_tables.sql
2. Download Full UMLS Release Files (for example umls-YYYYAA-full.zip) from http://www.nlm.nih.gov/research/umls/licensedcontent/umlsknowledgesources.html
3. Unpack files
MRCONSO.RRF
MRHIER.RRF
MRMAP.RRF
MRSMAP.RRF
MRSAT.RRF
MRREL.RRF
MRSTY.RRF

4. Run in devv5 (with fresh vocabulary date): SELECT sources.load_input_tables('UMLS',TO_DATE('20180507','YYYYMMDD'),'2018AA');
