--NCIm source processing
DROP TABLE IF EXISTS source;
CREATE TABLE source as (
WITH concepts AS (
SELECT
    c.scui,
    c.cui,
    STRING_AGG(DISTINCT CASE WHEN main.code LIKE '%CD'
                                  THEN main.str
                                  END, '-' )
                FILTER (WHERE main.str <> c.concept_name
                           AND str <> c.scui
                           AND main.sab = 'CDISC') AS concept_code,
    c.concept_name
FROM sources.meta_mrconso main
JOIN
(    SELECT scui,
            cui,
            str as concept_name,
            ROW_NUMBER() OVER (
           PARTITION BY scui
        ORDER BY
            CASE WHEN code in (SELECT TRIM(TRAILING 'CD' FROM t.code)
                                 FROM sources.meta_mrconso t
                                 WHERE t.scui = main.scui AND t.code LIKE '%CD') THEN 1
                 WHEN tty = 'PT' AND sab = 'CDISC' THEN
                     CASE WHEN (SELECT COUNT(*)

                                  FROM sources.meta_mrconso c2
                                 WHERE c2.str = main.str
                                   AND c2.tty = 'PT'
                                   AND c2.sab = 'CDISC'
                                   AND c2.scui = main.scui) > 1 THEN 2
                         ELSE 3
                     END
                 WHEN tty = 'SY' AND ispref = 'Y' THEN 4
                 WHEN sab = 'NCI' AND tty = 'SY' AND ispref = 'Y' THEN 5
            END,
            LENGTH(str) DESC
        ) as applied_condition
     FROM sources.meta_mrconso main
    WHERE main.sab = 'CDISC'
      AND LEFT(main.scui, 1) = 'C'
      AND SUBSTRING(main.scui FROM 2) ~ '\d') c ON main.scui = c.scui
WHERE c.applied_condition = 1
GROUP BY c.scui, c.cui, c.concept_name
),
synonyms AS (
    SELECT scui,
            str,
            ROW_NUMBER() OVER (
                PARTITION BY scui
                ORDER BY LENGTH(str) DESC
            ) as rn
     FROM sources.meta_mrconso
     WHERE sab = 'CDISC'
       AND code NOT LIKE '%CD'
),
longest_synonyms AS (
    SELECT scui, str
    FROM synonyms
   WHERE rn = 1
)
SELECT
distinct
    c.scui,
    c.cui,
    c.scui || COALESCE('-'||c.concept_code, '') AS concept_code,
    CASE
        WHEN c.concept_name ~ '^[^a-zA-Z\/]*$'
            THEN (SELECT ls.str FROM longest_synonyms ls WHERE scui = c.scui)
        ELSE c.concept_name
    END AS concept_name,
    CASE
        WHEN c.concept_name ~ '^[^a-zA-Z\/]*$' THEN c.concept_name
        ELSE s.str
    END AS synonym
FROM concepts c
LEFT JOIN synonyms s ON c.scui = s.scui
      AND s.str <> c.concept_name
      AND POSITION(s.str IN COALESCE(c.concept_code, '')) = 0)
;