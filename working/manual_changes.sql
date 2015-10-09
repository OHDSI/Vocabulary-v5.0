/*
-- start new sequence
drop sequence v5_concept;
DECLARE
 ex NUMBER;
BEGIN
  SELECT MAX(concept_id)+1 INTO ex FROM concept WHERE concept_id<500000000; -- Last valid below HOI concept_id
  BEGIN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE v5_concept INCREMENT BY 1 START WITH ' || ex || ' NOCYCLE CACHE 20 NOORDER';
    EXCEPTION
      WHEN OTHERS THEN NULL;
  END;
END;
*/

-- Update CPT4 to RxNorm mappings
-- Add missing CPT4s (should be in next UMLS release)
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Meningococcal recombinant protein and outer membrane vesicle vaccine, Serogroup B, 2 dose schedule, for intramuscular use', 'Drug', 'CPT4', 'CPT4', 'S', '90620', '1-Jan-2015', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Meningococcal recombinant lipoprotein vaccine, Serogroup B, 2 or 3 dose schedule, for intramuscular use', 'Drug', 'CPT4', 'CPT4', 'S', '90621', '1-Jan-2015', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Influenza virus vaccine, quadrivalent (IIV4), split virus, preservative free, for intradermal use', 'Drug', 'CPT4', 'CPT4', 'S', '90630', '1-Jan-2015', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Diphtheria, tetanus toxoids, acellular pertussis vaccine, inactivated poliovirus vaccine, Haemophilus influenza type b PRP-OMP conjugate vaccine, and hepatitis B vaccine (DTaP- IPV-Hib-HepB), for intramuscular use', 'Drug', 'CPT4', 'CPT4', 'S', '90697', '1-Jan-2015', '31-Dec-2099', null);

-- Refresh deprecated but correct mappings
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90296') and concept_id_2=19135942;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90384') and concept_id_2=535714;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90385') and concept_id_2=535714;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90386') and concept_id_2=535714;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90389') and concept_id_2=561401;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90696') and concept_id_2=529218;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90696') and concept_id_2=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90696') and concept_id_2=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90698') and concept_id_2=529218;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90698') and concept_id_2=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90698') and concept_id_2=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90698') and concept_id_2=551977;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90700') and concept_id_2=529218;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90700') and concept_id_2=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90700') and concept_id_2=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90702') and concept_id_2=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90714') and concept_id_2=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90714') and concept_id_2=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90715') and concept_id_2=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90715') and concept_id_2=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90715') and concept_id_2=529218;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90718') and concept_id_2=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90718') and concept_id_2=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90719') and concept_id_2=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90721') and concept_id_2=529218;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90721') and concept_id_2=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90721') and concept_id_2=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90735') and concept_id_2=19047598;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90738') and concept_id_2=19047598;

-- Kill currently active one
update concept_relationship set valid_end_date='19-Jul-2015', invalid_reason = 'D' where concept_id_1=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90379') and concept_id_2=19013765;

-- Create new ones
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90281'),  40053913, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90283'),  40053913, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90284'),  40053913, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90291'),  40060257, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90371'),  19126485, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90375'),  46233999, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90376'),  46233999, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90378'),  537648, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90379'),  19013766, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90393'),  19122170, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90396'),  43013222, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90399'),  40053913, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90476'),  40237615, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90477'),  40237619, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90581'),  19045675, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90585'),  46234108, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90620'), 45892101, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90621'),  45775646, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90636'),  19131619, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90644'), 43560548, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90645'),  586325, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90646'),  19067404, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90647'),  530010, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90648'),  40150646, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90649'),  19093987, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90650'),  42873276, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90651'), 45892508, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90669'),  19029084, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90670'),  40163665, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90680'),  19133404, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90681'),  19131940, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90690'),  19129379, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90691'),  19132274, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90696'), 523283, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90696'), 523365, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90696'), 523367, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90698'), 19086313, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90702'), 529411, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90703'),  529411, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90704'),  529716, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90705'),  40064425, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90706'),  523215, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90707'),  19131658, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90708'),  19040342, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90710'),  42799832, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90713'),  19129483, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90716'),  42800031, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90717'),  42800062, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90720'), 40111226, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90721'), 19086313, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90723'), 19034102, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90725'),  40025601, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90727'),  43560347, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90732'), 40163665, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90733'),  514012, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90733'),  509081, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90733'),  509079, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90733'),  514015, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90734'),  40173209, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90734'),  40173207, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90734'),  40173205, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90734'),  40173198, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90736'),  42800035, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90739'),  528323, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90740'),  528323, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90743'),  19133371, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90744'),  528323, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90746'),  528323, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90747'),  528323, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90748'),  40150636, 'Maps to', '20-Jul_2015', '31-Dec-2099', null);

-- Reciprocal mappings
-- Refresh deprecated but correct mappings
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90296') and concept_id_1=19135942;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90384') and concept_id_1=535714;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90385') and concept_id_1=535714;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90386') and concept_id_1=535714;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90389') and concept_id_1=561401;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90696') and concept_id_1=529218;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90696') and concept_id_1=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90696') and concept_id_1=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90698') and concept_id_1=529218;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90698') and concept_id_1=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90698') and concept_id_1=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90698') and concept_id_1=551977;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90700') and concept_id_1=529218;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90700') and concept_id_1=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90700') and concept_id_1=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90702') and concept_id_1=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90714') and concept_id_1=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90714') and concept_id_1=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90715') and concept_id_1=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90715') and concept_id_1=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90715') and concept_id_1=529218;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90718') and concept_id_1=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90718') and concept_id_1=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90719') and concept_id_1=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90721') and concept_id_1=529218;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90721') and concept_id_1=529303;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90721') and concept_id_1=529411;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90735') and concept_id_1=19047598;
update concept_relationship set valid_end_date='31-Dec-2099', invalid_reason = null where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90738') and concept_id_1=19047598;

-- Kill currently active one
update concept_relationship set valid_end_date='19-Jul-2015', invalid_reason = 'D' where concept_id_2=(select concept_id from concept where vocabulary_id='CPT4' and concept_code='90379') and concept_id_1=19013765;

-- Create new ones
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90281'),  40053913, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90283'),  40053913, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90284'),  40053913, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90291'),  40060257, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90371'),  19126485, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90375'),  46233999, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90376'),  46233999, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90378'),  537648, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90379'),  19013766, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90393'),  19122170, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90396'),  43013222, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90399'),  40053913, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90476'),  40237615, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90477'),  40237619, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90581'),  19045675, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90585'),  46234108, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90620'), 45892101, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90621'),  45775646, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90636'),  19131619, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90644'), 43560548, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90645'),  586325, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90646'),  19067404, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90647'),  530010, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90648'),  40150646, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90649'),  19093987, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90650'),  42873276, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90651'), 45892508, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90669'),  19029084, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90670'),  40163665, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90680'),  19133404, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90681'),  19131940, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90690'),  19129379, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90691'),  19132274, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90696'), 523283, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90696'), 523365, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90696'), 523367, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90698'), 19086313, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90702'), 529411, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90703'),  529411, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90704'),  529716, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90705'),  40064425, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90706'),  523215, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90707'),  19131658, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90708'),  19040342, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90710'),  42799832, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90713'),  19129483, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90716'),  42800031, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90717'),  42800062, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90720'), 40111226, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90721'), 19086313, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90723'), 19034102, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90725'),  40025601, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90727'),  43560347, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90732'), 40163665, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90733'),  514012, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90733'),  509081, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90733'),  509079, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90733'),  514015, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90734'),  40173209, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90734'),  40173207, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90734'),  40173205, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90734'),  40173198, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90736'),  42800035, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90739'),  528323, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90740'),  528323, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90743'),  19133371, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90744'),  528323, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90746'),  528323, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90747'),  528323, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id='CPT4' and concept_code='90748'),  40150636, 'Mapped from', '20-Jul_2015', '31-Dec-2099', null);

-- Fix typo in IHDSDO
update vocabulary set vocabulary_name='Systematic Nomenclature of Medicine - Clinical Terms (IHTSDO)' where vocabulary_concept_id=44819097;
update concept set concept_name='Systematic Nomenclature of Medicine - Clinical Terms (IHTSDO)' where concept_id=44819097;

-- Fix extra megaunit
insert into concept_relationship
select 9689, concept_id_2, 'Mapped from', '3-Aug-2015', '31-Dec-2099', null from concept_relationship where relationship_id='Mapped from' and invalid_reason is null and concept_id_1=45891020;
insert into concept_relationship
select concept_id_1, 9689, 'Maps to', '3-Aug-2015', '31-Dec-2099', null from concept_relationship where relationship_id='Maps to' and invalid_reason is null and concept_id_2=45891020;
update concept set valid_end_date='2-Aug-2015', invalid_reason = 'D' where concept_id = 45891020; -- remove duplicate
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (45891020, 9689, 'Concept replaced by', '2-Aug-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (9689, 45891020, 'Concept replaces', '2-Aug-2015', '31-Dec-2099', null);
update concept_relationship set valid_end_date = '2-Aug-2015', invalid reason = 'D' where concept_id_1 = 45891020 and relationship_id = 'Mapped from';
update concept_relationship set valid_end_date = '2-Aug-2015', invalid reason = 'D' where concept_id_2 = 45891020 and relationship_id = 'Maps to';

-- Add reciprocal NDC to RxNorm mapping
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values ((select concept_id from concept where vocabulary_id='NDC' and concept_code='00005010002'), 45775646, 'Mapped from', '15-Jul-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
  values ((select concept_id from concept where vocabulary_id='NDC' and concept_code='63851061301'), 44818418, 'Mapped from', '15-Jul-2015', '31-Dec-2099', null);

-- fix non-symmetrical relationships with respect to deprecation
update concept_relationship d set d.invalid_reason=null, d.valid_end_date=TO_DATE ('20991231', 'YYYYMMDD')  where d.rowid in (
      select r.rowid
      from concept c, concept c1, concept_relationship r
      where r.concept_id_1=c.concept_id
      and c.invalid_reason='U'
      and r.relationship_id='Concept replaced by'
      and r.concept_id_2=c1.concept_id
      and r.invalid_reason='D'
      and c1.standard_concept = 'S'
      and c.concept_id in (
          select c.concept_id
          from concept c, concept c1, concept_relationship r
          where r.concept_id_1=c.concept_id
          and c.invalid_reason='U'
          and r.relationship_id='Concept replaced by'
          and r.concept_id_2=c1.concept_id
          and r.invalid_reason='D'
          and c1.standard_concept = 'S'
          group by c.concept_id having count(*)=1    
      )
); 

-- add SPL concept_class_id values
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'FDA Product Type Food', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Food', 'Food', (select concept_id from concept where concept_name = 'FDA Product Type Food'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'FDA Product Type Supplement', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Supplement', 'Supplement', (select concept_id from concept where concept_name = 'FDA Product Type Supplement'));
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'FDA Product Type Cosmetic', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Cosmetic', 'Cosmetic', (select concept_id from concept where concept_name = 'FDA Product Type Cosmetic'));

-- add additional SPL class
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'FDA Product Type Animal Drug', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Animal Drug', 'FDA Product Type Animal Drug', (select concept_id from concept where concept_name = 'FDA Product Type Animal Drug'));

-- add domain for Type Concepts
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (58, 'Type Concept', 'Metadata', 'Domain', 'Domain', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into domain (domain_id, domain_name, domain_concept_id)
values ('Type Concept', 'Type Concept', 58);

-- ????? ???????? domain_id ???? ?????????



commit;

------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remove invalid ICD10 codes
delete 
from concept_relationship r 
where exists (
  select 1 from concept c1 where r.concept_id_1=c1.concept_id and c1.vocabulary_id='ICD10CM' and c1.concept_class_id='ICD10 code'
)
;

update concept set 
  'Invalid ICD10 Concept, do not use' as concept_name, 
  vocabulary_id='ICD10', 
  concept_code=concept_id, -- so they can't even find them anymore by concept_code
  '1-July-2015' as valid_end_date, 
  'D' as invalid_reason
where vocabulary_id='ICD10CM' 
and concept_class_id='ICD10 code'
;
