options (direct=true, errors=0, SKIP=1)
load data
infile 'new_pack.txt' 
truncate
into table NEW_PACK
fields terminated by '\t' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   CONCEPT_CODE       VARCHAR2(30 Byte),
   AIC                VARCHAR2(240 Byte),
   CONCEPT_NAME       VARCHAR2(240 Byte),
   INGREDIENT         VARCHAR2(240 Byte),
   AMOUNT_VALUE       VARCHAR2(20 Byte),
   AMOUNT_UNIT        VARCHAR2(40 Byte),
   DENOMINATOR_VALUE  VARCHAR2(40 Byte),
   DENOMINATOR_UNIT   VARCHAR2(40 Byte),
   NUMERATOR_VALUE    VARCHAR2(20 Byte),
   NUMERATOR_UNIT     VARCHAR2(40 Byte),
   NOTES              VARCHAR2(2000 Byte),
   DRUG_CODE          VARCHAR2(10 Byte),
   BRAND_NAME         VARCHAR2(200 Byte),
   NUMBER_OF_AIS      VARCHAR2(10 Byte),
   INVALID_REASON     VARCHAR2(255 Byte)       
);
