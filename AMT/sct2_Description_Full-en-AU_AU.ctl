options (direct=true, errors=0, SKIP=1)
load data
infile 'sct2_Description_Full-en-AU_AU.csv' 
truncate
into table FULL_DESCR_DRUG_ONLY
fields terminated by ';' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   ID                  CHAR(255 Byte),
   EFFECTIVETIME       CHAR(255 Byte),
   ACTIVE              CHAR(255 Byte),
   MODULEID            CHAR(255 Byte),
   CONCEPTID           CHAR(255 Byte),
   LANGUAGECODE        CHAR(255 Byte),
   TYPEID              CHAR(255 Byte),
   TERM                CHAR(1555 Byte),
   CASESIGNIFICANCEID  CHAR(255 Byte)  
);

