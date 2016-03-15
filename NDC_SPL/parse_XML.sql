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
* Authors: Timur Vakhitov, Christian Reich
* Date: 2016
**************************************************************************/

--1. Clear target tables
TRUNCATE TABLE SPL2NDC_MAPPINGS;
TRUNCATE TABLE SPL_EXT;
ALTER INDEX SPLEXT_idx UNUSABLE;
ALTER INDEX SPL2NDC_idx UNUSABLE;

--2. Create temporary table for SPL to NDC mappings from XML sources
INSERT /*+ APPEND */ INTO SPL2NDC_MAPPINGS
   SELECT concept_code,
          CASE WHEN LENGTH (ndc_p1) = 4 THEN '0' || ndc_p1 ELSE ndc_p1 END
       || CASE WHEN LENGTH (ndc_p2) = 3 THEN '0' || ndc_p2 ELSE ndc_p2 END
       || CASE WHEN LENGTH (ndc_p3) = 1 THEN '0' || ndc_p3 ELSE ndc_p3 END
          AS ndc_code
    from (
        SELECT concept_code, REGEXP_SUBSTR(ndc_code, '[^-]+', 1, 1) ndc_p1, REGEXP_SUBSTR(ndc_code, '[^-]+', 1, 2) ndc_p2, REGEXP_SUBSTR(ndc_code, '[^-]+', 1, 3) ndc_p3 FROM
        (
        SELECT DISTINCT TRIM (concept_code) AS concept_code, TRIM (ndc_code) AS ndc_code FROM (
            SELECT /*+ no_merge */ * FROM (
                SELECT traw.xmlfield.EXTRACT('/document/setId/@root','xmlns="urn:hl7-org:v3"').getStringVal() AS concept_code,
                EXTRACTVALUE (VALUE (T), 'containerPackagedProduct/code/@code') ndc_1,
                EXTRACTVALUE (VALUE (t1), 'containerPackagedProduct/code/@code') ndc_2
                FROM spl_ext_raw  traw, TABLE (XMLSEQUENCE (traw.xmlfield.EXTRACT ('/document/component/structuredBody/component/section/subject/manufacturedProduct/manufacturedProduct/asContent/containerPackagedProduct','xmlns="urn:hl7-org:v3"')))(+) T
                , TABLE (XMLSEQUENCE (traw.xmlfield.EXTRACT ('/document/component/structuredBody/component/section/subject/manufacturedProduct/manufacturedProduct/asContent/containerPackagedProduct/asContent/containerPackagedProduct','xmlns="urn:hl7-org:v3"')))(+) t1            ) where coalesce(ndc_1,ndc_2) is not null --and rownum>0
        ) 
        UNPIVOT (ndc_code FOR ndc_codes IN (ndc_1, ndc_2))

        UNION ALL

        SELECT DISTINCT TRIM (concept_code) AS concept_code, TRIM (ndc_code) AS ndc_code FROM (
            SELECT /*+ no_merge */ * FROM (
                SELECT traw.xmlfield.extract('/document/setId/@root','xmlns="urn:hl7-org:v3"').getStringVal() as concept_code,
                EXTRACTVALUE (VALUE (t), 'containerPackagedMedicine/code/@code') ndc_1,
                EXTRACTVALUE (VALUE (t1), 'containerPackagedMedicine/code/@code') ndc_2
                FROM spl_ext_raw  traw, TABLE (XMLSEQUENCE (traw.xmlfield.EXTRACT ('/document/component/structuredBody/component/section/subject/manufacturedProduct/manufacturedMedicine/asContent/containerPackagedMedicine','xmlns="urn:hl7-org:v3"')))(+) t
                , TABLE (XMLSEQUENCE (traw.xmlfield.EXTRACT ('/document/component/structuredBody/component/section/subject/manufacturedProduct/manufacturedMedicine/asContent/containerPackagedMedicine/asContent/containerPackagedMedicine','xmlns="urn:hl7-org:v3"')))(+) t1
            ) WHERE COALESCE(ndc_1,ndc_2) IS NOT NULL
        ) 
        UNPIVOT (ndc_code FOR ndc_codes IN (ndc_1, ndc_2))
        )        
    ) WHERE LENGTH(ndc_p2)<=4;
COMMIT;

--3. Create temporary table for SPL concepts from XML sources
INSERT /*+ APPEND */ INTO SPL_EXT
    select xml_name, TRANSLATE (concept_name,'X' || CHR (9) || CHR (10) || CHR (13),'X') concept_name, concept_code, valid_start_date, displayname, replaced_spl, low_value, high_value from (
        select xml_name, coalesce(concept_name,to_char(concept_name_clob))||' - '||coalesce(lower(kit), concept_name_p2,to_char(concept_name_clob_p2)) as concept_name, concept_code, valid_start_date, displayname, replaced_spl,
        low_value, high_value from (
            select xml_name, trim(upper(trim(concept_name_part))||' '||upper(trim(concept_name_suffix))) as concept_name, trim(upper(trim(concept_name_clob_part))||' '||upper(trim(concept_name_clob_suffix))) as concept_name_clob, 
            trim(lower(trim(concept_name_part2))||' '||lower(trim(formcode))) as concept_name_p2, trim(lower(trim(concept_name_clob_part2))||' '||lower(trim(formcode_clob))) as concept_name_clob_p2, concept_code,
            to_date(substr(valid_start_date,1,6) || case when to_number(substr(valid_start_date,-2,2))>31 then '31' else substr(valid_start_date,-2,2) end, 'YYYYMMDD') as valid_start_date, 
            upper(trim(regexp_replace(displayname, '[[:space:]]+',' '))) as displayname, replaced_spl, kit,
            trim (';' from low_value1||';'||low_value2) low_value,
            trim (';' from high_value1||';'||high_value2) high_value
            from (
                select t.xml_name, 
                extractvalue(t.xmlfield,'/document/component/structuredBody/component[1]/section/subject[1]/manufacturedProduct/*/name/text()','xmlns="urn:hl7-org:v3"') as concept_name_part,
                extractvalue(t.xmlfield,'/document/component/structuredBody/component[1]/section/subject[1]/manufacturedProduct/*/name/suffix','xmlns="urn:hl7-org:v3"') as concept_name_suffix,
                extractvalue(t.xmlfield,'/document/component/structuredBody/component[1]/section/subject[1]/manufacturedProduct/*/asEntityWithGeneric/genericMedicine/name/text()','xmlns="urn:hl7-org:v3"') as concept_name_part2,
                extractvalue(t.xmlfield,'/document/component/structuredBody/component[1]/section/subject[1]/manufacturedProduct/*/formCode/@displayName/text()','xmlns="urn:hl7-org:v3"') as formcode,
                extractvalue(t.xmlfield,'/document/component/structuredBody/component[1]/section/subject[1]/manufacturedProduct/*/asSpecializedKind/generalizedMaterialKind/code/@displayName/text()','xmlns="urn:hl7-org:v3"') as kit,
                t.xmlfield.extract('/document/component/structuredBody/component/section/subject/manufacturedProduct/*/name/text()','xmlns="urn:hl7-org:v3"').getClobVal() as concept_name_clob_part,
                t.xmlfield.extract('/document/component/structuredBody/component/section/subject/manufacturedProduct/*/name/suffix/text()','xmlns="urn:hl7-org:v3"').getClobVal() as concept_name_clob_suffix,
                t.xmlfield.extract('/document/component/structuredBody/component/section/subject/manufacturedProduct/*/asEntityWithGeneric/genericMedicine/name/text()','xmlns="urn:hl7-org:v3"').getClobVal() as concept_name_clob_part2,
                t.xmlfield.extract('/document/component/structuredBody/component/section/subject/manufacturedProduct/*/formCode/@displayName','xmlns="urn:hl7-org:v3"').getClobVal() as formcode_clob,
                t.xmlfield.extract('/document/setId/@root','xmlns="urn:hl7-org:v3"').getStringVal() as concept_code,
                t.xmlfield.extract('/document/effectiveTime/@value','xmlns="urn:hl7-org:v3"').getStringVal() as valid_start_date,
                t.xmlfield.extract('/document/code/@displayName','xmlns="urn:hl7-org:v3"').getStringVal() as displayname,
                --t.xmlfield.extract('/document/relatedDocument/relatedDocument/setId/@root','xmlns="urn:hl7-org:v3"').getStringVal() as replaced_spl,
                xmlcast(xmlquery(( 'declare default element namespace "urn:hl7-org:v3"; (::) string-join(//child::text(),";")' ) passing 
                    extract(t.xmlfield, '/document/relatedDocument/relatedDocument/setId/@root', 'xmlns="urn:hl7-org:v3"') returning content) as varchar2(4000)) as replaced_spl,
                xmlcast(xmlquery(( 'declare default element namespace "urn:hl7-org:v3"; (::) string-join(distinct-values(//child::text()),";")' ) passing 
                    extract(t.xmlfield, '/document/component/structuredBody/component/section/subject/manufacturedProduct/subjectOf/marketingAct/effectiveTime/low/@value', 'xmlns="urn:hl7-org:v3"') returning content) as varchar2(4000)) as low_value1,
                xmlcast(xmlquery(( 'declare default element namespace "urn:hl7-org:v3"; (::) string-join(distinct-values(//child::text()),";")' ) passing 
                    extract(t.xmlfield, '/document/component/structuredBody/component/section/subject/manufacturedProduct/manufacturedProduct/asContent/subjectOf/marketingAct/effectiveTime/low/@value', 'xmlns="urn:hl7-org:v3"') returning content) as varchar2(4000)) as low_value2,                
                xmlcast(xmlquery(( 'declare default element namespace "urn:hl7-org:v3"; (::) string-join(distinct-values(//child::text()),";")' ) passing 
                    extract(t.xmlfield, '/document/component/structuredBody/component/section/subject/manufacturedProduct/subjectOf/marketingAct/effectiveTime/high/@value', 'xmlns="urn:hl7-org:v3"') returning content) as varchar2(4000)) as high_value1,            
                xmlcast(xmlquery(( 'declare default element namespace "urn:hl7-org:v3"; (::) string-join(distinct-values(//child::text()),";")' ) passing 
                    extract(t.xmlfield, '/document/component/structuredBody/component/section/subject/manufacturedProduct/manufacturedProduct/asContent/subjectOf/marketingAct/effectiveTime/high/@value', 'xmlns="urn:hl7-org:v3"') returning content) as varchar2(4000)) as high_value2
                from spl_ext_raw  t    
        )
    )
);
COMMIT;

--4 Delete duplicate records
DELETE from spl_ext where rowid not in (select max(rowid) from spl_ext group by concept_code);
COMMIT;

--5. GATHER_TABLE_STATS
ALTER INDEX SPLEXT_idx REBUILD NOLOGGING;
ALTER INDEX SPL2NDC_idx REBUILD NOLOGGING;
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'SPL2NDC_MAPPINGS', estimate_percent  => null, cascade  => true);
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'SPL_EXT', estimate_percent  => null, cascade  => true);