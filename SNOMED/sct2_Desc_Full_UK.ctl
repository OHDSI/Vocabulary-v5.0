options (direct=true, errors=0, SKIP=1)
load data
infile 'sct2_Description_Full-UK.txt' 
replace
into table sct2_Desc_Full_UK
fields terminated by X'09'
trailing nullcols
(
id			    CHAR( 18)           ,		
effectiveTime	CHAR(  8)           ,		
active			CHAR(  1)           ,
moduleId		CHAR( 18)           ,		
conceptId		CHAR(256)           ,		
languageCode	CHAR(  2)           ,		
typeId			CHAR( 18)           ,		
term CHAR(256) "SUBSTR(:term, 1, 252)"      ,
caseSignificanceId	CHAR(256)           
)
