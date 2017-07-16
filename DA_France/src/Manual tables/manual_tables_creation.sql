create table ingredient_all_completed (
  CONCEPT_NAME varchar (250),
	CONCEPT_ID_2 varchar (250)
	);
WbImport -file=             --choose directory of ingredient_all_completed.txt
         -type=text
         -table=INGREDIENT_ALL_COMPLETED
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/mm/yyyy
         -timestampFormat=dd/mm/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=CONCEPT_NAME,CONCEPT_ID_2
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;


create table france_names_translation (
DOSE_FORM varchar (255),
DOSE_FORM_NAME varchar (255)
);
WbImport -file= --choose directory of france_names_translation.txt
         -type=text
         -table=FRANCE_NAMES_TRANSLATION
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/mm/yyyy
         -timestampFormat=dd/mm/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=DOSE_FORM,DOSE_FORM_NAME
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;

update france_names_translation set DOSE_FORM_NAME=regexp_replace(DOSE_FORM_NAME,'"');


create table NEW_FORM_NAME_MAPPING (
DOSE_FORM_NAME varchar (255),
CONCEPT_ID_2 varchar (255),
PRECEDENCE varchar (255),
CONCEPT_NAME varchar (255)
);
WbImport -file= --choose directory of NEW_FORM_NAME_MAPPING.txt
         -type=text
         -table=NEW_FORM_NAME_MAPPING
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/mm/yyyy
         -timestampFormat=dd/mm/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=DOSE_FORM_NAME,CONCEPT_ID_2,PRECEDENCE,CONCEPT_NAME
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;
         
update NEW_FORM_NAME_MAPPING set DOSE_FORM_NAME=regexp_replace(DOSE_FORM_NAME,'"');

create table  brand_names_manual (
CONCEPT_NAME varchar (255),
CONCEPT_ID_2 varchar (255)
);
WbImport -file= --choose directory of brand_names_manual.txt
         -type=text
         -table=BRAND_NAMES_MANUAL
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/mm/yyyy
         -timestampFormat=dd/mm/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=CONCEPT_NAME,CONCEPT_ID_2
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=100;


update brand_names_manual set CONCEPT_NAME=regexp_replace(CONCEPT_NAME,'"');




