--create source tables--

CREATE TABLE FO_PRODUCT
(
   FO_PRD_ID              VARCHAR2(255 Byte),
   PRD_EID                VARCHAR2(255 Byte),
   PRD_NAME               VARCHAR2(255 Byte),
   MAST_PRD_NAME          VARCHAR2(255 Byte),
   INT_BRAND_NAME         VARCHAR2(255 Byte),
   DOSAGE                 VARCHAR2(255 Byte),
   DOSAGE_AS_TEXT         VARCHAR2(255 Byte),
   UNIT                   VARCHAR2(255 Byte),
   DOSAGE2                VARCHAR2(255 Byte),
   DOSAGE2_AS_TEXT        VARCHAR2(255 Byte),
   UNIT2                  VARCHAR2(255 Byte),
   DOSAGE3                VARCHAR2(255 Byte),
   DOSAGE3_AS_TEXT        VARCHAR2(255 Byte),
   UNIT3                  VARCHAR2(255 Byte),
   NBDOSE                 VARCHAR2(255 Byte),
   NBDOSE_AS_TEXT         VARCHAR2(255 Byte),
   GALENIC                VARCHAR2(255 Byte),
   NBDOSE2                VARCHAR2(255 Byte),
   NBDOSE2_AS_TEXT        VARCHAR2(255 Byte),
   GALENIC2               VARCHAR2(255 Byte),
   IS_PRD_REFUNDABLE      VARCHAR2(255 Byte),
   PRD_REFUNDABLE_RATE    VARCHAR2(255 Byte),
   PRD_PRICE              VARCHAR2(255 Byte),
   CANCELED_DAT           VARCHAR2(255 Byte),
   CREATION_DAT           VARCHAR2(255 Byte),
   MANUFACTURER_NAME      VARCHAR2(255 Byte),
   IS_GENERIC             VARCHAR2(255 Byte),
   IS_HOSP                VARCHAR2(255 Byte),
   PRD_START_DAT          VARCHAR2(255 Byte),
   PRD_END_DAT            VARCHAR2(255 Byte),
   REGROUPING_CODE        VARCHAR2(255 Byte),
   EPH_CODE               VARCHAR2(255 Byte),
   EPH_NAME               VARCHAR2(255 Byte),
   EPH_TYPE               VARCHAR2(255 Byte),
   EPH_STATE              VARCHAR2(255 Byte),
   MOL_EID                VARCHAR2(255 Byte),
   MOL_NAME               VARCHAR2(255 Byte),
   ATCCODE                VARCHAR2(255 Byte),
   ATC_NAME               VARCHAR2(255 Byte),
   ATC_MOL                VARCHAR2(255 Byte),
   ATC_TYPE               VARCHAR2(255 Byte),
   ATC_STATE              VARCHAR2(255 Byte),
   BNF_EID                VARCHAR2(255 Byte),
   BNF_NAME               VARCHAR2(255 Byte),
   VERSION                VARCHAR2(255 Byte),
   UPDATED                VARCHAR2(255 Byte),
   MIN_DOSAGE_BY_DAY_REF  VARCHAR2(255 Byte),
   MAX_DOSAGE_BY_DAY_REF  VARCHAR2(255 Byte),
   GAL_ID                 VARCHAR2(255 Byte),
   GAL_ID2                VARCHAR2(255 Byte),
   FIRST_PRD_DATE         VARCHAR2(255 Byte),
   FIRST_PRE_TRA_ID       VARCHAR2(255 Byte),
   FIRST_TRA_DATE         VARCHAR2(255 Byte),
   DDL_ID                 VARCHAR2(255 Byte),
   DDL_LBL                VARCHAR2(255 Byte),
   PRD_VAT                VARCHAR2(255 Byte),
   REGROUPING_CODE_2      VARCHAR2(255 Byte),
   GMP_ID                 VARCHAR2(255 Byte),
   PRD_ID_DC              VARCHAR2(255 Byte)
)
TABLESPACE USERS;


CREATE TABLE DRUG_MAPPING
(
   PRD_EID          VARCHAR2(255 Byte),
   LPDORIGINALNAME  VARCHAR2(255 Byte),
   FCC              VARCHAR2(255 Byte),
   DESCRIPTION      VARCHAR2(255 Byte),
   MANUFACTURER     VARCHAR2(255 Byte),
   EPHMRA_ATC_CODE  VARCHAR2(255 Byte),
   NFC_CODE         VARCHAR2(255 Byte),
   PRD_NAME         VARCHAR2(255 Byte),
   MAST_PRD_NAME    VARCHAR2(255 Byte),
   WHO_ATC_EID      VARCHAR2(255 Byte),
   PRD_DOSAGE       VARCHAR2(255 Byte),
   UNIT             VARCHAR2(255 Byte),
   PRD_DOSAGE2      VARCHAR2(255 Byte),
   UNIT_ID2         VARCHAR2(255 Byte),
   MOL_NAME         VARCHAR2(255 Byte)
)
TABLESPACE USERS;



CREATE TABLE FO_PRODUCT_p2
(
   FO_PRD_ID              VARCHAR2(255 Byte),
   PRD_EID                VARCHAR2(255 Byte),
   PRD_NAME               VARCHAR2(255 Byte),
   MAST_PRD_NAME          VARCHAR2(255 Byte),
   INT_BRAND_NAME         VARCHAR2(255 Byte),
   DOSAGE                 VARCHAR2(255 Byte),
   DOSAGE_AS_TEXT         VARCHAR2(255 Byte),
   UNIT                   VARCHAR2(255 Byte),
   DOSAGE2                VARCHAR2(255 Byte),
   DOSAGE2_AS_TEXT        VARCHAR2(255 Byte),
   UNIT2                  VARCHAR2(255 Byte),
   DOSAGE3                VARCHAR2(255 Byte),
   DOSAGE3_AS_TEXT        VARCHAR2(255 Byte),
   UNIT3                  VARCHAR2(255 Byte),
   NBDOSE                 VARCHAR2(255 Byte),
   NBDOSE_AS_TEXT         VARCHAR2(255 Byte),
   GALENIC                VARCHAR2(255 Byte),
   NBDOSE2                VARCHAR2(255 Byte),
   NBDOSE2_AS_TEXT        VARCHAR2(255 Byte),
   GALENIC2               VARCHAR2(255 Byte),
   IS_PRD_REFUNDABLE      VARCHAR2(255 Byte),
   PRD_REFUNDABLE_RATE    VARCHAR2(255 Byte),
   PRD_PRICE              VARCHAR2(255 Byte),
   CANCELED_DAT           VARCHAR2(255 Byte),
   CREATION_DAT           VARCHAR2(255 Byte),
   MANUFACTURER_NAME      VARCHAR2(255 Byte),
   IS_GENERIC             VARCHAR2(255 Byte),
   IS_HOSP                VARCHAR2(255 Byte),
   PRD_START_DAT          VARCHAR2(255 Byte),
   PRD_END_DAT            VARCHAR2(255 Byte),
   REGROUPING_CODE        VARCHAR2(255 Byte),
   EPH_CODE               VARCHAR2(255 Byte),
   EPH_NAME               VARCHAR2(255 Byte),
   EPH_TYPE               VARCHAR2(255 Byte),
   EPH_STATE              VARCHAR2(255 Byte),
   MOL_EID                VARCHAR2(255 Byte),
   MOL_NAME               VARCHAR2(255 Byte),
   ATCCODE                VARCHAR2(255 Byte),
   ATC_NAME               VARCHAR2(255 Byte),
   ATC_MOL                VARCHAR2(255 Byte),
   ATC_TYPE               VARCHAR2(255 Byte),
   ATC_STATE              VARCHAR2(255 Byte),
   BNF_EID                VARCHAR2(255 Byte),
   BNF_NAME               VARCHAR2(255 Byte),
   VERSION                VARCHAR2(255 Byte),
   UPDATED                VARCHAR2(255 Byte),
   MIN_DOSAGE_BY_DAY_REF  VARCHAR2(255 Byte),
   MAX_DOSAGE_BY_DAY_REF  VARCHAR2(255 Byte),
   GAL_ID                 VARCHAR2(255 Byte),
   GAL_ID2                VARCHAR2(255 Byte),
   FIRST_PRD_DATE         VARCHAR2(255 Byte),
   FIRST_PRE_TRA_ID       VARCHAR2(255 Byte),
   FIRST_TRA_DATE         VARCHAR2(255 Byte),
   DDL_ID                 VARCHAR2(255 Byte),
   DDL_LBL                VARCHAR2(255 Byte),
   PRD_VAT                VARCHAR2(255 Byte),
   REGROUPING_CODE_2      VARCHAR2(255 Byte),
   GMP_ID                 VARCHAR2(255 Byte),
   PRD_ID_DC              VARCHAR2(255 Byte)
)
;
CREATE TABLE DRUG_MAPPING_p2
(
   PRD_EID          VARCHAR2(255 Byte),
   LPDORIGINALNAME  VARCHAR2(255 Byte),
   FCC              VARCHAR2(255 Byte),
   DESCRIPTION      VARCHAR2(255 Byte),
   MANUFACTURER     VARCHAR2(255 Byte),
   EPHMRA_ATC_CODE  VARCHAR2(255 Byte),
   NFC_CODE         VARCHAR2(255 Byte),
   PRD_NAME         VARCHAR2(255 Byte),
   MAST_PRD_NAME    VARCHAR2(255 Byte),
   WHO_ATC_EID      VARCHAR2(255 Byte),
   PRD_DOSAGE       VARCHAR2(255 Byte),
   UNIT             VARCHAR2(255 Byte),
   PRD_DOSAGE2      VARCHAR2(255 Byte),
   UNIT_ID2         VARCHAR2(255 Byte),
   MOL_NAME         VARCHAR2(255 Byte)
);



create table fo_product_1_vs_2 as
select * from fo_product
union
select * from fo_product_p2;
create table drug_mapping_1_vs_2 as
select * from drug_mapping
union
select * from drug_mapping_p2;

drop table drugs;
create table drugs as
select distinct fo_prd_id,a.PRD_NAME,a.MAST_PRD_NAME,a.DOSAGE,a.UNIT,a.DOSAGE2,a.UNIT2,a.MOL_EID,a.MOL_NAME,b.MOL_NAME as MOL_NAME_2, ATCCODE,ATC_NAME,NFC_CODE,MANUFACTURER
from fo_product_1_vs_2 a full outer join drug_mapping_1_vs_2 b on a.prd_eid=b.prd_eid;

--next manipulation requires correct numbers--
update drugs 
set PRD_NAME=regexp_replace(PRD_NAME,',','.') where PRD_NAME is not null;




CREATE TABLE DRUG_MAPPING_3
(
   PRD_EID          VARCHAR2(255 Byte),
   LPDORIGINALNAME  VARCHAR2(255 Byte),
   FCC              VARCHAR2(255 Byte),
   DESCRIPTION      VARCHAR2(255 Byte),
   MANUFACTURER     VARCHAR2(255 Byte),
   EPHMRA_ATC_CODE  VARCHAR2(255 Byte),
   NFC_CODE         VARCHAR2(255 Byte),
   PRD_NAME         VARCHAR2(255 Byte),
   MAST_PRD_NAME    VARCHAR2(255 Byte),
   WHO_ATC_EID      VARCHAR2(255 Byte),
   PRD_DOSAGE       VARCHAR2(255 Byte),
   UNIT             VARCHAR2(255 Byte),
   PRD_DOSAGE2      VARCHAR2(255 Byte),
   UNIT_ID2         VARCHAR2(255 Byte),
   MOL_NAME         VARCHAR2(255 Byte)
)
TABLESPACE USERS;
WbImport -file=C:/Users/eallakhverdiiev/Desktop/AUSLOCAL/NEW SOURCE/drug_mapping.csv
         -type=text
         -table=DRUG_MAPPING_3
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter="';'"
         -decimal=.
         -fileColumns=PRD_EID,LPDORIGINALNAME,FCC,DESCRIPTION,MANUFACTURER,EPHMRA_ATC_CODE,NFC_CODE,PRD_NAME,MAST_PRD_NAME,WHO_ATC_EID,PRD_DOSAGE,UNIT,PRD_DOSAGE2,UNIT_ID2,MOL_NAME,$wb_skip$
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000;
         

CREATE TABLE FO_PRODUCT_3
(
   FO_PRD_ID              VARCHAR2(255 Byte),
   PRD_EID                VARCHAR2(255 Byte),
   PRD_NAME               VARCHAR2(255 Byte),
   MAST_PRD_NAME          VARCHAR2(255 Byte),
   INT_BRAND_NAME         VARCHAR2(255 Byte),
   DOSAGE                 VARCHAR2(255 Byte),
   DOSAGE_AS_TEXT         VARCHAR2(255 Byte),
   UNIT                   VARCHAR2(255 Byte),
   DOSAGE2                VARCHAR2(255 Byte),
   DOSAGE2_AS_TEXT        VARCHAR2(255 Byte),
   UNIT2                  VARCHAR2(255 Byte),
   DOSAGE3                VARCHAR2(255 Byte),
   DOSAGE3_AS_TEXT        VARCHAR2(255 Byte),
   UNIT3                  VARCHAR2(255 Byte),
   NBDOSE                 VARCHAR2(255 Byte),
   NBDOSE_AS_TEXT         VARCHAR2(255 Byte),
   GALENIC                VARCHAR2(255 Byte),
   NBDOSE2                VARCHAR2(255 Byte),
   NBDOSE2_AS_TEXT        VARCHAR2(255 Byte),
   GALENIC2               VARCHAR2(255 Byte),
   IS_PRD_REFUNDABLE      VARCHAR2(255 Byte),
   PRD_REFUNDABLE_RATE    VARCHAR2(255 Byte),
   PRD_PRICE              VARCHAR2(255 Byte),
   CANCELED_DAT           VARCHAR2(255 Byte),
   CREATION_DAT           VARCHAR2(255 Byte),
   MANUFACTURER_NAME      VARCHAR2(255 Byte),
   IS_GENERIC             VARCHAR2(255 Byte),
   IS_HOSP                VARCHAR2(255 Byte),
   PRD_START_DAT          VARCHAR2(255 Byte),
   PRD_END_DAT            VARCHAR2(255 Byte),
   REGROUPING_CODE        VARCHAR2(255 Byte),
   EPH_CODE               VARCHAR2(255 Byte),
   EPH_NAME               VARCHAR2(255 Byte),
   EPH_TYPE               VARCHAR2(255 Byte),
   EPH_STATE              VARCHAR2(255 Byte),
   MOL_EID                VARCHAR2(255 Byte),
   MOL_NAME               VARCHAR2(255 Byte),
   ATCCODE                VARCHAR2(255 Byte),
   ATC_NAME               VARCHAR2(255 Byte),
   ATC_MOL                VARCHAR2(255 Byte),
   ATC_TYPE               VARCHAR2(255 Byte),
   ATC_STATE              VARCHAR2(255 Byte),
   BNF_EID                VARCHAR2(255 Byte),
   BNF_NAME               VARCHAR2(255 Byte),
   VERSION                VARCHAR2(255 Byte),
   UPDATED                VARCHAR2(255 Byte),
   MIN_DOSAGE_BY_DAY_REF  VARCHAR2(255 Byte),
   MAX_DOSAGE_BY_DAY_REF  VARCHAR2(255 Byte),
   GAL_ID                 VARCHAR2(255 Byte),
   GAL_ID2                VARCHAR2(255 Byte),
   FIRST_PRD_DATE         VARCHAR2(255 Byte),
   FIRST_PRE_TRA_ID       VARCHAR2(255 Byte),
   FIRST_TRA_DATE         VARCHAR2(255 Byte),
   DDL_ID                 VARCHAR2(255 Byte),
   DDL_LBL                VARCHAR2(255 Byte),
   PRD_VAT                VARCHAR2(255 Byte),
   REGROUPING_CODE_2      VARCHAR2(255 Byte),
   GMP_ID                 VARCHAR2(255 Byte),
   PRD_ID_DC              VARCHAR2(255 Byte)
)
TABLESPACE USERS;

WbImport -file=C:/Users/eallakhverdiiev/Desktop/AUSLOCAL/NEW SOURCE/fo_product.csv
         -type=text
         -table=FO_PRODUCT_3
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter="';'"
         -decimal=.
         -fileColumns=FO_PRD_ID,PRD_EID,PRD_NAME,MAST_PRD_NAME,INT_BRAND_NAME,DOSAGE,DOSAGE_AS_TEXT,UNIT,DOSAGE2,DOSAGE2_AS_TEXT,UNIT2,DOSAGE3,DOSAGE3_AS_TEXT,UNIT3,NBDOSE,NBDOSE_AS_TEXT,GALENIC,NBDOSE2,NBDOSE2_AS_TEXT,GALENIC2,IS_PRD_REFUNDABLE,PRD_REFUNDABLE_RATE,PRD_PRICE,CANCELED_DAT,CREATION_DAT,MANUFACTURER_NAME,IS_GENERIC,IS_HOSP,PRD_START_DAT,PRD_END_DAT,REGROUPING_CODE,EPH_CODE,EPH_NAME,EPH_TYPE,EPH_STATE,MOL_EID,MOL_NAME,ATCCODE,ATC_NAME,ATC_MOL,ATC_TYPE,ATC_STATE,BNF_EID,BNF_NAME,VERSION,UPDATED,MIN_DOSAGE_BY_DAY_REF,MAX_DOSAGE_BY_DAY_REF,GAL_ID,GAL_ID2,FIRST_PRD_DATE,FIRST_PRE_TRA_ID,FIRST_TRA_DATE,DDL_ID,DDL_LBL,PRD_VAT,REGROUPING_CODE_2,GMP_ID,PRD_ID_DC
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000;

drop table drugs;
create table drugs as
select distinct fo_prd_id,a.PRD_NAME,a.MAST_PRD_NAME,a.DOSAGE,a.UNIT,a.DOSAGE2,a.UNIT2,a.MOL_EID,a.MOL_NAME,b.MOL_NAME as MOL_NAME_2, ATCCODE,ATC_NAME,NFC_CODE,MANUFACTURER
from fo_product_3 a join drug_mapping_3  b on a.prd_eid=b.prd_eid;



drop table drugs_3;
create table drugs_3 as 
select a.fo_prd_id, a.prd_name,a.mast_prd_name, DOSAGE_AS_TEXT as dosage, b.unit, DOSAGE2_AS_TEXT as dosage2, unit_id2 as unit2, a.mol_eid,a.mol_name, b.manufacturer,b.nfc_code,a.atccode, atc_name
from fo_product_3 a  left join drug_mapping_3 b on
a.prd_eid= b.prd_eid
;

UPDATE  DRUGS
SET MANUFACTURER = (SELECT MANUFACTURER FROM DRUGS_3 WHERE DRUGS_3.FO_PRD_ID = DRUGS.FO_PRD_ID)
;
UPDATE  DRUGS
SET ATCCODE = (SELECT ATCCODE FROM DRUGS_3 WHERE DRUGS_3.FO_PRD_ID = DRUGS.FO_PRD_ID AND DRUGS_3.ATCCODE NOT IN ('%IMIQUIMOD%','-1','??'))
;
INSERT INTO DRUGS (FO_PRD_ID,PRD_NAME,MAST_PRD_NAME,DOSAGE,UNIT,DOSAGE2,UNIT2,MOL_EID,MOL_NAME,ATCCODE,ATC_NAME,NFC_CODE,MANUFACTURER)
select  FO_PRD_ID, PRD_NAME,MAST_PRD_NAME,DOSAGE,UNIT,DOSAGE2,UNIT2,MOL_EID,MOL_NAME,ATCCODE,ATC_NAME,nfc_code,MANUFACTURER 
from drugs_3 where fo_prd_id not in (select fo_prd_id from drugs)
;

--next manipulation requires correct numbers--
update drugs 
set PRD_NAME=regexp_replace(PRD_NAME,',','.') where PRD_NAME is not null;
update drugs
SET PRD_NAME=REGEXP_REPLACE(PRD_NAME,'"')
;
