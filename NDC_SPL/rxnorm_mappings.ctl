OPTIONS (errors=0, SKIP=1, direct=true)
LOAD DATA 
CHARACTERSET UTF8                                                                      
INFILE 'rxnorm_mappings.txt'
TRUNCATE
INTO TABLE spl2rxnorm_mappings                                                                
FIELDS TERMINATED BY '|'                                                
TRAILING NULLCOLS                                                               
(                                                                               
   SETID          CHAR    
 , SPL_VERSION    CHAR       
 , RXCUI          CHAR 
 , RXSTRING       FILLER CHAR (4000)         
 , RXTTY    	  CHAR           
)                                                                               
