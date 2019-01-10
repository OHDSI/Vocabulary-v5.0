--"rename" UCUM concept [degC] to Cel
update concept set standard_concept=null, invalid_reason='U', valid_end_date=current_date where concept_id=8653;
insert into concept values(586323,'degree Celsius','Unit','UCUM','Unit','S','Cel',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
update concept_relationship set valid_end_date=current_date, invalid_reason='D' where concept_id_1=8653 and concept_id_2=8653;
insert into concept_relationship values(8653,586323,'Concept replaced by',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(586323,8653,'Concept replaces',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(586323,586323,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(586323,586323,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);

--bugfix with non-proper standard_concept (old OMOP generated concepts)
update concept set standard_concept=null where invalid_reason is not null and standard_concept is not null;