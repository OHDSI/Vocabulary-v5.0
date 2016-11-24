options (direct=true, errors=0, SKIP=1)
load data
infile 'der2_ccsRefset_UnitOfUseQuantityFull_AU1000036_20160930.csv' 
truncate
into table rf2_ss_unit_of_use_qr
fields terminated by ';' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
id varchar (255),
effectivetime varchar (255),
active varchar (255),
moduleid varchar (255), 
refsetid varchar (255), 
referencedcomponentid varchar (255), 
unitid varchar (255), 
operatorid varchar (255), 
value varchar (255) 
);
