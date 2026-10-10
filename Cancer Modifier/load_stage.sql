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
* Authors: Nemesis Health Inc., Christian Reich, Asieh Golozar, Vlad Korsik
* Date: 2026
**************************************************************************/

--1. Set Cancer Modifier vocabulary metadata
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=>'Cancer Modifier',
	pVocabularyDate			=> CURRENT_DATE,
	pVocabularyVersion		=> 'Cancer Modifier '||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
	pVocabularyDevSchema	=> 'dev_cancer_modifier'
);
END $_$;


--2. Emulate universal load stage logic for the vocabularies changed by this refresh
DO $LATESTUPDATE$
DECLARE
	pVocabs CONSTANT VARCHAR[]:=ARRAY['SNOMED','LOINC','Cancer Modifier','Episode','OMOP Genomic']; --ARRAY['NDC','SPL']
	pSchemaName CONSTANT TEXT:='dev_cancer_modifier';

	pVocab concept.vocabulary_id%TYPE;
	pLatestUpdate vocabulary_conversion.latest_update%TYPE;
	pVocabVersion vocabulary.vocabulary_version%TYPE;
	pGeneratedStmt TEXT;
	i INT;
BEGIN
	pGeneratedStmt:='DO $_$ BEGIN';

	FOR i IN 1..ARRAY_UPPER(pVocabs,1) LOOP
		SELECT COALESCE(vc.latest_update, CURRENT_DATE),
			COALESCE(v.vocabulary_version, v.vocabulary_id || ' ' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD'))
		INTO pLatestUpdate,
			pVocabVersion
		FROM vocabulary v
		JOIN vocabulary_conversion vc ON vc.vocabulary_id_v5 = v.vocabulary_id
		WHERE v.vocabulary_id = pVocabs[i];

		IF NOT FOUND THEN
			RAISE EXCEPTION 'Vocabulary with id=% not found', pVocabs[i];
		END IF;

		pGeneratedStmt:=pGeneratedStmt||FORMAT($$
			PERFORM VOCABULARY_PACK.SetLatestUpdate(
			pVocabularyName=>%1$L,
			pVocabularyDate=>%4$L,
			pVocabularyVersion=>%5$L,
			pVocabularyDevSchema=>%2$L,
			pAppendVocabulary=>%3$L
		);
		$$,pVocabs[i],pSchemaName,(i>1),pLatestUpdate,pVocabVersion);
	END LOOP;

	pGeneratedStmt:=pGeneratedStmt||'END $_$;';

	EXECUTE pGeneratedStmt;
END $LATESTUPDATE$;


--3. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;


--4. Load full list of concepts
INSERT INTO concept_stage
SELECT c.*
FROM concept c
JOIN vocabulary v ON v.vocabulary_id=c.vocabulary_id
WHERE v.latest_update IS NOT NULL;--load only updatable vocabularies

--5. Load full list of relationships
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT c1.concept_code,
	c2.concept_code,
	c1.vocabulary_id,
	c2.vocabulary_id,
	cr.relationship_id,
	cr.valid_start_date,
	cr.valid_end_date,
	cr.invalid_reason
FROM concept_relationship cr
JOIN concept c1 ON c1.concept_id = cr.concept_id_1
JOIN vocabulary v1 ON v1.vocabulary_id = c1.vocabulary_id
JOIN concept c2 ON c2.concept_id = cr.concept_id_2
JOIN vocabulary v2 ON v2.vocabulary_id = c2.vocabulary_id
WHERE cr.invalid_reason IS NULL
	--load only updatable vocabularies
	AND COALESCE(v1.latest_update, v2.latest_update) IS NOT NULL

	AND (
			CASE
				WHEN cr.invalid_reason IS NULL
					AND COALESCE(v1.latest_update, v2.latest_update) IS NOT NULL
					THEN devv5.GetPrimaryRelationshipID(cr.relationship_id)
				END
			) = cr.relationship_id;

--6. Load full list of synonyms
INSERT INTO concept_synonym_stage
SELECT cs.concept_id,
	cs.concept_synonym_name,
	c.concept_code,
	c.vocabulary_id,
	cs.language_concept_id
FROM concept_synonym cs
JOIN concept c ON c.concept_id = cs.concept_id
JOIN vocabulary v ON v.vocabulary_id=c.vocabulary_id
WHERE v.latest_update IS NOT NULL;

--7. Load full list of pack content
INSERT INTO pack_content_stage
SELECT c1.concept_code AS pack_concept_code,
	c1.vocabulary_id AS pack_vocabulary_id,
	c2.concept_code AS drug_concept_code,
	c2.vocabulary_id AS drug_vocabulary_id,
	pc.amount,
	pc.box_size
FROM pack_content pc
JOIN concept c1 ON c1.concept_id = pc.pack_concept_id
JOIN concept c2 ON c2.concept_id = pc.drug_concept_id
JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
WHERE v.latest_update IS NOT NULL;--load only updatable vocabularies

--8. Load full list of drug strength
INSERT INTO drug_strength_stage
SELECT c1.concept_code AS drug_concept_code,
	c1.vocabulary_id AS vocabulary_id_1,
	c2.concept_code AS ingredient_concept_code,
	c2.vocabulary_id AS vocabulary_id_2,
	ds.amount_value,
	ds.amount_unit_concept_id,
	ds.numerator_value,
	ds.numerator_unit_concept_id,
	ds.denominator_value,
	ds.denominator_unit_concept_id,
	ds.valid_start_date,
	ds.valid_end_date,
	ds.invalid_reason
FROM drug_strength ds
JOIN concept c1 ON c1.concept_id = ds.drug_concept_id
JOIN concept c2 ON c2.concept_id = ds.ingredient_concept_id
JOIN vocabulary v ON v.vocabulary_id = c1.vocabulary_id
WHERE v.latest_update IS NOT NULL;--load only updatable vocabularies

ANALYZE concept_stage;
ANALYZE concept_relationship_stage;
ANALYZE drug_strength_stage;

--9. Manual concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

--9.1 Genomic concept class reconstruction
-- Protein class renew
UPDATE concept_stage cs
SET concept_class_id='Gene Protein Variant'
--SELECT *
FROM concept c
where c.vocabulary_id='OMOP Genomic'
    and c.concept_class_id !='Gene Protein Variant'
and c.concept_name ~*'protein expression'
and c.concept_code=cs.concept_code
and c.vocabulary_id=cs.vocabulary_id
;


--Gene variant class renew
UPDATE concept_stage cs
SET concept_class_id='Gene Variant'
FROM concept c
where c.vocabulary_id='OMOP Genomic'
    and c.concept_class_id ='Genetic Variation'
and c.concept_code=cs.concept_code
and c.vocabulary_id=cs.vocabulary_id
;

--10. Manual synonyms
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualSynonyms();
END $_$;

--11. Introduction of precoordinated pairs relationship processed during the release
INSERT INTO concept_relationship_stage (
	concept_code_1,
	vocabulary_id_1,
	concept_code_2,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)

with correct_precoordinated_pairs as (SELECT cs.concept_code                 as concept_code_1,
                                             cs.vocabulary_id                as vocabulary_id_1,
                                             c.concept_code                  as concept_code_2,
                                             c.vocabulary_id                 as vocabulary_id_2,
                                             'Precoord pair of'              as relationship_id,
                                             current_date                    as valid_start_date,
                                             TO_DATE('20991231', 'yyyymmdd') as valid_end_date,
                                             NULL                            as invalid_reason

                                      from concept_stage cs
                                               JOIN concept c
                                                    on c.concept_code = split_part(cs.concept_code, '|', 1)
                                      where cs.concept_class_id = 'Precoordinated pair'
                                        and not exists(SELECT 1
                                                       from concept cx
                                                       where (cx.concept_code, cx.vocabulary_id) =
                                                             (cs.concept_code, cs.vocabulary_id))
                                        AND exists (SELECT 1
                                                    from concept_relationship crx
                                                             JOIN concept cx1
                                                                  on crx.concept_id_2 = cx1.concept_id
                                                                      and crx.relationship_id = 'Has Answer'
                                                                      and crx.invalid_reason IS NULL
                                                                      and cx1.vocabulary_id = 'LOINC'
                                                    WHERE cx1.concept_code = split_part(cs.concept_code, '|', 2)
                                                      and crx.concept_id_1 = c.concept_id)

                                      UNION ALL

                                      SELECT cs.concept_code                 as concept_code_1,
                                             cs.vocabulary_id                as vocabulary_id_1,
                                             c.concept_code                  as concept_code_2,
                                             c.vocabulary_id                 as vocabulary_id_2,
                                             'Precoord pair of'              as relationship_id,
                                             current_date                    as valid_start_date,
                                             TO_DATE('20991231', 'yyyymmdd') as valid_end_date,
                                             NULL                            as invalid_reason

                                      from concept_stage cs
                                               JOIN concept c
                                                    on c.concept_code = split_part(cs.concept_code, '|', 2)
                                      where cs.concept_class_id = 'Precoordinated pair'
                                        and not exists(SELECT 1
                                                       from concept cx
                                                       where (cx.concept_code, cx.vocabulary_id) =
                                                             (cs.concept_code, cs.vocabulary_id))
                                        AND exists (SELECT 1
                                                    from concept_relationship crx
                                                             JOIN concept cx1
                                                                  on crx.concept_id_2 = cx1.concept_id
                                                                      and crx.relationship_id = 'Answer of'
                                                                      and crx.invalid_reason IS NULL
                                                                      and cx1.vocabulary_id = 'LOINC'
                                                    WHERE cx1.concept_code = split_part(cs.concept_code, '|', 1)
                                                      and crx.concept_id_1 = c.concept_id))

SELECT cpp.concept_code_1,
       cpp.vocabulary_id_1,
       cpp.concept_code_2,
       cpp.vocabulary_id_2,
       cpp.relationship_id,
       cpp.valid_start_date,
       cpp.valid_end_date,
       cpp.invalid_reason
FROM correct_precoordinated_pairs as cpp
JOIN vocabulary v ON v.vocabulary_id=cpp.vocabulary_id_1
and v.vocabulary_id=cpp.vocabulary_id_2
WHERE v.latest_update IS NOT NULL
;

--12. Manual mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--12.1 De-standardize LOINC questions and answers covered by Cancer Modifier pre-coordinated pairs
/*
Purpose:
  De-standardize original LOINC question and answer concepts only when their
  active production "Has Answer" universe is fully covered by the new
  pre-coordinated pair representation.

Coverage rules:
  - For a QUESTION:
      every active production LOINC "Has Answer" answer must be covered either by:
        a) a mapped pre-coordinated pair; or
        b) a no-information / administrative answer that is intentionally not mapped.
      This allows broad answers such as "Other" or "Unknown" to stop blocking
      the de-standardization of a specific question.

  - For an ANSWER:
      every active production LOINC question using that answer must be covered by:
        a) a mapped pre-coordinated pair; or
        b) an explicit in-scope pre-coordinated pair for a no-information /
           administrative answer.
      This prevents broad answers such as LA46-8 "Other" from being
      de-standardized while they are still used by questions outside the
      Cancer Modifier pre-coordinated-pair scope.
*/
WITH zero_map_acceptable_answers AS (
    SELECT *
    FROM (
        VALUES
            ('LA3983-9',  'Grade/differentiation unknown, not stated, or not applicable'),
            ('LA4158-7',  'Code - not defined in code system'),
            ('LA4489-6',  'Unknown'),
            ('LA4543-0',  'N/A'),
            ('LA4703-0',  'Not applicable (no AJCC staging scheme)'),
            ('LA4720-4',  'Not applicable'),
            ('LA7338-2',  'Not available'),
            ('LA46-8',    'Other'),
            ('LA4379-9',  'Registrar'),
            ('LA4622-2',  'Managing physician'),
            ('LA4651-1',  'Pathologist'),
            ('LA4724-6',  'Other physician'),
            ('LA4693-3',  'Not staged'),
            ('LA4406-0',  'Unknown if Staged'),
            ('LA4391-4',  'Recurrent, unstaged, unknown, Stage X'),
            ('LA3595-1',  'Unstaged'),
            ('LA3594-4',  'Unstaged, unknown'),
            ('LA4708-9',  'NOS, unknown'),
            ('LA13420-7', 'Unknown/Indeterminate'),
            ('LA14100-4', 'Undetermined'),
            ('LA11884-6', 'Indeterminate')
    ) AS x(answer_concept_code, reason)
),
active_qa AS (
    SELECT DISTINCT
        q.concept_code  AS question_concept_code,
        q.concept_name  AS question_concept_name,
        q.vocabulary_id AS question_vocabulary_id,
        a.concept_code  AS answer_concept_code,
        a.concept_name  AS answer_concept_name,
        a.vocabulary_id AS answer_vocabulary_id
    FROM concept_relationship cr
    JOIN concept q
        ON q.concept_id = cr.concept_id_1
    JOIN concept a
        ON a.concept_id = cr.concept_id_2
    WHERE cr.relationship_id = 'Has Answer'
      AND cr.invalid_reason IS NULL
      AND q.vocabulary_id = 'LOINC'
      AND a.vocabulary_id = 'LOINC'
),
staged_pairs AS (
    SELECT DISTINCT
        cs.concept_code  AS pair_concept_code,
        cs.concept_name  AS pair_concept_name,
        cs.vocabulary_id AS pair_vocabulary_id
    FROM concept_stage cs
    WHERE cs.vocabulary_id = 'LOINC'
      AND cs.concept_class_id = 'Precoordinated pair'
),
pair_links AS (
    SELECT
        concept_code_1,
        vocabulary_id_1,
        concept_code_2,
        vocabulary_id_2
    FROM concept_relationship_stage
    WHERE relationship_id = 'Precoord pair of'
      AND invalid_reason IS NULL

    UNION

    SELECT
        concept_code_1,
        vocabulary_id_1,
        concept_code_2,
        vocabulary_id_2
    FROM concept_relationship_manual
    WHERE relationship_id = 'Precoord pair of'
      AND invalid_reason IS NULL
),
pair_components AS (
    SELECT DISTINCT
        sp.pair_concept_code,
        sp.pair_concept_name,
        sp.pair_vocabulary_id,
        CASE
            WHEN pl.concept_code_1 = sp.pair_concept_code
             AND pl.vocabulary_id_1 = sp.pair_vocabulary_id
            THEN pl.concept_code_2
            ELSE pl.concept_code_1
        END AS component_concept_code,
        CASE
            WHEN pl.concept_code_1 = sp.pair_concept_code
             AND pl.vocabulary_id_1 = sp.pair_vocabulary_id
            THEN pl.vocabulary_id_2
            ELSE pl.vocabulary_id_1
        END AS component_vocabulary_id
    FROM staged_pairs sp
    JOIN pair_links pl
        ON (
            pl.concept_code_1 = sp.pair_concept_code
            AND pl.vocabulary_id_1 = sp.pair_vocabulary_id
        )
        OR (
            pl.concept_code_2 = sp.pair_concept_code
            AND pl.vocabulary_id_2 = sp.pair_vocabulary_id
        )
),
qa_precoord_pairs AS (
    SELECT DISTINCT
        qa.question_concept_code,
        qa.question_concept_name,
        qa.question_vocabulary_id,
        qa.answer_concept_code,
        qa.answer_concept_name,
        qa.answer_vocabulary_id,
        pp.pair_concept_code,
        pp.pair_concept_name,
        pp.pair_vocabulary_id
    FROM active_qa qa
    LEFT JOIN (
        SELECT DISTINCT
            pcq.pair_concept_code,
            pcq.pair_concept_name,
            pcq.pair_vocabulary_id,
            pcq.component_concept_code  AS question_concept_code,
            pcq.component_vocabulary_id AS question_vocabulary_id,
            pca.component_concept_code  AS answer_concept_code,
            pca.component_vocabulary_id AS answer_vocabulary_id
        FROM pair_components pcq
        JOIN pair_components pca
            ON pca.pair_concept_code = pcq.pair_concept_code
           AND pca.pair_vocabulary_id = pcq.pair_vocabulary_id
           AND (
                pca.component_concept_code <> pcq.component_concept_code
                OR pca.component_vocabulary_id <> pcq.component_vocabulary_id
           )
    ) pp
        ON pp.question_concept_code = qa.question_concept_code
       AND pp.question_vocabulary_id = qa.question_vocabulary_id
       AND pp.answer_concept_code = qa.answer_concept_code
       AND pp.answer_vocabulary_id = qa.answer_vocabulary_id
),
mapped_pairs AS (
    SELECT DISTINCT
        concept_code_1  AS pair_concept_code,
        vocabulary_id_1 AS pair_vocabulary_id
    FROM concept_relationship_stage
    WHERE relationship_id IN ('Maps to', 'Maps to value')
      AND vocabulary_id_1 = 'LOINC'
      AND invalid_reason IS NULL

    UNION

    SELECT DISTINCT
        concept_code_1  AS pair_concept_code,
        vocabulary_id_1 AS pair_vocabulary_id
    FROM concept_relationship_manual
    WHERE relationship_id IN ('Maps to', 'Maps to value')
      AND vocabulary_id_1 = 'LOINC'
      AND invalid_reason IS NULL
),
qa_coverage AS (
    SELECT
        qa.question_concept_code,
        qa.question_vocabulary_id,
        qa.answer_concept_code,
        qa.answer_vocabulary_id,
        qa.pair_concept_code,
        qa.pair_vocabulary_id,
        CASE
            WHEN mp.pair_concept_code IS NOT NULL
            THEN 1
            WHEN z.answer_concept_code IS NOT NULL
            THEN 1
            ELSE 0
        END AS is_covered_for_question,
        CASE
            WHEN mp.pair_concept_code IS NOT NULL
            THEN 1
            WHEN z.answer_concept_code IS NOT NULL
             AND qa.pair_concept_code IS NOT NULL
            THEN 1
            ELSE 0
        END AS is_covered_for_answer
    FROM qa_precoord_pairs qa
    LEFT JOIN mapped_pairs mp
        ON mp.pair_concept_code = qa.pair_concept_code
       AND mp.pair_vocabulary_id = qa.pair_vocabulary_id
    LEFT JOIN zero_map_acceptable_answers z
        ON z.answer_concept_code = qa.answer_concept_code
),
eligible_concepts AS (
    SELECT
        qc.question_concept_code AS concept_code,
        qc.question_vocabulary_id AS vocabulary_id
    FROM qa_coverage qc
    JOIN concept_stage cs
        ON cs.concept_code = qc.question_concept_code
       AND cs.vocabulary_id = qc.question_vocabulary_id
    GROUP BY
        qc.question_concept_code,
        qc.question_vocabulary_id
    HAVING COUNT(*) = SUM(is_covered_for_question)

    UNION

    SELECT
        qc.answer_concept_code AS concept_code,
        qc.answer_vocabulary_id AS vocabulary_id
    FROM qa_coverage qc
    JOIN concept_stage cs
        ON cs.concept_code = qc.answer_concept_code
       AND cs.vocabulary_id = qc.answer_vocabulary_id
    GROUP BY
        qc.answer_concept_code,
        qc.answer_vocabulary_id
    HAVING COUNT(*) = SUM(is_covered_for_answer)
)
UPDATE concept_stage cs
SET standard_concept = NULL
FROM eligible_concepts ec
WHERE cs.concept_code = ec.concept_code
  AND cs.vocabulary_id = ec.vocabulary_id
  AND cs.vocabulary_id = 'LOINC'
  AND cs.standard_concept IS NOT NULL
;

-- 12.2 Add 'Positive' value mappings for genomic and oncology concepts
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	vocabulary_id_1,
	vocabulary_id_2,
	relationship_id,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT
    c.concept_code AS concept_code_1,
     pos.concept_code AS concept_code_2,
    c.vocabulary_id AS vocabulary_id_1,
    pos.vocabulary_id AS vocabulary_id_2,
    'Maps to value' AS relationship_id,
    CURRENT_DATE AS valid_start_date,
    TO_DATE('20991231', 'YYYYMMDD') AS valid_end_date,
    NULL::varchar AS invalid_reason
FROM concept_stage c
-- Get the codes for the "Positive" concept
CROSS JOIN (
    SELECT concept_code, vocabulary_id
    FROM concept
    WHERE concept_id = 9191
) pos
-- 1. Find valid 'Maps to' relationships IN THE STAGING TABLE
JOIN concept_relationship_stage crs_maps_to
  ON crs_maps_to.concept_code_1 = c.concept_code
  AND crs_maps_to.vocabulary_id_1 = c.vocabulary_id
  AND crs_maps_to.relationship_id = 'Maps to'
  AND crs_maps_to.invalid_reason IS NULL
-- 2. Find the target concepts they map to (joining by code and vocabulary)
JOIN concept c_target
  ON c_target.concept_code = crs_maps_to.concept_code_2
  AND c_target.vocabulary_id = crs_maps_to.vocabulary_id_2
WHERE c.vocabulary_id = 'SNOMED'
  -- 3. Only keep targets related to Genomics, Nodes, or Metastasis
  AND (
      c_target.vocabulary_id = 'OMOP Genomic'
      OR c_target.concept_class_id IN ('Nodes', 'Metastasis', 'Extension/Invasion')
      OR c_target.concept_id IN (
          SELECT descendant_concept_id
          FROM concept_ancestor
          WHERE ancestor_concept_id IN (36769180, 36768587) -- Nodes, Metastasis
      )
  )
  -- 4. Skip if a 'Maps to value' already exists in the main table
  AND NOT EXISTS (
      SELECT 1
      FROM concept_relationship cr_mtv
      WHERE cr_mtv.concept_id_1 = c.concept_id
        AND cr_mtv.relationship_id = 'Maps to value'
        AND cr_mtv.invalid_reason IS NULL
  )
  -- 5. Skip if a 'Maps to value' already exists in the staging table
  AND NOT EXISTS (
      SELECT 1
      FROM concept_relationship_stage crs_mtv
      WHERE crs_mtv.concept_code_1 = c.concept_code
        AND crs_mtv.vocabulary_id_1 = c.vocabulary_id
        AND crs_mtv.relationship_id = 'Maps to value'
        AND crs_mtv.invalid_reason IS NULL
  )
  -- 6. Skip concepts with negative words in their name
  AND c.concept_name !~* '\y(negative|no|absent|without|w/o|not)\y'
;


--13. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--14. Add mapping (Maps to) from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--15. Add mapping (Maps to value) from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
END $_$;

--16. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--17. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script
