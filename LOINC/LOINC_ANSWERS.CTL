OPTIONS (errors=0, SKIP=1, direct=true)
LOAD DATA
INFILE 'answers.csv' "str '\n'"
BADFILE 'LOINC_ANSWERS.bad'
DISCARDFILE 'LOINC_ANSWERS.dsc'
TRUNCATE
CONTINUEIF LAST != '"'
INTO TABLE LOINC_ANSWERS
FIELDS TERMINATED BY ","
OPTIONALLY ENCLOSED BY '"'
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
 , DISPLAYTEXT                  CHAR (4000) "substr(replace(:DISPLAYTEXT,'_x000D_',' '),1,250)"
)
