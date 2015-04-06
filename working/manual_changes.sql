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

