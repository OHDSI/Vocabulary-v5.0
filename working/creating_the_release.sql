--1. create copy of base tables
--run in DEVV5
drop table concept_old purge;
create table concept_old nologging as select * From concept;
drop table concept_relationship_old purge;
create table concept_relationship_old nologging as select * From concept_relationship;
drop table concept_synonym_old purge;
create table concept_synonym_old nologging as select * From concept_synonym;

--2. update vocabulaies (with generic_update)

--3. make checks
exec DEVV5.QA_TESTS.PURGE_CACHE;
select * from table(DEVV5.QA_TESTS.GET_SUMMARY('concept')); 
select * from table(DEVV5.QA_TESTS.GET_SUMMARY('concept_relationship'));
select * from table(DEVV5.QA_TESTS.GET_SUMMARY('concept_ancestor'));
select * from table(DEVV5.QA_TESTS.GET_CHECKS);

--4. start the release (concept_ancestor, v5-to-v4 conversion, copying data to PROD)
--run in DEVV5
exec vocabulary_pack.StartRelease;

