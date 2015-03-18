-- Fix names of mapping relationships
update concept set concept_name = 'Mapping relationship to Standard Concept (OMOP)' where concept_id = 44818977;
update concept set concept_name = 'Mapping relationship from Standard Concept (OMOP)' where concept_id = 44818976;

-- start new sequence
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

-- Add another Observation Period type for Rimma
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Period of complete data capture based on geographic isolation', 'Obs Period Type', 'Obs Period Type', 'Obs Period Type', 'S', 'OMOP generated', '01-JAN-70', '31-DEC-99', null);

-- Remove relationships to domains
delete from concept_relationship where relationship_id in ('Is domain','Domain subsumes');

-- Remove PCORNet concepts that are deprecated
delete from concept where vocabulary_id='PCORNet' and invalid_reason is not null;

-- Fix PCORNet concept_codes
update concept set concept_code='Generic-OT' where concept_id=44814649;
update concept set concept_code='Generic-NI' where concept_id=44814650;
update concept set concept_code='Generic-UN' where concept_id=44814653;
update concept set concept_code='Biobank Flag-Y' where concept_id=44814647;
update concept set concept_code='Biobank Flag-N' where concept_id=44814648;
update concept set concept_code='Hispanic-Y' where concept_id=44814651;
update concept set concept_code='Hispanic-N' where concept_id=44814652;
update concept set concept_code='Race-01' where concept_id=44814654;
update concept set concept_code='Race-02' where concept_id=44814655;
update concept set concept_code='Race-03' where concept_id=44814656;
update concept set concept_code='Race-04' where concept_id=44814657;
update concept set concept_code='Race-05' where concept_id=44814658;
update concept set concept_code='Race-06' where concept_id=44814659;
update concept set concept_code='Race-07' where concept_id=44814660;
update concept set concept_code='Sex-A' where concept_id=44814664;
update concept set concept_code='Sex-F' where concept_id=44814665;
update concept set concept_code='Sex-M' where concept_id=44814666;
update concept set concept_code='Admitting Source-AF' where concept_id=44814670;
update concept set concept_code='Admitting Source-AL' where concept_id=44814671;
update concept set concept_code='Admitting Source-AV' where concept_id=44814672;
update concept set concept_code='Admitting Source-ED' where concept_id=44814673;
update concept set concept_code='Admitting Source-HH' where concept_id=44814674;
update concept set concept_code='Admitting Source-HO' where concept_id=44814675;
update concept set concept_code='Admitting Source-HS' where concept_id=44814676;
update concept set concept_code='Admitting Source-IP' where concept_id=44814677;
update concept set concept_code='Admitting Source-NH' where concept_id=44814678;
update concept set concept_code='Admitting Source-RH' where concept_id=44814679;
update concept set concept_code='Admitting Source-RS' where concept_id=44814680;
update concept set concept_code='Admitting Source-SN' where concept_id=44814681;
update concept set concept_code='Discharge Disposition-A' where concept_id=44814685;
update concept set concept_code='Discharge Disposition-E' where concept_id=44814686;
update concept set concept_code='Discharge Status-AF' where concept_id=44814690;
update concept set concept_code='Discharge Status-AL' where concept_id=44814691;
update concept set concept_code='Discharge Status-AM' where concept_id=44814692;
update concept set concept_code='Discharge Status-AW' where concept_id=44814693;
update concept set concept_code='Discharge Status-E' where concept_id=44814694;
update concept set concept_code='Discharge Status-HH' where concept_id=44814695;
update concept set concept_code='Discharge Status-HO' where concept_id=44814696;
update concept set concept_code='Discharge Status-HS' where concept_id=44814697;
update concept set concept_code='Discharge Status-IP' where concept_id=44814698;
update concept set concept_code='Discharge Status-NH' where concept_id=44814699;
update concept set concept_code='Discharge Status-RH' where concept_id=44814700;
update concept set concept_code='Discharge Status-RS' where concept_id=44814701;
update concept set concept_code='Discharge Status-SH' where concept_id=44814702;
update concept set concept_code='Discharge Status-SN' where concept_id=44814703;
update concept set concept_code='Encounter Type-IP' where concept_id=44814707;
update concept set concept_code='Encounter Type-AV' where concept_id=44814708;
update concept set concept_code='Encounter Type-ED' where concept_id=44814709;
update concept set concept_code='Encounter Type-IS' where concept_id=44814710;
update concept set concept_code='Encounter Type-OA' where concept_id=44814711;
update concept set concept_code='Chart Availability-Y' where concept_id=44814715;
update concept set concept_code='Chart Availability-N' where concept_id=44814716;
update concept set concept_code='Enrollment Basis-I' where concept_id=44814717;
update concept set concept_code='Enrollment Basis-G' where concept_id=44814718;
update concept set concept_code='Enrollment Basis-A' where concept_id=44814719;
update concept set concept_code='Enrollment Basis-E' where concept_id=44814720;
update concept set concept_code='DRG Type-01' where concept_id=44819189;
update concept set concept_code='DRG Type-02' where concept_id=44819190;
update concept set concept_code='Diagnosis Code Type-09' where concept_id=44819194;
update concept set concept_code='Diagnosis Code Type-10' where concept_id=44819195;
update concept set concept_code='Diagnosis Code Type-11' where concept_id=44819196;
update concept set concept_code='Diagnosis Code Type-SM' where concept_id=44819197;
update concept set concept_code='Diagnosis Type-P' where concept_id=44819201;
update concept set concept_code='Diagnosis Type-S' where concept_id=44819202;
update concept set concept_code='Diagnosis Type-X' where concept_id=44819203;
update concept set concept_code='Procedure Code Type-09' where concept_id=44819207;
update concept set concept_code='Procedure Code Type-10' where concept_id=44819208;
update concept set concept_code='Procedure Code Type-11' where concept_id=44819209;
update concept set concept_code='Procedure Code Type-C2' where concept_id=44819210;
update concept set concept_code='Procedure Code Type-C3' where concept_id=44819211;
update concept set concept_code='Procedure Code Type-C4' where concept_id=44819212;
update concept set concept_code='Procedure Code Type-H3' where concept_id=44819213;
update concept set concept_code='Procedure Code Type-HC' where concept_id=44819214;
update concept set concept_code='Procedure Code Type-LC' where concept_id=44819215;
update concept set concept_code='Procedure Code Type-ND' where concept_id=44819216;
update concept set concept_code='Procedure Code Type-RE' where concept_id=44819217;
update concept set concept_code='Vital Source-PR' where concept_id=44819221;
update concept set concept_code='Vital Source-HC' where concept_id=44819222;
update concept set concept_code='Blood Pressure Position-01' where concept_id=44819226;
update concept set concept_code='Blood Pressure Position-02' where concept_id=44819227;
update concept set concept_code='Blood Pressure Position-03' where concept_id=44819228;

-- Add PCORNet mapping
-- Maps to
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814693, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814670, 4145666, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814690, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814692, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814664, 0, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814672, 9202, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814708, 4145666, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814654, 8657, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814655, 8515, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814671, 4145666, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814691, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814647, 4001345, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814656, 8516, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814715, 4030450, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814716, 4030450, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814685, 44813951, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814673, 4145666, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814709, 9203, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814718, 44814723, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814717, 44814722, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814720, 44814724, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814719, 44814725, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814686, 44813951, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814694, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814665, 8532, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814651, 38003563, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814675, 4145666, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814696, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814674, 4145666, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814695, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814676, 4145666, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814697, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814707, 9201, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814666, 8507, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814659, 0, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814657, 8557, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814650, 0, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814710, 42898160, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814652, 38003564, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814678, 4145666, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814699, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814649, 0, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814677, 4145666, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814698, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814711, 0, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814660, 0, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814679, 4145666, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814700, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814680, 4145666, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814701, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814681, 4145666, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814703, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814702, 4137274, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44819203, 0, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814648, 4001345, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814653, 4145666, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814658, 8527, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);

-- Maps from
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814693, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814670, 4145666, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814690, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814692, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814664, 0, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814672, 9202, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814708, 4145666, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814654, 8657, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814655, 8515, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814671, 4145666, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814691, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814647, 4001345, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814656, 8516, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814715, 4030450, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814716, 4030450, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814685, 44813951, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814673, 4145666, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814709, 9203, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814718, 44814723, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814717, 44814722, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814720, 44814724, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814719, 44814725, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814686, 44813951, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814694, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814665, 8532, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814651, 38003563, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814675, 4145666, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814696, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814674, 4145666, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814695, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814676, 4145666, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814697, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814707, 9201, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814666, 8507, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814659, 0, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814657, 8557, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814650, 0, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814710, 42898160, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814652, 38003564, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814678, 4145666, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814699, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814649, 0, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814677, 4145666, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814698, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814711, 0, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814660, 0, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814679, 4145666, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814700, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814680, 4145666, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814701, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814681, 4145666, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814703, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814702, 4137274, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44819203, 0, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814648, 4001345, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814653, 4145666, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814658, 8527, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);

-- Maps to value
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814693, 44814693, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814670, 38004205, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814690, 38004205, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814692, 4021968, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814708, 38004207, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814671, 38004301, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814691, 38004301, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814647, 4188539, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814715, 4188539, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814716, 4188540, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814685, 4161979, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814673, 8870, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814686, 4216643, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814694, 4216643, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814675, 8536, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814696, 8536, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814674, 38004195, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814695, 38004195, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814676, 8546, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814697, 8546, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814678, 8676, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814699, 8676, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814677, 38004279, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814698, 38004279, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814679, 8920, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814700, 8920, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814680, 44814680, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814701, 44814701, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814681, 8863, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814703, 8863, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814702, 8717, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814648, 4188540, 'Maps to value', '01-Jan-1970', '31-Dec-2099', null);

-- Value mapped from
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814693, 44814693, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814670, 38004205, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814690, 38004205, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814692, 4021968, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814708, 38004207, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814671, 38004301, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814691, 38004301, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814647, 4188539, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814715, 4188539, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814716, 4188540, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814685, 4161979, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814673, 8870, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814686, 4216643, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814694, 4216643, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814675, 8536, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814696, 8536, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814674, 38004195, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814695, 38004195, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814676, 8546, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814697, 8546, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814678, 8676, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814699, 8676, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814677, 38004279, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814698, 38004279, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814679, 8920, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814700, 8920, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814680, 44814680, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814701, 44814701, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814681, 8863, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814703, 8863, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814702, 8717, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (44814648, 4188540, 'Value mapped from', '01-Jan-1970', '31-Dec-2099', null);

commit;




-- Not done yet:
-- Change all relationships containing replaces or replaces by to these. Remove the extra relationships
update concept_relationship set relationship_id = 'Concept replaces' where relationship_id in (
  'LOINC replaces',
  'RxNorm replaces',
  'SNOMED replaces',
  'ICD9P replaces',
  'UCUM replaces'
);
update concept_relationship set relationship_id = 'Concept replaced by' where relationship_id in (
  'LOINC replaced by',
  'RxNorm replaced by',
  'SNOMED replaced by',
  'ICD9P replaced by',
  'UCUM replaced by'
);
update concept set 
  valid_end_date = '10-Jan-2015',
  invalid_reason = 'D'
where concept_id in (
  44818714, -- LOINC replaced by
  44818812, -- LOINC replaces
  44818946, -- RxNorm replaced by
  44818947, -- RxNorm replaces
  44818948, -- SNOMED replaced by
  44818949, -- SNOMED replaces
  44818971, -- ICD9P replaced by
  44818972, -- ICD9P replaces
  44818978, -- UCUM replaced by
  44818979 -- UCUM replaces
);
delete from relationship where relationship_id in (
  'LOINC replaces',
  'RxNorm replaces',
  'SNOMED replaces',
  'ICD9P replaces',
  'UCUM replaces',
  'LOINC replaced by',
  'RxNorm replaced by',
  'SNOMED replaced by',
  'ICD9P replaced by',
  'UCUM replaced by'
);

