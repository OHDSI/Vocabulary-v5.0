CREATE TABLE AUT_INGR_5
(
   CONCEPT_CODE_1  VARCHAR2(50 Byte),
   CONCEPT_NAME_1  VARCHAR2(255 Byte),
   CONCEPT_ID_2    NUMBER               NOT NULL,
   CONCEPT_NAME_2  VARCHAR2(255 Byte)   NOT NULL,
   PRECEDENCE      CHAR(1)
)
TABLESPACE USERS;
WbImport -file=C:/Users/aostropolets/Desktop/Australia/AMT_ingr_to_map.txt
         -type=text
         -table=AUT_INGR_5
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=CONCEPT_CODE_1,CONCEPT_NAME_1,CONCEPT_ID_2,CONCEPT_NAME_2,PRECEDENCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;

CREATE TABLE AUT_INGR_6
(
   CONCEPT_CODE_1  VARCHAR2(50 Byte),
   CONCEPT_NAME_1  VARCHAR2(255 Byte),
   CONCEPT_ID_2    NUMBER               NOT NULL,
   CONCEPT_NAME_2  VARCHAR2(255 Byte)   NOT NULL,
   PRECEDENCE      CHAR(2)
)
TABLESPACE USERS;
WbImport -file=C:/Users/aostropolets/Desktop/australia/aut_ing_6.txt
         -type=text
         -table=AUT_INGR_6
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=CONCEPT_CODE_1,CONCEPT_NAME_1,CONCEPT_ID_2,CONCEPT_NAME_2,PRECEDENCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=50;



create table aut_form_man (
concept_code_1 varchar(255),
concept_name_1 varchar(255),
concept_id_2 number,
concept_name_2 varchar(255),
precedence varchar(2));
WbImport -file=C:/Users/aostropolets/Desktop/australia/forms to map_done.txt
         -type=text
         -table=AUT_FORM_MAN
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=CONCEPT_CODE_1,CONCEPT_NAME_1,CONCEPT_ID_2,CONCEPT_NAME_2,PRECEDENCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false;
         

CREATE TABLE AUT_FORM_2
(
   CONCEPT_CODE_1  VARCHAR2(255 Byte),
   CONCEPT_NAME_1  VARCHAR2(255 Byte),
   CONCEPT_ID_2    NUMBER,
   CONCEPT_NAME_2  VARCHAR2(255 Byte),
   PRECEDENCE      VARCHAR2(2 Byte)
)
;
WbImport -file=C:/Users/aostropolets/Desktop/australia/form_map_2.txt
         -type=text
         -table=AUT_FORM_2
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=CONCEPT_CODE_1,CONCEPT_NAME_1,CONCEPT_ID_2,CONCEPT_NAME_2,PRECEDENCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false;
