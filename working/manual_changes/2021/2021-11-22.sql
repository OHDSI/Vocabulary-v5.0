--make new relationships hierarchical
update relationship 
set is_hierarchical = 1, defines_ancestry = 1
where relationship_id in (
'Rx AB-drug cjgt of',
'Rx endocrine tx of',
'Rx immunotherapy of',
'Rx pept-drg cjg of',
'Rx radiocjgt of',
'Rx radiotherapy of',
'Rx targeted tx of'
)
;
--make reverse relationships names consistent with the previously created relationships names
UPDATE relationship
   SET relationship_name = 'RxNorm antibody-drug conjugate of (HemOnc)'
WHERE relationship_id = 'Rx AB-drug cjgt of';
UPDATE relationship
   SET relationship_name = 'RxNorm endocrine therapy of (HemOnc)'
WHERE relationship_id = 'Rx endocrine tx of';
UPDATE relationship
   SET relationship_name = 'RxNorm immunotherapy of (HemOnc)'
WHERE relationship_id = 'Rx immunotherapy of';
UPDATE relationship
   SET relationship_name = 'RxNorm peptide-drug conjugate of (HemOnc)'
WHERE relationship_id = 'Rx pept-drg cjg of';
UPDATE relationship
   SET relationship_name = 'RxNorm radioconjugate of (HemOnc)'
WHERE relationship_id = 'Rx radiocjgt of';
UPDATE relationship
   SET relationship_name = 'RxNorm radiotherapy of (HemOnc)'
WHERE relationship_id = 'Rx radiotherapy of';
UPDATE relationship
   SET relationship_name = 'RxNorm targeted therapy of (HemOnc)'
WHERE relationship_id = 'Rx targeted tx of';
