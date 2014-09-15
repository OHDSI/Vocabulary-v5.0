-- Create
create user prototype
  identified by 123
  default tablespace users
  temporary tablespace temp
  profile default
  account unlock;

 -- Grants
grant connect to prototype;
alter user prototype default role all;
grant create procedure to prototype;
grant create sequence to prototype;
grant create any index to prototype;
grant create database link to prototype;
grant create table to prototype;
grant create view to prototype;
alter user prototype quota unlimited on users;

-- Access to dev
grant select, insert, update, delete on dev.concept to prototype; 
grant select, insert, update, delete on dev.concept_relationship to prototype;
grant select, insert, update, delete on dev.concept_ancestor to prototype;
grant select, insert, update, delete on dev.relationship to prototype;
grant select, insert, update, delete on dev.source_to_concept_map to prototype;
grant select, insert, update, delete on dev.vocabulary to prototype;
grant select on dev.seq_concept to prototype;

