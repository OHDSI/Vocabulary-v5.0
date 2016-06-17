-- each marketed product must represent exactly one sub-product
select cs.concept_code, count(distinct crs.rowid) from concept_stage cs LEFT JOIN concept_relationship_stage crs ON crs.CONCEPT_CODE_1=cs.concept_code and crs.RELATIONSHIP_ID ='Marketed form of' WHERE cs.concept_class_id like 'Marketed%' GROUP BY cs.concept_code HAVING count(distinct crs.rowid) != 1;


-- marketed products must have only the following relationships
select crs.concept_code_1, crs.relationship_id, crs.CONCEPT_CODE_2 from concept_stage cs JOIN concept_relationship_stage crs ON crs.CONCEPT_CODE_1=cs.concept_code AND crs.VOCABULARY_ID_1=cs.VOCABULARY_ID WHERE cs.concept_class_id like 'Marketed%' AND crs.RELATIONSHIP_ID not in ('Marketed form of', 'Has Supplier', 'Maps to');

-- should we allow two-way `Maps to` ?


select * from drug_concept_stage dcs left join concept_stage ecs ON dcs.concept_code = ecs.concept_code WHERE ecs.rowid is null and dcs.concept_class_id != 'Unit';

-- (AMIS)

select st.* from source_table st left join drug_concept_stage dcs ON dcs.concept_code = st.enr WHERE dcs.rowid is null and st.domain_id = 'Drug';



-- marketed packs should be there (AMIS)
select crs.CONCEPT_CODE_2 from concept_stage cs JOIN concept_relationship_stage crs ON crs.CONCEPT_CODE_1=cs.concept_code and crs.RELATIONSHIP_ID ='Marketed form of' 
JOIN concept_stage cs2 ON cs2.concept_code=crs.concept_code_2 WHERE cs2.concept_class_id LIKE '%Pack%';
