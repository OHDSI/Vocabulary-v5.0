-- Copy all relevant tables from DevV4

create table CONCEPT as select * from devv4.CONCEPT;
create table VOCABULARY as select * from devv4.VOCABULARY;
create table CONCEPT_RELATIONSHIP as select * from devv4.CONCEPT_RELATIONSHIP;
create table RELATIONSHIP as select * from devv4.RELATIONSHIP;
create table CONCEPT_SYNONYM as select * from devv4.CONCEPT_SYNONYM;
create table CONCEPT_ANCESTOR as select * from devv4.CONCEPT_ANCESTOR;
create table SOURCE_TO_CONCEPT_MAP as select * from devv4.SOURCE_TO_CONCEPT_MAP;
create table DRUG_STRENGTH as select * from devv4.DRUG_STRENGTH;

update vocabulary set vocabulary_name='OMOP Vocabulary v4.5' ||sysdate where vocabulary_id=0;

alter table CONCEPT add constraint XPK_CONCEPT primary key (CONCEPT_ID);
create index CONCEPT_vocab on CONCEPT (vocabulary_id);

create index CONCEPT_RELATIONSHIP_C_1 on CONCEPT_RELATIONSHIP (concept_id_1);
create index CONCEPT_RELATIONSHIP_C_2 on CONCEPT_RELATIONSHIP (concept_id_2);

create index CONCEPT_SYNONYM_concept on CONCEPT_SYNONYM (concept_id);