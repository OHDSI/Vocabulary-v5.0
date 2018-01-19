/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
* 
* Authors: Timur Vakhitov, Anna Ostropolets, Christian Reich
* Date: 2016
**************************************************************************/

--1 Update latest_update field to new date 
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'RxNorm Extension',
                                          pVocabularyDate        => TRUNC(SYSDATE),
                                          pVocabularyVersion     => 'RxNorm Extension '||SYSDATE,
                                          pVocabularyDevSchema   => 'DEV_RXE');									  
END;
COMMIT;

--2 Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3 Load full list of RxNorm Extension concepts
INSERT /*+ APPEND */ INTO  CONCEPT_STAGE (concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT concept_name,
          domain_id,
          vocabulary_id,
          concept_class_id,
          standard_concept,
          concept_code,
          valid_start_date,
          valid_end_date,
          invalid_reason
     FROM concept
    WHERE vocabulary_id = 'RxNorm Extension';			   
COMMIT;


--4 Load full list of RxNorm Extension relationships
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT c1.concept_code,
          c2.concept_code,
          c1.vocabulary_id,
          c2.vocabulary_id,
          r.relationship_id,
          r.valid_start_date,
          r.valid_end_date,
          r.invalid_reason
     FROM concept c1, concept c2, concept_relationship r
    WHERE c1.concept_id = r.concept_id_1 AND c2.concept_id = r.concept_id_2 AND 'RxNorm Extension' IN (c1.vocabulary_id, c2.vocabulary_id);
COMMIT;


--5 Load full list of RxNorm Extension drug strength
INSERT /*+ APPEND */
      INTO  drug_strength_stage (drug_concept_code,
                                 vocabulary_id_1,
                                 ingredient_concept_code,
                                 vocabulary_id_2,
                                 amount_value,
                                 amount_unit_concept_id,
                                 numerator_value,
                                 numerator_unit_concept_id,
                                 denominator_value,
                                 denominator_unit_concept_id,
                                 valid_start_date,
                                 valid_end_date,
                                 invalid_reason)
   SELECT c.concept_code,
          c.vocabulary_id,
          c2.concept_code,
          c2.vocabulary_id,
          amount_value,
          amount_unit_concept_id,
          numerator_value,
          numerator_unit_concept_id,
          denominator_value,
          denominator_unit_concept_id,
          ds.valid_start_date,
          ds.valid_end_date,
          ds.invalid_reason
     FROM concept c
          JOIN drug_strength ds ON ds.DRUG_CONCEPT_ID = c.CONCEPT_ID
          JOIN concept c2 ON ds.INGREDIENT_CONCEPT_ID = c2.CONCEPT_ID
    WHERE c.vocabulary_id IN ('RxNorm', 'RxNorm Extension');
COMMIT;

--6 Load full list of RxNorm Extension pack content
INSERT /*+ APPEND */
      INTO  pack_content_stage (pack_concept_code,
                                pack_vocabulary_id,
                                drug_concept_code,
                                drug_vocabulary_id,
                                amount,
                                box_size)
   SELECT c.concept_code,
          c.vocabulary_id,
          c2.concept_code,
          c2.vocabulary_id,
          amount,
          box_size
     FROM pack_content pc
          JOIN concept c ON pc.PACK_CONCEPT_ID = c.CONCEPT_ID
          JOIN concept c2 ON pc.DRUG_CONCEPT_ID = c2.CONCEPT_ID;
COMMIT;

--7 name and dosage udpates
--fix names and dosage for rxe-concepts with various denominator_unit_concept_id
update concept_stage set concept_name='Polymyxin B 10 000 MG/ML / Trimethoprim 1 MG/ML [Polytrim]'
where vocabulary_id='RxNorm Extension' 
and concept_code='OMOP420658' 
and concept_name='Polymyxin B 10 IU/MG / Trimethoprim 1 MG/ML [Polytrim]';

update concept_stage set concept_name='Polymyxin B 10 000 MG/ML / Trimethoprim 1 MG/ML Ophthalmic Solution'
where vocabulary_id='RxNorm Extension' 
and concept_code='OMOP420659' 
and concept_name='Polymyxin B 10 IU/MG / Trimethoprim 1 MG/ML Ophthalmic Solution';

update concept_stage set concept_name='Polymyxin B 10 000 MG/ML / Trimethoprim 1 MG/ML Ophthalmic Solution [Polytrim]'
where vocabulary_id='RxNorm Extension' 
and concept_code='OMOP420660' 
and concept_name='Polymyxin B 10 IU/MG / Trimethoprim 1 MG/ML Ophthalmic Solution [Polytrim]';

update concept_stage set concept_name='Polymyxin B 10 000 MG/ML / Trimethoprim 1 MG/ML Ophthalmic Solution [Polytrim] by PLIVA'
where vocabulary_id='RxNorm Extension' 
and concept_code='OMOP420661' 
and concept_name='Polymyxin B 10 IU/MG / Trimethoprim 1 MG/ML Ophthalmic Solution [Polytrim] by PLIVA';

update drug_strength_stage set numerator_value=numerator_value*1000, denominator_unit_concept_id=8587
where vocabulary_id_1='RxNorm Extension' and drug_concept_code in ('OMOP420658','OMOP420659','OMOP420660','OMOP420661')
and denominator_unit_concept_id=8576;

commit;

--8
--normalizing
merge into concept_stage cs
using (
    select distinct cs.concept_code, l.new_name
    from drug_strength_stage ds, concept_stage cs,
    lateral (
        select listagg(
        case when ld='/HR' 
            then 
                rtrim(to_char(splitted_name/1000,'fm999999999990d99999999999999999999'), '.,') 
            else 
                case when splitted_name='/HR' 
                    then 
                        'MG/HR' 
                    else 
                        splitted_name
                    end
        end,' ') WITHIN GROUP (order by lv) new_name from (
            select splitted_name, lead(splitted_name) over (order by lv) ld, lv from (
            select regexp_substr(cs.concept_name,'[^ ]+', 1, level) splitted_name, level lv from dual 
            connect by regexp_substr(cs.concept_name, '[^ ]+', 1, level) is not null
            )
        )
    ) l 
    where ds.numerator_unit_concept_id=9655
    and ds.drug_concept_code=cs.concept_code
    and ds.vocabulary_id_1=cs.vocabulary_id
    and cs.vocabulary_id='RxNorm Extension'
	union all
    select distinct cs.concept_code, l.new_name
    from drug_strength_stage ds, concept_stage cs,
    lateral (
        select listagg(
        case when regexp_substr(splitted_name,'[[:digit:]]+') is not null
            then
                rtrim(to_char(splitted_name/1000,'fm999999999990d99999999999999999999'), '.,')||' MG'
            else
              splitted_name
        end,' ') WITHIN GROUP (order by lv) new_name from (
            select regexp_substr(cs.concept_name,'[^ ]+', 1, level) splitted_name, level lv from dual
            connect by regexp_substr(cs.concept_name, '[^ ]+', 1, level) is not null
        )
    ) l
    where ds.amount_unit_concept_id=9655
    and ds.drug_concept_code=cs.concept_code
    and ds.vocabulary_id_1=cs.vocabulary_id
    and cs.vocabulary_id='RxNorm Extension'
    union all
    select distinct cs.concept_code, l.new_name
    from drug_strength_stage ds, concept_stage cs,
    lateral (
        select listagg(
        case when splitted_name='0.9'
            then
                splitted_name*1000000||' UNT'
            else
              splitted_name
        end,' ') WITHIN GROUP (order by lv) new_name from (
            select regexp_substr(cs.concept_name,'[^ ]+', 1, level) splitted_name, level lv from dual
            connect by regexp_substr(cs.concept_name, '[^ ]+', 1, level) is not null
        )
    ) l
    where ds.amount_unit_concept_id=44777647
    and ds.drug_concept_code=cs.concept_code
    and ds.vocabulary_id_1=cs.vocabulary_id
    and cs.vocabulary_id='RxNorm Extension'
	union all
	select distinct cs.concept_code, replace(replace(replace(cs.concept_name,' IU ',' UNT '),'IU/','UNT/'),'/IU','/UNT') new_name
	from drug_strength_stage ds, concept_stage cs
	where (ds.numerator_unit_concept_id=8718 or ds.denominator_unit_concept_id=8718)
	and ds.drug_concept_code=cs.concept_code
	and ds.vocabulary_id_1=cs.vocabulary_id
	and cs.vocabulary_id='RxNorm Extension'	
	union all --two merges for amount_unit_concept_id=8718 (one for IU and one for MIU)
	select distinct cs.concept_code, trim(regexp_replace(cs.concept_name,' IU | IU$',' UNT ')) new_name
	from drug_strength_stage ds, concept_stage cs
	where ds.amount_unit_concept_id=8718
	and ds.drug_concept_code=cs.concept_code
	and ds.vocabulary_id_1=cs.vocabulary_id
	and cs.vocabulary_id='RxNorm Extension'	
	and cs.concept_name like '% IU%'
	union all
	select distinct cs.concept_code, l.new_name
	from drug_strength_stage ds, concept_stage cs,
	lateral (
		select listagg(
		case when ld='MIU' 
			then 
				to_char(splitted_name*1e6)
			else 
				splitted_name
		end,' ') WITHIN GROUP (order by lv) new_name from (
			select splitted_name, lead(splitted_name) over (order by lv) ld, lv from (
			select regexp_substr(cs.concept_name,'[^ ]+', 1, level) splitted_name, level lv from dual 
			connect by regexp_substr(cs.concept_name, '[^ ]+', 1, level) is not null
			)
		)
	) l
	where ds.amount_unit_concept_id=8718
	and ds.drug_concept_code=cs.concept_code
	and ds.vocabulary_id_1=cs.vocabulary_id
	and cs.vocabulary_id='RxNorm Extension'
	and cs.concept_name like '% MIU%'
	union all
	--change the drug strength for homeopathy (p1)
	select distinct cs.concept_code, replace(cs.concept_name,'/'||upper(c.concept_code),'') new_name
	from drug_strength_stage ds, concept_stage cs, concept c
	where ds.numerator_unit_concept_id in (9324,9325)
	and ds.drug_concept_code=cs.concept_code
	and ds.vocabulary_id_1=cs.vocabulary_id
	and cs.vocabulary_id='RxNorm Extension'
	and c.concept_id=ds.denominator_unit_concept_id
	
) l on (cs.concept_code=l.concept_code and cs.vocabulary_id='RxNorm Extension')
when matched then 
	update set cs.concept_name=case when length(l.new_name)>255 then substr(substr(l.new_name, 1, 255),1,length(substr(l.new_name, 1, 255))-3)||'...' else l.new_name end 
	where cs.concept_name<>case when length(l.new_name)>255 then substr(substr(l.new_name, 1, 255),1,length(substr(l.new_name, 1, 255))-3)||'...' else l.new_name end;

update drug_strength_stage
set NUMERATOR_UNIT_CONCEPT_ID=8576,NUMERATOR_VALUE=NUMERATOR_VALUE/1000 -- 'mg'
where NUMERATOR_UNIT_CONCEPT_ID=9655 -- 'ug'
and vocabulary_id_1='RxNorm Extension';

update drug_strength_stage
set AMOUNT_UNIT_CONCEPT_ID=8576,AMOUNT_VALUE=AMOUNT_VALUE/1000 -- 'mg'
where AMOUNT_UNIT_CONCEPT_ID=9655 -- 'ug'
and vocabulary_id_1='RxNorm Extension';

update drug_strength_stage
set AMOUNT_UNIT_CONCEPT_ID=8510,AMOUNT_VALUE=AMOUNT_VALUE*1000000 -- 'U'
where AMOUNT_UNIT_CONCEPT_ID=44777647 -- 'ukat'
and vocabulary_id_1='RxNorm Extension';

/* temporary disabled
--deprecate concepts with iU
update concept_stage set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
WHERE concept_code in (
	select drug_concept_code from drug_strength_stage
	where (NUMERATOR_UNIT_CONCEPT_ID=8718 or DENOMINATOR_UNIT_CONCEPT_ID=8718 or AMOUNT_UNIT_CONCEPT_ID=8718) -- 'iU'
	and vocabulary_id_1='RxNorm Extension'
);
*/

update drug_strength_stage
set NUMERATOR_UNIT_CONCEPT_ID=8510
where NUMERATOR_UNIT_CONCEPT_ID=8718 -- 'iU'
and vocabulary_id_1='RxNorm Extension';

update drug_strength_stage
set DENOMINATOR_UNIT_CONCEPT_ID=8510
where DENOMINATOR_UNIT_CONCEPT_ID=8718 -- 'iU'
and vocabulary_id_1='RxNorm Extension';

update drug_strength_stage
set AMOUNT_UNIT_CONCEPT_ID=8510 -- 'U'
where AMOUNT_UNIT_CONCEPT_ID=8718 -- 'iU'
and vocabulary_id_1='RxNorm Extension';

--deprecate transdermal patches with cm and mm as unit in order to rebuild them
update concept_stage set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
WHERE concept_code in (
	select drug_concept_code from drug_strength_stage
	where  denominator_unit_concept_id in (8582,8588)
	and vocabulary_id_1='RxNorm Extension'
)
and invalid_reason is null;

--change the drug strength for homeopathy (p2)
update drug_strength_stage ds set 
    ds.amount_value=ds.numerator_value, 
    ds.amount_unit_concept_id=ds.numerator_unit_concept_id,
    ds.numerator_value=null,
    ds.numerator_unit_concept_id=null,
    ds.denominator_value=null,
    ds.denominator_unit_concept_id=null
where ds.numerator_unit_concept_id in (9324,9325)
and ds.vocabulary_id_1='RxNorm Extension';
commit;

--direct manual update (names too long)
update concept_stage set concept_name='Ascorbic Acid 25 MG/ML / Biotin 0.0138 MG/ML / Cholecalciferol 44 UNT/ML / Folic Acid 0.0828 MG/ML / Niacinamide 9.2 MG/ML / Pantothenic Acid 3.45 MG/ML / Riboflavin 0.828 MG/ML / Thiamine 0.702 MG/ML / ... Prefilled Syringe Box of 1' where concept_code='OMOP441099' and vocabulary_id='RxNorm Extension';
update concept_stage set concept_name='Bordetella pertussis 0.05 MG/ML / acellular pertussis vaccine, inactivated 0.05 MG/ML / diphtheria toxoid vaccine, inactivated 60 UNT/ML / ... Injectable Suspension [TETRAVAC-ACELLULAIRE] Box of 10' where concept_code='OMOP445896' and vocabulary_id='RxNorm Extension';
commit;

--9
--create the table with rxe's wrong replacements (concept_code_1 has multiply 'Concept replaced by')
create table wrong_rxe_replacements nologging as
select concept_code, true_concept from (
    select concept_code, count(*) over (partition by lower(concept_name), concept_class_id) cnt, 
    first_value(concept_code) over (partition by lower(concept_name), concept_class_id order by invalid_reason nulls first, concept_code) true_concept
    from concept_stage
    where concept_name not like '%...%'
    and nvl(invalid_reason,'x')<>'D'
    and vocabulary_id='RxNorm Extension'
) where cnt>1 and concept_code<>true_concept;

--deprecate old replacements
update concept_relationship_stage crs set crs.invalid_reason='D', 
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension')
where concept_code_1 in (select concepts from wrong_rxe_replacements unpivot (concepts for concepts_codes in (concept_code,true_concept)))
and concept_code_2 in (select concepts from wrong_rxe_replacements unpivot (concepts for concepts_codes in (concept_code,true_concept)))
and crs.vocabulary_id_1='RxNorm Extension'
and crs.vocabulary_id_2='RxNorm Extension'
and crs.relationship_id in ('Concept replaced by','Concept replaces')
and crs.invalid_reason is null;

--build new ones or update existing
merge into concept_relationship_stage crs
using (
    select concept_code,true_concept, relationship_id from
    (select concept_code,true_concept, 'Concept replaced by' as relationship_id,'Concept replaces' as reverse_relationship_id from wrong_rxe_replacements)
    unpivot ((concept_code,true_concept, relationship_id) for relationships in ((concept_code,true_concept,relationship_id),(true_concept, concept_code, reverse_relationship_id)))
) i
on (
    i.concept_code=crs.concept_code_1
    and crs.vocabulary_id_1='RxNorm Extension'
    and i.true_concept=crs.concept_code_2
    and crs.vocabulary_id_2='RxNorm Extension'
    and crs.relationship_id=i.relationship_id
)
when matched then 
    update set crs.invalid_reason=null, crs.valid_end_date=to_date ('20991231', 'YYYYMMDD') where crs.invalid_reason is not null
when not matched then insert
(
    crs.concept_code_1,
    crs.vocabulary_id_1,
    crs.concept_code_2,
    crs.vocabulary_id_2,
    crs.relationship_id,
    crs.valid_start_date,
    crs.valid_end_date,
    crs.invalid_reason    
)
values
(
    i.concept_code,
    'RxNorm Extension',    
    i.true_concept,
    'RxNorm Extension',
    i.relationship_id,
    (SELECT latest_update FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension'),
    to_date ('20991231', 'YYYYMMDD'),
    null  
);

--update invalid_reason and standard_concept in the concept
update concept_stage set invalid_reason=null, valid_end_date=to_date ('20991231', 'YYYYMMDD'), standard_concept='S' 
where concept_code in (select true_concept from wrong_rxe_replacements)
and vocabulary_id='RxNorm Extension'
and invalid_reason is not null;

update concept_stage set invalid_reason='U', 
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension'), 
standard_concept=null 
where concept_code in (select concept_code from wrong_rxe_replacements)
and vocabulary_id='RxNorm Extension'
and nvl(invalid_reason,'x')<>'U';
commit;

--after rxe name's update we have duplicates with rx. fix it
--build new ones replacements or update existing 
merge into concept_relationship_stage crs
using (
	select cs.concept_code rxe_code, c.concept_code rx_code
	from concept_stage cs, concept c 
	where cs.vocabulary_id='RxNorm Extension'
	and cs.concept_name not like '%...%'
	and cs.invalid_reason is null
	and c.vocabulary_id='RxNorm'
	and c.invalid_reason is null
	and lower(cs.concept_name)=lower(c.concept_name)
	and cs.concept_class_id=c.concept_class_id
) i
on (
    i.rxe_code=crs.concept_code_1
    and crs.vocabulary_id_1='RxNorm Extension'
    and i.rx_code=crs.concept_code_2
    and crs.vocabulary_id_2='RxNorm'
    and crs.relationship_id='Concept replaced by'
)
when matched then 
    update set crs.invalid_reason=null, crs.valid_end_date=to_date ('20991231', 'YYYYMMDD') where crs.invalid_reason is not null
when not matched then insert
(
    crs.concept_code_1,
    crs.vocabulary_id_1,
    crs.concept_code_2,
    crs.vocabulary_id_2,
    crs.relationship_id,
    crs.valid_start_date,
    crs.valid_end_date,
    crs.invalid_reason    
)
values
(
    i.rxe_code,
    'RxNorm Extension',    
    i.rx_code,
    'RxNorm',
    'Concept replaced by',
    (SELECT latest_update FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension'),
    to_date ('20991231', 'YYYYMMDD'),
    null  
);

--set 'U'
update concept_stage set invalid_reason='U', 
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension'), 
standard_concept=null 
where concept_code in (
	select cs.concept_code
	from concept_stage cs, concept c 
	where cs.vocabulary_id='RxNorm Extension'
	and cs.concept_name not like '%...%'
	and cs.invalid_reason is null
	and c.vocabulary_id='RxNorm'
	and c.invalid_reason is null
	and lower(cs.concept_name)=lower(c.concept_name)
	and cs.concept_class_id=c.concept_class_id
)
and vocabulary_id='RxNorm Extension'
and invalid_reason is null;
commit;

--Working with new replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;

--Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;

--Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

--10 deprecate solid drugs with denominator
update concept_stage set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
WHERE concept_code in (
	select cs.concept_code from drug_strength_stage ds, concept_stage cs
	where ds.denominator_unit_concept_id is not null
	and ds.drug_concept_code=cs.concept_code
	and ds.vocabulary_id_1=cs.vocabulary_id
	and cs.vocabulary_id='RxNorm Extension'
	and (cs.concept_name like '%Tablet%' or cs.concept_name like '%Capsule%')
	and cs.invalid_reason is null
);
commit;

--11
--do a rounding amount_value, numerator_value and denominator_value
update drug_strength_stage set 
    amount_value=round(amount_value, 3-floor(log(10, amount_value))-1),
    numerator_value=round(numerator_value, 3-floor(log(10, numerator_value))-1),
    denominator_value=round(denominator_value, 3-floor(log(10, denominator_value))-1)
where amount_value<>round(amount_value, 3-floor(log(10, amount_value))-1)
or numerator_value<>round(numerator_value, 3-floor(log(10, numerator_value))-1)
or denominator_value<>round(denominator_value, 3-floor(log(10, denominator_value))-1)
and vocabulary_id_1='RxNorm Extension';
commit;

--12 
--wrong ancestor
update concept_stage set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
WHERE concept_code in (
	select an.concept_code from concept an
	join concept_ancestor a on a.ancestor_concept_id=an.concept_id and an.vocabulary_id='RxNorm Extension'
	join concept de on de.concept_id=a.descendant_concept_id and de.vocabulary_id='RxNorm'
)
and invalid_reason is null;
commit;

--13 
--impossible dosages
update concept_stage set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension')
where (concept_code,vocabulary_id) in (
	select drug_concept_code, vocabulary_id_1 from drug_strength_stage a 
	where (numerator_unit_concept_id=8554 and denominator_unit_concept_id is not null) 
	or amount_unit_concept_id=8554
	or ( numerator_unit_concept_id=8576 and denominator_unit_concept_id=8587 and numerator_value / denominator_value > 1000 )
	or (numerator_unit_concept_id=8576 and denominator_unit_concept_id=8576 and numerator_value / denominator_value > 1 )
	and vocabulary_id_1='RxNorm Extension'
)
and invalid_reason is null;
commit;

--14 
--wrong pack components
update concept_stage  set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension')
where (concept_code, vocabulary_id) in (
select pack_concept_code, pack_vocabulary_id  from pack_content_stage where pack_vocabulary_id='RxNorm Extension' group by drug_concept_code, drug_vocabulary_id, pack_concept_code, pack_vocabulary_id having count (*) > 1 )
and invalid_reason is null;
commit;

--15
--deprecate drugs that have different number of ingredients in ancestor and drug_strength
update concept_stage set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where (concept_code, vocabulary_id) in (
    with a as (
        select drug_concept_code, vocabulary_id_1, count(drug_concept_code) as cnt1 
        from drug_strength_stage
        where vocabulary_id_1='RxNorm Extension'
        group by drug_concept_code, vocabulary_id_1
    ),
    b as (
        select b2.concept_code as descendant_concept_code, b2.vocabulary_id as descendant_vocabulary_id, count(b2.concept_code) as cnt2 
        from concept_ancestor a 
        join concept b on ancestor_concept_id=b.concept_id and concept_class_id='Ingredient'
        join concept b2 on descendant_concept_id=b2.concept_id 
        where b2.concept_class_id not like '%Comp%'
        and b2.vocabulary_id='RxNorm Extension'
        group by b2.concept_code, b2.vocabulary_id
    )
    select a.drug_concept_code, a.vocabulary_id_1
    from a 
    join b on a.drug_concept_code=b.descendant_concept_code and a.vocabulary_id_1=b.descendant_vocabulary_id
    where cnt1<cnt2
)
and invalid_reason is null;
commit;

update concept_stage set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where (concept_code, vocabulary_id) in (
    with a as (
        select drug_concept_code, vocabulary_id_1, count(drug_concept_code) as cnt1 
        from drug_strength_stage
        where vocabulary_id_1='RxNorm Extension'
        group by drug_concept_code, vocabulary_id_1
    ),
    b as (
        select b2.concept_code as descendant_concept_code, b2.vocabulary_id as descendant_vocabulary_id, count(b2.concept_code) as cnt2  
        from concept_ancestor a 
        join concept b on ancestor_concept_id=b.concept_id and concept_class_id='Ingredient'
        join concept b2 on descendant_concept_id=b2.concept_id where b2.concept_class_id not like '%Comp%'
        and b2.vocabulary_id='RxNorm Extension'
        group by b2.concept_code, b2.vocabulary_id
    ),
    c as (
        select concept_code, vocabulary_id, regexp_count(concept_name,'\s/\s')+1 as cnt3 
        from concept
        where vocabulary_id='RxNorm Extension'
    )
    select a.drug_concept_code, a.vocabulary_id_1
    from a join b on a.drug_concept_code=b.descendant_concept_code and a.vocabulary_id_1=b.descendant_vocabulary_id
    join  c on c.concept_code=b.descendant_concept_code and c.vocabulary_id=b.descendant_vocabulary_id
    where cnt1>cnt2 and cnt3>cnt1
)
and invalid_reason is null;
commit;

--16
--deprecate drugs that have deprecated ingredients (all)
update concept_stage c set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where (concept_code, vocabulary_id) in (
    select dss.drug_concept_code, dss.vocabulary_id_1 from drug_strength_stage dss, concept_stage cs
    where dss.ingredient_concept_code=cs.concept_code
    and dss.vocabulary_id_2=cs.vocabulary_id
    and vocabulary_id_1='RxNorm Extension'
    group by dss.drug_concept_code, dss.vocabulary_id_1
    having count(dss.ingredient_concept_code)=sum(case when cs.invalid_reason='D' then 1 else 0 end)
)
and invalid_reason is null;
commit;

exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'concept_relationship_stage', cascade  => true);
exec DBMS_STATS.GATHER_TABLE_STATS (ownname => USER, tabname  => 'drug_strength_stage', cascade  => true);

--17
--deprecate drugs that link to each other and has different strength
update concept_relationship_stage crs set crs.invalid_reason='D', 
crs.valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension')
where crs.invalid_reason is null 
and (concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2) in (
    select concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2 from (
        select concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2 from (
            select distinct dss1.drug_concept_code as concept_code_1, dss1.vocabulary_id_1 as vocabulary_id_1, 
            dss2.drug_concept_code as concept_code_2, dss2.vocabulary_id_1 as vocabulary_id_2 
            from drug_strength_stage dss1, drug_strength_stage dss2
            where dss1.vocabulary_id_1 in ('RxNorm', 'RxNorm Extension')
            and dss2.vocabulary_id_1 in ('RxNorm', 'RxNorm Extension')
            and dss1.ingredient_concept_code=dss2.ingredient_concept_code
            and dss1.vocabulary_id_2=dss2.vocabulary_id_2
            and not (dss1.vocabulary_id_1='RxNorm' and dss2.vocabulary_id_1='RxNorm')
            and exists (
                select 1 from concept_relationship_stage crs
                where crs.concept_code_1=dss1.drug_concept_code 
                and crs.vocabulary_id_1=dss1.vocabulary_id_1
                and crs.concept_code_2=dss2.drug_concept_code 
                and crs.vocabulary_id_2=dss2.vocabulary_id_1
                and crs.invalid_reason is null
            )
            and (
                coalesce (dss1.amount_value, dss1.numerator_value / coalesce (dss1.denominator_value, 1)) / coalesce (dss2.amount_value, dss2.numerator_value / coalesce( dss2.denominator_value, 1)) >1.12
                or coalesce (dss1.amount_value, dss1.numerator_value / coalesce (dss1.denominator_value, 1)) / coalesce (dss2.amount_value, dss2.numerator_value / coalesce( dss2.denominator_value, 1)) < 0.9
            )
            and coalesce (dss1.amount_unit_concept_id, (dss1.numerator_unit_concept_id+dss1.denominator_unit_concept_id)) = coalesce (dss2.amount_unit_concept_id, (dss2.numerator_unit_concept_id+dss2.denominator_unit_concept_id))
        )
        --add a reverse
        unpivot ((concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2) 
		FOR relationships IN ((concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2),(concept_code_2,vocabulary_id_2,concept_code_1,vocabulary_id_1)))
    )
);
commit;

--18
--deprecate the drugs that have inaccurate dosage due to difference in ingredients subvarieties
--for ingredients with not null amount_value
update concept_stage c set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where (concept_code, vocabulary_id) in (
    select dss.drug_concept_code, dss.vocabulary_id_1 from (
        select ingredient_concept_code, dosage, flag, count(distinct flag) over (partition by ingredient_concept_code, dosage_group) cnt_flags, 
		first_value (dosage) over (partition by ingredient_concept_code, dosage_group order by length(regexp_replace(dosage,'[^1-9]')), dosage) true_dosage from (
            select rxe.ingredient_concept_code, rxe.dosage, rxe.dosage_group, nvl(rx.flag,rxe.flag) as flag from (
                select distinct ingredient_concept_code, dosage, dosage_group, 'bad' as flag 
                from (
                    select ingredient_concept_code, dosage, dosage_group, count(*) over(partition by ingredient_concept_code, dosage_group) as cnt_gr
                    from (
                        select ingredient_concept_code, dosage, sum(group_trigger) over (partition by ingredient_concept_code order by dosage)+1 dosage_group from (
                            select ingredient_concept_code, dosage, prev_dosage, abs(round((dosage-prev_dosage)*100/prev_dosage)) perc_dosage, 
                            case when abs(round((dosage-prev_dosage)*100/prev_dosage))<=5 then 0 else 1 end group_trigger from (
                                select 
                                ingredient_concept_code, dosage, lag(dosage,1,dosage) over (partition by ingredient_concept_code order by dosage) prev_dosage 
                                from (
                                    select distinct ingredient_concept_code, amount_value as dosage
                                    from drug_strength_stage  where vocabulary_id_1='RxNorm Extension' and  amount_value is not null             
                                )
                            ) 
                        )
                    )
                ) where cnt_gr > 1
            ) rxe,
            (
                select distinct ingredient_concept_code, amount_value as dosage, 'good' as flag 
                from drug_strength_stage  where vocabulary_id_1='RxNorm' and amount_value is not null
            ) rx
            where rxe.ingredient_concept_code=rx.ingredient_concept_code(+)
            and rxe.dosage=rx.dosage(+)
        )
    ) merged_rxe, drug_strength_stage dss 
    where (
        merged_rxe.flag='bad' and merged_rxe.cnt_flags=2 or
        merged_rxe.flag='bad' and merged_rxe.cnt_flags=1 and dosage<>true_dosage
    )
    and dss.ingredient_concept_code=merged_rxe.ingredient_concept_code
    and dss.amount_value=merged_rxe.dosage
    and dss.vocabulary_id_1='RxNorm Extension'
)
and invalid_reason is null;

--same, but for ingredients with null amount_value (instead, we use numerator_value or numerator_value/denominator_value)
update concept_stage c set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where (concept_code, vocabulary_id) in (
    select dss.drug_concept_code, dss.vocabulary_id_1 from (
        select ingredient_concept_code, dosage, flag, count(distinct flag) over (partition by ingredient_concept_code, dosage_group) cnt_flags,
		--min (dosage) over (partition by ingredient_concept_code, dosage_group) min_dosage from (
		first_value (dosage) over (partition by ingredient_concept_code, dosage_group order by length(regexp_replace(dosage,'[^1-9]')), dosage) true_dosage from (
            select rxe.ingredient_concept_code, rxe.dosage, rxe.dosage_group, nvl(rx.flag,rxe.flag) as flag from (
                select distinct ingredient_concept_code, dosage, dosage_group, 'bad' as flag 
                from (
                    select ingredient_concept_code, dosage, dosage_group, count(*) over(partition by ingredient_concept_code, dosage_group) as cnt_gr
                    from (
                        select ingredient_concept_code, dosage, sum(group_trigger) over (partition by ingredient_concept_code order by dosage)+1 dosage_group from (
                            select ingredient_concept_code, dosage, prev_dosage, abs(round((dosage-prev_dosage)*100/prev_dosage)) perc_dosage, 
                            case when abs(round((dosage-prev_dosage)*100/prev_dosage))<=5 then 0 else 1 end group_trigger from (
                                select 
                                ingredient_concept_code, dosage, lag(dosage,1,dosage) over (partition by ingredient_concept_code order by dosage) prev_dosage 
                                from (
                                    select distinct ingredient_concept_code, round(dosage, 3-floor(log(10, dosage))-1) as dosage   
                                    from ( 
                                        select ingredient_concept_code,
                                        case when amount_value is null and denominator_value is null then 
                                            numerator_value
                                        else 
                                            numerator_value/denominator_value
                                        end as dosage
                                        from drug_strength_stage  where vocabulary_id_1='RxNorm Extension' and amount_value is null
                                    )           
                                )
                            ) 
                        )
                    )
                ) where cnt_gr > 1
            ) rxe,
            (
                select distinct ingredient_concept_code, round(dosage, 3-floor(log(10, dosage))-1) as dosage, 'good' as flag from 
                ( 
                    select ingredient_concept_code,
                    case when amount_value is null and denominator_value is null then 
                        numerator_value
                    else 
                        numerator_value/denominator_value
                    end as dosage                
                    from drug_strength_stage  where vocabulary_id_1='RxNorm' and amount_value is null
                )
            ) rx
            where rxe.ingredient_concept_code=rx.ingredient_concept_code(+)
            and rxe.dosage=rx.dosage(+)
        )
    ) merged_rxe, drug_strength_stage dss 
    where (
        merged_rxe.flag='bad' and merged_rxe.cnt_flags=2 or
        merged_rxe.flag='bad' and merged_rxe.cnt_flags=1 and dosage<>true_dosage
    )
    and dss.ingredient_concept_code=merged_rxe.ingredient_concept_code
    and case when dss.amount_value is null and dss.denominator_value is null then 
        round(dss.numerator_value, 3-floor(log(10, dss.numerator_value))-1)
    else 
        round(dss.numerator_value/dss.denominator_value, 3-floor(log(10, dss.numerator_value/dss.denominator_value))-1)
    end = merged_rxe.dosage
    and dss.vocabulary_id_1='RxNorm Extension'
)
and invalid_reason is null;
commit;

--19
--deprecate drugs with insignificant volume
update concept_stage set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where concept_code in (
    select drug_concept_code From drug_strength_stage where denominator_value<0.05 
    and vocabulary_id_1='RxNorm Extension'
    and denominator_unit_concept_id=8587
)
and vocabulary_id = 'RxNorm Extension'
and invalid_reason is null;
commit;

--20
--deprecate all impossible drug_strength_stage inputs
update concept_stage set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where concept_code in (
	select drug_concept_code from (
		select distinct drug_concept_code, denominator_value, denominator_unit_concept_id from 
		drug_strength_stage where invalid_reason is null
		and vocabulary_id_1='RxNorm Extension'
	) group by drug_concept_code having count(*)>1
)
and vocabulary_id = 'RxNorm Extension'
and invalid_reason is null;
commit;

--21
--Deprecate concepts that have ingredients both in soluble and solid form
update concept_stage set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where concept_code in (
	select drug_concept_code from drug_strength_stage ds
	where ds.amount_value is not null
	and exists (
		select 1 from drug_strength_stage ds_int
		where ds_int.drug_concept_code=ds.drug_concept_code
		and ds_int.vocabulary_id_1=ds.vocabulary_id_1
		and not (ds_int.ingredient_concept_code=ds.ingredient_concept_code and ds_int.vocabulary_id_2=ds.vocabulary_id_2)
		and ds_int.numerator_value is not null
	)
	and ds.vocabulary_id_1='RxNorm Extension'
)
and vocabulary_id = 'RxNorm Extension'
and invalid_reason is null;
commit;

--22
--deprecate all mappings (except 'Maps to' and 'Drug has drug class') if RxE-concept was deprecated 
update concept_relationship_stage crs set crs.invalid_reason='D', 
crs.valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where exists (select 1 from concept_stage cs
    where cs.concept_code=crs.concept_code_1
    and cs.vocabulary_id=crs.vocabulary_id_1
    and cs.invalid_reason='D'
    and cs.vocabulary_id='RxNorm Extension'
)
and crs.relationship_id not in ('Maps to','Drug has drug class')
and crs.invalid_reason is null;

--reverse
update concept_relationship_stage crs set crs.invalid_reason='D', 
crs.valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where exists (select 1 from concept_stage cs
    where cs.concept_code=crs.concept_code_2
    and cs.vocabulary_id=crs.vocabulary_id_2
    and cs.invalid_reason='D'
    and cs.vocabulary_id='RxNorm Extension'
)
and crs.relationship_id not in ('Mapped from','Drug class of drug')
and crs.invalid_reason is null;
commit;

--23
--create temporary table with old mappings and fresh concepts (after all 'Concept replaced by')
create table rxe_tmp_replaces nologging as
with
src_codes as (
    --get concepts and all their links, which targets to 'U'
    select crs.concept_code_1 as src_code, crs.vocabulary_id_1 as src_vocab, 
    cs.concept_code upd_code, cs.vocabulary_id upd_vocab, 
    cs.concept_class_id upd_class_id, 
    crs.relationship_id src_rel
    From concept_stage cs, concept_relationship_stage crs
    where cs.concept_code=crs.concept_code_2
    and cs.vocabulary_id=crs.vocabulary_id_2
    and cs.invalid_reason='U'
    and cs.vocabulary_id='RxNorm Extension'
    and crs.invalid_reason is null
    and crs.relationship_id not in ('Concept replaced by','Concept replaces')
),
fresh_codes as (
    --get all fresh concepts (with recursion until the last fresh)
    select connect_by_root concept_code_1 as upd_code,
    connect_by_root vocabulary_id_1 upd_vocab,
    concept_code_2 new_code,
    vocabulary_id_2 new_vocab
    from (
        select * from concept_relationship_stage crs
        where crs.relationship_id='Concept replaced by'
        and crs.invalid_reason is null
    ) 
    where connect_by_isleaf = 1
    connect by nocycle prior concept_code_2 = concept_code_1 and prior vocabulary_id_2 = vocabulary_id_1
)
select src.src_code, src.src_vocab, src.upd_code, src.upd_vocab, src.upd_class_id, src.src_rel, fr.new_code, fr.new_vocab
from src_codes src, fresh_codes fr
where src.upd_code=fr.upd_code
and src.upd_vocab=fr.upd_vocab
and not (src.src_vocab='RxNorm' and fr.new_vocab='RxNorm');

--deprecate old relationships
update concept_relationship_stage crs set crs.invalid_reason='D', 
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where (crs.concept_code_1, crs.vocabulary_id_1, crs.concept_code_2, crs.vocabulary_id_2, crs.relationship_id) 
in (
    select r.src_code, r.src_vocab, r.upd_code, r.upd_vocab, r.src_rel from rxe_tmp_replaces r 
    where r.upd_class_id in ('Brand Name','Ingredient','Supplier','Dose Form')
);
--reverse
update concept_relationship_stage crs set crs.invalid_reason='D', 
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where (crs.concept_code_1, crs.vocabulary_id_1, crs.concept_code_2, crs.vocabulary_id_2, crs.relationship_id) 
in (
    select r.upd_code, r.upd_vocab, r.src_code, r.src_vocab, rel.reverse_relationship_id from rxe_tmp_replaces r, relationship rel 
    where r.upd_class_id in ('Brand Name','Ingredient','Supplier','Dose Form')
    and r.src_rel=rel.relationship_id
);

--build new ones relationships or update existing
merge into concept_relationship_stage crs
using (
    select * from rxe_tmp_replaces r where 
    r.upd_class_id in ('Brand Name','Ingredient','Supplier','Dose Form')
) i
on (
    i.src_code=crs.concept_code_1
    and i.src_vocab=crs.vocabulary_id_1
    and i.new_code=crs.concept_code_2
    and i.new_vocab=crs.vocabulary_id_2
    and i.src_rel=crs.relationship_id
)
when matched then 
    update set crs.invalid_reason=null, crs.valid_end_date=to_date ('20991231', 'YYYYMMDD') where crs.invalid_reason is not null
when not matched then insert
(
    crs.concept_code_1,
    crs.vocabulary_id_1,
    crs.concept_code_2,
    crs.vocabulary_id_2,
    crs.relationship_id,
    crs.valid_start_date,
    crs.valid_end_date,
    crs.invalid_reason    
)
values
(
    i.src_code,
    i.src_vocab,
    i.new_code,
    i.new_vocab,
    i.src_rel,
    (SELECT latest_update FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension'),
    to_date ('20991231', 'YYYYMMDD'),
    null  
);

--reverse
merge into concept_relationship_stage crs
using (
    select * from rxe_tmp_replaces r, relationship rel where 
    r.upd_class_id in ('Brand Name','Ingredient','Supplier','Dose Form')
    and r.src_rel=rel.relationship_id
) i
on (
    i.src_code=crs.concept_code_2
    and i.src_vocab=crs.vocabulary_id_2
    and i.new_code=crs.concept_code_1
    and i.new_vocab=crs.vocabulary_id_1
    and i.reverse_relationship_id=crs.relationship_id
)
when matched then 
    update set crs.invalid_reason=null, crs.valid_end_date=to_date ('20991231', 'YYYYMMDD') where crs.invalid_reason is not null
when not matched then insert
(
    crs.concept_code_1,
    crs.vocabulary_id_1,
    crs.concept_code_2,
    crs.vocabulary_id_2,
    crs.relationship_id,
    crs.valid_start_date,
    crs.valid_end_date,
    crs.invalid_reason    
)
values
(
    i.new_code,
    i.new_vocab,
    i.src_code,
    i.src_vocab,
    i.reverse_relationship_id,
    (SELECT latest_update FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension'),
    to_date ('20991231', 'YYYYMMDD'),
    null  
);

--same for drugs (only deprecate old relationships except 'Maps to' and 'Drug has drug class' from 'U'
update concept_relationship_stage crs set crs.invalid_reason='D', 
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where (crs.concept_code_1, crs.vocabulary_id_1, crs.concept_code_2, crs.vocabulary_id_2, crs.relationship_id) 
in (
    select r.src_code, r.src_vocab, r.upd_code, r.upd_vocab, r.src_rel from rxe_tmp_replaces r 
    where r.upd_class_id not in ('Brand Name','Ingredient','Supplier','Dose Form')
    and r.src_rel not in ('Mapped from','Drug class of drug')
);
--reverse
update concept_relationship_stage crs set crs.invalid_reason='D', 
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where (crs.concept_code_1, crs.vocabulary_id_1, crs.concept_code_2, crs.vocabulary_id_2, crs.relationship_id) 
in (
    select r.upd_code, r.upd_vocab, r.src_code, r.src_vocab, rel.reverse_relationship_id from rxe_tmp_replaces r, relationship rel 
    where r.upd_class_id not in ('Brand Name','Ingredient','Supplier','Dose Form')
    and r.src_rel=rel.relationship_id
    and r.src_rel not in ('Mapped from','Drug class of drug')
);
commit;

--24
--deprecate relationships to multiple drug forms or suppliers
update concept_relationship_stage crs set crs.invalid_reason='D', 
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where (crs.concept_code_1, crs.vocabulary_id_1, crs.concept_code_2, crs.vocabulary_id_2)
in (
    select concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2 from (
        select concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2 from (
            select cs1.concept_code as concept_code_1, cs1.vocabulary_id as vocabulary_id_1, 
            c2.concept_code as concept_code_2, c2.vocabulary_id as vocabulary_id_2 from concept_stage cs1 
            join (--for c2 we cannot use stage table, because we need rx classes
                select crs.concept_code_1, c2.concept_class_id from concept_stage cs1, concept c2, concept_relationship_stage crs
                where cs1.concept_code=crs.concept_code_1
                and cs1.vocabulary_id=crs.vocabulary_id_1
                and cs1.vocabulary_id='RxNorm Extension'
                and c2.concept_code=crs.concept_code_2
                and c2.vocabulary_id=crs.vocabulary_id_2
                and c2.concept_class_id in ('Dose Form','Supplier') 
                and crs.invalid_reason is null
                group by crs.concept_code_1, c2.concept_class_id having count (*)>1
            ) d on d.concept_code_1=cs1.concept_code and cs1.concept_class_id not in ('Dose Form','Supplier','Ingredient','Brand Name') and cs1.vocabulary_id='RxNorm Extension'
            join concept_relationship_stage crs on crs.concept_code_1=d.concept_code_1 and crs.vocabulary_id_1='RxNorm Extension' and crs.invalid_reason is null
            --for c2 we cannot use stage table, because we need rx classes
            join concept c2 on c2.concept_code=crs.concept_code_2 and c2.vocabulary_id=crs.vocabulary_id_2 and c2.concept_class_id=d.concept_class_id
            where lower(cs1.concept_name) not like '%'||lower(c2.concept_name)||'%'
        )
        unpivot ((concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2) 
        FOR relationships IN ((concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2),(concept_code_2,vocabulary_id_2,concept_code_1,vocabulary_id_1)))
    )    
)
and crs.invalid_reason is null;
commit;

--25
--deprecate relationship from Pack to Brand Names of it's components
update concept_relationship_stage crs set crs.invalid_reason='D', 
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
where (crs.concept_code_1, crs.vocabulary_id_1, crs.concept_code_2, crs.vocabulary_id_2)
in (
    select concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2 from (
        select concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2 from (
            select cs1.concept_code as concept_code_1, cs1.vocabulary_id as vocabulary_id_1, 
            c2.concept_code as concept_code_2, c2.vocabulary_id as vocabulary_id_2 from concept_stage cs1 
            join (--for c2 we cannot use stage table, because we need rx classes
                select crs.concept_code_1 from concept c2, concept_relationship_stage crs
                where crs.vocabulary_id_1='RxNorm Extension'
                and c2.concept_code=crs.concept_code_2
                and c2.vocabulary_id=crs.vocabulary_id_2
                and c2.concept_class_id='Brand Name' 
                and crs.invalid_reason is null
                group by crs.concept_code_1, c2.concept_class_id having count (*)>1
            ) d on d.concept_code_1=cs1.concept_code and cs1.concept_class_id not in ('Dose Form','Supplier','Ingredient','Brand Name') and cs1.vocabulary_id='RxNorm Extension'
            join concept_relationship_stage crs on crs.concept_code_1=d.concept_code_1 and crs.vocabulary_id_1='RxNorm Extension' and crs.invalid_reason is null
            --for c2 we cannot use stage table, because we need rx classes
            join concept c2 on c2.concept_code=crs.concept_code_2 and c2.vocabulary_id=crs.vocabulary_id_2 and c2.concept_class_id ='Brand Name'
			where lower(regexp_replace (cs1.concept_name,'.* Pack .*\[(.*)\]','\1'))<>lower(c2.concept_name)
        )
        unpivot ((concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2) 
        FOR relationships IN ((concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2),(concept_code_2,vocabulary_id_2,concept_code_1,vocabulary_id_1)))
    )    
)
and crs.invalid_reason is null;
commit;

--26 
--deprecate branded packs without links to brand names
update concept_stage set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension') 
WHERE concept_code in (
    select cs1.concept_code from concept_stage cs1
    where cs1.vocabulary_id='RxNorm Extension'
    and cs1.concept_class_id like '%Branded%Pack%'
    and not exists (
        select 1 from concept_relationship_stage crs, concept_stage cs2
        where crs.concept_code_1=cs1.concept_code
        and crs.vocabulary_id_1=cs1.vocabulary_id
        and crs.concept_code_2=cs2.concept_code
        and crs.vocabulary_id_2=cs2.vocabulary_id
        and cs2.concept_class_id='Brand Name' 
        and cs2.vocabulary_id='RxNorm Extension'
        and crs.invalid_reason is null
    )
)
and vocabulary_id = 'RxNorm Extension'
and invalid_reason is null;
commit;

--27
--turn 'Brand name of' and RxNorm ing of to 'Supplier of' (between 'Supplier' and 'Marketed Product')
merge into concept_relationship_stage crs
using (
    select crs.concept_code_1, crs.concept_code_2, crs.relationship_id, 'Supplier of' new_relationship_id from 
    concept_stage cs1, concept_stage cs2, concept_relationship_stage crs
    where cs1.concept_code=crs.concept_code_1
    and cs1.vocabulary_id=crs.vocabulary_id_1
    and cs1.vocabulary_id='RxNorm Extension'
    and cs2.concept_code=crs.concept_code_2
    and cs2.vocabulary_id=crs.vocabulary_id_2
    and cs2.vocabulary_id='RxNorm Extension'
    and cs1.concept_class_id='Supplier'
    and cs2.concept_class_id='Marketed Product'
    and crs.relationship_id in ('Brand name of','RxNorm ing of')
    and crs.invalid_reason is null
) i
on (
    i.concept_code_1=crs.concept_code_1
    and crs.vocabulary_id_1='RxNorm Extension'
    and i.concept_code_2=crs.concept_code_2
    and crs.vocabulary_id_2='RxNorm Extension'
    and i.new_relationship_id=crs.relationship_id
)
when matched then 
    update set crs.invalid_reason=null, crs.valid_end_date=to_date ('20991231', 'YYYYMMDD') where crs.invalid_reason is not null
when not matched then insert
(
    crs.concept_code_1,
    crs.vocabulary_id_1,
    crs.concept_code_2,
    crs.vocabulary_id_2,
    crs.relationship_id,
    crs.valid_start_date,
    crs.valid_end_date,
    crs.invalid_reason    
)
values
(
    i.concept_code_1,
    'RxNorm Extension',
    i.concept_code_2,
    'RxNorm Extension',
    i.new_relationship_id,
    (SELECT latest_update FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension'),
    to_date ('20991231', 'YYYYMMDD'),
    null  
);

--turn 'Has brand name' and to 'Has supplier' (reverse)
merge into concept_relationship_stage crs
using (
    select crs.concept_code_1, crs.concept_code_2, crs.relationship_id, 'Has supplier' new_relationship_id from 
    concept_stage cs1, concept_stage cs2, concept_relationship_stage crs
    where cs1.concept_code=crs.concept_code_1
    and cs1.vocabulary_id=crs.vocabulary_id_1
    and cs1.vocabulary_id='RxNorm Extension'
    and cs2.concept_code=crs.concept_code_2
    and cs2.vocabulary_id=crs.vocabulary_id_2
    and cs2.vocabulary_id='RxNorm Extension'
    and cs1.concept_class_id='Marketed Product'
    and cs2.concept_class_id='Supplier'
    and crs.relationship_id in ('Has brand name','RxNorm has ing')
    and crs.invalid_reason is null
) i
on (
    i.concept_code_1=crs.concept_code_1
    and crs.vocabulary_id_1='RxNorm Extension'
    and i.concept_code_2=crs.concept_code_2
    and crs.vocabulary_id_2='RxNorm Extension'
    and i.new_relationship_id=crs.relationship_id
)
when matched then 
    update set crs.invalid_reason=null, crs.valid_end_date=to_date ('20991231', 'YYYYMMDD') where crs.invalid_reason is not null
when not matched then insert
(
    crs.concept_code_1,
    crs.vocabulary_id_1,
    crs.concept_code_2,
    crs.vocabulary_id_2,
    crs.relationship_id,
    crs.valid_start_date,
    crs.valid_end_date,
    crs.invalid_reason    
)
values
(
    i.concept_code_1,
    'RxNorm Extension',
    i.concept_code_2,
    'RxNorm Extension',
    i.new_relationship_id,
    (SELECT latest_update FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension'),
    to_date ('20991231', 'YYYYMMDD'),
    null  
);

--deprecate wrong relationship_ids
--('Supplier'<->'Marketed Product' via relationship_id in ('Has brand name','Brand name of','RxNorm has ing','RxNorm ing of'))
update concept_relationship_stage  set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension')
where rowid in (
    select crs.rowid from 
    concept_stage cs1, concept_stage cs2, concept_relationship_stage crs
    where cs1.concept_code=crs.concept_code_1
    and cs1.vocabulary_id=crs.vocabulary_id_1
    and cs1.vocabulary_id='RxNorm Extension'
    and cs2.concept_code=crs.concept_code_2
    and cs2.vocabulary_id=crs.vocabulary_id_2
    and cs2.vocabulary_id='RxNorm Extension'
    and cs1.concept_class_id in ('Supplier','Marketed Product')
    and cs2.concept_class_id in ('Supplier','Marketed Product')
    and crs.relationship_id in ('Has brand name','Brand name of','RxNorm has ing','RxNorm ing of')
    and crs.invalid_reason is null
);
commit;

--28 little manual fixes
--update supplier
update concept_stage c set standard_concept=null where concept_code='OMOP897375' and vocabulary_id='RxNorm Extension' and standard_concept='S';

--deprecate wrong links to brand name because we already have new ones
update concept_relationship_stage  set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension')
where concept_code_1 in ('OMOP559924','OMOP560898') and concept_code_2='848161' and relationship_id='Has brand name'
and invalid_reason is null;
--reverse
update concept_relationship_stage  set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension')
where concept_code_2 in ('OMOP559924','OMOP560898') and concept_code_1='848161' and relationship_id='Brand name of'
and invalid_reason is null;

update concept_relationship_stage set invalid_reason='D',
valid_end_date=(SELECT latest_update-1 FROM vocabulary WHERE vocabulary_id = 'RxNorm Extension')
where (concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2, relationship_id) in
(
    select concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2, relationship_id From (
        select crs.concept_code_1, crs.vocabulary_id_1, crs.concept_code_2, crs.vocabulary_id_2, 
        crs.relationship_id, rl.reverse_relationship_id
        from concept_stage cs1, concept c2, 
        concept_relationship_stage crs, relationship rl
        where cs1.concept_code=crs.concept_code_1
        and cs1.vocabulary_id=crs.vocabulary_id_1
        and cs1.vocabulary_id='RxNorm Extension'
        and c2.concept_code=crs.concept_code_2
        and c2.vocabulary_id=crs.vocabulary_id_2
        and c2.vocabulary_id='RxNorm'
        and cs1.concept_class_id ='Brand Name'
        and (c2.concept_class_id like '%Drug%' or c2.concept_class_id like '%Pack%' or c2.concept_class_id like '%Box%') 
        and crs.invalid_reason is null
        and crs.relationship_id=rl.relationship_id
    )
    unpivot ((concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2, relationship_id) 
    FOR relationships IN ((concept_code_1,vocabulary_id_1,concept_code_2,vocabulary_id_2, relationship_id),(concept_code_2,vocabulary_id_2,concept_code_1,vocabulary_id_1, reverse_relationship_id)))
)
and invalid_reason is null;
commit;

--29 Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--30 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;

--31 Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;

--32 Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

--33 Clean up
DROP TABLE rxe_tmp_replaces PURGE;
DROP TABLE wrong_rxe_replacements PURGE;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script