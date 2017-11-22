--deprecate old wrong links from SNOMED to SNOMED (and reverse)
update concept_relationship set invalid_reason='D', valid_end_date=to_date('20171122','yyyymmdd') where relationship_id='Morphology of' and invalid_reason is null;
update concept_relationship set invalid_reason='D', valid_end_date=to_date('20171122','yyyymmdd') where relationship_id='Has morphology' and invalid_reason is null;
commit;