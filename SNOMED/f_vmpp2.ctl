OPTIONS (errors=0, direct=true)
LOAD DATA
INFILE *                                                        
TRUNCATE
INTO TABLE f_vmpp2
xmltype(xmlfield)
(
	xmlfield LOBFILE (CONSTANT f_vmpp2.xml)  TERMINATED BY EOF
)
BEGINDATA
0