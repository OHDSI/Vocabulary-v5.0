CREATE OR REPLACE FUNCTION vocabulary_pack.getancestorpath_in_dev (
  pancestorid integer,
  pdescendantid integer
)
RETURNS TABLE (
  ancestorconceptid integer,
  descendantconceptid integer,
  hierarchypath text
) AS
$body$
BEGIN
	RETURN QUERY
    with recursive hierarchy_concepts (ancestor_concept_id,descendant_concept_id, root_ancestor_concept_id, hierarchy_path, full_path) as
    (
        select 
            ancestor_concept_id, descendant_concept_id, ancestor_concept_id as root_ancestor_concept_id,
            ancestor_concept_id||' '''||relationship_id||''' '||descendant_concept_id as hierarchy_path,
            ARRAY [descendant_concept_id] AS full_path
        from concepts 
        where ancestor_concept_id=pAncestorID
        union all
        select 
            c.ancestor_concept_id, c.descendant_concept_id, root_ancestor_concept_id,
            hc.hierarchy_path||' '''||c.relationship_id||''' '||c.descendant_concept_id as hierarchy_path,
            hc.full_path || c.descendant_concept_id as full_path
        from concepts c
        join hierarchy_concepts hc on hc.descendant_concept_id=c.ancestor_concept_id
        WHERE c.descendant_concept_id <> ALL (full_path)
    ),
    concepts as (
        select
            r.concept_id_1 as ancestor_concept_id,
            r.concept_id_2 as descendant_concept_id,    
            s.relationship_id
        from concept_relationship r 
        join relationship s on s.relationship_id=r.relationship_id and s.defines_ancestry=1
        join concept c1 on c1.concept_id=r.concept_id_1 and c1.invalid_reason is null
        join concept c2 on c2.concept_id=r.concept_id_2 and c2.invalid_reason is null
        where r.invalid_reason is null
    )    
    select 
        hc.root_ancestor_concept_id as ancestor_concept_id, hc.descendant_concept_id, hc.hierarchy_path
    from hierarchy_concepts hc
    join concept c1 on c1.concept_id=hc.root_ancestor_concept_id and c1.standard_concept is not null
    join concept c2 on c2.concept_id=hc.descendant_concept_id and c2.standard_concept is not null
    where  descendant_concept_id=pDescendantID;
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;