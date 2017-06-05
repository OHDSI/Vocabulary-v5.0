OPTIONS (errors=0, SKIP=1, direct=true)
LOAD DATA
INFILE 'LOINC_FORMS.txt' "str '\r\n'"
BADFILE 'LOINC_FORMS.bad'
DISCARDFILE 'LOINC_FORMS.dsc'                                                           
TRUNCATE
INTO TABLE LOINC_FORMS                                                                
FIELDS TERMINATED BY X'09' 
TRAILING NULLCOLS                                                             
(                                                                               
   ParentId                     FILLER
 , ParentLoinc                  CHAR    
 , ParentName					FILLER
 , Id 							FILLER
 , Sequence                		FILLER
 , Loinc          				CHAR           
)                                                                               
