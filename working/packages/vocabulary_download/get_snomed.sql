CREATE OR REPLACE FUNCTION vocabulary_download.get_snomed (
    iOperation TEXT default null,
    OUT session_id INT4,
    OUT last_status INT,
    OUT result_output TEXT
)
AS
$BODY$
DECLARE
    pVocabularyID TEXT;
    CRLF CONSTANT TEXT:=E'\r\n';
    
    pVocabulary_auth vocabulary_access.vocabulary_auth%TYPE;
    pVocabulary_url vocabulary_access.vocabulary_url%TYPE;
    pVocabulary_login vocabulary_access.vocabulary_login%TYPE;
    pVocabulary_pass vocabulary_access.vocabulary_pass%TYPE;
    pVocabularySrcDate DATE;
    pVocabularySrcVersion TEXT;
    pVocabularyNewDate DATE;
    pVocabularyNewVersion TEXT;
    pCookie TEXT;
    pContent TEXT;
    pTicket TEXT;
    pDownloadURL TEXT;
    pErrorDetails TEXT;
    pVocabularyOperation TEXT;
/*
  possible values of pJumpToOperation:
  ALL (default), 
  JUMP_TO_SNOMED_UK, 
  JUMP_TO_SNOMED_US, 
  JUMP_TO_SNOMED_UK_DE, 
  JUMP_TO_SNOMED_IMPORT
*/
    pJumpToOperation TEXT;
    z INT;
    cRet TEXT;
    pSession int4;
    pVocabulary_load_path TEXT;
BEGIN

    IF iOperation IS NULL 
    THEN 
        pJumpToOperation := 'ALL'; 
    ELSE 
        pJumpToOperation := iOperation; 
    END IF;

    IF iOperation NOT IN ('ALL', 
                          'JUMP_TO_SNOMED_INT', 
                          'JUMP_TO_SNOMED_UK', 
                          'JUMP_TO_SNOMED_US' ,
                          'JUMP_TO_SNOMED_UK_DE', 
                          'JUMP_TO_DMD', 
                          'JUMP_TO_DMD_PREPARE',
                          'JUMP_TO_SNOMED_IMPORT') 
    THEN 
        RAISE EXCEPTION 'Wrong iOperation %', iOperation; 
    END IF;

   pVocabularyID := CASE iOperation
                    WHEN 'JUMP_TO_SNOMED_INT'   THEN 'SNOMED_INT'
                    WHEN 'JUMP_TO_SNOMED_UK'    THEN 'SNOMED_UK'
                    WHEN 'JUMP_TO_SNOMED_US'    THEN 'SNOMED_US'
                    WHEN 'JUMP_TO_SNOMED_UK_DE' THEN 'SNOMED_UK_DE'
                    ELSE 'SNOMED'
                    END CASE;
            
   pVocabularyOperation := 'GET_' || pVocabularyID;

   SELECT NEXTVAL('vocabulary_download.log_seq') INTO pSession;
  
   SELECT new_date, new_version, src_date, src_version 
     INTO pVocabularyNewDate, pVocabularyNewVersion, pVocabularySrcDate, pVocabularySrcVersion 
     FROM vocabulary_pack.CheckVocabularyUpdate(pVocabularyID);
  
    SET LOCAL search_path TO vocabulary_download;
  
    PERFORM write_log (
        iVocabularyID => pVocabularyID,
        iSessionID => pSession,
        iVocabulary_operation => pVocabularyOperation ||' started',
        iVocabulary_status => 0
    );
  
  
  /*if pJumpToOperation='ALL' then 
    if pVocabularyNewDate is null then raise exception '% already updated',pVocabularyID; end if;
  else
    --if we want to partially update the SNOMED (e.g. only UK-part), then we use the old date from the main source (International release), even if it was updated
    select vocabulary_date into pVocabularyNewDate from sources.sct2_concept_full_merged limit 1;
  end if;*/
    IF pVocabularyNewDate IS NULL 
    THEN 
        RAISE EXCEPTION '% already updated', pVocabularyID; 
    END IF;
  
    IF NOT pg_try_advisory_xact_lock(hashtext(pVocabularyID)) 
    THEN 
        RAISE EXCEPTION 'Processing of % already started',pVocabularyID; 
    END IF;
  
    SELECT var_value || pVocabularyID 
      INTO pVocabulary_load_path 
      FROM devv5.config$ 
     WHERE var_name = 'vocabulary_load_path';
    
    -- INT download
    IF pJumpToOperation in ('ALL','JUMP_TO_SNOMED_INT')
    THEN
        --get credentials
        SELECT vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, MAX(vocabulary_order) OVER()
          INTO pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z 
          FROM devv5.vocabulary_access 
         WHERE vocabulary_id = pVocabularyID 
           AND vocabulary_order = 2;
    
        --first part, getting raw download link from page
        SELECT TRIM(SUBSTRING(http_content,'<h1>Current International Edition Release</h1>.+?<a class=.+?href="(.+?)".*?><strong>Download RF2 Files Now!</strong></a>'))
          INTO pDownloadURL 
          FROM py_http_get(url => pVocabulary_url);
          
        IF NOT COALESCE(pDownloadURL, '-') ~* '^(https://download.nlm.nih.gov/)(.+)\.zip$' 
        THEN 
            pErrorDetails := COALESCE(pDownloadURL, '-'); 
            RAISE EXCEPTION 'pDownloadURL (raw) is not valid'; 
        END IF;
    
        --get the proper ticket and concatenate it with the pDownloadURL
        pTicket := get_umls_ticket (pVocabulary_auth, pVocabulary_login, pDownloadURL);
        
        pDownloadURL := pDownloadURL || '?ticket=' || pTicket;

        PERFORM write_log (
            iVocabularyID => pVocabularyID,
            iSessionID => pSession,
            iVocabulary_operation => pVocabularyOperation || ' authorization successful',
            iVocabulary_status => 1
        );

        --start downloading
        pVocabularyOperation := 'GET_SNOMED downloading';
        
        PERFORM run_wget (
            iPath => pVocabulary_load_path,
            iFilename => lower(pVocabularyID) || '.zip',
            iDownloadLink => pDownloadURL
        );
        
        PERFORM write_log (
            iVocabularyID => pVocabularyID,
            iSessionID => pSession,
            iVocabulary_operation => 'GET_SNOMED downloading complete',
            iVocabulary_status => 1
        );
    END IF;

    -- INT prepare
    IF pJumpToOperation IN ('ALL','JUMP_TO_SNOMED_INT') 
    THEN
        --extraction
        pVocabularyOperation := 'GET_SNOMED INT prepare';
        
        PERFORM get_snomed_prepare_int (
            iPath => pVocabulary_load_path,
            iFilename => LOWER(pVocabularyID) || '.zip'
        );
        
        PERFORM write_log (
            iVocabularyID => pVocabularyID,
            iSessionID => pSession,
            iVocabulary_operation => 'GET_SNOMED INT prepare complete',
            iVocabulary_status => 1
        );
    END IF;

    -- UK download
    IF pJumpToOperation IN ('ALL', 'JUMP_TO_SNOMED_UK') 
    THEN
        pVocabularyOperation := 'GET_SNOMED UK-part';
        
        --get credentials
        SELECT vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, MAX(vocabulary_order) OVER()
          INTO pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z 
          FROM devv5.vocabulary_access 
         WHERE vocabulary_id = pVocabularyID 
           AND vocabulary_order = 3;
    
        --authorization
        SELECT (SELECT VALUE 
                  FROM json_each_text(http_headers) 
                 WHERE LOWER(key) = 'set-cookie'), 
               http_content 
          INTO pCookie, pContent
          FROM py_http_post(url => pVocabulary_auth, params => 'j_username=' || 
                            devv5.urlencode(pVocabulary_login) ||
                            '&j_password=' || devv5.urlencode(pVocabulary_pass) || '&commit=LOG%20IN');
                        
        IF pCookie NOT LIKE '%JSESSIONID=%' 
        THEN pErrorDetails:=pCookie||CRLF||CRLF||pContent; 
            RAISE EXCEPTION 'cookie %%JSESSIONID=%% not found'; 
        END IF;
    
        --get working download link
        pCookie = SUBSTRING(pCookie, 'JSESSIONID=(.*?);');
        
        SELECT http_content 
          INTO pContent 
          FROM py_http_get(url => pVocabulary_url, cookies => '{"JSESSIONID":"' || pCookie || '"}');

        pDownloadURL := SUBSTRING(pContent, '<div class="release-details__label">.+?<a href="(.*?)">.+');
    
        --start downloading
        pVocabularyOperation := 'GET_SNOMED UK-part downloading';
        
        PERFORM run_wget (
            iPath => pVocabulary_load_path,
            iFilename => LOWER(pVocabularyID) || '.zip',
            iDownloadLink => pDownloadURL,
            iDeleteAll => 0
        );
        
        PERFORM write_log (
            iVocabularyID => pVocabularyID,
            iSessionID => pSession,
            iVocabulary_operation => 'GET_SNOMED UK-part downloading complete',
            iVocabulary_status => 1
        );
    END IF;

    -- UK prepare
    IF pJumpToOperation IN ('ALL', 'JUMP_TO_SNOMED_UK') 
    THEN
        --extraction
        pVocabularyOperation := 'GET_SNOMED UK prepare';
        
        PERFORM get_snomed_prepare_uk (
            iPath => pVocabulary_load_path,
            iFilename => lower(pVocabularyID) || '.zip'
        );
        
        PERFORM write_log (
            iVocabularyID => pVocabularyID,
            iSessionID => pSession,
            iVocabulary_operation => 'GET_SNOMED UK prepare complete',
            iVocabulary_status => 1
        );
    END IF;

    -- US download
    IF pJumpToOperation IN ('ALL','JUMP_TO_SNOMED_US') 
    THEN
        pVocabularyOperation := 'GET_SNOMED US-part';
        
        --get credentials
        SELECT vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, MAX(vocabulary_order) OVER()
          INTO pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z 
          FROM devv5.vocabulary_access 
         WHERE vocabulary_id = pVocabularyID 
           AND vocabulary_order = 4;
    
        --first part, getting raw download link from page
        SELECT SUBSTRING(http_content, 'Current US Edition Release.+?<p><a href="(.+?\.zip)".*?>Download Now!</a></p>')
          INTO pDownloadURL 
          FROM py_http_get(url => pVocabulary_url);
          
        IF NOT COALESCE(pDownloadURL,'-') ~* '^(https://download.nlm.nih.gov/)(.+)\.zip$' 
        THEN 
            pErrorDetails := COALESCE(pDownloadURL, '-'); 
            RAISE EXCEPTION 'pDownloadURL (raw) is not valid'; 
        END IF;
    
        --get the proper ticket and concatenate it with the pDownloadURL
        pTicket := get_umls_ticket (pVocabulary_auth, pVocabulary_login, pDownloadURL);
        
        pDownloadURL := pDownloadURL || '?ticket=' || pTicket;

        PERFORM write_log (
            iVocabularyID => pVocabularyID,
            iSessionID => pSession,
            iVocabulary_operation => pVocabularyOperation || ' authorization successful',
            iVocabulary_status => 1
        );

        --start downloading
        pVocabularyOperation:='GET_SNOMED US-part downloading';
        
        PERFORM run_wget (
            iPath => pVocabulary_load_path,
            iFilename => lower(pVocabularyID) || '.zip',
            iDownloadLink => pDownloadURL,
            iDeleteAll => 0
        );
        
        PERFORM write_log (
            iVocabularyID => pVocabularyID,
            iSessionID => pSession,
            iVocabulary_operation => 'GET_SNOMED US-part downloading complete',
            iVocabulary_status => 1
        );
    END IF;

    -- US prepare
    IF pJumpToOperation IN ('ALL','JUMP_TO_SNOMED_US') 
    THEN
        --extraction
        pVocabularyOperation:='GET_SNOMED US prepare';
        
        PERFORM get_snomed_prepare_us (
            iPath => pVocabulary_load_path,
            iFilename => lower(pVocabularyID) || '.zip'
        );
        
        PERFORM write_log (
            iVocabularyID => pVocabularyID,
            iSessionID => pSession,
            iVocabulary_operation => 'GET_SNOMED US prepare complete',
            iVocabulary_status => 1
        );
    END IF;

    -- UK_DE download
    IF pJumpToOperation IN ('ALL','JUMP_TO_SNOMED_UK_DE') 
    THEN
        pVocabularyOperation := 'GET_SNOMED UK DE-part';
        
        --get credentials
        SELECT vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass, MAX(vocabulary_order) OVER()
          INTO pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass, z 
          FROM devv5.vocabulary_access 
         WHERE vocabulary_id = pVocabularyID 
           AND vocabulary_order = 5;
    
        --authorization
        SELECT (SELECT value 
                  FROM json_each_text(http_headers) 
                 WHERE LOWER(key) = 'set-cookie'), 
               http_content 
          INTO pCookie, pContent
          FROM py_http_post(url => pVocabulary_auth, 
                            params => 'j_username=' || devv5.urlencode(pVocabulary_login) || 
                                      '&j_password=' || devv5.urlencode(pVocabulary_pass) || 
                                      '&commit=LOG%20IN');
                                      
        IF pCookie NOT LIKE '%JSESSIONID=%' 
        THEN 
            pErrorDetails := pCookie || CRLF || CRLF || pContent; 
            RAISE EXCEPTION 'cookie %%JSESSIONID=%% not found'; 
        END IF;
    
        --get working download link
        pCookie = SUBSTRING(pCookie,'JSESSIONID=(.*?);');
        
        SELECT http_content 
          INTO pContent 
          FROM py_http_get(url => pVocabulary_url,cookies => '{"JSESSIONID":"' || pCookie || '"}');
          
        pDownloadURL := SUBSTRING(pContent,'<div class="release-details__label">.+?<a href="(.*?)">.+');
    
        --start downloading
        pVocabularyOperation:='GET_SNOMED UK DE-part downloading';
        PERFORM run_wget (
            iPath => pVocabulary_load_path,
            iFilename => lower(pVocabularyID) || '.zip',
            iDownloadLink => pDownloadURL,
            iDeleteAll => 0
        );
        
        PERFORM write_log (
            iVocabularyID => pVocabularyID,
            iSessionID => pSession,
            iVocabulary_operation => 'GET_SNOMED UK DE-part downloading complete',
            iVocabulary_status => 1
        );
    END IF;

    -- UK_DE prepare
    IF pJumpToOperation IN ('ALL','JUMP_TO_SNOMED_UK_DE') 
    THEN
        --extraction
        pVocabularyOperation := 'GET_SNOMED UK DE prepare';
        
        PERFORM get_snomed_prepare_uk_de (
            iPath => pVocabulary_load_path,
            iFilename => LOWER(pVocabularyID) || '.zip'
        );
        PERFORM write_log (
            iVocabularyID => pVocabularyID,
            iSessionID => pSession,
            iVocabulary_operation => 'GET_SNOMED UK DE prepare complete',
            iVocabulary_status => 1
        );
    END IF;
  
    IF pJumpToOperation IN ('ALL','JUMP_TO_SNOMED_IMPORT',
                            'JUMP_TO_SNOMED_INT', 
                            'JUMP_TO_SNOMED_UK', 
                            'JUMP_TO_SNOMED_US' ,
                            'JUMP_TO_SNOMED_UK_DE') 
    THEN
        --finally we have all input tables, we can start importing
        pVocabularyOperation := 'GET_SNOMED load_input_tables';
        
        PERFORM sources.load_input_tables(pVocabularyID, pVocabularyNewDate, pVocabularyNewVersion);
        
        PERFORM write_log (
            iVocabularyID => pVocabularyID,
            iSessionID => pSession,
            iVocabulary_operation => 'GET_SNOMED load_input_tables complete',
            iVocabulary_status => 1
        );
    END IF;
    
    PERFORM write_log (
        iVocabularyID => pVocabularyID,
        iSessionID => pSession,
        iVocabulary_operation => 'GET_SNOMED all tasks done',
        iVocabulary_status => 3
    );
  
    session_id := pSession;
    last_status := 3;
    result_output := TO_CHAR(pVocabularySrcDate,'YYYYMMDD') || ' -> ' || TO_CHAR(pVocabularyNewDate,'YYYYMMDD') || ', ' || pVocabularySrcVersion || ' -> ' || pVocabularyNewVersion;
    
    RETURN;
  
EXCEPTION WHEN OTHERS 
THEN
    GET stacked DIAGNOSTICS cRet = pg_exception_context;
    cRet:='ERROR: ' || SQLERRM || CRLF || 'CONTEXT: ' || cRet;
    set local search_path to vocabulary_download;
    
    PERFORM write_log (
        iVocabularyID => pVocabularyID,
        iSessionID => pSession,
        iVocabulary_operation => pVocabularyOperation,
        iVocabulary_error => cRet,
        iError_details => pErrorDetails,
        iVocabulary_status => 2
    );

    session_id:=pSession;
    last_status:=2;
    result_output:=cRet;
    
    RETURN;
END;
$BODY$
LANGUAGE 'plpgsql'
SECURITY DEFINER;