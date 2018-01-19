options (direct=true, errors=0, SKIP=1)
load data
infile 'der2_ccsRefset_UnitOfUseSizeFull_AU.csv' 
truncate
into table rf2_ss_unit_of_use_size_refset
fields terminated by ';' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
ID 			CHAR (255),
EFFECTIVETIME 		CHAR (255),
ACTIVE 			CHAR (255),
MODULEID 		CHAR (255), 
REFSETID 		CHAR (255), 
REFERENCEDCOMPONENTID 	CHAR (255), 
UNITID 			CHAR (255), 
OPERATORID 		CHAR (255), 
VALUE 			CHAR (255)  
);

