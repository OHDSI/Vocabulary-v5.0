CREATE OR REPLACE FUNCTION vocabulary_pack.GetAncestorLoops (pVocabularies TEXT)
RETURNS SETOF concept_ancestor AS
$BODY$
	/*
	Use this function to found loops during the concept_ancestor building

	Example:
	SELECT * FROM vocabulary_pack.GetAncestorLoops(pVocabularies=>'CVX,SNOMED,RxNorm');
	*/
BEGIN
	PERFORM vocabulary_pack.ConceptAncestorCore(pVocabularies, TRUE);

	PERFORM FROM temporary_ca$ LIMIT 1;
	IF NOT FOUND THEN
		RAISE EXCEPTION 'No loops found in the concept_relationship table';
	END IF;

	RETURN QUERY TABLE temporary_ca$;
END;
$BODY$
LANGUAGE 'plpgsql';