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
* Date: 2017
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.PRODUCT;
CREATE TABLE SOURCES.PRODUCT
(
  productid                         VARCHAR(50),
  productndc                        VARCHAR(10),
  producttypename                   VARCHAR(500),
  proprietaryname                   VARCHAR(4000),
  proprietarynamesuffix             VARCHAR(126),
  nonproprietaryname                VARCHAR(4000),
  dosageformname                    VARCHAR(48),
  routename                         TEXT,
  startmarketingdate                DATE,
  endmarketingdate                  DATE,
  marketingcategoryname             VARCHAR(40),
  applicationnumber                 VARCHAR(100),
  labelername                       VARCHAR(500),
  substancename                     VARCHAR(4000),
  active_numerator_strength         VARCHAR(4000),
  active_ingred_unit                VARCHAR(4000),
  pharm_classes                     VARCHAR(4000),
  deaschedule                       VARCHAR(5),
  ndc_exclude_flag                  VARCHAR(1),
  listing_record_certified_through  DATE,
  vocabulary_date                   DATE,
  vocabulary_version                VARCHAR (200)
);

DROP TABLE IF EXISTS SOURCES.PACKAGE;
CREATE TABLE SOURCES.PACKAGE
(
  productid                         VARCHAR(50),
  productndc                        VARCHAR(10),
  ndcpackagecode                    VARCHAR(500),
  packagedescription                VARCHAR(1000),
  startmarketingdate                DATE,
  endmarketingdate                  DATE,
  ndc_exclude_flag                  VARCHAR(1),
  sample_package                    VARCHAR(1),
  pack_code                         VARCHAR(11)
);

DROP TABLE IF EXISTS SOURCES.SPL2RXNORM_MAPPINGS;
CREATE TABLE SOURCES.SPL2RXNORM_MAPPINGS
(
  setid         VARCHAR (50),
  spl_version   VARCHAR (10),
  rxcui         VARCHAR (8),
  rxstring      VARCHAR (4000),
  rxtty         VARCHAR (10)
);

DROP TABLE IF EXISTS SOURCES.ALLXMLFILELIST;
CREATE TABLE SOURCES.ALLXMLFILELIST
(
  xml_path  VARCHAR(100)
);

DROP TABLE IF EXISTS SOURCES.SPL_EXT_RAW;
CREATE TABLE SOURCES.SPL_EXT_RAW
(
  xmlfield  TEXT
);

DROP TABLE IF EXISTS SOURCES.SPL_EXT;
CREATE TABLE SOURCES.SPL_EXT
(
  concept_name      VARCHAR(4000),
  concept_code      VARCHAR(4000),
  valid_start_date  DATE,
  displayname       VARCHAR(4000),
  replaced_spl      VARCHAR(4000),
  ndc_code          VARCHAR(4000),
  low_value         VARCHAR(4000),
  high_value        VARCHAR(4000),
  is_diluent        BOOLEAN
);

DROP TABLE IF EXISTS SOURCES.SPL2NDC_MAPPINGS;
CREATE TABLE SOURCES.SPL2NDC_MAPPINGS
(
  concept_code  VARCHAR(4000),
  ndc_code      VARCHAR(4000)
);

CREATE INDEX splext_idx ON SOURCES.spl_ext (concept_code);
CREATE INDEX spl2ndc_idx ON SOURCES.spl2ndc_mappings (ndc_code);
CREATE INDEX idx_f_product ON SOURCES.product ((SUBSTR (productid, INSTR (productid, '_') + 1)));
CREATE INDEX idx_f1_product ON SOURCES.product (
	(
		CASE 
			WHEN INSTR(productndc, '-') = 5
				THEN '0' || SUBSTR(productndc, 1, INSTR(productndc, '-') - 1)
			ELSE SUBSTR(productndc, 1, INSTR(productndc, '-') - 1)
			END || CASE 
			WHEN LENGTH(SUBSTR(productndc, INSTR(productndc, '-'))) = 4
				THEN '0' || SUBSTR(productndc, INSTR(productndc, '-') + 1)
			ELSE SUBSTR(productndc, INSTR(productndc, '-') + 1)
			END
		)
	);

--We should use python functions for XML parsing because PG at this moment (9.6) can't work with huge XML
CREATE OR REPLACE FUNCTION sources.py_xmlparse_spl_mappings (
	xml_string text
)
RETURNS
TABLE (
	concept_code varchar,
	ndc_code varchar
)
AS
$BODY$
	from lxml.etree import XMLParser, fromstring
	p = XMLParser(huge_tree=True) #to prevent XML_PARSE_HUGE error
	res = []
	xmlns_uris = {'x': 'urn:hl7-org:v3'}
	xml = fromstring(xml_string, parser=p)
	concept_code = xml.xpath('/x:document/x:setId/@root',namespaces=xmlns_uris)[0]
	ndc_codes = xml.xpath('//x:containerPackagedProduct/x:code/@code|//x:containerPackagedMedicine/x:code/@code',namespaces=xmlns_uris)
	for ndc_code in ndc_codes:
		res.append((concept_code,ndc_code))
	return res
$BODY$
LANGUAGE 'plpythonu'
SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sources.py_xmlparse_spl (
	xml_string text
)
RETURNS
TABLE (
	concept_name_part varchar,
	concept_name_suffix varchar,
	concept_name_part2 varchar,
	formcode varchar,
	kit varchar,
	concept_name_clob_part varchar,
	concept_name_clob_suffix varchar,
	concept_name_clob_part2 varchar,
	formcode_clob varchar,
	concept_code varchar,
	valid_start_date varchar,
	displayname varchar,
	replaced_spl varchar,
	ndc_code varchar,
	low_value varchar,
	high_value varchar,
	ndc_root_code varchar,
	ndc_root_name varchar
)
AS
$BODY$
	from lxml.etree import XMLParser, fromstring
	p = XMLParser(huge_tree=True) #to prevent XML_PARSE_HUGE error
	res = []
	ndc_root_code_prev = None
	ndc_root_name_prev = None
	xmlns_uris = {'x': 'urn:hl7-org:v3'}
	xml = fromstring(xml_string, parser=p)
	concept_code = xml.xpath('/x:document/x:setId/@root',namespaces=xmlns_uris)[0]
	concept_name_part = xml.xpath('/x:document/x:component/x:structuredBody/x:component[1]/x:section/x:subject[1]/x:manufacturedProduct/x:*/x:name/text()',namespaces=xmlns_uris)
	concept_name_part=concept_name_part[0] if concept_name_part else ''
	concept_name_suffix = xml.xpath('/x:document/x:component/x:structuredBody/x:component[1]/x:section/x:subject[1]/x:manufacturedProduct/x:*/x:name/x:suffix/text()',namespaces=xmlns_uris)
	concept_name_suffix=concept_name_suffix[0] if concept_name_suffix else ''
	concept_name_part2 = xml.xpath('/x:document/x:component/x:structuredBody/x:component[1]/x:section/x:subject[1]/x:manufacturedProduct/x:*/x:asEntityWithGeneric/x:genericMedicine/x:name/text()',namespaces=xmlns_uris)
	concept_name_part2=concept_name_part2[0] if concept_name_part2 else ''
	formcode = xml.xpath('/x:document/x:component/x:structuredBody/x:component[1]/x:section/x:subject[1]/x:manufacturedProduct/x:*/x:formCode/@displayName',namespaces=xmlns_uris)
	formcode=formcode[0] if formcode else ''
	kit = xml.xpath('/x:document/x:component/x:structuredBody/x:component[1]/x:section/x:subject[1]/x:manufacturedProduct/x:*/x:asSpecializedKind/x:generalizedMaterialKind/x:code/@displayName',namespaces=xmlns_uris)
	kit=kit[0] if kit else ''
	concept_name_clob_part = ' '.join(set(xml.xpath('/x:document/x:component/x:structuredBody/x:component/x:section/x:subject/x:manufacturedProduct/x:*/x:name/text()',namespaces=xmlns_uris)))
	concept_name_clob_suffix = ''.join(xml.xpath('/x:document/x:component/x:structuredBody/x:component/x:section/x:subject/x:manufacturedProduct/x:*/x:name/x:suffix/text()',namespaces=xmlns_uris))
	concept_name_clob_part2 = ''.join(xml.xpath('/x:document/x:component/x:structuredBody/x:component/x:section/x:subject/x:manufacturedProduct/x:*/x:asEntityWithGeneric/x:genericMedicine/x:name/text()',namespaces=xmlns_uris))
	formcode_clob = ''.join(xml.xpath('/x:document/x:component/x:structuredBody/x:component/x:section/x:subject/x:manufacturedProduct/x:*/x:formCode/@displayName',namespaces=xmlns_uris))
	valid_start_date = xml.xpath('/x:document/x:effectiveTime[1]/@value',namespaces=xmlns_uris)[0]
	displayname = xml.xpath('/x:document/x:code/@displayName',namespaces=xmlns_uris)[0]
	replaced_spls = ';'.join(xml.xpath('//x:document/x:relatedDocument/x:relatedDocument/x:setId/@root',namespaces=xmlns_uris))
	contents = xml.xpath('//x:asContent',namespaces=xmlns_uris)
	if contents:
		for content in contents:
			#ndc_root_code=content.xpath('../../../x:manufacturedProduct/x:manufacturedProduct/x:code/@code|../../../x:manufacturedProduct/x:manufacturedMedicine/x:code/@code',namespaces=xmlns_uris)
			#ndc_root_code=content.xpath('../x:code/@code',namespaces=xmlns_uris)
			ndc_root_code=content.xpath('../../x:manufacturedProduct/x:code/@code|../../x:manufacturedMedicine/x:code/@code|../../x:partProduct/x:code/@code',namespaces=xmlns_uris)
			ndc_root_code=ndc_root_code[0] if ndc_root_code else ndc_root_code_prev
			ndc_root_code_prev=ndc_root_code
			#ndc_root_name=content.xpath('../../../x:manufacturedProduct/x:manufacturedProduct/x:name/text()|../../../x:manufacturedProduct/x:manufacturedMedicine/x:name/text()',namespaces=xmlns_uris)
			#ndc_root_name=content.xpath('../x:name/text()',namespaces=xmlns_uris)
			ndc_root_name=content.xpath('../../x:manufacturedProduct/x:name/text()|../../x:manufacturedMedicine/x:name/text()|../../x:partProduct/x:name/text()',namespaces=xmlns_uris)
			ndc_root_name=ndc_root_name[0] if ndc_root_name else ndc_root_name_prev
			ndc_root_name_prev=ndc_root_name
			ndc_code = content.xpath('./x:containerPackagedProduct/x:code/@code|./x:containerPackagedMedicine/x:code/@code',namespaces=xmlns_uris)
			ndc_code=ndc_code[0] if ndc_code else ''
			low_value = content.xpath('./x:subjectOf/x:marketingAct/x:effectiveTime/x:low/@value',namespaces=xmlns_uris)
			low_value=low_value[0] if low_value else ''
			high_value = content.xpath('./x:subjectOf/x:marketingAct/x:effectiveTime/x:high/@value',namespaces=xmlns_uris)
			high_value=high_value[0] if high_value else ''
			res.append((concept_name_part,concept_name_suffix,concept_name_part2,formcode,kit,concept_name_clob_part,concept_name_clob_suffix,concept_name_clob_part2,formcode_clob,concept_code,valid_start_date,displayname,replaced_spls,ndc_code,low_value,high_value,ndc_root_code,ndc_root_name))
	else:
		res.append((concept_name_part,concept_name_suffix,concept_name_part2,formcode,kit,concept_name_clob_part,concept_name_clob_suffix,concept_name_clob_part2,formcode_clob,concept_code,valid_start_date,displayname,replaced_spls,'','','','',''))
	return res
$BODY$
LANGUAGE 'plpythonu'
SECURITY DEFINER;