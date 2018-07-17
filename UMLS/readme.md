Update of UMLS

Prerequisites:
- Created SOURCES schema.
- Working directory UMLS.

1. Run create_source_tables.sql
2. Download umls-YYYYAB-full.zip (for example umls-2016AB-full.zip) from http://www.nlm.nih.gov/research/umls/licensedcontent/umlsknowledgesources.html
3. Unpack 
MRCONSO.RRF.*
MRHIER.RRF.*
MRMAP.RRF.*
MRSMAP.RRF.*
MRSAT.RRF.*
MRREL.RRF.*

then run in console:
gunzip *.gz && cat MRCONSO.RRF.* > MRCONSO.RRF && cat MRHIER.RRF.* > MRHIER.RRF && cat MRSAT.RRF.* > MRSAT.RRF && cat MRREL.RRF.* > MRREL.RRF && rm MRCONSO.RRF.* MRHIER.RRF.* MRSAT.RRF.* MRREL.RRF.*

4. Run in devv5 (with fresh vocabulary date): SELECT sources.load_input_tables('UMLS',TO_DATE('20180507','YYYYMMDD'),'2018AA');
