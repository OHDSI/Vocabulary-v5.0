-- New vocab build Jan 2014

-- Copy tables from 
create table concept as select * from v5dev.concept;
create table concept_relationship as select * from v5dev.concept_relationship;
create table relationship as select * from v5dev.relationship;
create table vocabulary as select * from v5dev.vocabulary;
create table concept_class as select * from v5dev.concept_class;
create table domain as select * from v5dev.domain;
