--AVOF-3294
do $$
begin
	UPDATE relationship
	SET relationship_name = 'Panel contains'
	WHERE relationship_id = 'Panel contains';

	UPDATE concept
	SET concept_name = 'Panel contains'
	WHERE concept_id = 46233678;

	UPDATE relationship
	SET relationship_name = 'Contained in panel'
	WHERE relationship_id = 'Contained in panel';

	UPDATE concept
	SET concept_name = 'Contained in panel'
	WHERE concept_id = 46233679;
end $$;