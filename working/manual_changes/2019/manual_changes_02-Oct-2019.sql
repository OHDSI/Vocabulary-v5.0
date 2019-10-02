--https://github.com/OHDSI/Vocabulary-v5.0/issues/244
update concept set concept_name='Canonical' where concept_id=44819053;
update concept set valid_end_date=CURRENT_DATE, invalid_reason='D' where concept_id=55;