--wrong Maps to/Maps to value
update concept_relationship set valid_end_date=current_date, invalid_reason='D' where concept_id_1=44814693 and concept_id_2=44814693 and relationship_id in ('Maps to value','Value mapped from');
update concept_relationship set valid_end_date=current_date, invalid_reason='D' where concept_id_1=38004311 and concept_id_2=8546 and relationship_id='Maps to';
update concept_relationship set valid_end_date=current_date, invalid_reason='D' where concept_id_1=8546 and concept_id_2=38004311 and relationship_id='Mapped from';