Update of META

Prerequisites:
- Created sources schema.
- Working directory META.

1. Run create_source_tables.sql
2. Download NCI Metathesaurus Data File from https://evs.nci.nih.gov/metval
3. Unpack files from the META folder:
MRCONSO.RRF
MRHIER.RRF
MRMAP.RRF
MRSMAP.RRF
MRSAT.RRF
MRREL.RRF
MRSTY.RRF
MRDEF.RRF
MRSAB.RRF
NCIMEME_yyyymm_history.txt

4. Run in devv5 (with fresh vocabulary date): SELECT sources.load_input_tables('META',TO_DATE('202402','YYYYMMDD'),'META 202402');
