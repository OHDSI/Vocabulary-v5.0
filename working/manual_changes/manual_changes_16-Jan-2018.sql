--rename BCFI to GGR
begin
EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DISABLE CONSTRAINT fpk_vocabulary_concept';
EXECUTE IMMEDIATE 'ALTER TABLE concept DISABLE CONSTRAINT fpk_concept_vocabulary';
update concept set vocabulary_id='GGR' where vocabulary_id='BCFI';
update concept set concept_name='GGR' where vocabulary_id='Vocabulary' and concept_name ='BCFI';
update vocabulary set vocabulary_id='GGR', vocabulary_name = 'Commented Drug Directory (BFCI)' where vocabulary_id='BCFI';
update vocabulary_conversion set vocabulary_id_v5='GGR' where vocabulary_id_v5='BCFI';
EXECUTE IMMEDIATE 'ALTER TABLE vocabulary ENABLE CONSTRAINT fpk_vocabulary_concept';
EXECUTE IMMEDIATE 'ALTER TABLE concept ENABLE CONSTRAINT fpk_concept_vocabulary';
end;

--fix vocabulary_name for CDT
update vocabulary set vocabulary_name = 'Current Dental Terminology (ADA)' where vocabulary_id='CDT';
COMMIT;