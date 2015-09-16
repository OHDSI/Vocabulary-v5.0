OPTIONS (errors=0, direct=true)
LOAD DATA
INFILE 'allxmlfilelist.dat'                                                          
TRUNCATE
INTO TABLE spl_ext_raw
xmltype(xmlfield)
(
	xml_name  char(100) "SUBSTR(:xml_name, 11)",
	xmlfield   lobfile(xml_name) terminated by eof
)                                                                               