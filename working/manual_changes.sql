-- Fix HCPCS modifier mapping
update concept
set domain_id = case
  when concept_code in ('A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9', 'AU', 'AV', 'AW', 'AX', 'AY', 'BA',
    'CS', 'EM', 'GQ', 'JC', 'JD', 'K0', 'K1', 'K2', 'K3', 'K4', 'KA', 'KC', 'KF', 'KM', 'KN', 'KS', 'LR', 'LS',
    'NB', 'PL', 'Q0', 'QH', 'SC', 'TC', 'TW', 'UE', 'V5', 'V6', 'V7')
  then 'Device'
  when concept_code in ('EA', 'EB', 'EC', 'SL') then 'Drug'
  when concept_code in ('ED', 'EE', 'G1', 'G2', 'G3', 'G4', 'G5', 'PT') then 'Measurement'  
  when concept_code in ('AD', 'AT', 'BL', 'BO', 'CC', 'DA', 'ET', 'G8', 'G9', 'GG', 'GH', 'GJ', 'GN', 'GO', 'GP', 'GS', 'HA', 'HB',
    'HC', 'HD', 'HE', 'HF', 'HG', 'HH', 'HI', 'HJ', 'HK', 'JA', 'JB', 'JE', 'KD', 'PA', 'PB', 'PI', 'PS', 'QC', 'QK',
    'QS', 'QZ', 'RA', 'RB', 'RD', 'RE', 'RT', 'SE', 'SH', 'SJ', 'TL')
  then 'Procedure'  
  else 'Observation'
end
where vocabulary_id = 'HCPCS' and concept_class_id = 'HCPCS Modifier'
;

-- Fix 1999 to 2099 for Patient Self-Reported Medication 
update concept set valid_end_date='31-Dec-2099' where concept_id=44787730;

-- add UCUM equivalents to SNOMED UK units used in drug extension
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45890995, 'Million unit per liter', 'Unit', 'UCUM', 'Unit', 'S', '10*6.[U]/mL', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45890996, 'gram per dose', 'Unit', 'UCUM', 'Unit', 'S', 'g/[dose]', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45890997, 'milligram per dose', 'Unit', 'UCUM', 'Unit', 'S', 'mg/[dose]', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45890998, 'microgram per dose', 'Unit', 'UCUM', 'Unit', 'S', 'ug/[dose]', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45890999, 'unit per dose', 'Unit', 'UCUM', 'Unit', 'S', '[U]/[dose]', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891000, 'application', 'Unit', 'UCUM', 'Unit', 'S', '[App]', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891001, 'gram per application', 'Unit', 'UCUM', 'Unit', 'S', 'g/[App]', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891002, 'milligram per application', 'Unit', 'UCUM', 'Unit', 'S', 'mg/[App]', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891003, 'tuberculin unit per milliliter', 'Unit', 'UCUM', 'Unit', 'S', '[tb''U]/mL', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891004, 'month supply', 'Unit', 'UCUM', 'Unit', 'S', 'mo{supply}', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891005, 'week supply', 'Unit', 'UCUM', 'Unit', 'S', 'wk{supply}', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891006, 'unit per drop', 'Unit', 'UCUM', 'Unit', 'S', '[U]/[drop]', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891007, 'Megabecquerel', 'Unit', 'UCUM', 'Unit', 'S', 'MBq', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891008, 'kilobecquerel', 'Unit', 'UCUM', 'Unit', 'S', 'kBq', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891009, 'weight percent volume', 'Unit', 'UCUM', 'Unit', 'S', '{wt]%{vol]', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891010, 'volume percent volume', 'Unit', 'UCUM', 'Unit', 'S', '{vol}%{vol}', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891011, 'weight percent weight', 'Unit', 'UCUM', 'Unit', 'S', '{wt}%{wt}', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891012, 'volume percent weight', 'Unit', 'UCUM', 'Unit', 'S', '{vol}%{wt}', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891013, 'milliliter per liter', 'Unit', 'UCUM', 'Unit', 'S', 'mL/L', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891014, 'millimole per milliliter', 'Unit', 'UCUM', 'Unit', 'S', 'mmol/mL', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891015, 'microgram per actuation', 'Unit', 'UCUM', 'Unit', 'S', 'ug/{actuat}', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891016, 'milligram per actuation', 'Unit', 'UCUM', 'Unit', 'S', 'mg/{actuat}', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891017, 'unit per actuation', 'Unit', 'UCUM', 'Unit', 'S', '[U]/{actuat}', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891018, 'gram per actuation', 'Unit', 'UCUM', 'Unit', 'S', 'g/{actuat}', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891019, 'international unit per milligram', 'Unit', 'UCUM', 'Unit', 'S', '[iU]/mg', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891020, 'megaunit', 'Unit', 'UCUM', 'Unit', 'S', '10*6.[U]', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891021, 'milligram per 16 hours', 'Unit', 'UCUM', 'Unit', 'S', 'mg/(16.h)', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891022, 'milligram per 72 hours', 'Unit', 'UCUM', 'Unit', 'S', 'mg/(72.h)', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891023, 'microgram per 72 hours', 'Unit', 'UCUM', 'Unit', 'S', 'ug/(72.h)', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891024, 'Kallikrein inactivator unit', 'Unit', 'UCUM', 'Unit', 'S', '{KIU}', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891025, 'nanoliter per milliliter', 'Unit', 'UCUM', 'Unit', 'S', 'nL/mL', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891026, 'Kallikrein inactivator unit per milliliter', 'Unit', 'UCUM', 'Unit', 'S', '{KIU]/mL', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891027, 'microgram per square centimeter', 'Unit', 'UCUM', 'Unit', 'S', 'ug/cm2', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891028, 'Gigabecquerel per milliliter', 'Unit', 'UCUM', 'Unit', 'S', 'GBq/mL', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891029, 'microliter per milliliter', 'Unit', 'UCUM', 'Unit', 'S', 'uL/mL', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891030, 'unit per milligram', 'Unit', 'UCUM', 'Unit', 'S', '[U]/mg', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891031, 'Gigabecquerel', 'Unit', 'UCUM', 'Unit', 'S', 'GBq', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891032, 'Megabecquerel per milliliter', 'Unit', 'UCUM', 'Unit', 'S', 'MBq/mL', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891033, 'milliliter per milliliter', 'Unit', 'UCUM', 'Unit', 'S', 'mL/mL', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891034, 'unit per square centimeter', 'Unit', 'UCUM', 'Unit', 'S', '[U]/cm2', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891035, 'milliliter per gram', 'Unit', 'UCUM', 'Unit', 'S', 'mL/g', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891036, 'milligram per square centimeter', 'Unit', 'UCUM', 'Unit', 'S', 'mg/cm2', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891037, 'microliter per gram', 'Unit', 'UCUM', 'Unit', 'S', 'uL/g', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (45891038, 'kilobecquerel per milliliter', 'Unit', 'UCUM', 'Unit', 'S', 'kBq/mL', '01-JAN-1970', '31-DEC-2099', null);

-- Add mappings from SNOMED to UCUM
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10368511000001103' and vocabulary_id = 'SNOMED'
), 45890995, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10691711000001108' and vocabulary_id = 'SNOMED'
), 45890996, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10691811000001100' and vocabulary_id = 'SNOMED'
), 45890997, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10691911000001105' and vocabulary_id = 'SNOMED'
), 45890998, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692011000001103' and vocabulary_id = 'SNOMED'
), 45890999, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692211000001108' and vocabulary_id = 'SNOMED'
), 45891000, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692311000001100' and vocabulary_id = 'SNOMED'
), 45891001, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692411000001107' and vocabulary_id = 'SNOMED'
), 45891002, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692511000001106' and vocabulary_id = 'SNOMED'
), 45891003, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692711000001101' and vocabulary_id = 'SNOMED'
), 9510, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692811000001109' and vocabulary_id = 'SNOMED'
), 45891004, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692911000001104' and vocabulary_id = 'SNOMED'
), 45891005, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10693311000001105' and vocabulary_id = 'SNOMED'
), 8784, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10693711000001109' and vocabulary_id = 'SNOMED'
), 45891006, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '229034000' and vocabulary_id = 'SNOMED'
), 45891007, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258669008' and vocabulary_id = 'SNOMED'
), 9546, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258672001' and vocabulary_id = 'SNOMED'
), 8582, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258673006' and vocabulary_id = 'SNOMED'
), 8588, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258682000' and vocabulary_id = 'SNOMED'
), 8504, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258683005' and vocabulary_id = 'SNOMED'
), 9529, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258684004' and vocabulary_id = 'SNOMED'
), 8576, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258685003' and vocabulary_id = 'SNOMED'
), 9655, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258686002' and vocabulary_id = 'SNOMED'
), 9600, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258702006' and vocabulary_id = 'SNOMED'
), 8505, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258718000' and vocabulary_id = 'SNOMED'
), 9573, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258719008' and vocabulary_id = 'SNOMED'
), 9667, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258731005' and vocabulary_id = 'SNOMED'
), 9241, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258770004' and vocabulary_id = 'SNOMED'
), 8519, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258773002' and vocabulary_id = 'SNOMED'
), 8587, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258774008' and vocabulary_id = 'SNOMED'
), 9665, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258794004' and vocabulary_id = 'SNOMED'
), 8636, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258796002' and vocabulary_id = 'SNOMED'
), 8751, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258798001' and vocabulary_id = 'SNOMED'
), 8861, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258801007' and vocabulary_id = 'SNOMED'
), 8859, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258802000' and vocabulary_id = 'SNOMED'
), 8720, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258806002' and vocabulary_id = 'SNOMED'
), 8842, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258812007' and vocabulary_id = 'SNOMED'
), 9586, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258813002' and vocabulary_id = 'SNOMED'
), 8736, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258836006' and vocabulary_id = 'SNOMED'
), 8909, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258838007' and vocabulary_id = 'SNOMED'
), 44777645, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258840002' and vocabulary_id = 'SNOMED'
), 8906, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258948008' and vocabulary_id = 'SNOMED'
), 8763, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258997004' and vocabulary_id = 'SNOMED'
), 8718, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '259002007' and vocabulary_id = 'SNOMED'
), 8985, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '259022006' and vocabulary_id = 'SNOMED'
), 9483, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '282113003' and vocabulary_id = 'SNOMED'
), 9606, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '282143001' and vocabulary_id = 'SNOMED'
), 45891008, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '282379003' and vocabulary_id = 'SNOMED'
), 45891009, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '282380000' and vocabulary_id = 'SNOMED'
), 45891010, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3314211000001106' and vocabulary_id = 'SNOMED'
), 0, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3314511000001109' and vocabulary_id = 'SNOMED'
), 45891011, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3314611000001108' and vocabulary_id = 'SNOMED'
), 45891012, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3315911000001103' and vocabulary_id = 'SNOMED'
), 45891013, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3316111000001107' and vocabulary_id = 'SNOMED'
), 9586, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3316211000001101' and vocabulary_id = 'SNOMED'
), 8753, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3316311000001109' and vocabulary_id = 'SNOMED'
), 45891014, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3316411000001102' and vocabulary_id = 'SNOMED'
), 8510, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3319711000001103' and vocabulary_id = 'SNOMED'
), 8510, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '396163008' and vocabulary_id = 'SNOMED'
), 9562, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '396169007' and vocabulary_id = 'SNOMED'
), 9514, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '396180007' and vocabulary_id = 'SNOMED'
), 9571, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '4034511000001102' and vocabulary_id = 'SNOMED'
), 45744809, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '4034811000001104' and vocabulary_id = 'SNOMED'
), 9412, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408104008' and vocabulary_id = 'SNOMED'
), 45891015, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408105009' and vocabulary_id = 'SNOMED'
), 45891016, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408106005' and vocabulary_id = 'SNOMED'
), 45891017, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408107001' and vocabulary_id = 'SNOMED'
), 45891018, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408162005' and vocabulary_id = 'SNOMED'
), 9530, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408163000' and vocabulary_id = 'SNOMED'
), 9333, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408164006' and vocabulary_id = 'SNOMED'
), 45891019, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408165007' and vocabulary_id = 'SNOMED'
), 45891020, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408166008' and vocabulary_id = 'SNOMED'
), 45891021, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408167004' and vocabulary_id = 'SNOMED'
), 45891022, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408168009' and vocabulary_id = 'SNOMED'
), 8723, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408169001' and vocabulary_id = 'SNOMED'
), 9565, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408170000' and vocabulary_id = 'SNOMED'
), 45891023, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '411225003' and vocabulary_id = 'SNOMED'
), 45891024, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '414719002' and vocabulary_id = 'SNOMED'
), 9673, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '415758003' and vocabulary_id = 'SNOMED'
), 9413, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '415784009' and vocabulary_id = 'SNOMED'
), 8629, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '417932008' and vocabulary_id = 'SNOMED'
), 45891025, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '417962002' and vocabulary_id = 'SNOMED'
), 45891026, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '418042005' and vocabulary_id = 'SNOMED'
), 45891027, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '418261000' and vocabulary_id = 'SNOMED'
), 45891028, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '418342002' and vocabulary_id = 'SNOMED'
), 45891029, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '418830004' and vocabulary_id = 'SNOMED'
), 45891030, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '418931004' and vocabulary_id = 'SNOMED'
), 45891031, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '418948007' and vocabulary_id = 'SNOMED'
), 45891032, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '419346007' and vocabulary_id = 'SNOMED'
), 45891033, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '419691006' and vocabulary_id = 'SNOMED'
), 45891034, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '419805009' and vocabulary_id = 'SNOMED'
), 45891035, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '8083511000001107' and vocabulary_id = 'SNOMED'
), 45891036, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '8088511000001103' and vocabulary_id = 'SNOMED'
), 45891037, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '8090811000001104' and vocabulary_id = 'SNOMED'
), 45891038, 'Mapped from', '01-Jan-1970', '31-Dec-2099', null);

insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10368511000001103' and vocabulary_id = 'SNOMED'
), 45890995, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10691711000001108' and vocabulary_id = 'SNOMED'
), 45890996, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10691811000001100' and vocabulary_id = 'SNOMED'
), 45890997, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10691911000001105' and vocabulary_id = 'SNOMED'
), 45890998, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692011000001103' and vocabulary_id = 'SNOMED'
), 45890999, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692211000001108' and vocabulary_id = 'SNOMED'
), 45891000, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692311000001100' and vocabulary_id = 'SNOMED'
), 45891001, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692411000001107' and vocabulary_id = 'SNOMED'
), 45891002, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692511000001106' and vocabulary_id = 'SNOMED'
), 45891003, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692711000001101' and vocabulary_id = 'SNOMED'
), 9510, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692811000001109' and vocabulary_id = 'SNOMED'
), 45891004, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10692911000001104' and vocabulary_id = 'SNOMED'
), 45891005, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10693311000001105' and vocabulary_id = 'SNOMED'
), 8784, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '10693711000001109' and vocabulary_id = 'SNOMED'
), 45891006, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '229034000' and vocabulary_id = 'SNOMED'
), 45891007, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258669008' and vocabulary_id = 'SNOMED'
), 9546, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258672001' and vocabulary_id = 'SNOMED'
), 8582, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258673006' and vocabulary_id = 'SNOMED'
), 8588, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258682000' and vocabulary_id = 'SNOMED'
), 8504, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258683005' and vocabulary_id = 'SNOMED'
), 9529, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258684004' and vocabulary_id = 'SNOMED'
), 8576, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258685003' and vocabulary_id = 'SNOMED'
), 9655, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258686002' and vocabulary_id = 'SNOMED'
), 9600, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258702006' and vocabulary_id = 'SNOMED'
), 8505, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258718000' and vocabulary_id = 'SNOMED'
), 9573, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258719008' and vocabulary_id = 'SNOMED'
), 9667, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258731005' and vocabulary_id = 'SNOMED'
), 9241, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258770004' and vocabulary_id = 'SNOMED'
), 8519, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258773002' and vocabulary_id = 'SNOMED'
), 8587, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258774008' and vocabulary_id = 'SNOMED'
), 9665, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258794004' and vocabulary_id = 'SNOMED'
), 8636, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258796002' and vocabulary_id = 'SNOMED'
), 8751, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258798001' and vocabulary_id = 'SNOMED'
), 8861, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258801007' and vocabulary_id = 'SNOMED'
), 8859, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258802000' and vocabulary_id = 'SNOMED'
), 8720, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258806002' and vocabulary_id = 'SNOMED'
), 8842, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258812007' and vocabulary_id = 'SNOMED'
), 9586, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258813002' and vocabulary_id = 'SNOMED'
), 8736, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258836006' and vocabulary_id = 'SNOMED'
), 8909, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258838007' and vocabulary_id = 'SNOMED'
), 44777645, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258840002' and vocabulary_id = 'SNOMED'
), 8906, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258948008' and vocabulary_id = 'SNOMED'
), 8763, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '258997004' and vocabulary_id = 'SNOMED'
), 8718, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '259002007' and vocabulary_id = 'SNOMED'
), 8985, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '259022006' and vocabulary_id = 'SNOMED'
), 9483, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '282113003' and vocabulary_id = 'SNOMED'
), 9606, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '282143001' and vocabulary_id = 'SNOMED'
), 45891008, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '282379003' and vocabulary_id = 'SNOMED'
), 45891009, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '282380000' and vocabulary_id = 'SNOMED'
), 45891010, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3314211000001106' and vocabulary_id = 'SNOMED'
), 0, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3314511000001109' and vocabulary_id = 'SNOMED'
), 45891011, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3314611000001108' and vocabulary_id = 'SNOMED'
), 45891012, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3315911000001103' and vocabulary_id = 'SNOMED'
), 45891013, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3316111000001107' and vocabulary_id = 'SNOMED'
), 9586, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3316211000001101' and vocabulary_id = 'SNOMED'
), 8753, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3316311000001109' and vocabulary_id = 'SNOMED'
), 45891014, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3316411000001102' and vocabulary_id = 'SNOMED'
), 8510, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '3319711000001103' and vocabulary_id = 'SNOMED'
), 8510, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '396163008' and vocabulary_id = 'SNOMED'
), 9562, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '396169007' and vocabulary_id = 'SNOMED'
), 9514, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '396180007' and vocabulary_id = 'SNOMED'
), 9571, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '4034511000001102' and vocabulary_id = 'SNOMED'
), 45744809, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '4034811000001104' and vocabulary_id = 'SNOMED'
), 9412, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408104008' and vocabulary_id = 'SNOMED'
), 45891015, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408105009' and vocabulary_id = 'SNOMED'
), 45891016, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408106005' and vocabulary_id = 'SNOMED'
), 45891017, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408107001' and vocabulary_id = 'SNOMED'
), 45891018, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408162005' and vocabulary_id = 'SNOMED'
), 9530, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408163000' and vocabulary_id = 'SNOMED'
), 9333, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408164006' and vocabulary_id = 'SNOMED'
), 45891019, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408165007' and vocabulary_id = 'SNOMED'
), 45891020, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408166008' and vocabulary_id = 'SNOMED'
), 45891021, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408167004' and vocabulary_id = 'SNOMED'
), 45891022, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408168009' and vocabulary_id = 'SNOMED'
), 8723, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408169001' and vocabulary_id = 'SNOMED'
), 9565, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '408170000' and vocabulary_id = 'SNOMED'
), 45891023, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '411225003' and vocabulary_id = 'SNOMED'
), 45891024, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '414719002' and vocabulary_id = 'SNOMED'
), 9673, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '415758003' and vocabulary_id = 'SNOMED'
), 9413, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '415784009' and vocabulary_id = 'SNOMED'
), 8629, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '417932008' and vocabulary_id = 'SNOMED'
), 45891025, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '417962002' and vocabulary_id = 'SNOMED'
), 45891026, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '418042005' and vocabulary_id = 'SNOMED'
), 45891027, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '418261000' and vocabulary_id = 'SNOMED'
), 45891028, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '418342002' and vocabulary_id = 'SNOMED'
), 45891029, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '418830004' and vocabulary_id = 'SNOMED'
), 45891030, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '418931004' and vocabulary_id = 'SNOMED'
), 45891031, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '418948007' and vocabulary_id = 'SNOMED'
), 45891032, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '419346007' and vocabulary_id = 'SNOMED'
), 45891033, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '419691006' and vocabulary_id = 'SNOMED'
), 45891034, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '419805009' and vocabulary_id = 'SNOMED'
), 45891035, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '8083511000001107' and vocabulary_id = 'SNOMED'
), 45891036, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '8088511000001103' and vocabulary_id = 'SNOMED'
), 45891037, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((
	select concept_id from concept where concept_code = '8090811000001104' and vocabulary_id = 'SNOMED'
), 45891038, 'Maps to', '01-Jan-1970', '31-Dec-2099', null);

-- Add mappings from upgraded SNOMED Concepts to UCUM
insert into concept_relationship 
select 
  rep.concept_id_1, 
  ucum.concept_id_2,
  'SNOMED replaced by' as relationship_id,
  '01-Jan-1970' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from (
  select c1.concept_id as concept_id_1, c2.concept_id as concept_id_2 from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id
  join concept c2 on c2.concept_id=r.concept_id_2
  where relationship_id='SNOMED replaced by' 
  and c1.vocabulary_id='SNOMED' and c2.vocabulary_id='SNOMED'
) rep
join (
  select c1.concept_id as concept_id_1, c2.concept_id as concept_id_2 from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id
  join concept c2 on c2.concept_id=r.concept_id_2
  where relationship_id='Maps to' 
  and c1.vocabulary_id='SNOMED' and c2.vocabulary_id='UCUM'
) ucum on rep.concept_id_2=ucum.concept_id_1
;

insert into concept_relationship 
select 
  ucum.concept_id_2 as concept_id_1,
  rep.concept_id_1 as concept_id_2, 
  'SNOMED replaces' as relationship_id,
  '01-Jan-1970' as valid_start_date,
  '31-Dec-2099' as valid_end_date,
  null as invalid_reason
from (
  select c1.concept_id as concept_id_1, c2.concept_id as concept_id_2 from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id
  join concept c2 on c2.concept_id=r.concept_id_2
  where relationship_id='SNOMED replaced by' 
  and c1.vocabulary_id='SNOMED' and c2.vocabulary_id='SNOMED'
) rep
join (
  select c1.concept_id as concept_id_1, c2.concept_id as concept_id_2 from concept c1
  join concept_relationship r on r.concept_id_1=c1.concept_id
  join concept c2 on c2.concept_id=r.concept_id_2
  where relationship_id='Maps to' 
  and c1.vocabulary_id='SNOMED' and c2.vocabulary_id='UCUM'
) ucum on rep.concept_id_2=ucum.concept_id_1
;

-- Deprecate PCORNet concept mapping to 0
update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_1 = 44814664 and concept_id_2 = 0 and relationship_id = 'Maps to';
update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_1 = 44814659 and concept_id_2 = 0 and relationship_id = 'Maps to';
update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_1 = 44814650 and concept_id_2 = 0 and relationship_id = 'Maps to';
update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_1 = 44814649 and concept_id_2 = 0 and relationship_id = 'Maps to';
update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_1 = 44814711 and concept_id_2 = 0 and relationship_id = 'Maps to';
update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_1 = 44814660 and concept_id_2 = 0 and relationship_id = 'Maps to';
update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_1 = 44819203 and concept_id_2 = 0 and relationship_id = 'Maps to';

update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_2 = 44814664 and concept_id_1 = 0 and relationship_id = 'Mapped from';
update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_2 = 44814659 and concept_id_1 = 0 and relationship_id = 'Mapped from';
update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_2 = 44814650 and concept_id_1 = 0 and relationship_id = 'Mapped from';
update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_2 = 44814649 and concept_id_1 = 0 and relationship_id = 'Mapped from';
update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_2 = 44814711 and concept_id_1 = 0 and relationship_id = 'Mapped from';
update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_2 = 44814660 and concept_id_1 = 0 and relationship_id = 'Mapped from';
update concept_relationship set
  valid_end_date = '6-Apr-2015',
  invalid_reason = 'D' 
where concept_id_2 = 44819203 and concept_id_1 = 0 and relationship_id = 'Mapped from';

-- Retire one of two UCUM year concepts
update concept set
  valid_end_date = '1-Apr-2015',
  invalid_reason = 'U'
where concept_id = 8528
;
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (8528, 9448, 'Maps to', '1-Apr-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (9448, 8528, 'Mapped from', '1-Apr-2015', '31-Dec-2099', null);

-- Add SNOMED to UCUM maps fro those used in CIEL
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (9687, 'international unit per hour', 'Unit', 'UCUM', 'Unit', 'S', '[iU]/h', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (9688, 'microgram per hour per minute', 'Unit', 'UCUM', 'Unit', 'S', 'ug/kg/min', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (9689, 'Million unit', 'Unit', 'UCUM', 'Unit', 'S', '10*6.[U]', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (9690, 'microgram per kilogram per hour', 'Unit', 'UCUM', 'Unit', 'S', 'ug/kg/h', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (9691, 'milligram per kilogram per hour', 'Unit', 'UCUM', 'Unit', 'S', 'mg/kg/h', '01-JAN-1970', '31-DEC-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (9692, 'milligram per kilogram per minute', 'Unit', 'UCUM', 'Unit', 'S', 'mg/kg/min', '01-JAN-1970', '31-DEC-2099', null);

-- add SNOMEd to UCUM maps
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4121358, 8510, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4122390, 8550, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4121369, 8512, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4121370, 8511, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4122392, 9580, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4119673, 9448, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4122398, 9551, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4121398, 9662, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4117649, 9687, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4262468, 9688, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4244979, 9689, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4227847, 9296, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4226150, 9690, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4226151, 9691, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4226152, 9692, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4255052, 8510, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4188571, 9412, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4212702, 9416, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);

insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4121358, 8510, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4122390, 8550, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4121369, 8512, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4121370, 8511, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4122392, 9580, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4119673, 9448, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4122398, 9551, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4121398, 9662, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4117649, 9687, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4262468, 9688, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4244979, 9689, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4227847, 9296, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4226150, 9690, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4226151, 9691, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4226152, 9692, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4255052, 8510, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4188571, 9412, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4212702, 9416, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);

-- Add mappings from SNOMED to Specialty and Place of Service (not complete, only what we got from CIEL)
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4023468, 38004506, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4088712, 8977, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4318944, 8717, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4331001, 38004512, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4131032, 8562, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4206451, 38004514, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4150877, 38004514, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4140387, 8756, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (40493501, 38004512, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4326892, 38004482, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4299787, 8761, 'Maps to', '1-Jan-1970', '31-Dec-2099', null);

insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4023468, 38004506, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4088712, 8977, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4318944, 8717, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4331001, 38004512, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4131032, 8562, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4206451, 38004514, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4150877, 38004514, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4140387, 8756, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (40493501, 38004512, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4326892, 38004482, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values (4299787, 8761, 'Mapped from', '1-Jan-1970', '31-Dec-2099', null);

commit;

-- Add SNOMED UK additions to relationship
'Has disp dose form' HAS_DISPENSED_DOSE_FORM
'Has spec active ing' HAS_SPECIFIC_ACTIVE_INGREDIENT
'Has basis str subst' HAS_BASIS_OF_STRENGTH_SUBSTANCE
'Has VMP' HAS_VMP
'Has incipient' HAS_EXCIPIENT
'Has licensed route' Has licensed route
'Has dose form unit' Unit relating to the size
'Has unit of prod use' Unit relating to the entity that can be handled
'Has route' 
'Has AMP' HAS_AMP



-- Fix HCPCS modifier mapping
update concept
set domain_id = case
  when concept_code in ('A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9', 'AU', 'AV', 'AW', 'AX', 'AY', 'BA',
    'CS', 'EM', 'GQ', 'JC', 'JD', 'K0', 'K1', 'K2', 'K3', 'K4', 'KA', 'KC', 'KF', 'KM', 'KN', 'KS', 'LR', 'LS',
    'NB', 'PL', 'Q0', 'QH', 'SC', 'TC', 'TW', 'UE', 'V5', 'V6', 'V7')
  then 'Device'
  when concept_code in ('EA', 'EB', 'EC', 'SL') then 'Drug'
  when concept_code in ('ED', 'EE', 'G1', 'G2', 'G3', 'G4', 'G5', 'PT') then 'Measurement'  
  when concept_code in ('AD', 'AT', 'BL', 'BO', 'CC', 'DA', 'ET', 'G8', 'G9', 'GG', 'GH', 'GJ', 'GN', 'GO', 'GP', 'GS', 'HA', 'HB',
    'HC', 'HD', 'HE', 'HF', 'HG', 'HH', 'HI', 'HJ', 'HK', 'JA', 'JB', 'JE', 'KD', 'PA', 'PB', 'PI', 'PS', 'QC', 'QK',
    'QS', 'QZ', 'RA', 'RB', 'RD', 'RE', 'RT', 'SE', 'SH', 'SJ', 'TL')
  then 'Procedure'  
  else 'Observation'
end as domain,
concept.*
from concept
where vocabulary_id = 'HCPCS' and concept_class_id = 'HCPCS Modifier'
;





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

