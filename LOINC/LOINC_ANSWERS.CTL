OPTIONS (errors=0, SKIP=1, direct=true)
LOAD DATA 
CHARACTERSET UTF8  
INFILE 'LOINC_248_SELECTED_FORMS.csv' "str X'0D'"
BADFILE 'LOINC_248_SELECTED_FORMS.bad'
DISCARDFILE 'LOINC_248_SELECTED_FORMS.dsc'                                                           
TRUNCATE
INTO TABLE LOINC_ANSWERS                                                                
FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"'                                                       
TRAILING NULLCOLS                                                               
(                                                                               
   LOINC                        CHAR NULLIF (LOINC=BLANKS)              
 , LOINCNAME                    CHAR NULLIF (LOINCNAME=BLANKS)              
 , ANSWERLISTOID                CHAR NULLIF (ANSWERLISTOID=BLANKS)               
 , EXTERNALLYDEFINEDYN          CHAR NULLIF (EXTERNALLYDEFINEDYN=BLANKS)             
 , EXTERNALLYDEFINEDANSCS       CHAR NULLIF (EXTERNALLYDEFINEDANSCS=BLANKS)                 
 , LINKTOEXTERNALLIST           CHAR NULLIF (LINKTOEXTERNALLIST=BLANKS)              
 , ANSWERSTRINGID               CHAR NULLIF (ANSWERSTRINGID=BLANKS)             
 , ANSWERCODE                   CHAR NULLIF (ANSWERCODE=BLANKS)                  
 , SEQUENCENO                   CHAR NULLIF (SEQUENCENO=BLANKS)              
 , DISPLAYTEXT                  CHAR NULLIF (DISPLAYTEXT=BLANKS)                                               
 , ANSWERCODESYSTEM             CHAR NULLIF (ANSWERCODESYSTEM=BLANKS)                 
 , GLOBALID                     CHAR NULLIF (GLOBALID=BLANKS)          
 , GLOBALIDCODESYSTEM           CHAR NULLIF (GLOBALIDCODESYSTEM=BLANKS)             
 , COPYRIGHTNOTICE              FILLER CHAR (4000)
 , DESCRIPTION                  FILLER CHAR (4000) 
 , SCORE                        FILLER CHAR (4000) 
)                                                                               
