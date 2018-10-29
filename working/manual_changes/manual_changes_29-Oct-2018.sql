--Move all concepts from Death Type to Condition Type + change some names [AVOF-1296]
do $_$
begin
update concept set concept_name=concept_name||' of death' where concept_id in (254, 255, 256);
update concept set vocabulary_id='Condition Type' where vocabulary_id='Death Type';
end $_$;