Update of UMLS

Prerequisites:
- Created UMLS schema.
- Working directory UMLS.

1. Run create_source_tables.sql
2. Download umls-YYYYAB-full.zip (for example umls-2016AB-full.zip) from http://www.nlm.nih.gov/research/umls/licensedcontent/umlsknowledgesources.html.
3. Unpack 
MRCONSO.RRF.aa.gz 
MRCONSO.RRF.ab.gz 
MRHIER.RRF.aa.gz
MRHIER.RRF.ab.gz
MRHIER.RRF.ac.gz
MRMAP.RRF.gz
MRSMAP.RRF.gz
MRSAT.RRF.aa.gz
MRSAT.RRF.ab.gz
MRSAT.RRF.ac.gz
MRSAT.RRF.ad.gz

then run in console:
--gunzip *.gz
--cat MRCONSO.RRF.aa MRCONSO.RRF.ab > MRCONSO.RRF
--cat MRHIER.RRF.aa MRHIER.RRF.ab  MRHIER.RRF.ac > MRHIER.RRF
--cat MRSAT.RRF.aa MRSAT.RRF.ab MRSAT.RRF.ac MRSAT.RRF.ad > MRSAT.RRF

4. Load them into tables using control files of the same name
