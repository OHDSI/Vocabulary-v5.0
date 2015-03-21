-- Copy all relevant tables from DevV5

create table CONCEPT as select * from devv5.CONCEPT;
create table VOCABULARY as select * from devv5.VOCABULARY;
create table CONCEPT_RELATIONSHIP as select * from devv5.CONCEPT_RELATIONSHIP;
create table RELATIONSHIP as select * from devv5.RELATIONSHIP;
create table CONCEPT_SYNONYM as select * from devv5.CONCEPT_SYNONYM;
create table CONCEPT_ANCESTOR as select * from devv5.CONCEPT_ANCESTOR;
create table DOMAIN as select * from devv5.DOMAIN;
create table DRUG_STRENGTH as select * from devv5.DRUG_STRENGTH;
create table CONCEPT_CLASS as select * from devv5.CONCEPT_CLASS;

update vocabulary set vocabulary_name='OMOP Vocabulary v5.0 '||sysdate where vocabulary_id='None';

alter table CONCEPT add constraint XPK_CONCEPT primary key (CONCEPT_ID);
create index CONCEPT_vocab on CONCEPT (vocabulary_id);

create index CONCEPT_RELATIONSHIP_C_1 on CONCEPT_RELATIONSHIP (concept_id_1);
create index CONCEPT_RELATIONSHIP_C_2 on CONCEPT_RELATIONSHIP (concept_id_2);

create index CONCEPT_SYNONYM_concept on CONCEPT_SYNONYM (concept_id);