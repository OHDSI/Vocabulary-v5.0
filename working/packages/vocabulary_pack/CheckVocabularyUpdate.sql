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
        ) as s
        WHERE UPPER(vocabulary_id)=case cVocabularyName when 'NDC_SPL' then 'NDC' else cVocabularyName end;

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
        */
        SELECT http_content into cVocabHTML FROM vocabulary_download.py_http_get(url=>cURL,allow_redirects=>true);
        
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
                cSearchString := '<a class="btn btn-info" href="';
                cPos1 := devv5.INSTR (cVocabHTML, cSearchString);
                cPos2 := devv5.INSTR (cVocabHTML, '.zip"><strong>Download RF2 Files Now!</strong></a>', cPos1);
                perform vocabulary_pack.CheckVocabularyPositions (cPos1, cPos2, pVocabularyName);
                cVocabDate := TO_DATE (SUBSTRING (SUBSTR (cVocabHTML, cPos1 + LENGTH (cSearchString), cPos2 - cPos1 - LENGTH (cSearchString)), '[[:digit:]]+'), 'yyyymmdd');
                cVocabVer := 'Snomed Release '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'HCPCS'
            THEN
              cVocabDate := TO_DATE(SUBSTRING(cVocabHTML,'<a href="/Medicare/Coding/HCPCSReleaseCodeSets/Alpha-Numeric-HCPCS-Items/([[:digit:]]{4})-Alpha-Numeric-HCPCS-File">')::int - 1 || '0101', 'yyyymmdd');
              /*old version
              select TO_DATE ( (MAX (t.title) - 1) || '0101', 'yyyymmdd') into cVocabDate  From (
                select 
                    unnest(xpath ('/rss/channel/item/title/text()', cVocabHTML::xml))::varchar::int title,
                    unnest(xpath ('/rss/channel/item/link/text()', cVocabHTML::xml)) ::varchar description 
              ) as t
              WHERE t.description LIKE '%Alpha-Numeric-HCPCS-File%' AND t.description NOT LIKE '%orrections%';
              */
              cVocabVer := to_char(cVocabDate + interval '1 year','YYYY')||' Alpha Numeric HCPCS File';
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
                cVocabDate := TO_DATE (SUBSTRING (cVocabHTML, 'FY ([[:digit:]]{4}) release of ICD-10-CM') || '0101', 'yyyymmdd');
                cVocabVer := 'ICD10CM FY'||to_char(cVocabDate,'YYYY')||' code descriptions';
            WHEN cVocabularyName = 'ICD10PCS'
            THEN
                cVocabDate := TO_DATE(SUBSTRING(LOWER(cVocabHTML),'<a href="/medicare/[^/]+/([[:digit:]]{4})-icd-10-pcs".*?>[[:digit:]]{4} icd-10-pcs</a>') || '1001', 'yyyymmdd') - interval '1 year';
                /*old version2
                select s1.icd10pcs_year into cVocabDate from (
                  select TO_DATE (SUBSTRING(url,'/([[:digit:]]{4})')::int - 1 || '0101', 'yyyymmdd') icd10pcs_year from (
                    select unnest(xpath ('//global:loc/text()', cVocabHTML::xml, ARRAY[ARRAY['global', 'http://www.sitemaps.org/schemas/sitemap/0.9']]))::varchar url
                  ) s0
                  where s0.url ilike '%www.cms.gov/Medicare/Coding/ICD10/Downloads/%PCS%Order%.zip'
                ) as s1 order by s1.icd10pcs_year desc limit 1;
                */
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
                cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'.+<th rowspan="4">ALL FILES</th>.+?<td.+?>([-\d]{10})</td>.*'),'yyyy-mm-dd');
                cVocabVer := 'DPD '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'CVX'
            THEN
                select s0.cvx_date into cVocabDate from (
                  select unnest(xpath ('/rdf:RDF/global:item/dc:date/text()', cVocabHTML::xml, 
                  ARRAY[
                    ARRAY['rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'],
                    ARRAY['global', 'http://purl.org/rss/1.0/'],
                    ARRAY['dc', 'http://purl.org/dc/elements/1.1/']
                  ]))::VARCHAR::date cvx_date,
                  unnest(xpath ('/rdf:RDF/global:item/global:title/text()', cVocabHTML::xml, 
                  ARRAY[
                    ARRAY['rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'],
                    ARRAY['global', 'http://purl.org/rss/1.0/']
                  ]))::VARCHAR cvx_title
                ) as s0 where cvx_title like 'Vaccines administered (CVX)%' order by s0.cvx_date desc limit 1;
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
                    select trim(replace(replace(regexp_replace(t.json_content->>'name','^CDM v5\.0$','CDM v5.0.0'),' (historical)',''),'CDM v5.2 Bug Fix 1','CDM v5.2.0')) as vocabulary_version, 
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
                cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'.+?<a href="SnomedCT_Release_VTS.+?_([\d]{8})\.zip" target="main">Download the Veterinary Extension of SNOMED CT</a>.+'),'yyyymmdd');
                cVocabVer := 'SNOMED Veterinary '||to_char(cVocabDate,'YYYYMMDD');
            WHEN cVocabularyName = 'ICD10GM'
            THEN
                --ICD10GM uses ajax, so we need to make another HTTP-request to get date/version
                SELECT http_content INTO cVocabHTML FROM vocabulary_download.py_http_get(url=>'https://www.dimdi.de/dynamic/system/modules/de.dimdi.apollo.template.downloadcenter/pages/filelist-ajax.jsp?folder='||
                    SUBSTRING(cVocabHTML,'.*data-folder="(.*?/klassifikationen/icd-10-gm/version\d{4}/)"')||'&sitepath=/dynamic/system/modules/de.dimdi.apollo.template.downloadcenter/pages/&loc=de&rows=25&start=0',allow_redirects=>true);
                --cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'.*<a class=.*?/icd-10-gm/version\d{4}/icd10gm\d{4}syst-meta\.zip">ICD-10-GM \d{4} Metadaten TXT \(CSV\) </a>.*?<p>Stand: ([\d.]+).*'),'dd.mm.yyyy');
                --cVocabVer := cVocabularyName||SUBSTRING (cVocabHTML,'.*<a class=.*?/icd-10-gm/version\d{4}/icd10gm\d{4}syst-meta\.zip">ICD-10-GM( \d{4}) Metadaten TXT \(CSV\) </a>.*?<p>Stand: [\d.]+.*');
                cVocabDate := TO_DATE (SUBSTRING (cVocabHTML,'.*<a class=.*?/icd-10-gm/version\d{4}/icd10gm\d{4}syst-meta\.zip">ICD-10-GM (\d{4}) Metadaten TXT \(CSV\) </a>.*?<p>Stand: [\d.]+.*'),'yyyy');
                cVocabVer := cVocabularyName||' '||to_char(cVocabDate,'YYYY');
            WHEN cVocabularyName = 'CCAM'
            THEN
              cVocabVer := SUBSTRING (LOWER(cVocabHTML),'.+?<h3>version actuelle</h3><div class="telechargement_bas"><h4>ccam version ([\d]+)</h4>.+');
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