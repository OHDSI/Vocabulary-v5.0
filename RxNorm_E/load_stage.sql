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
* Authors: Timur Vakhitov, Christian Reich
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

--7
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

--8
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
        and crs.vocabulary_id_1='RxNorm Extension'
        and crs.vocabulary_id_2='RxNorm Extension'
    ) 
    where connect_by_isleaf = 1
    connect by nocycle prior concept_code_2 = concept_code_1 and prior vocabulary_id_2 = vocabulary_id_1
)
select src.src_code, src.src_vocab, src.upd_code, src.upd_vocab, src.upd_class_id, src.src_rel, fr.new_code, fr.new_vocab
from src_codes src, fresh_codes fr
where src.upd_code=fr.upd_code
and src.upd_vocab=fr.upd_vocab;

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

--9 Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--10 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;

--11 Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;

--12 Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;

--13 Clean upd
DROP TABLE rxe_tmp_replaces PURGE;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script