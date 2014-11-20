-- Create Devuction environment for version 5.0 voabulary
create user DevV5 identified by "123" default tablespace USERS temporary tablespace TEMP quota unlimited on users;

grant create cluster to DevV5;
grant create indextype to DevV5;
grant create operator to DevV5;
grant create procedure to DevV5;
grant create sequence to DevV5;
grant create session to DevV5;
grant create synonym to DevV5;
grant create table to DevV5;
grant create trigger to DevV5;
grant create type to DevV5;
grant create view to DevV5;
grant select any dictionary to DevV5;
grant select any table to DevV5;

-----------------------------------------------------------

