options (direct=true, errors=0, SKIP=1)
load data
CHARACTERSET UTF8 LENGTH SEMANTICS CHAR
infile 'HCPC2015_CONTR_ANWEB_v2.csv' 
BADFILE 'HCPC2015_CONTR_ANWEB_v2.bad'
DISCARDFILE 'HCPC2015_CONTR_ANWEB_v2.dsc'
truncate
into table ANWEB_v2
fields terminated by ';' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
HCPC char,
LONG_DESCRIPTION char (4000),
SHORT_DESCRIPTION char,
PRICE_CD1 char,
PRICE_CD2 char,
PRICE_CD3 char,
PRICE_CD4 char,
MULTI_PI char,
CIM1  char,   
CIM2  char,   
 CIM3  char,    
 MCM1  char,    
 MCM2  char,    
 MCM3  char,    
 STATUTE  char,    
 LAB_CERT_CD1  char,    
 LAB_CERT_CD2  char,    
 LAB_CERT_CD3  char,    
 LAB_CERT_CD4  char,    
 LAB_CERT_CD5  char,    
 LAB_CERT_CD6  char,    
 LAB_CERT_CD7  char,    
 LAB_CERT_CD8  char,    
 XREF1  char,    
 XREF2  char,    
 XREF3  char,    
 XREF4  char,    
 XREF5  char,
 COV_CODE char,    
 ASC_GPCD char,    
 ASC_EFF_DT DATE 'YYYYMMDD',    
 PROC_NOTE char,    
 BETOS char,    
 TOS1 char,    
 TOS2 char,    
 TOS3 char,    
 TOS4 char,    
 TOS5 char,    
 ANES_UNIT char,    
 ADD_DATE DATE 'YYYYMMDD',    
 ACT_EFF_DT DATE 'YYYYMMDD',    
 TERM_DT DATE 'YYYYMMDD',    
 ACTION_CODE char
)
