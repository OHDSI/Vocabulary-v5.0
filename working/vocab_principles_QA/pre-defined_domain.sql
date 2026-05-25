-- This check is used to analyse the dynamics of domain changes in the OHDSI vocabularies across four releases.
--- To run this check, you need to have schemas with base table states corresponding to the releases you are interested in (this can be done with our audit_pack: https://github.com/OHDSI/Vocabulary-v5.0/tree/master/working/packages/audit_pack)
--- Before running this check replace the placeholders with the respective schema names. 

--Standard code changes
SELECT DISTINCT c1.domain_id AS v1_domain_id,
                c1.standard_concept as v1_standard_concept,
                v1.vocabulary_version as v1_vocabulary_version,

                c2.domain_id AS v2_domain_id,
                c2.standard_concept as v2_standard_concept,
                v2.vocabulary_version as v2_vocabulary_version,

                c3.domain_id AS v3_domain_id,
                c3.standard_concept as v2_standard_concept,
                v3.vocabulary_version as v3_vocabulary_version,

                c4.domain_id AS v3_domain_id,
                c4.standard_concept as v3_standard_concept,
                v4.vocabulary_version as v4_vocabulary_version,
                COUNT(*)        AS id_cnt
FROM schema_4.concept c4
         JOIN schema_3.concept c3
              ON c4.concept_id = c3.concept_id
         JOIN schema_4.vocabulary v4
              ON v4.vocabulary_id = 'None'
         JOIN schema_3.vocabulary v3
              ON v3.vocabulary_id = 'None'
         JOIN schema_2.concept c2
              ON c4.concept_id = c2.concept_id
                and c2.concept_id=c3.concept_id
         JOIN schema_2.vocabulary v2
              ON v2.vocabulary_id = 'None'
         JOIN schema_1.concept c1
              ON c4.concept_id = c1.concept_id
     and c1.concept_id=c2.concept_id
         JOIN schema_1.vocabulary v1
              ON v1.vocabulary_id = 'None'
GROUP BY        c1.domain_id,
                c1.standard_concept,
                v1.vocabulary_version,

                c2.domain_id ,
                c2.standard_concept ,
                v2.vocabulary_version,

                c3.domain_id,
                c3.standard_concept,
                v3.vocabulary_version,

                c4.domain_id,
                c4.standard_concept,
                v4.vocabulary_version
ORDER BY id_cnt DESC
;
