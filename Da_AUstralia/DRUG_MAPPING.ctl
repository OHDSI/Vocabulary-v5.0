options (direct=true, errors=0, SKIP=1)
load data
infile 'DRUG_MAPPING.csv' 
truncate
into table DRUG_MAPPING
fields terminated by ';' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   PRD_EID          CHAR(255 Byte),
   LPDORIGINALNAME  CHAR(255 Byte),
   FCC              CHAR(255 Byte),
   DESCRIPTION      CHAR(255 Byte),
   MANUFACTURER     CHAR(255 Byte),
   EPHMRA_ATC_CODE  CHAR(255 Byte),
   NFC_CODE         CHAR(255 Byte),
   PRD_NAME         CHAR(255 Byte),
   MAST_PRD_NAME    CHAR(255 Byte),
   WHO_ATC_EID      CHAR(255 Byte),
   PRD_DOSAGE       CHAR(255 Byte),
   UNIT             CHAR(255 Byte),
   PRD_DOSAGE2      CHAR(255 Byte),
   UNIT_ID2         CHAR(255 Byte),
   MOL_NAME         CHAR(255 Byte)
);