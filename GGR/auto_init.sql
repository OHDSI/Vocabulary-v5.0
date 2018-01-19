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
**************************************************************************/
DECLARE
    z    number;
    ex   number;
    pVocabulary_id constant varchar2(100):='GGR';
    pVocabulary_name constant varchar2(100):= 'GGR';
    pVocabulary_reference constant varchar2(100):='http://www.bcfi.be/nl/download'; -- also  http://apps.who.int/classifications/apps/icd/ClassificationDownload/DLArea/ICD-O-3_CSV-metadata.zip
    pVocabulary_version constant varchar2(100):='GGR update october 2017';
BEGIN
    BEGIN
        EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;

    SELECT MAX (concept_id) + 1 INTO ex FROM concept
      --WHERE concept_id>=200 and concept_id<1000; --only for VIP concepts
    WHERE concept_id >= 571191 AND concept_id < 581479;
    
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXECUTE IMMEDIATE 'SELECT v5_concept.nextval FROM dual' INTO z;

    INSERT INTO concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
      VALUES (z, pVocabulary_name, 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
    INSERT INTO vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id)
      VALUES (pVocabulary_id, pVocabulary_name, pVocabulary_reference, pVocabulary_version, z);

    EXECUTE IMMEDIATE 'DROP SEQUENCE v5_concept';
END;
/

--we form this one first to clear way for future ds_stage
    insert into pc_stage     --take pack data straight from mpp
    select distinct
        'mpp' || mpp.mppcv as pack_concept_code,
        'mpp' || mpp.mppcv || '-' || sam.ppid as drug_concept_code,
        sam.ppq as amount,
        mpp.cq as box_size 
        
    from mpp -- Pack contents have two defining keys, we combine them
    left join sam
    on mpp.mppcv = sam.mppcv
    where mpp.ouc = 'C'; --OUC means *O*ne, m*U*ltiple or pa*C*k 


    DROP TABLE DEVICES_TO_FILTER;
    CREATE TABLE DEVICES_TO_FILTER
    (
    MPPCV   VARCHAR2(255 Byte)   NOT NULL,
    MPPNM   VARCHAR2(255 Byte)   NOT NULL
    );

    insert into DEVICES_TO_FILTER --this is the one most simple way to filter Devices with incredible accuracy
    select distinct
    mpp.mppcv, mpp.MPPNM from mpp
    left join sam on mpp.mppcv=sam.mppcv where
    sam.stofcv in (01990, 00649, 01475, 01843); -- 'no active ingredient', 'ethanol', 'propanol', 'oxygen peroxide'. Latter three are only listed as ingredient in Devices
    
    insert into DEVICES_TO_FILTER
    select distinct
    mpp.mppcv, mpp.MPPNM from mpp
    where hyrcv in (16253,16246,16303,20263,16212,16253); -- These are codes for contrast substances
    
    drop table units;
    create table units as --temporary table with list of all measurement units we will insert into drug_concept_stage. mpp and sam are source
    select distinct AU as unit from mpp where mppcv not in (select mppcv from devices_to_filter) union
    select distinct INBASU as unit from sam where mppcv not in (select mppcv from devices_to_filter) union
    select distinct inu2 as unit from sam where mppcv not in (select mppcv from devices_to_filter) union
    select distinct INU as unit from sam where mppcv not in (select mppcv from devices_to_filter);

    delete from units where unit is null;

    -- now that devices and packs are dealt with, we can fill ds_stage
    insert into DRUG_CONCEPT_STAGE -- Devices
    select distinct
    mppnm as concept_name,
    'BCFI' as vocabulary_ID,
    'Device' as concept_class_id,
    'Med Product Pack' as source_concept_class_id,
    'S' as standard_concept,
    'mpp' || mppcv as concept_code,
    null as possible_excipient,
    'Device' as domain_id,
    trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
    from DEVICES_TO_FILTER;

    insert into DRUG_CONCEPT_STAGE -- Brand Names
    select distinct
    mpnm as concept_name,
    'BCFI' as vocabulary_ID,
    'Brand Name' as concept_class_id,
    'Medicinal Product' as source_concept_class_id,
    null as standard_concept,
    'mp' || mpcv as concept_code,
    null as possible_excipient,
    'Drug' as domain_id,
    trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
    from mp
    where mpcv not in ( --filter devices we added earlier, as we don't need to store brand names for them
        select mpp.mpcv from mpp
        join devices_to_filter dev on
        dev.mppcv = mpp.mppcv)
    ;

    insert into DRUG_CONCEPT_STAGE -- Ingredients
    select distinct
    ninnm as concept_name,
    'BCFI' as vocabulary_ID,
    'Ingredient' as concept_class_id,
    'Stof' as source_concept_class_id,
    null as standard_concept,
    'stof' || STOFCV as concept_code,
    null as possible_excipient,
    'Drug' as domain_id,
    trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
    from innm;

    insert into DRUG_CONCEPT_STAGE -- Suppliers
    select distinct
    NIRNM as concept_name,
    'BCFI' as vocabulary_ID,
    'Supplier' as concept_class_id,
    'Supplier' as source_concept_class_id,
    null as standard_concept,
    'ir' || ircv as concept_code,
    null as possible_excipient,
    'Drug' as domain_id,
    trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
    from ir;

    insert into DRUG_CONCEPT_STAGE -- Dose forms
    select distinct
    NGALNM as concept_name,
    'BCFI' as vocabulary_ID,
    'Dose Form' as concept_class_id,
    null as source_concept_class_id,
    null as standard_concept,
    'gal' || galcv as concept_code,
    null as possible_excipient,
    'Drug' as domain_id,
    trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
    from gal;

    insert into DRUG_CONCEPT_STAGE -- Products, no pack contents
    select distinct
    mppnm as concept_name,
    'BCFI' as vocabulary_ID,
    'Drug Product' as concept_class_id,
    'Med Product Pack' as source_concept_class_id,
    null as standard_concept,
    'mpp' || mppcv as concept_code,
    null as possible_excipient,
    'Drug' as domain_id,
    trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
    from mpp
    where mppcv not in (select mppcv from devices_to_filter); --filter devices

    insert into DRUG_CONCEPT_STAGE -- Products, in packs
    select distinct
    mpp.mppnm || ', pack content #' || substr (pc.drug_concept_code, -1, 1) as concept_name, -- Generate new pack content name
    'BCFI' as vocabulary_ID,
    'Drug Product' as concept_class_id,
    'Med Product Pack' as source_concept_class_id,
    null as standard_concept,
    pc.drug_concept_code as concept_code,
    null as possible_excipient,
    'Drug' as domain_id,
    trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
    from mpp
    join PC_STAGE pc on pc.PACK_CONCEPT_CODE = 'mpp' || mpp.mppcv
    left join sam on sam.mppcv = mpp.mppcv
    where OUC = 'C';        

    insert into DRUG_CONCEPT_STAGE -- Measurement units
    select distinct
    unit as concept_name,
    'BCFI' as vocabulary_ID,
    'Unit' as concept_class_id,
    null as source_concept_class_id,
    null as standard_concept,
    unit as concept_code,
    null as possible_excipient,
    'Drug' as domain_id,
    trunc(sysdate) as valid_start_date,
    TO_DATE('2099/12/31', 'yyyy/mm/dd') as valid_end_date,
    null as invalid_reason
    from units;


    create table tomap_unit (
    Concept_code varchar (255),
    concept_id number,
    Concept_name varchar (255),
    conversion_factor number);
    insert into tomap_unit
    select unit as concept_code, null as concept_id, null as concept_name, null as conversion_factor from units;


    create table tomap_form (
    Concept_code varchar (255),
    concept_name_fr varchar (255),
    concept_name_nl varchar (255),
    concept_name_en varchar (255),
    mapped_id  number,
    mapped_name varchar (255),
    precedence number);
    insert into tomap_form
    select
    'gal' || galcv as concept_code,
    fgalnm as concept_name_fr,
    ngalnm as concept_name_nl,
    null as concept_name_en,
    null as mapped_id,
    null as mapped_name,
    null as precedence 
    from gal;


    create table tomap_supplier (
    Concept_code varchar (255),
    concept_name varchar (255),
    mapped_id  number,
    mapped_name varchar (255));
    insert into tomap_supplier
    select 
    dc.concept_code as concept_code,
    dc.concept_name,
    c.concept_id as mapped_id,
    c.concept_name as mapped_name
    from drug_concept_stage dc
    left join concept c on
    c.concept_class_id = 'Supplier' and
    c.vocabulary_id like 'Rx%' and
    c.invalid_reason is null and
    lower (c.concept_name) = lower (dc.concept_name)
    where dc.concept_class_id = 'Supplier';


    create table tomap_bn (
    Concept_code varchar (255),
    concept_name varchar (255),
    mapped_id number,
    mapped_name varchar (255),
    supplier_name varchar (255));
    insert into tomap_bn
    select 
    dc.concept_code as concept_code,
    dc.concept_name,
    c.concept_id as mapped_id,
    c.concept_name as mapped_name,
    ir.NIRNM as supplier_names
    from drug_concept_stage dc
    join mp on 'mp' || mp.mpcv = dc.concept_code
    join ir on mp.ircv = ir.ircv
    left join concept c on
    c.concept_class_id = 'Brand Name' and
    c.vocabulary_id like 'Rx%' and
    c.invalid_reason is null and
    lower (c.concept_name) = lower (dc.concept_name)
    where dc.concept_class_id = 'Brand Name';

    delete from tomap_bn where supplier_name = 'PI-Pharma'; --Dublicates exclusively, simplifies manual work 

    create table tomap_ingred (
    Concept_code varchar (255),
    concept_name varchar (255),
    mapped_id  number,
    mapped_name varchar (255),
    precedence number);
    insert into tomap_ingred
    select 
    dc.concept_code,
    dc.concept_name,
    c.concept_id as mapped_id,
    c.concept_name as mapped_name,
    null as precedence
    from drug_concept_stage dc
    left join concept c on
    c.concept_class_id = 'Ingredient' and
    c.vocabulary_id like 'Rx%' and
    c.invalid_reason is null and
    lower (c.concept_name) = lower (dc.concept_name)
    where dc.concept_class_id = 'Ingredient';