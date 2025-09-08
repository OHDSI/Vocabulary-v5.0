CREATE OR REPLACE FUNCTION vocabulary_download.get_atc (
    iOperation TEXT DEFAULT NULL,
    OUT session_id int4,
    OUT last_status INT,
    OUT result_output TEXT
)
AS
$BODY$
DECLARE
    pVocabularyID constant TEXT:='ATC';
    pVocabulary_auth vocabulary_access.vocabulary_auth%type;
    pVocabulary_url vocabulary_access.vocabulary_url%type;
    pVocabulary_login vocabulary_access.vocabulary_login%type;
    pVocabulary_pass vocabulary_access.vocabulary_pass%type;
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
    /*
      possible values of pJumpToOperation:
      ALL (default), JUMP_TO_META_PREPARE, JUMP_TO_META_IMPORT
    */
    pJumpToOperation text;
    z int;
    cRet text;
    CRLF constant text:=E'\r\n';
    pSession int4;
    pVocabulary_load_path text;
BEGIN
    pVocabularyOperation:='GET_ATC';
    
    SELECT NEXTVAL('vocabulary_download.log_seq') INTO pSession;
    
    SELECT new_date, new_version, src_date, src_version 
      INTO pVocabularyNewDate, pVocabularyNewVersion, pVocabularySrcDate, pVocabularySrcVersion 
      FROM vocabulary_pack.CheckVocabularyUpdate(pVocabularyID);
    
    set local search_path to vocabulary_download;
    
    PERFORM write_log (
        iVocabularyID => pVocabularyID,
        iSessionID => pSession,
        iVocabulary_operation => pVocabularyOperation||' started',
        iVocabulary_status => 0
    );

    if iOperation is null 
    then 
        pJumpToOperation := 'ALL'; 
    else 
        pJumpToOperation := iOperation; 
    end if;

    if iOperation not in ('ALL', 
                          'JUMP_TO_META_PREPARE',
                          'JUMP_TO_META_IMPORT')
    then 
        raise exception 'Wrong iOperation %', iOperation; 
    end if;
    
    if pVocabularyNewDate is null 
    then 
        raise exception '% already updated', pVocabularyID; 
    end if;
    
    if not pg_try_advisory_xact_lock(hashtext(pVocabularyID)) 
    then 
        raise exception 'Processing of % already started', pVocabularyID; 
    end if;

    if pJumpToOperation in ('ALL','JUMP_TO_META_IMPORT') 
    then
        pJumpToOperation := 'ALL';
        
        --finally we have all input tables, we can start importing
        pVocabularyOperation := 'GET_ATC load_input_tables';
        
        perform sources.load_input_tables(pVocabularyID, pVocabularyNewDate, pVocabularyNewVersion);
        
        perform write_log (
            iVocabularyID => pVocabularyID,
            iSessionID => pSession,
            iVocabulary_operation => 'GET_ATC load_input_tables complete',
            iVocabulary_status => 1
        );
    end if;
      
    perform write_log (
        iVocabularyID => pVocabularyID,
        iSessionID => pSession,
        iVocabulary_operation => 'GET_ATC all tasks done',
        iVocabulary_status => 3
    );
    
    session_id := pSession;
    last_status := 3;
    result_output := to_char(pVocabularySrcDate,'YYYYMMDD') || ' -> ' || to_char(pVocabularyNewDate,'YYYYMMDD') ||', ' || pVocabularySrcVersion || ' -> ' || pVocabularyNewVersion;
    return;
    
    EXCEPTION WHEN OTHERS THEN
        get stacked diagnostics cRet = pg_exception_context;
        cRet := 'ERROR: ' || SQLERRM || CRLF || 'CONTEXT: ' || cRet;
        set local search_path to vocabulary_download;
        
        perform write_log (
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
        return;
END;
$BODY$
LANGUAGE 'plpgsql'
SECURITY DEFINER;