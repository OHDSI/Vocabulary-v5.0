options (direct=true, errors=0, SKIP=1)
load data
infile 'pc_stage_manual.txt' 
truncate
into table PC_STAGE_MANUAL
fields terminated by '\t' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   CONCEPT_NAME_1  VARCHAR2(255 Byte),
   CONCEPT_NAME_2  VARCHAR2(1255 Byte),
   AMOUNT          VARCHAR2(255 Byte),
   BOX_SIZE        VARCHAR2(255 Byte)       
);
