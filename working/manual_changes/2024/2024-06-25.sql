--Add new Drug specific relationships for HemOnc

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has growth factor (HemOnc)',
	pRelationship_id			=>'Has growth factor',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Growth factor of (HemOnc)',
	pReverse_relationship_id		=>'Growth factor of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;


DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has anticoag Rx (HemOnc)',
	pRelationship_id			=>'Has anticoag Rx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Anticoag Rx of (HemOnc)',
	pReverse_relationship_id		=>'Anticoag Rx of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has anticoag tx (HemOnc)',
	pRelationship_id			=>'Has anticoag tx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Anticoag tx of (HemOnc)',
	pReverse_relationship_id		=>'Anticoag tx of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;


DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has growth factor Rx (HemOnc)',
	pRelationship_id			=>'Has growth factor Rx',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'Growth factor Rx of (HemOnc)',
	pReverse_relationship_id		=>'Growth factor Rx of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;


--indications

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has EMA indication (HemOnc)',
	pRelationship_id			=>'Has EMA indication',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'EMA indication of (HemOnc)',
	pReverse_relationship_id		=>'EMA indication of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has HC indication (HemOnc)',
	pRelationship_id			=>'Has HC indication',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'HC indication of (HemOnc)',
	pReverse_relationship_id		=>'HC indication of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has NMPA indication (HemOnc)',
	pRelationship_id			=>'Has NMPA indication',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'NMPA indication of (HemOnc)',
	pReverse_relationship_id		=>'NMPA indication of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;

DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewRelationship(
	pRelationship_name			=>'Has PMDA indication (HemOnc)',
	pRelationship_id			=>'Has PMDA indication',
	pIs_hierarchical			=>0,
	pDefines_ancestry			=>0,
	pRelationship_name_rev	=>'PMDA indication of (HemOnc)',
	pReverse_relationship_id		=>'PMDA indication of',
	pIs_hierarchical_rev		=>0,
	pDefines_ancestry_rev		=>0
);
END $_$;


--synth reg

    DO $_$
    BEGIN
        PERFORM vocabulary_pack.AddNewRelationship(
        pRelationship_name			=>'Has synthetic regimen (HemOnc)',
        pRelationship_id			=>'Has synth regimen',
        pIs_hierarchical			=>0,
        pDefines_ancestry			=>0,
        pRelationship_name_rev	=>'Synthetic regimen of(HemOnc)',
        pReverse_relationship_id		=>'Synth regimen of',
        pIs_hierarchical_rev		=>0,
        pDefines_ancestry_rev		=>0
    );
    END $_$;
