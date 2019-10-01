--concept_name/concept_synonym corrections

--'Public Medicine' is not a comprehensive name since doctor is still 'Podiatrist' http://athena.ohdsi.org/search-terms/terms/38004030
update concept set concept_name = 'Public Medicine Podiatrist' where vocabulary_id = 'NUCC' and concept_code = '213EP0504X';

--'millilieter' typo
update concept set concept_name = regexp_replace(concept_name, 'millilieter', 'milliliter') where vocabulary_id = 'UCUM' and concept_name ~ 'millilieter';
update concept_synonym cs
set concept_synonym_name = regexp_replace(cs.concept_synonym_name, 'millilieter', 'milliliter')
from concept c
where c.vocabulary_id = 'UCUM'
  and cs.concept_synonym_name ~ 'millilieter'
  and cs.concept_id = c.concept_id;

--'microiliter' typo
update concept set concept_name = regexp_replace(concept_name, 'microiliter', 'microliter') where vocabulary_id = 'UCUM' and concept_name ~ 'microiliter';
update concept_synonym cs
set concept_synonym_name = regexp_replace(cs.concept_synonym_name, 'microiliter', 'microliter')
from concept c
where c.vocabulary_id = 'UCUM'
  and cs.concept_synonym_name ~ 'microiliter'
  and cs.concept_id = c.concept_id;


--add new UCUM concepts
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32695, 'attogram per cell', 'Unit', 'UCUM', 'Unit', 'S', 'ag/{cell}', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32696, 'picomole per milligram', 'Unit', 'UCUM', 'Unit', 'S', 'pmol/mg', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32697, 'kilo-unified atomic mass unit', 'Unit', 'UCUM', 'Unit', 'S', '10*3.[u]', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32698, 'milliliter per minute per millimeter mercury column', 'Unit', 'UCUM', 'Unit', 'S', 'mL/min/mm[Hg]', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32699, 'liter per second', 'Unit', 'UCUM', 'Unit', 'S', 'L/s', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32700, 'gram per square centimeter', 'Unit', 'UCUM', 'Unit', 'S', 'g/cm2', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32701, 'gram per millimole', 'Unit', 'UCUM', 'Unit', 'S', 'g/mmol', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32702, 'dyne-second per centimeter to the fifth power', 'Unit', 'UCUM', 'Unit', 'S', 'dyn.sec/cm5', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (32703, 'millimeter mercury column-minute per liter', 'Unit', 'UCUM', 'Unit', 'S', 'mm[Hg].min/L', TO_DATE ('19700101', 'YYYYMMDD'), TO_DATE ('20991231', 'YYYYMMDD'), null);


--additional concept_synonym
insert into concept_synonym (concept_id, concept_synonym_name, language_concept_id)
values (9648, 'dalton, Da', 4180186);
insert into concept_synonym (concept_id, concept_synonym_name, language_concept_id)
values (32697, 'kilodalton, kDa', 4180186);
insert into concept_synonym (concept_id, concept_synonym_name, language_concept_id)
values (32703, 'wood unit, [wood''U]', 4180186);
insert into concept_synonym (concept_id, concept_synonym_name, language_concept_id)
values (32703, 'hybrid resistance unit, HRU)', 4180186);


--basic concept_name to concept_synonym insertion for new and existing UCUM concepts
insert into concept_synonym
select c.concept_id, c.concept_name, 4180186
from concept c
         left join concept_synonym cs
                   on c.concept_id = cs.concept_id
                       and c.concept_name = cs.concept_synonym_name
where c.vocabulary_id = 'UCUM'
  and c.concept_name <> 'Duplicate of UCUM Concept, do not use, use replacement from CONCEPT_RELATIONSHIP table instead'
  and cs.concept_id is null;


--concept_relationship insertion
insert into concept_relationship values(32695,32695,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32695,32695,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32696,32696,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32696,32696,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32697,32697,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32697,32697,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32698,32698,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32698,32698,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32699,32699,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32699,32699,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32700,32700,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32700,32700,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32701,32701,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32701,32701,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32702,32702,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32702,32702,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32703,32703,'Maps to',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
insert into concept_relationship values(32703,32703,'Mapped from',to_date ('19700101', 'YYYYMMDD'),to_date('20991231', 'YYYYMMDD'),null);
