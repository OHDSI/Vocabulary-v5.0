-- Create
create user v5dev
  identified by 123
  default tablespace users
  temporary tablespace temp
  profile default
  account unlock;

 -- Grants
grant connect to v5dev;
alter user v5dev default role all;
grant create procedure to v5dev;
grant create sequence to v5dev;
grant create any index to v5dev;
grant create database link to v5dev;
grant create table to v5dev;
grant create view to v5dev;
alter user v5dev quota unlimited on users;

-- Access to v5dev
grant select, insert, update, delete on v5dev.concept to v5dev; 
grant select, insert, update, delete on v5dev.concept_relationship to v5dev;
grant select, insert, update, delete on v5dev.concept_ancestor to v5dev;
grant select, insert, update, delete on v5dev.relationship to v5dev;
grant select, insert, update, delete on v5dev.source_to_concept_map to v5dev;
grant select, insert, update, delete on v5dev.vocabulary to v5dev;
grant select on v5dev.seq_concept to v5dev;

