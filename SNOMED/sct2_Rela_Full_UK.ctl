options (direct=true, errors=0, SKIP=1)
load data
infile 'sct2_Relationship_Full-UK.txt' 
replace
into table sct2_Rela_Full_UK
fields terminated by x'09' --WHITESPACE
trailing nullcols
(
id            		CHAR(18)           ,        
effectiveTime      	CHAR( 8)           ,        
active            	CHAR( 1)           ,        
moduleId        	CHAR(256)          ,        
sourceId        	CHAR(256)          ,        
destinationId        	CHAR(256)          ,        
relationshipGroup    	CHAR(11)           ,        
typeId                  CHAR(38)           ,        
characteristicTypeId    CHAR(18)           ,        
modifierId              CHAR(256)
)
