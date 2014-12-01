options (direct=true, errors=0, SKIP=1)
load data
infile 'der2_cRefset_AssociationReferenceFull_INT.txt'
replace
into table der2_cRefset_AssRefFull_INT
fields terminated by WHITESPACE
trailing nullcols
(
id		 CHAR(256),	
effectiveTime    CHAR(256),	
active		 CHAR(256),	
moduleId	 CHAR(256),	
refsetId	 CHAR(256),	
referencedComponentId   	 CHAR(256),	
targetComponent	 CHAR(256)
)