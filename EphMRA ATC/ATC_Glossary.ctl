options (direct=true, errors=0)
load data
infile 'ATC_Glossary.csv'
truncate
into table ATC_Glossary
fields terminated by ';'
trailing nullcols
(
   concept_code	char(1000),
   concept_name	char(1000),
   n1	char(1000),
   n2	char(1000),
   n3	char(1000),
   n4	char(1000),
   n5	char(1000)
)
