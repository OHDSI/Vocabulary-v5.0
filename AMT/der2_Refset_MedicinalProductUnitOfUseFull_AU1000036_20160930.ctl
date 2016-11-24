options (direct=true, errors=0, SKIP=1)
load data
infile 'der2_Refset_MedicinalProductUnitOfUseFull_AU1000036_20160930.csv' 
truncate
into table rf2_ss_refset
fields terminated by ';' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
ID 			CHAR (255),
EFFECTIVETIME 		CHAR (255),
ACTIVE 			CHAR (255),
MODULEID 	`	CHAR (255), 
REFSETID 		CHAR (255), 
REFERENCEDCOMPONENTID 	CHAR (255) 
);
