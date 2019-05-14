--insert relationship between vaccine and insulins to concept_relationship_manual
insert into concept_relationship_manual
select 
null::integer,
null::integer, 
fcc ,
concept_code,
'GRR',
vocabulary_id, 
'Maps to', 
current_date , 
TO_DATE('20991231', 'yyyymmdd'), 
null::varchar
from vacc_ins_manual
join concept on concept_id = c_id::integer;

-- Append result to concept_relationship_stage table
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;


