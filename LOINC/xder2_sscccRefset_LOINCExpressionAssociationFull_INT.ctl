options (direct=true, errors=0, SKIP=1)
load data
infile 'xder2_sscccRefset_LOINCExpressionAssociationFull_INT.txt'
truncate
into table scccRefset_MapCorrOrFull_INT
fields terminated by WHITESPACE
trailing nullcols
(
id		 CHAR(256),	
effectiveTime    CHAR(256),	
active		 CHAR(256),	
moduleId	 CHAR(256),	
refsetId	 CHAR(256),	
referencedComponentId   	 CHAR(256),	
mapTarget	 CHAR(256)
)