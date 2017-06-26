options (direct=true, errors=0, SKIP=1)
load data
infile 'package_ia.txt' 
truncate
into table PACKAGING_IA
fields terminated by '\t' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   DRUG_CODE            NUMBER,
   UPC                  VARCHAR2(12 Byte),
   PACKAGE_SIZE_UNIT    VARCHAR2(40 Byte),
   PACKAGE_TYPE         VARCHAR2(40 Byte),
   PACKAGE_SIZE         VARCHAR2(5 Byte),
   PRODUCT_INFORMATION  VARCHAR2(80 Byte)        
);