options (direct=true, errors=0, SKIP=1)
load data
infile 'route_ia.txt' 
truncate
into table route_ia
fields terminated by '\t' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
   DRUG_CODE                     VARCHAR2(15 Byte),
   ROUTE_OF_ADMINISTRATION_CODE  NUMBER(6),
   ROUTE_OF_ADMINISTRATION       VARCHAR2(50 Byte)
       
);