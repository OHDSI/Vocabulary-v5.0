CREATE OR REPLACE FUNCTION vocabulary_pack.pconceptancestor (
  is_small boolean = false
)
RETURNS void AS
$body$
DECLARE
  iVocabularies VARCHAR(1000) [ ];
  crlf VARCHAR (4) := '<br>';
  --iSmallCA_emails CONSTANT VARCHAR(1000) :=('timur.vakhitov@firstlinesoftware.com,timur.vakhitov@gmail.com');
  iSmallCA_emails CONSTANT VARCHAR(1000) :=('timur.vakhitov@firstlinesoftware.com,reich@ohdsi.org,reich@omop.org,ddymshyts@odysseusinc.com,anna.ostropolets@odysseusinc.com');
  cRet TEXT;
  cCAGroups INT:=50;
  cRecord record;
BEGIN

  IF is_small THEN 
	iVocabularies:=ARRAY['RxNorm','RxNorm Extension','ATC','NFC','EphMRA ATC'];
  END IF;
  
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
    PERFORM devv5.SendMailHTML ('timur.vakhitov@firstlinesoftware.com', '[DEBUG] concept ancestor iteration='||cRecord.n, '[DEBUG] concept ancestor iteration='||cRecord.n||' of '||cCAGroups);
  END LOOP;
  
  TRUNCATE TABLE concept_ancestor;
  ALTER TABLE concept_ancestor DROP CONSTRAINT IF EXISTS xpkconcept_ancestor;
  DROP INDEX IF EXISTS idx_ca_descendant;
  INSERT INTO concept_ancestor SELECT * FROM temporary_ca$;
  
  --Cleaning
  DROP TABLE temporary_ca$;
  DROP TABLE temporary_ca_groups$;
  DROP TABLE temporary_ca_base$;

  --Create main concept ancestor
  /*EXECUTE '
    insert into concept_ancestor
    with recursive hierarchy_concepts (ancestor_concept_id,descendant_concept_id, root_ancestor_concept_id, levels_of_separation, full_path) as
    (
        select 
            ancestor_concept_id, descendant_concept_id, ancestor_concept_id as root_ancestor_concept_id,
            levels_of_separation, ARRAY [descendant_concept_id] AS full_path
        from concepts 
        --where ancestor_concept_id=718333
        union all
        select 
            c.ancestor_concept_id, c.descendant_concept_id, root_ancestor_concept_id,
            hc.levels_of_separation+c.levels_of_separation as levels_of_separation,
            hc.full_path || c.descendant_concept_id as full_path
        from concepts c
        join hierarchy_concepts hc on hc.descendant_concept_id=c.ancestor_concept_id
        WHERE c.descendant_concept_id <> ALL (full_path)
    ),
    concepts as (
        select
            r.concept_id_1 as ancestor_concept_id,
            r.concept_id_2 as descendant_concept_id,
            case when s.is_hierarchical=1 and c1.standard_concept is not null then 1 else 0 end as levels_of_separation,       
            s.relationship_id
        from concept_relationship r 
        join relationship s on s.relationship_id=r.relationship_id and s.defines_ancestry=1
        join concept c1 on c1.concept_id=r.concept_id_1 and c1.invalid_reason is null and (c1.vocabulary_id=any($1) or $1 is null)
        join concept c2 on c2.concept_id=r.concept_id_2 and c2.invalid_reason is null and (c2.vocabulary_id=any($1) or $1 is null)
        where r.invalid_reason is null
    )    
    select 
        hc.root_ancestor_concept_id as ancestor_concept_id, hc.descendant_concept_id,
        min(hc.levels_of_separation) as min_levels_of_separation,
        max(hc.levels_of_separation) as max_levels_of_separation 
    from hierarchy_concepts hc
    join concept c1 on c1.concept_id=hc.root_ancestor_concept_id and c1.standard_concept is not null
    join concept c2 on c2.concept_id=hc.descendant_concept_id and c2.standard_concept is not null
    --where  descendant_concept_id=766815
    group by hc.root_ancestor_concept_id, hc.descendant_concept_id' USING iVocabularies;*/

  -- Add connections to self for those vocabs having at least one concept in the concept_relationship table

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
        )
        AND c.invalid_reason IS NULL
        AND c.standard_concept IS NOT NULL;

  ALTER TABLE concept_ancestor ADD CONSTRAINT xpkconcept_ancestor PRIMARY KEY(
      ancestor_concept_id,
      descendant_concept_id);
  CREATE INDEX idx_ca_descendant ON concept_ancestor(
      descendant_concept_id);
  analyze concept_ancestor;
  
  --postprocessing
  drop table if exists jump_table;
  create unlogged table jump_table
   as (
        SELECT DISTINCT /* there are many redundant pairs*/
          dc.concept_id AS class_concept_id, rxn.concept_id AS rxn_concept_id
        FROM concept_ancestor class_rxn
        -- get all hierarchical relationships between concepts 'C' ...
        JOIN concept dc ON dc.concept_id = class_rxn.ancestor_concept_id AND dc.standard_concept = CASE WHEN dc.vocabulary_id='CVX' THEN 'S' ELSE 'C' END 
        	AND dc.domain_id = 'Drug' and dc.concept_class_id not in ('Dose Form Group','Clinical Dose Group','Branded Dose Group')
        -- ... and 'S'
        JOIN concept rxn on rxn.concept_id = class_rxn.descendant_concept_id
          AND rxn.standard_concept = 'S'
          AND rxn.domain_id = 'Drug'
          AND rxn.vocabulary_id = 'RxNorm'
      );
  create index idx_jump_table on jump_table (rxn_concept_id,class_concept_id);
  analyze jump_table;

  drop table if exists excluded_concepts;
  create unlogged table excluded_concepts as (
  select ca.descendant_concept_id, j.class_concept_id 
  from jump_table j 
        -- connect all concepts inside the rxn hierachy. Some of them might be above the jump
        join concept_ancestor ca on ca.ancestor_concept_id=j.rxn_concept_id 
        	and ca.ancestor_concept_id<>ca.descendant_concept_id
  );
  create index idx_excluded_concepts on excluded_concepts (descendant_concept_id,class_concept_id); 
  analyze excluded_concepts;

  drop table if exists pair_tbl;
  create unlogged table pair_tbl as (
      select distinct j.class_concept_id, rxn_up.concept_id as rxn_concept_id, j.rxn_concept_id as jump_rxn_concept_id
      from jump_table j 
      JOIN concept_ancestor in_rxn ON in_rxn.descendant_concept_id = j.rxn_concept_id
      JOIN concept rxn_up on rxn_up.concept_id = in_rxn.ancestor_concept_id
        AND rxn_up.standard_concept = 'S'
        AND rxn_up.domain_id = 'Drug'
        AND rxn_up.vocabulary_id = 'RxNorm'   
      where not exists (select 1 from excluded_concepts ec where ec.descendant_concept_id=j.rxn_concept_id and ec.class_concept_id=j.class_concept_id)
  );
  CREATE INDEX idx_pair ON pair_tbl (class_concept_id);
  analyze pair_tbl;  
  
  --Update existing records and add missing relationships between concepts for RxNorm/RxE

  with t_bottom as (
      select ca.ancestor_concept_id, max(ca.min_levels_of_separation) as min_levels_of_separation, max(ca.max_levels_of_separation) as max_levels_of_separation
      from concept_ancestor ca
      join concept c on c.concept_id=ca.descendant_concept_id 
          and c.standard_concept=CASE WHEN c.vocabulary_id='CVX' THEN 'S' ELSE 'C' END
          and c.domain_id='Drug' and c.concept_class_id not in ('Dose Form Group','Clinical Dose Group','Branded Dose Group')
      group by ancestor_concept_id    
  ),
  to_be_upserted as (
      select
        pair.class_concept_id as ancestor_concept_id, -- concept in drug class
        pair.rxn_concept_id as descendant_concept_id, -- concept in RxNorm hierarchy above cross-over from class to RxNorm (jump)
        --direct relationship from ATC4 to Ingredient and no relationship to corresponding ATC5 gives min_level_of_separation = 0, but should be '1'
        min(to_bottom.min_levels_of_separation+case when c.concept_class_id='ATC 4th' then 1 else to_ing.min_levels_of_separation end) as min_levels_of_separation, -- levels in class plus the distance from ingredient to RxNorm concept
        max(to_bottom.max_levels_of_separation+case when c.concept_class_id='ATC 4th' then 1 else to_ing.max_levels_of_separation end) as max_levels_of_separation
      from pair_tbl pair
      -- get distance from class concept to lowest possible class concept
      join t_bottom to_bottom on to_bottom.ancestor_concept_id=pair.class_concept_id
      -- get distance from rxn concept to highest possible (Ingredient) rxn concept
      join concept_ancestor to_ing on to_ing.descendant_concept_id=pair.rxn_concept_id
      join concept c on c.concept_id=pair.class_concept_id
      join concept ing on ing.concept_id=to_ing.ancestor_concept_id and ing.vocabulary_id in ('RxNorm', 'RxNorm Extension') --and ing.concept_class_id='Ingredient'
      and ing.concept_class_id=
      case when c.vocabulary_id in ('ATC','CVX') and 
      (
          select count(*) from 
          (select r.concept_id_1, r.concept_id_2 from concept_relationship r 
          join concept c_int on c_int.concept_id=r.concept_id_2 and c_int.vocabulary_id like 'RxNorm%' and c_int.concept_class_id='Ingredient' and c_int.invalid_reason is null
          where r.invalid_reason is null and r.concept_id_1=pair.jump_rxn_concept_id
          union
          select ds.drug_concept_id, ds.ingredient_concept_id from drug_strength ds where ds.invalid_reason is null and ds.drug_concept_id=pair.jump_rxn_concept_id
          ) as s0
      )>1 then 'Clinical Drug Form' 
      else 'Ingredient'
      end      
      group by pair.class_concept_id, pair.rxn_concept_id
  ),
  to_be_updated as (
      update concept_ancestor ca
      set min_levels_of_separation=up.min_levels_of_separation, 
      max_levels_of_separation=up.max_levels_of_separation
      from to_be_upserted up
      where ca.ancestor_concept_id=up.ancestor_concept_id and ca.descendant_concept_id=up.descendant_concept_id
      RETURNING ca.*
  )
  INSERT INTO concept_ancestor
      SELECT tpu.* FROM to_be_upserted tpu WHERE (tpu.ancestor_concept_id, tpu.descendant_concept_id) 
      NOT IN (SELECT up.ancestor_concept_id, up.descendant_concept_id from to_be_updated up);

  analyze concept_ancestor;

  --replace all RxNorm internal links so only "neighbor" concepts are connected
  --create table with neighbor relationships  
  drop table if exists rxnorm_allowed_rel;
  create unlogged table rxnorm_allowed_rel as (
    select * From (
      with t as (
      select 'Brand Name' c_class_1, 'Brand name of' relationship_id, 'Branded Drug Box' c_class_2 union all
      select 'Brand Name', 'Brand name of', 'Branded Drug Comp' union all
      select 'Brand Name', 'Brand name of', 'Branded Drug Form' union all
      select 'Brand Name', 'Brand name of', 'Branded Drug' union all
      select 'Brand Name', 'Brand name of', 'Branded Pack' union all
      select 'Brand Name', 'Brand name of', 'Branded Pack Box' union all
      select 'Brand Name', 'Brand name of', 'Marketed Product' union all
      select 'Brand Name', 'Brand name of', 'Quant Branded Box' union all
      select 'Brand Name', 'Brand name of', 'Quant Branded Drug' union all
      select 'Branded Drug Box', 'Has marketed form', 'Marketed Product' union all
      select 'Branded Drug Box', 'Has quantified form', 'Quant Branded Box' union all
      select 'Branded Drug Comp', 'Constitutes', 'Branded Drug' union all
      select 'Branded Drug Form', 'RxNorm inverse is a', 'Branded Drug' union all
      select 'Branded Drug', 'Available as box', 'Branded Drug Box' union all
      select 'Branded Drug', 'Has marketed form', 'Marketed Product' union all
      select 'Branded Drug', 'Has quantified form', 'Quant Branded Drug' union all
      select 'Clinical Drug Box', 'Has marketed form', 'Marketed Product' union
      select 'Clinical Drug Box', 'Has quantified form', 'Quant Clinical Box' union all
      select 'Clinical Drug Box', 'Has tradename', 'Branded Drug Box' union all
      select 'Clinical Drug Comp', 'Constitutes', 'Clinical Drug' union all
      select 'Clinical Drug Comp', 'Has tradename', 'Branded Drug Comp' union all
      select 'Clinical Drug Form', 'Has tradename', 'Branded Drug Form' union all
      select 'Clinical Drug Form', 'RxNorm inverse is a', 'Clinical Drug' union all
      select 'Clinical Drug', 'Available as box', 'Clinical Drug Box' union all
      select 'Clinical Drug', 'Has marketed form', 'Marketed Product' union all
      select 'Clinical Drug', 'Has quantified form', 'Quant Clinical Drug' union all
      select 'Clinical Drug', 'Has tradename', 'Branded Drug' union all
      select 'Dose Form', 'RxNorm dose form of', 'Branded Drug Box' union all
      select 'Dose Form', 'RxNorm dose form of', 'Branded Drug Form' union all
      select 'Dose Form', 'RxNorm dose form of', 'Branded Drug' union all
      select 'Dose Form', 'RxNorm dose form of', 'Branded Pack' union all
      select 'Dose Form', 'RxNorm dose form of', 'Clinical Drug Box' union all
      select 'Dose Form', 'RxNorm dose form of', 'Clinical Drug Form' union all
      select 'Dose Form', 'RxNorm dose form of', 'Clinical Drug' union all
      select 'Dose Form', 'RxNorm dose form of', 'Clinical Pack' union all
      select 'Dose Form', 'RxNorm dose form of', 'Marketed Product' union all
      select 'Dose Form', 'RxNorm dose form of', 'Quant Branded Box' union all
      select 'Dose Form', 'RxNorm dose form of', 'Quant Branded Drug' union all
      select 'Dose Form', 'RxNorm dose form of', 'Quant Clinical Box' union all
      select 'Dose Form', 'RxNorm dose form of', 'Quant Clinical Drug' union all
      select 'Ingredient', 'Has brand name', 'Brand Name' union all
      select 'Ingredient', 'RxNorm ing of', 'Clinical Drug Comp' union all
      select 'Ingredient', 'RxNorm ing of', 'Clinical Drug Form' union all
      select 'Marketed Product', 'Has marketed form', 'Marketed Product' union all 
      select 'Supplier', 'Supplier of', 'Marketed Product' union all
      select 'Quant Branded Box', 'Has marketed form', 'Marketed Product' union all
      select 'Quant Branded Drug', 'Available as box', 'Quant Branded Box' union all
      select 'Quant Branded Drug', 'Has marketed form', 'Marketed Product' union all
      select 'Quant Clinical Box', 'Has marketed form', 'Marketed Product' union all
      select 'Quant Clinical Box', 'Has tradename', 'Quant Branded Box' union all
      select 'Quant Clinical Drug', 'Available as box', 'Quant Clinical Box' union all
      select 'Quant Clinical Drug', 'Has marketed form', 'Marketed Product' union all
      select 'Quant Clinical Drug', 'Has tradename', 'Quant Branded Drug' union all
      --new relationships 20170412
      select 'Branded Dose Group', 'Has brand name', 'Brand Name' union all
      select 'Branded Dose Group', 'Has dose form group', 'Dose Form Group' union all
      select 'Branded Dose Group', 'Marketed form of', 'Dose Form Group' union all
      select 'Branded Dose Group', 'RxNorm has ing', 'Brand Name' union all
      select 'Branded Dose Group', 'RxNorm inverse is a', 'Branded Drug Form' union all
      select 'Branded Dose Group', 'RxNorm inverse is a', 'Branded Drug' union all
      select 'Branded Dose Group', 'RxNorm inverse is a', 'Quant Branded Drug' union all
      select 'Branded Dose Group', 'RxNorm inverse is a', 'Quant Clinical Drug' union all
      select 'Branded Dose Group', 'Tradename of', 'Clinical Dose Group' union all
      select 'Clinical Dose Group', 'Has dose form group', 'Dose Form Group' union all
      select 'Clinical Dose Group', 'Marketed form of', 'Dose Form Group' union all
      select 'Clinical Dose Group', 'RxNorm has ing', 'Ingredient' union all
      select 'Clinical Dose Group', 'RxNorm has ing', 'Precise Ingredient' union all
      select 'Clinical Dose Group', 'RxNorm inverse is a', 'Clinical Drug Form' union all
      select 'Clinical Dose Group', 'RxNorm inverse is a', 'Clinical Drug' union all
      select 'Clinical Dose Group', 'RxNorm inverse is a', 'Quant Branded Drug' union all
      select 'Clinical Dose Group', 'RxNorm inverse is a', 'Quant Clinical Drug' union all
      select 'Dose Form Group', 'RxNorm inverse is a', 'Dose Form' union all
      --added 24.04.2017 (AVOF-341)
      select 'Precise Ingredient', 'Form of', 'Ingredient' UNION ALL
      --added 13.07.2017 (AVOF-468)
      select 'Clinical Drug', 'Contained in', 'Clinical Pack' UNION ALL
      select 'Clinical Drug', 'Contained in', 'Clinical Pack Box' UNION ALL
      select 'Clinical Drug', 'Contained in', 'Branded Pack' UNION ALL
      select 'Clinical Drug', 'Contained in', 'Branded Pack Box' UNION ALL
      select 'Clinical Drug', 'Contained in', 'Marketed Product' UNION ALL
      select 'Branded Drug', 'Contained in', 'Branded Pack' UNION ALL
      select 'Branded Drug', 'Contained in', 'Branded Pack Box' UNION ALL
      select 'Branded Drug', 'Contained in', 'Marketed Product' UNION ALL
      select 'Quant Clinical Drug', 'Contained in', 'Clinical Pack' UNION ALL
      select 'Quant Clinical Drug', 'Contained in', 'Clinical Pack Box' UNION ALL
      select 'Quant Clinical Drug', 'Contained in', 'Branded Pack' UNION ALL
      select 'Quant Clinical Drug', 'Contained in', 'Branded Pack Box' UNION ALL
      select 'Quant Clinical Drug', 'Contained in', 'Marketed Product' UNION ALL
      select 'Quant Branded Drug', 'Contained in', 'Branded Pack' UNION ALL
      select 'Quant Branded Drug', 'Contained in', 'Branded Pack Box' UNION ALL
      select 'Quant Branded Drug', 'Contained in', 'Marketed Product' UNION ALL
      --inner-pack relationship
      select 'Branded Pack', 'Has marketed form', 'Marketed Product' UNION ALL
      select 'Branded Pack Box', 'Has marketed form', 'Marketed Product' UNION ALL
      select 'Branded Pack', 'Available as box', 'Branded Pack Box' UNION ALL
      select 'Clinical Pack', 'Has marketed form', 'Marketed Product' UNION ALL
      select 'Clinical Pack Box', 'Has marketed form', 'Marketed Product' UNION ALL
      select 'Clinical Pack', 'Has tradename', 'Branded Pack' UNION ALL
      select 'Clinical Pack', 'Available as box', 'Clinical Pack Box' UNION ALL
      select 'Clinical Pack Box', 'Has tradename', 'Branded Pack Box'
    ) 
    select * from t 
    union all 
    --add reverse
    select c_class_2, r.reverse_relationship_id, c_class_1 
    from t rra, relationship r
    where rra.relationship_id=r.relationship_id
    ) as s1
  );
  
  --create table with wrong relationships (non-neighbor relationships)
  drop table if exists rxnorm_wrong_rel;
  create unlogged table rxnorm_wrong_rel as
  select c1.concept_class_id, r.concept_id_1, r.concept_id_2, r.relationship_id From concept c1, concept c2, concept_relationship r
  where c1.concept_id=r.concept_id_1
  and c2.concept_id=r.concept_id_2
  and r.invalid_reason is null
  and c1.vocabulary_id='RxNorm'
  and c2.vocabulary_id='RxNorm'
  and r.relationship_id not in ('Maps to','Precise ing of','Has precise ing','Concept replaces','Mapped from','Concept replaced by')
  and (c1.concept_class_id not like '%Pack' or c2.concept_class_id not like '%Pack')
  and (c1.concept_class_id,c2.concept_class_id) not in (select c_class_1, c_class_2 from rxnorm_allowed_rel);
  
  --add missing neighbor relationships (if not exists)
  with neighbor_relationships as (
    select ca1.ancestor_concept_id c_id1, ca2.ancestor_concept_id c_id2, rra.relationship_id 
    From rxnorm_wrong_rel wr, concept_ancestor ca1, concept_ancestor ca2, rxnorm_allowed_rel rra, concept c_dest 
    where ca1.descendant_concept_id=ca2.ancestor_concept_id
    and ca1.ancestor_concept_id=wr.concept_id_1 and ca2.descendant_concept_id=wr.concept_id_2
    and ca2.ancestor_concept_id<>ca2.descendant_concept_id
    and ca2.ancestor_concept_id<>ca1.ancestor_concept_id
    and c_dest.concept_id=ca2.ancestor_concept_id
    and rra.c_class_1=wr.concept_class_id
    and rra.c_class_2=c_dest.concept_class_id
  )
  INSERT INTO concept_relationship 
  select  nr.c_id1,
          nr.c_id2,
          nr.relationship_id,
          CURRENT_DATE,
          to_date ('20991231', 'YYYYMMDD'),
          null as invalid_reason
  from neighbor_relationships nr
  where not exists (select 1 from concept_relationship cr_int where cr_int.concept_id_1=nr.c_id1 and cr_int.concept_id_2=nr.c_id2 and cr_int.relationship_id=nr.relationship_id);
  
  --deprecate wrong relationships
  update concept_relationship set valid_end_date=CURRENT_DATE, invalid_reason='D'
  where (concept_id_1, concept_id_2, relationship_id) in (select concept_id_1, concept_id_2, relationship_id From rxnorm_wrong_rel)
  and invalid_reason is null;
  
  --create direct links between Branded* and Brand Names
  with to_be_upserted as (
    SELECT DISTINCT c1.concept_id AS concept_id_1,
        c2.concept_id AS concept_id_2,
        'Has brand name' AS relationship_id,
        CURRENT_DATE AS valid_start_date,
        TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
        NULL as invalid_reason        
    FROM concept_ancestor ca,
        concept_relationship r,
        concept c1,
        concept c2,
        concept c3
    WHERE ca.ancestor_concept_id = r.concept_id_1
        AND r.invalid_reason IS NULL
        AND relationship_id = 'Has brand name'
        AND ca.descendant_concept_id = c1.concept_id
        AND c1.vocabulary_id IN (
            'RxNorm',
            'RxNorm Extension'
            )
        AND c1.concept_class_id IN (
            'Branded Drug Box',
            'Quant Branded Box',
            'Branded Drug Comp',
            'Quant Branded Drug',
            'Branded Drug Form',
            'Branded Drug',
            'Marketed Product'
            )
        AND r.concept_id_2 = c2.concept_id
        AND c2.vocabulary_id IN (
            'RxNorm',
            'RxNorm Extension'
            )
        AND c2.concept_class_id = 'Brand Name'
        AND c2.invalid_reason IS NULL
        AND c3.concept_id = r.concept_id_1
        AND c3.concept_class_id <> 'Ingredient'
  ),
  to_be_updated as (
    update concept_relationship cr
    set invalid_reason = NULL, valid_end_date = up.valid_end_date
    from to_be_upserted up
    where cr.concept_id_1=up.concept_id_1 
    and cr.concept_id_2=up.concept_id_2
    and cr.relationship_id=up.relationship_id
    RETURNING cr.*
  )
  INSERT INTO concept_relationship
    SELECT tpu.* FROM to_be_upserted tpu WHERE (tpu.concept_id_1, tpu.concept_id_2, tpu.relationship_id) 
    NOT IN (SELECT up.concept_id_1, up.concept_id_2, up.relationship_id from to_be_updated up);  
  
  --reverse

  with to_be_upserted as (
    SELECT DISTINCT c1.concept_id AS concept_id_1,
        c2.concept_id AS concept_id_2,
        'Brand name of' AS relationship_id,
        CURRENT_DATE AS valid_start_date,
        TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
        NULL as invalid_reason
    FROM concept_ancestor ca,
        concept_relationship r,
        concept c1,
        concept c2,
        concept c3
    WHERE ca.ancestor_concept_id = r.concept_id_2
        AND r.invalid_reason IS NULL
        AND relationship_id = 'Brand name of'
        AND ca.descendant_concept_id = c2.concept_id
        AND c2.vocabulary_id IN (
            'RxNorm',
            'RxNorm Extension'
            )
        AND c2.concept_class_id IN (
            'Branded Drug Box',
            'Quant Branded Box',
            'Branded Drug Comp',
            'Quant Branded Drug',
            'Branded Drug Form',
            'Branded Drug',
            'Marketed Product'
            )
        AND r.concept_id_1 = c1.concept_id
        AND c1.vocabulary_id IN (
            'RxNorm',
            'RxNorm Extension'
            )
        AND c1.concept_class_id = 'Brand Name'
        AND c1.invalid_reason IS NULL
        AND c3.concept_id = r.concept_id_2
        AND c3.concept_class_id <> 'Ingredient'
  ),
  to_be_updated as (
    update concept_relationship cr
    set invalid_reason = NULL, valid_end_date = up.valid_end_date
    from to_be_upserted up
    where cr.concept_id_1=up.concept_id_1 
    and cr.concept_id_2=up.concept_id_2
    and cr.relationship_id=up.relationship_id
    RETURNING cr.*
  )
  INSERT INTO concept_relationship
    SELECT tpu.* FROM to_be_upserted tpu WHERE (tpu.concept_id_1, tpu.concept_id_2, tpu.relationship_id) 
    NOT IN (SELECT up.concept_id_1, up.concept_id_2, up.relationship_id from to_be_updated up);  
  
  --section for units of ingredients and drug forms. this is after the RxNorm and RxNorm Extensions are in there (AVOF-365)    
  DELETE
  FROM drug_strength
  WHERE amount_unit_concept_id IS NOT NULL AND amount_value IS NULL;
  
  INSERT INTO drug_strength
  SELECT *
  FROM (
      WITH ingredient_unit AS (
              SELECT DISTINCT
                  -- pick the most common unit for an ingredient. If there is a draw, pick always the same by sorting by unit_concept_id
                  ingredient_concept_code,
                  vocabulary_id,
                  FIRST_VALUE(unit_concept_id) OVER (
                      PARTITION BY ingredient_concept_code ORDER BY cnt DESC,
                          unit_concept_id
                      ) AS unit_concept_id
              FROM (
                  -- sum the counts coming from amount and numerator
                  SELECT ingredient_concept_code,
                      vocabulary_id,
                      unit_concept_id,
                      SUM(cnt) AS cnt
                  FROM (
                      -- count ingredients, their units and the frequency
                      SELECT c2.concept_code AS ingredient_concept_code,
                          c2.vocabulary_id,
                          ds.amount_unit_concept_id AS unit_concept_id,
                          COUNT(*) AS cnt
                      FROM drug_strength ds
                      JOIN concept c1 ON c1.concept_id = ds.drug_concept_id
                          AND c1.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                      JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id
                          AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                      WHERE ds.amount_value <> 0 AND ds.amount_unit_concept_id IS NOT NULL
                      GROUP BY c2.concept_code,
                          c2.vocabulary_id,
                          ds.amount_unit_concept_id
  					
                      UNION
  					
                      SELECT c2.concept_code AS ingredient_concept_code,
                          c2.vocabulary_id,
                          ds.numerator_unit_concept_id AS unit_concept_id,
                          COUNT(*) AS cnt
                      FROM drug_strength ds
                      JOIN concept c1 ON c1.concept_id = ds.drug_concept_id
                          AND c1.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                      JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id
                          AND c2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
                      WHERE ds.numerator_value <> 0 AND ds.numerator_unit_concept_id IS NOT NULL
                      GROUP BY c2.concept_code,
                          c2.vocabulary_id,
                          ds.numerator_unit_concept_id
                      ) as s1
                  GROUP BY ingredient_concept_code,
                      vocabulary_id,
                      unit_concept_id
                  ) as s2
              )
      -- Create drug_strength for ingredients
      SELECT c.concept_id AS drug_concept_id,
          c.concept_id AS ingredient_concept_id,
          NULL::FLOAT AS amount_value,
          iu.unit_concept_id AS amount_unit_concept_id,
          NULL::FLOAT AS numerator_value,
          NULL::INT4 AS numerator_unit_concept_id,
          NULL::FLOAT AS denominator_value,
          NULL::INT4 AS denominator_unit_concept_id,
          NULL::INT4 AS box_size,
          c.valid_start_date,
          c.valid_end_date,
          c.invalid_reason
      FROM ingredient_unit iu
      JOIN concept c ON c.concept_code = iu.ingredient_concept_code
          AND c.vocabulary_id = iu.vocabulary_id
  	
      UNION
  	
      -- Create drug_strength for drug forms
      SELECT de.concept_id AS drug_concept_code,
          an.concept_id AS ingredient_concept_code,
          NULL AS amount_value,
          iu.unit_concept_id AS amount_unit_concept_id,
          NULL AS numerator_value,
          NULL AS numerator_unit_concept_id,
          NULL AS denominator_value,
          NULL AS denominator_unit_concept_id,
          NULL AS box_size,
          an.valid_start_date,
          an.valid_end_date,
          an.invalid_reason
      FROM concept an
      JOIN concept_ancestor a ON a.ancestor_concept_id = an.concept_id
      JOIN concept de ON de.concept_id = a.descendant_concept_id
      JOIN ingredient_unit iu ON iu.ingredient_concept_code = an.concept_code
          AND iu.vocabulary_id = an.vocabulary_id
      WHERE an.vocabulary_id IN (
              'RxNorm',
              'RxNorm Extension'
              )
          AND an.concept_class_id = 'Ingredient'
          AND de.vocabulary_id IN (
              'RxNorm',
              'RxNorm Extension'
              )
          AND de.concept_class_id IN (
              'Clinical Drug Form',
              'Branded Drug Form'
              )
      ) as s3;

  --clean up
  drop table jump_table;
  drop table excluded_concepts;
  drop table pair_tbl;
  drop table rxnorm_allowed_rel;
  drop table rxnorm_wrong_rel;

  if is_small then
  	PERFORM devv5.SendMailHTML (iSmallCA_emails, 'Small concept ancestor in '||upper(current_schema)||' [ok]', 'Small concept ancestor in '||upper(current_schema)||' completed');
  end if;
  
  EXCEPTION
  WHEN OTHERS
  THEN
    if is_small then
	  GET STACKED DIAGNOSTICS cRet = PG_EXCEPTION_CONTEXT;
      cRet:='ERROR: '||SQLERRM||crlf||'CONTEXT: '||regexp_replace(cRet, '\r|\n|\r\n', crlf, 'g');
      cRet := SUBSTR ('Small concept ancestor completed with errors:'||crlf||'<b>'||cRet||'</b>', 1, 5000);
      PERFORM devv5.SendMailHTML (iSmallCA_emails, 'Small concept ancestor in '||upper(current_schema)||' [error]', cRet);  
    else
      raise;
    end if;
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100
SET client_min_messages = error;