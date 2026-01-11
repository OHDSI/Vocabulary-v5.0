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

UNION
----- DROP MANUALY CURATED CONCEPTS

select DISTINCT t2.concept_name,
       t2.domain_id,
       t2.vocabulary_id,
       t2.concept_class_id,
       t2.standard_concept,
       t2.concept_code,
       t2.valid_start_date,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_end_date,
       'U' as invalid_reason
from dev_rxnorm.rxn_rxe_duplicates_manual t1
     join devv5.concept t2 on t1.source_code = t2.concept_code and t1.source_vocabulary_id = t2.vocabulary_id
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
and concept_code_2 not in ('OMOP5154536', 'OMOP5154534', 'OMOP5154532', 'OMOP5154533', 'OMOP5154537', 'OMOP5154538', 'OMOP1116538', 'OMOP4995035', 'OMOP5144067', 'OMOP364173', 'OMOP4944542', 'OMOP4978105', 'OMOP4978113', 'OMOP4978121', 'OMOP4978153', 'OMOP4978187', 'OMOP4993714', 'OMOP5130199', 'OMOP5214469', 'OMOP1024756', 'OMOP1063565', 'OMOP1076284', 'OMOP1076503', 'OMOP1077154', 'OMOP1077868', 'OMOP1089624', 'OMOP1089734', 'OMOP1102514', 'OMOP1140405', 'OMOP1143427', 'OMOP1143880', 'OMOP1146228', 'OMOP2019987', 'OMOP2122250', 'OMOP2795950', 'OMOP2795968', 'OMOP2795996', 'OMOP2808071', 'OMOP2809655', 'OMOP3101286', 'OMOP3105391', 'OMOP322480', 'OMOP408540', 'OMOP4698404', 'OMOP4703825', 'OMOP4730789', 'OMOP4754844', 'OMOP4822787', 'OMOP4826749', 'OMOP4828854', 'OMOP4828897', 'OMOP4829009', 'OMOP4867304', 'OMOP4967660', 'OMOP4977988', 'OMOP4978074', 'OMOP4978077', 'OMOP4978081', 'OMOP4978101', 'OMOP4978102', 'OMOP4978127', 'OMOP4978133', 'OMOP4978139', 'OMOP4978145', 'OMOP4978180', 'OMOP4978184', 'OMOP4978185', 'OMOP4978186', 'OMOP4978188', 'OMOP4978189', 'OMOP4978190', 'OMOP4978579', 'OMOP4978935', 'OMOP4979472', 'OMOP4980230', 'OMOP4980553', 'OMOP4985897', 'OMOP4993739', 'OMOP4996285', 'OMOP4996291', 'OMOP5032180', 'OMOP5032296', 'OMOP5032356', 'OMOP5032474', 'OMOP5032566', 'OMOP5040668', 'OMOP5040759', 'OMOP5040765', 'OMOP5040814', 'OMOP5040869', 'OMOP5122369', 'OMOP5122810', 'OMOP5144092', 'OMOP5147132', 'OMOP5151610', 'OMOP5153222', 'OMOP5154204', 'OMOP5154878', 'OMOP5154881', 'OMOP5214681', 'OMOP5215805', 'OMOP5561075', 'OMOP5561084', 'OMOP5561110', 'OMOP5561136', 'OMOP5561154', 'OMOP5561217', 'OMOP5561227', 'OMOP5561228', 'OMOP5561229', 'OMOP5561264', 'OMOP5561268', 'OMOP5561278', 'OMOP5561279', 'OMOP5561280', 'OMOP5561281', 'OMOP5561299', 'OMOP5561375', 'OMOP5561381', 'OMOP5561631', 'OMOP5561662', 'OMOP5561738', 'OMOP5561839', 'OMOP5561972', 'OMOP5563082', 'OMOP5564095', 'OMOP5564613', 'OMOP5577089', 'OMOP5577095', 'OMOP5582542', 'OMOP5583316', 'OMOP799479', 'OMOP799488', 'OMOP799514', 'OMOP799519', 'OMOP995861')


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
and concept_code_2 not in ('OMOP5154536', 'OMOP5154534', 'OMOP5154532', 'OMOP5154533', 'OMOP5154537', 'OMOP5154538', 'OMOP1116538', 'OMOP4995035', 'OMOP5144067', 'OMOP364173', 'OMOP4944542', 'OMOP4978105', 'OMOP4978113', 'OMOP4978121', 'OMOP4978153', 'OMOP4978187', 'OMOP4993714', 'OMOP5130199', 'OMOP5214469', 'OMOP1024756', 'OMOP1063565', 'OMOP1076284', 'OMOP1076503', 'OMOP1077154', 'OMOP1077868', 'OMOP1089624', 'OMOP1089734', 'OMOP1102514', 'OMOP1140405', 'OMOP1143427', 'OMOP1143880', 'OMOP1146228', 'OMOP2019987', 'OMOP2122250', 'OMOP2795950', 'OMOP2795968', 'OMOP2795996', 'OMOP2808071', 'OMOP2809655', 'OMOP3101286', 'OMOP3105391', 'OMOP322480', 'OMOP408540', 'OMOP4698404', 'OMOP4703825', 'OMOP4730789', 'OMOP4754844', 'OMOP4822787', 'OMOP4826749', 'OMOP4828854', 'OMOP4828897', 'OMOP4829009', 'OMOP4867304', 'OMOP4967660', 'OMOP4977988', 'OMOP4978074', 'OMOP4978077', 'OMOP4978081', 'OMOP4978101', 'OMOP4978102', 'OMOP4978127', 'OMOP4978133', 'OMOP4978139', 'OMOP4978145', 'OMOP4978180', 'OMOP4978184', 'OMOP4978185', 'OMOP4978186', 'OMOP4978188', 'OMOP4978189', 'OMOP4978190', 'OMOP4978579', 'OMOP4978935', 'OMOP4979472', 'OMOP4980230', 'OMOP4980553', 'OMOP4985897', 'OMOP4993739', 'OMOP4996285', 'OMOP4996291', 'OMOP5032180', 'OMOP5032296', 'OMOP5032356', 'OMOP5032474', 'OMOP5032566', 'OMOP5040668', 'OMOP5040759', 'OMOP5040765', 'OMOP5040814', 'OMOP5040869', 'OMOP5122369', 'OMOP5122810', 'OMOP5144092', 'OMOP5147132', 'OMOP5151610', 'OMOP5153222', 'OMOP5154204', 'OMOP5154878', 'OMOP5154881', 'OMOP5214681', 'OMOP5215805', 'OMOP5561075', 'OMOP5561084', 'OMOP5561110', 'OMOP5561136', 'OMOP5561154', 'OMOP5561217', 'OMOP5561227', 'OMOP5561228', 'OMOP5561229', 'OMOP5561264', 'OMOP5561268', 'OMOP5561278', 'OMOP5561279', 'OMOP5561280', 'OMOP5561281', 'OMOP5561299', 'OMOP5561375', 'OMOP5561381', 'OMOP5561631', 'OMOP5561662', 'OMOP5561738', 'OMOP5561839', 'OMOP5561972', 'OMOP5563082', 'OMOP5564095', 'OMOP5564613', 'OMOP5577089', 'OMOP5577095', 'OMOP5582542', 'OMOP5583316', 'OMOP799479', 'OMOP799488', 'OMOP799514', 'OMOP799519', 'OMOP995861')


UNION
----- DROP MANUALY CURATED CONCEPTS

select DISTINCT t2.concept_name,
       t2.domain_id,
       t2.vocabulary_id,
       t2.concept_class_id,
       t2.standard_concept,
       t2.concept_code,
       t2.valid_start_date,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_end_date,
       'U' as invalid_reason
from dev_rxnorm.rxn_rxe_duplicates_manual t1
     join devv5.concept t2 on t1.source_code = t2.concept_code and t1.source_vocabulary_id = t2.vocabulary_id
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
and concept_code_2 not in ('OMOP5154536', 'OMOP5154534', 'OMOP5154532', 'OMOP5154533', 'OMOP5154537', 'OMOP5154538', 'OMOP1116538', 'OMOP4995035', 'OMOP5144067', 'OMOP364173', 'OMOP4944542', 'OMOP4978105', 'OMOP4978113', 'OMOP4978121', 'OMOP4978153', 'OMOP4978187', 'OMOP4993714', 'OMOP5130199', 'OMOP5214469', 'OMOP1024756', 'OMOP1063565', 'OMOP1076284', 'OMOP1076503', 'OMOP1077154', 'OMOP1077868', 'OMOP1089624', 'OMOP1089734', 'OMOP1102514', 'OMOP1140405', 'OMOP1143427', 'OMOP1143880', 'OMOP1146228', 'OMOP2019987', 'OMOP2122250', 'OMOP2795950', 'OMOP2795968', 'OMOP2795996', 'OMOP2808071', 'OMOP2809655', 'OMOP3101286', 'OMOP3105391', 'OMOP322480', 'OMOP408540', 'OMOP4698404', 'OMOP4703825', 'OMOP4730789', 'OMOP4754844', 'OMOP4822787', 'OMOP4826749', 'OMOP4828854', 'OMOP4828897', 'OMOP4829009', 'OMOP4867304', 'OMOP4967660', 'OMOP4977988', 'OMOP4978074', 'OMOP4978077', 'OMOP4978081', 'OMOP4978101', 'OMOP4978102', 'OMOP4978127', 'OMOP4978133', 'OMOP4978139', 'OMOP4978145', 'OMOP4978180', 'OMOP4978184', 'OMOP4978185', 'OMOP4978186', 'OMOP4978188', 'OMOP4978189', 'OMOP4978190', 'OMOP4978579', 'OMOP4978935', 'OMOP4979472', 'OMOP4980230', 'OMOP4980553', 'OMOP4985897', 'OMOP4993739', 'OMOP4996285', 'OMOP4996291', 'OMOP5032180', 'OMOP5032296', 'OMOP5032356', 'OMOP5032474', 'OMOP5032566', 'OMOP5040668', 'OMOP5040759', 'OMOP5040765', 'OMOP5040814', 'OMOP5040869', 'OMOP5122369', 'OMOP5122810', 'OMOP5144092', 'OMOP5147132', 'OMOP5151610', 'OMOP5153222', 'OMOP5154204', 'OMOP5154878', 'OMOP5154881', 'OMOP5214681', 'OMOP5215805', 'OMOP5561075', 'OMOP5561084', 'OMOP5561110', 'OMOP5561136', 'OMOP5561154', 'OMOP5561217', 'OMOP5561227', 'OMOP5561228', 'OMOP5561229', 'OMOP5561264', 'OMOP5561268', 'OMOP5561278', 'OMOP5561279', 'OMOP5561280', 'OMOP5561281', 'OMOP5561299', 'OMOP5561375', 'OMOP5561381', 'OMOP5561631', 'OMOP5561662', 'OMOP5561738', 'OMOP5561839', 'OMOP5561972', 'OMOP5563082', 'OMOP5564095', 'OMOP5564613', 'OMOP5577089', 'OMOP5577095', 'OMOP5582542', 'OMOP5583316', 'OMOP799479', 'OMOP799488', 'OMOP799514', 'OMOP799519', 'OMOP995861')

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
and concept_code_2 not in ('OMOP5154536', 'OMOP5154534', 'OMOP5154532', 'OMOP5154533', 'OMOP5154537', 'OMOP5154538', 'OMOP1116538', 'OMOP4995035', 'OMOP5144067', 'OMOP364173', 'OMOP4944542', 'OMOP4978105', 'OMOP4978113', 'OMOP4978121', 'OMOP4978153', 'OMOP4978187', 'OMOP4993714', 'OMOP5130199', 'OMOP5214469', 'OMOP1024756', 'OMOP1063565', 'OMOP1076284', 'OMOP1076503', 'OMOP1077154', 'OMOP1077868', 'OMOP1089624', 'OMOP1089734', 'OMOP1102514', 'OMOP1140405', 'OMOP1143427', 'OMOP1143880', 'OMOP1146228', 'OMOP2019987', 'OMOP2122250', 'OMOP2795950', 'OMOP2795968', 'OMOP2795996', 'OMOP2808071', 'OMOP2809655', 'OMOP3101286', 'OMOP3105391', 'OMOP322480', 'OMOP408540', 'OMOP4698404', 'OMOP4703825', 'OMOP4730789', 'OMOP4754844', 'OMOP4822787', 'OMOP4826749', 'OMOP4828854', 'OMOP4828897', 'OMOP4829009', 'OMOP4867304', 'OMOP4967660', 'OMOP4977988', 'OMOP4978074', 'OMOP4978077', 'OMOP4978081', 'OMOP4978101', 'OMOP4978102', 'OMOP4978127', 'OMOP4978133', 'OMOP4978139', 'OMOP4978145', 'OMOP4978180', 'OMOP4978184', 'OMOP4978185', 'OMOP4978186', 'OMOP4978188', 'OMOP4978189', 'OMOP4978190', 'OMOP4978579', 'OMOP4978935', 'OMOP4979472', 'OMOP4980230', 'OMOP4980553', 'OMOP4985897', 'OMOP4993739', 'OMOP4996285', 'OMOP4996291', 'OMOP5032180', 'OMOP5032296', 'OMOP5032356', 'OMOP5032474', 'OMOP5032566', 'OMOP5040668', 'OMOP5040759', 'OMOP5040765', 'OMOP5040814', 'OMOP5040869', 'OMOP5122369', 'OMOP5122810', 'OMOP5144092', 'OMOP5147132', 'OMOP5151610', 'OMOP5153222', 'OMOP5154204', 'OMOP5154878', 'OMOP5154881', 'OMOP5214681', 'OMOP5215805', 'OMOP5561075', 'OMOP5561084', 'OMOP5561110', 'OMOP5561136', 'OMOP5561154', 'OMOP5561217', 'OMOP5561227', 'OMOP5561228', 'OMOP5561229', 'OMOP5561264', 'OMOP5561268', 'OMOP5561278', 'OMOP5561279', 'OMOP5561280', 'OMOP5561281', 'OMOP5561299', 'OMOP5561375', 'OMOP5561381', 'OMOP5561631', 'OMOP5561662', 'OMOP5561738', 'OMOP5561839', 'OMOP5561972', 'OMOP5563082', 'OMOP5564095', 'OMOP5564613', 'OMOP5577089', 'OMOP5577095', 'OMOP5582542', 'OMOP5583316', 'OMOP799479', 'OMOP799488', 'OMOP799514', 'OMOP799519', 'OMOP995861')

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
and concept_code_2 not in ('OMOP5154536', 'OMOP5154534', 'OMOP5154532', 'OMOP5154533', 'OMOP5154537', 'OMOP5154538', 'OMOP1116538', 'OMOP4995035', 'OMOP5144067', 'OMOP364173', 'OMOP4944542', 'OMOP4978105', 'OMOP4978113', 'OMOP4978121', 'OMOP4978153', 'OMOP4978187', 'OMOP4993714', 'OMOP5130199', 'OMOP5214469', 'OMOP1024756', 'OMOP1063565', 'OMOP1076284', 'OMOP1076503', 'OMOP1077154', 'OMOP1077868', 'OMOP1089624', 'OMOP1089734', 'OMOP1102514', 'OMOP1140405', 'OMOP1143427', 'OMOP1143880', 'OMOP1146228', 'OMOP2019987', 'OMOP2122250', 'OMOP2795950', 'OMOP2795968', 'OMOP2795996', 'OMOP2808071', 'OMOP2809655', 'OMOP3101286', 'OMOP3105391', 'OMOP322480', 'OMOP408540', 'OMOP4698404', 'OMOP4703825', 'OMOP4730789', 'OMOP4754844', 'OMOP4822787', 'OMOP4826749', 'OMOP4828854', 'OMOP4828897', 'OMOP4829009', 'OMOP4867304', 'OMOP4967660', 'OMOP4977988', 'OMOP4978074', 'OMOP4978077', 'OMOP4978081', 'OMOP4978101', 'OMOP4978102', 'OMOP4978127', 'OMOP4978133', 'OMOP4978139', 'OMOP4978145', 'OMOP4978180', 'OMOP4978184', 'OMOP4978185', 'OMOP4978186', 'OMOP4978188', 'OMOP4978189', 'OMOP4978190', 'OMOP4978579', 'OMOP4978935', 'OMOP4979472', 'OMOP4980230', 'OMOP4980553', 'OMOP4985897', 'OMOP4993739', 'OMOP4996285', 'OMOP4996291', 'OMOP5032180', 'OMOP5032296', 'OMOP5032356', 'OMOP5032474', 'OMOP5032566', 'OMOP5040668', 'OMOP5040759', 'OMOP5040765', 'OMOP5040814', 'OMOP5040869', 'OMOP5122369', 'OMOP5122810', 'OMOP5144092', 'OMOP5147132', 'OMOP5151610', 'OMOP5153222', 'OMOP5154204', 'OMOP5154878', 'OMOP5154881', 'OMOP5214681', 'OMOP5215805', 'OMOP5561075', 'OMOP5561084', 'OMOP5561110', 'OMOP5561136', 'OMOP5561154', 'OMOP5561217', 'OMOP5561227', 'OMOP5561228', 'OMOP5561229', 'OMOP5561264', 'OMOP5561268', 'OMOP5561278', 'OMOP5561279', 'OMOP5561280', 'OMOP5561281', 'OMOP5561299', 'OMOP5561375', 'OMOP5561381', 'OMOP5561631', 'OMOP5561662', 'OMOP5561738', 'OMOP5561839', 'OMOP5561972', 'OMOP5563082', 'OMOP5564095', 'OMOP5564613', 'OMOP5577089', 'OMOP5577095', 'OMOP5582542', 'OMOP5583316', 'OMOP799479', 'OMOP799488', 'OMOP799514', 'OMOP799519', 'OMOP995861')




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
and t1.name_similarity != '1.0'
and concept_code_2 not in ('OMOP5154536', 'OMOP5154534', 'OMOP5154532', 'OMOP5154533', 'OMOP5154537', 'OMOP5154538', 'OMOP1116538', 'OMOP4995035', 'OMOP5144067', 'OMOP364173', 'OMOP4944542', 'OMOP4978105', 'OMOP4978113', 'OMOP4978121', 'OMOP4978153', 'OMOP4978187', 'OMOP4993714', 'OMOP5130199', 'OMOP5214469', 'OMOP1024756', 'OMOP1063565', 'OMOP1076284', 'OMOP1076503', 'OMOP1077154', 'OMOP1077868', 'OMOP1089624', 'OMOP1089734', 'OMOP1102514', 'OMOP1140405', 'OMOP1143427', 'OMOP1143880', 'OMOP1146228', 'OMOP2019987', 'OMOP2122250', 'OMOP2795950', 'OMOP2795968', 'OMOP2795996', 'OMOP2808071', 'OMOP2809655', 'OMOP3101286', 'OMOP3105391', 'OMOP322480', 'OMOP408540', 'OMOP4698404', 'OMOP4703825', 'OMOP4730789', 'OMOP4754844', 'OMOP4822787', 'OMOP4826749', 'OMOP4828854', 'OMOP4828897', 'OMOP4829009', 'OMOP4867304', 'OMOP4967660', 'OMOP4977988', 'OMOP4978074', 'OMOP4978077', 'OMOP4978081', 'OMOP4978101', 'OMOP4978102', 'OMOP4978127', 'OMOP4978133', 'OMOP4978139', 'OMOP4978145', 'OMOP4978180', 'OMOP4978184', 'OMOP4978185', 'OMOP4978186', 'OMOP4978188', 'OMOP4978189', 'OMOP4978190', 'OMOP4978579', 'OMOP4978935', 'OMOP4979472', 'OMOP4980230', 'OMOP4980553', 'OMOP4985897', 'OMOP4993739', 'OMOP4996285', 'OMOP4996291', 'OMOP5032180', 'OMOP5032296', 'OMOP5032356', 'OMOP5032474', 'OMOP5032566', 'OMOP5040668', 'OMOP5040759', 'OMOP5040765', 'OMOP5040814', 'OMOP5040869', 'OMOP5122369', 'OMOP5122810', 'OMOP5144092', 'OMOP5147132', 'OMOP5151610', 'OMOP5153222', 'OMOP5154204', 'OMOP5154878', 'OMOP5154881', 'OMOP5214681', 'OMOP5215805', 'OMOP5561075', 'OMOP5561084', 'OMOP5561110', 'OMOP5561136', 'OMOP5561154', 'OMOP5561217', 'OMOP5561227', 'OMOP5561228', 'OMOP5561229', 'OMOP5561264', 'OMOP5561268', 'OMOP5561278', 'OMOP5561279', 'OMOP5561280', 'OMOP5561281', 'OMOP5561299', 'OMOP5561375', 'OMOP5561381', 'OMOP5561631', 'OMOP5561662', 'OMOP5561738', 'OMOP5561839', 'OMOP5561972', 'OMOP5563082', 'OMOP5564095', 'OMOP5564613', 'OMOP5577089', 'OMOP5577095', 'OMOP5582542', 'OMOP5583316', 'OMOP799479', 'OMOP799488', 'OMOP799514', 'OMOP799519', 'OMOP995861')


UNION
----- Add Maps to and Concept replaced by simultaneously in  MANUALLY CURATED CONCEPTS

select DISTINCT
       t1.source_code :: TEXT,
       t1.target_concept_code :: TEXT,
        t1.source_vocabulary_id as vocabulary_id_1,
        t1.target_vocabulary_id as vocabulary_id_2,
       t1.relationship_id as realtionship_id,
       TO_DATE(CURRENT_DATE::TEXT, 'YYYY-MM-DD') as valid_start_date,
       TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date,
        NULL as invalid_reason
from dev_rxnorm.rxn_rxe_duplicates_manual t1
);

