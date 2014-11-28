options (direct=true, errors=0, SKIP=1)
load data
infile 'sct2_Concept_Full-UK.txt' 
replace
into table sct2_Concept_Full_UK
fields terminated by X'09'
trailing nullcols
(
id			    CHAR( 18)           ,		
effectiveTime	CHAR(  8)           ,		
active			CHAR(  1)           ,
moduleId		CHAR( 18)           ,		
statusId		CHAR(256)           
)
