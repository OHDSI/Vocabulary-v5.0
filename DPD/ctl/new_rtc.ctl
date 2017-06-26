options (direct=true, errors=0, SKIP=1)
load data
infile 'dose_form_spring_DPD.txt' 
truncate
into table NEW_RTC
fields terminated by '\t' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   CONCEPT_NAME_1      VARCHAR2(255 Byte),
   CONCEPT_CLASS_ID_1  VARCHAR2(255 Byte),
   CONCEPT_ID_2        NUMBER,
   CONCEPT_NAME_2      VARCHAR2(255 Byte),
   INVALID_REASON_2    VARCHAR2(255 Byte),
   PRECEDENCE          VARCHAR2(255 Byte),
   CONVERSION_FACTOR   VARCHAR2(255 Byte)      
);
