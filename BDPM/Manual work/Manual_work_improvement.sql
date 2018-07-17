--INGREDIENTS
select count(rtc.concept_code) from AUT_INGR_ALL_MAPPED rtc
join concept c on c.concept_id = rtc.concept_id_2 and c.invalid_reason is null and c.concept_class_id ='Ingredient' and c.standard_concept is null
join concept_relationship cr on cr.concept_id_1=rtc.concept_id_2 and relationship_id='Form of'  and cr.invalid_reason is null 
join concept c2 on cr.concept_id_2=c2.concept_id and c2.invalid_reason is null and c2.standard_concept is not null;
;
MERGE
INTO    AUT_INGR_ALL_MAPPED a
USING   (
select distinct rtc.concept_name_2 as wrong_name,c2.concept_id,c2.concept_name from AUT_INGR_ALL_MAPPED rtc
join concept c on c.concept_id = rtc.concept_id_2 and c.invalid_reason is null and c.concept_class_id ='Ingredient' and c.standard_concept is null
join concept_relationship cr on cr.concept_id_1=rtc.concept_id_2 and relationship_id='Form of'  and cr.invalid_reason is null 
join concept c2 on cr.concept_id_2=c2.concept_id and c2.invalid_reason is null and c2.standard_concept is not null) d ON (d.wrong_name=a.concept_name_2)
WHEN MATCHED THEN UPDATE
    SET a.concept_id_2=d.concept_id
;

--BN
select distinct * from AUT_FORM_ALL_MAPPED a
join concept b on b.concept_id = a.concept_id_2 and invalid_reason='U'
--join concept_relationship d on d.concept_id_2=a.concept_id_2
--join concept e on e.concept_id = d.concept_id_1
--and relationship_id='Concept replaced by';
;

MERGE
INTO    AUT_BRAND_ALL_MAPPED a
USING   (
select distinct d.concept_id_2,a.concept_name_2 as wrong_name from AUT_BRAND_ALL_MAPPED a
join concept b on b.concept_id = a.concept_id_2 and invalid_reason is not null and vocabulary_id !='ATC'
join concept_relationship d on d.concept_id_1=a.concept_id_2
and relationship_id='Concept replaced by') d ON (d.wrong_name=a.concept_name_2)
WHEN MATCHED THEN UPDATE
    SET a.concept_id_2=d.concept_id_2
;