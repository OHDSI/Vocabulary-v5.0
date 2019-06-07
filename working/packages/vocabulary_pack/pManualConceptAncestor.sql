CREATE OR REPLACE FUNCTION vocabulary_pack.pManualConceptAncestor (
  pVocabularies VARCHAR(1000)
)
RETURNS void AS
$BODY$
/*
 Manual concept ancestor
 AVOF-1702
 Usage:
 1. run this script like
 DO $_$
 BEGIN
    PERFORM VOCABULARY_PACK.pManualConceptAncestor(
    pVocabularies => 'CVX,SNOMED,RxNorm'
 );
 END $_$;
 
 pVocabularies - comma separated vocabulary_id
*/
DECLARE
  iVocabularies VARCHAR(1000) [ ] = (SELECT array_agg(trim(voc)) FROM unnest(string_to_array (pVocabularies,',')) voc);
  crlf VARCHAR (4) := '<br>';
  iSmallCA_emails CONSTANT VARCHAR(1000) := (SELECT var_value FROM devv5.config$ WHERE var_name='concept_ancestor_email');
  cRet TEXT;
  cRet2 TEXT;
  cCAGroups INT:=50;
  cRecord record;
  cStartTime timestamp;
  cWorkTime float;
  z int;
  v_id varchar(100);
BEGIN
  IF CURRENT_SCHEMA = 'devv5'
    THEN RAISE EXCEPTION 'You cannot use this script in the ''devv5''!';
  END IF;
  
  FOREACH v_id IN ARRAY iVocabularies LOOP
    SELECT COUNT(*) INTO z FROM vocabulary v WHERE v.vocabulary_id=v_id;
    IF z=0 THEN
        RAISE EXCEPTION 'vocabulary_id=% not found!',v_id;
    END IF;
  END LOOP;

  cStartTime:=clock_timestamp();
  
  --materialize main query
  DROP TABLE IF EXISTS temporary_ca_base$;
  EXECUTE'
  CREATE UNLOGGED TABLE temporary_ca_base$ AS 
  SELECT
    r.concept_id_1 AS ancestor_concept_id,
    r.concept_id_2 AS descendant_concept_id,
    case when s.is_hierarchical=1 and c1.standard_concept is not null then 1 else 0 end as levels_of_separation
  FROM concept_relationship r 
  JOIN relationship s on s.relationship_id=r.relationship_id and s.defines_ancestry=1
  JOIN concept c1 on c1.concept_id=r.concept_id_1 and c1.invalid_reason is null and (c1.vocabulary_id=any($1) or $1 is null)
  JOIN concept c2 on c2.concept_id=r.concept_id_2 and c2.invalid_reason is null and (c2.vocabulary_id=any($1) or $1 is null)
  WHERE r.invalid_reason is null' USING iVocabularies;
  CREATE INDEX idx_temp_ca_base$ ON temporary_ca_base$ (ancestor_concept_id,descendant_concept_id,levels_of_separation);
  ANALYZE temporary_ca_base$;

  DROP TABLE IF EXISTS temporary_ca_groups$;
  EXECUTE'
  CREATE TABLE temporary_ca_groups$ AS
  SELECT n, coalesce(lag(ancestor_concept_id) over (order by n),-1) ancestor_concept_id_min, ancestor_concept_id ancestor_concept_id_max from (
    SELECT n, max(ancestor_concept_id) ancestor_concept_id from (select ntile ($1) over (order by ancestor_concept_id) n, ancestor_concept_id from temporary_ca_base$) as s0
    GROUP BY n
  ) AS s1' USING cCAGroups;
  
  DROP TABLE IF EXISTS temporary_ca$;
  CREATE UNLOGGED TABLE temporary_ca$ AS SELECT * FROM concept_ancestor WHERE 1=0;
  FOR cRecord IN (SELECT * FROM temporary_ca_groups$ ORDER BY n) LOOP
    EXECUTE '
    insert into temporary_ca$
    with recursive hierarchy_concepts (ancestor_concept_id,descendant_concept_id, root_ancestor_concept_id, levels_of_separation, full_path) as
    (
        SELECT 
            ancestor_concept_id, descendant_concept_id, ancestor_concept_id as root_ancestor_concept_id,
            levels_of_separation, ARRAY [descendant_concept_id] AS full_path
        FROM temporary_ca_base$ 
        WHERE ancestor_concept_id>$1 and ancestor_concept_id<=$2
        UNION ALL
        SELECT 
            c.ancestor_concept_id, c.descendant_concept_id, root_ancestor_concept_id,
            hc.levels_of_separation+c.levels_of_separation as levels_of_separation,
            hc.full_path || c.descendant_concept_id as full_path
        FROM temporary_ca_base$ c
        JOIN hierarchy_concepts hc on hc.descendant_concept_id=c.ancestor_concept_id
        WHERE c.descendant_concept_id <> ALL (full_path)
    )   
    SELECT 
        hc.root_ancestor_concept_id as ancestor_concept_id, hc.descendant_concept_id,
        min(hc.levels_of_separation) as min_levels_of_separation,
        max(hc.levels_of_separation) as max_levels_of_separation 
    FROM hierarchy_concepts hc
    JOIN concept c1 on c1.concept_id=hc.root_ancestor_concept_id and c1.standard_concept is not null
    JOIN concept c2 on c2.concept_id=hc.descendant_concept_id and c2.standard_concept is not null
    GROUP BY hc.root_ancestor_concept_id, hc.descendant_concept_id' USING cRecord.ancestor_concept_id_min, cRecord.ancestor_concept_id_max;
  END LOOP;
  
  TRUNCATE TABLE concept_ancestor;
  ALTER TABLE concept_ancestor DROP CONSTRAINT IF EXISTS xpkconcept_ancestor;
  DROP INDEX IF EXISTS idx_ca_descendant;
  INSERT INTO concept_ancestor SELECT * FROM temporary_ca$;
  
  --Cleaning
  DROP TABLE temporary_ca$;
  DROP TABLE temporary_ca_groups$;
  DROP TABLE temporary_ca_base$;

  --Add connections to self for those vocabs having at least one concept in the concept_relationship table
  INSERT INTO concept_ancestor
  SELECT c.concept_id AS ancestor_concept_id,
         c.concept_id AS descendant_concept_id,
         0 AS min_levels_of_separation,
         0 AS max_levels_of_separation
  FROM concept c
  WHERE c.vocabulary_id IN (
                             SELECT c_int.vocabulary_id
                             FROM concept_relationship cr,
                                  concept c_int
                             WHERE c_int.concept_id = cr.concept_id_1
                             AND cr.invalid_reason IS NULL
        )
        AND c.invalid_reason IS NULL
        AND c.standard_concept IS NOT NULL
        AND c.vocabulary_id=any(iVocabularies);

  ALTER TABLE concept_ancestor ADD CONSTRAINT xpkconcept_ancestor PRIMARY KEY(
      ancestor_concept_id,
      descendant_concept_id);
  CREATE INDEX idx_ca_descendant ON concept_ancestor(
      descendant_concept_id);
  ANALYZE concept_ancestor;
  
  cWorkTime:=round((EXTRACT(epoch from clock_timestamp()-cStartTime)/60)::numeric,1);
  PERFORM devv5.SendMailHTML (iSmallCA_emails, 'Manual concept ancestor in '||upper(current_schema)||' [ok]', 'Manual concept ancestor in '||upper(current_schema)||' completed'||crlf||'Execution time: '||cWorkTime||' min');
  
  EXCEPTION
  WHEN OTHERS
  THEN
    GET STACKED DIAGNOSTICS cRet = PG_EXCEPTION_CONTEXT, cRet2 = PG_EXCEPTION_DETAIL;
    cRet:='ERROR: '||SQLERRM||crlf||'DETAIL: '||cRet2||crlf||'CONTEXT: '||regexp_replace(cRet, '\r|\n|\r\n', crlf, 'g');
    cRet := SUBSTR ('Manual concept ancestor completed with errors:'||crlf||'<b>'||cRet||'</b>', 1, 10000);
    PERFORM devv5.SendMailHTML (iSmallCA_emails, 'Manual concept ancestor in '||upper(current_schema)||' [error]', cRet);
END;
$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100
SET client_min_messages = error;