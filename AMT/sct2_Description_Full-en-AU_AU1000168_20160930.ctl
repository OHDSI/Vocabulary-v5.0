options (direct=true, errors=0, SKIP=1)
load data
infile 'sct2_Description_Full-en-AU_AU1000168_20160930.csv' 
truncate
into table FULL_DESCR_DRUG_ONLY
fields terminated by ';' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   ID                  VARCHAR2(255 Byte),
   EFFECTIVETIME       VARCHAR2(255 Byte),
   ACTIVE              VARCHAR2(255 Byte),
   MODULEID            VARCHAR2(255 Byte),
   CONCEPTID           VARCHAR2(255 Byte),
   LANGUAGECODE        VARCHAR2(255 Byte),
   TYPEID              VARCHAR2(255 Byte),
   TERM                VARCHAR2(1555 Byte),
   CASESIGNIFICANCEID  VARCHAR2(255 Byte)  
);

