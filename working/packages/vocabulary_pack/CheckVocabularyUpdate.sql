CREATE OR REPLACE FUNCTION vocabulary_pack.CheckVocabularyUpdate (
  pVocabularyName VARCHAR,
  OUT old_date DATE,
  OUT new_date date,
  OUT old_version VARCHAR,
  OUT new_version VARCHAR,
  OUT src_date DATE,
  OUT src_version VARCHAR
)
AS
$body$
DECLARE
    /*
    CREATE TABLE devv5.vocabulary_access(
        vocabulary_id VARCHAR (20) NOT NULL,
        vocabulary_auth VARCHAR (500),
        vocabulary_url VARCHAR (500) NOT NULL,
        vocabulary_login VARCHAR (100),
        vocabulary_pass VARCHAR (100),
        vocabulary_order INT NOT NULL,
        vocabulary_source_table VARCHAR (1000),
        vocabulary_dev_schema VARCHAR (100),
        vocabulary_update_after VARCHAR (20),
        vocabulary_params JSONB,
        vocabulary_enabled INT NOT NULL DEFAULT 1);
    ALTER TABLE devv5.vocabulary_access ADD CONSTRAINT unique_vocab_access UNIQUE (vocabulary_id,vocabulary_order);
    */
    cURL            devv5.vocabulary_access.vocabulary_url%TYPE;
    cVocabOldDate   DATE;
    cVocabOldVer    VARCHAR (500);
    cVocabSrcDate   DATE;
    cVocabHTML      TEXT;
    cVocabDate      DATE;
    cVocabVer       VARCHAR (500);
    cVocabSrcVer    VARCHAR (500);
    cPos1           INT4;
    cPos2           INT4;
    cSearchString   VARCHAR (500);
    cVocabSrcTable  VARCHAR (1000);
    cVocabularyName VARCHAR (20);
BEGIN
    cVocabularyName := UPPER(pVocabularyName);
    
    SET LOCAL search_path TO devv5;
    
    IF pVocabularyName IS NULL
    THEN
        RAISE EXCEPTION '% cannot be empty!', pVocabularyName;
    END IF;

    SELECT vocabulary_url, vocabulary_source_table
      INTO cURL, cVocabSrcTable
      FROM vocabulary_access
     WHERE UPPER(vocabulary_id) = cVocabularyName 
       AND vocabulary_order = 1;

    IF cURL IS NULL
    THEN
        RAISE EXCEPTION '% not found in vocabulary_access table!', pVocabularyName;
    END IF;
    
    --Get date and version from main sources tables. This is necessary to determine partial update of the vocabulary (only in sources)
    IF cVocabSrcTable IS NOT NULL 
    THEN
      --added 'order by' clause due to CDM
      EXECUTE 'select vocabulary_date, vocabulary_version from '||cVocabSrcTable||' order by vocabulary_date desc limit 1' 
         INTO cVocabSrcDate, cVocabSrcVer;
    END IF;

    SELECT COALESCE (latest_update, TO_DATE ('19700101', 'yyyymmdd')), 
           vocabulary_version 
      INTO cVocabOldDate, 
           cVocabOldVer 
      FROM (SELECT vc.latest_update, 
                   SUBSTRING(REPLACE(v.vocabulary_version,v.vocabulary_id,''),'[\d.-]+[A-z]*[\d./-]*') AS vocabulary_version, 
                   vc.vocabulary_id_v5 AS vocabulary_id
              FROM devv5.vocabulary_conversion vc
              JOIN devv5.vocabulary v ON v.vocabulary_id = vc.vocabulary_id_v5
              UNION ALL
              (SELECT vocabulary_date, vocabulary_version, 'UMLS' FROM sources.mrsmap LIMIT 1)
              UNION ALL
              (SELECT vocabulary_date, vocabulary_version, 'META' FROM sources.meta_mrsab LIMIT 1)
           ) AS s
     WHERE UPPER(vocabulary_id) = CASE cVocabularyName 
                                      WHEN 'NDC_SPL' THEN 'NDC' 
                                      WHEN 'DMD' THEN 'DM+D' 
                                      ELSE cVocabularyName 
                                  END;

    IF pVocabularyName='DPD' THEN
        --DPD only uses HTTP/2
        SELECT http_content INTO cVocabHTML FROM vocabulary_download.py_http2_get(url => cURL);
    ELSE
        SELECT http_content INTO cVocabHTML FROM vocabulary_download.py_http_get(url => cURL, allow_redirects => TRUE);
    END IF;
    
    CASE
        WHEN cVocabularyName = 'RXNORM'
        THEN
            cSearchString := 'https://download.nlm.nih.gov/umls/kss/rxnorm/RxNorm_full_';
            cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
            cPos2 := devv5.INSTR (cVocabHTML, '.zip', cPos1);
            PERFORM vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
            cVocabDate := TO_DATE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), 'mmddyyyy');
            cVocabVer := 'RxNorm '||TO_CHAR(cVocabDate,'YYYYMMDD');
        WHEN cVocabularyName = 'UMLS'
        THEN
            cVocabDate := TO_DATE(SUBSTRING(cVocabHTML,'Full UMLS Release Files.+?(?:<td>.+?</td>\s+){4}<td>(.+?)</td>'),'monthdd,yyyy');
            cVocabVer := SUBSTRING(cVocabHTML,'([\d]{4}[A-z]{2}) Full UMLS Release Files');
        WHEN cVocabularyName = 'SNOMED'
        THEN
            cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'<div class="releases available".+?<div id="release-uk_sct2cl_[\d.]+_(\d{8})\d+.*\.zip".+?\.zip">.+'),'yyyymmdd');
            cVocabVer := 'Snomed Release '||TO_CHAR(cVocabDate,'YYYYMMDD');
        WHEN cVocabularyName = 'SNOMED_INT'
        THEN
            cVocabDate := to_date(SUBSTRING(cVocabHTML FROM 'Release Date: ([A-Za-z]+ \d{1,2}, \d{4})'), 'Month DD, YYYY');
            cVocabVer := 'Snomed International '||TO_CHAR(cVocabDate,'YYYYMMDD');
        WHEN cVocabularyName = 'SNOMED_US'
        THEN
            cVocabDate := TO_DATE(SUBSTRING(cVocabHTML FROM '<p><strong>Release Date:</strong> ([A-Za-z]+ \d{1,2}, \d{4})'), 'Month DD, YYYY');
            cVocabVer := 'Snomed US '||TO_CHAR(cVocabDate,'YYYYMMDD');
        WHEN cVocabularyName = 'SNOMED_UK_DE'
        THEN
            cVocabDate := TO_DATE(SUBSTRING(cVocabHTML FROM '(\d+\s+[A-Za-z]+\s+\d+)\s+major release.'), 'DD Month YYYY');
            cVocabVer := 'Snomed UK_DE '||TO_CHAR(cVocabDate,'YYYYMMDD');
        WHEN cVocabularyName = 'SNOMED_UK'
        THEN
            cVocabDate := TO_DATE(SUBSTRING(cVocabHTML FROM '(\d+\s+[A-Za-z]+\s+\d+)\s+major release.'), 'DD Month YYYY');
            cVocabVer := 'Snomed UK '||TO_CHAR(cVocabDate,'YYYYMMDD');
        WHEN cVocabularyName = 'HCPCS'
        THEN
            --cVocabDate := TO_DATE(SUBSTRING(LOWER(cVocabHTML),'<span class=.*?hcpcs quarterly update</span>.*?<li>.*?<a data-entity-substitution.*?href=.+?\.zip" title="(.+?) alpha-numeric hcpcs files*">'),'month yyyy');
            --cVocabDate := TO_DATE(SUBSTRING(LOWER(cVocabHTML),'<span class=.*?hcpcs quarterly update</span>.*?<li>.*?<a href="/media/\d+".*?>(.+?) alpha-numeric hcpcs files'),'month yyyy');
            cVocabDate := TO_DATE(SUBSTRING(LOWER(cVocabHTML),'<span class=.*?hcpcs quarterly update</span>.*?<li>.*?<a href="/files/zip/.+?\.zip" .*?title="(.+?) alpha-numeric hcpcs file'),'month yyyy');
            cVocabVer := TO_CHAR(cVocabDate,'YYYYMMDD')||' Alpha Numeric HCPCS File';
        WHEN cVocabularyName IN ('ICD9CM', 'ICD9PROC')
        THEN
            cSearchString := '<a type="application/zip" href="/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads';
            cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
            cPos2 := devv5.INSTR (cVocabHTML, '[ZIP,', cPos1);
            PERFORM vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
            cVocabHTML := REGEXP_REPLACE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), '[[:space:]]+$', '');
            cSearchString := 'Effective';
            cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
            cPos2 := LENGTH (cVocabHTML) + 1;
            PERFORM vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
            cVocabDate := TO_DATE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), 'monthdd,yyyy');
        WHEN cVocabularyName = 'ICD10CM'
        THEN
            cVocabDate := TO_DATE (SUBSTRING (cVocabHTML, '.+<A HREF="/pub/Health_Statistics/NCHS/Publications/ICD10CM/\d{4}/">(\d{4})</A>') || '1001', 'yyyymmdd') - interval '1 year';
            cVocabVer := 'ICD10CM FY'||TO_CHAR(cVocabDate + interval '1 year','YYYY')||' code descriptions';
        WHEN cVocabularyName = 'ICD10PCS'
        THEN
            cVocabDate := TO_DATE(SUBSTRING(LOWER(cVocabHTML),'<a href="/files/zip/([[:digit:]]{4})-icd-10-pcs-codes-file.zip"') || '1001', 'yyyymmdd') - interval '1 year';
            cVocabVer := 'ICD10PCS '||TO_CHAR(cVocabDate + interval '1 year','YYYY');
        WHEN cVocabularyName = 'LOINC'
        THEN
            SELECT TO_DATE(s0.arr[2],'yyyy-mm-dd'), 'LOINC '||s0.arr[1] INTO cVocabDate, cVocabVer FROM (
              SELECT regexp_matches(cVocabHTML,'<h3>LOINC Version ([\d.]+)</h3>.*?Released ([\d-]+)</p>') arr
            ) AS s0;
        WHEN cVocabularyName = 'MEDDRA'
        THEN
            SELECT TO_DATE (SUBSTRING (TRIM (title), '[[:alpha:]]+ [[:digit:]]+$'), 'month yyyy'),
                   SUBSTRING (TRIM (title), 'MedDRA Version [[:digit:].]+')
              INTO cVocabDate, cVocabVer
              FROM (SELECT UNNEST(xpath ('/rss/channel/item/title/text()', cVocabHTML::xml))::varchar title,
                           UNNEST(xpath ('/rss/channel/item/link/text()', cVocabHTML::xml))::varchar link_str,
                           UNNEST(xpath ('/rss/channel/item/pubDate/text()', cVocabHTML::xml))::varchar pubDate
                   ) AS t
             WHERE t.link_str LIKE '%www.meddra.org/how-to-use/support-documentation/english'
               AND t.title LIKE '%MedDRA Version%'
             ORDER BY TO_DATE (pubDate, 'dy dd mon yyyy hh24:mi:ss') DESC
             LIMIT 1;
        WHEN cVocabularyName = 'NDC_SPL'
        THEN
            cVocabDate := CURRENT_DATE;
            cVocabVer:='NDC '||TO_CHAR(cVocabDate,'YYYYMMDD');
        --WHEN cVocabularyName IN ('OPCS4', 'READ') --disable READ
        WHEN cVocabularyName = 'OPCS4'
        THEN
            cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'<div class="releases available".+?<div id="release-nhs_dmwb_[\d.]+_(\d{8}).*\.zip".+'),'yyyymmdd');
            cVocabVer := 'DATAMIGRATION '||SUBSTRING (cVocabHTML,'<div class="releases available".+?<div id="release-nhs_dmwb_([\d.]+_\d{8}.*)\.zip".+');
        WHEN cVocabularyName = 'ISBT'
        THEN
          SELECT SUBSTRING(t.title,' ([\d.]+) ') INTO cVocabVer FROM (
            SELECT 
                UNNEST(xpath ('/rss/channel/item/title/text()', cVocabHTML::xml))::varchar title
          ) AS t
          WHERE t.title LIKE '%Version % of the ISBT 128 Product Description Code Database%';
        WHEN cVocabularyName = 'DPD'
        THEN
            cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'.+<th rowspan="4".*?>ALL FILES</th>.+?<td.+?>([\d-]{10})</td>.*'),'yyyy-mm-dd');
            cVocabVer := 'DPD '||TO_CHAR(cVocabDate,'YYYYMMDD');
        WHEN cVocabularyName = 'CVX'
        THEN
            SELECT max(TO_DATE(parsed.last_updated,'mm/dd/yyyy')) INTO cVocabDate FROM (
              SELECT UNNEST(regexp_matches(cVocabHTML,'<div class=''table-responsive''>(<table class.+?</table>)<div/>','g'))::xml xmlfield) cvx_table
              CROSS JOIN xmltable ('/table/tr' passing cvx_table.xmlfield
                columns last_updated text path 'td[5]'
              ) parsed;
            cVocabVer := 'CVX '||TO_CHAR(cVocabDate,'YYYYMMDD');
        WHEN cVocabularyName = 'BDPM'
        THEN
            SELECT max(TO_DATE(arr[2],'dd/mm/yyyy')) AS bdpm_dt INTO cVocabDate FROM (
              SELECT regexp_matches(cVocabHTML,'"\?fichier=(.+?)".+?jour : ([\d/]+),.+?</a>','g') arr
            ) AS s0
             WHERE arr[1] IN ('CIS_bdpm.txt','CIS_CIP_bdpm.txt','CIS_COMPO_bdpm.txt','CIS_GENER_bdpm.txt');
            cVocabVer := 'BDPM '||TO_CHAR(cVocabDate,'YYYYMMDD');
        WHEN cVocabularyName = 'GGR'
        THEN
            cVocabDate := TO_DATE (SUBSTRING (LOWER(cVocabHTML),'.+?<a target="_blank" download="" href="/nl/downloads/file\?type=emd&amp;name=/csv4emd_nl_([\d]{4}).+\.zip">csv nl</a>.+'),'yymm');
            cVocabVer := 'GGR '||TO_CHAR(cVocabDate,'YYYYMMDD');
        WHEN cVocabularyName IN ('MESH','CDT','CPT4')
        THEN
            SELECT vocabulary_date, vocabulary_version INTO cVocabDate, cVocabVer FROM sources.mrsmap LIMIT 1;
        WHEN cVocabularyName = 'AMT'
        THEN
            SELECT s0.amt_date INTO cVocabDate FROM (
              SELECT UNNEST(xpath ('//xmlns:category/@term', cVocabHTML::xml,
                  ARRAY[ARRAY['xmlns', 'http://www.w3.org/2005/Atom'],
                  ARRAY['ncts', 'http://ns.electronichealth.net.au/ncts/syndication/asf/extensions/1.0.0']
              	]))::varchar category,
              	TO_DATE(SUBSTRING(UNNEST(xpath ('//ncts:contentItemVersion/text()', cVocabHTML::xml,
                  ARRAY[ARRAY['xmlns', 'http://www.w3.org/2005/Atom'],
                  ARRAY['ncts', 'http://ns.electronichealth.net.au/ncts/syndication/asf/extensions/1.0.0']
              	]))::varchar,'.+/([\d]{8})$'),'yyyymmdd') amt_date
              ) s0
              WHERE s0.category='SCT_RF2_FULL' ORDER BY s0.amt_date DESC LIMIT 1;
            cVocabVer := 'Clinical Terminology v'||TO_CHAR(cVocabDate,'YYYYMMDD');
        WHEN cVocabularyName = 'CDM'
        THEN
            SELECT s1.vocabulary_version, s1.release_date::date,
            l.vocabulary_version, l.vocabulary_date
            INTO cVocabVer, cVocabDate, cVocabSrcVer, cVocabSrcDate
            FROM (
              SELECT s0.vocabulary_version, s0.release_date FROM (
                WITH t AS (SELECT json_array_elements(cVocabHTML::json) AS json_content)
                SELECT TRIM(regexp_replace(replace(replace(regexp_replace(t.json_content->>'name','^CDM v5\.0$','CDM v5.0.0'),' (historical)',''),'CDM v5.2 Bug Fix 1','CDM v5.2.0'),'^CDM v5.4$','CDM v5.4.0')) AS vocabulary_version, 
                (t.json_content->>'published_at')::timestamp AS release_date
                FROM t
                WHERE (t.json_content ->> 'prerelease')::boolean = FALSE
                AND (t.json_content ->> 'node_id')<>'MDc6UmVsZWFzZTcxOTY0MDE=' --exclude 5.2.0 (before CDM v5.2 Bug Fix 1) due to DDL bugs
                AND NOT EXISTS (SELECT 1 FROM sources.cdm_tables ct WHERE ct.ddl_release_id=(t.json_content->>'node_id'))
              ) s0 ORDER BY release_date LIMIT 1 --first unparsed release
            ) s1
            LEFT JOIN LATERAL
            (
              --determine the affected version, because after 5.0.1 comes 4.0.0 for historical reasons, or after 5.3.1 comes 5.2.2 for support reason
              SELECT ct.vocabulary_version, ct.vocabulary_date 
                FROM sources.cdm_tables ct 
               WHERE ct.ddl_date < s1.release_date 
                 AND UPPER(ct.vocabulary_version) < UPPER(s1.vocabulary_version)
               ORDER BY UPPER(ct.vocabulary_version) DESC, ct.ddl_date DESC LIMIT 1
            ) l ON TRUE;
            cVocabSrcVer := COALESCE(cVocabSrcVer,cVocabVer);
            cVocabSrcDate := COALESCE(cVocabSrcDate,cVocabDate);
            cVocabOldDate := COALESCE(cVocabOldDate,cVocabSrcDate-1);
            cVocabOldVer := COALESCE(cVocabOldVer,cVocabSrcVer);
            cVocabDate := COALESCE(cVocabDate,cVocabOldDate);
        WHEN cVocabularyName = 'SNOMED VETERINARY'
        THEN
            cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'.+?<a href="SnomedCT_Release_VTS.+?_([\d]{8})(:?_updated)*\.zip" target="main">Download the Veterinary Extension of SNOMED CT</a>.+'),'yyyymmdd');
            cVocabVer := 'SNOMED Veterinary '||TO_CHAR(cVocabDate,'YYYYMMDD');
        WHEN cVocabularyName = 'ICD10GM'
        THEN
            cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'.+?<a href="SharedDocs/Downloads/DE/Kodiersysteme/klassifikationen/icd-10-gm/version(\d{4})/icd10gm\d{4}syst-meta.*?_zip.+?>'),'yyyy');
            cVocabVer := cVocabularyName||' '||TO_CHAR(cVocabDate,'YYYY');
        WHEN cVocabularyName = 'CCAM'
        THEN
          cVocabVer := SUBSTRING (LOWER(cVocabHTML),'.+?<h3>version actuelle</h3><div class="telechargement_bas"><h4>ccam version ([\d.]+)</h4>.+');
        WHEN cVocabularyName = 'HEMONC'
        THEN
          cVocabDate := TO_DATE (SUBSTRING (LOWER(cVocabHTML),'.+?>hemonc ontology</span>.+?<span class="text-muted">(.+?)</span>.+'),'Mon dd, yyyy');
          cVocabVer := 'HemOnc '||TO_CHAR(cVocabDate,'yyyy-mm-dd');
        WHEN cVocabularyName = 'DMD'
        THEN
            cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'<div class="releases available".+?<div id="release-nhsbsa_dmd_\d\.\d\.\d_(\d{8})\d+.zip".+?\.zip">.+'),'yyyymmdd');
            cVocabVer := 'dm+d Version '||SUBSTRING (cVocabHTML,'<div class="releases available".+?<div id="release-nhsbsa_dmd_\d\.\d\.\d_\d+.zip".+?\.zip">.+?<div class="current">.+?<h1 class="title">.+?Release (\d\.\d\.\d).+?</h1>.+')||' '||TO_CHAR(cVocabDate,'yyyymmdd');
        WHEN cVocabularyName = 'ONCOTREE'
        THEN
            SELECT x.release_date INTO cVocabDate
            FROM json_to_recordset(cVocabHTML::json) AS x (api_identifier text, release_date date)
            WHERE x.api_identifier='oncotree_latest_stable';
            cVocabVer := 'OncoTree version '||TO_CHAR(cVocabDate,'yyyy-mm-dd');
        WHEN cVocabularyName = 'CIM10'
        THEN
            SELECT TO_DATE (SUBSTRING (title, 'CIM-10 FR (\d{4}) à usage PMSI'), 'yyyy'),
            cVocabularyName||' '||SUBSTRING (title, 'CIM-10 FR (\d{4}) à usage PMSI')
            INTO cVocabDate, cVocabVer
            FROM (
             SELECT 
                UNNEST(xpath ('/rss/channel/item/title/text()', cVocabHTML::xml))::varchar title,
                UNNEST(xpath ('/rss/channel/item/pubDate/text()', cVocabHTML::xml)) ::varchar pubDate
            ) AS t
            WHERE t.title LIKE '%CIM-10 FR % à usage PMSI%'
            ORDER BY TO_DATE (pubDate, 'dy dd mon yyyy hh24:mi:ss') DESC LIMIT 1;
        WHEN cVocabularyName = 'OMOP INVEST DRUG'
        THEN
            SELECT TO_DATE(SUBSTRING(i.types->>'text',$$<a href = '.+?-([\d-]+)\..+'><b>Download</b></a>$$), 'yyyy-mm-dd')
              INTO cVocabDate FROM (SELECT JSON_ARRAY_ELEMENTS(cVocabHTML::json) AS types) i
             WHERE i.types->>'type'='news'
               AND i.types->>'title'='Newest GSRS Public Data Released'
             ORDER BY 1 DESC LIMIT 1;
            cVocabVer := 'OMOP Invest Drug version '||TO_CHAR(cVocabDate,'yyyy-mm-dd');
        WHEN cVocabularyName = 'CIVIC'
        THEN
            --CIViC use POST-requests
            SELECT http_content INTO cVocabHTML FROM vocabulary_download.py_http_post(url => cURL,
              content_type=>'application/json',
              params=>'{"operationName":"DataReleases","variables":{},"query":"query DataReleases {\n  dataReleases {\n    ...Release\n    __typename\n  }\n}\n\nfragment Release on DataRelease {\n  name\n  geneTsv {\n    filename\n    path\n    __typename\n  }\n  variantTsv {\n    filename\n    path\n    __typename\n  }\n  variantGroupTsv {\n    filename\n    path\n    __typename\n  }\n  evidenceTsv {\n    filename\n    path\n    __typename\n  }\n  assertionTsv {\n    filename\n    path\n    __typename\n  }\n  acceptedVariantsVcf {\n    filename\n    path\n    __typename\n  }\n  acceptedAndSubmittedVariantsVcf {\n    filename\n    path\n    __typename\n  }\n  __typename\n}"}'
            );
            
            SELECT TO_DATE(main_array#>>'{name}','dd-mon-yyyy') 
              INTO cVocabDate 
              FROM (SELECT json_array_elements(cVocabHTML::json#>'{data,dataReleases}') main_array) s0
             WHERE s0.main_array#>>'{name}'<>'nightly'
             ORDER BY 1 DESC LIMIT 1;
            cVocabVer := 'CIViC '||TO_CHAR(cVocabDate,'yyyy-mm-dd');
        WHEN cVocabularyName = 'META'
        THEN
            cVocabDate := TO_DATE(SUBSTRING(cVocabHTML,'This distribution contains the NCI Metathesaurus version <strong>(\d+)</strong>'),'yyyymm');
            cVocabVer := 'META '||TO_CHAR(cVocabDate,'yyyy-mm-dd');
        WHEN cVocabularyName = 'ATC'
        THEN
            -- _atc_ver stores a string containing three concatenated dates in the format YYMMDD`
            SELECT _atc_ver
              INTO cVocabVer
              FROM sources.atc_codes LIMIT 1;
            
            -- To determine the new version of the source to download, it needs to compare the dates from the three URLs
            -- If the new date string is different from the existing one, this means that the data source contains a new version
            IF (SELECT cVocabVer != (
                (SELECT TO_CHAR(TO_DATE((regexp_match(http_content, 'Last updated:\s*(\d{4}-\d{2}-\d{2})'))[1], 'YYYY-MM-DD'), 'YYMMDD')
                   FROM vocabulary_download.py_http_get(url => SPLIT_PART(cURL, ',', 1), allow_redirects => TRUE)) ||
                (SELECT TO_CHAR(TO_DATE((regexp_match(http_content, 'Last updated:\s*(\d{4}-\d{2}-\d{2})'))[1], 'YYYY-MM-DD'), 'YYMMDD')
                   FROM vocabulary_download.py_http_get(url => SPLIT_PART(cURL, ',', 2), allow_redirects => TRUE)) ||
                (SELECT TO_CHAR(TO_DATE((regexp_match(http_content, 'Last updated:\s*(\d{4}-\d{2}-\d{2})'))[1], 'YYYY-MM-DD'), 'YYMMDD')
                   FROM vocabulary_download.py_http_get(url => SPLIT_PART(cURL, ',', 3), allow_redirects => TRUE)))
            )
            THEN
                cVocabDate := CURRENT_DATE;
                cVocabVer := 'ATC '||TO_CHAR(cVocabDate,'yyyy-mm-dd');
            ELSE
                cVocabDate := cVocabSrcDate;
                cVocabVer := cVocabSrcVer;
            END IF;
        WHEN cVocabularyName = 'EORTC'
        THEN
            cVocabDate := CURRENT_DATE;
            cVocabVer := 'EORTC '||TO_CHAR(cVocabDate,'yyyy-mm-dd');
            cVocabOldDate := COALESCE(cVocabOldDate,cVocabSrcDate);
            cVocabOldVer := COALESCE(cVocabOldVer,cVocabSrcVer);
        ELSE
            RAISE EXCEPTION '% are not supported at this time!', pVocabularyName;
    END CASE;

    IF (cVocabDate IS NULL AND cVocabularyName NOT IN ('ISBT','CCAM')) OR (cVocabVer IS NULL AND cVocabularyName IN ('ISBT','CCAM'))
    THEN
        RAISE EXCEPTION 'NULL detected for %', pVocabularyName;
    END IF;

    IF cVocabularyName IN ('ISBT','CCAM')
    THEN
        IF cVocabVer <> cVocabOldVer
        THEN
            old_version := cVocabOldVer;
            new_version := cVocabVer;
            src_version := cVocabSrcVer;
            --sources_updated := case when cVocabVer=cVocabSrcVer then 1 else 0 end;
        END IF;
    ELSE
        IF cVocabDate > COALESCE(cVocabOldDate, TO_DATE ('19700101', 'yyyymmdd'))
        THEN
            old_date := cVocabOldDate;
            new_date := cVocabDate;
            old_version := cVocabOldVer;
            new_version := cVocabVer;
            src_date := cVocabSrcDate;
            src_version := cVocabSrcVer;
            --sources_updated := case when cVocabDate=cVocabSrcDate then 1 else 0 end;
        END IF;
    END IF;
    
    RETURN;
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY DEFINER
COST 100;