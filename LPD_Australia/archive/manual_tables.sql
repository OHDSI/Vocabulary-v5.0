/*

OUTDATED


create table pack_drug_product
(fo_prd_id varchar(255),
pack_name varchar(255),
PRD_name varchar(255),
dosage varchar(255),
unit varchar(255),
dosage_2 varchar(255),
unit_2	varchar(255),
amount_pack varchar(255),
 mol_name varchar(255),
 ATCCODE varchar(255),
 ATC_NAME varchar(255),
 NFC_CODE varchar(255),
 MANUFACTURER varchar(255));


WbImport -file=C:/Users/eallakhverdiiev/Desktop/projects/vocabularies/Australia/Da_AUstralia/manual_tables/pack_drug_product.txt
         -type=text
         -table=PACK_DRUG_PRODUCT
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=mm/dd/yyyy
         -timestampFormat=mm/dd/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=FO_PRD_ID,PACK_NAME,PRD_NAME,DOSAGE,UNIT,DOSAGE_2,UNIT_2,AMOUNT_PACK,MOL_NAME,ATCCODE,ATC_NAME,NFC_CODE,MANUFACTURER
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false;

create table ds_stage_manual_all
(
DRUG_CONCEPT_CODE	VARCHAR2(255),
INGREDIENT_NAME	VARCHAR2(255),
BOX_SIZE	NUMBER,
AMOUNT_VALUE	FLOAT(126),
AMOUNT_UNIT	VARCHAR2(255),	
NUMERATOR_VALUE	FLOAT(126),	
NUMERATOR_UNIT	VARCHAR2(255),	
DENOMINATOR_VALUE	FLOAT(126),
DENOMINATOR_UNIT	VARCHAR2(255)	
);
WbImport -file=C:/Users/eallakhverdiiev/Desktop/projects/vocabularies/Australia/Da_AUstralia/manual_tables/ds_stage_stage_manual_all.txt
         -type=text
         -table=DS_STAGE_MANUAL_ALL
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=mm/dd/yyyy
         -timestampFormat=mm/dd/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=DRUG_CONCEPT_CODE,INGREDIENT_NAME,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false;


create table aus_dose_forms_done
(dose_form varchar(255),
concept_id NUMBER,
concept_name varchar(255),
precedence NUMBER);

WbImport -file=C:/Users/eallakhverdiiev/Desktop/projects/vocabularies/Australia/Da_AUstralia/manual_tables/aus_dose_forms_done.txt
         -type=text
         -table=AUS_DOSE_FORMS_DONE
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=mm/dd/yyyy
         -timestampFormat=mm/dd/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=DOSE_FORM,CONCEPT_ID,CONCEPT_NAME,PRECEDENCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false;

create table RELATIONSHIP_MANUAL_INGREDIENT_DONE
(
CONCEPT_NAME varchar(255),
DUMMY varchar(255),
CONCEPT_ID number,
RXNE_NAME varchar(255),
Precedence	number
)
;
WbImport -file=C:/Users/eallakhverdiiev/Desktop/projects/vocabularies/Australia/Da_AUstralia/manual_tables/RELATIONSHIP_MANUAL_INGREDIENT_DONE.txt
         -type=text
         -table=RELATIONSHIP_MANUAL_INGREDIENT_DONE
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=mm/dd/yyyy
         -timestampFormat=mm/dd/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=CONCEPT_NAME,DUMMY,CONCEPT_ID,RXNE_NAME,PRECEDENCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;




create table RELATIONSHIP_MANUAL_BRAND_DONE
(
CONCEPT_NAME varchar(255),
DUMMY varchar(255),
CONCEPT_ID number,
RXNE_NAME varchar(255),
Precedence	number
)
;
WbImport -file=C:/Users/eallakhverdiiev/Desktop/projects/vocabularies/Australia/Da_AUstralia/manual_tables/RELATIONSHIP_MANUAL_BRAND_DONE.txt
         -type=text
         -table=RELATIONSHIP_MANUAL_BRAND_DONE
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=mm/dd/yyyy
         -timestampFormat=mm/dd/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=CONCEPT_NAME,DUMMY,CONCEPT_ID,RXNE_NAME,PRECEDENCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;

create table RELATIONSHIP_MANUAL_SUPPLIER_DONE
(
CONCEPT_NAME varchar(255),
DUMMY varchar(255),
CONCEPT_ID number,
RXNE_NAME varchar(255),
Precedence	number
)
;
WbImport -file=C:/Users/eallakhverdiiev/Desktop/projects/vocabularies/Australia/Da_AUstralia/manual_tables/RELATIONSHIP_MANUAL_SUPPLIER_DONE.txt
         -type=text
         -table=RELATIONSHIP_MANUAL_SUPPLIER_DONE
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=mm/dd/yyyy
         -timestampFormat=mm/dd/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=CONCEPT_NAME,DUMMY,CONCEPT_ID,RXNE_NAME,PRECEDENCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;


create table no_ds_done 
(
FO_PRD_ID	VARCHAR(255),	
PRD_NAME	VARCHAR(255),	
MAST_PRD_NAME	VARCHAR2(255),
DOSAGE	NUMBER	,
UNIT	VARCHAR2(255),	
DOSAGE2	NUMBER,		
UNIT2	VARCHAR2(255),
MOL_EID	VARCHAR2(255),	
MOL_NAME	VARCHAR2(255),	
ATC_NAME	VARCHAR2(255),
MANUFACTURER	VARCHAR2(255),	
INGREDIENT_NAME	VARCHAR2(255),	
BOX_SIZE	NUMBER,
AMOUNT_VALUE	NUMBER,	
AMOUNT_UNIT	VARCHAR2(255),	
NUMERATOR_VALUE	NUMBER	,
NUMERATOR_UNIT	VARCHAR2(255),	
DENOMINATOR_VALUE	NUMBER	,
DENOMINATOR_UNIT	VARCHAR2(255)
)
;
WbImport -file=C:/Users/eallakhverdiiev/Desktop/projects/vocabularies/Australia/Da_AUstralia/manual_tables/no_ds_done.txt
         -type=text
         -table=NO_DS_DONE
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=mm/dd/yyyy
         -timestampFormat=mm/dd/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=FO_PRD_ID,PRD_NAME,MAST_PRD_NAME,DOSAGE,UNIT,DOSAGE2,UNIT2,MOL_EID,MOL_NAME,ATC_NAME,MANUFACTURER,INGREDIENT_NAME,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;


CREATE TABLE DS_TO_DELETE_DONE 
(
FO_PRD_ID NUMBER,
PRD_NAME VARCHAR(255),
MOL_NAME VARCHAR(255),
INGREDIENT_CONCEPT_CODE VARCHAR(255),
CONCEPT_NAME VARCHAR(255),
BOX_SIZE NUMBER,
AMOUNT_VALUE NUMBER,
AMOUNT_UNIT VARCHAR(20),
NUMERATOR_VALUE NUMBER,
NUMERATOR_UNIT VARCHAR(20), 
DENOMINATOR_VALUE NUMBER,
DENOMINATOR_UNIT VARCHAR(20),
VALID_DS NUMBER
);
WbImport -file=C:/Users/eallakhverdiiev/Desktop/projects/vocabularies/Australia/Da_AUstralia/manual_tables/ds_to_delete_done.txt
         -type=text
         -table=DS_TO_DELETE_DONE
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=mm/dd/yyyy
         -timestampFormat=mm/dd/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=FO_PRD_ID,PRD_NAME,MOL_NAME,INGREDIENT_CONCEPT_CODE,CONCEPT_NAME,BOX_SIZE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT,VALID_DS
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;



create table manual_supp
(
CONCEPT_NAME	VARCHAR2(255),
CONCEPT_ID	NUMBER,
RCONCEPT_NAME	VARCHAR2(255)
)
;
WbImport -file=C:/Users/eallakhverdiiev/Desktop/projects/vocabularies/Australia/Da_AUstralia/manual_tables/MANUAL_SUPP.txt
         -type=text
         -table=MANUAL_SUPP
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=mm/dd/yyyy
         -timestampFormat=mm/dd/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=CONCEPT_NAME,CONCEPT_ID,RCONCEPT_NAME
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;


create table aus_unit_done
(
CONCEPT_CODE_1	VARCHAR2(255),
VOCABULARY_ID_1	VARCHAR2(20),
CONCEPT_ID_2	NUMBER,
PRECEDENCE	NUMBER,
CONVERSION_FACTOR	FLOAT(126)
)
;
WbImport -file=C:/Users/eallakhverdiiev/Desktop/projects/vocabularies/Australia/Da_AUstralia/manual_tables/aus_unit_done.txt
         -type=text
         -table=AUS_UNIT_DONE
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=mm/dd/yyyy
         -timestampFormat=mm/dd/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_ID_2,PRECEDENCE,CONVERSION_FACTOR
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;

create table RELATION_MANUAL_BN
(
CONCEPT_CODE	VARCHAR2(255),
CONCEPT_NAME	VARCHAR2(255),
CONCEPT_ID_2	FLOAT(126),
CONCEPT_NAME_2	VARCHAR2(255),
PRECEDENCE	NUMBER,
CONVERSTION_FACTOR	FLOAT(126)
)
;
WbImport -file=C:/Users/eallakhverdiiev/Desktop/projects/vocabularies/Australia/Da_AUstralia/manual_tables/RELATION_MANUAL_BN.txt
         -type=text
         -table=RELATION_MANUAL_BN
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=mm/dd/yyyy
         -timestampFormat=mm/dd/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=CONCEPT_CODE,CONCEPT_NAME,CONCEPT_ID_2,CONCEPT_NAME_2,PRECEDENCE,CONVERSTION_FACTOR
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;

 */
