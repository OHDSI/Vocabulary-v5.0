-- Add new relationships to SNOMED:
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'Process acts on (SNOMED)',
    pRelationship_id         =>'Process acts on',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'Affected by process',
    pRelationship_name_rev   =>'Affected by process (SNOMED)',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'Before (SNOMED)',
    pRelationship_id         =>'Before',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'After',
    pRelationship_name_rev   =>'After (SNOMED)',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'Towards (SNOMED)',
    pRelationship_id         =>'Towards',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'Subject of',
    pRelationship_name_rev   =>'Subject of (SNOMED)',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;

-- Add new concept class 'Disorder':
DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewConceptClass(
    pConcept_class_id       =>'Disorder',
    pConcept_class_name     =>'Disorder'
);
END $_$;

-- Update domain_id in Relationship vocabulary:
UPDATE concept
SET domain_id = 'Relationship'
WHERE vocabulary_id = 'Relationship';

--

