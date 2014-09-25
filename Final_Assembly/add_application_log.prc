create or replace procedure add_application_log (
        pApplication_name in application_log.al_name%type
       ,pProcedure_name   in application_log.procedure_name%type default null
       ,pDetail           in varchar2 default null )
is
  -- 22-SEP-2014. Created. Detail application logging.
  vApplication_name  application_log.al_name%type;
  vProcedure_name    application_log.procedure_name%type;
  vDetail application_log.al_detail%type;

  pragma autonomous_transaction;
begin
  vApplication_name := substrb ( pApplication_name, 1, 100 ); 
  vProcedure_name := substrb ( pProcedure_name, 1, 100 ); 
  vDetail := substrb ( pDetail, 1, 4000 ); 
  
  insert into application_log ( al_name, procedure_name, al_detail )
    values ( vApplication_name, vProcedure_name, vDetail );
  
  commit;
end add_application_log;
/
