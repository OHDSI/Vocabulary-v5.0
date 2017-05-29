select distinct form||' '||route from drug 
where drug_code not in (select pack_code from pack) 
and drug_code not in (select drug_code from homeop_drug);

create table form_translation (
FORM_ROUTE	varchar (255),
TRANSLATION varchar (255)
);
WbImport -file=C:/Users/aostropolets/Desktop/bdpm files/form translated.txt
         -type=text
         -table=FORM_TRANSLATION
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=FORM_ROUTE,TRANSLATION
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=200;
         
create table aut_form_all_mapped(
TRANSLATION	varchar (255),
CONCEPT_ID	number,
CONCEPT_NAME	varchar (255),
PRECEDENCE number);
WbImport -file=C:/Users/aostropolets/Desktop/bdpm files/aut_form_all_mapped.txt
         -type=text
         -table=AUT_FORM_ALL_MAPPED
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd/m/yyyy
         -timestampFormat=dd/m/yyyy
         -delimiter='\t'
         -decimal=.
         -fileColumns=TRANSLATION,CONCEPT_ID,CONCEPT_NAME,PRECEDENCE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=500;