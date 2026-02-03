/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Aliaksey Katyshou
* Date: 2025
**************************************************************************/

DROP FUNCTION vocabulary_download.get_ema(in text, out int4, out int4, out text);

CREATE OR REPLACE FUNCTION vocabulary_download.get_ema(ioperation text DEFAULT NULL::text, OUT session_id integer, OUT last_status integer, OUT result_output text)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    pVocabularyID constant TEXT := 'EMA';
    pVocabulary_url vocabulary_access.vocabulary_url%type;
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
    pApi_key TEXT;
/*
  possible values of pJumpToOperation:
  ALL (default), JUMP_TO_EMA_PREPARE, JUMP_TO_EMA_IMPORT
*/
    pJumpToOperation TEXT;
    z INT;
    cRet TEXT;
    CRLF constant TEXT:=E'\r\n';
    pSession INT4;
    pVocabulary_load_path TEXT;
BEGIN
    pVocabularyOperation:='GET_EMA';

    SELECT nextval('vocabulary_download.log_seq') INTO pSession;
  
    SELECT new_date, new_version, src_date, src_version 
      INTO pVocabularyNewDate, pVocabularyNewVersion, pVocabularySrcDate, pVocabularySrcVersion 
      FROM vocabulary_pack.CheckVocabularyUpdate(pVocabularyID);
  
    SET LOCAL search_path TO vocabulary_download;
  
    PERFORM write_log (
        iVocabularyID=>pVocabularyID,
        iSessionID=>pSession,
        iVocabulary_operation=>pVocabularyOperation||' started',
        iVocabulary_status=>0
    );
  
    IF iOperation IS NULL 
        THEN 
            pJumpToOperation := 'ALL'; 
        ELSE pJumpToOperation := iOperation; 
    END IF;
    
    IF iOperation NOT IN ('ALL',
                          'JUMP_TO_EMA_PREPARE',
                          'JUMP_TO_EMA_IMPORT') 
    THEN 
        RAISE EXCEPTION 'Wrong iOperation %',iOperation; 
    END IF;

    IF pVocabularyNewDate IS NULL 
    THEN 
        RAISE EXCEPTION '% already updated',pVocabularyID; 
    END IF;
  
    IF NOT pg_try_advisory_xact_lock(hashtext(pVocabularyID)) 
    THEN
        RAISE EXCEPTION 'Processing of % already started',pVocabularyID; 
    END IF;
  
    SELECT var_value||pVocabularyID 
      INTO pVocabulary_load_path 
      FROM devv5.config$ 
     WHERE var_name='vocabulary_load_path';
    
    if pJumpToOperation IN ('ALL','JUMP_TO_EMA_PREPARE') 
    THEN
        --start downloading
        pVocabularyOperation:='GET_EMA downloading';

        -- get Medicines
        PERFORM run_wget (
            iPath=>pVocabulary_load_path,
            iFilename=>'medicines-output-medicines-report_en.xlsx',
            iDownloadLink=>'https://www.ema.europa.eu/en/documents/report/medicines-output-medicines-report_en.xlsx'
        );

        -- get Post-authorisation procedures for medicines
        PERFORM run_wget (
            iPath=>pVocabulary_load_path,
            iFilename=>'medicines-output-post_authorisation-report_en.xlsx',
            iDownloadLink=>'https://www.ema.europa.eu/en/documents/report/medicines-output-post_authorisation-report_en.xlsx',
            iDeleteAll=>0
        );

        -- get Orphan designations
        PERFORM run_wget (
            iPath=>pVocabulary_load_path,
            iFilename=>'medicines-output-orphan_designations-report_en.xlsx',
            iDownloadLink=>'https://www.ema.europa.eu/en/documents/report/medicines-output-orphan_designations-report_en.xlsx',
            iDeleteAll=>0
        );

        -- get Herbal medicines
        PERFORM run_wget (
            iPath=>pVocabulary_load_path,
            iFilename=>'medicines-output-herbal_medicines-report_en.xlsx',
            iDownloadLink=>'https://www.ema.europa.eu/en/documents/report/medicines-output-herbal_medicines-report_en.xlsx',
            iDeleteAll=>0
        );

        PERFORM write_log (
            iVocabularyID=>pVocabularyID,
            iSessionID=>pSession,
            iVocabulary_operation=>'GET_EMA downloading complete',
            iVocabulary_status=>1
        );
    END IF;
  
    IF pJumpToOperation IN ('ALL','JUMP_TO_EMA_IMPORT') 
    THEN
        pJumpToOperation:='ALL';

        --finally we have all input tables, we can start importing
        pVocabularyOperation := 'GET_EMA load_input_tables';

        PERFORM sources.load_input_tables(pVocabularyID,pVocabularyNewDate,pVocabularyNewVersion);
        
        PERFORM write_log (
          iVocabularyID => pVocabularyID,
          iSessionID => pSession,
          iVocabulary_operation => 'GET_EMA load_input_tables complete',
          iVocabulary_status => 1
        );
    END IF;
    
    PERFORM write_log (
        iVocabularyID=>pVocabularyID,
        iSessionID=>pSession,
        iVocabulary_operation=>'GET_EMA all tasks done',
        iVocabulary_status=>3
    );
  
    session_id := pSession;
    last_status := 3;
    result_output:=to_char(pVocabularySrcDate,'YYYYMMDD')||' -> '||to_char(pVocabularyNewDate,'YYYYMMDD')||', '||pVocabularySrcVersion||' -> '||pVocabularyNewVersion;
    
    RETURN;
  
EXCEPTION WHEN OTHERS THEN
    GET stacked DIAGNOSTICS cRet = pg_exception_context;

    cRet:='ERROR: '||SQLERRM||CRLF||'CONTEXT: '||cRet;

    SET LOCAL search_path TO vocabulary_download;

    PERFORM write_log (
      iVocabularyID=>pVocabularyID,
      iSessionID=>pSession,
      iVocabulary_operation=>pVocabularyOperation,
      iVocabulary_error=>cRet,
      iError_details=>pErrorDetails,
      iVocabulary_status=>2
    );
    
    session_id := pSession;
    last_status := 2;
    result_output := cRet;
    RETURN;
END;
$function$
;
