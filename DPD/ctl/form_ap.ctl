options (direct=true, errors=0, SKIP=1)
load data
infile 'form_ap.txt' 
truncate
into table FORM_AP
fields terminated by '\t' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   DRUG_CODE            NUMBER,
   PHARM_FORM_CODE      NUMBER,
   PHARMACEUTICAL_FORM  VARCHAR2(100 Byte)       
);
