UPDATE INGREDIENT   SET DOSAGE = 'pas moins de 1000,0 DICC50' WHERE DRUG_CODE = '60043248' AND   DRUG_FORM = 'poudre'  AND   FORM_CODE = 85085 AND   INGREDIENT = 'VIRUS DE LA ROUGEOLE, SOUCHE SCHWARTZ, VIVANT, ATTÉNUÉ ' AND   DOSAGE = 'pas moins de 3,0 log  DICC50' AND   VOLUME = '"une dose de 0,5 ml de vaccin reconstitué"' AND   INGR_NATURE = 'SA' AND   COMP_NUMBER = 1;
CREATE TABLE AUT_UNIT_ALL_MAPPED
(
   CONCEPT_CODE       VARCHAR2(255 Byte),
   CONCEPT_ID_2       NUMBER,
   CONCEPT_NAME_2     VARCHAR2(255 Byte),
   CONVERSION_FACTOR  NUMBER,
   PRECEDENCE         NUMBER
)
TABLESPACE USERS;
WbImport -file=C:/Users/aostropolets/Desktop/bdpm files/aut_unit_all_mapped.txt
         -type=text
         -table=AUT_UNIT_ALL_MAPPED
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=CONCEPT_CODE,CONCEPT_ID_2,CONCEPT_NAME_2,CONVERSION_FACTOR,PRECEDENCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=10;
