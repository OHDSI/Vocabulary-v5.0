--PPI duplicated concept codes
--COPE_A_202 and cope_a_202
--COPE_A_236 and cope_a_236
--we keep the lower case ones, but make upper case ones unrecognizable
UPDATE concept
   SET concept_name = 'Invalid PPI Concept, do not use',
       concept_code = '905023',
       valid_end_date = to_date ('2022-01-25','yyyy-MM-dd'),
       invalid_reason = 'D'
WHERE concept_id = 905023;
UPDATE concept
   SET concept_name = 'Invalid PPI Concept, do not use',
       concept_code = '905043',
       valid_end_date = to_date ('2022-01-25','yyyy-MM-dd'),
       invalid_reason = 'D'
WHERE concept_id = 905043;

--deprecate all relationships for these concepts
update concept_relationship set invalid_reason='D' ,
valid_end_date = to_date ('2022-01-25','yyyy-MM-dd')
where concept_id_1 in (905023, 905043)
;
update concept_relationship set invalid_reason='D',
valid_end_date = to_date ('2022-01-25','yyyy-MM-dd')
where concept_id_2 in (905023, 905043)
;
--to avoid any confusion when people mapping to PPI, we cover it under the licence
UPDATE vocabulary_conversion
   SET url = 'mailto:contact@ohdsi.org?subject=License%20required%20for%20PPI&body=Describe%20your%20situation%20and%20your%20need%20for%20this%20vocabulary.'
WHERE vocabulary_id_v5 = 'PPI';

