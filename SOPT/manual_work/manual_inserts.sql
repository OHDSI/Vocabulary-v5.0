--relationship fixes
insert into concept_relationship_manual values ('1111','111','SOPT','SOPT','Is a',TO_DATE('20201211','YYYYMMDD'),CURRENT_DATE,'D');
insert into concept_relationship_manual values ('1111','119','SOPT','SOPT','Is a',TO_DATE('20201211','YYYYMMDD'),TO_DATE('20991231', 'yyyymmdd'),null);
insert into concept_relationship_manual values ('1112','111','SOPT','SOPT','Is a',TO_DATE('20201211','YYYYMMDD'),CURRENT_DATE,'D');
insert into concept_relationship_manual values ('1112','119','SOPT','SOPT','Is a',TO_DATE('20201211','YYYYMMDD'),TO_DATE('20991231', 'yyyymmdd'),null);
insert into concept_relationship_manual values ('59','5','SOPT','SOPT','Maps to',TO_DATE('20201211','YYYYMMDD'),TO_DATE('20991231', 'yyyymmdd'),null);
insert into concept_relationship_manual values ('24','81','SOPT','SOPT','Maps to',TO_DATE('20201211','YYYYMMDD'),TO_DATE('20991231', 'yyyymmdd'),null);

--name fixes
insert into concept_manual (vocabulary_id,concept_code, standard_concept, invalid_reason) values('SOPT','59',null,'X');
insert into concept_manual (concept_name, vocabulary_id,concept_code, standard_concept, invalid_reason) values('Dental Other Private Insurance','SOPT','561','X','X');
insert into concept_manual (concept_name, vocabulary_id,concept_code, standard_concept, invalid_reason) values('Managed Care Point of Service (POS)','SOPT','73','X','X');
insert into concept_manual (concept_name, vocabulary_id,concept_code, standard_concept, invalid_reason) values('Department of Defense (DoD) other','SOPT','3119','X','X');
insert into concept_manual (concept_name, vocabulary_id,concept_code, standard_concept, invalid_reason) values('Dual Eligible Medicare / Medicaid Special Needs Plan (D-SNP)','SOPT','141','X','X');
insert into concept_manual (concept_name, vocabulary_id,concept_code, standard_concept, invalid_reason) values('Fully Integrated Dual Eligible Medicare / Medicaid Special Needs Plan (FIDE-SNP)','SOPT','142','X','X');
insert into concept_manual (concept_name, vocabulary_id,concept_code, standard_concept, invalid_reason) values('HRSA Disaster-related (includes Covid-19) program','SOPT','344','X','X');