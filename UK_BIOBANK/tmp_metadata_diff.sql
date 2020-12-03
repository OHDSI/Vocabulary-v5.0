--It turned out that metadata significantly differs between versions

SELECT ENCODING_ID, TITLE, AVAILABILITY, CODED_AS, STRUCTURE, NUM_MEMBERS::varchar, DESCRIPT, 'current version' AS note
FROM SOURCES.UK_BIOBANK_ENCODING c
WHERE (ENCODING_ID, TITLE, AVAILABILITY, CODED_AS, STRUCTURE, NUM_MEMBERS::varchar, DESCRIPT) NOT IN (SELECT ENCODING_ID, TITLE, AVAILABILITY, CODED_AS, STRUCTURE, NUM_MEMBERS, DESCRIPT FROM dev_ukbiobank.encoding p)
UNION ALL
SELECT ENCODING_ID, TITLE, AVAILABILITY, CODED_AS, STRUCTURE, NUM_MEMBERS, DESCRIPT, 'previous version' AS note
FROM dev_ukbiobank.encoding p
WHERE (ENCODING_ID, TITLE, AVAILABILITY, CODED_AS, STRUCTURE, NUM_MEMBERS, DESCRIPT) NOT IN (SELECT ENCODING_ID, TITLE, AVAILABILITY, CODED_AS, STRUCTURE, NUM_MEMBERS::varchar, DESCRIPT FROM SOURCES.UK_BIOBANK_ENCODING c)
ORDER BY ENCODING_ID, note
;


SELECT CATEGORY_ID, TITLE, AVAILABILITY::varchar, GROUP_TYPE::varchar, DESCRIPT, 'current version' AS note
FROM sources.UK_BIOBANK_CATEGORY c
WHERE (CATEGORY_ID, TITLE, AVAILABILITY::varchar, GROUP_TYPE::varchar, DESCRIPT) NOT IN (SELECT CATEGORY_ID, TITLE, AVAILABILITY, GROUP_TYPE, DESCRIPT FROM dev_ukbiobank.category p)
UNION ALL
SELECT CATEGORY_ID, TITLE, AVAILABILITY, GROUP_TYPE, DESCRIPT, 'previous version' AS note
FROM dev_ukbiobank.category p
WHERE (CATEGORY_ID, TITLE, AVAILABILITY, GROUP_TYPE, DESCRIPT) NOT IN (SELECT CATEGORY_ID, TITLE, AVAILABILITY::varchar, GROUP_TYPE::varchar, DESCRIPT FROM sources.UK_BIOBANK_CATEGORY c)
ORDER BY CATEGORY_ID, note
;


SELECT ENCODING_ID, CODE_ID, PARENT_ID, VALUE::varchar, MEANING, SELECTABLE, SHOWCASE_ORDER, 'current version' AS note
FROM SOURCES.UK_BIOBANK_EHIERINT c
WHERE (ENCODING_ID, CODE_ID, PARENT_ID, VALUE::varchar, MEANING, SELECTABLE, SHOWCASE_ORDER) NOT IN (SELECT ENCODING_ID, CODE_ID, PARENT_ID, VALUE::varchar, MEANING, SELECTABLE, SHOWCASE_ORDER FROM dev_ukbiobank.ehierint p)
UNION ALL
SELECT ENCODING_ID, CODE_ID, PARENT_ID, VALUE::varchar, MEANING, SELECTABLE, SHOWCASE_ORDER, 'previous version' AS note
FROM dev_ukbiobank.ehierint p
WHERE (ENCODING_ID, CODE_ID, PARENT_ID, VALUE::varchar, MEANING, SELECTABLE, SHOWCASE_ORDER) NOT IN (SELECT ENCODING_ID, CODE_ID, PARENT_ID, VALUE::varchar, MEANING, SELECTABLE, SHOWCASE_ORDER FROM SOURCES.UK_BIOBANK_EHIERINT c)
ORDER BY ENCODING_ID, note
;



SELECT ENCODING_ID, CODE_ID, PARENT_ID, VALUE::varchar, MEANING, SELECTABLE, SHOWCASE_ORDER, 'current version' AS note
FROM SOURCES.UK_BIOBANK_EHIERSTRING c
WHERE (ENCODING_ID, CODE_ID, PARENT_ID, VALUE::varchar, MEANING, SELECTABLE, SHOWCASE_ORDER) NOT IN (SELECT ENCODING_ID, CODE_ID, PARENT_ID, VALUE::varchar, MEANING, SELECTABLE, SHOWCASE_ORDER FROM dev_ukbiobank.ehierstring p)
UNION ALL
SELECT ENCODING_ID, CODE_ID, PARENT_ID, VALUE::varchar, MEANING, SELECTABLE, SHOWCASE_ORDER, 'previous version' AS note
FROM dev_ukbiobank.ehierstring p
WHERE (ENCODING_ID, CODE_ID, PARENT_ID, VALUE::varchar, MEANING, SELECTABLE, SHOWCASE_ORDER) NOT IN (SELECT ENCODING_ID, CODE_ID, PARENT_ID, VALUE::varchar, MEANING, SELECTABLE, SHOWCASE_ORDER FROM SOURCES.UK_BIOBANK_EHIERSTRING c)
ORDER BY ENCODING_ID, note
;



--?
SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER::varchar, 'current version' AS note
FROM SOURCES.UK_BIOBANK_ESIMPSTRING c
WHERE (ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER::varchar) NOT IN (SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER FROM dev_ukbiobank.esimpstring p)
UNION ALL
SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER, 'previous version' AS note
FROM dev_ukbiobank.esimpstring p
WHERE (ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER) NOT IN (SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER::varchar FROM SOURCES.UK_BIOBANK_ESIMPSTRING c)
ORDER BY ENCODING_ID, value, note
;



SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER, 'current version' AS note
FROM SOURCES.UK_BIOBANK_ESIMPREAL c
WHERE (ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER) NOT IN (SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER FROM dev_ukbiobank.esimpreal p)
UNION ALL
SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER, 'previous version' AS note
FROM dev_ukbiobank.esimpreal p
WHERE (ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER) NOT IN (SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER FROM SOURCES.UK_BIOBANK_ESIMPREAL c)
ORDER BY ENCODING_ID, value, note
;



SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER, 'current version' AS note
FROM SOURCES.UK_BIOBANK_ESIMPINT c
WHERE (ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER) NOT IN (SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER FROM dev_ukbiobank.esimpint p)
UNION ALL
SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER, 'previous version' AS note
FROM dev_ukbiobank.esimpint p
WHERE (ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER) NOT IN (SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER FROM SOURCES.UK_BIOBANK_ESIMPINT c)
ORDER BY ENCODING_ID, value, note
;



SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER, 'current version' AS note
FROM SOURCES.UK_BIOBANK_ESIMPDATE c
WHERE (ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER) NOT IN (SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER FROM dev_ukbiobank.ESIMPDATE p)
UNION ALL
SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER, 'previous version' AS note
FROM dev_ukbiobank.ESIMPDATE p
WHERE (ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER) NOT IN (SELECT ENCODING_ID, VALUE, MEANING, SHOWCASE_ORDER FROM SOURCES.UK_BIOBANK_ESIMPDATE c)
ORDER BY ENCODING_ID, value, note
;



SELECT field_id,title,availability,stability,private,value_type,base_type,item_type,strata::varchar,instanced,arrayed,sexed,units,main_category,encoding_id,instance_id,instance_min::varchar,instance_max::varchar,array_min::varchar,array_max::varchar,debut, 'current version' AS note
FROM SOURCES.UK_BIOBANK_FIELD c
WHERE (field_id,title,availability,stability,private,value_type,base_type,item_type,strata::varchar,instanced,arrayed,sexed,units,main_category,encoding_id,instance_id,instance_min::varchar,instance_max::varchar,array_min::varchar,array_max::varchar,debut) NOT IN
      (SELECT field_id,title,availability,stability,private,value_type,base_type,item_type,strata,instanced,arrayed,sexed,units,main_category,encoding_id,instance_id,instance_min,instance_max,array_min,array_max,to_date(debut, 'DD/MM/YYYY') FROM dev_ukbiobank.field p)

UNION ALL

SELECT field_id,title,availability,stability,private,value_type,base_type,item_type,strata,instanced,arrayed,sexed,units,main_category,encoding_id,instance_id,instance_min,instance_max,array_min,array_max,to_date(debut, 'DD/MM/YYYY'), 'previous version' AS note
FROM dev_ukbiobank.field p
WHERE (field_id,title,availability,stability,private,value_type,base_type,item_type,strata,instanced,arrayed,sexed,units,main_category,encoding_id,instance_id,instance_min,instance_max,array_min,array_max,to_date(debut, 'DD/MM/YYYY')) NOT IN
      (SELECT field_id,title,availability,stability,private,value_type,base_type,item_type,strata::varchar,instanced,arrayed,sexed,units,main_category,encoding_id,instance_id,instance_min::varchar,instance_max::varchar,array_min::varchar,array_max::varchar,debut FROM SOURCES.UK_BIOBANK_FIELD c)
ORDER BY field_id, note
;

SELECT * FROM SOURCES.UK_BIOBANK_FIELD WHERE debut > to_date('2020-03-05', 'YYYY-MM-DD');

SELECT old.field_id, old.title, to_date(old.debut, 'DD/MM/YYYY'), to_date(old.version, 'DD/MM/YYYY'),
       new.field_id, new.title, new.debut, new.version
FROM dev_ukbiobank.field old
JOIN SOURCES.uk_biobank_field new
ON old.field_id = new.field_id
WHERE to_date(old.debut, 'DD/MM/YYYY') != new.debut;
--OR to_date(old.version, 'DD/MM/YYYY') != new.version;


SELECT * FROM SOURCES.UK_BIOBANK_FIELD WHERE field_id = 6015;

--142
SELECT field_id, title, main_category
FROM SOURCES.UK_BIOBANK_FIELD
    WHERE field_id NOT IN (SELECT field_id FROM dev_ukbiobank.field);

SELECT * FROM dev_ukbiobank.field where field_id = 23191;

--field_id = 115; title = 'Father's month of birth'




SELECT parent_id, child_id, showcase_order, 'current version' AS note
FROM sources.uk_biobank_catbrowse c
WHERE (parent_id, child_id, showcase_order) NOT IN (SELECT parent_id, child_id, showcase_order FROM dev_ukbiobank.catbrowse p)
UNION ALL
SELECT parent_id, child_id, showcase_order, 'previous version' AS note
FROM dev_ukbiobank.catbrowse p
WHERE (parent_id, child_id, showcase_order) NOT IN (SELECT parent_id, child_id, showcase_order FROM sources.uk_biobank_catbrowse c)
ORDER BY parent_id, note
;
