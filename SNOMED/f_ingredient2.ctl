OPTIONS (errors=0, direct=true)
LOAD DATA
INFILE *                                                        
TRUNCATE
INTO TABLE f_ingredient2
xmltype(xmlfield)
(
	xmlfield LOBFILE (CONSTANT f_ingredient2.xml)  TERMINATED BY EOF
)
BEGINDATA
0