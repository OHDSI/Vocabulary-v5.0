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



select  count(*) from internal_relationship_stage irs left join drug_concept_stage dcs ON dcs.concept_code=irs.CONCEPT_CODE_1  WHERE dcs.concept_code IS NULL;

select * from  internal_relationship_stage irs LEFT JOIN drug_concept_stage dcs ON dcs.CONCEPT_CODE=irs.concept_code_1 WHERE dcs.CONCEPT_CODE IS NULL;
select * from  internal_relationship_stage irs LEFT JOIN drug_concept_stage dcs ON dcs.CONCEPT_CODE=irs.concept_code_2 WHERE dcs.CONCEPT_CODE IS NULL;

select * from drug_concept_stage dcs 
LEFT JOIN internal_relationship_stage irs1 ON dcs.CONCEPT_CODE=irs1.concept_code_1 
LEFT JOIN internal_relationship_stage irs2 ON dcs.CONCEPT_CODE=irs2.concept_code_2 WHERE irs1.CONCEPT_CODE_1 IS NULL AND irs2.CONCEPT_CODE_2 IS NULL and dcs.CONCEPT_CLASS_ID != 'Unit';


select concept_code,error_type from (

--Marketed products
select cs.concept_code,'Marketed product represents more than one sub-product' as error_type 
from concept_stage cs 
LEFT JOIN concept_relationship_stage crs ON crs.CONCEPT_CODE_1=cs.concept_code and crs.RELATIONSHIP_ID ='Marketed form of' 
WHERE cs.concept_class_id like 'Marketed%' GROUP BY cs.concept_code HAVING count(distinct crs.rowid) != 1

union
-- XXX should we really allow Maps to?
select concept_code_1 as concept_Code , 'Marketed products have relationships other than Marketed form of,Has Supplier,Maps to'  from (
select crs.concept_code_1, crs.relationship_id from concept_stage cs 
JOIN concept_relationship_stage crs ON crs.CONCEPT_CODE_1=cs.concept_code 
AND crs.VOCABULARY_ID_1=cs.VOCABULARY_ID WHERE cs.concept_class_id like 'Marketed%' 
AND crs.RELATIONSHIP_ID not in ('Marketed form of', 'Has Supplier', 'Maps to'))

union

select concept_Code,'Duplicates in existing_concept_stage' 
from existing_concept_stage group by concept_Code having count(1)>1

union

select exs.concept_code,'Compete_concept_stage dont have concepts which are present in existing_Concept_stage'
from existing_Concept_stage exs 
LEFT JOIN complete_concept_stage ccs ON ccs.i_combo_code=exs.i_Combo_code AND ccs.DENOMINATOR_VALUE=exs.DENOMINATOR_VALUE
AND ccs.D_COMBO_CODE=exs.D_COMBO_CODE AND ccs.dose_form_code=exs.dose_form_code AND exs.brand_Code=ccs.brand_code AND ccs.box_size=exs.box_size and ccs.mf_code=exs.mf_Code
WHERE ccs.concept_code IS NULL

union

select concept_code,'Concepts from concept_relationship_stage missing in concept_stage' from 
concept_relationship_stage crs 
LEFT JOIN concept_stage cs ON cs.concept_code=crs.concept_code_1
WHERE cs.concept_code is null
AND crs.vocabulary_id_1=cs.vocabulary_id

union
--there are only 45 such a concepts in RxNorm,should be bug
/*select * from 
concept_relationship crs 
RIGHT JOIN concept cs ON cs.concept_id=crs.concept_id_1
RIGHT JOIN concept cs2 ON crs.concept_id_2=cs2.concept_id
WHERE crs.concept_id_1 IS NULL AND crs.concept_id_2 IS NULL and cs2.vocabulary_id='RxNorm' and cs2.invalid_reason is null
*/
select cs.concept_code, 'Concepts from concept_stage do not have any relationship' from 
concept_stage cs LEFT JOIN concept_relationship_stage crs ON cs.concept_code=crs.concept_code_1 OR cs.concept_code=crs.concept_code_2 WHERE crs.CONCEPT_CODE_1 IS NULL

union
--Check for duplicates, different standard_concept might be a problem
select concept_code,'Duplicates in concept_stage'
from concept_stage GROUP BY concept_Code HAVING COUNT (1)>1

union

--Check if the name in complete_concept_stage is correct
select cs.concept_Code,'Wrong Brand Name in concept_stage' from
concept_stage cs  LEFT JOIN xxx_replace x ON x.omop_code=cs.concept_code
LEFT JOIN complete_concept_stage ccs on ccs.concept_code=x.xxx_code
LEFT JOIN complete_concept_stage ccs2 on ccs2.concept_code=cs.concept_code
LEFT JOIN drug_concept_stage dcs ON coalesce(ccs.brand_code,ccs2.brand_code)=dcs.concept_code
--LEFT JOIN drug_concept_stage dcs ON ccs2.brand_code=dcs.concept_code
WHERE (regexp_substr(cs.concept_name,'\[.*\]',1,2))!='['||dcs.concept_name||']' AND cs.concept_class_id like '%Branded%'

union

--relationship problems in concept_relationship_stage
select concept_code, 'Deprecated concepts dont have necessary relationships'
from concept_stage
WHERE NOT EXISTS (select * from concept_stage c JOIN concept_relationship_stage cr ON cr.concept_code_1=c.concept_code
WHERE c.invalid_reason='D' and relationship_id in ('Maps to','Replaced by')) 
AND invalid_reason='D'

union

--check if relationship 'Has standard brand' exsists only to brand names
select concept_code_1,'Has standard brand refers not to brand name'
from concept_relationship_stage crs JOIN devv5.concept c on concept_code_2=concept_code
WHERE relationship_id='Has standard brand' AND c.concept_class_id!='Brand Name' AND c.vocabulary_id='RxNorm'

union
--check if relationship 'Has standard form' exsists only to dose form;
select concept_code_1,'Has standard form refers not to dose form'
from concept_relationship_stage crs JOIN devv5.concept c on concept_code_2=concept_code
WHERE relationship_id='Has standard form' AND c.concept_class_id!='Dose Form' AND c.vocabulary_id='RxNorm'

union

--check if relationship 'Has standard ing' exsists only to ingredient
select concept_code_1,'Has standard ing refers not to ingredient'
from concept_relationship_stage crs JOIN devv5.concept c on concept_code_2=concept_code
WHERE relationship_id='Has standard ing' AND c.concept_class_id!='Ingredient' AND c.vocabulary_id='RxNorm'

union

select distinct concept_code_1, 'Has tradename refers to wrong concept_class' 
from concept_relationship_stage crs 
LEFT JOIN concept_stage cs ON concept_code_2=cs.concept_code AND crs.vocabulary_id_2 = cs.vocabulary_id
LEFT JOIN concept_stage cs2 ON concept_code_1=cs2.concept_code AND crs.vocabulary_id_1 = cs2.vocabulary_id
WHERE relationship_id='Has tradename' AND (cs.concept_class_id not like '%Branded%'
OR cs2.concept_class_id not like '%Clinical%')

union

--Should be only Component to Drug relationship
select distinct concept_code_1, 'Constitutes refers to wrong concept_class'
from concept_relationship_stage crs 
LEFT JOIN concept_stage cs ON concept_code_2=cs.concept_code AND crs.vocabulary_id_2 = cs.vocabulary_id
LEFT JOIN concept_stage cs2 ON concept_code_1=cs2.concept_code AND crs.vocabulary_id_1 = cs2.vocabulary_id
WHERE relationship_id='Constitutes' AND (cs.concept_class_id not like '%Drug%'
OR cs2.concept_class_id not like '%Comp%')

union

--There should be no standard deprecated and updated concepts
select distinct c.concept_code, 'Wrong standard_concept' 
from concept_stage c JOIN concept_relationship_stage cr ON cr.concept_code_1=c.concept_code 
WHERE c.standard_concept='S' and (c.invalid_reason='U' or c.invalid_reason='D')
union
select distinct c.concept_code, 'Wrong standard_concept'
from concept_stage c JOIN concept_relationship_stage cr ON cr.concept_code_2=c.concept_code 
WHERE c.standard_concept='S' and (c.invalid_reason='U' or c.invalid_reason='D')

union

--Improper valid_end_date
select concept_code, 'Improper valid_end_date' from concept_stage where concept_code not in (
select concept_code  from concept_stage
where  valid_end_date <=SYSDATE or valid_end_date = to_date ('2099-12-31', 'YYYY-MM-DD') )
union
--Improper valid_start_date
select concept_code, 'Improper valid_start_date' from concept_stage where valid_start_date > SYSDATE

);




-- Strange thing! May be ignored, but we should understand these cases!
select distinct RELATIONSHIP_ID from concept_relationship_stage where vocabulary_id_1='RxNorm' and vocabulary_id_2 != 'RxNorm';



/*--Was looking for difference in count of ingredients in the name and in table 'q_ing_count' which is used in matching of vocabulary drugs and rxnorm.
Got confused,as tne number of ingr in names are correct and cnt is not.
select cn.concept_code,'Wrong number of ingredient' from concept_stage cn LEFT JOIN xxx_replace x ON omop_code=concept_code
LEFT JOIN q_ing_count q ON xxx_code=q.dcode
LEFT JOIN q_ing_count qi ON concept_code=qi.dcode
WHERE regexp_count(cn.concept_name,'(\s)/(\s)')!=q.cnt-1
AND concept_class_id not like '%Pack%';

As example this can be used
select * from concept_stage cn LEFT JOIN xxx_replace x ON omop_code=concept_code
LEFT JOIN q_ing_count q ON xxx_code=q.dcode
LEFT JOIN q_ing_count qi ON concept_code=qi.dcode
WHERE regexp_count(cn.concept_name,'(\s)/(\s)')!=q.cnt-1
AND concept_class_id not like '%Pack%'  AND qi.dcode is null
and concept_code ='OMOP1123036';
select * from drug_strength_stage where drug_concept_code ='OMOP1123036';

-- marketed packs should be there (AMIS)
--Do not know how to put it in qa.
select crs.CONCEPT_CODE_2 from concept_stage cs JOIN concept_relationship_stage crs 
ON crs.CONCEPT_CODE_1=cs.concept_code and crs.RELATIONSHIP_ID ='Marketed form of' 
JOIN concept_stage cs2 ON cs2.concept_code=crs.concept_code_2 WHERE cs2.concept_class_id 
LIKE '%Pack%';

--should there be RxNorm in vocabulary_id_1?
select distinct * from concept_relationship_stage where relationship_id='Available as box' and vocabulary_id='RxNorm'

--do not understand why there are XXX codes as concept_code_1 as Christian script takes this codes from pack_content.
Actually want to check wether relashionship 'Contains' is correct.
select distinct * from concept_relationship_stage crs 
JOIN drug_concept_stage dcs ON concept_code_2=concept_code
where relationship_id='Contains'

--not sure if its right
select *  from drug_concept_stage where valid_start_date is null

;*/