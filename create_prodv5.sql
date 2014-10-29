-- Create production environment for version 5.0 voabulary
create user ProdV5 identified by "123" default tablespace USERS temporary tablespace TEMP quota unlimited on users;

grant create cluster to ProdV5;
grant create indextype to ProdV5;
grant create operator to ProdV5;
grant create procedure to ProdV5;
grant create sequence to ProdV5;
grant create session to ProdV5;
grant create synonym to ProdV5;
grant create table to ProdV5;
grant create trigger to ProdV5;
grant create type to ProdV5;
grant create view to ProdV5;
grant select any dictionary to ProdV5;
grant select any table to ProdV5;

-----------------------------------------------------------

