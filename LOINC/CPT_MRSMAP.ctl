options (direct=true, errors=0)
load data
infile 'MRSMAP.RRF' 
badfile 'MRSMAP.bad'
discardfile 'MRSMAP.dsc'
truncate
into table CPT_MRSMAP
fields terminated by '|'
trailing nullcols(
 MAPSETCUI CHAR,
 MAPSETSAB CHAR,
 MAPID CHAR,
 MAPSID CHAR,
 FROMEXPR CHAR (4000),
 FROMTYPE CHAR,
 REL CHAR,
 RELA CHAR,
 TOEXPR CHAR (4000),
 TOTYPE CHAR,
 CVF INTEGER external
)
