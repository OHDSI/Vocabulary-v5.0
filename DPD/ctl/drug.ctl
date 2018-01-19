options (direct=true, errors=0, SKIP=1)
load data
infile 'drug.txt' 
truncate
into table drug_act
fields terminated by '\t' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   DRUG_CODE                   NUMBER,
   PRODUCT_CATEGORIZATION      VARCHAR2(80 Byte),
   CLASS                       VARCHAR2(40 Byte),
   DRUG_IDENTIFICATION_NUMBER  VARCHAR2(200 Byte),
   BRAND_NAME                  VARCHAR2(200 Byte),
   DESCRIPTOR                  VARCHAR2(200 Byte),
   PEDIATRIC_FLAG              VARCHAR2(1 Byte),
   ACCESSION_NUMBER            VARCHAR2(5 Byte),
   NUMBER_OF_AIS               VARCHAR2(10 Byte),
   LAST_UPDATE_DATE            DATE,
   AI_GROUP_NO                 VARCHAR2(10 Byte)          
);