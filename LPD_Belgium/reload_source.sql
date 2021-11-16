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
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'LPD_Belgium',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.ggr_ir LIMIT 1),
	pVocabularyVersion		=> 'LPD_Belgium 2020-MARCH-01',
	pVocabularyDevSchema	=> 'dev_belg'
);
END $_$;
;
drop table if exists belg_source cascade
;
create table belg_source
	(
		prescr_prd_id varchar,
		count_rec int4,
		prod_prd_id	varchar,
		prod_prd_eid varchar,
		prd_name varchar,
		mast_prd_name varchar,
		manufacturer_name varchar,
		prd_dosage float,
		prd_dosage2 float,
		prd_dosage3 float,
		gal_id varchar,
		drug_form varchar,
		gal_id2 varchar,
		unit_id	varchar,
		unit_name1 varchar,
		unit_id2 varchar,
		unit_name2 varchar,
		unit_id3 varchar,
		unit_name3 varchar,
		mol_id varchar,
		mol_name varchar,
		concept_id int4
	)
;
-- WbImport -file=/home/ekorchmar/Documents/belgium_source2018.csv
--          -type=text
--          -table=belg_source
--          -encoding="UTF-8"
--          -header=true
--          -decode=false
--          -dateFormat="yyyy-MM-dd"
--          -timestampFormat="yyyy-MM-dd HH:mm:ss"
--          -delimiter='\t'
--          -quotechar='"'
--          -decimal=.
--          -fileColumns=prescr_prd_id,count_rec,prod_prd_id,prod_prd_eid,prd_name,mast_prd_name,manufacturer_name,prd_dosage,prd_dosage2,prd_dosage3,gal_id,drug_form,gal_id2,unit_id,unit_name1,unit_id2,unit_name2,unit_id3,unit_name3,mol_id,mol_name,concept_id
--          -quoteCharEscaping=none
--          -ignoreIdentityColumns=false
--          -deleteTarget=true
--          -continueOnError=false
--          -batchSize=2000
;
WbImport -file=C:/Users/vkomar/Downloads/prd_id(OHDSI_LPD_Belgium)_202108_with_prd_eid.txt
         -type=text
         -table=belg_source
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='|'
         -quotechar='"'
         -decimal=.
         -fileColumns=prescr_prd_id,count_rec,prod_prd_id,prod_prd_eid,prd_name,mast_prd_name,manufacturer_name,prd_dosage,prd_dosage2,prd_dosage3,gal_id,drug_form,gal_id2,unit_id,unit_name1,unit_id2,unit_name2,unit_id3,unit_name3,mol_id,mol_name,concept_id
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=false
         -continueOnError=false
         -batchSize=1000;

DROP TABLE IF EXISTS DEVICES_MAPPED;
CREATE TABLE DEVICES_MAPPED
(
    PRD_NAME    VARCHAR (255)
);
WbImport -file="/home/ekorchmar/git/Vocabulary-v5.0/LPD_Belgium/manual_work/devices_mapped.csv"
         -type=text
         -table=devices_mapped
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=prd_name
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000
;
DROP TABLE IF EXISTS BRANDS_MAPPED;
CREATE TABLE BRANDS_MAPPED
(
    PRD_NAME         VARCHAR (255),
    MAST_PRD_NAME    VARCHAR (255),
    CONCEPT_ID       INT4,
    CONCEPT_NAME     VARCHAR (255),
    VOCABULARY_ID    VARCHAR (255)
);
WbImport -file="/home/ekorchmar/git/Vocabulary-v5.0/LPD_Belgium/manual_work/brands_mapped.csv"
         -type=text
         -table=brands_mapped
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=mast_prd_name,concept_id,concept_name,vocabulary_id
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000
;
DROP TABLE IF EXISTS INGRED_MAPPED; --old mappings, serve legacy purposes
CREATE TABLE INGRED_MAPPED
(
    MOL_NAME         VARCHAR (255),
    CONCEPT_ID       INT4,
    CONCEPT_NAME     VARCHAR (255),
    VOCABULARY_ID    VARCHAR (255),
    PRECEDENCE       INT
);
WbImport -file="/home/ekorchmar/git/Vocabulary-v5.0/LPD_Belgium/manual_work/ingred_mapped.csv"
         -type=text
         -table=ingred_mapped
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=mol_name,concept_id,concept_name,vocabulary_id,precedence
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000
;
DROP TABLE IF EXISTS PRODUCTS_TO_INGREDS; -- old relations, legacy
CREATE TABLE PRODUCTS_TO_INGREDS
(
    PRD_NAME         VARCHAR (255),
    CONCEPT_ID       INT4 NOT NULL,
    CONCEPT_NAME     VARCHAR (255) NOT NULL,
    VOCABULARY_ID    VARCHAR (20) NOT NULL
);
WbImport -file="/home/ekorchmar/git/Vocabulary-v5.0/LPD_Belgium/manual_work/products_to_ingreds.csv"
         -type=text
         -table=products_to_ingreds
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=prd_name,concept_id,concept_name,vocabulary_id
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=10000
;
with ingreds_per_name as
	(
		select distinct
			prd_name,
			length (mol_name) - length (replace (mol_name,'/','')) + 1 as ic
		from belg_source
		where mol_name != 'UNKNOWN'
	)
delete from products_to_ingreds p
where p.prd_name in
	(
		select prd_name
		from products_to_ingreds
		where prd_name = p.prd_name
		group by prd_name
		having	count (distinct concept_id) !=
			(
				select ic
				from ingreds_per_name
				where prd_name = p.prd_name
			)
	)
;
drop table if exists p_to_i --update old table with new source-provided relations
;
create table p_to_i as
select distinct
	s.prod_prd_id,
	s.prd_name,
	s.mol_name,
	ing_name
from belg_source s, lateral unnest(string_to_array(s.mol_name, '/')) ing_name
where
	not exists 
		(
			select
			from devices_mapped d
			where d.prd_name = s.prd_name
		) and
	s.mol_name != 'UNKNOWN'
;
drop table if exists tomap_ingreds --manually edit this table with new mappings to apply delta
;
create table tomap_ingreds as
with I as 
	(
		select distinct ing_name from p_to_i
	)
select distinct i.ing_name, coalesce (m.concept_id, c.concept_id) as concept_id, coalesce (m.concept_name, c.concept_name) as concept_name
from I
left join ingred_mapped m on --preserve old mappings
	i.ing_name = m.mol_name
left join concept_synonym s on --guess mappings based on name
	upper (s.concept_synonym_name) = i.ing_name 
	--or upper (s.concept_synonym_name) = regexp_replace (i.ing_name,'E$','')
left join concept c on
	c.concept_id = s.concept_id and
	c.concept_class_id = 'Ingredient' and
	c.invalid_reason is null and
	c.vocabulary_id in ('RxNorm', 'RxNorm Extension')
;
delete from tomap_ingreds t
where
	t.concept_id is null and
	exists (select from tomap_ingreds where concept_id is not null and ing_name = t.ing_name)
;
alter table tomap_ingreds add precedence int4 
;
WbImport -file="/home/ekorchmar/git/Vocabulary-v5.0/LPD_Belgium/manual_work/map_ing.csv"
         -type=text
         -table=tomap_ingreds
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=ing_name,concept_id,concept_name,precedence
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000;
;
insert into products_to_ingreds
select
	p.prd_name,
	c.concept_id,
	c.concept_name,
	c.vocabulary_id
from p_to_i p
join tomap_ingreds t on
	t.ing_name = p.ing_name and
	(
		t.precedence is null or
		t.precedence = 1
	)
join concept c on
	c.concept_id = t.concept_id
;
DROP TABLE IF EXISTS SUPPLIER_MAPPED;
CREATE TABLE SUPPLIER_MAPPED
(
    MANUFACTURER_NAME    VARCHAR (255),
    CONCEPT_ID           INT4,
    CONCEPT_NAME         VARCHAR (255)
);
WbImport -file="/home/ekorchmar/git/Vocabulary-v5.0/LPD_Belgium/manual_work/suppliers_mapped.csv"
         -type=text
         -table=supplier_mapped
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter=','
         -quotechar='"'
         -decimal=.
         -fileColumns=manufacturer_name,concept_id,concept_name
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000
;
DROP TABLE IF EXISTS UNITS_MAPPED;
CREATE TABLE UNITS_MAPPED
(
    UNIT_NAME            VARCHAR (255),
    CONCEPT_ID           INT4,
    CONCEPT_NAME         VARCHAR (255),
    CONVERSION_FACTOR    FLOAT,
    PRECEDENCE           INT
);
WbImport -file="/home/ekorchmar/git/Vocabulary-v5.0/LPD_Belgium/manual_work/units_mapped.csv"
         -type=text
         -table=units_mapped
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=unit_name,concept_id,concept_name,conversion_factor,precedence
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000
;
DROP TABLE IF EXISTS FORMS_MAPPED;
CREATE TABLE FORMS_MAPPED
(
    DRUG_FORM       VARCHAR (255),
    CONCEPT_ID      INT4,
    CONCEPT_NAME    VARCHAR (255),
    PRECEDENCE      INT
);
WbImport -file="/home/ekorchmar/git/Vocabulary-v5.0/LPD_Belgium/manual_work/forms.csv"
         -type=text
         -table=forms_mapped
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=drug_form,concept_id,concept_name,precedence
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000;
;
drop table if exists DS_MANUAL;
CREATE TABLE DS_MANUAL
(
    COUNT                INT,
    PRD_ID               INT,
    PRD_NAME             VARCHAR (255),
    CONCEPT_ID           INT,
    CONCEPT_NAME         VARCHAR (255),
    AMOUNT_VALUE         FLOAT,
    AMOUNT_UNIT          VARCHAR (255),
    DENOMINATOR_VALUE    FLOAT,
    DENOMINATOR_UNIT     VARCHAR (255),
    BOX_SIZE             INT
);
WbImport -file="/home/ekorchmar/git/Vocabulary-v5.0/LPD_Belgium/manual_work/ds_manual.csv"
         -type=text
         -table=ds_manual
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns="count",prd_id,prd_name,concept_id,concept_name,amount_value,amount_unit,denominator_value,denominator_unit,box_size
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000;
drop table if exists lost_ing
;
CREATE TABLE LOST_ING
(
    PRD_ID        VARCHAR (255),
    PRD_NAME      VARCHAR (255),
    CONCEPT_ID    INT4
);
WbImport -file="/home/ekorchmar/git/Vocabulary-v5.0/LPD_Belgium/manual_work/no_ing.csv"
         -type=text
         -table=lost_ing
         -encoding="UTF-8"
         -header=true
         -decode=false
         -dateFormat="yyyy-MM-dd"
         -timestampFormat="yyyy-MM-dd HH:mm:ss"
         -delimiter='\t'
         -quotechar='"'
         -decimal=.
         -fileColumns=prd_id,prd_name,concept_id
         -quoteCharEscaping=none
         -ignoreIdentityColumns=false
         -deleteTarget=true
         -continueOnError=false
         -batchSize=1000;
;
DROP TABLE IF EXISTS DRUG_CONCEPT_STAGE cascade;
CREATE TABLE DRUG_CONCEPT_STAGE
(
   CONCEPT_NAME              VARCHAR(255),
   VOCABULARY_ID             VARCHAR(20),
   CONCEPT_CLASS_ID          VARCHAR(25),
   SOURCE_CONCEPT_CLASS_ID   VARCHAR(25),
   STANDARD_CONCEPT          VARCHAR(1),
   CONCEPT_CODE              VARCHAR(50),
   POSSIBLE_EXCIPIENT        VARCHAR(1),
   DOMAIN_ID                 VARCHAR(25),
   VALID_START_DATE          DATE,
   VALID_END_DATE            DATE,
   INVALID_REASON            VARCHAR(1)
);

DROP TABLE IF EXISTS DS_STAGE;
CREATE TABLE DS_STAGE
(
   DRUG_CONCEPT_CODE        VARCHAR(255),
   INGREDIENT_CONCEPT_CODE  VARCHAR(255),
   BOX_SIZE                 INT4,
   AMOUNT_VALUE             FLOAT,
   AMOUNT_UNIT              VARCHAR(255),
   NUMERATOR_VALUE          FLOAT,
   NUMERATOR_UNIT           VARCHAR(255),
   DENOMINATOR_VALUE        FLOAT,
   DENOMINATOR_UNIT         VARCHAR(255)
);

DROP TABLE IF EXISTS INTERNAL_RELATIONSHIP_STAGE;
CREATE TABLE INTERNAL_RELATIONSHIP_STAGE
(
   CONCEPT_CODE_1     VARCHAR(50),
   CONCEPT_CODE_2     VARCHAR(50)
);

DROP TABLE IF EXISTS RELATIONSHIP_TO_CONCEPT;
CREATE TABLE RELATIONSHIP_TO_CONCEPT
(
   CONCEPT_CODE_1     VARCHAR(255),
   VOCABULARY_ID_1    VARCHAR(20),
   CONCEPT_ID_2       INTEGER,
   PRECEDENCE         INTEGER,
   CONVERSION_FACTOR  FLOAT
);

DROP TABLE IF EXISTS PC_STAGE;
CREATE TABLE PC_STAGE
(
   PACK_CONCEPT_CODE  VARCHAR(255),
   DRUG_CONCEPT_CODE  VARCHAR(255),
   AMOUNT             FLOAT,
   BOX_SIZE           INT4
);
drop table if exists official_mappings
;
--get mappings from GGR vocabulary
create table official_mappings as
select
	a.prod_prd_id,
	cr.concept_id_2 as concept_id
from belg_source a
join concept c0 on
	c0.vocabulary_id = 'GGR' and
	(
		c0.concept_code = 'mpp' ||  to_char (prod_prd_eid :: int4, 'fm0000000') or
		c0.concept_code = to_char (prod_prd_eid :: int4, 'fm0000000')
	)
join concept_relationship cr on
	cr.concept_id_1 = c0.concept_id and
	cr.invalid_reason is null and
	cr.relationship_id = 'Maps to'
;
--find dublicates by name
insert into official_mappings
select distinct  b.prod_prd_id, o.concept_id
from belg_source b
join belg_source x on
	x.prd_name = b.prd_name and
	x.prod_prd_id != b.prod_prd_id
join official_mappings o on
	o.prod_prd_id = x.prod_prd_id
where 
	b.prod_prd_id not in
	(
		select prod_prd_id
		from official_mappings
	)
;
--preserve existing mappings, if not mapped in official
insert into official_mappings
select distinct
	a.prod_prd_id,
	r.concept_id_2
from belg_source a
join concept c on
	c.vocabulary_id = 'LPD_Belgium' and
	c.concept_code = a.prod_prd_id
join concept_relationship r on
	r.concept_id_1 = c.concept_id and
	r.relationship_id = 'Maps to' and
	r.invalid_reason is null
join concept c2 on
	c2.concept_id = r.concept_id_2 and
	c2.concept_class_id != 'Ingredient'
-- we trust already made official mappings more
left join official_mappings o using (prod_prd_id)
where o.prod_prd_id is null
;
--find dublicates by name
insert into official_mappings
select distinct b.prod_prd_id, o.concept_id
from belg_source b
join belg_source x on
	x.prd_name = b.prd_name and
	x.prod_prd_id != b.prod_prd_id
join official_mappings o on
	o.prod_prd_id = x.prod_prd_id
where 
	b.prod_prd_id not in
	(
		select prod_prd_id
		from official_mappings
	)
;
delete from official_mappings m
where exists
	(
		select
		from official_mappings o
		join concept x on
			m.concept_id = x.concept_id
		join concept y on
			o.concept_id = y.concept_id and
			x.valid_start_date > y.valid_start_date
		where
			m.prod_prd_id = o.prod_prd_id and
			m.concept_id != o.concept_id
	)
;
delete from belg_source b --only delta gets to be mapped
where exists (select from official_mappings where prod_prd_id = b.prod_prd_id)
;
delete from map_drug 
where
	from_code in
		( 
			select prod_prd_id
			from official_mappings
		)
;
insert into devices_mapped
select prd_name
from belg_source_full 
where 
	regexp_match (prd_name,'[0-9 ]+(CM|MM|M)? ?X ?[0-9 ]+(CM|MM|M)[ $]') is not null or -- 00 MM X 00 MM
	prd_name like '% PANTS %' or
	(prd_name like '%SHAMPOO%' and mol_name = 'UNKNOWN') or
	regexp_match (prd_name,'\d{2,} ?G$') is not null or
	prd_name like '%ROUL%' or
	prd_name like '%TROUSSE%' or
	prd_name like 'BOTA%' or
	prd_name like '%COMPRESS%' or
	prd_name like '%VALVE%' or
	prd_name like '%BAND%' or
	prd_name like '%ACCESSOIRE%' or
	prd_name like '%COLLIER%' or
	prd_name like '%CM %' or
	prd_name like '%LATEX%' or
	prd_name like '%TALC%' or
	prd_name like '%STRIP%' or
	--suppliers
	prd_name like '%UNDA' or
	prd_name like '%BOIRON%' or
	prd_name like '%HEEL' or
	prd_name like 'WELEDA%' or
	prd_name like '%HOMEOROPA%' or
	manufacturer_name like 'HEEL %' or
	manufacturer_name like 'BOIRON %' or
	--Brands (nutrition, devices)
	prd_name like '%CALDYN%' or
	prd_name like '%SOUVENAID%' or
	prd_name like '%ACTIMOVE%' or
	prd_name like 'PUSH %' or
	prd_name like '%FORTIMEL%' or
	prd_name like '2L%' or
	prd_name like 'AEROCHAMBER%'
;
--select * from belg_source
;
INSERT INTO drug_concept_stage --devices
SELECT distinct
	d.prd_name,
	'LPD_Belgium' AS vocabulary_id,
	'Device' AS concept_class_id,
	NULL AS source_concept_class_id,
	'S' AS standard_concept,
	d.prod_prd_id AS concept_code,
	NULL AS possible_excipient,
	'Device' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM belg_source_full d
JOIN devices_mapped m ON m.prd_name = d.prd_name;


INSERT INTO drug_concept_stage --drugs
SELECT d.prd_name,
	'LPD_Belgium' AS vocabulary_id,
	'Drug Product' AS concept_class_id,
	NULL AS source_concept_class_id,
	'S' AS standard_concept,
	d.prod_prd_id AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM belg_source_full d
WHERE prd_name NOT IN (
		SELECT prd_name
		FROM devices_mapped
		)
;
DROP SEQUENCE IF EXISTS conc_stage_seq;
CREATE sequence conc_stage_seq MINVALUE 100 MAXVALUE 1000000 START
	WITH 100 INCREMENT BY 1 CACHE 20;

INSERT INTO drug_concept_stage --bn
SELECT NAME,
	'LPD_Belgium' AS vocabulary_id,
	'Brand Name' AS concept_class_id,
	NULL AS source_concept_class_id,
	NULL AS standard_concept,
	'OMOP' || nextval('conc_stage_seq') AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT DISTINCT coalesce(mast_prd_name, concept_name) AS NAME
	FROM brands_mapped
	) AS s0;

INSERT INTO drug_concept_stage
WITH units AS --units
	(
		SELECT UNIT_NAME1 AS NAME
		FROM belg_source_full d
		
		UNION
		
		SELECT UNIT_NAME2 AS NAME
		FROM belg_source_full d
		
		UNION
		
		SELECT UNIT_NAME3 AS NAME
		FROM belg_source_full d
		
		union
		
		select 'actuat'
		)
SELECT distinct NAME,
	'LPD_Belgium' AS vocabulary_id,
	'Unit' AS concept_class_id,
	NULL AS source_concept_class_id,
	NULL AS standard_concept,
	NAME AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM units
WHERE NAME IS NOT NULL;

INSERT INTO drug_concept_stage --dose form
SELECT DISTINCT drug_form,
	'LPD_Belgium' AS vocabulary_id,
	'Dose Form' AS concept_class_id,
	NULL AS source_concept_class_id,
	NULL AS standard_concept,
	CONCAT (
		'g',
		gal_id
		),
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM belg_source_full
WHERE gal_id NOT IN (
		'-1',
		'28993'
		)-- unknown or IUD
;
INSERT INTO internal_relationship_stage --brands
SELECT d.prod_prd_id,
	c.concept_code
FROM belg_source_full d
JOIN brands_mapped p ON d.prd_name = p.prd_name
JOIN drug_concept_stage c ON c.concept_name = p.concept_name
	AND concept_class_id = 'Brand Name'
WHERE d.prd_name NOT IN (
		SELECT prd_name
		FROM devices_mapped
		)
;
INSERT INTO relationship_to_concept --brands
SELECT DISTINCT d.concept_code,
	'LPD_Belgium' AS vocabulary_id,
	c.concept_id,
	1::INT,
	NULL::FLOAT
FROM brands_mapped c
JOIN drug_concept_stage d ON d.concept_class_id = 'Brand Name'
	AND coalesce(c.mast_prd_name, c.concept_name) = d.concept_name
	and c.concept_id != 0	
;
--insert new ingredients from concept tables after brands are mapped
with branded as
	(
		select b.prd_name, b.mast_prd_name, c.concept_id, c.concept_name
		from belg_source b 
		join drug_concept_stage s on
			b.mol_name = 'UNKNOWN' and 
			b.mast_prd_name is not null and
			b.mast_prd_name = s.concept_name and
			s.concept_class_id = 'Brand Name'
		join relationship_to_concept r on
			r.concept_code_1 = s.concept_code and
			(
				r.precedence is null or
				r.precedence = 1
			)
		join concept c on
			c.concept_id = r.concept_id_2
		left join devices_mapped d using (prd_name)
		left join products_to_ingreds x on
			x.prd_name = b.prd_name
		where 
			x.concept_id is null and
			d.prd_name is null
	),
b2i as
	(
		select distinct b.prd_name, c.concept_id --ingredients *should* be the same among all the drugs under same brand name
		from branded b
		join concept_relationship cr on
			cr.concept_id_1 = b.concept_id and
			cr.relationship_id = 'Brand name of' and
			cr.invalid_reason is null
		join concept c on
			c.invalid_reason is null and
			c.concept_id = cr.concept_id_2 and
			c.concept_class_id = 'Ingredient'
	)
insert into products_to_ingreds
select distinct
	b.prd_name,
	c.concept_id,
	c.concept_name,
	c.vocabulary_id	
from b2i b
join concept c on
	c.concept_id = b.concept_id and
	c.concept_class_id = 'Ingredient'
;
--guess new ingredients from names
create or replace view remaining as
select *
from belg_source 
where 
	prd_name not in 
	(
		select prd_name 
		from products_to_ingreds
	) and
	prd_name not in --device or manually done in legacy
		(
			select prd_name 
			from devices_mapped 
			
				union all 
				
			select prd_name
			from lost_ing
		)
;
drop table if exists regex_ing
;
create table regex_ing as
with ingreds as
	(
		select concept_id, upper(concept_name) as concept_name
		from concept
		where
			concept_class_id = 'Ingredient' and
			vocabulary_id in ('RxNorm','RxNorm Extension') and
			standard_concept = 'S'
			
			union
		
		select concept_id, trim (upper(regexp_replace (concept_name,'e($| )',' ','i'))) -- replace E at end of each word
		from concept
		where
			concept_class_id = 'Ingredient' and
			vocabulary_id in ('RxNorm','RxNorm Extension') and
			standard_concept = 'S'
	)
select r.count_rec, r.prd_name, i.*
from remaining r
join ingreds i on
	position ( (i.concept_name) in r.prd_name) != 0 and
	length (i.concept_name) > 3 and
	i.concept_id not in 
		(
			40798873,36878634,40799093,906914,
			19025274,19011034,19124906,19066891,
			19018544,718583,19076389,43012233,
			43012239,1312007,911891,19010309,
			19066774,42900468,1360067,43012267,
			42898385,44785045,44785061,42899196,
			19124477,44818494,44818483,1718473,
			44012699,36878993,36878926,1510528,
			19029306,19126511,44012589,19009540,
			1037015
		)
;
delete from regex_ing r --remove atom where salt is present
where exists
	(
		select
		from regex_ing
		where
			prd_name = r.prd_name and
			position (lower (r.concept_name) in lower (concept_name)) != 0 and
			r.concept_name != concept_name
	)
;
insert into products_to_ingreds
select 
	r.prd_name,
	c.concept_id,
	c.concept_name,
	c.vocabulary_id
from regex_ing r
join concept c using (concept_id)
;
drop view remaining
;
update products_to_ingreds --Sodium => Sodium Chloride
set
	concept_id = 967823,
	concept_name = 'Sodium Chloride'
where
	concept_id = 19136048
;
INSERT INTO drug_concept_stage --ingredients: now that products_to_ingreds is formed
SELECT TRIM(NAME),
	'LPD_Belgium' AS vocabulary_id,
	'Ingredient' AS concept_class_id,
	NULL AS source_concept_class_id,
	'S' AS standard_concept,
	'OMOP' || nextval('conc_stage_seq') AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT DISTINCT concept_name AS NAME
	FROM products_to_ingreds
	) AS s0;
;
INSERT INTO internal_relationship_stage --ingreds
SELECT d.prod_prd_id,
	c.concept_code
FROM belg_source_full d
JOIN products_to_ingreds p ON d.prd_name = p.prd_name
JOIN drug_concept_stage c ON c.concept_name = p.concept_name
	AND concept_class_id = 'Ingredient'
WHERE d.prd_name NOT IN (
		SELECT prd_name
		FROM devices_mapped
		);

/*DELETE
FROM internal_relationship_stage
WHERE concept_code_2 = 'OMOP3380918'
	AND concept_code_1 IN (
		'10541251',
		'10541252'
		);*/

INSERT INTO internal_relationship_stage --dose forms
SELECT DISTINCT d.prod_prd_id,
	CONCAT (
		'g',
		d.gal_id
		)
FROM belg_source_full d
WHERE d.prd_name NOT IN (
		SELECT prd_name
		FROM devices_mapped
		)
	AND d.gal_id NOT IN (
		'-1',
		'28993'
		);

INSERT INTO drug_concept_stage --Suppliers
SELECT MANUFACTURER_NAME,
	'LPD_Belgium' AS vocabulary_id,
	'Supplier' AS concept_class_id,
	NULL AS source_concept_class_id,
	'S' AS standard_concept,
	'OMOP' || nextval('conc_stage_seq') AS concept_code,
	NULL AS possible_excipient,
	'Drug' AS domain_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT DISTINCT MANUFACTURER_NAME
	FROM supplier_mapped
	) AS s0;

INSERT INTO internal_relationship_stage --suppliers
SELECT DISTINCT d.prod_prd_id,
	c.concept_code
FROM belg_source d
JOIN drug_concept_stage c ON c.concept_class_id = 'Supplier'
	AND c.concept_name = d.manufacturer_name
WHERE d.prd_name NOT IN (
		SELECT prd_name
		FROM devices_mapped
		)
	AND d.gal_id != '-1';

DELETE
FROM drug_concept_stage
WHERE concept_class_id = 'Unit'
	AND concept_code = 'unknown'
;
INSERT INTO ds_stage
WITH a AS (
		SELECT prd_name
		FROM products_to_ingreds
		GROUP BY prd_name
		HAVING count(distinct concept_id) = 1
		),
	SIMPLE AS (
		SELECT d.*
		FROM belg_source d
		JOIN a ON a.prd_name = d.prd_name
		WHERE (
				d.prd_dosage != '0'
				OR d.prd_dosage2 != '0'
				OR d.prd_dosage3 != '0'
				)
			AND d.unit_name1 NOT LIKE '%!%%' ESCAPE '!'
			AND (
				d.unit_name1 NOT LIKE '%/%'
				OR unit_name1 = '% v/v'
				)
			AND d.prd_name NOT IN (
				SELECT *
				FROM devices_mapped
				)
		),
	percents AS (
		SELECT d.*
		FROM belg_source d
		JOIN a ON a.prd_name = d.prd_name
		WHERE (
				d.prd_dosage != '0'
				OR d.prd_dosage2 != '0'
				OR d.prd_dosage3 != '0'
				)
			AND d.unit_name1 = '%'
			AND d.prd_name NOT IN (
				SELECT *
				FROM devices_mapped
				)
		),
	transderm AS (
		SELECT d.*
		FROM belg_source d
		JOIN a ON a.prd_name = d.prd_name
		WHERE (
				d.prd_dosage != '0'
				OR d.prd_dosage2 != '0'
				OR d.prd_dosage3 != '0'
				)
			AND d.unit_name1 LIKE 'm_g/%h'
			AND d.prd_name NOT IN (
				SELECT *
				FROM devices_mapped
				)
		)
SELECT c1.concept_code AS drug_concept_code,
	c2.concept_code AS ingredient_concept_code,
	NULL::INT AS box_size,
	/*replace(SIMPLE.prd_dosage, ',', '.')::FLOAT*/prd_dosage AS amount_value,
	SIMPLE.unit_name1 AS amount_unit,
	NULL AS numerator_value,
	NULL AS numerator_unit,
	NULL AS denominator_value,
	NULL AS denominator_unit
FROM SIMPLE
JOIN drug_concept_stage c1 ON SIMPLE.prd_name = c1.concept_name
	AND concept_class_id = 'Drug Product'
JOIN products_to_ingreds p ON p.prd_name = SIMPLE.prd_name
JOIN drug_concept_stage c2 ON p.concept_name = c2.concept_name

UNION

SELECT c1.concept_code AS drug_concept_code,
	c2.concept_code AS ingredient_concept_code,
	NULL AS box_size,
	NULL AS amount_value,
	NULL AS amount_unit,
	10 * percents.prd_dosage /*(replace(percents.prd_dosage, ',', '.')::FLOAT)*/ AS numerator_value,
	'mg' AS denominator_unit, --mg
	1::FLOAT AS numerator_value,
	'ml' AS denominator_unit --ml
FROM percents
JOIN drug_concept_stage c1 ON percents.prd_name = c1.concept_name
	AND concept_class_id = 'Drug Product'
JOIN products_to_ingreds p ON p.prd_name = percents.prd_name
JOIN drug_concept_stage c2 ON p.concept_name = c2.concept_name

UNION

SELECT c1.concept_code AS drug_concept_code,
	c2.concept_code AS ingredient_concept_code,
	NULL AS box_size,
	transderm.prd_dosage/*replace(transderm.prd_dosage, ',', '.')::FLOAT*/ AS amount_value,
	CASE 
		WHEN transderm.unit_id LIKE 'mg%'
			THEN 'mg' --mg
		ELSE 'mcg' --mcg
		END AS amount_unit,
	NULL AS numerator_value,
	NULL AS denominator_unit,
	NULL AS numerator_value,
	NULL AS denominator_unit
FROM transderm
JOIN drug_concept_stage c1 ON transderm.prd_name = c1.concept_name
	AND concept_class_id = 'Drug Product'
JOIN products_to_ingreds p ON p.prd_name = transderm.prd_name
JOIN drug_concept_stage c2 ON p.concept_name = c2.concept_name;

INSERT INTO relationship_to_concept --ingredients
SELECT DISTINCT d.concept_code,
	'LPD_Belgium' AS vocabulary_id,
	c.concept_id,
	coalesce (c.precedence,1),
	NULL::FLOAT AS conversion_factor
FROM ingred_mapped c
JOIN drug_concept_stage d ON d.concept_class_id = 'Ingredient'
	AND d.concept_name = c.concept_name
	and c.concept_id != 0

	union

SELECT DISTINCT d.concept_code,
	'LPD_Belgium' AS vocabulary_id,
	c.concept_id,
	1 as precedence,
	NULL::FLOAT AS conversion_factor
FROM products_to_ingreds c
JOIN drug_concept_stage d ON d.concept_class_id = 'Ingredient'
	AND d.concept_name = c.concept_name
	and c.concept_id != 0
;
INSERT INTO relationship_to_concept --units
SELECT DISTINCT d.concept_code,
	'LPD_Belgium' AS vocabulary_id,
	c.concept_id,
	coalesce (c.precedence,1),
	coalesce (c.conversion_factor,1)
FROM drug_concept_stage d
JOIN units_mapped c ON d.concept_class_id = 'Unit'
	AND d.concept_name = c.unit_name
	and c.concept_id != 0	
;

INSERT INTO relationship_to_concept --forms
SELECT DISTINCT d.concept_code,
	'LPD_Belgium' AS vocabulary_id,
	c.concept_id,
	coalesce (c.precedence,1),
	NULL::FLOAT
FROM drug_concept_stage d
JOIN forms_mapped c ON d.concept_class_id = 'Dose Form'
	AND d.concept_name = c.drug_form
	and c.concept_id != 0
;
delete 
FROM internal_relationship_stage --redundant elemental atoms
WHERE 
	concept_code_2 IN 
		(
			SELECT d.concept_code
			FROM concept c
			JOIN drug_concept_stage d ON
				d.concept_name = c.concept_name
			WHERE concept_id IN 
				(
					19136048,
					36878798,
					19049024,
					1036525,
					19125390,
					1394027,
					19066891,
					19010961,
					42899013,
					42899196,
					19043395,
					36878798
				)
		)
	and concept_code_1 not in --not only ingredient
		(
			select concept_code_1
			from drug_concept_stage, internal_relationship_stage
			where 
				concept_code_2 = concept_code and
				concept_class_id = 'Ingredient'
			group by concept_code_1
			having count (distinct concept_code_2) = 1
		)
;
INSERT INTO relationship_to_concept
SELECT DISTINCT d.concept_code,
	'LPD_Belgium' AS vocabulary_id,
	c.concept_id,
	NULL::INT,
	NULL::FLOAT
FROM drug_concept_stage d
JOIN supplier_mapped c ON d.concept_class_id = 'Supplier'
	AND d.concept_name = c.manufacturer_name
WHERE c.concept_name IS NOT NULL
;
INSERT INTO internal_relationship_stage
SELECT DISTINCT prod_prd_id,
	CASE 
		WHEN prd_name LIKE '%INJECT%'
			OR prd_name LIKE '%SERINGU%'
			OR prd_name LIKE '%STYLO%'
			OR prd_name LIKE '% INJ %'
			THEN 'g29010' --solution injectable
		WHEN prd_name LIKE '%SOLUTION%'
			OR prd_name LIKE '%AMPOULES%'
			OR prd_name LIKE '%GOUTTES%'
			OR prd_name LIKE '%GUTT%'
			THEN 'g28919' --solution
		WHEN prd_name LIKE '%POUR SUSPE%'
			THEN 'g29027' --suspension
		WHEN prd_name LIKE '%COMPRI%'
			OR prd_name LIKE '%TABS %'
			OR prd_name LIKE '% DRAG%'
			THEN 'g28901' --compr.
		WHEN prd_name LIKE '%POUDRE%'
			OR prd_name LIKE '% PDR %'
			THEN 'g28929' --poudre(s)
		WHEN prd_name LIKE '%GELUL%'
			OR prd_name LIKE '%CAPS %'
			or (prd_name like '% GEL %' and prd_name not like '%ML%' and regexp_match (prd_name,' \d*G( |$)') is null)
			THEN 'g29033' --compr. enrob.
		WHEN prd_name LIKE '%SPRAY%'
			THEN 'g28926' --spray
		WHEN prd_name LIKE '%CREME%'
			OR prd_name LIKE '%CREAM%'
			THEN 'g28920' --crème
		WHEN prd_name LIKE '%LAVEMENTS%'
			OR prd_name LIKE '%LAVEMENTS%'
			THEN 'g28909' --suppos.
		WHEN prd_name LIKE '%POMM%'
			THEN 'g28910' --pommade
		WHEN prd_name LIKE '%INHALAT%'
			THEN 'g28988' --inhalation
		WHEN prd_name LIKE '%EFFERVESCENTS%'
			OR prd_name LIKE '%AMP%'
			THEN 'g28919' --solution
		WHEN prd_name LIKE '% COMP%'
			OR prd_name LIKE '%TAB%'
			THEN 'g28901' --compr.
		WHEN prd_name LIKE '%PERFUS%'
			THEN 'g28987' --solution pour perfusion
		WHEN prd_name LIKE '%BUCCAL%'
			or prd_name like '%SIROP%'
			THEN 'g29009' --solution buvable
		ELSE 'boo'
		END
FROM belg_source
WHERE prod_prd_id NOT IN (
		SELECT concept_code_1
		FROM internal_relationship_stage
		WHERE concept_code_2 LIKE 'g%' --dose forms
		)
	AND prd_name NOT IN (
		SELECT *
		FROM devices_mapped
		);

DELETE
FROM internal_relationship_stage
WHERE concept_code_2 = 'boo';
--add ds entries from parsed names

DROP TABLE IF EXISTS map_auto;
CREATE TABLE map_auto AS
	WITH unmapped AS (
			SELECT DISTINCT 
				d.count_rec,
				d.prod_prd_id,
				replace (regexp_replace(d.prd_name, ' (\d+) (\d+ ?(MG|MCG|G|UI|IU))', ' \1.\2', 'g'),'X',' ') AS fixed_name,
				c.concept_id,
				c.concept_name
			FROM belg_source d
			LEFT JOIN prod_to_ind c ON c.prod_prd_id = d.prod_prd_id
			WHERE prod_prd_id NOT IN (
					SELECT drug_concept_code
					FROM ds_stage
					)
				AND d.prd_name NOT IN (
					SELECT *
					FROM devices_mapped
					)
				AND regexp_match (d.prd_name, '(X| )\d+ ?(MCG|MG|G)( |$)') is not null
				AND c.concept_id IS NOT NULL
				AND (ARRAY(SELECT unnest(regexp_matches(d.prd_name, '((?:\d+)\.?(?:\d+)? ?(?:MCG|MG|G|UI|IU) )', 'g')))) [3] IS NULL
			),
		list AS ( --only 1 or 2 ingredient drugs can be processed this way; more is rarely needed
			SELECT prod_prd_id
			FROM unmapped
			GROUP BY prod_prd_id
			HAVING count(concept_id) < 3
			)

SELECT DISTINCT u.count_rec,
	u.prod_prd_id,
	u.fixed_name,
	--amount 1
	regexp_replace(substring(u.fixed_name, '((\d+)?\.?(\d+ ?(MG|MCG|G|UI|IU))( |$))'), '[A-Z ]', '', 'g')::FLOAT AS a1,
	--unit 1
	lower(substring(u.fixed_name, '(?:\d+)?\.?(?:\d+ ?(MG|MCG|G|UI|IU))( |$)')) AS u1,
	--amount 2
	regexp_replace((ARRAY(SELECT unnest(regexp_matches(u.fixed_name, '((?:\d+)\.?(?:\d+ ?(?:MCG|MG|G|UI|IU)))', 'g')))) [2], '[A-Z ]', '', 'g')::FLOAT AS a2,
	--unit 2
	lower(substring((ARRAY(SELECT unnest(regexp_matches(u.fixed_name, '((?:\d+)\.?(?:\d+ ?(?:MCG|MG|G|UI|IU)))', 'g')))) [2], '[A-Z]+')) AS u2,
	min(u.concept_id) OVER (PARTITION BY u.prod_prd_id) AS i1,
	max(u.concept_id) OVER (PARTITION BY u.prod_prd_id) AS i2
FROM unmapped u
WHERE prod_prd_id IN (
		SELECT *
		FROM list
		);

UPDATE map_auto
SET i2 = NULL
WHERE i1 = i2;

ALTER TABLE map_auto ADD UC1 INT,
	ADD UC2 INT;

UPDATE map_auto
SET u1 = 'IU'
WHERE u1 = 'iu';

UPDATE map_auto
SET u2 = 'IU'
WHERE u2 = 'iu';

UPDATE map_auto
SET uc1 = 8504
WHERE u1 = 'g';

UPDATE map_auto
SET uc1 = 8576
WHERE u1 = 'mg';

UPDATE map_auto
SET uc1 = 9655
WHERE u1 = 'mcg';

UPDATE map_auto
SET uc1 = 8718
WHERE u1 = 'IU';

UPDATE map_auto
SET uc2 = 8504
WHERE u2 = 'g';

UPDATE map_auto
SET uc2 = 8576
WHERE u2 = 'mg';

UPDATE map_auto
SET uc2 = 9655
WHERE u2 = 'mcg';

UPDATE map_auto
SET uc2 = 8718
WHERE u2 = 'IU';

INSERT INTO ds_stage
SELECT m.prod_prd_id,
	d.concept_code,
	NULL,
	A1,
	U1,
	NULL,
	NULL,
	NULL,
	NULL
FROM map_auto m
JOIN concept c ON m.i1 = c.concept_id
JOIN drug_concept_stage d ON c.concept_name = d.concept_name
	AND d.concept_class_id = 'Ingredient'
WHERE a2 IS NULL
	AND i2 IS NULL
;
delete from internal_relationship_stage
where (concept_code_1,concept_code_2) in
	(
		select concept_code_1, concept_code_2
		FROM internal_relationship_stage
		JOIN drug_concept_stage ON concept_code_2 = concept_code
			AND concept_class_id = 'Supplier'
		LEFT JOIN ds_stage ON drug_concept_code = concept_code_1
		WHERE drug_concept_code IS NULL
	)
;
--to pass qa faster
delete from drug_concept_stage 
where 
	concept_code not in (select concept_code_2 from internal_relationship_stage) and
	concept_class_id in ('Ingredient', 'Dose Form', 'Brand Name', 'Supplier')
;
delete from drug_concept_stage
where concept_code not in
	(
		select amount_unit from ds_stage where amount_unit is not null union
		select numerator_unit from ds_stage where numerator_unit is not null union
		select denominator_unit from ds_stage where denominator_unit is not null
	)
and concept_class_id = 'Unit'
;
drop table if exists irs_shuffle
;
create table irs_shuffle as
select distinct
	concept_code_1,
	concept_code_2
from internal_relationship_stage
;
drop table internal_relationship_stage
;
alter table irs_shuffle
rename to internal_relationship_stage
;
DO $$
DECLARE
	ex INTEGER;
BEGIN
	SELECT MAX(replace(concept_code, 'OMOP','')::int4)+1 into ex FROM devv5.concept WHERE concept_code like 'OMOP%'  and concept_code not like '% %';
	DROP SEQUENCE IF EXISTS new_vocab;
	EXECUTE 'CREATE SEQUENCE new_vocab INCREMENT BY 1 START WITH ' || ex || ' NO CYCLE CACHE 20';
END;$$
;


DROP TABLE IF EXISTS code_replace;
CREATE TABLE code_replace AS
SELECT 'OMOP' || nextval('new_vocab') AS new_code,
	concept_code AS old_code
FROM (
	SELECT concept_code
	FROM drug_concept_stage
	WHERE concept_code LIKE 'OMOP%'
	GROUP BY concept_code
	ORDER BY LPAD(concept_code, 50, '0')
	) AS s0;

UPDATE drug_concept_stage a
SET concept_code = b.new_code
FROM code_replace b
WHERE a.concept_code = b.old_code;

UPDATE relationship_to_concept a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE ds_stage a
SET ingredient_concept_code = b.new_code
FROM code_replace b
WHERE a.ingredient_concept_code = b.old_code;

UPDATE ds_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_1 = b.new_code
FROM code_replace b
WHERE a.concept_code_1 = b.old_code;

UPDATE internal_relationship_stage a
SET concept_code_2 = b.new_code
FROM code_replace b
WHERE a.concept_code_2 = b.old_code;

UPDATE pc_stage a
SET drug_concept_code = b.new_code
FROM code_replace b
WHERE a.drug_concept_code = b.old_code;

UPDATE drug_concept_stage
SET standard_concept = NULL
WHERE concept_code IN (
		SELECT concept_code
		FROM drug_concept_stage
		JOIN internal_relationship_stage ON concept_code_1 = concept_code
		WHERE concept_class_id = 'Ingredient'
			AND standard_concept IS NOT NULL
		);
delete from relationship_to_concept
where
	concept_code_1 not in
	(select concept_code from drug_concept_stage)
;
delete from relationship_to_concept r
where exists
	(
		select
		from relationship_to_concept
		where
			concept_code_1 = r.concept_code_1 and
			concept_id_2 = r.concept_id_2 and
			precedence < r.precedence
	)
;
delete from ds_stage where coalesce (amount_unit, numerator_unit) IS NULL
;
delete from ds_stage where coalesce (amount_value, numerator_value) = 0
;
delete from internal_relationship_stage where concept_code_1 in
	(
		select prod_prd_id from official_mappings
	)
