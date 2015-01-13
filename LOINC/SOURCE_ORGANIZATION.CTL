OPTIONS (errors=0, SKIP=1, direct=true)
LOAD DATA 
CHARACTERSET UTF8                                                                      
INFILE 'source_organization.csv'  
BADFILE 'source_organization.bad'
DISCARDFILE 'source_organization.dsc'                                                           
TRUNCATE
INTO TABLE SOURCE_ORGANIZATION                                                                
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'                                                       
TRAILING NULLCOLS                                                               
(  
	COPYRIGHT_ID		CHAR NULLIF (COPYRIGHT_ID=BLANKS)                                                                             
 , NAME            CHAR NULLIF (NAME=BLANKS)              
 , COPYRIGHT       CHAR(5000) NULLIF (COPYRIGHT=BLANKS)              
 , TERMS_OF_USE    CHAR(10000) NULLIF (TERMS_OF_USE=BLANKS)               
 , URL             CHAR NULLIF (URL=BLANKS)             
)                                                                               
