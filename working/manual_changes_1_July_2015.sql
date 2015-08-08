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

-- Add SNOMED to UCUM maps for those used in CIEL
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

-- add SNOMED to UCUM maps
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

-- Add CIEL vocabulary and concept_class_ids
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Columbia International eHealth Laboratory (Columbia University)', 'Metadata', 'Vocabulary', 'Vocabulary', null, 'OMOP generated', '01-JAN-1970', '31-DEC-2099', null);
insert into vocabulary (vocabulary_id, vocabulary_name, vocabulary_reference, vocabulary_version, vocabulary_concept_id, latest_update)
values ('CIEL', 'Columbia International eHealth Laboratory (Columbia University)', 'https://wiki.openmrs.org/display/docs/Getting+and+Using+the+MVP-CIEL+Concept+Dictionary', '1.11.0_20150227', (select concept_id from concept where concept_name='Columbia International eHealth Laboratory (Columbia University)'), '1-Apr-2015');

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Test', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Diagnosis', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Finding', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Anatomy', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Question', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'LabSet', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'MedSet', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'ConvSet', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Misc', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

-- Update existing but unused Concept Class Symptom
update concept set concept_name = 'Symptom' where concept_id = 44819184;
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Symptom/Finding', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Misc Order', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Workflow', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'State', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Program', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Aggregate Measurement', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Indicator', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Health Care Monitoring Topics', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Radiology/Imaging Procedure', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Frequency', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

-- Update existing but unused Concept class Drug class
update concept set concept_name = 'Pharmacologic Drug Class' where concept_id = 44818993;
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Units of Measure', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Drug form', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Medical supply', 'Metadata', 'Concept Class', 'Concept Class', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Test', 'Test', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Test'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Diagnosis', 'Diagnosis', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Diagnosis'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Finding', 'Finding', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Finding'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Anatomy', 'Anatomy', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Anatomy'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Question', 'Question', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Question'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('LabSet', 'LabSet', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'LabSet'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('MedSet', 'MedSet', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'MedSet'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('ConvSet', 'ConvSet', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'ConvSet'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Misc', 'Misc', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Misc'));
-- Update existing but unused Concept Class Symptom
update concept_class set concept_class_name = 'Symptom' where concept_class_id='Symptom';
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Symptom/Finding', 'Symptom/Finding', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Symptom/Finding'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Misc Order', 'Misc Order', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Misc Order'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Workflow', 'Workflow', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Workflow'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('State', 'State', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'State'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Program', 'Program', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Program'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Aggregate Meas', 'Aggregate Measurement', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Aggregate Measurement'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Indicator', 'Indicator', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Indicator'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Monitoring', 'Health Care Monitoring Topics', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Health Care Monitoring Topics'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Radiology', 'Radiology/Imaging Procedure', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Radiology/Imaging Procedure'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Frequency', 'Frequency', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Frequency'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Units of Measure', 'Units of Measure', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Units of Measure'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Drug form', 'Drug form', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Drug form'));
insert into concept_class (concept_class_id, concept_class_name, concept_class_concept_id)
values ('Medical supply', 'Medical supply', (select concept_id from concept where vocabulary_id = 'Concept Class' and concept_name = 'Medical supply'));

-- Add SNOMED UK additions to relationship
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has dispensed dose form (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has specific active ingredient (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has basis of strength substance (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has Virtual Medicinal Product (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has excipient (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has licensed route (CM+D)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has unit relating to the size (CM+D)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has unit relating to the entity that can be handled (CM+D)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has route (CM+D)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has Actual Medicinal Product (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Is pack of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has trade family group (CM+D)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Dispensed dose form of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Specific active ingredient of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Basis of strength substance of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Virtual Medicinal Product of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Excipient of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Licensed route of (CM+D)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Unit relating to the size of (CM+D)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Unit relating to the entity that can be handled of (CM+D)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Route of (CM+D)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Actual Medicinal Product of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has pack (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Trade family group of (CM+D)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has disp dose form', 'Has dispensed dose form (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has dispensed dose form (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Disp dose form of', 'Dispensed dose form of (SNOMED)', 0, 0, 'Has disp dose form', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Dispensed dose form of (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has spec active ing', 'Has specific active ingredient (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has specific active ingredient (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Spec active ing of', 'Specific active ingredient of (SNOMED)', 0, 0, 'Has spec active ing', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Specific active ingredient of (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has basis str subst', 'Has basis of strength substance (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has basis of strength substance (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Basis str subst of', 'Basis of strength substance of (SNOMED)', 0, 0, 'Has basis str subst', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Basis of strength substance of (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has VMP', 'Has Virtual Medicinal Product (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has Virtual Medicinal Product (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('VMP of', 'Virtual Medicinal Product of (SNOMED)', 0, 0, 'Has VMP', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Virtual Medicinal Product of (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has excipient', 'Has excipient (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has excipient (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Excipient of', 'Excipient of (SNOMED)', 0, 0, 'Has excipient', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Excipient of (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has licensed route', 'Has licensed route (CM+D)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has licensed route (CM+D)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Licensed route of', 'Licensed route of (CM+D)', 0, 0, 'Has licensed route', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Licensed route of (CM+D)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has dose form unit', 'Has unit relating to the size (CM+D)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has unit relating to the size (CM+D)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Dose form unit of', 'Unit relating to the size of (CM+D)', 0, 0, 'Has dose form unit', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Unit relating to the size of (CM+D)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has unit of prod use', 'Has unit relating to the entity that can be handled (CM+D)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has unit relating to the entity that can be handled (CM+D)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Unit of prod use of', 'Unit relating to the entity that can be handled of (CM+D)', 0, 0, 'Has unit of prod use', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Unit relating to the entity that can be handled of (CM+D)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has route', 'Has route (CM+D)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has route (CM+D)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Route of', 'Route of (CM+D)', 0, 0, 'Has route', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Route of (CM+D)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has AMP', 'Has Actual Medicinal Product (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has Actual Medicinal Product (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('AMP of', 'Actual Medicinal Product of (SNOMED)', 0, 0, 'Has AMP', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Actual Medicinal Product of (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Is pack of', 'Is pack of (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Is pack of (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has pack', 'Has pack (SNOMED)', 0, 0, 'Is pack of', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has pack (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has trade family grp', 'Has trade family group (CM+D)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has trade family group (CM+D)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Trade family grp of', 'Trade family group of (CM+D)', 0, 0, 'Has trade family grp', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Trade family group of (CM+D)'));

-- fix the temporary reverse_relationship_id from 'Is a' to what it should be
update relationship set reverse_relationship_id = 'Disp dose form of' where relationship_id = 'Has disp dose form';
update relationship set reverse_relationship_id = 'Spec active ing of' where relationship_id = 'Has spec active ing';
update relationship set reverse_relationship_id = 'Basis str subst of' where relationship_id = 'Has basis str subst';
update relationship set reverse_relationship_id = 'VMP of' where relationship_id = 'Has VMP';
update relationship set reverse_relationship_id = 'Excipient of' where relationship_id = 'Has excipient';
update relationship set reverse_relationship_id = 'Licensed route of' where relationship_id = 'Has licensed route';
update relationship set reverse_relationship_id = 'Dose form unit of' where relationship_id = 'Has dose form unit';
update relationship set reverse_relationship_id = 'Unit of prod use of' where relationship_id = 'Has unit of prod use';
update relationship set reverse_relationship_id = 'Route of' where relationship_id = 'Has route';
update relationship set reverse_relationship_id = 'AMP of' where relationship_id = 'Has AMP';
update relationship set reverse_relationship_id = 'Has pack' where relationship_id = 'Is pack of';
update relationship set reverse_relationship_id = 'Trade family grp of' where relationship_id = 'Has trade family grp';

-- Add Erica's Type Concepts
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Patient Self-Reported Condition', 'Condition Type', 'Condition Type', 'Condition Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Observation Recorded from a Survey', 'Observation Type', 'Observation Type', 'Observation Type', 'S', 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);

-- Fix remaining concept_class_id of 2-character HCPCS to be HCPCS Modifier
update concept set concept_class_id = 'HCPCS Modifier' where vocabulary_id = 'HCPCS' and concept_class_id = 'HCPCS' and length(concept_code) < 3;


-- Fix HCPCS modifier domain again
update concept
set domain_id = case
  when concept_code in ('A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9', 'AU', 'AV', 'AW', 'AX', 'AY', 'BA',
    'CS', 'EM', 'GQ', 'JC', 'JD', 'K0', 'K1', 'K2', 'K3', 'K4', 'KA', 'KC', 'KF', 'KM', 'KN', 'KS', 'LR', 'LS',
    'NB', 'PL', 'Q0', 'QH', 'SC', 'TC', 'TW', 'UE', 'V5', 'V6', 'V7')
  and concept_class_id = 'HCPCS Modifier' then 'Device'
  when concept_code in ('ED', 'EE', 'G1', 'G2', 'G3', 'G4', 'G5', 'PT') and concept_class_id = 'HCPCS Modifier' then 'Measurement'
  else 'Observation'
end
where vocabulary_id = 'HCPCS' and concept_class_id = 'HCPCS Modifier'
;

-- Rename excipient into incipient for DM+D relationship
update concept set concept_name = 'Has incipient (DM+D)' where concept_id = 45905740;
update concept set concept_name = 'Incipient of (DM+D)' where concept_id = 45905752;

update relationship set reverse_relationship_id = 'Is a' where relationship_concept_id = 45905740;
update relationship set reverse_relationship_id = 'Is a' where relationship_concept_id = 45905752;

update relationship set
  relationship_id = 'Has incipient',
  relationship_name = 'Has incipient (DM+D)'
where relationship_concept_id = 45905740; 
update relationship set
  relationship_id = 'Incipient of',
  relationship_name = 'Incipient of (DM+D)'
where relationship_concept_id = 45905752; 

update relationship set reverse_relationship_id = 'Incipient of' where relationship_concept_id = 45905740;
update relationship set reverse_relationship_id = 'Has incipient' where relationship_concept_id = 45905752;

-- Add back excipient relationships
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has excipient (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Excipient of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has excipient', 'Has excipient (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has excipient (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Excipient of', 'Excipient of (SNOMED)', 0, 0, 'Has excipient', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Excipient of (SNOMED)'));
update relationship set reverse_relationship_id = 'Excipient of' where relationship_id = 'Has excipient';

-- Fix incorrect CM+D into DM+D
update concept set concept_name = regexp_replace(concept_name, '\(CM\+D\)', '(DM+D)') where concept_name like '%(CM+D)%';
update relationship set relationship_name = regexp_replace(relationship_name, '\(CM\+D\)', '(DM+D)') where relationship_name like '%(CM+D)%';

-- Add other relationships added to SNOMED by SNOMED UK Drug Extension
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Follows (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Followed by (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Follows', 'Follows (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Follows (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Followed by', 'Followed by (SNOMED)', 0, 0, 'Follows', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Followed by (SNOMED)'));
update relationship set reverse_relationship_id = 'Followed by' where relationship_id = 'Follows';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has VMP non-availability indicator (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'VMP non-availability indicator of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has non-avail ind', 'Has VMP non-availability indicator (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has VMP non-availability indicator (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Non-avail ind of', 'VMP non-availability indicator of (SNOMED)', 0, 0, 'Has non-avail ind', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'VMP non-availability indicator of (SNOMED)'));
update relationship set reverse_relationship_id = 'Non-avail ind of' where relationship_id = 'Has non-avail ind';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has ARP (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'ARP of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has ARP', 'Has ARP (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has ARP (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('ARP of', 'ARP of (SNOMED)', 0, 0, 'Has ARP', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'ARP of (SNOMED)'));
update relationship set reverse_relationship_id = 'ARP of' where relationship_id = 'Has ARP';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has VRP (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'VRP of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has VRP', 'Has VRP (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has VRP (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('VRP of', 'VRP of (SNOMED)', 0, 0, 'Has VRP', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'VRP of (SNOMED)'));
update relationship set reverse_relationship_id = 'VRP of' where relationship_id = 'Has VRP';

update relationship set relationship_name = 'Has trade family group (SNOMED)' where relationship_concept_id=45905747;
update relationship set relationship_name = 'Trade family group of (SNOMED)' where relationship_concept_id=45905759;
update concept set concept_name = 'Has trade family group (SNOMED)' where concept_id=45905747;
update concept set concept_name = 'Trade family group of (SNOMED)' where concept_id=45905759;

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has flavor (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Flavor of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has flavor', 'Has flavor (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has flavor (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Flavor of', 'Flavor of (SNOMED)', 0, 0, 'Has flavor', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Flavor of (SNOMED)'));
update relationship set reverse_relationship_id = 'Flavor of' where relationship_id = 'Has flavor';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has discontinued indicator (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Discontinued indicator of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has disc indicator', 'Has discontinued indicator (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has discontinued indicator (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Disc indicator of', 'Discontinued indicator of (SNOMED)', 0, 0, 'Has disc indicator', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Discontinued indicator of (SNOMED)'));
update relationship set reverse_relationship_id = 'Disc indicator of' where relationship_id = 'Has disc indicator';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'VRP has prescribing status (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'VRP prescribing status of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('VRP has prescr stat', 'VRP has prescribing status (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'VRP has prescribing status (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('VRP prescr stat of', 'VRP prescribing status of (SNOMED)', 0, 0, 'VRP has prescr stat', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'VRP prescribing status of (SNOMED)'));
update relationship set reverse_relationship_id = 'VRP prescr stat of' where relationship_id = 'VRP has prescr stat';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has VMP (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'VMP of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has VMP', 'Has VMP (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has VMP (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('VMP of', 'VMP of (SNOMED)', 0, 0, 'Has VMP', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'VMP of (SNOMED)'));
update relationship set reverse_relationship_id = 'VMP of' where relationship_id = 'Has VMP';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has AMP (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'AMP of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has AMP', 'Has AMP (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has AMP (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('AMP of', 'AMP of (SNOMED)', 0, 0, 'Has AMP', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'AMP of (SNOMED)'));
update relationship set reverse_relationship_id = 'AMP of' where relationship_id = 'Has AMP';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'VMP has prescribing status (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'VMP prescribing status of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('VMP has prescr stat', 'VMP has prescribing status (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'VMP has prescribing status (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('VMP prescr stat of', 'VMP prescribing status of (SNOMED)', 0, 0, 'VRP has prescr stat', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'VMP prescribing status of (SNOMED)'));
update relationship set reverse_relationship_id = 'VRP prescr stat of' where relationship_id = 'VRP has prescr stat';

insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Has legal category (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'Legal category of (SNOMED)', 'Metadata', 'Relationship', 'Relationship', null, 'OMOP generated', '1-Jan-1970', '31-Dec-2099', null);
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Has legal category', 'Has legal category (SNOMED)', 0, 0, 'Is a', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Has legal category (SNOMED)'));
insert into relationship (relationship_id, relationship_name, is_hierarchical, defines_ancestry, reverse_relationship_id, relationship_concept_id)			
values ('Legal category of', 'Legal category of (SNOMED)', 0, 0, 'Has legal category', (select concept_id from concept where vocabulary_id = 'Relationship' and concept_name = 'Legal category of (SNOMED)'));
update relationship set reverse_relationship_id = 'Legal category of' where relationship_id = 'Has legal category';

-- Adding and fixing UCUM concepts needed for CIEL
insert into concept (concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept, concept_code, valid_start_date, valid_end_date, invalid_reason)
values (v5_concept.nextval, 'gram per cubical centimeter', 'Unit', 'UCUM', 'Unit', 'S', 'g/cm3', '01-JAN-1970', '31-DEC-2099', null);
update concept set concept_name = 'signal to cutoff ratio' where concept_id = 8779;
update concept set concept_code = '[beth''U]/mL' where concept_id = 44777562;
update concept set concept_code = 'mL/s' where concept_id = 44777614;
update concept set concept_code = 'mL/h' where concept_id = 44777613;

-- Remove redundant replace by relationships
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 2617369 and relationship_id = 'Concept replaced by' and concept_id_2 = 43533186;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 2617369 and relationship_id = 'Concept replaced by' and concept_id_2 = 43533353;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 2617369 and relationship_id = 'Concept replaced by' and concept_id_2 = 43533248;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 2617370 and relationship_id = 'Concept replaced by' and concept_id_2 = 43533187;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 2617370 and relationship_id = 'Concept replaced by' and concept_id_2 = 43533223;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 2617370 and relationship_id = 'Concept replaced by' and concept_id_2 = 43533242;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 2617370 and relationship_id = 'Concept replaced by' and concept_id_2 = 43533354;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 4058770 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 40485469;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40305404 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 4141548;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40328560 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 45765741;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40343703 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 4093140;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40351921 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 134031;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40355023 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 4108905;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40358195 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 4061262;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40390118 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 4166222;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40397523 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 4140216;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40403601 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 4166587;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40408925 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 45763732;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40408925 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 437449;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40436455 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 45763750;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40436455 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 4025168;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40461392 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 4027292;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40502851 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 4030147;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40564008 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 4311193;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40622238 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 45763732;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 2617369 and relationship_id = 'Concept replaced by' and concept_id_2 = 43533247;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40307008 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 4282906;
update concept_relationship set valid_end_date = '28-May-2015', invalid_reason = 'D' where concept_id_1 = 40307008 and relationship_id = 'Concept poss_eq to' and concept_id_2 = 4065257;

-- Improved ICD10 mappings by Martijn
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.0'), 4002357, 'Maps to', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.1'), 4001329, 'Maps to', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.2'), 4003833, 'Maps to', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.7'), 4147411, 'Maps to', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.9'), 4147411, 'Maps to', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.0'), 4002356, 'Maps to', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.1'), 4003180, 'Maps to', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C85.9'), 4038838, 'Maps to', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.3'), 432574, 'Maps to', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.4'), 4003832, 'Maps to', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.5'), 4001328, 'Maps to', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.6'), 4003831, 'Maps to', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.8'), 4003830, 'Maps to', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_1, concept_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C85.1'), 434592, 'Maps to', '30-May-2015', '31-Dec-2099', null);

insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.0'), 4002357, 'Mapped from', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.1'), 4001329, 'Mapped from', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.2'), 4003833, 'Mapped from', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.7'), 4147411, 'Mapped from', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.9'), 4147411, 'Mapped from', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.0'), 4002356, 'Mapped from', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.1'), 4003180, 'Mapped from', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C85.9'), 4038838, 'Mapped from', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.3'), 432574, 'Mapped from', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.4'), 4003832, 'Mapped from', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.5'), 4001328, 'Mapped from', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.6'), 4003831, 'Mapped from', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.8'), 4003830, 'Mapped from', '30-May-2015', '31-Dec-2099', null);
insert into concept_relationship (concept_id_2, concept_id_1, relationship_id, valid_start_date, valid_end_date, invalid_reason)
values ((select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C85.1'), 434592, 'Mapped from', '30-May-2015', '31-Dec-2099', null);

update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.0') and concept_id_2 = 194878;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.1') and concept_id_2 = 194878;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.2') and concept_id_2 = 194878;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.7') and concept_id_2 = 4299152;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.9') and concept_id_2 = 194878;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.0') and concept_id_2 = 440058;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.1') and concept_id_2 = 40481901;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C85.9') and concept_id_2 = 432571;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.3') and concept_id_2 = 436920;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.4') and concept_id_2 = 4003830;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.5') and concept_id_2 = 200662;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.6') and concept_id_2 = 4003830;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.8') and concept_id_2 = 440058;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_1 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C85.1') and concept_id_2 = 432571;

update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.0') and concept_id_1 = 194878;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.1') and concept_id_1 = 194878;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.2') and concept_id_1 = 194878;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.7') and concept_id_1 = 4299152;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C82.9') and concept_id_1 = 194878;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.0') and concept_id_1 = 440058;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.1') and concept_id_1 = 40481901;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C85.9') and concept_id_1 = 432571;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.3') and concept_id_1 = 436920;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.4') and concept_id_1 = 4003830;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.5') and concept_id_1 = 200662;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.6') and concept_id_1 = 4003830;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C83.8') and concept_id_1 = 440058;
update concept_relationship set valid_end_date = '29-May-2015', invalid_reason = 'D' where concept_id_2 = (select concept_id from concept where vocabulary_id = 'ICD10' and concept_code = 'C85.1') and concept_id_1 = 432571;

-- Remove obsolete vocabulary LOINC Hierarchy
delete from vocabulary_conversion where vocabulary_id_v5='LOINC Hierarchy';
delete from vocabulary where vocabulary_id='LOINC Hierarchy';

