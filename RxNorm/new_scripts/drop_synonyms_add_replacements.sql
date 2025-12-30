--- Drop from manual tables concepts that are already in
WITH CTE as
(
---- Drop RxE vaccines duplicates
select DISTINCT t2.concept_name,
       t2.domain_id,
       t2.vocabulary_id,
       t2.concept_class_id,
       t2.standard_concept,
       t2.concept_code,
       t2.valid_start_date,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_end_date,
       'U' as invalid_reason
from dev_rxnorm.rxn_rxe_vaccines_duplicates_gpt_v01 t1
     join dev_rxnorm.concept t2 on t1.concept_id_2 = t2.concept_id
where is_synonym_manual = 'yes'

UNION

--- Drop other RxE drugs duplicates RxN-RxE
select DISTINCT t2.concept_name,
       t2.domain_id,
       t2.vocabulary_id,
       t2.concept_class_id,
       t2.standard_concept,
       t2.concept_code,
       t2.valid_start_date,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_end_date,
       'U' as invalid_reason
from dev_rxnorm.rxnorm_synonym_wo_vaccines_v01 t1
     join dev_rxnorm.concept t2 on t1.concept_id_2 = t2.concept_id
where is_synonym = 'yes'

UNION

--- Drop other RxE drugs duplicates RxE-RxE
select DISTINCT t2.concept_name,
       t2.domain_id,
       t2.vocabulary_id,
       t2.concept_class_id,
       t2.standard_concept,
       t2.concept_code,
       t2.valid_start_date,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_end_date,
       'U' as invalid_reason
from dev_rxnorm.similar_concepts_rxe_rxe_processed_chatgpt t1
     join dev_rxnorm.concept t2 on t1.concept_id_2 = t2.concept_id
where is_synonym = 'yes'
and name_similarity != '1.0'
)

DELETE FROM concept_manual
WHERE concept_code IN (SELECT concept_code FROM CTE);



------ Set flag U to RxE concepts
INSERT INTO concept_manual
(
---- Drop RxE vaccines duplicates
select DISTINCT t2.concept_name,
       t2.domain_id,
       t2.vocabulary_id,
       t2.concept_class_id,
       t2.standard_concept,
       t2.concept_code,
       t2.valid_start_date,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_end_date,
       'U' as invalid_reason
from dev_rxnorm.rxn_rxe_vaccines_duplicates_gpt_v01 t1
     join dev_rxnorm.concept t2 on t1.concept_id_2 = t2.concept_id
where is_synonym_manual = 'yes'



UNION

--- Drop other RxE drugs duplicates RxN-RxE
select DISTINCT t2.concept_name,
       t2.domain_id,
       t2.vocabulary_id,
       t2.concept_class_id,
       t2.standard_concept,
       t2.concept_code,
       t2.valid_start_date,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_end_date,
       'U' as invalid_reason
from dev_rxnorm.rxnorm_synonym_wo_vaccines_v01 t1
     join dev_rxnorm.concept t2 on t1.concept_id_2 = t2.concept_id
where is_synonym = 'yes'

UNION

--- Drop other RxE drugs duplicates RxE-RxE
select DISTINCT t2.concept_name,
       t2.domain_id,
       t2.vocabulary_id,
       t2.concept_class_id,
       t2.standard_concept,
       t2.concept_code,
       t2.valid_start_date,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_end_date,
       'U' as invalid_reason
from dev_rxnorm.similar_concepts_rxe_rxe_processed_chatgpt t1
     join dev_rxnorm.concept t2 on t1.concept_id_2 = t2.concept_id
where is_synonym = 'yes'
and name_similarity  != '1.0'


);


---- Concept relationship_manual table update
INSERT INTO concept_relationship_manual
(

---------------------------- Vaccines

--- Add maps_to for U concepts (vaccines)
select DISTINCT
       t1.concept_code_2 :: TEXT,
       t1.concept_code_1 :: TEXT,
       'RxNorm Extension' as vocabulary_id_1,
       'RxNorm' as vocabulary_id_2,
       'Maps to' as realtionship_id,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_start_date,
       TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date,
       NULL as invalid_reason
from dev_rxnorm.rxn_rxe_vaccines_duplicates_gpt_v01 t1
        join devv5.concept t2 on t1.concept_id_1 = t2.concept_id
                              and t2.standard_concept = 'S'
where t1.is_synonym_manual = 'yes'

UNION

--- Add concept replaced by for nonstandard targets (Vaccines)
select DISTINCT
       t1.concept_code_2 :: TEXT,
       t1.concept_code_1 :: TEXT,
       'RxNorm Extension' as vocabulary_id_1,
       'RxNorm' as vocabulary_id_2,
       'Concept replaced by' as realtionship_id,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_start_date,
       TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date,
       NULL as invalid_reason
from dev_rxnorm.rxn_rxe_vaccines_duplicates_gpt_v01 t1
        join devv5.concept t2 on t1.concept_id_1 = t2.concept_id
                              and t2.standard_concept is NULL
where t1.is_synonym_manual = 'yes'


---------------------------- RxN - RxE

UNION

--- Add maps_to for U concepts (other drugs)
select DISTINCT
       t1.concept_code_2 :: TEXT,
       t1.concept_code_1 :: TEXT,
       'RxNorm Extension' as vocabulary_id_1,
       'RxNorm' as vocabulary_id_2,
       'Maps to' as realtionship_id,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_start_date,
       TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date,
       NULL as invalid_reason
from dev_rxnorm.rxnorm_synonym_wo_vaccines_v01 t1
        join devv5.concept t2 on t1.concept_id_1 = t2.concept_id
                              and t2.standard_concept = 'S'
where t1.is_synonym = 'yes'

UNION

--- Add concept replaced by for nonstandard targets (other drugs)

select DISTINCT
       t1.concept_code_2 :: TEXT,
       t1.concept_code_1 :: TEXT,
       'RxNorm Extension' as vocabulary_id_1,
       'RxNorm' as vocabulary_id_2,
       'Concept replaced by' as realtionship_id,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_start_date,
       TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date,
       NULL as invalid_reason
from dev_rxnorm.rxnorm_synonym_wo_vaccines_v01 t1
        join devv5.concept t2 on t1.concept_id_1 = t2.concept_id
                              and t2.standard_concept is NULL
where t1.is_synonym = 'yes'

---------------------------- RxE - RxE

UNION

--- Add maps_to for U concepts
select DISTINCT
       t1.concept_code_2 :: TEXT,
       t1.concept_code_1 :: TEXT,
       'RxNorm Extension' as vocabulary_id_1,
       'RxNorm Extension' as vocabulary_id_2,
       'Maps to' as realtionship_id,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_start_date,
       TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date,
       NULL as invalid_reason
from dev_rxnorm.similar_concepts_rxe_rxe_processed_chatgpt t1
        join devv5.concept t2 on t1.concept_id_1 = t2.concept_id
                              and t2.standard_concept = 'S'
where t1.is_synonym = 'yes'
and t1.name_similarity != '1.0'

UNION

--- Add concept replaced by for nonstandard targets

select DISTINCT
       t1.concept_code_2 :: TEXT,
       t1.concept_code_1 :: TEXT,
       'RxNorm Extension' as vocabulary_id_1,
       'RxNorm Extension' as vocabulary_id_2,
       'Concept replaced by' as realtionship_id,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_start_date,
       TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date,
       NULL as invalid_reason
from dev_rxnorm.similar_concepts_rxe_rxe_processed_chatgpt t1
        join devv5.concept t2 on t1.concept_id_1 = t2.concept_id
                              and t2.standard_concept is NULL
where t1.is_synonym = 'yes'
and t1.name_similarity != '1.0');



