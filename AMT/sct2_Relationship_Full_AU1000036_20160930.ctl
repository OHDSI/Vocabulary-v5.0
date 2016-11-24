options (direct=true, errors=0, SKIP=1)
load data
infile 'sct2_Relationship_Full_AU1000036_20160930.csv' 
truncate
into table rf2_full_relationships
fields terminated by ';' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
id varchar (255),
effectivetime varchar (255),
active varchar (255),
moduleid varchar (255), 
sourceid varchar (255),
destinationid varchar (255),
relationshipgroup varchar (255),
typeid varchar (255),
characteristictypeid varchar (255),
modifierid varchar (255)  
);
