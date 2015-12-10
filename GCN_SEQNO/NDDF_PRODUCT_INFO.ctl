options (direct=true, errors=0)
load data
infile 'NDDF_PRODUCT_INFO.TXT' "str '\r\n'"
truncate
into table NDDF_PRODUCT_INFO
fields terminated by '|'
trailing nullcols
(
	NDDF_VERSION		 CHAR(8)
)