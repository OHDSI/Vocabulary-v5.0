--need to change it to a proper ctl-file and tables creation script
--create THIN_GEMSC_DMD_0417 with all available mappings
WbCopy -sourceProfile='gemscript local'
       -sourceGroup='Default group'
       -targetProfile='gemscript new server'
       -targetGroup='Default group'
       -targetTable=THIN_GEMSC_DMD_0417
       -createTarget=true
       -sourceTable=UK_THIN_BY_URVI
       -ignoreIdentityColumns=false
       -deleteTarget=false
       -continueOnError=false
       -batchSize=1000
;
--create THIN_REFERNCE_0516 with all available mappings
WbCopy -sourceProfile=' local -rwe'
       -sourceGroup='Default group'
       -targetProfile='gemscript new server'
       -targetGroup='Default group'
       -targetTable=THIN_REFERNCE_0516
       -createTarget=true
       -sourceTable=DRUG_CODES_THIN_201605
       -ignoreIdentityColumns=false
       -deleteTarget=false
       -continueOnError=false
       -batchSize=1000
;

create table THIN_GEMSC_DMD_0717 as select * from THIN_GEMSC_DMD_0417 where rownum =0
;
WbImport -file=C:/work/thin_gemsc_dmd_0717.txt
         -type=text
         -table=THIN_GEMSC_DMD_0717
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat=dd.mm.yyyy
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=GEMSCRIPT_DRUGCODE,ENCRYPTED_DRUGCODE,BRAND,GENERIC,DMD_CODE
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000;
--names clean up
update THIN_GEMSC_DMD_0717 set brand = regexp_replace (brand , '^"')
;
update THIN_GEMSC_DMD_0717 set brand = regexp_replace (brand , '"$')
;
update THIN_GEMSC_DMD_0717 set brand = trim (brand )
;
commit
;
update THIN_GEMSC_DMD_0717 set generic = regexp_replace (generic , '^"')
;
update THIN_GEMSC_DMD_0717 set generic = regexp_replace (generic , '"$')
;
update THIN_GEMSC_DMD_0717 set generic = trim (generic )
;
commit
;
 update THIN_GEMSC_DMD_0717 set gemscript_drugcode = ltrim (gemscript_drugcode, '0') where gemscript_drugcode like '0%'
 ;
 commit
 ;
--add Gemscript reference table
drop table gemscript_reference;
create table gemscript_reference (
prodcode varchar (50),
	gemscriptcode  varchar (50),
productname varchar (500),
	drugsubstance varchar (1500),
		strength varchar (300),
			formulation varchar (300),
				route	varchar (300),
				bnf varchar (300),
					bnf_with_dots varchar (300),
						bnfchapter varchar (500)
						)
;
TRUNCATE TABLE GEMSCRIPT_REFERENCE
;

WbImport -file=C:/work/GEMSCRIPT_reference_042017.txt
         -type=text
         -table=GEMSCRIPT_REFERENCE
         -encoding="ISO-8859-15"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -decimal=.
         -fileColumns=prodcode,gemscriptcode,PRODUCTNAME,DRUGSUBSTANCE,STRENGTH,FORMULATION,ROUTE,BNF,BNF_WITH_DOTS,BNFCHAPTER
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000;
--names clean up
update GEMSCRIPT_REFERENCE set PRODUCTNAME = regexp_replace (PRODUCTNAME , '^"')
;
update GEMSCRIPT_REFERENCE set PRODUCTNAME = regexp_replace (PRODUCTNAME , '"$')
;
commit
;