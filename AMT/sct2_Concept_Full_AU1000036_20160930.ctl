options (direct=true, errors=0, SKIP=1)
load data
infile 'sct2_Concept_Full_AU1000036_20160930.csv' 
truncate
into table sct2_Concept_Full_AU
fields terminated by ';' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
ID			CHAR(255),		
EFFECTIVETIME		CHAR(255),		
ACTIVE			CHAR(255),
MODULEID		CHAR(255),		
STATUSID		CHAR(256)           
);
