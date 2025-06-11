CREATE OR REPLACE FUNCTION sources.load_input_tables (
  pvocabularyid text,
  pvocabularydate date = NULL::date,
  pvocabularyversion text = NULL::text
)
RETURNS void AS
$body$
declare
/*****
pVocabularyPath varchar (1000) := (SELECT var_value FROM devv5.config$ WHERE var_name='vocabulary_load_path');

 Hard coded path when testing. Where is devv5.config$, var_value and how to set devv5.config? I suspect is a 
session variable or from config. 
*****/
 pVocabularyPath varchar (1000) := 'C:/Users/Administrator/Downloads/';

  z varchar(100);
begin
  pVocabularyID=UPPER(pVocabularyID);
  pVocabularyPath=pVocabularyPath||pVocabularyID||'/';
  case pVocabularyID
  when 'UMLS' THEN
      truncate table sources.mrconso, sources.mrhier, sources.mrmap, sources.mrsmap, sources.mrsat, sources.mrrel, sources.mrsty;
      drop index sources.x_mrconso_aui;
      drop index sources.x_mrsat_cui;
      drop index sources.x_mrconso_code;
      drop index sources.x_mrconso_cui;
      drop index sources.x_mrconso_sab_tty;
      drop index sources.x_mrconso_scui;
      drop index sources.x_mrsty_cui;
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
      execute 'COPY sources.mrsty FROM '''||pVocabularyPath||'MRSTY.RRF'' delimiter ''|'' csv quote E''\b''';
      update sources.mrsmap set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
            
      CREATE INDEX x_mrsat_cui ON sources.mrsat (cui);
      CREATE INDEX x_mrconso_code ON sources.mrconso (code);
      CREATE INDEX x_mrconso_cui ON sources.mrconso (cui);
      CREATE INDEX x_mrconso_aui ON sources.mrconso (aui);
      CREATE INDEX x_mrconso_sab_tty ON sources.mrconso (sab, tty);
      CREATE INDEX x_mrconso_scui ON sources.mrconso (scui);
      CREATE INDEX x_mrsty_cui ON sources.mrsty (cui);
      analyze sources.mrconso;
      analyze sources.mrhier;
      analyze sources.mrmap;
      analyze sources.mrsmap;
      analyze sources.mrsat;
      analyze sources.mrrel;
      analyze sources.mrsty;
      PERFORM sources_archive.AddVocabularyToArchive('UMLS', ARRAY['mrconso','mrhier','mrmap','mrsmap','mrsat','mrrel','mrsty'], COALESCE(pVocabularyDate,current_date), 'archive.umls_version', 5);
  when 'CIEL' then
      --set local datestyle='ISO, DMY'; --set proper date format
      truncate table sources.ciel_concept, sources.ciel_concept_class, sources.ciel_concept_name, sources.ciel_concept_reference_map, sources.ciel_concept_reference_term, sources.ciel_concept_reference_source;
      execute 'COPY sources.ciel_concept FROM '''||pVocabularyPath||'CONCEPT_CIEL.csv'' delimiter E''\t'' csv NULL ''\N''';
      execute 'COPY sources.ciel_concept_class (concept_class_id,ciel_name,description,creator,date_created,
      	retired,retired_by,date_retired,retire_reason,uuid,date_changed,changed_by) FROM '''||pVocabularyPath||'CONCEPT_CLASS_CIEL.csv'' delimiter E''\t'' csv NULL ''\N''';
      execute 'COPY sources.ciel_concept_name FROM '''||pVocabularyPath||'CONCEPT_NAME.csv'' delimiter E''\t'' csv NULL ''\N''';
      execute 'COPY sources.ciel_concept_reference_map FROM '''||pVocabularyPath||'CONCEPT_REFERENCE_MAP.csv'' delimiter E''\t'' csv NULL ''\N''';
      execute 'COPY sources.ciel_concept_reference_term FROM '''||pVocabularyPath||'CONCEPT_REFERENCE_TERM.csv'' delimiter E''\t'' csv NULL ''\N''';
      execute 'COPY sources.ciel_concept_reference_source FROM '''||pVocabularyPath||'CONCEPT_REFERENCE_SOURCE.csv'' delimiter E''\t'' csv NULL ''\N''';
      update sources.ciel_concept_class set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      --force NULL for empty fields
      update sources.ciel_concept_class set ciel_name=nullif(trim(ciel_name),'');
      update sources.ciel_concept_name set ciel_name=nullif(trim(ciel_name),''),locale=nullif(trim(locale),'');
      update sources.ciel_concept_reference_term set ciel_name=nullif(trim(ciel_name),''),ciel_code=nullif(trim(ciel_code),'');
      update sources.ciel_concept_reference_source set ciel_name=nullif(trim(ciel_name),'');
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
      PERFORM sources_archive.AddVocabularyToArchive('RxNorm', ARRAY['rxnatomarchive','rxnconso','rxnrel','rxnsat'], COALESCE(pVocabularyDate,current_date), 'archive.rxnorm_version', 10);
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
      PERFORM sources_archive.AddVocabularyToArchive('OPCS4', ARRAY['opcs','opcssctmap'], COALESCE(pVocabularyDate,current_date), 'archive.opcs4_version', 10);
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
      	sources.md_hierarchy, sources.pref_term, sources.soc_term, sources.soc_hlgt_comp, sources.meddra_mapsto_snomed, sources.meddra_mappedfrom_snomed, sources.meddra_mappedfrom_icd10;
      execute 'COPY sources.hlgt_pref_term FROM '''||pVocabularyPath||'hlgt.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.hlgt_hlt_comp FROM '''||pVocabularyPath||'hlgt_hlt.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.hlt_pref_term FROM '''||pVocabularyPath||'hlt.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.hlt_pref_comp (hlt_code,pt_code,filler_column) FROM '''||pVocabularyPath||'hlt_pt.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.low_level_term FROM '''||pVocabularyPath||'llt.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.md_hierarchy FROM '''||pVocabularyPath||'mdhier.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.pref_term FROM '''||pVocabularyPath||'pt.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.soc_term FROM '''||pVocabularyPath||'soc.asc'' delimiter ''$'' csv quote E''\b''';
      execute 'COPY sources.soc_hlgt_comp FROM '''||pVocabularyPath||'soc_hlgt.asc'' delimiter ''$'' csv quote E''\b''';
      insert into sources.meddra_mapsto_snomed select * from sources.py_xlsparse_meddra_snomed(pVocabularyPath||'/meddra_mappings.xlsx',0);
      insert into sources.meddra_mappedfrom_snomed select * from sources.py_xlsparse_meddra_snomed(pVocabularyPath||'/meddra_mappings.xlsx',1);
      insert into sources.meddra_mappedfrom_icd10 select * from sources.py_xlsparse_meddra_icd10(pVocabularyPath||'/meddra_mappings_icd10.xlsx',0);
      update sources.hlt_pref_comp set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      PERFORM sources_archive.AddVocabularyToArchive('MedDRA', ARRAY['hlgt_pref_term','hlgt_hlt_comp','hlt_pref_term','hlt_pref_comp','low_level_term',
        'md_hierarchy','pref_term','soc_term','soc_hlgt_comp','meddra_mapsto_snomed','meddra_mappedfrom_snomed','meddra_mappedfrom_icd10'], COALESCE(pVocabularyDate,current_date), 'archive.meddra_version', 10);
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
      PERFORM sources_archive.AddVocabularyToArchive('ICD10PCS', ARRAY['icd10pcs'], COALESCE(pVocabularyDate,current_date), 'archive.icd10pcs_version', 10);
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
          NULLIF(CONCAT (
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
              ), '') AS ndc_code,
          low_value,
          high_value,
          is_diluent
      FROM (
          SELECT COALESCE(NULLIF(concept_name, ''), NULLIF(concept_name_clob, ''), '') || ' - ' || COALESCE(NULLIF(LOWER(kit), ''), NULLIF(concept_name_p2, ''), NULLIF(concept_name_clob_p2, ''), '') AS concept_name,
              concept_code,
              valid_start_date,
              displayname,
              NULLIF(replaced_spl, '') AS replaced_spl,
              ndc_code_array [1] AS ndc_p1,
              ndc_code_array [2] AS ndc_p2,
              ndc_code_array [3] AS ndc_p3,
              NULLIF(low_value, '') AS low_value,
              NULLIF(high_value, '') AS high_value,
              CASE WHEN ndc_root_name LIKE '%DILUENT%' AND ndc_code <> '' THEN TRUE ELSE FALSE END AS is_diluent
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
                  regexp_split_to_array(ndc_code, '-') AS ndc_code_array,
                  low_value,
                  high_value,
                  ndc_code,
                  UPPER(ndc_root_name) AS ndc_root_name
              FROM (
                  SELECT (sources.py_xmlparse_spl(xmlfield)).*
                  FROM sources.spl_ext_raw
                  ) AS s0
              ) AS s1
          ) AS s2;

      --delete duplicate records
      --DELETE FROM sources.spl_ext s WHERE EXISTS (SELECT 1 FROM sources.spl_ext s_int WHERE s_int.concept_code = s.concept_code AND s_int.ctid > s.ctid);
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
      PERFORM sources_archive.AddVocabularyToArchive('NDC', ARRAY['product','package','spl2rxnorm_mappings','spl2ndc_mappings','spl_ext'], COALESCE(pVocabularyDate,current_date), 'archive.ndc_version', 30);
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
      execute 'COPY sources.loinc FROM '''||pVocabularyPath||'loinc.csv'' delimiter '','' csv HEADER FORCE NULL loinc_num, component, property, time_aspct, system, scale_typ, method_typ, class, versionlastchanged, 
         chng_type, definitiondescription, status, consumer_name, classtype, formula, exmpl_answers, survey_quest_text, survey_quest_src, unitsrequired, relatednames2, shortname, 
         order_obs, hl7_field_subfield_id, external_copyright_notice, example_units, long_common_name, example_ucum_units, status_reason, 
         status_text, change_reason_public, common_test_rank, common_order_rank, hl7_attachment_structure, external_copyright_link, paneltype, askatorderentry, associatedobservations, 
         versionfirstreleased, validhl7attachmentrequest, displayname';
      alter table sources.loinc ADD COLUMN vocabulary_date date;
      alter table sources.loinc ADD COLUMN vocabulary_version VARCHAR (200);
      update sources.loinc set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      execute 'COPY sources.map_to FROM '''||pVocabularyPath||'mapto.csv'' delimiter '','' csv HEADER';
      execute 'COPY sources.source_organization FROM '''||pVocabularyPath||'sourceorganization.csv'' delimiter '','' csv HEADER';
      execute 'COPY sources.loinc_hierarchy FROM '''||pVocabularyPath||'componenthierarchybysystem.csv'' delimiter '','' csv HEADER FORCE NULL path_to_root,sequence,immediate_parent,code,code_text';
      truncate table sources.loinc_answerslist, sources.loinc_answerslistlink, sources.loinc_forms;
      execute 'COPY sources.loinc_answerslist FROM '''||pVocabularyPath||'answerlist.csv'' delimiter '','' csv HEADER FORCE NULL answerlistid, answerlistname, answerlistoid, extdefinedyn, 
         extdefinedanswerlistcodesystem, extdefinedanswerlistlink, answerstringid, localanswercode, localanswercodesystem, sequencenumber, displaytext, extcodeid, extcodedisplayname, extcodesystem, 
         extcodesystemversion, extcodesystemcopyrightnotice, subsequenttextprompt, description, score';
      update sources.loinc_answerslist set displaytext=substr(displaytext,1,255) where length(displaytext)>255;
      execute 'COPY sources.loinc_answerslistlink FROM '''||pVocabularyPath||'loincanswerlistlink.csv'' delimiter '','' csv HEADER';
      --insert into sources.loinc_forms select * from sources.py_xlsparse_forms(pVocabularyPath||'/LOINC_PanelsAndForms.xlsx'); --PanelsAndForms.xlsx replaced with CSV-file in v2.65
      --execute 'COPY sources.loinc_forms FROM '''||pVocabularyPath||'panelsandforms.csv'' delimiter '','' csv HEADER'; --use csvcut (pip3 install csvkit --user) for parsing and ignoring new last columns
      execute 'COPY sources.loinc_forms FROM PROGRAM ''/var/lib/pgsql/.local/bin/csvcut --columns=1-28 "'||pVocabularyPath||'panelsandforms.csv" '' delimiter '','' csv HEADER';
      truncate table sources.loinc_group, sources.loinc_parentgroupattributes, sources.loinc_grouploincterms, sources.loinc_partlink_primary, sources.loinc_partlink_supplementary, sources.loinc_part, sources.loinc_radiology, sources.loinc_consumer_name;
      execute 'COPY sources.loinc_group FROM '''||pVocabularyPath||'group.csv'' delimiter '','' csv HEADER FORCE NULL parentgroupid,groupid,lgroup,archetype,status,versionfirstreleased';
      execute 'COPY sources.loinc_parentgroupattributes FROM '''||pVocabularyPath||'parentgroupattributes.csv'' delimiter '','' csv HEADER FORCE NULL parentgroupid,ltype,lvalue';
      execute 'COPY sources.loinc_grouploincterms FROM '''||pVocabularyPath||'grouploincterms.csv'' delimiter '','' csv HEADER FORCE NULL category,groupid,archetype,loincnumber,longcommonname';
      execute 'COPY sources.loinc_partlink_primary FROM '''||pVocabularyPath||'loincpartlink_primary.csv'' delimiter '','' csv HEADER FORCE NULL loincnumber,longcommonname,partnumber,partname,partcodesystem,parttypename,linktypename,property';
      execute 'COPY sources.loinc_partlink_supplementary FROM '''||pVocabularyPath||'loincpartlink_supplementary.csv'' delimiter '','' csv HEADER FORCE NULL loincnumber,longcommonname,partnumber,partname,partcodesystem,parttypename,linktypename,property';
      execute 'COPY sources.loinc_part FROM '''||pVocabularyPath||'part.csv'' delimiter '','' csv HEADER FORCE NULL partnumber,parttypename,partname,partdisplayname,status';
      execute 'COPY sources.loinc_radiology FROM '''||pVocabularyPath||'loincrsnaradiologyplaybook.csv'' delimiter '','' csv HEADER FORCE NULL loincnumber,longcommonname,partnumber,parttypename,partname,partsequenceorder,rid,preferredname,rpid,longname';
      truncate table sources.loinc_class, sources.cpt_mrsmap;
      set local datestyle='ISO, DMY'; --set proper date format
      execute 'COPY sources.loinc_class FROM '''||pVocabularyPath||'loinc_class.csv'' delimiter ''|'' csv HEADER';
      execute 'COPY sources.cpt_mrsmap FROM '''||pVocabularyPath||'cpt_mrsmap.rrf'' delimiter ''|'' csv';
      execute 'COPY sources.loinc_documentontology FROM '''||pVocabularyPath||'documentontology.csv'' delimiter '','' csv HEADER';
      execute 'COPY sources.loinc_consumer_name FROM '''||pVocabularyPath||'ConsumerName.csv'' delimiter '','' csv HEADER';
      PERFORM sources_archive.AddVocabularyToArchive('LOINC', ARRAY['loinc','map_to','source_organization','loinc_hierarchy','loinc_documentontology','loinc_answerslist','loinc_answerslistlink','loinc_forms',
        'loinc_group','loinc_parentgroupattributes','loinc_grouploincterms','loinc_partlink_primary','loinc_partlink_supplementary','loinc_part','loinc_radiology','loinc_class','cpt_mrsmap',
        'scccrefset_expressionassociation_int','scccrefset_mapcorrorfull_int','loinc_consumer_name'], COALESCE(pVocabularyDate,current_date), 'archive.loinc_version', 100);
  when 'HCPCS' then
      truncate table sources.anweb_v2;
      insert into sources.anweb_v2 
        select trim(HCPC),long_description,short_description,xref1,xref2,xref3,xref4,xref5,betos,
        TO_DATE(add_date,'YYYYMMDD'),TO_DATE(act_eff_dt,'YYYYMMDD'),TO_DATE(term_dt ,'YYYYMMDD'),
        COALESCE(pVocabularyDate,current_date),COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date) 
        from sources.py_xlsparse_hcpcs(pVocabularyPath||'/HCPC_CONTR_ANWEB.xlsx') where add_date ~ '\d{6}';
      PERFORM sources_archive.AddVocabularyToArchive('HCPCS', ARRAY['anweb_v2'], COALESCE(pVocabularyDate,current_date), 'archive.hcpcs_version', 10);
  when 'SNOMED' then
      truncate table sources.sct2_concept_full_merged, sources.sct2_desc_full_merged, sources.sct2_rela_full_merged, sources.der2_crefset_assreffull_merged, sources.der2_crefset_attributevalue_full_merged, sources.der2_crefset_language_merged;
      drop index sources.idx_concept_merged_id;
      drop index sources.idx_desc_merged_id;
      drop index sources.idx_rela_merged_id;
      drop index sources.idx_lang_merged_refid;
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
      --loading der2_crefset_attributevalue_full_merged
      execute 'COPY sources.der2_crefset_attributevalue_full_merged FROM '''||pVocabularyPath||'der2_cRefset_AttributeValueFull_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.der2_crefset_attributevalue_full_merged FROM '''||pVocabularyPath||'der2_cRefset_AttributeValueFull_UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.der2_crefset_attributevalue_full_merged FROM '''||pVocabularyPath||'der2_cRefset_AttributeValueFull_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.der2_crefset_attributevalue_full_merged FROM '''||pVocabularyPath||'der2_cRefset_AttributeValue_GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      --delete duplicate records
      DELETE FROM sources.der2_crefset_attributevalue_full_merged s WHERE EXISTS (SELECT 1 FROM sources.der2_crefset_attributevalue_full_merged s_int 
      	WHERE s_int.id = s.id AND s_int.effectivetime=s.effectivetime
        AND s_int.active = s.active AND s_int.moduleid=s.moduleid
        AND s_int.refsetid=s.refsetid AND s_int.referencedcomponentid=s.referencedcomponentid
        AND s_int.valueid = s.valueid AND s_int.ctid > s.ctid);
      CREATE INDEX idx_concept_merged_id ON sources.sct2_concept_full_merged (id);
      CREATE INDEX idx_desc_merged_id ON sources.sct2_desc_full_merged (conceptid);
      CREATE INDEX idx_rela_merged_id ON sources.sct2_rela_full_merged (id);
      analyze sources.sct2_concept_full_merged;
      analyze sources.sct2_desc_full_merged;
      analyze sources.sct2_rela_full_merged;
      --loading der2_sRefset_SimpleMapFull_INT
      truncate table sources.der2_srefset_simplemapfull_int;
      execute 'COPY sources.der2_srefset_simplemapfull_int FROM '''||pVocabularyPath||'der2_sRefset_SimpleMapFull_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      --loading der2_crefset_language_merged
      execute 'COPY sources.der2_crefset_language_merged (id,effectivetime,active,moduleid,refsetId,referencedComponentId,acceptabilityId) FROM '''||pVocabularyPath||'der2_sRefset_LanguageFull_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      update sources.der2_crefset_language_merged set source_file_id='INT' where source_file_id is null;
      execute 'COPY sources.der2_crefset_language_merged (id,effectivetime,active,moduleid,refsetId,referencedComponentId,acceptabilityId) FROM '''||pVocabularyPath||'der2_sRefset_LanguageFull_UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      update sources.der2_crefset_language_merged set source_file_id='UK' where source_file_id is null;
      execute 'COPY sources.der2_crefset_language_merged (id,effectivetime,active,moduleid,refsetId,referencedComponentId,acceptabilityId) FROM '''||pVocabularyPath||'der2_sRefset_LanguageFull_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      update sources.der2_crefset_language_merged set source_file_id='US' where source_file_id is null;
      execute 'COPY sources.der2_crefset_language_merged (id,effectivetime,active,moduleid,refsetId,referencedComponentId,acceptabilityId) FROM '''||pVocabularyPath||'der2_sRefset_LanguageFull_GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      update sources.der2_crefset_language_merged set source_file_id='GB_DE' where source_file_id is null;
      CREATE INDEX idx_lang_merged_refid ON sources.der2_crefset_language_merged (referencedcomponentid);
      analyze sources.der2_crefset_language_merged;
      --loading der2_ssrefset_moduledependency_merged
      truncate table sources.der2_ssrefset_moduledependency_merged;
      execute 'COPY sources.der2_ssrefset_moduledependency_merged FROM '''||pVocabularyPath||'der2_ssRefset_ModuleDependencyFull_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.der2_ssrefset_moduledependency_merged FROM '''||pVocabularyPath||'der2_ssRefset_ModuleDependencyFull_UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.der2_ssrefset_moduledependency_merged FROM '''||pVocabularyPath||'der2_ssRefset_ModuleDependencyFull_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.der2_ssrefset_moduledependency_merged FROM '''||pVocabularyPath||'der2_ssRefset_ModuleDependencyFull_GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      --loading der2_iisssccrefset_extendedmapfull_us
      truncate table sources.der2_iisssccrefset_extendedmapfull_us;
      execute 'COPY sources.der2_iisssccrefset_extendedmapfull_us FROM '''||pVocabularyPath||'der2_iisssccRefset_ExtendedMapFull_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      PERFORM sources_archive.AddVocabularyToArchive('SNOMED', ARRAY['sct2_concept_full_merged','sct2_desc_full_merged','sct2_rela_full_merged','der2_crefset_assreffull_merged','der2_crefset_language_merged',
        'der2_srefset_simplemapfull_int','der2_ssrefset_moduledependency_merged','der2_iisssccrefset_extendedmapfull_us','der2_crefset_attributevalue_full_merged'], COALESCE(pVocabularyDate,current_date), 'archive.snomed_version', 10);
  when 'SNOMED_INT' then
    truncate table sources.sct2_concept_full_int, 
                   sources.sct2_desc_full_int, 
                   sources.sct2_rela_full_int, 
                   sources.der2_crefset_assreffull_int, 
                   sources.der2_crefset_attributevalue_full_int, 
                   sources.der2_crefset_language_int;

    drop index sources.idx_concept_int_id;
    drop index sources.idx_desc_int_id;
    drop index sources.idx_rela_int_id;
    drop index sources.idx_lang_int_refid;

    execute 'COPY sources.sct2_concept_full_int (id,effectivetime,active,moduleid,statusid) FROM '''||pVocabularyPath||'sct2_Concept_Full_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
    
    update sources.sct2_concept_full_int 
       set vocabulary_date = COALESCE(pVocabularyDate,current_date), 
           vocabulary_version = COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);

    execute 'COPY sources.sct2_desc_full_int FROM ''' || pVocabularyPath || 'sct2_Description_Full-en_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    execute 'COPY sources.sct2_rela_full_int FROM ''' || pVocabularyPath || 'sct2_Relationship_Full_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    execute 'COPY sources.der2_crefset_assreffull_int FROM ''' || pVocabularyPath || 'der2_cRefset_AssociationFull_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    execute 'COPY sources.der2_crefset_attributevalue_full_int FROM ''' || pVocabularyPath || 'der2_cRefset_AttributeValueFull_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    CREATE INDEX idx_concept_int_id ON sources.sct2_concept_full_int (id);
    CREATE INDEX idx_desc_int_id ON sources.sct2_desc_full_int (conceptid);
    CREATE INDEX idx_rela_int_id ON sources.sct2_rela_full_int (id);
    
    analyze sources.sct2_concept_full_int;
    analyze sources.sct2_desc_full_int;
    analyze sources.sct2_rela_full_int;

    truncate table sources.der2_srefset_simplemapfull_int;
    execute 'COPY sources.der2_srefset_simplemapfull_int FROM ''' || pVocabularyPath || 'der2_sRefset_SimpleMapFull_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    execute 'COPY sources.der2_crefset_language_int (id,effectivetime,active,moduleid,refsetId,referencedComponentId,acceptabilityId) FROM ''' || pVocabularyPath || 'der2_sRefset_LanguageFull_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    update sources.der2_crefset_language_int 
       set source_file_id = 'INT' 
     where source_file_id is null;

    CREATE INDEX idx_lang_int_refid ON sources.der2_crefset_language_int (referencedcomponentid);
    analyze sources.der2_crefset_language_int;

    execute 'COPY sources.der2_ssrefset_moduledependency_int FROM ''' || pVocabularyPath || 'der2_ssRefset_ModuleDependencyFull_INT.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    PERFORM sources_archive.AddVocabularyToArchive(
        'SNOMED_INT', 
        ARRAY['sct2_concept_full_int',
              'sct2_desc_full_int',
              'sct2_rela_full_int',
              'der2_crefset_assreffull_int',
              'der2_crefset_language_int',
              'der2_srefset_simplemapfull_int',
              'der2_ssrefset_moduledependency_int',
              'der2_crefset_attributevalue_full_int'], 
              COALESCE(pVocabularyDate, current_date), 
              'archive.snomed_int_version', 20);

  WHEN 'SNOMED_US' THEN
    truncate table sources.sct2_concept_full_us, 
                   sources.sct2_desc_full_us, 
                   sources.sct2_rela_full_us, 
                   sources.der2_crefset_assreffull_us, 
                   sources.der2_crefset_attributevalue_full_us, 
                   sources.der2_crefset_language_us;
                   
    drop index sources.idx_concept_us_id;
    drop index sources.idx_desc_us_id;
    drop index sources.idx_rela_us_id;
    drop index sources.idx_lang_us_refid;

    execute 'COPY sources.sct2_concept_full_us (id,effectivetime,active,moduleid,statusid) FROM ''' || pVocabularyPath || 'sct2_Concept_Full_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    update sources.sct2_concept_full_us
       set vocabulary_date = COALESCE(pVocabularyDate, current_date), 
           vocabulary_version = COALESCE(pVocabularyVersion, pVocabularyID || ' ' || current_date);

    execute 'COPY sources.sct2_desc_full_us FROM ''' || pVocabularyPath || 'sct2_Description_Full-en_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    execute 'COPY sources.sct2_rela_full_us FROM ''' || pVocabularyPath || 'sct2_Relationship_Full_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    execute 'COPY sources.der2_crefset_assreffull_us FROM ''' || pVocabularyPath || 'der2_cRefset_AssociationFull_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    execute 'COPY sources.der2_crefset_attributevalue_full_us FROM '''||pVocabularyPath||'der2_cRefset_AttributeValueFull_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    CREATE INDEX idx_concept_us_id ON sources.sct2_concept_full_us (id);
    CREATE INDEX idx_desc_us_id ON sources.sct2_desc_full_us (conceptid);
    CREATE INDEX idx_rela_us_id ON sources.sct2_rela_full_us (id);
    
    analyze sources.sct2_concept_full_us;
    analyze sources.sct2_desc_full_us;
    analyze sources.sct2_rela_full_us;

    execute 'COPY sources.der2_crefset_language_us (id,effectivetime,active,moduleid,refsetId,referencedComponentId,acceptabilityId) FROM '''||pVocabularyPath||'der2_sRefset_LanguageFull_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
    
    update sources.der2_crefset_language_us
       set source_file_id = 'US' 
     where source_file_id is null;

    CREATE INDEX idx_lang_us_refid ON sources.der2_crefset_language_us (referencedcomponentid);
    
    analyze sources.der2_crefset_language_us;
    
    truncate table sources.der2_ssrefset_moduledependency_us;

    execute 'COPY sources.der2_ssrefset_moduledependency_us FROM ''' || pVocabularyPath || 'der2_ssRefset_ModuleDependencyFull_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    truncate table sources.der2_iisssccrefset_extendedmapfull_us;

    execute 'COPY sources.der2_iisssccrefset_extendedmapfull_us FROM '''||pVocabularyPath||'der2_iisssccRefset_ExtendedMapFull_US.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    PERFORM sources_archive.AddVocabularyToArchive(
        'SNOMED_US', 
        ARRAY['sct2_concept_full_us',
              'sct2_desc_full_us',
              'sct2_rela_full_us',
              'der2_crefset_assreffull_us',
              'der2_crefset_language_us',
              'der2_ssrefset_moduledependency_us',
              'der2_crefset_attributevalue_full_us',
              'der2_iisssccrefset_extendedmapfull_us'], 
              COALESCE(pVocabularyDate, current_date), 
              'archive.snomed_us_version', 
              20);

  WHEN 'SNOMED_UK_DE' THEN

    truncate table sources.sct2_concept_full_gb_de, 
                   sources.sct2_desc_full_gb_de, 
                   sources.sct2_rela_full_gb_de, 
                   sources.der2_crefset_assreffull_gb_de, 
                   sources.der2_crefset_attributevalue_full_gb_de, 
                   sources.der2_crefset_language_gb_de;
                   
    drop index sources.idx_concept_gb_de_id;
    drop index sources.idx_desc_gb_de_id;
    drop index sources.idx_rela_gb_de_id;
    drop index sources.idx_lang_gb_de_refid;

    execute 'COPY sources.sct2_concept_full_gb_de (id,effectivetime,active,moduleid,statusid) FROM ''' || pVocabularyPath || 'sct2_Concept_Full_GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    update sources.sct2_concept_full_gb_de
       set vocabulary_date = COALESCE(pVocabularyDate, current_date), 
           vocabulary_version = COALESCE(pVocabularyVersion, pVocabularyID || ' ' || current_date);

    execute 'COPY sources.sct2_desc_full_gb_de FROM ''' || pVocabularyPath || 'sct2_Description_Full-en-GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    execute 'COPY sources.sct2_rela_full_gb_de FROM ''' || pVocabularyPath || 'sct2_Relationship_Full_GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    execute 'COPY sources.der2_crefset_assreffull_gb_de FROM ''' || pVocabularyPath || 'der2_cRefset_AssociationFull_GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    execute 'COPY sources.der2_crefset_attributevalue_full_gb_de FROM '''||pVocabularyPath||'der2_cRefset_AttributeValue_GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    CREATE INDEX idx_concept_gb_de_id ON sources.sct2_concept_full_gb_de (id);
    CREATE INDEX idx_desc_gb_de_id ON sources.sct2_desc_full_gb_de (conceptid);
    CREATE INDEX idx_rela_gb_de_id ON sources.sct2_rela_full_gb_de (id);
    
    analyze sources.sct2_concept_full_gb_de;
    analyze sources.sct2_desc_full_gb_de;
    analyze sources.sct2_rela_full_gb_de;

    execute 'COPY sources.der2_crefset_language_gb_de (id,effectivetime,active,moduleid,refsetId,referencedComponentId,acceptabilityId) FROM ''' || pVocabularyPath || 'der2_sRefset_LanguageFull_GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
    
    update sources.der2_crefset_language_gb_de 
       set source_file_id = 'GB_DE' 
     where source_file_id is null;
     
    CREATE INDEX idx_lang_gb_de_refid ON sources.der2_crefset_language_gb_de (referencedcomponentid);

    analyze sources.der2_crefset_language_gb_de;

    truncate table sources.der2_ssrefset_moduledependency_gb_de;

    execute 'COPY sources.der2_ssrefset_moduledependency_gb_de FROM '''||pVocabularyPath||'der2_ssRefset_ModuleDependencyFull_GB_DE.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    PERFORM sources_archive.AddVocabularyToArchive(
        'SNOMED_UK_DE', 
        ARRAY['sct2_concept_full_gb_de',
              'sct2_desc_full_gb_de',
              'sct2_rela_full_gb_de',
              'der2_crefset_assreffull_gb_de',
              'der2_crefset_language_gb_de',
              'der2_ssrefset_moduledependency_gb_de',
              'der2_crefset_attributevalue_full_gb_de'], 
              COALESCE(pVocabularyDate, current_date), 
              'archive.snomed_gb_de_version', 
              20);

  when 'SNOMED_UK' then
    truncate table sources.sct2_concept_full_uk, 
                   sources.sct2_desc_full_uk, 
                   sources.sct2_rela_full_uk, 
                   sources.der2_crefset_assreffull_uk, 
                   sources.der2_crefset_attributevalue_full_uk, 
                   sources.der2_crefset_language_uk;
                   
    drop index sources.idx_concept_uk_id;
    drop index sources.idx_desc_uk_id;
    drop index sources.idx_rela_uk_id;
    drop index sources.idx_lang_uk_refid;

    execute 'COPY sources.sct2_concept_full_uk (id,effectivetime,active,moduleid,statusid) FROM ''' || pVocabularyPath || 'sct2_Concept_Full-UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    update sources.sct2_concept_full_uk 
       set vocabulary_date = COALESCE(pVocabularyDate,current_date), 
           vocabulary_version = COALESCE(pVocabularyVersion, pVocabularyID || ' ' || current_date);

    execute 'COPY sources.sct2_desc_full_uk FROM ''' || pVocabularyPath || 'sct2_Description_Full-UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    execute 'COPY sources.sct2_rela_full_uk FROM ''' || pVocabularyPath || 'sct2_Relationship_Full-UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    execute 'COPY sources.der2_crefset_assreffull_uk FROM ''' || pVocabularyPath || 'der2_cRefset_AssociationFull_UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    execute 'COPY sources.der2_crefset_attributevalue_full_uk FROM '''||pVocabularyPath||'der2_cRefset_AttributeValueFull_UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    CREATE INDEX idx_concept_uk_id ON sources.sct2_concept_full_uk (id);
    CREATE INDEX idx_desc_uk_id ON sources.sct2_desc_full_uk (conceptid);
    CREATE INDEX idx_rela_uk_id ON sources.sct2_rela_full_uk (id);
    
    analyze sources.sct2_concept_full_uk;
    analyze sources.sct2_desc_full_uk;
    analyze sources.sct2_rela_full_uk;

    execute 'COPY sources.der2_crefset_language_uk (id,effectivetime,active,moduleid,refsetId,referencedComponentId,acceptabilityId) FROM ''' || pVocabularyPath || 'der2_sRefset_LanguageFull_UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
    
    update sources.der2_crefset_language_uk 
       set source_file_id = 'UK' 
     where source_file_id is null;

    CREATE INDEX idx_lang_uk_refid ON sources.der2_crefset_language_uk (referencedcomponentid);
    
    analyze sources.der2_crefset_language_uk;

    truncate table sources.der2_ssrefset_moduledependency_uk;

    execute 'COPY sources.der2_ssrefset_moduledependency_uk FROM ''' || pVocabularyPath || 'der2_ssRefset_ModuleDependencyFull_UK.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';

    PERFORM sources_archive.AddVocabularyToArchive(
        'SNOMED_UK', 
        ARRAY['sct2_concept_full_uk',
              'sct2_desc_full_uk',
              'sct2_rela_full_uk',
              'der2_crefset_assreffull_uk',
              'der2_crefset_language_uk',
              'der2_ssrefset_moduledependency_uk',
              'der2_crefset_attributevalue_full_uk'], 
              COALESCE(pVocabularyDate, current_date), 
              'archive.snomed_uk_version', 
              20);

  when 'ICD10CM' then
      truncate table sources.icd10cm_temp, sources.icd10cm;
      execute 'COPY sources.icd10cm_temp FROM '''||pVocabularyPath||'icd10cm.txt'' delimiter E''\b''';
      insert into sources.icd10cm select trim(substring (icd10cm_codes_and_desc from 7 for 7)), substring (icd10cm_codes_and_desc from 15 for 1)::INT4,
      	trim(substring (icd10cm_codes_and_desc from 17 for 60)), trim(substring (icd10cm_codes_and_desc from 78)),
        COALESCE(pVocabularyDate,current_date), COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date) From  sources.icd10cm_temp;
      analyze sources.icd10cm;
      PERFORM sources_archive.AddVocabularyToArchive('ICD10CM', ARRAY['icd10cm'], COALESCE(pVocabularyDate,current_date), 'archive.icd10cm_version', 5);
  when 'CVX' then
      if pVocabularyDate is null then 
      	RAISE EXCEPTION 'For current vocabulary (%) you must set the pVocabularyDate!', pVocabularyID;
      end if;
      truncate table sources.cvx, sources.cvx_cpt, sources.cvx_vaccine;
      insert into sources.cvx select TRIM(CVX_CODE),TRIM(SHORT_DESCRIPTION),TRIM(FULL_VACCINE_NAME),TRIM(vaccinestatus),LAST_UPDATED_DATE, pVocabularyDate, COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date) from 
        sources.py_xlsparse_cvx_codes(pVocabularyPath||'/web_cvx.xlsx');
      insert into sources.cvx_cpt select TRIM(CPT_CODE),TRIM(CPT_DESCRIPTION),TRIM(CVX_SHORT_DESCRIPTION),TRIM(CVX_CODE),TRIM(MAP_COMMENT),LAST_UPDATED_DATE, TRIM(CPT_CODE_ID) from 
        sources.py_xlsparse_cvx_cpt(pVocabularyPath||'/web_cpt.xlsx');
      insert into sources.cvx_vaccine select TRIM(CVX_SHORT_DESCRIPTION),TRIM(CVX_CODE),TRIM(VACCINE_STATUS),TRIM(VG_NAME), TRIM(CVX_VACCINE_GROUP) from 
        sources.py_xlsparse_cvx_vaccine(pVocabularyPath||'/web_vax2vg.xlsx');
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
      PERFORM sources_archive.AddVocabularyToArchive('CVX', ARRAY['cvx','cvx_cpt','cvx_vaccine','cvx_dates'], pVocabularyDate, 'archive.cvx_version', 30);
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
      execute 'COPY sources.dpd_therapeutic_class_all FROM '''||pVocabularyPath||'ther.txt'' delimiter '','' csv ENCODING ''ISO-8859-1'' FORCE NULL tc_atc_number,tc_atc';
      execute 'COPY sources.dpd_therapeutic_class_all FROM '''||pVocabularyPath||'ther_ia.txt'' delimiter '','' csv ENCODING ''ISO-8859-1'' FORCE NULL tc_atc_number,tc_atc';
      execute 'COPY sources.dpd_therapeutic_class_all FROM '''||pVocabularyPath||'ther_ap.txt'' delimiter '','' csv ENCODING ''ISO-8859-1'' FORCE NULL tc_atc_number,tc_atc';
      PERFORM sources_archive.AddVocabularyToArchive('DPD', ARRAY['dpd_drug_all','dpd_active_ingredients_all','dpd_form_all','dpd_route_all','dpd_packaging_all','dpd_status_all','dpd_companies_all',
        'dpd_therapeutic_class_all'], COALESCE(pVocabularyDate,current_date), 'archive.dpd_version', 30);
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
      PERFORM sources_archive.AddVocabularyToArchive('GGR', ARRAY['ggr_gal','ggr_innm','ggr_ir','ggr_mp','ggr_mpp','ggr_sam'], COALESCE(pVocabularyDate,current_date), 'archive.ggr_version', 30);
  when 'AMT' then
      truncate table sources.amt_full_descr_drug_only, sources.amt_sct2_concept_full_au, sources.amt_rf2_full_relationships, sources.amt_rf2_ss_strength_refset,
      	sources.amt_crefset_language;
      drop index sources.idx_amt_concept_id;
      drop index sources.idx_amt_descr_id;
      drop index sources.idx_amt_rela_id;
      drop index sources.idx_amt_lang_refid;
      execute 'COPY sources.amt_full_descr_drug_only FROM '''||pVocabularyPath||'sct2_Description_Full-en-AU_AU.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.amt_sct2_concept_full_au (id,effectivetime,active,moduleid,statusid) FROM '''||pVocabularyPath||'sct2_Concept_Full_AU.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.amt_rf2_full_relationships FROM '''||pVocabularyPath||'sct2_Relationship_Full_AU.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.amt_rf2_ss_strength_refset FROM '''||pVocabularyPath||'der2_ccsRefset_StrengthFull_AU.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.amt_crefset_language FROM '''||pVocabularyPath||'der2_cRefset_LanguageFull-en-AU_AU.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      update sources.amt_sct2_concept_full_au set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      
      create index idx_amt_concept_id on sources.amt_sct2_concept_full_au (id);
      create index idx_amt_descr_id on sources.amt_full_descr_drug_only (conceptid);
      create index idx_amt_rela_id on sources.amt_rf2_full_relationships (id);
      create index idx_amt_lang_refid on sources.amt_crefset_language (referencedcomponentid);
      
      analyze sources.amt_full_descr_drug_only;
      analyze sources.amt_sct2_concept_full_au;
      analyze sources.amt_rf2_full_relationships;
      analyze sources.amt_rf2_ss_strength_refset;
      analyze sources.amt_crefset_language;
      PERFORM sources_archive.AddVocabularyToArchive('AMT', ARRAY['amt_full_descr_drug_only','amt_sct2_concept_full_au','amt_rf2_full_relationships','amt_rf2_ss_strength_refset','amt_crefset_language'], COALESCE(pVocabularyDate,current_date), 'archive.amt_version', 30);
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
      --execute 'COPY sources.bdpm_ingredient FROM '''||pVocabularyPath||'CIS_COMPO_bdpm.txt'' delimiter E''\t'' csv quote E''\b'' ENCODING ''ISO-8859-1''';
      --data hotfix, extra TAB in 'ingredient' column
      execute 'COPY sources.bdpm_ingredient FROM PROGRAM ''cat "'||pVocabularyPath||'CIS_COMPO_bdpm.txt"| sed ''''s/\t\t\t\t/\t/g''''  '' delimiter E''\t'' csv quote E''\b'' ENCODING ''ISO-8859-1''';
      execute 'COPY sources.bdpm_packaging FROM '''||pVocabularyPath||'CIS_CIP_bdpm.txt'' delimiter E''\t'' csv quote E''\b'' ENCODING ''ISO-8859-1''';
      --execute 'COPY sources.bdpm_gener FROM '''||pVocabularyPath||'CIS_GENER_bdpm.txt'' delimiter E''\t'' csv quote E''\b'' ENCODING ''ISO-8859-1''';
      --data hotfix, extra TAB in 'generic_desc' column
      execute 'COPY sources.bdpm_gener FROM PROGRAM ''cat "'||pVocabularyPath||'CIS_GENER_bdpm.txt"| sed ''''s/\t\t/\t/g''''  '' delimiter E''\t'' csv quote E''\b'' ENCODING ''ISO-8859-1''';
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
      PERFORM sources_archive.AddVocabularyToArchive('BDPM', ARRAY['bdpm_drug','bdpm_ingredient','bdpm_packaging'], COALESCE(pVocabularyDate,current_date), 'archive.bdpm_version', 30);
  when 'ICDO3' THEN
      drop index sources.idx_icdo3_mrconso;
      drop index sources.idx_icdo3_mrrel;
      truncate table sources.icdo3_mrconso, sources.icdo3_mrrel;
      execute 'COPY sources.icdo3_mrconso (cui,lat,ts,lui,stt,sui,ispref,aui,saui,scui,sdui,sab,tty,code,str,srl,suppress,cvf,vocabulary_date) FROM '''||pVocabularyPath||'MRCONSO.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.icdo3_mrrel FROM '''||pVocabularyPath||'MRREL.RRF'' delimiter ''|'' csv quote E''\b''';
      update sources.icdo3_mrconso set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      CREATE INDEX idx_icdo3_mrconso ON sources.icdo3_mrconso (SAB,TTY);
      CREATE INDEX idx_icdo3_mrrel ON sources.icdo3_mrrel (AUI1, AUI2);
      analyze sources.icdo3_mrconso;
      analyze sources.icdo3_mrrel;
  when 'CDM' THEN
      if pVocabularyVersion is null then
      	RAISE EXCEPTION 'For current vocabulary (%) you must set the pVocabularyVersion! Format (json): {''version'':''CDM vX.Y.Z'', ''published_at'':''A'',''node_id'':''B''}', pVocabularyID;
      end if;
      
      if not (pVocabularyVersion::json->>'version') ~* '^CDM v\d+\.\d+\.\d+$' then
      	RAISE EXCEPTION 'For current vocabulary (%) you must set the proper CDM format!', pVocabularyID;
      end if;
      
      truncate table sources.cdm_raw_table;
      --we need to replace all carriage returns with chr(0) due to loading the entire file
      execute 'COPY sources.cdm_raw_table (ddl_text) FROM PROGRAM ''cat "'||pVocabularyPath||'PostgreSQL_DDL.sql" | tr ''''\r\n'''' '''''||chr(1)||'''''  '' csv delimiter E''\b'' quote E''\f'' ';
      --return the carriage returns back and comment all 'ALTER TABLE' clauses
      update sources.cdm_raw_table set ddl_text=regexp_replace(replace(ddl_text,chr(1),E'\r\n'),'ALTER TABLE','--ALTER TABLE','gi'),
      	ddl_date=(pVocabularyVersion::json->>'published_at')::timestamp, ddl_release_id=(pVocabularyVersion::json->>'node_id'), 
        vocabulary_date=(pVocabularyVersion::json->>'published_at')::date, vocabulary_version=(pVocabularyVersion::json->>'version');
      update sources.cdm_raw_table set ddl_text=regexp_replace(ddl_text,'datetime2','timestamp','gi') where ddl_release_id='MDc6UmVsZWFzZTExNDY1Njg5';--fix DDL bug in CDM v5.3.1
      update sources.cdm_raw_table set ddl_text=replace(ddl_text,'@cdmDatabaseSchema.','');--remove prefixes
      insert into sources.cdm_tables
        select p.*,r.ddl_date, r.ddl_release_id,r.vocabulary_date, r.vocabulary_version
        from sources.cdm_raw_table r
        cross join vocabulary_pack.ParseTables (r.ddl_text) p
        where not exists (select 1 from sources.cdm_tables c where c.ddl_release_id=r.ddl_release_id);
      analyze sources.cdm_tables;
  when 'SNOMED VETERINARY' then
     truncate table sources.vet_sct2_concept_full, sources.vet_sct2_desc_full, sources.vet_sct2_rela_full, sources.vet_der2_crefset_assreffull;
      execute 'COPY sources.vet_sct2_concept_full(id,effectivetime,active,moduleid,statusid) FROM '''||pVocabularyPath||'sct2_Concept_Full_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      update sources.vet_sct2_concept_full set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      execute 'COPY sources.vet_sct2_desc_full FROM '''||pVocabularyPath||'sct2_Description_Full_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.vet_sct2_rela_full FROM '''||pVocabularyPath||'sct2_Relationship_Full_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.vet_der2_crefset_assreffull FROM '''||pVocabularyPath||'der2_cRefset_AssociationFull_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
    execute 'COPY sources.vet_der2_crefset_language(id,effectiveTime  ,active,moduleId,refsetId,referencedComponentId,acceptabilityId) 
    FROM '''||pVocabularyPath||'der2_cRefset_LanguageFull_en_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
    execute 'COPY sources.vet_der2_crefset_attributevalue_full FROM '''||pVocabularyPath||'der2_cRefset_AttributeValueFull_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
    execute 'COPY sources.vet_der2_ssRefset_ModuleDependency FROM '''||pVocabularyPath||'der2_ssRefset_ModuleDependencyfull_VTS.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      update sources.vet_der2_crefset_language
      set source_file_id = 'VET' 
     where source_file_id is null;
      analyze sources.vet_sct2_concept_full;
      analyze sources.vet_sct2_desc_full;
      analyze sources.vet_sct2_rela_full;
    analyze sources.vet_der2_crefset_assreffull;
    analyze sources.vet_der2_crefset_language;
    analyze sources.vet_der2_crefset_attributevalue_full;
      PERFORM sources_archive.AddVocabularyToArchive('SNOMED Veterinary', 
    ARRAY['vet_sct2_concept_full','vet_sct2_desc_full','vet_sct2_rela_full','vet_der2_crefset_assreffull','vet_der2_crefset_language','vet_der2_crefset_attributevalue_full','vet_der2_ssRefset_ModuleDependency'], 
    COALESCE(pVocabularyDate,current_date), 'archive.snomedvet_version', 10);
  when 'EDI' then
      truncate table sources.edi_data;
      execute 'COPY sources.edi_data (concept_code,concept_name,concept_synonym,domain_id,vocabulary_id,concept_class_id,valid_start_date,valid_end_date,invalid_reason,ancestor_concept_code,previous_concept_code,material,dosage,dosage_unit,sanjung_name) FROM '''||pVocabularyPath||'ediData_UTF8v3.csv'' delimiter '','' csv quote ''"'' HEADER';
      update sources.edi_data set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
  when 'ICD10CN' then
      truncate table sources.icd10cn_concept, sources.icd10cn_concept_relationship;
      execute 'COPY sources.icd10cn_concept (concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason,english_concept_name,vocabulary_date,vocabulary_version) FROM '''||pVocabularyPath||'icd10cn_concept.tsv'' delimiter E''\t'' csv quote ''"'' HEADER';
      execute 'COPY sources.icd10cn_concept_relationship FROM '''||pVocabularyPath||'icd10cn_concept_relationship.csv'' delimiter E''\t'' csv quote ''"'' HEADER';
      update sources.icd10cn_concept set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      --create 'clear' concept code
      update sources.icd10cn_concept set concept_code_clean=substring(trim('()' from concept_code),'([^*(]*)');
  when 'NEBRASKA LEXICON' then
      truncate table sources.lex_sct2_concept, sources.lex_sct2_desc, sources.lex_sct2_rela, sources.lex_der2_crefset_assref;
      execute 'COPY sources.lex_sct2_concept (id,effectivetime,active,moduleid,statusid) FROM '''||pVocabularyPath||'sct2_Concept.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      update sources.lex_sct2_concept set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      execute 'COPY sources.lex_sct2_desc FROM '''||pVocabularyPath||'sct2_Description.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.lex_sct2_rela FROM '''||pVocabularyPath||'sct2_Relationship.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      execute 'COPY sources.lex_der2_crefset_assref FROM '''||pVocabularyPath||'der2_cRefset_Association.txt'' delimiter E''\t'' csv quote E''\b'' HEADER';
      analyze sources.lex_sct2_concept;
      analyze sources.lex_sct2_desc;
      analyze sources.lex_sct2_rela;
  when 'ICD9PROCCN' then
      truncate table sources.icd9proccn_concept, sources.icd9proccn_concept_relationship;
      execute 'COPY sources.icd9proccn_concept (concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,standard_concept,concept_code,valid_start_date,valid_end_date,invalid_reason,english_concept_name) FROM '''||pVocabularyPath||'icd9proccn_concept.csv'' delimiter E''\t'' csv quote ''"'' HEADER';
      execute 'COPY sources.icd9proccn_concept_relationship FROM '''||pVocabularyPath||'icd9proccn_concept_relationship.csv'' delimiter E''\t'' csv quote ''"'' HEADER';
      update sources.icd9proccn_concept set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
  when 'CAP' then
      truncate table sources.cap_allxmlfilelist, sources.cap_xml_raw;
      alter table sources.cap_xml_raw alter column xmlfield type text; --first we need TEXT column due to UTF BOM (byte order mark)
      execute 'COPY sources.cap_allxmlfilelist FROM '''||pVocabularyPath||'cap_allxmlfilelist.dat''';
      for z in (select * from sources.cap_allxmlfilelist) loop
        /*Use PROGRAM for running 'cat' with 'tr'. 'tr' for replacing all carriage returns with space. quote E'\f' for prevent 'invalid byte sequence for encoding "UTF8"' errors,
        because xml files can contain "\..." in strings*/
        execute 'COPY sources.cap_xml_raw (xmlfield) FROM PROGRAM ''cat "'||pVocabularyPath||z||'"| tr ''''\r\n'''' '''' ''''  '' csv delimiter E''\b'' quote E''\f'' ';
      end loop;
      --remove UTF BOM
      update sources.cap_xml_raw set xmlfield=REPLACE(xmlfield,E'\xEF\xBB\xBF','');
      alter table sources.cap_xml_raw alter column xmlfield type xml using xmlfield::xml; --return proper TYPE
      update sources.cap_xml_raw set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
  when 'ICD10GM' then
      truncate table sources.icd10gm;
      execute 'COPY sources.icd10gm (concept_code,concept_name) FROM PROGRAM ''cat "'||pVocabularyPath||'icd10gm.csv"| awk -F "\"*;\"*" ''''{print $7";"$9}''''  '' delimiter '';'' csv quote ''"'' ';
      update sources.icd10gm set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      PERFORM sources_archive.AddVocabularyToArchive('ICD10GM', ARRAY['icd10gm'], COALESCE(pVocabularyDate,current_date), 'archive.icd10gm_version', 5);
  when 'CCAM' then
      truncate table sources.ccam_r_acte, sources.ccam_r_menu, sources.ccam_r_acte_ivite, sources.ccam_r_regroupement, sources.ccam_version;
      execute 'COPY sources.ccam_r_acte FROM PROGRAM ''pgdbf -TCDE -s 850 "'||pVocabularyPath||'R_ACTE.dbf" | awk "{if(NR>1)print}" ''';
      execute 'COPY sources.ccam_r_menu FROM PROGRAM ''pgdbf -TCDE -s 850 "'||pVocabularyPath||'R_MENU.dbf" | awk "{if(NR>1)print}" ''';
      execute 'COPY sources.ccam_r_acte_ivite FROM PROGRAM ''pgdbf -TCDE -s 850 "'||pVocabularyPath||'R_ACTE_IVITE.dbf" | awk "{if(NR>1)print}" ''';
      execute 'COPY sources.ccam_r_regroupement FROM PROGRAM ''pgdbf -TCDE -s 850 "'||pVocabularyPath||'R_REGROUPEMENT.dbf" | awk "{if(NR>1)print}" ''';
      execute 'COPY sources.ccam_version (vocabulary_date) FROM PROGRAM ''cat "'||pVocabularyPath||'R_ACTE.txt" | awk "{if(NR==1)print}" ''';
      update sources.ccam_version set vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      analyze sources.ccam_r_acte;
      PERFORM sources_archive.AddVocabularyToArchive('CCAM', ARRAY['ccam_r_acte','ccam_r_menu','ccam_r_acte_ivite','ccam_r_regroupement','ccam_version'], (select vocabulary_date from sources.ccam_version limit 1), 'archive.ccam_version', 5);
  when 'HEMONC' then
      truncate table sources.hemonc_cs, sources.hemonc_crs, sources.hemonc_css;
      alter table sources.hemonc_cs alter column valid_end_date type text; --dirty hack for truncating values like "2021-09-06 11-30-12" (otherwise there will be an error "time zone displacement out of range: "2021-09-06 11-30-12")

      execute 'COPY sources.hemonc_cs (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason) FROM '''||pVocabularyPath||'concept_stage.tab'' delimiter E''\t'' csv quote ''"'' FORCE NULL concept_name, vocabulary_id, concept_class_id, concept_code, valid_start_date, valid_end_date, invalid_reason HEADER';

      execute 'COPY sources.hemonc_crs (concept_id_1, concept_id_2, concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason) FROM '''||pVocabularyPath||'concept_relationship_stage.tab'' delimiter E''\t'' csv quote ''"'' FORCE NULL concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id HEADER';

      execute 'COPY sources.hemonc_css (synonym_concept_id, synonym_name, synonym_concept_code, synonym_vocabulary_id, language_concept_id, valid_start_date, valid_end_date, invalid_reason) FROM '''||pVocabularyPath||'concept_synonym_stage.tab'' delimiter E''\t'' csv quote ''"'' FORCE NULL synonym_concept_id, synonym_name, synonym_concept_code, synonym_vocabulary_id, language_concept_id, valid_start_date, valid_end_date, invalid_reason HEADER';
      update sources.hemonc_cs set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      update sources.hemonc_cs set valid_end_date=SUBSTRING(valid_end_date,'(.+)\s') where valid_end_date like '% %';
      alter table sources.hemonc_cs alter column valid_end_date type date using valid_end_date::date; --return proper type
      PERFORM sources_archive.AddVocabularyToArchive('HemOnc', ARRAY['hemonc_cs','hemonc_crs','hemonc_css'], COALESCE(pVocabularyDate,current_date), 'archive.hemonc_version', 30);
  when 'DMD' then
      truncate table sources.f_lookup2, sources.f_ingredient2, sources.f_vtm2, sources.f_vmp2, sources.f_vmpp2, sources.f_amp2, sources.f_ampp2, sources.dmdbonus;
      execute 'COPY sources.f_lookup2 (xmlfield) FROM '''||pVocabularyPath||'f_lookup2.xml'' delimiter E''\b''';
      execute 'COPY sources.f_ingredient2 FROM '''||pVocabularyPath||'f_ingredient2.xml'' delimiter E''\b''';
      execute 'COPY sources.f_vtm2 FROM '''||pVocabularyPath||'f_vtm2.xml'' delimiter E''\b''';
      execute 'COPY sources.f_vmp2 FROM '''||pVocabularyPath||'f_vmp2.xml'' delimiter E''\b''';
      execute 'COPY sources.f_vmpp2 FROM '''||pVocabularyPath||'f_vmpp2.xml'' delimiter E''\b''';
      execute 'COPY sources.f_amp2 FROM '''||pVocabularyPath||'f_amp2.xml'' delimiter E''\b''';
      execute 'COPY sources.f_ampp2 FROM '''||pVocabularyPath||'f_ampp2.xml'' delimiter E''\b''';
      execute 'COPY sources.dmdbonus FROM '''||pVocabularyPath||'dmdbonus.xml'' delimiter E''\b''';
      update sources.f_lookup2 set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      PERFORM sources_archive.AddVocabularyToArchive('dm+d', ARRAY['f_lookup2','f_ingredient2','f_vtm2','f_vmp2','f_vmpp2','f_amp2','f_ampp2','dmdbonus'], COALESCE(pVocabularyDate,current_date), 'archive.dmd_version', 30);
  when 'DM+D' then
      RAISE EXCEPTION 'Use ''DMD'' instead of %', pVocabularyID;
  when 'SOPT' then
      truncate table sources.sopt_source;
      execute 'COPY sources.sopt_source (concept_code,concept_name) FROM '''||pVocabularyPath||'sopt_source.csv'' delimiter '';'' csv quote ''"'' ';
      update sources.sopt_source set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
  when 'CIM10' then
      truncate table sources.cim10;
      ALTER TABLE sources.cim10 ALTER COLUMN xmlfield SET DATA TYPE text;
      execute 'COPY sources.cim10 (xmlfield) FROM PROGRAM ''cat "'||pVocabularyPath||'cim10.xml"| tr ''''\r\n'''' '''' ''''  '' csv delimiter E''\b'' quote E''\f'' ';
      update sources.cim10 set xmlfield=replace(xmlfield,'<!DOCTYPE ClaML SYSTEM "ClaML.dtd">',''); --PG can not work with DOCTYPE
      ALTER TABLE sources.cim10 ALTER COLUMN xmlfield SET DATA TYPE xml USING xmlfield::xml;
      update sources.cim10 set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
  when 'OMOP INVEST DRUG' then
      truncate table sources.invdrug_antineopl, sources.invdrug_pharmsub, sources.invdrug_inxight;
      execute 'COPY sources.invdrug_antineopl FROM '''||pVocabularyPath||'antineoplastic_agent.txt'' delimiter E''\t'' csv quote E''\b'' ENCODING ''ISO-8859-15'' HEADER';
      insert into sources.invdrug_pharmsub select concept_id, trim(pt), trim(sy), trim(cas_registry), trim(fda_unii_code), COALESCE(pVocabularyDate,current_date), COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date) from sources.py_xlsparse_ncit(pVocabularyPath||'/ncit_pharmsub.xlsx');
      execute 'COPY sources.invdrug_inxight FROM '''||pVocabularyPath||'dump-public.gsrs'' delimiter E''\b'' csv quote E''\f''';
      PERFORM sources_archive.AddVocabularyToArchive('OMOP Invest Drug', ARRAY['invdrug_antineopl','invdrug_pharmsub','invdrug_inxight'], COALESCE(pVocabularyDate,current_date), 'archive.omopinvestdrug_version', 30);
  when 'CIVIC' then
      truncate table sources.civic_variantsummaries_raw, sources.civic_variantsummaries;
      --CIViC has a problem with assertion_civic_urls field, it contains TABs without escaping
      execute 'COPY sources.civic_variantsummaries_raw FROM '''||pVocabularyPath||'variantsummaries.tsv'' delimiter E''\b'' csv quote E''\f'' HEADER';
      --so we just parse by TAB before this field (we don't need it and the subsequent ones)
      insert into sources.civic_variantsummaries
      select nullif(arr[1],''),nullif(arr[2],''),nullif(arr[3],''),nullif(arr[4],''),nullif(arr[5],''),nullif(arr[6],''),nullif(arr[7],''),nullif(arr[8],''),nullif(arr[9],''),nullif(arr[10],''),nullif(arr[11],''),
        nullif(arr[12],''),nullif(arr[13],''),nullif(arr[14],''),nullif(arr[15],''),nullif(arr[16],''),nullif(arr[17],''),nullif(arr[18],''),nullif(arr[19],''),nullif(arr[20],''),nullif(arr[21],''),
        nullif(arr[22],''),nullif(arr[23],''),nullif(arr[24],''),nullif(arr[25],''),nullif(arr[26],''),nullif(arr[27],''),COALESCE(pVocabularyDate,current_date),COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date) from (
        select regexp_split_to_array(civic_variantsummaries_tsv,'\t') arr from sources.civic_variantsummaries_raw
      ) s0;
      --execute 'COPY sources.civic_variantsummaries (variant_id,variant_civic_url,gene,entrez_id,variant,summary,variant_groups,chromosome,start,stop,reference_bases,variant_bases,representative_transcript,ensembl_version,reference_build,chromosome2,start2,stop2,representative_transcript2,variant_types,hgvs_expressions,last_review_date,civic_variant_evidence_score,allele_registry_id,clinvar_ids,variant_aliases,assertion_ids,assertion_civic_urls,is_flagged) FROM '''||pVocabularyPath||'variantsummaries.tsv'' delimiter E''\t'' csv quote E''\b'' HEADER';
      --update sources.civic_variantsummaries set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
      PERFORM sources_archive.AddVocabularyToArchive('CIViC', ARRAY['civic_variantsummaries'], COALESCE(pVocabularyDate,current_date), 'archive.civic_version', 10);
  when 'META' THEN
      truncate table sources.meta_mrconso, sources.meta_mrhier, sources.meta_mrmap, sources.meta_mrsmap, sources.meta_mrsat, sources.meta_mrrel, sources.meta_mrsty, sources.meta_mrdef, sources.meta_mrsab, sources.meta_ncimeme;
      drop index sources.idx_meta_mrsat_cui;
      drop index sources.idx_meta_mrconso_code;
      drop index sources.idx_meta_mrconso_cui;
      drop index sources.idx_meta_mrconso_aui;
      drop index sources.idx_meta_mrconso_sab_tty;
      drop index sources.idx_meta_mrconso_scui;
      drop index sources.idx_meta_mrsty_cui;
      drop index sources.idx_meta_mrdef_sab_cui;
      drop index sources.idx_meta_ncimeme_conceptcode;

      execute 'COPY sources.meta_mrconso FROM '''||pVocabularyPath||'MRCONSO.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.meta_mrhier FROM PROGRAM ''/var/lib/pgsql/.local/bin/csvcut --columns=1-10 --delimiter="|" "'||pVocabularyPath||'MRHIER.RRF" '' delimiter '','' csv';
      execute 'COPY sources.meta_mrmap FROM '''||pVocabularyPath||'MRMAP.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.meta_mrsmap FROM '''||pVocabularyPath||'MRSMAP.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.meta_mrsat FROM '''||pVocabularyPath||'MRSAT.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.meta_mrrel FROM '''||pVocabularyPath||'MRREL.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.meta_mrsty FROM '''||pVocabularyPath||'MRSTY.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.meta_mrdef FROM '''||pVocabularyPath||'MRDEF.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.meta_mrsab (vcui, rcui, vsab, rsab, son, sf, sver, vstart, vend, imeta, rmeta, slc, scc, srl, tfr, cfr, cxty, ttyl, atnl, lat, cenc, curver, sabin, ssn, scit, vocabulary_date) FROM '''||pVocabularyPath||'MRSAB.RRF'' delimiter ''|'' csv quote E''\b''';
      execute 'COPY sources.meta_ncimeme FROM '''||pVocabularyPath||'NCIMEME.txt'' delimiter ''|'' csv quote E''\b''';
      update sources.meta_mrsab set vocabulary_date=COALESCE(pVocabularyDate,current_date), vocabulary_version=COALESCE(pVocabularyVersion,pVocabularyID||' '||current_date);
            
      create index idx_meta_mrsat_cui on sources.meta_mrsat (cui);
      create index idx_meta_mrconso_code on sources.meta_mrconso (code);
      create index idx_meta_mrconso_cui on sources.meta_mrconso (cui);
      create index idx_meta_mrconso_aui on sources.meta_mrconso (aui);
      create index idx_meta_mrconso_sab_tty on sources.meta_mrconso (sab,tty);
      create index idx_meta_mrconso_scui on sources.meta_mrconso (scui);
      create index idx_meta_mrsty_cui on sources.meta_mrsty (cui);
      create index idx_meta_mrdef_sab_cui on sources.meta_mrdef (sab,cui);
      create index idx_meta_ncimeme_conceptcode on sources.meta_ncimeme (conceptcode);
      
      analyze sources.meta_mrconso;
      analyze sources.meta_mrhier;
      analyze sources.meta_mrmap;
      analyze sources.meta_mrsmap;
      analyze sources.meta_mrsat;
      analyze sources.meta_mrrel;
      analyze sources.meta_mrsty;
      analyze sources.meta_mrdef;
      analyze sources.meta_mrsab;
      analyze sources.meta_ncimeme;
      
      PERFORM sources_archive.AddVocabularyToArchive('META', ARRAY['meta_mrconso','meta_mrhier','meta_mrmap','meta_mrsmap','meta_mrsat','meta_mrrel','meta_mrsty','meta_mrdef','meta_mrsab','meta_ncimeme'], COALESCE(pVocabularyDate,current_date), 'archive.meta_version', 5);
    WHEN 'EORTC'
    THEN 
        TRUNCATE TABLE sources.eortc_questionnaires CASCADE;
        TRUNCATE TABLE sources.eortc_languages CASCADE;
        
        PERFORM vocabulary_download.py_load_eortc_qlq(pVocabularyPath);
        
        UPDATE sources.eortc_questionnaires
           SET vocabulary_date = pvocabularydate,
               vocabulary_version = pvocabularyversion;
               
        PERFORM sources_archive.AddVocabularyToArchive(
            'EORTC', 
            ARRAY['eortc_questionnaires', 'eortc_questions', 'eortc_question_items', 'eortc_recommended_wordings', 'eortc_languages'], 
            COALESCE(pVocabularyDate, current_date), 
            'archive.eortc_version', 
            10);
    WHEN 'ATC'
    THEN 
        TRUNCATE TABLE sources.atc_codes;
        
        INSERT INTO sources.atc_codes(
            class_code, 
            class_name, 
            ddd, 
            u, 
            adm_r, 
            note, 
            start_date, 
            revision_date, 
            active, 
            replaced_by, 
            _atc_ver)
        SELECT
            class_code::VARCHAR(7),
            class_name::VARCHAR(255),
            ddd::VARCHAR(10),
            u::VARCHAR(20),
            adm_r::VARCHAR(20),
            note::VARCHAR(255),
            start_date::DATE,
            revision_date::DATE,
            active::VARCHAR(2),
            replaced_by::VARCHAR(7),
            ver::VARCHAR(20)
        FROM vocabulary_download.py_load_atc();
        
        UPDATE sources.atc_codes
           SET vocabulary_date = pvocabularydate,
               vocabulary_version = pvocabularyversion;
        
        PERFORM sources_archive.AddVocabularyToArchive(
            'ATC', 
            ARRAY['atc_codes'], 
            COALESCE(pVocabularyDate, current_date), 
            'archive.atc_version', 
            10);
  ELSE
      RAISE EXCEPTION 'Vocabulary with id=% not found', pVocabularyID;
  END CASE;
end;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY DEFINER
COST 100;