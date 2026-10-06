CREATE OR REPLACE FUNCTION dev_rxnorm.get_pack_content_delta()
RETURNS TABLE(vocabulary_id VARCHAR(50), row_delta INT) AS $$
WITH current AS (
    SELECT DISTINCT c.vocabulary_id, count(*) as count
     FROM pack_content pc
     JOIN concept c ON c.concept_id = pc.pack_concept_id
     GROUP BY c.vocabulary_id),

  prodv5 AS (
    SELECT DISTINCT c.vocabulary_id, count(*) as count
     FROM prodv5.pack_content pc
     JOIN concept c ON c.concept_id = pc.pack_concept_id
     GROUP BY c.vocabulary_id)

SELECT c.vocabulary_id,
       (c.count-p.count) as row_delta
FROM current c
JOIN prodv5 p USING (vocabulary_id)
$$ LANGUAGE SQL;