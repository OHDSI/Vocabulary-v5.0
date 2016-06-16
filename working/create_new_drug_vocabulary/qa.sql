-- each marketed product must represent only one sub-product
select cs.concept_code, count(crs.concept_code_2) from concept_stage cs JOIN concept_relationship_stage crs ON crs.CONCEPT_CODE_1=cs.concept_code and crs.RELATIONSHIP_ID ='Marketed form of' WHERE cs.concept_class_id like 'Marketed%' GROUP BY cs.concept_code HAVING count(crs.concept_code_2) > 1;

