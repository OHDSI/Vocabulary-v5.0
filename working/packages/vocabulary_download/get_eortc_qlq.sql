CREATE OR REPLACE FUNCTION vocabulary_download.get_eortc_qlq(
    iOperation TEXT DEFAULT NULL,
    OUT session_id int4,
    OUT last_status INT,
    OUT result_output TEXT
)
AS
$BODY$
DECLARE
    pVocabularyID constant TEXT := 'EORTC';
    pVocabulary_auth vocabulary_access.vocabulary_auth%TYPE;
    pVocabulary_url vocabulary_access.vocabulary_url%TYPE;
    pVocabulary_login vocabulary_access.vocabulary_login%TYPE;
    pVocabulary_pass vocabulary_access.vocabulary_pass%TYPE;
    pVocabularySrcDate DATE;
    pVocabularySrcVersion TEXT;
    pVocabularyNewDate DATE;
    pVocabularyNewVersion TEXT;
    pCookie TEXT;
    pCookie_p1 TEXT;
    pCookie_p1_value TEXT;
    pCookie_p2 TEXT;
    pCookie_p2_value TEXT;
    pContent TEXT;
    pDownloadURL TEXT;
    auth_hidden_param VARCHAR(10000);
    pErrorDetails TEXT;
    pVocabularyOperation TEXT;
    pAuthToken TEXT;
    /*
      possible values of pJumpToOperation:
      ALL (default), JUMP_TO_META_PREPARE, JUMP_TO_META_IMPORT
    */
    pJumpToOperation TEXT;
    z INT;
    cRet TEXT;
    CRLF constant TEXT:=E'\r\n';
    pSession INT4;
    pVocabulary_load_path TEXT;
BEGIN
    pVocabularyOperation:='GET_EORTC';
    
    SELECT NEXTVAL('vocabulary_download.log_seq') INTO pSession;
    
    SELECT new_date, new_version, src_date, src_version 
      INTO pVocabularyNewDate, pVocabularyNewVersion, pVocabularySrcDate, pVocabularySrcVersion 
      FROM vocabulary_pack.CheckVocabularyUpdate(pVocabularyID);
    
    SET LOCAL search_path TO vocabulary_download;
    
    PERFORM write_log (
        iVocabularyID => pVocabularyID,
        iSessionID => pSession,
        iVocabulary_operation => pVocabularyOperation||' started',
        iVocabulary_status => 0
    );

    IF iOperation IS NULL 
    THEN 
        pJumpToOperation := 'ALL'; 
    ELSE 
        pJumpToOperation := iOperation; 
    END IF;

    IF iOperation NOT IN ('ALL', 
                          'JUMP_TO_META_PREPARE',
                          'JUMP_TO_META_IMPORT')
    THEN 
        RAISE EXCEPTION 'Wrong iOperation %', iOperation; 
    END IF;
    
    IF NOT pg_try_advisory_xact_lock(hashtext(pVocabularyID)) 
    THEN 
        RAISE EXCEPTION 'Processing of % already started', pVocabularyID; 
    END IF;

    IF pJumpToOperation IN ('ALL','JUMP_TO_META_IMPORT') 
    THEN
        pJumpToOperation := 'ALL';
        
        SELECT vocabulary_auth, vocabulary_url, vocabulary_login, vocabulary_pass
          INTO pVocabulary_auth, pVocabulary_url, pVocabulary_login, pVocabulary_pass 
          FROM devv5.vocabulary_access 
         WHERE vocabulary_id = pVocabularyID 
           AND vocabulary_order = 1;
           
        SELECT var_value||pVocabularyID 
          INTO pVocabulary_load_path 
          FROM devv5.config$ 
         WHERE var_name = 'vocabulary_load_path';

        SELECT (SELECT VALUE 
                  FROM json_each_text(http_content::json) 
                 WHERE LOWER(KEY)='access_token')
          INTO pAuthToken
          FROM vocabulary_download.py_http_post(url => pVocabulary_auth, 
                                                params => 'username='||devv5.urlencode(pVocabulary_login)||
                                                '&password='||devv5.urlencode(pVocabulary_pass)||
                                                '&grant_type=password');

        PERFORM vocabulary_download.py_get_eortc_qlq(pAuthToken, pVocabulary_load_path);
        
        PERFORM sources.load_input_tables(pVocabularyID, pVocabularyNewDate, pVocabularyNewVersion);
        
        PERFORM write_log (
            iVocabularyID => pVocabularyID,
            iSessionID => pSession,
            iVocabulary_operation => 'GET_EORTC load_input_tables complete',
            iVocabulary_status => 1
        );
    END IF;
      
    PERFORM write_log (
        iVocabularyID => pVocabularyID,
        iSessionID => pSession,
        iVocabulary_operation => 'GET_EORTC all tasks done',
        iVocabulary_status => 3
    );
    
    session_id := pSession;
    last_status := 3;
    result_output := TO_CHAR(pVocabularySrcDate,'YYYYMMDD') || ' -> ' || 
                     TO_CHAR(pVocabularyNewDate,'YYYYMMDD') ||', ' || pVocabularySrcVersion || ' -> ' || pVocabularyNewVersion;
    RETURN;
    
    EXCEPTION WHEN OTHERS THEN
        GET stacked DIAGNOSTICS cRet = pg_exception_context;
        cRet := 'ERROR: ' || SQLERRM || CRLF || 'CONTEXT: ' || cRet;
        SET LOCAL search_path TO vocabulary_download;
        
        PERFORM write_log (
          iVocabularyID => pVocabularyID,
          iSessionID => pSession,
          iVocabulary_operation => pVocabularyOperation,
          iVocabulary_error => cRet,
          iError_details => pErrorDetails,
          iVocabulary_status => 2
        );
        
        session_id := pSession;
        last_status := 2;
        result_output := cRet;
        RETURN;
END;
$BODY$
LANGUAGE 'plpgsql'
SECURITY DEFINER;