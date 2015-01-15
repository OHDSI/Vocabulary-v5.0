OPTIONS (errors=0, SKIP=1, direct=true)
LOAD DATA 
CHARACTERSET UTF8                                                                      
INFILE 'loinc_class.csv'  
BADFILE 'loinc_class.bad'
DISCARDFILE 'loinc_class.dsc'                                                           
TRUNCATE
INTO TABLE loinc_class                                                                
FIELDS TERMINATED BY '|' OPTIONALLY ENCLOSED BY '"'                                                       
TRAILING NULLCOLS                                                               
(                                                                               
   CONCEPT_ID          CHAR NULLIF (CONCEPT_ID=BLANKS)              
 , CONCEPT_NAME        CHAR NULLIF (CONCEPT_NAME=BLANKS)              
 , DOMAIN_ID           CHAR NULLIF (DOMAIN_ID=BLANKS)               
 , VOCABULARY_ID       CHAR NULLIF (VOCABULARY_ID=BLANKS)               
 , CONCEPT_CLASS_ID    CHAR NULLIF (CONCEPT_CLASS_ID=BLANKS)               
 , STANDARD_CONCEPT    CHAR NULLIF (STANDARD_CONCEPT=BLANKS)               
 , CONCEPT_CODE        CHAR NULLIF (CONCEPT_CODE=BLANKS)               
 , VALID_START_DATE    DATE 'DD.MM.YYYY' NULLIF (VALID_START_DATE=BLANKS)               
 , VALID_END_DATE      DATE 'DD.MM.YYYY' NULLIF (VALID_END_DATE=BLANKS)               
 , INVALID_REASON      CHAR NULLIF (INVALID_REASON=BLANKS)
)                                                                               
