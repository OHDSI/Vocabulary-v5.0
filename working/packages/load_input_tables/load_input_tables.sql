CREATE OR REPLACE FUNCTION sources.load_input_tables (
  pvocabularyid text,
  pvocabularydate date = NULL::date,
  pvocabularyversion text = NULL::text
)
RETURNS void AS
$body$
declare
  pVocabularyPath varchar (1000) := (SELECT var_value FROM devv5.config$ WHERE var_name='vocabulary_load_path');
  z varchar(100);
begin
  pVocabularyID=UPPER(pVocabularyID);
  pVocabularyPath=pVocabularyPath||pVocabularyID||'/';
  case pVocabularyID
  when 'UMLS' THEN
      truncate table sources.mrconso, sources.mrhier, sources.mrmap, sources.mrsmap, sources.mrsat, sources.mrrel;
      alter table sources.mrconso drop constraint x_mrconso_pk;
      drop index sources.x_mrsat_cui;
      drop index sources.x_mrconso_code;
      drop index sources.x_mrconso_cui;
      drop index sources.x_mrconso_lui;
      drop index sources.x_mrconso_sab_tty;
      drop index sources.x_mrconso_scui;
      drop index sources.x_mrconso_sdui;
      drop index sources.x_mrconso_str;
      drop index sources.x_mrconso_sui;
      drop index sources.x_mrrel_aui;
      /*
      UMLS can contain characters like single quotes and double quotes, but PG uses them as a service characters
      So we specifying a quote character that should never be in the text: E'\b' (backspace)
      */
      execute 'COPY sources.mrconso FROM '''||pVocabularyPath||'MRCONSO.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.mrhier FROM '''||pVocabularyPath||'MRHIER.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.mrmap FROM '''||pVocabularyPath||'MRMAP.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.mrsmap (mapsetcui,mapsetsab,mapid,mapsid,fromexpr,fromtype,rel,rela,toexpr,totype,cvf,vocabulary_date) FROM '''||pVocabularyPath||'MRSMAP.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.mrsat FROM '''||pVocabularyPath||'MRSAT.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.mrrel FROM '''||pVocabularyPath||'MRREL.RRF'' delimiter ''|'' csv quote E''\b''';
      update sources.mrsmap set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
            
      CREATE INDEX x_mrsat_cui ON sources.mrsat (cui);
      CREATE INDEX x_mrconso_code ON sources.mrconso (code);
      CREATE INDEX x_mrconso_cui ON sources.mrconso (cui);
      CREATE INDEX x_mrconso_lui ON sources.mrconso (lui);
      CREATE UNIQUE INDEX x_mrconso_pk ON sources.mrconso (aui);
      CREATE INDEX x_mrconso_sab_tty ON sources.mrconso (sab, tty);
      CREATE INDEX x_mrconso_scui ON sources.mrconso (scui);
      CREATE INDEX x_mrconso_sdui ON sources.mrconso (sdui);
      CREATE INDEX x_mrconso_str ON sources.mrconso (str);
      CREATE INDEX x_mrconso_sui ON sources.mrconso (sui);
      CREATE INDEX x_mrrel_aui ON sources.mrrel (aui1, aui2);
      ALTER TABLE sources.mrconso ADD CONSTRAINT x_mrconso_pk PRIMARY KEY USING INDEX x_mrconso_pk;
      analyze sources.mrconso;
      analyze sources.mrhier;
      analyze sources.mrmap;
      analyze sources.mrsmap;
      analyze sources.mrsat;
      analyze sources.mrrel;
  when 'CIEL' then
      set local datestyle='ISO, DMY'; --set proper date format
      truncate table sources.concept_ciel, sources.concept_class_ciel, sources.concept_name, sources.concept_reference_map, sources.concept_reference_term, sources.concept_reference_source;
      execute 'COPY sources.concept_ciel FROM '''||pVocabularyPath||'CONCEPT_CIEL.csv'' delimiter ''|'' csv';
      execute 'COPY sources.concept_class_ciel (concept_class_id,"name",description,creator,date_created,
      	retired,retired_by,date_retired,retire_reason,uuid,filler_column) FROM '''||pVocabularyPath||'CONCEPT_CLASS_CIEL.csv'' delimiter ''|'' csv';
      execute 'COPY sources.concept_name FROM '''||pVocabularyPath||'CONCEPT_NAME.csv'' delimiter ''|'' csv';
      execute 'COPY sources.concept_reference_map FROM '''||pVocabularyPath||'CONCEPT_REFERENCE_MAP.csv'' delimiter ''|'' csv';
      execute 'COPY sources.concept_reference_term FROM '''||pVocabularyPath||'CONCEPT_REFERENCE_TERM.csv'' delimiter ''|'' csv';
      execute 'COPY sources.concept_reference_source FROM '''||pVocabularyPath||'CONCEPT_REFERENCE_SOURCE.csv'' delimiter ''|'' csv';
      update sources.concept_class_ciel set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      analyze sources.concept_ciel;
      analyze sources.concept_class_ciel;
      analyze sources.concept_name;
      analyze sources.concept_reference_map;
      analyze sources.concept_reference_term;
      analyze sources.concept_reference_source;
  when 'RXNORM' then
      truncate table sources.rxnsat, sources.rxnrel, sources.rxnatomarchive, sources.rxnconso;
      drop index sources.x_rxnconso_str;
      drop index sources.x_rxnconso_rxcui;
      drop index sources.x_rxnconso_tty;
      drop index sources.x_rxnconso_code;
      drop index sources.x_rxnconso_rxaui;
      drop index sources.x_rxnsat_rxcui;
      drop index sources.x_rxnsat_atv;
      drop index sources.x_rxnsat_atn;
      drop index sources.x_rxnrel_rxcui1;
      drop index sources.x_rxnrel_rxcui2;
      drop index sources.x_rxnrel_rela;
      drop index sources.x_rxnatomarchive_rxaui;
      drop index sources.x_rxnatomarchive_rxcui;
      drop index sources.x_rxnatomarchive_merged_to;
      execute 'COPY sources.rxnsat FROM '''||pVocabularyPath||'RXNSAT.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.rxnrel FROM '''||pVocabularyPath||'RXNREL.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.rxnatomarchive (rxaui,aui,str,archive_timestamp,created_timestamp,updated_timestamp,code,is_brand,lat,last_released,saui,vsab,rxcui,sab,tty,merged_to_rxcui,vocabulary_date) FROM '''||pVocabularyPath||'RXNATOMARCHIVE.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.rxnconso FROM '''||pVocabularyPath||'RXNCONSO.RRF'' delimiter ''|'' csv quote E''\b''';
      CREATE INDEX x_rxnconso_str ON sources.rxnconso(str);
      CREATE INDEX x_rxnconso_rxcui ON sources.rxnconso(rxcui);
      CREATE INDEX x_rxnconso_tty ON sources.rxnconso(tty);
      CREATE INDEX x_rxnconso_code ON sources.rxnconso(code);
      CREATE INDEX x_rxnconso_rxaui ON sources.rxnconso(rxaui);
      CREATE INDEX x_rxnsat_rxcui ON sources.rxnsat(rxcui);
      CREATE INDEX x_rxnsat_atv ON sources.rxnsat(atv);
      CREATE INDEX x_rxnsat_atn ON sources.rxnsat(atn);
      CREATE INDEX x_rxnrel_rxcui1 ON sources.rxnrel(rxcui1);
      CREATE INDEX x_rxnrel_rxcui2 ON sources.rxnrel(rxcui2);
      CREATE INDEX x_rxnrel_rela ON sources.rxnrel(rela);
      CREATE INDEX x_rxnatomarchive_rxaui ON sources.rxnatomarchive(rxaui);
      CREATE INDEX x_rxnatomarchive_rxcui ON sources.rxnatomarchive(rxcui);
      CREATE INDEX x_rxnatomarchive_merged_to ON sources.rxnatomarchive(merged_to_rxcui);
      update sources.rxnatomarchive set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      analyze sources.rxnsat;
      analyze sources.rxnrel;
      analyze sources.rxnatomarchive;
      analyze sources.rxnconso;
  when 'DRG' then
      truncate table sources.fy_table_5;
      execute 'COPY sources.fy_table_5 (drg_code,filler_column1,filler_column2,filler_column3,filler_column4,
      	drg_name,filler_column5,filler_column6,filler_column7,filler_column8,filler_column9) FROM '''||pVocabularyPath||'FY.txt'' delimiter E''\t'' csv';
      update sources.fy_table_5 set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      analyze sources.fy_table_5;
  when 'ICD9CM' then
      truncate table sources.icd9cm_temp, sources.cms_desc_short_dx, sources.cms_desc_long_dx;
      --load CMS32_DESC_SHORT_DX
      execute 'COPY sources.icd9cm_temp FROM '''||pVocabularyPath||'CMS32_DESC_SHORT_DX.txt'' delimiter E''\b''';
      insert into sources.cms_desc_short_dx (code, name)  select trim(substring (cms32_codes_and_desc from 1 for 6)), trim(substring (cms32_codes_and_desc from 7)) From  SOURCES.icd9cm_temp;
      update sources.cms_desc_short_dx set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      --load CMS32_DESC_SHORT_DX
      truncate table sources.icd9cm_temp;
      execute 'COPY sources.icd9cm_temp FROM '''||pVocabularyPath||'CMS32_DESC_LONG_DX.txt'' delimiter E''\b'' ENCODING ''ISO-8859-1'''; --CMS32_DESC_LONG_DX in ANSI
      insert into sources.cms_desc_long_dx select trim(substring (cms32_codes_and_desc from 1 for 6)), trim(substring (cms32_codes_and_desc from 7)) From  SOURCES.icd9cm_temp;
      analyze sources.cms_desc_short_dx;
      analyze sources.cms_desc_long_dx;
  when 'ICD9PROC' then
      truncate table sources.icd9proc_temp, sources.cms_desc_short_sg, sources.cms_desc_long_sg;
      --load CMS32_DESC_SHORT_SG
      execute 'COPY sources.icd9proc_temp FROM '''||pVocabularyPath||'CMS32_DESC_SHORT_SG.txt'' delimiter E''\b''';
      insert into sources.cms_desc_short_sg (code, name) select trim(substring (cms32_codes_and_desc from 1 for 4)), trim(substring (cms32_codes_and_desc from 6)) From  SOURCES.icd9proc_temp;
      update sources.cms_desc_short_sg set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      --load CMS32_DESC_SHORT_SG
      truncate table sources.icd9proc_temp;
      execute 'COPY sources.icd9proc_temp FROM '''||pVocabularyPath||'CMS32_DESC_LONG_SG.txt'' delimiter E''\b''';
      insert into sources.cms_desc_long_sg select trim(substring (cms32_codes_and_desc from 1 for 4)), trim(substring (cms32_codes_and_desc from 6)) From  SOURCES.icd9proc_temp;      
      analyze sources.cms_desc_short_sg;
      analyze sources.cms_desc_long_sg;
  when 'OPCS4' then
      truncate table sources.opcs, sources.opcssctmap;
      execute 'COPY sources.opcs (cui, term) FROM PROGRAM ''mdb-export -H "'||pVocabularyPath||'opcs4_data_migration.mdb" OPCS'' delimiter '','' csv';
      execute 'COPY sources.opcssctmap FROM PROGRAM ''mdb-export -H "'||pVocabularyPath||'opcs4_data_migration.mdb" OPCSSCTMAP'' delimiter '','' csv';
      update sources.opcs set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      UPDATE sources.opcs SET cui = REPLACE (cui, '–', '-') WHERE cui LIKE '%–%'; --remove long dashes
      analyze sources.opcs;
      analyze sources.opcssctmap;
  when 'READ' then
      truncate table sources.keyv2, sources.rcsctmap2_uk;
      execute 'COPY sources.keyv2 (termclass,classnumber,description_short,description,description_long,termcode,lang,readcode,digit) FROM '''||pVocabularyPath||'Keyv2.all'' delimiter '','' csv FORCE NULL termclass,description_short,description,description_long';
      execute 'COPY sources.rcsctmap2_uk FROM '''||pVocabularyPath||'rcsctmap2_uk.txt'' delimiter E''\t'' csv HEADER';
      update sources.keyv2 set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      analyze sources.keyv2;
      analyze sources.rcsctmap2_uk;
  when 'GCNSEQNO' then
      truncate table sources.nddf_product_info;
      insert into sources.nddf_product_info values (COALESCE(pVocabularyDate,current_date), COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date));
  when 'INDICATION' then
      truncate table sources.rfmlsyn0_dxid_syn, sources.rfmldx0_dxid, sources.rfmldrh0_dxid_hist, sources.rfmlisr1_icd_search, sources.rddcmma1_contra_mstr, 
      	sources.rddcmgc0_contra_gcnseqno_link, sources.rindmma2_indcts_mstr, sources.rindmgc0_indcts_gcnseqno_link;
      execute 'COPY sources.rfmlsyn0_dxid_syn FROM '''||pVocabularyPath||'RFMLSYN0_DXID_SYN.txt'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.rfmldx0_dxid FROM '''||pVocabularyPath||'RFMLDX0_DXID.txt'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.rfmldrh0_dxid_hist FROM '''||pVocabularyPath||'RFMLDRH0_DXID_HIST.txt'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.rfmlisr1_icd_search FROM '''||pVocabularyPath||'RFMLISR1_ICD_SEARCH.txt'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.rddcmma1_contra_mstr FROM '''||pVocabularyPath||'RDDCMMA1_CONTRA_MSTR.txt'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.rddcmgc0_contra_gcnseqno_link FROM '''||pVocabularyPath||'RDDCMGC0_CONTRA_GCNSEQNO_LINK.txt'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.rindmma2_indcts_mstr FROM '''||pVocabularyPath||'RINDMMA2_INDCTS_MSTR.txt'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.rindmgc0_indcts_gcnseqno_link FROM '''||pVocabularyPath||'RINDMGC0_INDCTS_GCNSEQNO_LINK.txt'' delimiter ''|'' csv quote E''\b''';
      analyze sources.rfmlsyn0_dxid_syn;
      analyze sources.rfmldx0_dxid;
      analyze sources.rfmldrh0_dxid_hist;
      analyze sources.rfmlisr1_icd_search;
      analyze sources.rddcmma1_contra_mstr;
      analyze sources.rddcmgc0_contra_gcnseqno_link;
      analyze sources.rindmma2_indcts_mstr;
      analyze sources.rindmgc0_indcts_gcnseqno_link;
  when 'ETC' then
      truncate table sources.retctbl0_etc_id, sources.retcgch0_etc_gcnseqno_hist, sources.retchch0_etc_hicseqn_hist;
      execute 'COPY sources.retctbl0_etc_id FROM '''||pVocabularyPath||'RETCTBL0_ETC_ID.txt'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.retcgch0_etc_gcnseqno_hist FROM '''||pVocabularyPath||'RETCGCH0_ETC_GCNSEQNO_HIST.txt'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.retchch0_etc_hicseqn_hist FROM '''||pVocabularyPath||'RETCHCH0_ETC_HICSEQN_HIST.txt'' delimiter ''|'' csv quote E''\b''';
      analyze sources.retctbl0_etc_id;
      analyze sources.retcgch0_etc_gcnseqno_hist;
      analyze sources.retchch0_etc_hicseqn_hist;
  when 'MEDDRA' then
      truncate table sources.hlgt_pref_term, sources.hlgt_hlt_comp, sources.hlt_pref_term, sources.hlt_pref_comp, sources.low_level_term, 
      	sources.md_hierarchy, sources.pref_term, sources.soc_term, sources.soc_hlgt_comp;
      execute 'COPY sources.hlgt_pref_term FROM '''||pVocabularyPath||'hlgt.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.hlgt_hlt_comp FROM '''||pVocabularyPath||'hlgt_hlt.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.hlt_pref_term FROM '''||pVocabularyPath||'hlt.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.hlt_pref_comp (hlt_code,pt_code,filler_column) FROM '''||pVocabularyPath||'hlt_pt.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.low_level_term FROM '''||pVocabularyPath||'llt.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.md_hierarchy FROM '''||pVocabularyPath||'mdhier.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.pref_term FROM '''||pVocabularyPath||'pt.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.soc_term FROM '''||pVocabularyPath||'soc.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.soc_hlgt_comp FROM '''||pVocabularyPath||'soc_hlgt.asc'' delimiter ''$'' csv quote E''\b''';
      update sources.hlt_pref_comp set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      analyze sources.hlgt_pref_term;
      analyze sources.hlgt_hlt_comp;
      analyze sources.hlt_pref_term;
      analyze sources.hlt_pref_comp;
      analyze sources.low_level_term;
      analyze sources.md_hierarchy;
      analyze sources.pref_term;
      analyze sources.soc_term;
      analyze sources.soc_hlgt_comp;
  when 'GPI' then
      truncate table sources.gpi_name, sources.ndw_v_product;
      execute 'COPY sources.gpi_name (gpi_code,drug_string) FROM '''||pVocabularyPath||'gpi_name.txt'' delimiter '';'' csv quote ''$''';
      execute 'COPY sources.ndw_v_product FROM '''||pVocabularyPath||'ndw_v_product.txt'' delimiter ''|'' csv quote E''\b'' HEADER';
      update sources.gpi_name set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      analyze sources.gpi_name;
      analyze sources.ndw_v_product;
  when 'EPHMRA ATC' then
      truncate table sources.atc_glossary;
      execute 'COPY sources.atc_glossary (concept_code,concept_name,n1,n2) FROM '''||pVocabularyPath||'ATC_Glossary.csv'' delimiter '';'' csv quote E''\b'' ENCODING ''ISO-8859-1''';
      update sources.atc_glossary set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      analyze sources.atc_glossary;
  when 'NFC' then
      truncate table sources.nfc;
      execute 'COPY sources.nfc (concept_code,concept_name) FROM '''||pVocabularyPath||'nfc.txt'' delimiter E''\t'' csv quote E''\b''';
      update sources.nfc set concept_name=TRIM(REGEXP_REPLACE (concept_name, '[[:space:]]+', ' ', 'g'));
      update sources.nfc set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      analyze sources.nfc;
  when 'ICD10PCS' then
      truncate table sources.icd10pcs_temp, sources.icd10pcs;
      execute 'COPY sources.icd10pcs_temp FROM '''||pVocabularyPath||'icd10pcs.txt'' delimiter E''\b''';
      insert into sources.icd10pcs (concept_code, concept_name) select trim(substring (icd10pcs_codes_and_desc from 7 for 7)), trim(substring (icd10pcs_codes_and_desc from 78 for 300)) From  SOURCES.icd10pcs_temp;
      update sources.icd10pcs set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      analyze sources.icd10pcs;
  when 'NDC_SPL' then
      truncate table sources.product, sources.package;
      execute 'COPY sources.product (productid,productndc,producttypename,proprietaryname,proprietarynamesuffix,nonproprietaryname,dosageformname,
      	routename,startmarketingdate,endmarketingdate,marketingcategoryname,applicationnumber,labelername,substancename,active_numerator_strength,
        active_ingred_unit,pharm_classes,deaschedule,ndc_exclude_flag,listing_record_certified_through) FROM '''||pVocabularyPath||'product.txt'' delimiter E''\t'' csv ENCODING ''ISO-8859-15'' HEADER';
      update sources.product set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      analyze sources.product;
      execute 'COPY sources.package (productid,productndc,ndcpackagecode,packagedescription,startmarketingdate,endmarketingdate,ndc_exclude_flag,sample_package) FROM '''||pVocabularyPath||'package.txt'' delimiter E''\t'' csv ENCODING ''ISO-8859-15'' HEADER';
      update sources.package p SET pack_code=i.pack_code
      FROM (
        SELECT ndcpackagecode,
            CASE 
                WHEN length(pack_1) = 4
                    THEN '0' || pack_1
                ELSE pack_1
                END || CASE 
                WHEN length(pack_2) = 3
                    THEN '0' || pack_2
                ELSE pack_2
                END || CASE 
                WHEN length(pack_3) = 1
                    THEN '0' || pack_3
                ELSE pack_3
                END as pack_code
        FROM (
            SELECT (string_to_array(pack.ndcpackagecode, '-')) [1] AS pack_1,
                (string_to_array(pack.ndcpackagecode, '-')) [2] AS pack_2,
                (string_to_array(pack.ndcpackagecode, '-')) [3] AS pack_3,
                pack.ndcpackagecode,
                pack.productndc
            FROM sources.package pack
            ) AS s0 	
      ) i where p.ndcpackagecode=i.ndcpackagecode;
      analyze sources.package;
      truncate table sources.allxmlfilelist, sources.spl_ext_raw;
      execute 'COPY sources.allxmlfilelist FROM '''||pVocabularyPath||'allxmlfilelist.dat''';
      for z in (select * from sources.allxmlfilelist order by 1) loop
        /*Use PROGRAM for running 'cat' with 'tr'. 'tr' for replacing all carriage returns with space. quote E'\f' for prevent 'invalid byte sequence for encoding "UTF8"' errors,
        because xml files can contain "\..." in strings*/
        execute 'COPY sources.spl_ext_raw (xmlfield) FROM PROGRAM ''cat "'||pVocabularyPath||z||'"| tr ''''\r\n'''' '''' ''''  '' csv delimiter E''\b'' quote E''\f'' ';
      end loop;
      truncate table sources.spl2rxnorm_mappings;
      execute 'COPY sources.spl2rxnorm_mappings FROM '''||pVocabularyPath||'rxnorm_mappings.txt'' delimiter ''|'' csv HEADER';
      --XML parsing
      TRUNCATE TABLE sources.spl2ndc_mappings;
      TRUNCATE TABLE sources.spl_ext;
      --create table for SPL to NDC mappings from XML sources
      INSERT INTO sources.spl2ndc_mappings
      SELECT concept_code,
          CONCAT (
              CASE 
                  WHEN LENGTH(ndc_p1) = 4
                      THEN '0' || ndc_p1
                  ELSE ndc_p1
                  END,
              CASE 
                  WHEN LENGTH(ndc_p2) = 3
                      THEN '0' || ndc_p2
                  ELSE ndc_p2
                  END,
              CASE 
                  WHEN LENGTH(ndc_p3) = 1
                      THEN '0' || ndc_p3
                  ELSE ndc_p3
                  END
              ) AS ndc_code
      FROM (
          SELECT concept_code,
              ndc_code_array [1] AS ndc_p1,
              ndc_code_array [2] AS ndc_p2,
              ndc_code_array [3] AS ndc_p3
          FROM (
              SELECT concept_code,
                  regexp_split_to_array(ndc_code, '-') AS ndc_code_array
              FROM (
                  SELECT DISTINCT TRIM(concept_code) AS concept_code,
                      TRIM(ndc_code) AS ndc_code
                  FROM (
                      SELECT (sources.py_xmlparse_spl_mappings(xmlfield)).*
                      FROM sources.spl_ext_raw
                      ) AS s0
                  ) AS s1
              ) AS s2
          ) AS s3
      WHERE LENGTH(ndc_p2) <= 4;
      
      --create table for SPL concepts from XML sources
      INSERT INTO sources.spl_ext
      SELECT TRANSLATE(concept_name, 'X' || CHR(9) || CHR(10) || CHR(13), 'X') concept_name,
          concept_code,
          valid_start_date,
          displayname,
          replaced_spl,
          low_value,
          high_value
      FROM (
          SELECT COALESCE(NULLIF(concept_name, ''), NULLIF(concept_name_clob, ''), '') || ' - ' || COALESCE(NULLIF(LOWER(kit), ''), NULLIF(concept_name_p2, ''), NULLIF(concept_name_clob_p2, ''), '') AS concept_name,
              concept_code,
              valid_start_date,
              displayname,
              NULLIF(replaced_spl, '') AS replaced_spl,
              NULLIF(low_value, '') AS low_value,
              NULLIF(high_value, '') AS high_value
          FROM (
              SELECT TRIM(UPPER(TRIM(concept_name_part)) || ' ' || UPPER(TRIM(concept_name_suffix))) AS concept_name,
                  TRIM(UPPER(TRIM(concept_name_clob_part)) || ' ' || UPPER(TRIM(concept_name_clob_suffix))) AS concept_name_clob,
                  TRIM(LOWER(TRIM(concept_name_part2)) || ' ' || LOWER(TRIM(formcode))) AS concept_name_p2,
                  TRIM(LOWER(TRIM(concept_name_clob_part2)) || ' ' || LOWER(TRIM(formcode_clob))) AS concept_name_clob_p2,
                  concept_code,
                  TO_DATE(SUBSTR(valid_start_date, 1, 6) || CASE 
                          WHEN SUBSTR(valid_start_date, LENGTH(valid_start_date) - 1, 2)::INT > 31
                              THEN '31'
                          ELSE SUBSTR(valid_start_date, LENGTH(valid_start_date) - 1, 2)
                          END, 'YYYYMMDD') AS valid_start_date,
                  UPPER(TRIM(regexp_replace(displayname, '[[:space:]]+', ' ', 'g'))) AS displayname,
                  replaced_spl,
                  kit,
                  low_value,
                  high_value
              FROM (
                  SELECT (sources.py_xmlparse_spl(xmlfield)).*
                  FROM sources.spl_ext_raw
                  ) AS s0
              ) AS s1
          ) AS s2;

      --delete duplicate records
      DELETE FROM sources.spl_ext s WHERE EXISTS (SELECT 1 FROM sources.spl_ext s_int WHERE s_int.concept_code = s.concept_code AND s_int.ctid > s.ctid);
      UPDATE sources.spl_ext s
      SET valid_start_date = i.vocabulary_date
      FROM (
          SELECT vocabulary_date
          FROM sources.product LIMIT 1
          ) i
      WHERE s.valid_start_date > i.vocabulary_date;
      
      ANALYZE sources.spl2ndc_mappings;
      ANALYZE sources.spl_ext;
      ANALYZE sources.product;
  when 'NDC' then
      RAISE EXCEPTION 'Use ''NDC_SPL'' instead of %', pVocabularyID;
  when 'SPL' then
      RAISE EXCEPTION 'Use ''NDC_SPL'' instead of %', pVocabularyID;
  when 'ICD10' then
      truncate table sources.icdclaml;
      ALTER TABLE sources.icdclaml ALTER COLUMN xmlfield SET DATA TYPE text;
      execute 'COPY sources.icdclaml (xmlfield) FROM PROGRAM ''cat "'||pVocabularyPath||'icdClaML.xml"| tr ''''\r\n'''' '''' ''''  '' csv delimiter E''\b'' quote E''\f'' ';
      update sources.icdclaml set xmlfield=replace(xmlfield,'<!DOCTYPE ClaML SYSTEM "ClaML.dtd">',''); --PG can not work with DOCTYPE
      ALTER TABLE sources.icdclaml ALTER COLUMN xmlfield SET DATA TYPE xml USING xmlfield::xml;
      update sources.icdclaml set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
  when 'LOINC' then
      truncate table sources.loinc, sources.map_to, sources.source_organization, sources.loinc_hierarchy, sources.loinc_documentontology;
      alter table sources.loinc DROP COLUMN IF EXISTS vocabulary_date;
      alter table sources.loinc DROP COLUMN IF EXISTS vocabulary_version;
      execute 'COPY sources.loinc FROM '''||pVocabularyPath||'loinc.csv'' delimiter '','' csv HEADER';
      alter table sources.loinc ADD COLUMN vocabulary_date date;
      alter table sources.loinc ADD COLUMN vocabulary_version VARCHAR (200);
      update sources.loinc set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      execute 'COPY sources.map_to FROM '''||pVocabularyPath||'map_to.csv'' delimiter '','' csv HEADER';
      execute 'COPY sources.source_organization FROM '''||pVocabularyPath||'source_organization.csv'' delimiter '','' csv HEADER';
      execute 'COPY sources.loinc_hierarchy FROM '''||pVocabularyPath||'LOINC_MULTI-AXIAL_HIERARCHY.CSV'' delimiter '','' csv HEADER';
      truncate table sources.loinc_answerslist, sources.loinc_answerslistlink, sources.loinc_forms;
      execute 'COPY sources.loinc_answerslist FROM '''||pVocabularyPath||'AnswerList.csv'' delimiter '','' csv HEADER';
      update sources.loinc_answerslist set displaytext=substr(displaytext,1,255) where length(displaytext)>255;
      execute 'COPY sources.loinc_answerslistlink FROM '''||pVocabularyPath||'LoincAnswerListLink.csv'' delimiter '','' csv HEADER';
      insert into sources.loinc_forms select * from sources.py_xlsparse_forms(pVocabularyPath||'/LOINC_PanelsAndForms.xlsx');
      truncate table sources.loinc_group, sources.loinc_parentgroupattributes, sources.loinc_grouploincterms;
      execute 'COPY sources.loinc_group FROM '''||pVocabularyPath||'Group.csv'' delimiter '','' csv HEADER FORCE NULL parentgroupid,groupid,lgroup,archetype,status,versionfirstreleased';
      execute 'COPY sources.loinc_parentgroupattributes FROM '''||pVocabularyPath||'ParentGroupAttributes.csv'' delimiter '','' csv HEADER FORCE NULL parentgroupid,ltype,lvalue';
      execute 'COPY sources.loinc_grouploincterms FROM '''||pVocabularyPath||'GroupLoincTerms.csv'' delimiter '','' csv HEADER FORCE NULL category,groupid,archetype,loincnumber,longcommonname';
      truncate table sources.loinc_class, sources.scccrefset_mapcorrorfull_int, sources.cpt_mrsmap;
      set local datestyle='ISO, DMY'; --set proper date format
      execute 'COPY sources.loinc_class FROM '''||pVocabularyPath||'loinc_class.csv'' delimiter ''|'' csv HEADER';
      execute 'COPY sources.scccrefset_mapcorrorfull_int FROM '''||pVocabularyPath||'xder2_sscccRefset_LOINCExpressionAssociationFull_INT.txt'' delimiter E''\t'' csv HEADER';
      execute 'COPY sources.cpt_mrsmap FROM '''||pVocabularyPath||'CPT_MRSMAP.RRF'' delimiter ''|'' csv';
      execute 'COPY sources.loinc_documentontology FROM '''||pVocabularyPath||'DocumentOntology.csv'' delimiter '','' csv HEADER';
  when 'HCPCS' then
      truncate table sources.anweb_v2;
      insert into sources.anweb_v2 
        select trim(HCPC),long_description,short_description,xref1,xref2,xref3,xref4,xref5,betos,
        TO_DATE(add_date,'YYYYMMDD'),TO_DATE(act_eff_dt,'YYYYMMDD'),TO_DATE(term_dt ,'YYYYMMDD'),
        COALESCE(pVocabularyDate,current_date),COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date) 
        from sources.py_xlsparse_hcpcs(pVocabularyPath||'/HCPC_CONTR_ANWEB.xlsx') where add_date ~ '\d{6}';
  when 'SNOMED' then
      truncate table sources.sct2_concept_full_merged, sources.sct2_desc_full_merged, sources.sct2_rela_full_merged;
      drop index sources.idx_concept_merged_id;
      drop index sources.idx_desc_merged_id;
      drop index sources.idx_rela_merged_id;
      --loading sct2_concept_full_merged
      execute 'COPY sources.sct2_concept_full_merged (id,effectivetime,active,moduleid,statusid) FROM '''||pVocabularyPath||'sct2_Concept_Full_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.sct2_concept_full_merged (id,effectivetime,active,moduleid,statusid) FROM '''||pVocabularyPath||'sct2_Concept_Full-UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.sct2_concept_full_merged (id,effectivetime,active,moduleid,statusid) FROM '''||pVocabularyPath||'sct2_Concept_Full_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.sct2_concept_full_merged (id,effectivetime,active,moduleid,statusid) FROM '''||pVocabularyPath||'sct2_Concept_Full_GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      update sources.sct2_concept_full_merged set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      --delete duplicate records
      DELETE FROM sources.sct2_concept_full_merged s WHERE EXISTS (SELECT 1 FROM sources.sct2_concept_full_merged s_int 
      	WHERE s_int.id = s.id AND s_int.effectivetime=s.effectivetime
        AND s_int.active = s.active AND s_int.moduleid=s.moduleid
        AND s_int.statusid=s.statusid AND s_int.ctid > s.ctid);
      --loading sct2_desc_full_merged
      execute 'COPY sources.sct2_desc_full_merged FROM '''||pVocabularyPath||'sct2_Description_Full-en_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.sct2_desc_full_merged FROM '''||pVocabularyPath||'sct2_Description_Full-UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.sct2_desc_full_merged FROM '''||pVocabularyPath||'sct2_Description_Full-en_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.sct2_desc_full_merged FROM '''||pVocabularyPath||'sct2_Description_Full-en-GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      --delete duplicate records
      DELETE FROM sources.sct2_desc_full_merged s WHERE EXISTS (SELECT 1 FROM sources.sct2_desc_full_merged s_int 
      	WHERE s_int.id = s.id AND s_int.effectivetime=s.effectivetime
        AND s_int.active = s.active AND s_int.moduleid=s.moduleid
        AND s_int.conceptid=s.conceptid AND s_int.languagecode=s.languagecode
        AND s_int.typeid = s.typeid AND s_int.term=s.term
        AND s_int.casesignificanceid = s.casesignificanceid AND s_int.ctid > s.ctid);
      --loading sct2_rela_full_merged
      execute 'COPY sources.sct2_rela_full_merged FROM '''||pVocabularyPath||'sct2_Relationship_Full_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.sct2_rela_full_merged FROM '''||pVocabularyPath||'sct2_Relationship_Full-UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.sct2_rela_full_merged FROM '''||pVocabularyPath||'sct2_Relationship_Full_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.sct2_rela_full_merged FROM '''||pVocabularyPath||'sct2_Relationship_Full_GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      --delete duplicate records
      DELETE FROM sources.sct2_rela_full_merged s WHERE EXISTS (SELECT 1 FROM sources.sct2_rela_full_merged s_int 
      	WHERE s_int.id = s.id AND s_int.effectivetime=s.effectivetime
        AND s_int.active = s.active AND s_int.moduleid=s.moduleid
        AND s_int.sourceid=s.sourceid AND s_int.destinationid=s.destinationid
        AND s_int.relationshipgroup = s.relationshipgroup AND s_int.typeid=s.typeid
        AND s_int.characteristictypeid = s.characteristictypeid AND s_int.modifierid=s.modifierid
        AND s_int.ctid > s.ctid);
      --loading der2_crefset_assreffull_merged
      execute 'COPY sources.der2_crefset_assreffull_merged FROM '''||pVocabularyPath||'der2_cRefset_AssociationFull_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.der2_crefset_assreffull_merged FROM '''||pVocabularyPath||'der2_cRefset_AssociationFull_UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.der2_crefset_assreffull_merged FROM '''||pVocabularyPath||'der2_cRefset_AssociationFull_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.der2_crefset_assreffull_merged FROM '''||pVocabularyPath||'der2_cRefset_AssociationFull_GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      --delete duplicate records
      DELETE FROM sources.der2_crefset_assreffull_merged s WHERE EXISTS (SELECT 1 FROM sources.der2_crefset_assreffull_merged s_int 
      	WHERE s_int.id = s.id AND s_int.effectivetime=s.effectivetime
        AND s_int.active = s.active AND s_int.moduleid=s.moduleid
        AND s_int.refsetid=s.refsetid AND s_int.referencedcomponentid=s.referencedcomponentid
        AND s_int.targetcomponent = s.targetcomponent AND s_int.ctid > s.ctid);
	  CREATE INDEX idx_concept_merged_id ON sources.sct2_concept_full_merged (id);
      CREATE INDEX idx_desc_merged_id ON sources.sct2_desc_full_merged (conceptid);
      CREATE INDEX idx_rela_merged_id ON sources.sct2_rela_full_merged (id);
      analyze sources.sct2_concept_full_merged;
      analyze sources.sct2_desc_full_merged;
      analyze sources.sct2_rela_full_merged;
      --load XML sources
      truncate table sources.f_lookup2, sources.f_ingredient2, sources.f_vtm2, sources.f_vmp2, sources.f_vmpp2, sources.f_amp2, sources.f_ampp2, sources.dmdbonus;
      execute 'COPY sources.f_lookup2 FROM '''||pVocabularyPath||'f_lookup2.xml'' delimiter E''\b''';
      execute 'COPY sources.f_ingredient2 FROM '''||pVocabularyPath||'f_ingredient2.xml'' delimiter E''\b''';
      execute 'COPY sources.f_vtm2 FROM '''||pVocabularyPath||'f_vtm2.xml'' delimiter E''\b''';
      execute 'COPY sources.f_vmp2 FROM '''||pVocabularyPath||'f_vmp2.xml'' delimiter E''\b''';
      execute 'COPY sources.f_vmpp2 FROM '''||pVocabularyPath||'f_vmpp2.xml'' delimiter E''\b''';
      execute 'COPY sources.f_amp2 FROM '''||pVocabularyPath||'f_amp2.xml'' delimiter E''\b''';
      execute 'COPY sources.f_ampp2 FROM '''||pVocabularyPath||'f_ampp2.xml'' delimiter E''\b''';
      execute 'COPY sources.dmdbonus FROM '''||pVocabularyPath||'dmdbonus.xml'' delimiter E''\b''';
  when 'ICD10CM' then
      truncate table sources.icd10cm_temp, sources.icd10cm;
      execute 'COPY sources.icd10cm_temp FROM '''||pVocabularyPath||'icd10cm.txt'' delimiter E''\b''';
      insert into sources.icd10cm select trim(substring (icd10cm_codes_and_desc from 7 for 7)), substring (icd10cm_codes_and_desc from 15 for 1)::INT4,
      	trim(substring (icd10cm_codes_and_desc from 17 for 60)), trim(substring (icd10cm_codes_and_desc from 78)),
        COALESCE(pVocabularyDate,current_date), COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date) From  sources.icd10cm_temp;
      analyze sources.icd10cm;
  when 'CVX' then
      if pVocabularyDate is null then 
      	RAISE EXCEPTION 'For current vocabulary (%) you must set the pVocabularyDate!', pVocabularyID;
      end if;
      truncate table sources.cvx;
      insert into sources.cvx select CVX_CODE,TRIM(SHORT_DESCRIPTION),TRIM(FULL_VACCINE_NAME),LAST_UPDATED_DATE, pVocabularyDate, COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date) from 
      	sources.py_xlsparse_cvx_codes(pVocabularyPath||'/web_cvx.xlsx');
      --upsert (inserts new codes and updates existing codes to minimum date)
      INSERT INTO sources.cvx_dates AS c
      SELECT cvx_code, pVocabularyDate
      FROM sources.py_xlsparse_cvx_dates(pVocabularyPath||'/ValueSetConceptDetailResultSummary.xls') 
      ON CONFLICT(cvx_code) 
      DO UPDATE
      SET concept_date = (
              SELECT LEAST(concept_date, excluded.concept_date)
              FROM sources.cvx_dates
              WHERE cvx_code = excluded.cvx_code
              )
      WHERE c.cvx_code = excluded.cvx_code;
  when 'DPD' then
      truncate table sources.dpd_drug_all, sources.dpd_active_ingredients_all, sources.dpd_form_all, sources.dpd_route_all, 
      	sources.dpd_packaging_all, sources.dpd_status_all, sources.dpd_companies_all, sources.dpd_therapeutic_class_all;
      --drug, drug_ia, drug_ap
      execute 'COPY sources.dpd_drug_all FROM '''||pVocabularyPath||'drug_ia.txt'' delimiter '','' csv FORCE NULL
      	product_categorization,class,drug_identification_number,brand_name,descriptor,pediatric_flag,accession_number,number_of_ais,last_update_date,ai_group_no';
      update sources.dpd_drug_all set filler_column1='marked_for_drug_ia'; --we need to mark data from this source (drug_ia) for later use in load_stage
      execute 'COPY sources.dpd_drug_all FROM '''||pVocabularyPath||'drug.txt'' delimiter '','' csv FORCE NULL
      	product_categorization,class,drug_identification_number,brand_name,descriptor,pediatric_flag,accession_number,number_of_ais,last_update_date,ai_group_no';
      execute 'COPY sources.dpd_drug_all FROM '''||pVocabularyPath||'drug_ap.txt'' delimiter '','' csv FORCE NULL
      	product_categorization,class,drug_identification_number,brand_name,descriptor,pediatric_flag,accession_number,number_of_ais,last_update_date,ai_group_no';
      --ingred, ingred_ia, ingred_ap
      execute 'COPY sources.dpd_active_ingredients_all FROM '''||pVocabularyPath||'ingred.txt'' delimiter '','' csv FORCE NULL 
      	active_ingredient_code,ingredient,ingredient_supplied_ind,strength,strength_unit,strength_type,dosage_value,base,dosage_unit,notes';
      execute 'COPY sources.dpd_active_ingredients_all FROM '''||pVocabularyPath||'ingred_ia.txt'' delimiter '','' csv FORCE NULL 
      	active_ingredient_code,ingredient,ingredient_supplied_ind,strength,strength_unit,strength_type,dosage_value,base,dosage_unit,notes';
      execute 'COPY sources.dpd_active_ingredients_all FROM '''||pVocabularyPath||'ingred_ap.txt'' delimiter '','' csv FORCE NULL 
      	active_ingredient_code,ingredient,ingredient_supplied_ind,strength,strength_unit,strength_type,dosage_value,base,dosage_unit,notes';
      --form, form_ia, form_ap
      execute 'COPY sources.dpd_form_all (drug_code,pharm_form_code,pharmaceutical_form,filler_column1) FROM '''||pVocabularyPath||'form.txt'' delimiter '','' csv FORCE NULL pharm_form_code,pharmaceutical_form';
      execute 'COPY sources.dpd_form_all (drug_code,pharm_form_code,pharmaceutical_form,filler_column1) FROM '''||pVocabularyPath||'form_ia.txt'' delimiter '','' csv FORCE NULL pharm_form_code,pharmaceutical_form';
      execute 'COPY sources.dpd_form_all (drug_code,pharm_form_code,pharmaceutical_form,filler_column1) FROM '''||pVocabularyPath||'form_ap.txt'' delimiter '','' csv FORCE NULL pharm_form_code,pharmaceutical_form';
      update sources.dpd_form_all set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      --route, route_ia, route_ap
      execute 'COPY sources.dpd_route_all FROM '''||pVocabularyPath||'route.txt'' delimiter '','' csv FORCE NULL drug_code,route_of_administration_code,route_of_administration';
      execute 'COPY sources.dpd_route_all FROM '''||pVocabularyPath||'route_ia.txt'' delimiter '','' csv FORCE NULL drug_code,route_of_administration_code,route_of_administration';
      execute 'COPY sources.dpd_route_all FROM '''||pVocabularyPath||'route_ap.txt'' delimiter '','' csv FORCE NULL drug_code,route_of_administration_code,route_of_administration';
      --package, package_ia, package_ap
      execute 'COPY sources.dpd_packaging_all FROM '''||pVocabularyPath||'package.txt'' delimiter '','' csv ENCODING ''ISO-8859-1'' FORCE NULL upc,package_size_unit,package_type,package_size,product_information';
      execute 'COPY sources.dpd_packaging_all FROM '''||pVocabularyPath||'package_ia.txt'' delimiter '','' csv ENCODING ''ISO-8859-1'' FORCE NULL upc,package_size_unit,package_type,package_size,product_information';
      execute 'COPY sources.dpd_packaging_all FROM '''||pVocabularyPath||'package_ap.txt'' delimiter '','' csv ENCODING ''ISO-8859-1'' FORCE NULL upc,package_size_unit,package_type,package_size,product_information';
      --status, status_ia, status_ap
      execute 'COPY sources.dpd_status_all FROM '''||pVocabularyPath||'status.txt'' delimiter '','' csv FORCE NULL drug_code,current_status_flag,status,history_date';
      execute 'COPY sources.dpd_status_all FROM '''||pVocabularyPath||'status_ia.txt'' delimiter '','' csv FORCE NULL drug_code,current_status_flag,status,history_date';
      execute 'COPY sources.dpd_status_all FROM '''||pVocabularyPath||'status_ap.txt'' delimiter '','' csv FORCE NULL drug_code,current_status_flag,status,history_date';
      --comp, comp_ia, comp_ap
      execute 'COPY sources.dpd_companies_all FROM '''||pVocabularyPath||'comp.txt'' delimiter '','' csv FORCE NULL mfr_code,company_code,company_name,company_type,
      	address_mailing_flag,address_billing_flag,address_notification_flag,address_other,suite_number,street_name,city_name,province,country,postal_code,post_office_box';
      execute 'COPY sources.dpd_companies_all FROM '''||pVocabularyPath||'comp_ia.txt'' delimiter '','' csv FORCE NULL mfr_code,company_code,company_name,company_type,
      	address_mailing_flag,address_billing_flag,address_notification_flag,address_other,suite_number,street_name,city_name,province,country,postal_code,post_office_box';
      execute 'COPY sources.dpd_companies_all FROM '''||pVocabularyPath||'comp_ap.txt'' delimiter '','' csv FORCE NULL mfr_code,company_code,company_name,company_type,
      	address_mailing_flag,address_billing_flag,address_notification_flag,address_other,suite_number,street_name,city_name,province,country,postal_code,post_office_box';
      --ther, ther_ia, ther_ap
      execute 'COPY sources.dpd_therapeutic_class_all FROM '''||pVocabularyPath||'ther.txt'' delimiter '','' csv ENCODING ''ISO-8859-1'' FORCE NULL tc_atc_number,tc_atc,tc_ahfs_number,tc_ahfs';
      execute 'COPY sources.dpd_therapeutic_class_all FROM '''||pVocabularyPath||'ther_ia.txt'' delimiter '','' csv ENCODING ''ISO-8859-1'' FORCE NULL tc_atc_number,tc_atc,tc_ahfs_number,tc_ahfs';
      execute 'COPY sources.dpd_therapeutic_class_all FROM '''||pVocabularyPath||'ther_ap.txt'' delimiter '','' csv ENCODING ''ISO-8859-1'' FORCE NULL tc_atc_number,tc_atc,tc_ahfs_number,tc_ahfs';
  when 'GGR' then
      truncate table sources.ggr_gal, sources.ggr_innm, sources.ggr_ir, sources.ggr_mp, sources.ggr_mpp, sources.ggr_sam;
      execute 'COPY sources.ggr_gal FROM '''||pVocabularyPath||'Gal.csv'' delimiter '';'' csv HEADER';
      execute 'COPY sources.ggr_innm FROM '''||pVocabularyPath||'Stof.csv'' delimiter '';'' csv HEADER';
      execute 'COPY sources.ggr_ir (ircv,nirnm,firnm,pip,amb,hosp) FROM '''||pVocabularyPath||'Ir.csv'' delimiter '';'' csv HEADER';
      execute 'COPY sources.ggr_mp FROM '''||pVocabularyPath||'MP.csv'' delimiter '';'' csv HEADER';
      execute 'COPY sources.ggr_mpp FROM '''||pVocabularyPath||'MPP.csv'' delimiter '';'' csv HEADER';
      execute 'COPY sources.ggr_sam FROM '''||pVocabularyPath||'Sam.csv'' delimiter '';'' csv HEADER';
      update sources.ggr_ir set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      analyze sources.ggr_gal;
      analyze sources.ggr_innm;
      analyze sources.ggr_ir;
      analyze sources.ggr_mp;
      analyze sources.ggr_mpp;
      analyze sources.ggr_sam;
  when 'AMT' then
      truncate table sources.amt_full_descr_drug_only, sources.amt_sct2_concept_full_au, sources.amt_rf2_full_relationships, sources.amt_rf2_ss_strength_refset,
      	sources.amt_sct2_rela_full_au;
      drop index sources.idx_amt_concept_id;
      drop index sources.idx_amt_descr_id;
      drop index sources.idx_amt_rela_id;
      drop index sources.idx_amt_rela2_id;
      execute 'COPY sources.amt_full_descr_drug_only FROM '''||pVocabularyPath||'sct2_Description_Full-en-AU_AU.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.amt_sct2_concept_full_au (id,effectivetime,active,moduleid,statusid) FROM '''||pVocabularyPath||'sct2_Concept_Full_AU.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.amt_rf2_full_relationships FROM '''||pVocabularyPath||'sct2_Relationship_Full_AU.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.amt_rf2_ss_strength_refset FROM '''||pVocabularyPath||'der2_ccsRefset_StrengthFull_AU.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      --execute 'COPY sources.amt_sct2_rela_full_au FROM '''||pVocabularyPath||'sct2_Relationship_Full_AU36.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      update sources.amt_sct2_concept_full_au set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      
      create index idx_amt_concept_id on sources.amt_sct2_concept_full_au (id);
      create index idx_amt_descr_id on sources.amt_full_descr_drug_only (conceptid);
      create index idx_amt_rela_id on sources.amt_rf2_full_relationships (id);
      create index idx_amt_rela2_id on sources.amt_sct2_rela_full_au (id);
      
      analyze sources.amt_full_descr_drug_only;
      analyze sources.amt_sct2_concept_full_au;
      analyze sources.amt_rf2_full_relationships;
      analyze sources.amt_rf2_ss_strength_refset;
      analyze sources.amt_sct2_rela_full_au;
  when 'ISBT' then
      truncate table sources.isbt_product_desc, sources.isbt_classes, sources.isbt_modifiers, sources.isbt_attribute_values, sources.isbt_attribute_groups, 
      	sources.isbt_categories, sources.isbt_modifier_category_map, sources.isbt_version;
      execute 'COPY sources.isbt_product_desc FROM PROGRAM ''mdb-export -H "'||pVocabularyPath||'isbt.accdb" "Product Description Codes"'' delimiter '','' csv';
      execute 'COPY sources.isbt_classes FROM PROGRAM ''mdb-export -H "'||pVocabularyPath||'isbt.accdb" "Classes"'' delimiter '','' csv';
      execute 'COPY sources.isbt_modifiers FROM PROGRAM ''mdb-export -H "'||pVocabularyPath||'isbt.accdb" "Modifiers"'' delimiter '','' csv';
      execute 'COPY sources.isbt_attribute_values FROM PROGRAM ''mdb-export -H "'||pVocabularyPath||'isbt.accdb" "Attribute values"'' delimiter '','' csv';
      execute 'COPY sources.isbt_attribute_groups FROM PROGRAM ''mdb-export -H "'||pVocabularyPath||'isbt.accdb" "Attribute groups"'' delimiter '','' csv';
      execute 'COPY sources.isbt_categories FROM PROGRAM ''mdb-export -H "'||pVocabularyPath||'isbt.accdb" "Categories"'' delimiter '','' csv';
      execute 'COPY sources.isbt_modifier_category_map FROM PROGRAM ''mdb-export -H "'||pVocabularyPath||'isbt.accdb" "Modifier Category Map"'' delimiter '','' csv';
      execute 'COPY sources.isbt_version FROM PROGRAM ''mdb-export -H "'||pVocabularyPath||'isbt.accdb" "Version"'' delimiter '','' csv';
  when 'ISBT ATTRIBUTE' then
      RAISE EXCEPTION 'Use ''ISBT'' instead of %', pVocabularyID;
  when 'AMIS' then
      truncate table sources.amis_source_table;
      insert into sources.amis_source_table select * from sources.py_xlsparse_amis(pVocabularyPath||'/AM-Liste.xlsx');
  when 'DA_AUSTRALIA' then
      truncate table sources.aus_fo_product, sources.aus_drug_mapping, sources.aus_fo_product_p2, sources.aus_drug_mapping_p2, sources.aus_drug_mapping_3, 
      	sources.aus_fo_product_3;
      execute 'COPY sources.aus_fo_product FROM '''||pVocabularyPath||'fo_product.csv'' delimiter '','' csv quote ''"'' HEADER';
      execute 'COPY sources.aus_drug_mapping FROM '''||pVocabularyPath||'drug_mapping.csv'' delimiter '','' csv quote ''"'' HEADER';
      execute 'COPY sources.aus_fo_product_p2 FROM '''||pVocabularyPath||'fo_product_p2.csv'' delimiter '','' csv quote ''"'' HEADER';
      execute 'COPY sources.aus_drug_mapping_p2 FROM '''||pVocabularyPath||'drug_mapping_p2.csv'' delimiter '','' csv quote ''"'' HEADER';
      execute 'COPY sources.aus_drug_mapping_3 FROM '''||pVocabularyPath||'drug_mapping_3.csv'' delimiter '';'' csv quote ''"'' HEADER';
      execute 'COPY sources.aus_fo_product_3 FROM '''||pVocabularyPath||'fo_product_3.csv'' delimiter '';'' csv quote ''"'' HEADER';
  when 'BDPM' then
      set local datestyle='ISO, DMY'; --set proper date format
      truncate table sources.bdpm_drug, sources.bdpm_ingredient, sources.bdpm_packaging;
      execute 'COPY sources.bdpm_drug (drug_code,drug_descr,form,route,status,certifier,market_status,approval_date,inactive_flag,eu_number,manufacturer,surveillance_flag) FROM '''||pVocabularyPath||'CIS_bdpm.txt'' delimiter E''\t'' csv quote E''\b'' ENCODING ''ISO-8859-1''';
      execute 'COPY sources.bdpm_ingredient FROM '''||pVocabularyPath||'CIS_COMPO_bdpm.txt'' delimiter E''\t'' csv quote E''\b'' ENCODING ''ISO-8859-1''';
      execute 'COPY sources.bdpm_packaging FROM '''||pVocabularyPath||'CIS_CIP_bdpm.txt'' delimiter E''\t'' csv quote E''\b'' ENCODING ''ISO-8859-1''';
      execute 'COPY sources.bdpm_gener FROM '''||pVocabularyPath||'CIS_GENER_bdpm.txt'' delimiter E''\t'' csv quote E''\b'' ENCODING ''ISO-8859-1''';
      update sources.bdpm_drug set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      --mistakes in the orinal table fixing
      UPDATE sources.bdpm_ingredient
      SET volume = '100 ml'
      WHERE drug_code = '64482812'
          AND form_code = '03691'
          AND volume = '00 ml';

      UPDATE sources.bdpm_ingredient
      SET dosage = '0,05000 g'
      WHERE dosage = '0, 05000';
  when 'ICDO3' THEN
      drop index sources.idx_icdo3_mrconso;
      truncate table sources.icdo3_mrconso;
      execute 'COPY sources.icdo3_mrconso (cui,lat,ts,lui,stt,sui,ispref,aui,saui,scui,sdui,sab,tty,code,str,srl,suppress,cvf,vocabulary_date) FROM '''||pVocabularyPath||'MRCONSO.RRF'' delimiter ''|'' csv quote E''\b''';
      update sources.icdo3_mrconso set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      CREATE INDEX idx_icdo3_mrconso ON sources.icdo3_mrconso (SAB,TTY);
      analyze sources.icdo3_mrconso;
  when 'CDM' THEN
      if pVocabularyVersion is null then
      	RAISE EXCEPTION 'For current vocabulary (%) you must set the pVocabularyVersion! Format (json): {''version'':''CDM vX.Y.Z'', ''published_at'':''A'',''node_id'':''B''}', pVocabularyID;
      end if;
      
      if not (pVocabularyVersion::json->>'version') ~* '^CDM v\d+\.\d+\.\d+$' then
      	RAISE EXCEPTION 'For current vocabulary (%) you must set the proper CDM format!', pVocabularyID;
      end if;
      
      truncate table sources.cdm_raw_table;
      --we need to replace all carriage returns with chr(0) due to loading the entire file
      execute 'COPY sources.cdm_raw_table (ddl_text) FROM PROGRAM ''cat "'||pVocabularyPath||'OMOP CDM postgresql ddl.txt" "'||pVocabularyPath||'OMOP CDM Results postgresql ddl.txt" | tr ''''\r\n'''' '''''||chr(1)||'''''  '' csv delimiter E''\b'' quote E''\f'' ';
      --return the carriage returns back and comment all 'ALTER TABLE' clauses
      update sources.cdm_raw_table set ddl_text=regexp_replace(replace(ddl_text,chr(1),E'\r\n'),'ALTER TABLE','--ALTER TABLE','gi'),
      	ddl_date=(pVocabularyVersion::json->>'published_at')::timestamp, ddl_release_id=(pVocabularyVersion::json->>'node_id'), 
        vocabulary_date=(pVocabularyVersion::json->>'published_at')::date, vocabulary_version=(pVocabularyVersion::json->>'version');
      update sources.cdm_raw_table set ddl_text=regexp_replace(ddl_text,'datetime2','timestamp','gi') where ddl_release_id='MDc6UmVsZWFzZTExNDY1Njg5';--fix DDL bug in CDM v5.3.1
      insert into sources.cdm_tables
        select p.*,r.ddl_date, r.ddl_release_id,r.vocabulary_date, r.vocabulary_version
        from sources.cdm_raw_table r
        cross join vocabulary_pack.ParseTables (r.ddl_text) p
        where not exists (select 1 from sources.cdm_tables c where c.ddl_release_id=r.ddl_release_id);
      analyze sources.cdm_tables;
  else
      RAISE EXCEPTION 'Vocabulary with id=% not found', pVocabularyID;
  end case;        
end;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY DEFINER
COST 100;