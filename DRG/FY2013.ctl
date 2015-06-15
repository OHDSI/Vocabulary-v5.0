options (direct=true, errors=0, skip=2)
load data
infile 'FY2013.txt'
append
into table FY_TABLE_5
fields terminated by X'09'
trailing nullcols
(
   DRG_CODE	char "SUBSTR(:DRG_CODE,1,3)",
   filler_column1 FILLER,
   filler_column2 FILLER,
   filler_column3 FILLER,
   filler_column4 FILLER,
   DRG_NAME	char(4000),
   DRG_VERSION	"2013"
)