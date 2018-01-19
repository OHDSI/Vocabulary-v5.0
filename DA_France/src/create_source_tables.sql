create table france (
PRODUCT_DESC	VARCHAR2(250 Byte),
FORM_DESC	VARCHAR2(250 Byte),
DOSAGE	VARCHAR2(100 Byte),
DOSAGE_ADD	VARCHAR2(100 Byte),
VOLUME	VARCHAR2(100 Byte),
PACKSIZE	VARCHAR2(100 Byte),
CLAATC	VARCHAR2(100 Byte),
PFC	VARCHAR2(100 Byte),
MOLECULE	VARCHAR2(450 Byte),
CD_NFC_3	VARCHAR2(250 Byte),
ENGLISH	VARCHAR2(250 Byte),
LB_NFC_3	VARCHAR2(250 Byte),
DESCR_PCK	VARCHAR2(250 Byte),
STRG_UNIT	VARCHAR2(100 Byte),
STRG_MEAS	VARCHAR2(100 Byte)
)
;
WbImport -file=              --choose directory fo source file
         -type=text
         -table=FRANCE
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/mm/yyyy
         -timestampFormat=dd/mm/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=PRODUCT_DESC,FORM_DESC,DOSAGE,DOSAGE_ADD,VOLUME,PACKSIZE,CLAATC,PFC,MOLECULE,CD_NFC_3,ENGLISH,LB_NFC_3,DESCR_PCK,STRG_UNIT,STRG_MEAS
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;








