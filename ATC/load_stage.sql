DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'ATC',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_ATATUR'
);
END $_$;


TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;



                    /***************************************************************
                    **************************CONCEPT_STAGE*************************
                    ***************************************************************/

INSERT INTO concept_stage
            (
             concept_id,
                concept_name,
                domain_id,
                vocabulary_id,
                concept_class_id,
                standard_concept,
                concept_code,
                valid_start_date,
                valid_end_date,
                invalid_reason
            )
SELECT
        t1.concept_id,
        CASE
            WHEN t1.adm_r is NULL then trim(t1.name)
            ELSE trim(t1.name || '; ' || t1.adm_r)
        END as concept_name,
        domain_id,
        vocabulary_id,
        concept_class_id,
        standard_concept,
        concept_code,
        valid_start_date,
        valid_end_date,
        invalid_reason
FROM
            (
                select
                    DISTINCT NULL::int as concept_id,
                    CASE
                        WHEN active = 'NA' or active = 'C' THEN t1.class_name
                        ELSE '[' || active || '] ' || t1.class_name
                    END AS name,
                    t2.new as adm_r,
                    'Drug' as domain_id,
                    'ATC' as vocabulary_id,
                    CASE
                        WHEN length(t1.class_code) = 1 then 'ATC 1st'
                        WHEN length(t1.class_code) = 3 then 'ATC 2nd'
                        WHEN length(t1.class_code) = 4 then 'ATC 3rd'
                        WHEN length(t1.class_code) = 5 then 'ATC 4th'
                        WHEN length(t1.class_code) = 7 then 'ATC 5th'
                    END AS concept_class_id,
                    'C' as standard_concept,
                    t1.class_code as concept_code,
                    CASE
                        WHEN active = 'NA' and t1.class_code not in (
                                                                    select distinct replaced_by      ----
                                                                    from sources.atc_codes           ----  all codes except those for which we know actual dates
                                                                    where replaced_by != 'NA'        ----  get standard 1970-2099 values.
                                                                    )
                        THEN TO_DATE('1970-01-01', 'YYYY-MM-DD')
                        ELSE start_date
                    END AS valid_start_date,
                    revision_date as valid_end_date,
                    CASE
                        WHEN active = 'NA' THEN NULL
                        ELSE active
                    END AS invalid_reason
                from sources.atc_codes t1
                left join dev_atatur.new_adm_r t2 on t1.class_code = t2.class_code
                where t1.active != 'C'
            ) t1;

                    /***************************************************************
                    **********************CONCEPT_SYNONYM_STAGE*********************
                    ***************************************************************/
INSERT INTO concept_synonym_stage
            (
            synonym_concept_id,
            synonym_name,
            synonym_concept_code,
            synonym_vocabulary_id,
            language_concept_id
            )
SELECT
        DISTINCT NULL::int as synonym_concept_id,
        CASE
            WHEN t1.synonym_name is null then trim(t2.class_name)
            ELSE trim(t1.synonym_name)
        END AS synonym_name,
        t1.synonym_concept_code,
        'ATC' as synonym_vocabulary_id,
        4180186 as language_concept_id
FROM
    (
          SELECT class_code as synonym_concept_code,
                 class_name || ' ' || ddd || ' ' || u || ' ' || product                                                                               as synonym_name
          FROM
              (
                SELECT
                       class_code,
                       class_name,
                       CASE when ddd = 'NA' THEN NULL ELSE ddd END AS ddd,
                       CASE when u = 'NA' THEN NULL ELSE u END     AS u,
                       CASE
                           WHEN adm_r = 'NA' THEN NULL
                           WHEN adm_r = 'Inhal.powder' THEN 'Inhal.Powder'
                           WHEN adm_r = 'TD' THEN 'Transdrmal Product'
                           WHEN adm_r = 'Instill.solution' THEN 'Instill.Sol'
                           WHEN adm_r = '"""Inhal.powder"""' THEN 'Inhal.Powder'
                           WHEN adm_r = 'ointment' THEN 'Ointmen'
                           WHEN adm_r = 'O' THEN 'Oral Product'
                           WHEN adm_r = 'Inhal.aerosol' THEN 'Inhal.Aerosol'
                           WHEN adm_r = 'Chewing gum' THEN 'Chewing Gum'
                           WHEN adm_r = 'V' THEN 'Vaginal Product'
                           WHEN adm_r = 'lamella' THEN 'Lamella'
                           WHEN adm_r = 'oral aerosol' THEN 'Oral Aerosol'
                           WHEN adm_r = 's.c. implant' THEN 'S.C. Implant'
                           WHEN adm_r = 'Inhal. powder' THEN 'Inhal.Powder'
                           WHEN adm_r = 'urethral' THEN 'Urethral'
                           WHEN adm_r = 'N' THEN 'Nasal Product'
                           WHEN adm_r = '"O,P"' THEN 'Oral, Parentheral Product'
                           WHEN adm_r = 'P' THEN 'Parenteral Product'
                           WHEN adm_r = 'Inhal.solution' THEN 'Inhal.Solution'
                           WHEN adm_r = 'SL' THEN 'Sublingual Product'
                           WHEN adm_r = 'Inhal' THEN 'Inhal'
                           WHEN adm_r = 'intravesical' THEN 'Intravesical'
                           WHEN adm_r = 'R' THEN 'Rectal Product'
                           WHEN adm_r = 'implant' THEN 'Implan'
                           END                                     AS product
                FROM
                    sources.atc_codes
                WHERE
                    length(class_code) = 7
              ) t1

        UNION

              (SELECT
                   class_code as synonym_concept_code,
                   class_name as synonym_name
              FROM sources.atc_codes
              WHERE length(class_code) = 7)

        ) t1

        JOIN sources.atc_codes t2
        on t1.synonym_concept_code = t2.class_code;

                    /***************************************************************
                    ********************CONCEPT_RELATIONSHIP_STAGE******************
                    ***************************************************************/

-------------------------------
---- ATC - Ings connections----
-------------------------------

INSERT INTO concept_relationship_stage
    (
	concept_id_1,
    concept_id_2,
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
	)
SELECT
        NULL::INT as concept_id_1,
        NULL::INT as concept_id_2,
        class_code as concept_code_1,
        t2.concept_code as concept_code_2,
        'ATC' as vocabulary_id_1,
        t2.vocabulary_id as vocabulary_id_2,
        relationship_id,
        CURRENT_DATE as valid_start_date,
        TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date,
        NULL as invalid_reason
FROM
     (
        SELECT
            class_code,
            class_name,
            relationship_id,
            unnest(string_to_array(ids, ', ')) as concept_code_2
        FROM
            new_atc_codes_ings_for_manual
     ) t1
      JOIN devv5.concept t2
          ON t1.concept_code_2::int = t2.concept_id and t2.vocabulary_id in ('RxNorm', 'RxNorm Extension');

-------------------------------
------Maps to connections------
-------------------------------

INSERT INTO concept_relationship_stage
    (
	concept_id_1,
    concept_id_2,
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
	)
SELECT
        DISTINCT NULL::INT as concept_id_1,
        NULL::INT as concept_id_2,
        class_code as concept_code_1,
        t2.concept_code as concept_code_2,
        'ATC' as vocabulary_id_1,
        t2.vocabulary_id as vocabulary_id_2,
        'Maps to' as relationship_id,
        CURRENT_DATE as valid_start_date,
        TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date,
        NULL as invalid_reason
FROM
    (
        SELECT
            class_code,
            class_name,
            relationship_id,
            unnest(string_to_array(ids, ', ')) as concept_code_2
        FROM new_atc_codes_ings_for_manual
        WHERE relationship_id in ('ATC - RxNorm pr lat', 'ATC - RxNorm sec lat')
      ) t1
      JOIN devv5.concept t2
          ON t1.concept_code_2::int = t2.concept_id and t2.vocabulary_id in ('RxNorm', 'RxNorm Extension');

-------------------------------
--------ATC - RxNorm-----------
-------------------------------
DROP TABLE IF EXISTS  new_unique_atc_codes_rxnorm;
CREATE TABLE new_unique_atc_codes_rxnorm AS
SELECT DISTINCT class_code, ids
FROM new_atc_codes_rxnorm
where length(class_code) = 7
and concept_class_id = 'Clinical Drug Form';


INSERT INTO concept_relationship_stage
    (
	concept_id_1,
    concept_id_2,
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date,
    invalid_reason
	)
SELECT
        NULL::INT as concept_id_1,
        NULL::INT as concept_id_2,
        class_code as concept_code_1,
        t2.concept_code as concept_code_2,
        'ATC' as vocabulary_id_1,
        t2.vocabulary_id as vocabulary_id_2,
        'ATC - RxNorm' as relationship_id,
        CURRENT_DATE as valid_start_date,
        TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date,
        NULL as invalid_reason
FROM new_unique_atc_codes_rxnorm t1
    JOIN devv5.concept t2 ON t1.ids::int = t2.concept_id and t2.vocabulary_id in ('RxNorm', 'RxNorm Extension');

-------------------------------
------Concept replaced by------
-------------------------------
INSERT INTO concept_relationship_stage
    (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date
    )
SELECT
        class_code as concept_code_1,
        replaced_by as concept_code_2,
        'ATC' as vocabulary_id_1,
        'ATC' as vocabulary_id_2,
        'Concept replaced by' as relationship_id,
        revision_date as valid_start_date,
        TO_DATE('2099-12-31', 'YYYY-MM-DD') as valid_end_date
FROM
    sources.atc_codes
WHERE
    active = 'U';

---------------------------------
--ATC - SNOMED + ATC - Internal--
---------------------------------

--ATC - SNOMED
INSERT INTO concept_relationship_stage
    (
    concept_code_1,
    concept_code_2,
    vocabulary_id_1,
    vocabulary_id_2,
    relationship_id,
    valid_start_date,
    valid_end_date
	)
SELECT
    DISTINCT d.concept_code AS concept_code_1,
	e.concept_code AS concept_code_2,
	'SNOMED' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	'SNOMED - ATC eq' AS relationship_id,
	d.valid_start_date AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM devv5.concept d
JOIN sources.rxnconso r ON r.code = d.concept_code
	AND r.sab = 'SNOMEDCT_US'
	AND r.code <> 'NOCODE'
JOIN sources.rxnconso r2 ON r2.rxcui = r.rxcui
	AND r2.sab = 'ATC'
	AND r2.code <> 'NOCODE'
JOIN concept_stage e ON e.concept_code = r2.code
	AND e.concept_class_id <> 'ATC 5th' -- Ingredients only to RxNorm
	AND e.vocabulary_id = 'ATC'
WHERE d.vocabulary_id = 'SNOMED'
	AND d.invalid_reason IS NULL

UNION ALL

-- 'Is a' relationships between ATC Classes using mrconso (internal ATC hierarchy)
SELECT uppr.concept_code AS concept_code_1,
	lowr.concept_code AS concept_code_2,
	'ATC' AS vocabulary_id_1,
	'ATC' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
FROM concept_stage uppr
JOIN concept_stage lowr ON lowr.vocabulary_id = 'ATC'
	AND lowr.invalid_reason IS NULL -- to exclude deprecated or updated codes from the hierarchy
JOIN vocabulary v ON v.vocabulary_id = 'ATC'
WHERE uppr.invalid_reason IS NULL
	AND uppr.vocabulary_id = 'ATC'
	AND (
		(
			LENGTH(uppr.concept_code) IN (
				4,
				5
				)
			AND lowr.concept_code = SUBSTR(uppr.concept_code, 1, LENGTH(uppr.concept_code) - 1)
			)
		OR (
			LENGTH(uppr.concept_code) IN (
				3,
				7
				)
			AND lowr.concept_code = SUBSTR(uppr.concept_code, 1, LENGTH(uppr.concept_code) - 2)
			)
		);


                    /***************************************************************
                    *********CORRECTION OF LEGACY (STANDARD MANUAL TABLES)**********
                    ***************************************************************/

    ----- THESE TWO ARE NOT NEEDED (BUILDED ABOVE FROM SCRATCH). DON'T RUN!
--  DO $_$
-- BEGIN
-- 	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
-- END $_$;
--
-- ANALYZE concept_stage;

-- DO $_$
-- BEGIN
-- 	PERFORM VOCABULARY_PACK.ProcessManualSynonyms();
-- END $_$;


---- deprecating wrong mappings using manual table ----
UPDATE concept_relationship_manual
SET invalid_reason = 'D',
    valid_end_date = CURRENT_DATE
WHERE (concept_code_1, concept_code_2) IN (
    SELECT t1.atc_code, t2.concept_code
    FROM existent_atc_rxnorm_to_drop t1
    JOIN devv5.concept t2 ON t1.concept_id = t2.concept_id
    WHERE t2.vocabulary_id IN ('RxNorm', 'RxNorm Extension')
    AND t1.to_drop = 'D'
)
and vocabulary_id_1 = 'ATC'
and vocabulary_id_2 in ('RxNorm', 'RxNorm Extension');

                    /***************************************************************
                    ************************POSTPROCESSING**************************
                    ***************************************************************/

-- Add manually created relationships using the function which processes the concept_relationship_manual table
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--- Drop all 'bad' connections from stage table
UPDATE concept_relationship_stage
SET invalid_reason = 'D',
    valid_end_date = CURRENT_DATE
where (concept_id_1, concept_id_2) in (
select concept_id_atc,
       concept_id_rx
from atc_rxnorm_to_drop_in_sources
where drop = 'D');


ANALYZE concept_relationship_stage;

-- Perform mapping replacement using function below
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

-- Add mappings from deprecated to fresh codes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

-- Deprecate 'Maps to' mappings to deprecated AND updated codes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

-- Remove ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DELETEAmbiguousMAPSTO();
END $_$;