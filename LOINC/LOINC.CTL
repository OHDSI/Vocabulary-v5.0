OPTIONS (errors=0, SKIP=1, direct=true)
LOAD DATA 
CHARACTERSET UTF8  
INFILE 'loinc.csv'  
BADFILE 'loinc.bad'
DISCARDFILE 'loinc.dsc'                                                           
TRUNCATE
INTO TABLE LOINC                                                                
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'                                                       
TRAILING NULLCOLS                                                               
(                                                                               
   LOINC_NUM                        CHAR NULLIF (LOINC_NUM=BLANKS)              
 , COMPONENT                        CHAR NULLIF (COMPONENT=BLANKS)              
 , PROPERTY                         CHAR NULLIF (PROPERTY=BLANKS)               
 , TIME_ASPCT                       CHAR NULLIF (TIME_ASPCT=BLANKS)             
 , SYSTEM                           CHAR NULLIF (SYSTEM=BLANKS)                 
 , SCALE_TYP                        CHAR NULLIF (SCALE_TYP=BLANKS)              
 , METHOD_TYP                       CHAR NULLIF (METHOD_TYP=BLANKS)             
 , CLASS                            CHAR NULLIF (CLASS=BLANKS)                  
 , SOURCE                           CHAR NULLIF (SOURCE=BLANKS)                 
 , DATE_LAST_CHANGED                DATE "yyyymmdd" NULLIF (DATE_LAST_CHANGED=BLANKS)                                                                       
 , CHNG_TYPE                        CHAR NULLIF (CHNG_TYPE=BLANKS)              
 , COMMENTS                         CHAR(5000) NULLIF (COMMENTS=BLANKS)                                               
 , STATUS                           CHAR NULLIF (STATUS=BLANKS)                 
 , CONSUMER_NAME                    CHAR NULLIF (CONSUMER_NAME=BLANKS)          
 , CLASSTYPE                        CHAR NULLIF (CLASSTYPE=BLANKS)              
 , FORMULA                          CHAR NULLIF (FORMULA=BLANKS)                
 , SPECIES                          CHAR NULLIF (SPECIES=BLANKS)                
 , EXMPL_ANSWERS                    CHAR(5000) NULLIF (EXMPL_ANSWERS=BLANKS)                                            
 , SURVEY_QUEST_TEXT                CHAR(5000) NULLIF (SURVEY_QUEST_TEXT =BLANKS)                                             
 , SURVEY_QUEST_SRC                 CHAR NULLIF (SURVEY_QUEST_SRC=BLANKS)       
 , UNITSREQUIRED                    CHAR NULLIF (UNITSREQUIRED=BLANKS)          
 , SUBMITTED_UNITS                  CHAR NULLIF (SUBMITTED_UNITS=BLANKS)        
 , RELATEDNAMES2                    CHAR(5000) NULLIF (RELATEDNAMES2=BLANKS)                                            
 , SHORTNAME                        CHAR NULLIF (SHORTNAME=BLANKS)              
 , ORDER_OBS                        CHAR(5000)
 , CDISC_COMMON_TESTS               CHAR NULLIF (CDISC_COMMON_TESTS=BLANKS)     
 , HL7_FIELD_SUBFIELD_ID            CHAR NULLIF (HL7_FIELD_SUBFIELD_ID=BLANKS)  
 , EXTERNAL_COPYRIGHT_NOTICE        CHAR(5000) NULLIF (EXTERNAL_COPYRIGHT_NOTICE=BLANKS)                                            
 , EXAMPLE_UNITS                    CHAR NULLIF (EXAMPLE_UNITS=BLANKS)          
 , LONG_COMMON_NAME                 CHAR NULLIF (LONG_COMMON_NAME=BLANKS)       
)                                                                               
