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

insert into FORM_TRANSLATION values('solution inhalée',	'Inhalant Solution');
 insert into FORM_TRANSLATION values('solution ou injectable pour perfusion intraveineuse;sous-cutanée',	'Injectable Solution');
 insert into FORM_TRANSLATION values('solution injectable endosinusale;intra-articulaire;intralésionnelle;intramusculaire;intraveineuse;périarticulaire;sous-conjonctivale;voie parentérale autre',	'Injectable Solution');
 insert into FORM_TRANSLATION values('poudre et solvant pour solution pour perfusion intraveineuse;voie extracorporelle autre',	'Injectable Solution');
 insert into FORM_TRANSLATION values('solution injectable intra-camérulaire'	,'Injectable Solution');
 insert into FORM_TRANSLATION values('solution à diluer injectable pour perfusion intramusculaire;intraveineuse',	'Injectable Solution');
 insert into FORM_TRANSLATION values('solution pour pulvérisation nasale;orale',	'Nasal or Oral Spray');
 insert into FORM_TRANSLATION values('solution injectable pour perfusion intramusculaire;intraveineuse',	'Injectable Solution');
 insert into FORM_TRANSLATION values('solution injectable pour perfusion intraveineuse;sous-cutanée','Injectable Solution');
 insert into FORM_TRANSLATION values('dispositif cutanée'	,'Transdermal Patch');
 insert into FORM_TRANSLATION values('poudre pour inhalation et poudre pour inhalation pour inhalation inhalée'	,'Inhalant Powder');
 insert into FORM_TRANSLATION values('suspension injectable endosinusale;intra-articulaire;intradurale;intralésionnelle;périarticulaire;péridurale;sous-conjonctivale;voie parentérale autre',	'Injectable Suspension');
 insert into FORM_TRANSLATION values('solution et solution pour perfusion sous-cutanée'	,'Injectable Solution');
 insert into FORM_TRANSLATION values('comprimé à croquer à sucer ou dispersible orale'	,'Chewable or Disintegrating Oral Tablet');
 insert into FORM_TRANSLATION values('comprimé orale;sublinguale',	'Chewable Oral Tablet');
 insert into FORM_TRANSLATION values('poudre et solvant pour solution intravésicale' ,'Injectable Solution');
 insert into FORM_TRANSLATION values('granules pour suspension buvable orale'	,'Granules for Oral Suspension');
 insert into FORM_TRANSLATION values('liquide orale','Oral Solution');
 insert into FORM_TRANSLATION values('poudre pour inhalation et poudre pour inhalation inhalée',	'Inhalant Powder');
 insert into FORM_TRANSLATION values('solution injectable endotrachéobronchique;intra-osseuse;intraveineuse'	,'Injectable Solution');
 insert into FORM_TRANSLATION values('solution injectable endosinusale;intra-articulaire;intralésionnelle;intramusculaire;intraveineuse;périarticulaire;sous-conjonctivale'	,'Injectable Solution');
 insert into FORM_TRANSLATION values('poudre et solvant pour usage parentéral intramusculaire;intraveineuse'	,'Injectable Suspension');
 insert into FORM_TRANSLATION values('poudre pour solution à diluer pour injection ou pour perfusion intraveineuse'	,'Injectable Solution');
 insert into FORM_TRANSLATION values('solution pour perfusion sous-cutanée'	,'Injectable Solution');
 insert into FORM_TRANSLATION values('solution à diluer et solvant à diluer pour solution injectable intramusculaire;intraveineuse'	,'Injectable Solution');
 insert into FORM_TRANSLATION values('poudre à diluer pour solution pour perfusion intraveineuse'	,'Injectable Suspension');
 insert into FORM_TRANSLATION values('poudre et solvant pour solution injectable intralésionnelle'	,'Injectable Suspension');



         
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








