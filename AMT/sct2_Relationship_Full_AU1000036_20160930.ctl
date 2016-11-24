options (direct=true, errors=0, SKIP=1)
load data
infile 'sct2_Relationship_Full_AU1000036_20160930.csv' 
truncate
into table rf2_full_relationships
fields terminated by ';' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
ID CHAR (255),
EFFECTIVETIME CHAR (255),
ACTIVE CHAR (255),
MODULEID CHAR (255), 
SOURCEID CHAR (255),
DESTINATIONID CHAR (255),
RELATIONSHIPGROUP CHAR (255),
TYPEID CHAR (255),
CHARACTERISTICTYPEID CHAR (255),
MODIFIERID CHAR (255)  
);
