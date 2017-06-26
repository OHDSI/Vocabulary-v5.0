options (direct=true, errors=0, SKIP=1)
load data
infile 'prev_rtc.txt' 
truncate
into table PREV_RTC
fields terminated by '\t' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   CONCEPT_CODE_1      VARCHAR2(255 Byte),
   CONCEPT_NAME_1      VARCHAR2(255 Byte),
   CONCEPT_CLASS_ID_1  VARCHAR2(255 Byte),
   CONCEPT_ID_2        NUMBER,
   CONCEPT_NAME_2      VARCHAR2(255 Byte),
   CONCEPT_CODE_2      VARCHAR2(255 Byte),
   INVALID_REASON_2    VARCHAR2(1 Byte),
   PRECEDENCE          NUMBER,
   CONVERSION_FACTOR   NUMBER     
);
