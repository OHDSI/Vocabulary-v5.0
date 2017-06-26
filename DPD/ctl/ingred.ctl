options (direct=true, errors=0, SKIP=1)
load data
infile 'ingred.txt' 
truncate
into table ACTIVE_INGREDIENTS_ACT
fields terminated by '\t' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   DRUG_CODE                NUMBER,
   ACTIVE_INGREDIENT_CODE   NUMBER,
   INGREDIENT               VARCHAR2(240 Byte),
   INGREDIENT_SUPPLIED_IND  VARCHAR2(1 Byte),
   STRENGTH                 VARCHAR2(20 Byte),
   STRENGTH_UNIT            VARCHAR2(40 Byte),
   STRENGTH_TYPE            VARCHAR2(40 Byte),
   DOSAGE_VALUE             VARCHAR2(20 Byte),
   BASE                     VARCHAR2(1 Byte),
   DOSAGE_UNIT              VARCHAR2(40 Byte),
   NOTES                    VARCHAR2(2000 Byte)
);
