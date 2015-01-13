OPTIONS (errors=0, SKIP=1, direct=true)
LOAD DATA 
CHARACTERSET UTF8                                                                      
INFILE 'map_to.csv'  
BADFILE 'map_to.bad'
DISCARDFILE 'map_to.dsc'                                                           
TRUNCATE
INTO TABLE MAP_TO                                                                
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'                                                       
TRAILING NULLCOLS                                                               
(                                                                               
   LOINC          CHAR NULLIF (LOINC=BLANKS)              
 , MAP_TO         CHAR NULLIF (MAP_TO=BLANKS)              
 , "COMMENT"      CHAR NULLIF ("COMMENT"=BLANKS)               
)                                                                               
