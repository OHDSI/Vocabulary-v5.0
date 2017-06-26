options (direct=true, errors=0, SKIP=1)
load data
infile 'status.txt' 
truncate
into table STATUS_ACT
fields terminated by '\t' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   DRUG_CODE            VARCHAR2(255 Byte),
   CURRENT_STATUS_FLAG  VARCHAR2(255 Byte),
   STATUS               VARCHAR2(255 Byte),
   HISTORY_DATE         DATE       
);

