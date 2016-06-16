drop sequence new_voc;

-- Create sequence for new OMOP-created standard concepts
declare
 ex number;
begin
  select max(cast(substr(concept_code, 5) as integer))+1 into ex from devv5.concept where concept_code like 'OMOP%' and concept_code not like '% %'; -- Last valid value of the OMOP123-type codes
  begin
    execute immediate 'create sequence new_voc increment by 1 start with ' || ex || ' nocycle cache 20 noorder';
  end;
end;