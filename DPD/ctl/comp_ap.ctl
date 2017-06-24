options (direct=true, errors=0, SKIP=1)
load data
infile 'comp_ap.txt' 
truncate
into table COMPANIES_AP
fields terminated by '\t' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   DRUG_CODE                  NUMBER,
   MFR_CODE                   VARCHAR2(5 Byte),
   COMPANY_CODE               NUMBER(6),
   COMPANY_NAME               VARCHAR2(80 Byte),
   COMPANY_TYPE               VARCHAR2(40 Byte),
   ADDRESS_MAILING_FLAG       VARCHAR2(1 Byte),
   ADDRESS_BILLING_FLAG       VARCHAR2(1 Byte),
   ADDRESS_NOTIFICATION_FLAG  VARCHAR2(1 Byte),
   ADDRESS_OTHER              VARCHAR2(1 Byte),
   SUITE_NUMBER               VARCHAR2(20 Byte),
   STREET_NAME                VARCHAR2(80 Byte),
   CITY_NAME                  VARCHAR2(60 Byte),
   PROVINCE                   VARCHAR2(40 Byte),
   COUNTRY                    VARCHAR2(40 Byte),
   POSTAL_CODE                VARCHAR2(20 Byte),
   POST_OFFICE_BOX            VARCHAR2(15 Byte)        
);
