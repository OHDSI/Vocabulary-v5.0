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
          --added 'order by' clause due to CDM
          execute 'select vocabulary_date, vocabulary_version from '||cVocabSrcTable||' order by vocabulary_date desc limit 1' into cVocabSrcDate, cVocabSrcVer;
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
          union all
          (select vocabulary_date, vocabulary_version, 'META' FROM sources.meta_mrsab LIMIT 1)
        ) as s
        WHERE UPPER(vocabulary_id)=case cVocabularyName when 'NDC_SPL' then 'NDC' when 'DMD' then 'DM+D' else cVocabularyName end;

        /*
          INSERT INTO vocabulary_access
               VALUES ('UMLS', --in UPPER case!
                       NULL,
                       'https://www.nlm.nih.gov/research/umls/licensedcontent/umlsknowledgesources.html',
                       NULL,
                       NULL,
                       1,
                       'sources.mrsmap',
                       NULL,
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
          22. AMT
          23. CDM
          24. SNOMED Veterinary
          25. ICD10GM
          26. CCAM
          27. HemOnc
          28. dm+d
          29. OncoTree
          30. CIM10
          31. OMOP Invest Drug
          32. CiViC
          33. META
        */
        IF pVocabularyName='DPD' THEN
            --DPD only uses HTTP/2
            SELECT http_content into cVocabHTML FROM vocabulary_download.py_http2_get(url=>cURL);
        ELSE
            SELECT http_content into cVocabHTML FROM vocabulary_download.py_http_get(url=>cURL,allow_redirects=>true);
        END IF;
        
        CASE
            WHEN cVocabularyName = 'RXNORM'
            THEN
                cSearchString := 'https://download.nlm.nih.gov/umls/kss/rxnorm/RxNorm_full_';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cPos2 := devv5.INSTR (cVocabHTML, '.zip', cPos1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabDate := TO_DATE (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), 'mmddyyyy');
                cVocabVer := 'RxNorm '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'UMLS'
            THEN
                cVocabDate := TO_DATE(SUBSTRING(cVocabHTML,'Full UMLS Release Files.+?(?:<td>.+?</td>\s+){4}<td>(.+?)</td>'),'monthdd,yyyy');
                cVocabVer := SUBSTRING(cVocabHTML,'([\d]{4}[A-z]{2}) Full UMLS Release Files');
            WHEN cVocabularyName = 'SNOMED'
            THEN
                cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'<div class="releases available".+?<div id="release-uk_sct2cl_[\d.]+_(\d{8})\d+.*\.zip".+?\.zip">.+'),'yyyymmdd');
                cVocabVer := 'Snomed Release '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'HCPCS'
            THEN
              --cVocabDate := TO_DATE(SUBSTRING(LOWER(cVocabHTML),'<span class=.*?hcpcs quarterly update</span>.*?<li>.*?<a data-entity-substitution.*?href=.+?\.zip" title="(.+?) alpha-numeric hcpcs files*">'),'month yyyy');
              --cVocabDate := TO_DATE(SUBSTRING(LOWER(cVocabHTML),'<span class=.*?hcpcs quarterly update</span>.*?<li>.*?<a href="/media/\d+".*?>(.+?) alpha-numeric hcpcs files'),'month yyyy');
              cVocabDate := TO_DATE(SUBSTRING(LOWER(cVocabHTML),'<span class=.*?hcpcs quarterly update</span>.*?<li>.*?<a href="/files/zip/.+?\.zip" .*?title="(.+?) alpha-numeric hcpcs file'),'month yyyy');
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
                cVocabDate := TO_DATE (SUBSTRING (cVocabHTML, '.+<A HREF="/pub/Health_Statistics/NCHS/Publications/ICD10CM/\d{4}/">(\d{4})</A>') || '1001', 'yyyymmdd') - interval '1 year';
                cVocabVer := 'ICD10CM FY'||to_char(cVocabDate + interval '1 year','YYYY')||' code descriptions';
            WHEN cVocabularyName = 'ICD10PCS'
            THEN
                cVocabDate := TO_DATE(SUBSTRING(LOWER(cVocabHTML),'<a href="/medicare/coding-billing/icd-10-codes/([[:digit:]]{4})-icd-10-pcs".*?>[[:digit:]]{4} icd-10-pcs</a>') || '1001', 'yyyymmdd') - interval '1 year';
                cVocabVer := 'ICD10PCS '||to_char(cVocabDate + interval '1 year','YYYY');
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
                from (
                 SELECT 
                    unnest(xpath ('/rss/channel/item/title/text()', cVocabHTML::xml))::varchar title,
                    unnest(xpath ('/rss/channel/item/link/text()', cVocabHTML::xml)) ::varchar link_str,
                    unnest(xpath ('/rss/channel/item/pubDate/text()', cVocabHTML::xml)) ::varchar pubDate
                ) as t
                WHERE t.link_str LIKE '%www.meddra.org/how-to-use/support-documentation/english'
                AND t.title LIKE '%MedDRA Version%'
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
                cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'<div class="releases available".+?<div id="release-nhs_dmwb_[\d.]+_(\d{8}).*\.zip".+'),'yyyymmdd');
                cVocabVer := 'DATAMIGRATION '||SUBSTRING (cVocabHTML,'<div class="releases available".+?<div id="release-nhs_dmwb_([\d.]+_\d{8}.*)\.zip".+');
            WHEN cVocabularyName = 'ISBT'
            THEN
              SELECT SUBSTRING(t.title,' ([\d.]+) ') INTO cVocabVer FROM (
                SELECT 
                    unnest(xpath ('/rss/channel/item/title/text()', cVocabHTML::xml))::varchar title
              ) as t
              WHERE t.title LIKE '%Version % of the ISBT 128 Product Description Code Database%';
            WHEN cVocabularyName = 'DPD'
            THEN
                cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'.+<th rowspan="4".*?>ALL FILES</th>.+?<td.+?>([\d-]{10})</td>.*'),'yyyy-mm-dd');
                cVocabVer := 'DPD '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'CVX'
            THEN
                select max(TO_DATE(parsed.last_updated,'mm/dd/yyyy')) into cVocabDate from (
                  select unnest(regexp_matches(cVocabHTML,'<div class=''table-responsive''>(<table class.+?</table>)<div/>','g'))::xml xmlfield) cvx_table
                  cross join xmltable ('/table/tr' passing cvx_table.xmlfield
                    columns last_updated text path 'td[5]'
                  ) parsed;
                cVocabVer := 'CVX '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'BDPM'
            THEN
                select max(to_date(arr[2],'dd/mm/yyyy')) as bdpm_dt into cVocabDate from (
                  select regexp_matches(cVocabHTML,'"\?fichier=(.+?)".+?jour : ([\d/]+),.+?</a>','g') arr
                ) as s0
                where arr[1] in ('CIS_bdpm.txt','CIS_CIP_bdpm.txt','CIS_COMPO_bdpm.txt','CIS_GENER_bdpm.txt');
                cVocabVer := 'BDPM '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'GGR'
            THEN
                cVocabDate := TO_DATE (SUBSTRING (LOWER(cVocabHTML),'.+?<a target="_blank" download="" href="/nl/downloads/file\?type=emd&amp;name=/csv4emd_nl_([\d]{4}).+\.zip">csv nl</a>.+'),'yymm');
                cVocabVer := 'GGR '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName in ('MESH','CDT','CPT4')
            THEN
                select vocabulary_date, vocabulary_version into cVocabDate, cVocabVer FROM sources.mrsmap LIMIT 1;
            WHEN cVocabularyName = 'AMT'
            THEN
                select s0.amt_date into cVocabDate from (
                  select unnest(xpath ('//xmlns:category/@term', cVocabHTML::xml,
                      ARRAY[ARRAY['xmlns', 'http://www.w3.org/2005/Atom'],
                      ARRAY['ncts', 'http://ns.electronichealth.net.au/ncts/syndication/asf/extensions/1.0.0']
                  	]))::varchar category,
                  	to_date(substring(unnest(xpath ('//ncts:contentItemVersion/text()', cVocabHTML::xml,
                      ARRAY[ARRAY['xmlns', 'http://www.w3.org/2005/Atom'],
                      ARRAY['ncts', 'http://ns.electronichealth.net.au/ncts/syndication/asf/extensions/1.0.0']
                  	]))::varchar,'.+/([\d]{8})$'),'yyyymmdd') amt_date
                  ) s0
                  where s0.category='SCT_RF2_FULL' order by s0.amt_date desc limit 1;
                cVocabVer := 'Clinical Terminology v'||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'CDM'
            THEN
                select s1.vocabulary_version, s1.release_date::date,
                l.vocabulary_version, l.vocabulary_date
                into cVocabVer, cVocabDate, cVocabSrcVer, cVocabSrcDate
                from (
                  select s0.vocabulary_version, s0.release_date from (
                    with t as (select json_array_elements(cVocabHTML::json) as json_content)
                    select trim(regexp_replace(replace(replace(regexp_replace(t.json_content->>'name','^CDM v5\.0$','CDM v5.0.0'),' (historical)',''),'CDM v5.2 Bug Fix 1','CDM v5.2.0'),'^CDM v5.4$','CDM v5.4.0')) as vocabulary_version, 
                    (t.json_content->>'published_at')::timestamp as release_date
                    from t
                    where (t.json_content->>'prerelease')::boolean = false
                    and (t.json_content->>'node_id')<>'MDc6UmVsZWFzZTcxOTY0MDE=' --exclude 5.2.0 (before CDM v5.2 Bug Fix 1) due to DDL bugs
                    and not exists (select 1 from sources.cdm_tables ct where ct.ddl_release_id=(t.json_content->>'node_id'))
                  ) s0 order by release_date limit 1 --first unparsed release
                ) s1
                left join lateral
                (
                  --determine the affected version, because after 5.0.1 comes 4.0.0 for historical reasons, or after 5.3.1 comes 5.2.2 for support reason
                  select ct.vocabulary_version, ct.vocabulary_date from sources.cdm_tables ct 
                  where ct.ddl_date<s1.release_date and upper(ct.vocabulary_version)<upper(s1.vocabulary_version)
                  order by upper(ct.vocabulary_version) desc, ct.ddl_date desc limit 1
                ) l on true;
                cVocabSrcVer:=coalesce(cVocabSrcVer,cVocabVer);
                cVocabSrcDate:=coalesce(cVocabSrcDate,cVocabDate);
                cVocabOldDate:=coalesce(cVocabOldDate,cVocabSrcDate-1);
                cVocabOldVer:=coalesce(cVocabOldVer,cVocabSrcVer);
                cVocabDate:=COALESCE(cVocabDate,cVocabOldDate);
            WHEN cVocabularyName = 'SNOMED VETERINARY'
            THEN
                cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'.+?<a href="SnomedCT_Release_VTS.+?_([\d]{8})(:?_updated)*\.zip" target="main">Download the Veterinary Extension of SNOMED CT</a>.+'),'yyyymmdd');
                cVocabVer := 'SNOMED Veterinary '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'ICD10GM'
            THEN
                cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'.+?<a href="SharedDocs/Downloads/DE/Kodiersysteme/klassifikationen/icd-10-gm/version(\d{4})/icd10gm\d{4}syst-meta.*?_zip.+?>'),'yyyy');
                cVocabVer := cVocabularyName||' '||to_char(cVocabDate,'YYYY');
            WHEN cVocabularyName = 'CCAM'
            THEN
              cVocabVer := SUBSTRING (LOWER(cVocabHTML),'.+?<h3>version actuelle</h3><div class="telechargement_bas"><h4>ccam version ([\d.]+)</h4>.+');
            WHEN cVocabularyName = 'HEMONC'
            THEN
              cVocabDate := TO_DATE (SUBSTRING (LOWER(cVocabHTML),'.+?>hemonc knowledgebase</span>.+?<span class="text-muted">(.+?)</span>.+'),'Mon dd, yyyy');
              cVocabVer := 'HemOnc '||to_char(cVocabDate,'yyyy-mm-dd');
            WHEN cVocabularyName = 'DMD'
            THEN
                cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'<div class="releases available".+?<div id="release-nhsbsa_dmd_\d\.\d\.\d_(\d{8})\d+.zip".+?\.zip">.+'),'yyyymmdd');
                cVocabVer := 'dm+d Version '||SUBSTRING (cVocabHTML,'<div class="releases available".+?<div id="release-nhsbsa_dmd_\d\.\d\.\d_\d+.zip".+?\.zip">.+?<div class="current">.+?<h1 class="title">.+?Release (\d\.\d\.\d).+?</h1>.+')||' '||to_char(cVocabDate,'yyyymmdd');
            WHEN cVocabularyName = 'ONCOTREE'
            THEN
                select x.release_date into cVocabDate
                from json_to_recordset(cVocabHTML::json) as x (api_identifier text, release_date date)
                where x.api_identifier='oncotree_latest_stable';
                cVocabVer := 'OncoTree version '||to_char(cVocabDate,'yyyy-mm-dd');
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
                cVocabVer := 'OMOP Invest Drug version '||to_char(cVocabDate,'yyyy-mm-dd');
            WHEN cVocabularyName = 'CIVIC'
            THEN
                --CIViC use POST-requests
                SELECT http_content into cVocabHTML FROM vocabulary_download.py_http_post(url=>cURL,
                  content_type=>'application/json',
                  params=>'{"operationName":"DataReleases","variables":{},"query":"query DataReleases {\n  dataReleases {\n    ...Release\n    __typename\n  }\n}\n\nfragment Release on DataRelease {\n  name\n  geneTsv {\n    filename\n    path\n    __typename\n  }\n  variantTsv {\n    filename\n    path\n    __typename\n  }\n  variantGroupTsv {\n    filename\n    path\n    __typename\n  }\n  evidenceTsv {\n    filename\n    path\n    __typename\n  }\n  assertionTsv {\n    filename\n    path\n    __typename\n  }\n  acceptedVariantsVcf {\n    filename\n    path\n    __typename\n  }\n  acceptedAndSubmittedVariantsVcf {\n    filename\n    path\n    __typename\n  }\n  __typename\n}"}'
                );
                
                SELECT TO_DATE(main_array#>>'{name}','dd-mon-yyyy') INTO cVocabDate FROM
                (SELECT json_array_elements(cVocabHTML::json#>'{data,dataReleases}') main_array) s0
                WHERE s0.main_array#>>'{name}'<>'nightly'
                ORDER BY 1 DESC LIMIT 1;
                cVocabVer := 'CIViC '||to_char(cVocabDate,'yyyy-mm-dd');
            WHEN cVocabularyName = 'META'
            THEN
                cVocabDate := TO_DATE(SUBSTRING(cVocabHTML,'This distribution contains the NCI Metathesaurus version <strong>(\d+)</strong>'),'yyyymm');
                cVocabVer := 'META '||to_char(cVocabDate,'yyyy-mm-dd');
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
              old_version:=cVocabOldVer;
              new_version:=cVocabVer;
              src_version:=cVocabSrcVer;
              --sources_updated:=case when cVocabVer=cVocabSrcVer then 1 else 0 end;
          END IF;
        ELSE
          IF cVocabDate > COALESCE(cVocabOldDate, TO_DATE ('19700101', 'yyyymmdd'))
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