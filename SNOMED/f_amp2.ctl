OPTIONS (errors=0, direct=true)
LOAD DATA
INFILE *                                                        
TRUNCATE
INTO TABLE f_amp2
xmltype(xmlfield)
(
	xmlfield LOBFILE (CONSTANT f_amp2.xml)  TERMINATED BY EOF
)
BEGINDATA
0