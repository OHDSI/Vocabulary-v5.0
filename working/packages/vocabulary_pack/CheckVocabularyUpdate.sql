CREATE OR REPLACE FUNCTION vocabulary_pack.CheckVocabularyUpdate (
  pVocabularyName varchar,
  out old_date date,
  out new_date date,
  out old_version varchar,
  out new_version varchar,
  out src_date date,
  out src_version varchar
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
      vocabulary_udpate_after VARCHAR (20),
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
        cVocabularyName:=UPPER(pVocabularyName);
        
        set local search_path to devv5;
        
        IF pVocabularyName IS NULL
        THEN
            RAISE EXCEPTION '% cannot be empty!', pVocabularyName;
        END IF;

        SELECT vocabulary_url, vocabulary_source_table
          INTO cURL, cVocabSrcTable
          FROM vocabulary_access
         WHERE UPPER(vocabulary_id) = cVocabularyName AND vocabulary_order = 1;

        IF cURL IS NULL
        THEN
            RAISE EXCEPTION '% not found in vocabulary_access table!', pVocabularyName;
        END IF;
        
        --Get date and version from main sources tables. This is necessary to determine partial update of the vocabulary (only in sources)
        if cVocabSrcTable is not null then
          execute 'select vocabulary_date, vocabulary_version from '||cVocabSrcTable||' limit 1' into cVocabSrcDate, cVocabSrcVer;
        end if;

        /*
          set proper update date
        */
        /*IF pVocabularyName = 'ISBT'
        THEN
            SELECT vocabulary_version
              INTO cVocabOldVer
              FROM devv5.vocabulary
             WHERE vocabulary_id=pVocabularyName;
        ELSIF pVocabularyName <> 'UMLS'
        THEN
            SELECT COALESCE (LATEST_UPDATE, TO_DATE ('19700101', 'yyyymmdd'))
              INTO cVocabOldDate
              FROM devv5.vocabulary_conversion
             WHERE vocabulary_id_v5 = pVocabularyName;
        ELSE
             SELECT vocabulary_date into cVocabOldDate FROM sources.mrsmap LIMIT 1;
        END IF;*/

        SELECT COALESCE (latest_update, to_date ('19700101', 'yyyymmdd')), vocabulary_version 
        into cVocabOldDate, cVocabOldVer from (
          select vc.latest_update, 
          substring(replace(v.vocabulary_version,v.vocabulary_id,''),'[\d.-]+[A-z]*[\d./-]*') as vocabulary_version, 
          vc.vocabulary_id_v5 as vocabulary_id
          from devv5.vocabulary_conversion vc
          join devv5.vocabulary v on v.vocabulary_id=vc.vocabulary_id_v5
          union all
          (select vocabulary_date, vocabulary_version, 'UMLS' FROM sources.mrsmap LIMIT 1)
        ) as s
        WHERE UPPER(vocabulary_id)=case cVocabularyName when 'NDC_SPL' then 'NDC' else cVocabularyName end;

        /*
          INSERT INTO vocabulary_access
               VALUES ('UMLS', --in UPPER case!
                       NULL,
                       'https://www.nlm.nih.gov/research/umls/licensedcontent/umlsknowledgesources.html',
                       NULL,
                       NULL,
                       1);
          start checking
          supported:
          1. RxNorm
          2. UMLS
          3. SNOMED
          4. HCPCS
          5. ICD9CM
          6. ICD9Proc
          7. ICD10CM
          8. ICD10PCS
          9. LOINC
          10. MedDRA
          11. NDC
          12. OPCS4
          13. Read
          14. ISBT
          15. DPD
          16. CVX
          17. BDPM
          18. GGR
          19. MeSH
          20. CDT
          21. CPT4
        */
        perform http_set_curlopt('CURLOPT_TIMEOUT', '30');
        set local http.timeout_msec TO 30000;
        SELECT content into cVocabHTML FROM http_get(cURL);
        

        CASE
            WHEN cVocabularyName = 'RXNORM'
            THEN
                cSearchString := 'https://download.nlm.nih.gov/umls/kss/rxnorm/RxNorm_full_';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cPos2 := devv5.INSTR (cVocabHTML, '.zip', cPos1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabDate := TO_DATE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), 'mmddyyyy');
            WHEN cVocabularyName = 'UMLS'
            THEN
                cSearchString := '<table class="umls_download">';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cPos1 := devv5.INSTR (cVocabHTML, '<td>', cPos1 + 1);
                cPos1 := devv5.INSTR (cVocabHTML, '<td>', cPos1 + 1);
                cPos1 := devv5.INSTR (cVocabHTML, '<td>', cPos1 + 1);
                cPos2 := devv5.INSTR (cVocabHTML, '</td>', cPos1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabDate := TO_DATE (SUBSTR (cVocabHTML, cPos1 + 4, cPos2 - cPos1 - 4), 'monthdd,yyyy');
                --the version exctraction
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cSearchString='Full Release';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString, cPos1 + 1);
                cPos2 := devv5.INSTR (cVocabHTML, '</a>', cPos1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabVer := substring (SUBSTR (cVocabHTML, cPos1 + 4, cPos2 - cPos1 - 4), '[\d]{4}[A-z]{2}');
            WHEN cVocabularyName = 'SNOMED'
            THEN
                cSearchString := '<a class="btn btn-primary btn-md" href="';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cPos2 := devv5.INSTR (cVocabHTML, '.zip">Download RF2 Files Now!</a>', cPos1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabDate := TO_DATE (SUBSTRING (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), '[[:digit:]]+'), 'yyyymmdd');
                cVocabVer := 'Snomed Release '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'HCPCS'
            THEN
              select TO_DATE ( (MAX (t.title) - 1) || '0101', 'yyyymmdd') into cVocabDate  From (
                select 
                    unnest(xpath ('/rss/channel/item/title/text()', cVocabHTML::xml))::varchar::int title,
                    unnest(xpath ('/rss/channel/item/link/text()', cVocabHTML::xml)) ::varchar description 
              ) as t
              WHERE t.description LIKE '%Alpha-Numeric-HCPCS-File%' AND t.description NOT LIKE '%orrections%';
              cVocabVer := to_char(cVocabDate,'YYYYMMDD')||' Alpha Numeric HCPCS File';
            WHEN cVocabularyName IN ('ICD9CM', 'ICD9PROC')
            THEN
                cSearchString := '<a type="application/zip" href="/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cPos2 := devv5.INSTR (cVocabHTML, '[ZIP,', cPos1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabHTML := REGEXP_REPLACE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), '[[:space:]]+$', '');
                cSearchString := 'Effective';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cPos2 := LENGTH (cVocabHTML) + 1;
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabDate := TO_DATE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), 'monthdd,yyyy');  
            WHEN cVocabularyName = 'ICD10CM'
            THEN
                cSearchString := '<div id="contentArea" >';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cSearchString := '<strong>Note: <a href="';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString, cPos1);
                cSearchString := '">';
                cPos1 := INSTR (cVocabHTML, cSearchString, cPos1);
                cPos2 := devv5.INSTR (cVocabHTML, '</a>', cPos1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabDate := TO_DATE (SUBSTRING (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), ' [[:digit:]]{4} ')::int - 1 || '0101', 'yyyymmdd');
                cVocabVer := 'ICD10CM FY'||to_char(cVocabDate + interval '1 year','YYYY')||' code descriptions';
            WHEN cVocabularyName = 'ICD10PCS'
            THEN
                select s1.icd10pcs_year into cVocabDate from (
                  select TO_DATE (SUBSTRING(url,'/([[:digit:]]{4})')::int - 1 || '0101', 'yyyymmdd') icd10pcs_year from (
                    select unnest(xpath ('//global:loc/text()', cVocabHTML::xml, ARRAY[ARRAY['global', 'http://www.sitemaps.org/schemas/sitemap/0.9']]))::varchar url
                  ) s0
                  where s0.url ilike '%www.cms.gov/Medicare/Coding/ICD10/Downloads/%PCS%Order%.zip'
                ) as s1 order by s1.icd10pcs_year desc limit 1;
                /*old version
                cSearchString := 'ICD-10 PCS and GEMs';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cSearchString := '">';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString, cPos1);
                cPos2 := devv5.INSTR (cVocabHTML, '</a>', cPos1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabDate := TO_DATE (SUBSTRING (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), '^[[:digit:]]+')::int - 1 || '0101', 'yyyymmdd');
                */
                cVocabVer := 'ICD10PCS '||to_char(cVocabDate + interval '1 year','YYYY');
            WHEN cVocabularyName = 'LOINC'
            THEN
                cSearchString := 'LOINC Table File (CSV)';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cSearchString := 'Released';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString, cPos1);
                cPos2 := devv5.INSTR (cVocabHTML, ' ', cPos1 + LENGTH (cSearchString) + 1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabDate := TO_DATE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), 'yyyy-mm-dd');
                --the version extraction
                cSearchString := 'LOINC Table File (CSV)';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cSearchString := 'Version ';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString, cPos1);
                cPos2 := devv5.INSTR (cVocabHTML, ' ', cPos1 + LENGTH (cSearchString) + 1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabVer := SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString));
            WHEN cVocabularyName = 'MEDDRA'
            THEN
                SELECT TO_DATE (SUBSTRING (TRIM (title), '[[:alpha:]]+ [[:digit:]]+$'), 'month yyyy'),
                SUBSTRING (TRIM (title), 'MedDRA Version [[:digit:].]+')
                INTO cVocabDate, cVocabVer
                from (
                 SELECT 
                    unnest(xpath ('/rss/channel/item/title/text()', cVocabHTML::xml))::varchar title,
                    unnest(xpath ('/rss/channel/item/link/text()', cVocabHTML::xml)) ::varchar link_str,
                    unnest(xpath ('/rss/channel/item/pubDate/text()', cVocabHTML::xml)) ::varchar pubDate
                ) as t
                WHERE t.link_str LIKE '%www.meddra.org/how-to-use/support-documentation/english'
                ORDER BY TO_DATE (pubDate, 'dy dd mon yyyy hh24:mi:ss') DESC
                LIMIT 1;             
            WHEN cVocabularyName = 'NDC_SPL'
            THEN
                /*cSearchString := 'Current through: ';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cPos2 := devv5.INSTR (cVocabHTML, '</p>', cPos1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabDate := TO_DATE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), 'monthdd,yyyy');
                */ --commented because "updated daily"
                /*from the site:
                  <script type="text/javascript">
                  var currentdate = new Date(); 
                  var datetime = "<p><strong>The National Drug Code (NDC) Directory is updated daily. <br />Current through: " 
                  + (currentdate.getMonth()+1) + "/" 
                  + currentdate.getDate()   +  "/" 
                  + currentdate.getFullYear() + "</strong></p>";

                  document.write(datetime);

                  </script>
                */ --so using current_date
                
                cVocabDate:=current_date;
                cVocabVer:='NDC '||to_char(cVocabDate,'YYYYMMDD');
            --WHEN cVocabularyName IN ('OPCS4', 'READ') --disable READ
            WHEN cVocabularyName = 'OPCS4'
            THEN
                cSearchString := 'class="release available';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                /*
                gets 21.0.0_YYYYMMDD000001
                cPos2 := devv5.INSTR (cVocabHTML, '</h2>', cPos1);
                cVocabDate:=to_date(regexp_substr(TRIM (REGEXP_REPLACE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), '[[:space:]]+', ' ')),'[[:digit:]]{8}'),'yyyymmdd');
                new: Friday, 18 March 2016
                */
                cSearchString := 'Released on';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString, cPos1);
                cPos2 := devv5.INSTR (cVocabHTML, '</p>', cPos1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabDate := TO_DATE (TRIM (REGEXP_REPLACE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), '[[:space:]]+', ' ')), 'day, dd month yyyy');
                --the version extraction
                cSearchString := 'Releases of this item';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cSearchString := 'data-entity-id="';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString, cPos1);
                cPos2 := devv5.INSTR (cVocabHTML, '">', cPos1 + LENGTH (cSearchString) + 1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabVer := SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString));
            WHEN cVocabularyName = 'ISBT'
            THEN
              SELECT SUBSTRING(t.title,' ([\d.]+) ') INTO cVocabVer FROM (
                SELECT 
                    unnest(xpath ('/rss/channel/item/title/text()', cVocabHTML::xml))::varchar title
              ) as t
              WHERE t.title LIKE '%Version % of the ISBT 128 Product Description Code Database%';
            WHEN cVocabularyName = 'DPD'
            THEN
                cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'.+<th rowspan="4" id="t253" headers="t5">ALL FILES</th>.+?<td headers="t7 t253">([-\d]{10})</td>'),'yyyy-mm-dd');
                cVocabVer := 'DPD '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'CVX'
            THEN
                select s0.cvx_date into cVocabDate from (
                  select unnest(xpath ('/rdf:RDF/global:item/dc:date/text()', cVocabHTML::xml, 
                  ARRAY[
                    ARRAY['rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'],
                    ARRAY['global', 'http://purl.org/rss/1.0/'],
                    ARRAY['dc', 'http://purl.org/dc/elements/1.1/']
                  ]))::VARCHAR::date cvx_date
                ) as s0 order by s0.cvx_date desc limit 1;
                cVocabVer := 'CVX Code Set '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'BDPM'
            THEN
                select max(to_date(arr[2],'dd/mm/yyyy')) as bdpm_dt into cVocabDate from (
                  select regexp_matches(cVocabHTML,'"\?fichier=(.+?)".+?jour : ([\d/]+),.+?</a>','g') arr
                ) as s0
                where arr[1] in ('CIS_bdpm.txt','CIS_CIP_bdpm.txt','CIS_COMPO_bdpm.txt','CIS_GENER_bdpm.txt');
                cVocabVer := 'BDPM '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'GGR'
            THEN
                cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'.+?<a download="" href="/nl/downloads/file\?type=EMD&amp;name=/csv4Emd_Nl_([\d]{4}).+\.zip" target="_blank">CSV NL</a>.+'),'yymm');
                cVocabVer := 'GGR '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName in ('MESH','CDT','CPT4')
            THEN
                select vocabulary_date, vocabulary_version into cVocabDate, cVocabVer FROM sources.mrsmap LIMIT 1;
            ELSE
                RAISE EXCEPTION '% are not supported at this time!', pVocabularyName;
        END CASE;

        IF (cVocabDate IS NULL AND cVocabularyName <> 'ISBT') OR (cVocabVer IS NULL AND cVocabularyName = 'ISBT')
        THEN
            RAISE EXCEPTION 'NULL detected for %', pVocabularyName;
        END IF;

        IF cVocabularyName = 'ISBT'
        THEN
          IF cVocabVer <> cVocabOldVer
          THEN
              old_version:=cVocabOldVer;
              new_version:=cVocabVer;
              src_version:=cVocabSrcVer;
              --sources_updated:=case when cVocabVer=cVocabSrcVer then 1 else 0 end;
          END IF;
        ELSE
          IF cVocabDate > cVocabOldDate
          THEN
              old_date:=cVocabOldDate;
              new_date:=cVocabDate;
              old_version:=cVocabOldVer;
              new_version:=cVocabVer;
              src_date:=cVocabSrcDate;
              src_version:=cVocabSrcVer;
              --sources_updated:=case when cVocabDate=cVocabSrcDate then 1 else 0 end;
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