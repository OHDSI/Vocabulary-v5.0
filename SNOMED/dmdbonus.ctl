OPTIONS (errors=0, direct=true)
LOAD DATA
INFILE *                                                        
TRUNCATE
INTO TABLE dmdbonus
(
	xmlfield LOBFILE (CONSTANT dmdbonus.xml)  TERMINATED BY EOF
)
BEGINDATA
0