DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'Has NHS dm+d (dictionary of medicines and devices) additional monitoring indicator',
    pRelationship_id         =>'Has add monitor ind',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'Add monitor ind of',
    pRelationship_name_rev   =>'NHS dm+d (dictionary of medicines and devices) additional monitoring indicator of',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'Has NHS dm+d (dictionary of medicines and devices) AMP (actual medicinal product) availability restriction indicator',
    pRelationship_id         =>'Has AMP restr ind',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'AMP restr ind of',
    pRelationship_name_rev   =>'NHS dm+d (dictionary of medicines and devices) AMP (actual medicinal product) availability restriction indicator of',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'Has NHS dm+d parallel import indicator',
    pRelationship_id         =>'Paral imprt ind',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'Paral imprt of',
    pRelationship_name_rev   =>'NHS dm+d parallel import indicator of',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'Has NHS dm+d freeness indicator',
    pRelationship_id         =>'Has free indicator',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'Free indicator of',
    pRelationship_name_rev   =>'NHS dm+d freenes indicator of',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;

DO $_$
BEGIN
  PERFORM vocabulary_pack.AddNewRelationship(
    pRelationship_name       =>'Process duration',
    pRelationship_id         =>'Has proc duration',
    pIs_hierarchical         =>0,
    pDefines_ancestry        =>0,
    pReverse_relationship_id =>'Proc duration of',
    pRelationship_name_rev   =>'Process duration of',
    pIs_hierarchical_rev     =>0,
    pDefines_ancestry_rev    =>0
);
END $_$;
