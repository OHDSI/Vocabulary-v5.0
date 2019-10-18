--This file contains all the test, statistics and other secondary code to LOINC

--Relationships from this subquery (7484 distinct relationships between LOINC Parts) can be added only with help of Loinc_partlink, but not LOINC_hierarchy
WITH a AS (
    SELECT concept_code_1,
           c.concept_name,
           c.concept_class_id,
           relationship_id,
           concept_code_2,
           j.concept_name,
           j.concept_class_id
    FROM dev_loinc.concept_relationship_stage r
             JOIN dev_loinc.concept_stage c ON (r.concept_code_1, r.vocabulary_id_1) = (c.concept_code, c.vocabulary_id)
        AND c.vocabulary_id = 'LOINC' AND c.concept_class_id IN
                                          ('LOINC Component', 'LOINC System', 'LOINC Property', 'LOINC Method',
                                           'LOINC Time', 'LOINC Scale')
             JOIN dev_loinc.concept_stage j ON (r.concept_code_2, r.vocabulary_id_2) = (j.concept_code, j.vocabulary_id)
        AND j.vocabulary_id = 'LOINC' AND j.concept_class_id IN
                                          ('LOINC Component', 'LOINC System', 'LOINC Property', 'LOINC Method',
                                           'LOINC Time', 'LOINC Scale')
    WHERE (concept_code_1, concept_code_2) NOT IN (SELECT immediate_parent, code FROM sources.loinc_hierarchy)
    ORDER BY c.concept_name
)

SELECT DISTINCT a.*
FROM a
JOIN sources.loinc_hierarchy lh
    ON lh.immediate_parent = a.concept_code_1
    AND lh.code = a.concept_code_2
ORDER BY a.concept_code_1;


--Subsumes relationships between 'LP-' concepts built from loinc_hierarchy
SELECT lh.immediate_parent, cs.concept_name AS parent_name, cs.concept_class_id AS parent_concept_class_id, cr.relationship_id, css.concept_code, css.concept_name, css.concept_class_id
FROM sources.loinc_hierarchy lh
JOIN concept_stage cs
ON lh.immediate_parent = cs.concept_code
AND cs.concept_class_id in ('LOINC Component', 'LOINC System', 'LOINC Property', 'LOINC Method', 'LOINC Time', 'LOINC Scale')
JOIN concept_relationship_stage cr
ON lh.immediate_parent = cr.concept_code_1
JOIN concept_stage css
ON css.concept_code = lh.code
AND cs.concept_class_id in ('LOINC Component', 'LOINC System', 'LOINC Property', 'LOINC Method', 'LOINC Time', 'LOINC Scale')
WHERE relationship_id = 'Subsumes'
ORDER BY lh.immediate_parent;


--Look at the concepts that have
--              parttypename IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE')
--but with      linktypename != 'Primary'
SELECT DISTINCT p.partnumber, p.partdisplayname, p.parttypename, pl.linktypename
FROM sources.loinc_part p
JOIN sources.loinc_partlink pl
ON p.partnumber = pl.partnumber
WHERE p.parttypename IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE')
AND pl.linktypename != 'Primary';


/*Concepts with parttypename IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE') - 6 parttypes we agreed to include in CDM
  without analogues in 'Primary' (linktypename = 'Primary') concepts
    9053 distinct parts
  */
SELECT DISTINCT p.partnumber, p.partdisplayname, p.parttypename, pl.linktypename
FROM sources.loinc_part p
JOIN sources.loinc_partlink pl
ON p.partnumber = pl.partnumber
WHERE p.parttypename IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE')
AND pl.linktypename != 'Primary'
AND p.partnumber NOT IN (SELECT DISTINCT pl.partnumber FROM sources.loinc_partlink pl
    WHERE pl.linktypename = 'Primary'
    AND pl.parttypename IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE')
    AND pl.parttypename IS NOT NULL)
;


--LOINC codes where additional information is added with non-primary parts
with a AS (SELECT DISTINCT pl.loincnumber, pl.longcommonname, p.partnumber, p.partdisplayname, p.parttypename, pl.linktypename
FROM sources.loinc_part p
JOIN sources.loinc_partlink pl
ON p.partnumber = pl.partnumber
WHERE p.parttypename IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE')
AND pl.linktypename != 'Primary'
AND p.partnumber NOT IN (SELECT DISTINCT pl.partnumber FROM sources.loinc_partlink pl
    WHERE pl.linktypename = 'Primary'
    AND pl.parttypename IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE')
    AND pl.parttypename IS NOT NULL))

SELECT pl.loincnumber, pl.longcommonname, pl.partnumber, pl.partname, pl.parttypename, array_agg(pl.linktypename) AS linktypes
FROM sources.loinc_partlink pl
WHERE pl.loincnumber IN (SELECT loincnumber FROM a)
AND pl.parttypename IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE')
GROUP BY pl.loincnumber, pl.longcommonname, pl.partnumber, pl.partname, pl.parttypename
ORDER BY loincnumber, parttypename
;

--Также интересно заджойнить loinc_hierarchy и loinc_partlink,  чтобы посмотреть какие закономерности в построении иерархии для loinc parts присутствуют в сорсе
--Not sure this code will be helpful somehow
SELECT lh.immediate_parent, p.partdisplayname AS parent_name, p.parttypename, pl.linktypename, lh.code, lh.code_text
FROM sources.loinc_hierarchy lh
JOIN sources.loinc_partlink pl
ON lh.immediate_parent = pl.partnumber
JOIN sources.loinc_part p
ON lh.immediate_parent = p.partnumber
ORDER BY lh.immediate_parent;


--под диффом я имел ввиду, где будут видны имена тестов, текущие ссылки (в пределах primary) + все дополнительные ссылки
SELECT loincnumber, longcommonname, partnumber, partname, parttypename, linktypename
FROM sources.loinc_partlink
WHERE parttypename IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE')
ORDER BY loincnumber;




TRUNCATE TABLE concept_relationship_stage;

--Запрос Полины
--INSERT INTO concept_relationship_stage(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
SELECT DISTINCT x1.partnumber, -- LOINC Ancestor
                x1.partname,
                x2.partnumber,
                x2.partname,
                'LOINC',
                'LOINC',
                'Subsumes',
                TO_DATE('19700101', 'yyyymmdd'),
	            TO_DATE('20991231', 'yyyymmdd'),
                NULL
FROM sources.loinc_partlink x1
join sources.loinc_partlink x2 on x1.loincnumber = x2.loincnumber  and x1.parttypename = x2.parttypename
AND x1.partname <> x2.partname
WHERE (x2.linktypename = 'Primary' and x1.linktypename = 'DetailedModel')
or (x2.linktypename = 'Primary' and  x1.linktypename = 'Search' and 'METHOD' in (x1.parttypename,x2.parttypename))
GROUP BY x1.partnumber, x1.partname, x2.partnumber, x2.partname
HAVING count(*) = 2
ORDER BY x1.partnumber
;

--1-й уровень
WITH a AS (
    SELECT concept_code_1, p.partdisplayname, concept_code_2, pp.partdisplayname
    FROM concept_relationship_stage rs
             JOIN sources.loinc_part p
                  ON rs.concept_code_1 = p.partnumber
             JOIN sources.loinc_part pp
                  ON rs.concept_code_2 = pp.partnumber
    WHERE concept_code_1 NOT IN
          (SELECT DISTINCT concept_code_2 FROM concept_relationship_stage) --Concept without parents
      AND concept_code_2 NOT IN (SELECT DISTINCT concept_code_1 FROM concept_relationship_stage)
)

SELECT DISTINCT crr.concept_code_1, a.concept_code_1, CASE WHEN crr.concept_code_1 = a.concept_code_1 THEN 'True' ELSE 'False' END AS relationship
--родители отличающихся концептов. Сравнить их с concept_code_1 из а.
--Если совпадают, значит, есть промежуток между concept_code_1 и concept_code_2 и такой relationship нужно удалять
FROM concept_relationship_stage cr
JOIN concept_relationship_stage crr
ON crr.concept_code_2 = cr.concept_code_1
JOIN a
ON cr.concept_code_2 = a.concept_code_2
WHERE (cr.concept_code_1, cr.concept_code_2) NOT IN (SELECT concept_code_1, concept_code_2 FROM a)   --Взяли отличных родителей
;
--Затем итеративно взять всех, где родители не совпали и проверить еще раз


--2-й уровень
WITH a AS (
    SELECT concept_code_1, p.partdisplayname, concept_code_2, pp.partdisplayname
    FROM concept_relationship_stage rs
             JOIN sources.loinc_part p
                  ON rs.concept_code_1 = p.partnumber
             JOIN sources.loinc_part pp
                  ON rs.concept_code_2 = pp.partnumber
    WHERE concept_code_1 NOT IN
          (SELECT DISTINCT concept_code_2 FROM concept_relationship_stage) --Concept without parents
      AND concept_code_2 NOT IN (SELECT DISTINCT concept_code_1 FROM concept_relationship_stage)
)

SELECT DISTINCT crrr.concept_code_1, a.concept_code_1, CASE WHEN crrr.concept_code_1 = a.concept_code_1 THEN 'True' ELSE 'False' END AS relationship
--родители отличающихся концептов. Сравнить их с concept_code_1 из а.
--Если совпадают, значит, есть промежуток между concept_code_1 и concept_code_2 и такой relationship нужно удалять
FROM concept_relationship_stage cr
JOIN concept_relationship_stage crr
ON crr.concept_code_2 = cr.concept_code_1
JOIN concept_relationship_stage crrr
ON crrr.concept_code_2 = crr.concept_code_1
JOIN a
ON cr.concept_code_2 = a.concept_code_2
WHERE (cr.concept_code_1, cr.concept_code_2) NOT IN (SELECT concept_code_1, concept_code_2 FROM a)   --Взяли отличных родителей
;

--3-й уровень
WITH a AS (
    SELECT concept_code_1, p.partdisplayname, concept_code_2, pp.partdisplayname
    FROM concept_relationship_stage rs
             JOIN sources.loinc_part p
                  ON rs.concept_code_1 = p.partnumber
             JOIN sources.loinc_part pp
                  ON rs.concept_code_2 = pp.partnumber
    WHERE concept_code_1 NOT IN
          (SELECT DISTINCT concept_code_2 FROM concept_relationship_stage) --Concept without parents
      AND concept_code_2 NOT IN (SELECT DISTINCT concept_code_1 FROM concept_relationship_stage)
)

SELECT DISTINCT crrrr.concept_code_1, a.concept_code_1, CASE WHEN crrrr.concept_code_1 = a.concept_code_1 THEN 'True' ELSE 'False' END AS relationship
--родители отличающихся концептов. Сравнить их с concept_code_1 из а.
--Если совпадают, значит, есть промежуток между concept_code_1 и concept_code_2 и такой relationship нужно удалять
FROM concept_relationship_stage cr
JOIN concept_relationship_stage crr
ON crr.concept_code_2 = cr.concept_code_1
JOIN concept_relationship_stage crrr
ON crrr.concept_code_2 = crr.concept_code_1
JOIN concept_relationship_stage crrrr
ON crrrr.concept_code_2 = crrr.concept_code_1
JOIN a
ON cr.concept_code_2 = a.concept_code_2
WHERE (cr.concept_code_1, cr.concept_code_2) NOT IN (SELECT concept_code_1, concept_code_2 FROM a)   --Взяли отличных родителей
;

--4-й уровень
WITH a AS (
    SELECT concept_code_1, p.partdisplayname, concept_code_2, pp.partdisplayname
    FROM concept_relationship_stage rs
             JOIN sources.loinc_part p
                  ON rs.concept_code_1 = p.partnumber
             JOIN sources.loinc_part pp
                  ON rs.concept_code_2 = pp.partnumber
    WHERE concept_code_1 NOT IN
          (SELECT DISTINCT concept_code_2 FROM concept_relationship_stage) --Concept without parents
      AND concept_code_2 NOT IN (SELECT DISTINCT concept_code_1 FROM concept_relationship_stage)
)

SELECT DISTINCT crrrrr.concept_code_1, a.concept_code_1, CASE WHEN crrrrr.concept_code_1 = a.concept_code_1 THEN 'True' ELSE 'False' END AS relationship
--родители отличающихся концептов. Сравнить их с concept_code_1 из а.
--Если совпадают, значит, есть промежуток между concept_code_1 и concept_code_2 и такой relationship нужно удалять
FROM concept_relationship_stage cr
JOIN concept_relationship_stage crr
ON crr.concept_code_2 = cr.concept_code_1
JOIN concept_relationship_stage crrr
ON crrr.concept_code_2 = crr.concept_code_1
JOIN concept_relationship_stage crrrr
ON crrrr.concept_code_2 = crrr.concept_code_1
JOIN concept_relationship_stage crrrrr
ON crrrrr.concept_code_2 = crrrr.concept_code_1
JOIN a
ON cr.concept_code_2 = a.concept_code_2
WHERE (cr.concept_code_1, cr.concept_code_2) NOT IN (SELECT concept_code_1, concept_code_2 FROM a)   --Взяли отличных родителей
;






/*
CREATE OR REPLACE FUNCTION Recursive_interim_parent_search (concept_code_init_parent varchar, concept_code_child varchar)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
--берем родител, отличного от приведенного
--смотрим его родителя. Если они совпадают с первым, возвращаем true

    IF concept_code_init_parent != crr.concept_code_1 THEN
        RETURN QUERY SELECT * FROM Recursive_interim_parent_search();
    END IF;
END $$;
*/


--Relationships between X->Primary
SELECT DISTINCT pl.partnumber, pl.partname, pl.parttypename, --pl.linktypename,
       pll.partnumber, pll.partname, pll.parttypename --pll.linktypename
FROM sources.loinc_partlink pl
JOIN sources.loinc_partlink pll
ON (pl.loincnumber, pl.parttypename) = (pll.loincnumber, pll.parttypename)
       AND pl.partnumber != pll.partnumber
WHERE pl.parttypename IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE')
AND pl.linktypename IN ('DetailedModel', 'SyntaxEnhancement', 'Search')
AND pll.parttypename IN ('SYSTEM', 'METHOD', 'PROPERTY', 'TIME', 'COMPONENT', 'SCALE')
AND pll.linktypename = 'Primary'
ORDER BY pl.partnumber
;

SELECT DISTINCT x1.partnumber AS concept_code_1, -- LOINC Ancestor
x1.partname AS concept_name_1, 'Subsumes' AS relationship_id,
	x2.partnumber AS concept_code_2, -- LOINC Descendant
x2.partname AS concept_name_2
FROM loinc_partlink x1
JOIN loinc_partlink x2 ON x1.loincnumber = x2.loincnumber AND x1.parttypename = x2.parttypename
AND x1.partnumber != x2.partnumber
WHERE (x2.linktypename = 'Primary' AND x1.linktypename = 'DetailedModel')
GROUP BY x1.partnumber, x1.partname, x2.partnumber, x2.partname
;


SELECT DISTINCT x1.partnumber AS concept_code_1, -- LOINC Ancestor
x1.partname AS concept_name_1, 'Subsumes' AS relationship_id,
	x2.partnumber AS concept_code_2, -- LOINC Descendant
x2.partname AS concept_name_2
FROM loinc_partlink x1
JOIN loinc_partlink x2 ON x1.loincnumber = x2.loincnumber AND x1.parttypename = x2.parttypename
AND x1.partnumber != x2.partnumber
WHERE (x2.linktypename = 'Primary' AND x1.linktypename = 'DetailedModel')
GROUP BY x1.partnumber, x1.partname, x2.partnumber, x2.partname
HAVING count(x2.partnumber) > 5
ORDER BY concept_code_1
;