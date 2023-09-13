--backup checks
SELECT count(*) FROM concept_manual;
SELECT count(*) FROM concept_manual_backup_2023_02_08;
SELECT count(*) FROM concept_relationship_manual;
SELECT count(*) FROM concept_relationship_manual_2023_02_08;

 --integrity checks
--CHECK THE # OF CODES OVERLAPPING BETWEEN MANUAL REFRESH AND PREVIOUS CRM version in case of identical relationships and thier validities
SELECT *
FROM concept_relationship_manual_backup_2023_02_08 crmb
WHERE EXISTS (
    SELECT 1
    from concept_relationship_manual_refresh crmr
    WHERE crmr.concept_code_1=crmb.concept_code_1
    and crmr.vocabulary_id_1=crmb.vocabulary_id_1
    and crmr.relationship_id=crmb.relationship_id
          )
and crmb.invalid_reason IS NULL
and crmb.concept_code_1<>crmb.concept_code_2
and crmb.vocabulary_id_1<>crmb.vocabulary_id_2
;

--1toM check
--Clinically relevant
SELECT DISTINCT *
   FROM concept_relationship_manual_refresh
JOIN concept c ON concept_relationship_manual_refresh.concept_code_2 = c.concept_code
and c.vocabulary_id='Cancer Modifier'
    WHERE (concept_code_1,relationship_id) IN (
        SELECT concept_code_1,relationship_id
   FROM concept_relationship_manual_refresh
   GROUP BY concept_code_1,relationship_id HAVING count(DISTINCT concept_code_2)>1
        )
;

--Detect codes not existing as naaccr values
SELECT *
FROM concept_relationship_manual_refresh
WHERE concept_code_1 not in (SELECT concept_code from concept where concept_class_id='NAACCR Value')
;

--CHeck that NAACCR Values are not target for other codes
SELECT *
FROM concept_relationship_manual_refresh a
JOIN concept b
on a.concept_code_1=b.concept_code and concept_class_id='NAACCR Value'
JOIN concept_relationship r
on b.concept_id=r.concept_id_2
and r.relationship_id='Maps to'
and r.invalid_reason is null
and r.concept_id_2<>r.concept_id_1
;

--
SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason IS NULL --deprecate only what's not yet deprecated in order to preserve the original deprecation date

    AND concept_code_1 IN (SELECT concept_code_1 FROM concept_relationship_manual_refresh where relationship_id='Maps to') --work only with the codes presented in the manual file of the current vocabulary refresh

    AND NOT EXISTS (SELECT 1 --don't deprecate mapping if the same exists in the current manual file
                    FROM concept_relationship_manual_refresh rl
                    WHERE rl.concept_code_1 = crm.concept_code_1 --the same source_code is mapped
                        AND rl.concept_code_2 = crm.concept_code_2 --to the same concept_code
                        AND rl.vocabulary_id_2 = crm.vocabulary_id_2 --of the same vocabulary
                        AND rl.relationship_id = crm.relationship_id --with the same relationship
        )
and crm.relationship_id IN ('Maps to', 'Maps to value')
;
