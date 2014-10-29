-- Copy all relevant tables from DevV5

create table CONCEPT as select * from v5Dev.CONCEPT;
create table VOCABULARY as select * from v5Dev.VOCABULARY;
create table DOMAIN as select * from v5Dev.DOMAIN;
create table CONCEPT_CLASS as select * from v5Dev.CONCEPT_CLASS;
create table CONCEPT_RELATIONSHIP as select * from v5Dev.CONCEPT_RELATIONSHIP;
create table RELATIONSHIP as select * from v5Dev.RELATIONSHIP;
create table CONCEPT_SYNONYM as select * from v5Dev.CONCEPT_SYNONYM;
create table CONCEPT_ANCESTOR as select * from v5Dev.CONCEPT_ANCESTOR;
create table DRUG_STRENGTH as select * from v5Dev.DRUG_STRENGTH;
create table VOCABULARY_CONVERSION as select * from v5Dev.VOCABULARY_CONVERSION;

alter table CONCEPT add constraint XPK_CONCEPT primary key (CONCEPT_ID);
create index CONCEPT_vocab on CONCEPT (vocabulary_id);

create index CONCEPT_RELATIONSHIP_C_1 on CONCEPT_RELATIONSHIP (concept_id_1);
create index CONCEPT_RELATIONSHIP_C_2 on CONCEPT_RELATIONSHIP (concept_id_2);

create index CONCEPT_SYNONYM_concept on CONCEPT_SYNONYM (concept_id);

