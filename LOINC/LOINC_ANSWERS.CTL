OPTIONS (errors=0, SKIP=1, direct=true)
LOAD DATA
INFILE 'LOINC_ANSWERS.txt' "str '\t\r\n'"
BADFILE 'LOINC_ANSWERS.bad'
DISCARDFILE 'LOINC_ANSWERS.dsc'                                                           
TRUNCATE
INTO TABLE LOINC_ANSWERS                                                                
FIELDS TERMINATED BY X'09' 
TRAILING NULLCOLS                                                             
(                                                                               
   LOINC                        CHAR
 , LOINCNAME                    CHAR    
 , AnswerListId					filler
 , AnswerListName 				filler
 , ANSWERLISTOID                CHAR
 , EXTERNALLYDEFINEDYN          CHAR           
 , EXTERNALLYDEFINEDANSCS       CHAR             
 , LINKTOEXTERNALLIST           CHAR            
 , ANSWERSTRINGID               CHAR            
 , ANSWERCODE                   CHAR             
 , SEQUENCENO                   CHAR          
 , DISPLAYTEXT                  CHAR (4000) "substr(:DISPLAYTEXT,1,250)"
)                                                                               
