options (direct=true, errors=0, SKIP=1)
load data
infile 'pack_form.txt' 
truncate
into table PACK_FORM
fields terminated by '\t' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   CONCEPT_NAME_1  VARCHAR2(255 Byte),
   CONCEPT_NAME_2  VARCHAR2(255 Byte)   
);
