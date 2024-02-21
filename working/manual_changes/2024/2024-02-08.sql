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

-- Update concept_code and domain_id for concepts in Relationship vocabulary:
UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217056'
WHERE concept_id = 32668;

UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217057'
WHERE concept_id = 32669;

UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217058'
WHERE concept_id = 581410;

UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217059'
WHERE concept_id = 581411;

UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217060'
WHERE concept_id = 581436;

UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217061'
WHERE concept_id = 581437;

UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217062'
WHERE concept_id = 46233680;

UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217063'
WHERE concept_id = 46233681;

UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217064'
WHERE concept_id = 46233682;

UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217065'
WHERE concept_id = 46233683;

UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217066'
WHERE concept_id = 46233684;

UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217067'
WHERE concept_id = 46233685;

UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217068'
WHERE concept_id = 46233688;

UPDATE concept
SET domain_id = 'Relationship',
	concept_code = 'OMOP5217069'
WHERE concept_id = 46233689;

