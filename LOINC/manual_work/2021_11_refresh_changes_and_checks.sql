--concepts for manual mapping
SELECT *
FROM loinc_source;

--Backup of the previous version of loinc_source
--DROP TABLE dev_loinc.loinc_source_20211028;
CREATE TABLE dev_loinc.loinc_source_backup_20211028
AS (SELECT *
    FROM dev_loinc.loinc_source);

--In this release some discourage concepts should become Standard
--Show discouraged concepts that should be standard
SELECT DISTINCT *
FROM sources.loinc l
WHERE l.status = 'DISCOURAGED'
  AND l.loinc_num NOT IN (SELECT DISTINCT loincnumber
                          FROM sources.loinc_partlink_primary
                          WHERE partnumber = 'LP33032-1')
  AND loinc_num NOT IN (SELECT DISTINCT loinc
                        FROM sources.map_to
                        GROUP BY 1
                        HAVING COUNT(DISTINCT map_to) = 1)
  AND class != 'PANEL.HEDIS';

--Show discouraged concepts that are standard now
SELECT DISTINCT *
FROM dev_loinc.concept c
WHERE c.concept_code IN (SELECT loinc_num
                         FROM sources.loinc l
                         WHERE l.status = 'DISCOURAGED' and l.class != 'PANEL.HEDIS')
  AND c.concept_code NOT IN (SELECT DISTINCT loincnumber
                             FROM sources.loinc_partlink_primary
                             WHERE partnumber = 'LP33032-1')
  AND c.concept_code NOT IN (SELECT DISTINCT loinc
                             FROM sources.map_to
                             GROUP BY 1
                             HAVING COUNT(DISTINCT map_to) = 1)
  AND vocabulary_id = 'LOINC';

--Backup of the previous version of loinc_mapped
--DROP TABLE dev_loinc.loinc_mapped_20211028;
CREATE TABLE dev_loinc.loinc_mapped_backup_20211028
AS (SELECT *
    FROM dev_loinc.loinc_mapped);

--concepts from loinc_mapped table
SELECT *
FROM loinc_mapped;

--Creating flag for concepts that will be Standard
UPDATE dev_loinc.loinc_mapped
SET flag = 'DEP'
WHERE source_code IN (SELECT DISTINCT loinc_num
                      FROM sources.loinc l
                      WHERE l.status = 'DISCOURAGED' and l.class != 'PANEL.HEDIS')
  AND source_code NOT IN (SELECT DISTINCT loinc
                          FROM sources.map_to
                          GROUP BY 1
                          HAVING COUNT(DISTINCT map_to) = 1)
  AND source_code NOT IN (SELECT DISTINCT loincnumber
                          FROM sources.loinc_partlink_primary
                          WHERE partnumber = 'LP33032-1');


--Selection of concepts that will be Standard
SELECT id, source_code, flag
FROM dev_loinc.loinc_mapped
ORDER BY id;