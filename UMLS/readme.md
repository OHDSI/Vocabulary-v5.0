Update of UMLS

Prerequisites:
- Created UMLS schema.
- Working directory UMLS.

1. Run create_source_tables.sql
2. Download YYYYab-1-meta.nlm (for example 2014ab-1-meta.nlm) from http://www.nlm.nih.gov/research/umls/licensedcontent/umlsknowledgesources.html.
3. Unpack 
MRCONSO.RRF.aa.gz 
MRCONSO.RRF.ab.gz 
MRHIER.RRF.aa.gz
MRHIER.RRF.ab.gz
MRMAP.RRF.gz
MRREL.RRF.aa.gz
MRREL.RRF.ab.gz
MRREL.RRF.ac.gz
MRREL.RRF.ad.gz
MRSMAP.RRF.gz

then run:
--gunzip *.gz
--cat MRCONSO.RRF.aa MRCONSO.RRF.ab > MRCONSO.RRF
--cat MRHIER.RRF.aa MRHIER.RRF.ab > MRHIER.RRF
--cat MRREL.RRF.aa MRREL.RRF.ab MRREL.RRF.ac MRREL.RRF.ad > MRREL.RRF

4. Load them into tables using control files of the same name
