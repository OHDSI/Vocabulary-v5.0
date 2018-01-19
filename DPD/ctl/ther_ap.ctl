options (direct=true, errors=0, SKIP=1)
load data
infile 'ther_ap.txt' 
truncate
into table THERAPEUTIC_CLASS_AP
fields terminated by '\t' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   DRUG_CODE       NUMBER,
   TC_ATC_NUMBER   VARCHAR2(8 Byte),
   TC_ATC          VARCHAR2(120 Byte),
   TC_AHFS_NUMBER  VARCHAR2(20 Byte),
   TC_AHFS         VARCHAR2(80 Byte)       
);