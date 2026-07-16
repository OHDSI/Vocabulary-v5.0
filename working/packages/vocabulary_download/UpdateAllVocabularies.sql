CREATE OR REPLACE FUNCTION vocabulary_download.UpdateAllVocabularies () 
RETURNS void AS
$body$
DECLARE
    cModuleName CONSTANT TEXT := 'AUTOMATION';
    cVocab devv5.vocabulary_access%ROWTYPE;
    cVocabA devv5.vocabulary_access%ROWTYPE;
    cRet TEXT;
    cRet2 TEXT;
    cOldDate DATE;
    cNewDate DATE;
    cSrcDate DATE;
    cOldVersion VARCHAR(100);
    cNewVersion VARCHAR(100);
    cSrcVersion VARCHAR(100);
    cSessionID int4;
    cLastStatusID INT;
    cResult TEXT;
    cFastRecreateScript TEXT;
    cLoadStageURL TEXT;
    cMoveToDevv5 TEXT;
    cLoadStageScript TEXT;
    cScriptFailed boolean;
    cScriptErrorText TEXT;
    cParameters TEXT;
    pSession int4;
    cMailText TEXT;
    cVocabularyId TEXT;
    crlf CONSTANT VARCHAR(4) := '<br>';
    crlfSQL CONSTANT VARCHAR(4) := E'\r\n';
    cEmail VARCHAR(1000);
    cHTML_OK CONSTANT VARCHAR(100) := '<font color=''green''>&#10004;</font> ';
    cHTML_ERROR CONSTANT VARCHAR(100) := '<font color=''red''>&#10008;</font> ';
    cHTML_WAITING CONSTANT VARCHAR(100) := '<font color=''e6e600''>&#9650;</font> ';
    cHTML_DISABLED CONSTANT VARCHAR(100) := '&#10811; ';
BEGIN
    SELECT NEXTVAL('vocabulary_download.log_seq') INTO pSession;
    
    PERFORM vocabulary_download.write_log (
        iVocabularyID => cModuleName,
        iSessionID => pSession,
        iVocabulary_operation => cModuleName||' started',
        iVocabulary_status => 0
    );
  
    IF NOT pg_try_advisory_xact_lock(hashtext(cModuleName)) 
    THEN 
        RAISE EXCEPTION 'Automation already started'; 
    END IF;
  
    SELECT c.var_value 
      INTO cEmail 
      FROM devv5.config$ c 
     WHERE c.var_name = 'vocabulary_download_email';
  
    FOR cVocab IN (
        SELECT * 
          FROM devv5.vocabulary_access vc 
         WHERE vc.vocabulary_order = 1 
           AND vc.vocabulary_update_after IS NULL 
           AND vc.vocabulary_enabled = 1
         ORDER BY CASE vc.vocabulary_id 
                      WHEN 'UMLS' THEN 1 
                      WHEN 'META' THEN 2 
                      WHEN 'SNOMED' THEN 3 
                      WHEN 'RXNORM' THEN 4 
                      ELSE 5 
                  END, 
                  vc.vocabulary_id) 
    LOOP
        BEGIN
            SELECT old_date, 
                   new_date, 
                   old_version, 
                   new_version, 
                   src_date, 
                   src_version 
              INTO cOldDate, 
                   cNewDate, 
                   cOldVersion, 
                   cNewVersion, 
                   cSrcDate, 
                   cSrcVersion
              FROM vocabulary_pack.CheckVocabularyUpdate (cVocab.vocabulary_id);
              
            cScriptFailed := FALSE;
            cScriptErrorText := NULL;
          
            IF COALESCE(cSrcDate::VARCHAR,cSrcVersion) <> COALESCE(cNewDate::VARCHAR,cNewVersion) 
            THEN
                IF cVocab.vocabulary_id LIKE 'SNOMED_%'
                THEN
                    -- To execute get_snomed function with the iOperation parameter for SNOMED modules
                    cParameters := 'iOperation => ''JUMP_TO_' || cVocab.vocabulary_id || '''::TEXT';
                    cVocabularyId := 'SNOMED';
                ELSE 
                    -- To execut default get_<vocabulary_id>() function
                    cParameters := '';
                    cVocabularyId := REPLACE(cVocab.vocabulary_id,' ','_');
                END IF;
                
                --update vocabulary in source-schema
                EXECUTE 'SELECT session_id, last_status, result_output FROM vocabulary_download.get_' 
                        || cVocabularyId || '(' || cParameters || ')'
                   INTO cSessionID, cLastStatusID, cResult;
                        
                IF cLastStatusID = 3 
                THEN --the downloading/parsing was successfull
                    IF cVocab.vocabulary_dev_schema IS NOT NULL 
                    THEN
                        --set dev-schema
                        EXECUTE 'set local session authorization '||cVocab.vocabulary_dev_schema;
                        
                        --parsing the params (json)
                        cFastRecreateScript := cVocab.vocabulary_params ->> 'fast_recreate_script';
                        cLoadStageURL := cVocab.vocabulary_params ->> 'load_stage_path';
                        cMoveToDevv5 := cVocab.vocabulary_params ->> 'move_to_devv5';
                
                        IF cFastRecreateScript IS NOT NULL 
                        THEN
                            BEGIN --use another begin/end block because we don't want to rollback previous changes (fast recreate)
                                cFastRecreateScript := 'do $AutomationSctipt$ begin perform '||crlfSQL||cFastRecreateScript||crlfSQL
                                    || '; end $AutomationSctipt$';
                                RESET SEARCH_PATH;
                                EXECUTE cFastRecreateScript;
                                
                                PERFORM vocabulary_download.write_log (
                                    iVocabularyID => cModuleName,
                                    iSessionID => pSession,
                                    iVocabulary_operation => 'fast_recreate for '||cVocab.vocabulary_dev_schema||' finished',
                                    iVocabulary_status => 1
                                );
                            
                            EXCEPTION WHEN OTHERS 
                                THEN
                                    GET stacked DIAGNOSTICS cRet = pg_exception_context;
                                    cRet := 'ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                                    cScriptFailed := TRUE; --the 'Failed' marker
                                    cScriptErrorText := 'fast_recreate failed: '||SQLERRM;
                                    
                                    PERFORM vocabulary_download.write_log (
                                        iVocabularyID => cModuleName,
                                        iSessionID => pSession,
                                        iVocabulary_operation => 'fast_recreate for '||cVocab.vocabulary_dev_schema||' failed',
                                        iVocabulary_error => cRet,
                                        iVocabulary_status => 2
                                    );
                            END;
                        END IF;
                
                        --run load_stage
                        IF cLoadStageURL IS NOT NULL 
                        THEN 
                            IF NOT cScriptFailed 
                            THEN
                                BEGIN --use another begin/end block because we don't want to rollback previous changes (fast recreate)
                                    SELECT http_content 
                                      INTO cLoadStageScript 
                                      FROM vocabulary_download.py_http_get(url => cLoadStageURL,allow_redirects => TRUE);
                                    
                                    cLoadStageScript := 'do $AutomationSctipt$ begin '||crlfSQL||cLoadStageScript||crlfSQL||' END $AutomationSctipt$';
                                    RESET SEARCH_PATH;
                                    EXECUTE cLoadStageScript;
                                    
                                    PERFORM vocabulary_download.write_log (
                                        iVocabularyID => cModuleName,
                                        iSessionID => pSession,
                                        iVocabulary_operation => 'load_stage for '||cVocab.vocabulary_dev_schema||' finished',
                                        iVocabulary_status => 1
                                    );
                                EXCEPTION WHEN OTHERS 
                                THEN
                                    GET stacked DIAGNOSTICS cRet = pg_exception_context;
                                    cRet := 'ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                                    cScriptFailed := TRUE; --the 'Failed' marker
                                    cScriptErrorText := 'load_stage failed: '||SQLERRM;
                                    
                                    PERFORM vocabulary_download.write_log (
                                        iVocabularyID => cModuleName,
                                        iSessionID => pSession,
                                        iVocabulary_operation => 'load_stage for '||cVocab.vocabulary_dev_schema||' failed',
                                        iVocabulary_error => cRet,
                                        iVocabulary_status => 2
                                    );
                                END;
                            END IF;
                  
                            --run generic_update after load_stage
                            IF NOT cScriptFailed 
                            THEN
                                BEGIN
                                    RESET SEARCH_PATH;
                                    PERFORM devv5.GenericUpdate();
                                    
                                    PERFORM vocabulary_download.write_log (
                                        iVocabularyID => cModuleName,
                                        iSessionID => pSession,
                                        iVocabulary_operation => 'generic_update for '||cVocab.vocabulary_dev_schema||' finished',
                                        iVocabulary_status => 1
                                    );
                                EXCEPTION WHEN OTHERS 
                                THEN
                                    GET stacked DIAGNOSTICS cRet = pg_exception_context;
                                    cRet := 'ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                                    cScriptFailed := TRUE; --the 'Failed' marker
                                    cScriptErrorText := 'generic_update failed: '||SQLERRM;
                                    
                                    PERFORM vocabulary_download.write_log (
                                        iVocabularyID => cModuleName,
                                        iSessionID => pSession,
                                        iVocabulary_operation => 'generic_update for '||cVocab.vocabulary_dev_schema||' failed',
                                        iVocabulary_error => cRet,
                                        iVocabulary_status => 2
                                    );
                                END;
                            END IF;
                  
                            --move to devv5
                            IF NOT cScriptFailed AND cMoveToDevv5 = '1' 
                            THEN
                                BEGIN
                                    RESET SEARCH_PATH;
                                    PERFORM vocabulary_pack.ClearBasicTables(); --AVOF-3148
                                    RESET SESSION AUTHORIZATION;
                                    EXECUTE cLoadStageScript;
                                    PERFORM devv5.GenericUpdate();
                                    
                                    PERFORM vocabulary_download.write_log (
                                        iVocabularyID => cModuleName,
                                        iSessionID => pSession,
                                        iVocabulary_operation => 'moving to devv5 for '||cVocab.vocabulary_dev_schema||' finished',
                                        iVocabulary_status => 1
                                    );
                                EXCEPTION WHEN OTHERS 
                                THEN
                                    GET stacked DIAGNOSTICS cRet = pg_exception_context;
                                    cRet := 'ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                                    cScriptFailed := TRUE; --the 'Failed' marker
                                    cScriptErrorText := 'moving to devv5 failed: '||SQLERRM;
                                    
                                    PERFORM vocabulary_download.write_log (
                                        iVocabularyID => cModuleName,
                                        iSessionID => pSession,
                                        iVocabulary_operation => 'moving to devv5 for '||cVocab.vocabulary_dev_schema||' failed',
                                        iVocabulary_error => cRet,
                                        iVocabulary_status => 2
                                    );
                                END;
                            END IF;
                        END IF;
                    END IF;
                    
                    RESET SESSION AUTHORIZATION;
                    RESET SEARCH_PATH;
              
                    --store result
                    cRet := COALESCE(TO_CHAR(cSrcDate,'yyyymmdd'),cSrcVersion)||' -> '||COALESCE(TO_CHAR(cNewDate,'yyyymmdd'),cNewVersion);
                    
                    IF NOT cScriptFailed 
                    THEN
                        IF cMoveToDevv5 = '1' 
                        THEN
                            cRet := cHTML_OK||'<b>'||cVocab.vocabulary_id||'</b> was updated! ['||cRet||'] [devv5]';
                        ELSE
                            cRet := cHTML_OK||'<b>'||cVocab.vocabulary_id||'</b> was updated! ['||cRet||']';
                        END IF;
                    ELSE
                        cRet := cHTML_ERROR||'<b>'||cVocab.vocabulary_id||'</b> was updated in sources ['||cRet||'], but '||cScriptErrorText;
                    END IF;
                    
                    cMailText := concat(cMailText||crlf,cRet);
              
                    --update additional (dependent) vocabularies
                    FOR cVocabA IN (
                        SELECT * 
                          FROM devv5.vocabulary_access vc 
                         WHERE vc.vocabulary_order = 1 
                           AND vc.vocabulary_update_after = cVocab.vocabulary_id 
                           AND vc.vocabulary_enabled = 1
                         ORDER BY vc.vocabulary_id) 
                    LOOP
                        cScriptFailed := FALSE;
                        cScriptErrorText := NULL;
                        
                        BEGIN
                            IF cVocabA.vocabulary_dev_schema IS NOT NULL 
                            THEN
                                --set dev-schema
                                EXECUTE 'set local session authorization '||cVocabA.vocabulary_dev_schema;
                                --parsing the params (json)
                                cFastRecreateScript := cVocabA.vocabulary_params ->> 'fast_recreate_script';
                                cLoadStageURL := cVocabA.vocabulary_params ->> 'load_stage_path';
                                cMoveToDevv5 := cVocabA.vocabulary_params ->> 'move_to_devv5';
                                
                                IF cFastRecreateScript IS NOT NULL 
                                THEN
                                    BEGIN --use another begin/end block because we don't want to rollback previous changes (fast recreate)
                                        cFastRecreateScript := 'do $AutomationSctipt$ begin perform '||crlfSQL||cFastRecreateScript||crlfSQL||'; end $AutomationSctipt$';
                                        RESET SEARCH_PATH;
                                        
                                        EXECUTE cFastRecreateScript;
                                        
                                        PERFORM vocabulary_download.write_log (
                                            iVocabularyID => cModuleName,
                                            iSessionID => pSession,
                                            iVocabulary_operation => 'fast_recreate for '||cVocabA.vocabulary_dev_schema||' finished',
                                            iVocabulary_status => 1
                                        );
                                    EXCEPTION WHEN OTHERS 
                                    THEN
                                        GET stacked DIAGNOSTICS cRet = pg_exception_context;
                                        cRet := 'ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                                        cScriptFailed := TRUE; --the 'Failed' marker
                                        cScriptErrorText := 'fast_recreate failed: '||SQLERRM;
                                        
                                        PERFORM vocabulary_download.write_log (
                                            iVocabularyID => cModuleName,
                                            iSessionID => pSession,
                                            iVocabulary_operation => 'fast_recreate for '||cVocabA.vocabulary_dev_schema||' failed',
                                            iVocabulary_error => cRet,
                                            iVocabulary_status => 2
                                        );
                                    END;
                                END IF;
                    
                                --run load_stage
                                IF cLoadStageURL IS NOT NULL 
                                THEN
                                    IF NOT cScriptFailed 
                                    THEN
                                        BEGIN
                                            SELECT http_content 
                                              INTO cLoadStageScript 
                                              FROM vocabulary_download.py_http_get(url => cLoadStageURL,allow_redirects => TRUE);
                                              
                                            cLoadStageScript := 'do $AutomationSctipt$ begin '||crlfSQL||cLoadStageScript||crlfSQL||' end $AutomationSctipt$';
                                            
                                            RESET SEARCH_PATH;
                                            
                                            EXECUTE cLoadStageScript;
                                            
                                            PERFORM vocabulary_download.write_log (
                                                iVocabularyID => cModuleName,
                                                iSessionID => pSession,
                                                iVocabulary_operation => 'load_stage for '||cVocabA.vocabulary_dev_schema||' finished',
                                                iVocabulary_status => 1
                                            );
                                        EXCEPTION WHEN OTHERS 
                                        THEN
                                            GET stacked DIAGNOSTICS cRet = pg_exception_context;
                                            cRet := 'ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                                            cScriptFailed := TRUE; --the 'Failed' marker
                                            cScriptErrorText := 'load_stage failed: '||SQLERRM;
                                            
                                            PERFORM vocabulary_download.write_log (
                                                iVocabularyID => cModuleName,
                                                iSessionID => pSession,
                                                iVocabulary_operation => 'load_stage for '||cVocabA.vocabulary_dev_schema||' failed',
                                                iVocabulary_error => cRet,
                                                iVocabulary_status => 2
                                            );
                                        END;
                                    END IF;
                      
                                    --run generic_update after load_stage
                                    IF NOT cScriptFailed 
                                    THEN
                                        BEGIN
                                            RESET SEARCH_PATH;
                                            PERFORM devv5.GenericUpdate();
                                            
                                            PERFORM vocabulary_download.write_log (
                                                iVocabularyID => cModuleName,
                                                iSessionID => pSession,
                                                iVocabulary_operation => 'generic_update for '||cVocabA.vocabulary_dev_schema||' finished',
                                                iVocabulary_status => 1
                                            );
                                        EXCEPTION WHEN OTHERS 
                                        THEN
                                            GET stacked DIAGNOSTICS cRet = pg_exception_context;
                                            cRet := 'ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                                            cScriptFailed := TRUE; --the 'Failed' marker
                                            cScriptErrorText := 'generic_update failed: '||SQLERRM;
                                            
                                            PERFORM vocabulary_download.write_log (
                                                iVocabularyID => cModuleName,
                                                iSessionID => pSession,
                                                iVocabulary_operation => 'generic_update for '||cVocabA.vocabulary_dev_schema||' failed',
                                                iVocabulary_error => cRet,
                                                iVocabulary_status => 2
                                            );
                                        END;
                                    END IF;
                      
                                    --move to devv5
                                    IF NOT cScriptFailed AND cMoveToDevv5 = '1' 
                                    THEN
                                        BEGIN
                                            RESET SEARCH_PATH;
                                            PERFORM vocabulary_pack.ClearBasicTables(); --AVOF-3148
                                            RESET SESSION AUTHORIZATION;
                                            EXECUTE cLoadStageScript;
                                            PERFORM devv5.GenericUpdate();
                                            
                                            PERFORM vocabulary_download.write_log (
                                                iVocabularyID => cModuleName,
                                                iSessionID => pSession,
                                                iVocabulary_operation => 'moving to devv5 for '||cVocabA.vocabulary_dev_schema||' finished',
                                                iVocabulary_status => 1
                                            );
                                        EXCEPTION WHEN OTHERS 
                                        THEN
                                            GET stacked DIAGNOSTICS cRet = pg_exception_context;
                                            cRet := 'ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                                            cScriptFailed := TRUE; --the 'Failed' marker
                                            cScriptErrorText := 'moving to devv5 failed: '||SQLERRM;
                                            
                                            PERFORM vocabulary_download.write_log (
                                                iVocabularyID => cModuleName,
                                                iSessionID => pSession,
                                                iVocabulary_operation => 'moving to devv5 for '||cVocabA.vocabulary_dev_schema||' failed',
                                                iVocabulary_error => cRet,
                                                iVocabulary_status => 2
                                            );
                                        END;
                                    END IF;
                                END IF;
                            END IF;
                            
                            RESET SESSION authorization;
                            RESET SEARCH_PATH;
                  
                            --store result
                            IF NOT cScriptFailed 
                            THEN
                                IF cMoveToDevv5 = '1' 
                                THEN
                                    cRet := cHTML_OK||'<b>'||cVocabA.vocabulary_id||'</b> was updated! [based on '||cVocab.vocabulary_id||'] [devv5]';
                                ELSE
                                    cRet := cHTML_OK||'<b>'||cVocabA.vocabulary_id||'</b> was updated! [based on '||cVocab.vocabulary_id||']';
                                END IF;
                            ELSE
                                cRet := cHTML_ERROR||'<b>'||cVocabA.vocabulary_id||'</b> was updated [based on '||cVocab.vocabulary_id||'], but '||cScriptErrorText;
                            END IF;
                            
                            cMailText := concat(cMailText||crlf,cRet);
                  
                        EXCEPTION WHEN OTHERS 
                        THEN
                            RESET SESSION AUTHORIZATION;
                            RESET SEARCH_PATH;
                            GET stacked DIAGNOSTICS cRet = pg_exception_context;
                            cRet := 'ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                            cMailText := concat(cMailText||crlf,cHTML_ERROR||'<b>'||cVocabA.vocabulary_id||'</b> returns error: '||SQLERRM);
                            
                            PERFORM vocabulary_download.write_log (
                                iVocabularyID => cModuleName,
                                iSessionID => pSession,
                                iVocabulary_operation => 'update for '||cVocabA.vocabulary_id||' failed',
                                iVocabulary_error => cRet,
                                iVocabulary_status => 2
                            );
                        END;
                    END LOOP;
                    
                    RESET SESSION AUTHORIZATION;
                    RESET SEARCH_PATH;
                ELSE
                    RAISE EXCEPTION 'sessionID=%, %',cSessionID,cResult;
                END IF;
            ELSE
                --vocabulary already updated
                IF COALESCE(cSrcDate::VARCHAR,cNewDate::VARCHAR,cSrcVersion,cNewVersion) IS NOT NULL 
                THEN --if all values are NULL - vocabulary already fully updated (in sources and devv5)
                    --inform that vocabulary was updated, but only in sources
                    cRet := COALESCE(TO_CHAR(cOldDate,'yyyymmdd'),cOldVersion)||' -> '||COALESCE(TO_CHAR(cNewDate,'yyyymmdd'),cNewVersion);
                    cRet := cHTML_WAITING||'<b>'||cVocab.vocabulary_id||'</b> was already updated in sources ['||cRet||']. Waiting for migration to devv5';
                    cMailText := concat(cMailText||crlf,cRet);
                ELSE --special case for additional (dependent) vocabularies
                    FOR cVocabA IN (
                        SELECT * 
                          FROM devv5.vocabulary_access vc 
                         WHERE vc.vocabulary_order = 1 
                           AND vc.vocabulary_update_after = cVocab.vocabulary_id 
                           AND vc.vocabulary_enabled = 1
                         ORDER BY vc.vocabulary_id) 
                    LOOP
                        BEGIN
                            SELECT old_date, new_date, old_version, new_version, src_date, src_version 
                              INTO cOldDate, cNewDate, cOldVersion, cNewVersion, cSrcDate, cSrcVersion
                              FROM vocabulary_pack.CheckVocabularyUpdate (cVocabA.vocabulary_id);
                        
                            IF COALESCE(cSrcDate::VARCHAR,cSrcVersion) <> COALESCE(cOldDate::VARCHAR,cOldVersion) 
                            THEN
                                --inform that vocabulary was updated, but only in sources
                                cRet := COALESCE(TO_CHAR(cOldDate,'yyyymmdd'),cOldVersion)||' -> '||
                                    COALESCE(TO_CHAR(cSrcDate,'yyyymmdd'),cSrcVersion);
                                    
                                cRet := cHTML_WAITING||'<b>'||cVocabA.vocabulary_id||
                                    '</b> was already updated in sources ['||cRet||']. Waiting for migration to devv5';
                                    
                                cMailText := concat(cMailText||crlf,cRet);
                            END IF;
                            
                        EXCEPTION WHEN OTHERS 
                        THEN
                            RESET SESSION AUTHORIZATION;
                            RESET SEARCH_PATH;
                            GET stacked DIAGNOSTICS cRet = pg_exception_context;
                            cRet := 'ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
                            
                            cMailText := concat(cMailText||crlf,cHTML_ERROR||'<b>'||cVocabA.vocabulary_id||'</b> returns error: '||SQLERRM);
                            
                            PERFORM vocabulary_download.write_log (
                                iVocabularyID => cModuleName,
                                iSessionID => pSession,
                                iVocabulary_operation => 'check for '||cVocabA.vocabulary_id||' failed',
                                iVocabulary_error => cRet,
                                iVocabulary_status => 2
                            );
                        END;
                    END LOOP;
                END IF;
            END IF;
          
        EXCEPTION WHEN OTHERS 
        THEN
            RESET SESSION AUTHORIZATION;
            RESET SEARCH_PATH;
            GET stacked DIAGNOSTICS cRet = pg_exception_context;
            cRet := 'ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
            cMailText := concat(cMailText||crlf,cHTML_ERROR||'<b>'||cVocab.vocabulary_id||'</b> returns error: '||SQLERRM);
            
            PERFORM vocabulary_download.write_log (
                iVocabularyID => cModuleName,
                iSessionID => pSession,
                iVocabulary_operation => 'update for '||cVocab.vocabulary_id||' failed',
                iVocabulary_error => cRet,
                iVocabulary_status => 2
            );
        END;
    END LOOP;

    --check for disabled
    SELECT string_agg(distinct vocabulary_id,', ' ORDER BY vocabulary_id) 
      INTO cRet2 
      FROM devv5.vocabulary_access 
     WHERE vocabulary_enabled = 0;
     
    cMailText := cMailText||
        COALESCE(crlf||crlf||cHTML_DISABLED||'Disabled vocabularies: '||cRet2,'');
    
    SELECT string_agg(vocabulary_id,', ' ORDER BY vocabulary_id) 
      INTO cRet2 
      FROM devv5.vocabulary_access 
     WHERE vocabulary_order = 1 
       AND vocabulary_params IS NULL 
       AND vocabulary_enabled = 1 
       AND vocabulary_id NOT IN ('UMLS','META');
       
    cMailText := cMailText||crlf||crlf||'<font color=''#8c8c8c''><pre>---------------'||crlf||
        '- ISBT means ISBT and ISBT Attribute'||crlf||
        COALESCE('- For '||cRet2||' only source tables are updated'||crlf,'')||
        '</pre></font>';
    
    --send e-mail
    cMailText := COALESCE(cMailText,'Nothing to update');
    
    PERFORM devv5.SendMailHTML(cEmail, 'Automation notification service', cMailText);
    
    PERFORM vocabulary_download.write_log (
        iVocabularyID => cModuleName,
        iSessionID => pSession,
        iVocabulary_operation => cModuleName||' all tasks are done',
        iVocabulary_status => 3
    );
  
EXCEPTION WHEN OTHERS 
THEN
   GET stacked DIAGNOSTICS cRet = pg_exception_context;
   cRet := 'ERROR: '||SQLERRM||crlfSQL||'CONTEXT: '||cRet;
   
   PERFORM vocabulary_download.write_log (
       iVocabularyID => cModuleName,
       iSessionID => pSession,
       iVocabulary_operation => cModuleName,
       iVocabulary_error => cRet,
       iError_details => REPLACE(cMailText,crlf,crlfSQL),
       iVocabulary_status => 2
   );
END;
$body$
LANGUAGE 'plpgsql' SECURITY INVOKER
SET client_min_messages = error;