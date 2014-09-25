create sequence seq_application_log;

-- Create table
create table APPLICATION_LOG
(
  application_log_id NUMBER(15) default SEQ_APPLICATION_LOG.NEXTVAL not null,
  audsid             INTEGER default sys_context ('userenv', 'sessionid') not null,
  sid                INTEGER default sys_context ('userenv', 'sid') not null,
  al_timestamp       TIMESTAMP(3) default systimestamp not null,
  user_name          VARCHAR2(100) default user,
  al_name            VARCHAR2(100),
  procedure_name     VARCHAR2(100),
  al_detail          VARCHAR2(4000)
);
-- Add comments to the table 
comment on table APPLICATION_LOG
  is 'DataBase application logging. To add log record use procedure procedure add_application_log';
-- Add comments to the columns 
comment on column APPLICATION_LOG.al_name
  is 'name add log application';
comment on column APPLICATION_LOG.procedure_name
  is 'name add log procedure';
comment on column APPLICATION_LOG.al_detail
  is 'log message';
-- Create/Recreate primary, unique and foreign key constraints 
alter table APPLICATION_LOG
  add constraint PK_APPLICATION_LOG primary key (APPLICATION_LOG_ID);

