options (direct=true, errors=0, SKIP=1)
load data
CHARACTERSET UTF8 LENGTH SEMANTICS CHAR
infile 'ANWEB_V2.csv' 
truncate
into table ANWEB_v2
fields terminated by ';' OPTIONALLY ENCLOSED BY '"'
trailing nullcols
(
HCPC char (100),
SEQNUM FILLER CHAR (4000),
RECID FILLER CHAR (4000),
LONG_DESCRIPTION char (4000),
SHORT_DESCRIPTION char (4000),
PRICE_CD1 char (4000),
PRICE_CD2 char (4000),
PRICE_CD3 char (4000),
PRICE_CD4 char (4000),
MULTI_PI char (4000),
CIM1  char (4000),   
CIM2  char (4000),   
 CIM3  char (4000),    
 MCM1  char (4000),    
 MCM2  char (4000),    
 MCM3  char (4000),    
 STATUTE  char (4000),    
 LAB_CERT_CD1  char (4000),    
 LAB_CERT_CD2  char (4000),    
 LAB_CERT_CD3  char (4000),    
 LAB_CERT_CD4  char (4000),    
 LAB_CERT_CD5  char (4000),    
 LAB_CERT_CD6  char (4000),    
 LAB_CERT_CD7  char (4000),    
 LAB_CERT_CD8  char (4000),    
 XREF1  char (4000),    
 XREF2  char (4000),    
 XREF3  char (4000),    
 XREF4  char (4000),    
 XREF5  char (4000),
 COV_CODE char (4000),    
 ASC_GPCD char (4000),    
 ASC_EFF_DT char (4000),    
 OPPS FILLER CHAR (4000),
 OPPS_PI FILLER CHAR (4000),
 OPPS_DT FILLER CHAR (4000),
 PROCNOTE FILLER CHAR (4000),
 BETOS char (4000),    
 TOS1 char (4000),    
 TOS2 char (4000),    
 TOS3 char (4000),    
 TOS4 char (4000),    
 TOS5 char (4000),    
 ANES_UNIT char (4000),    
 ADD_DATE DATE 'YYYYMMDD',    
 ACT_EFF_DT DATE 'YYYYMMDD',    
 TERM_DT DATE 'YYYYMMDD',    
 ACTION_CODE char (4000)
)
