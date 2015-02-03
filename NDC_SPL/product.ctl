options (direct=true, errors=0, skip=1)
load data 
infile 'product.txt' 
badfile 'product.bad'
discardfile 'product.dsc'
truncate
into table product
fields terminated by '\t'
trailing nullcols 
(
productid char(50),
productndc char(10),
producttypename char(27),
proprietaryname char(226),
proprietarynamesuffix char(126),
nonproprietaryname char(511),
dosageformname char(48),
routename char(118),
startmarketingdate date "YYYYMMDD",
endmarketingdate date "YYYYMMDD",
marketingcategoryname char(40),
applicationnumber char(11),
labelername char(100),
substancename char(3814),
active_numerator_strength char(742),
active_ingred_unit char(2055),
pharm_classes char(3998),
deaschedule char(4)
)

