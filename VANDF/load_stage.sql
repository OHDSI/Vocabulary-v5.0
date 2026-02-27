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
* Authors: Dmitry Dymshyts, Timur Vakhitov, Varvara Savitskaya, Oleg Zhuk, Masha Khitrun
* Date: 2026
**************************************************************************/

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'VANDF',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_VANDF'
);

	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'VA Class',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.rxnatomarchive LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_VANDF',
	pAppendVocabulary		=> TRUE
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Insert into concept_stage VANDF
INSERT INTO concept_stage (
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
SELECT DISTINCT ON (rx.code) vocabulary_pack.CutConceptName(rx.str) AS concept_name,
	'Drug' AS domain_id,
	'VANDF' AS vocabulary_id,
	'Drug Product' AS concept_class_id,
	NULL AS standard_concept,
	rx.code AS concept_code,
	LEAST(COALESCE(TO_DATE(rxs.atv, 'yyyymmdd'), v.latest_update), v.latest_update) AS valid_start_date,
	COALESCE(TO_DATE(rxs.atv, 'yyyymmdd'), TO_DATE('20991231', 'yyyymmdd')) AS valid_end_date,
	CASE 
		WHEN rxs.atv IS NULL
			THEN NULL
		ELSE 'D'
		END AS invalid_reason
FROM sources.rxnconso rx
LEFT JOIN sources.rxnsat rxs ON rxs.code = rx.code
	AND rxs.sab = 'VANDF'
	AND rxs.atn = 'NF_INACTIVATE'
JOIN vocabulary v ON v.vocabulary_id = 'VANDF'
WHERE rx.sab = 'VANDF'
	AND rx.tty IN (
		'CD',
		'PT',
		'IN'
		)
	AND v.vocabulary_id = 'VANDF'
ORDER BY rx.code,
	TO_DATE(rxs.atv, 'yyyymmdd') DESC;--some codes have several records in rxnsat with different NF_INACTIVATE, so we take the only one with MAX (atv)

--4. Insert into concept_stage VA Class
INSERT INTO concept_stage (
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
SELECT rx.rxaui::INT4, --store rxaui as concept_id, this field is needed below for relationships
	vocabulary_pack.CutConceptName(rx.str) AS concept_name,
	'Drug' AS domain_id,
	'VA Class' AS vocabulary_id,
	'VA Class' AS concept_class_id,
	NULL AS standard_concept,
	rxs.atv AS concept_code,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.rxnconso rx
JOIN sources.rxnsat rxs ON rxs.rxaui = rx.rxaui
	AND rxs.rxcui = rx.rxcui
	AND rxs.sab = 'VANDF'
	AND rxs.atn = 'VAC'
JOIN vocabulary v ON v.vocabulary_id = 'VA Class'
WHERE rx.sab = 'VANDF'
	AND rx.tty = 'PT'
	AND NOT (
		rxs.atv = 'AM114'
		AND rx.str LIKE '(%'
		); --fix for names of AM114

--5. Fill concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_name,
	synonym_concept_code,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT vocabulary_pack.CutConceptSynonymName(rx.str),
	rx.code,
	'VANDF',
	4180186 -- English
FROM sources.rxnconso rx
LEFT JOIN concept_stage cs ON cs.concept_code = rx.code
	AND cs.concept_name = vocabulary_pack.CutConceptSynonymName(rx.str)
WHERE rx.sab = 'VANDF'
	AND rx.tty NOT IN (
		'CD',
		'PT',
		'IN'
		)
	AND cs.concept_code IS NULL;

--6. Fill relationships VANDF to RxNorm
--6.1. Direct mappings to RxNorm:
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
SELECT rx.code AS concept_code_1,
   	c.concept_code AS concept_code_2,
	'VANDF' AS vocabulary_id_1,
	'RxNorm' AS vocabulary_id_2,
	'Maps to' AS relationship_id,
	(SELECT latest_update
	 FROM vocabulary
	 WHERE vocabulary_id = 'VANDF') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept c
JOIN sources.rxnconso rx ON rx.rxcui = c.concept_code
WHERE rx.sab = 'VANDF'
	AND rx.tty IN (
		'CD',
		'PT',
		'IN'
		)
	AND c.vocabulary_id = 'RxNorm'
	AND c.standard_concept = 'S';

--6.2 Use intermediate step:
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
SELECT DISTINCT rx1.code AS concept_code_1,
       c.concept_code AS concept_code_2,
       'VANDF' AS vocabulary_id_1,
       c.vocabulary_id AS vocabulary_id_2,
       'Maps to' AS relationship_id,
       (SELECT latest_update
        FROM vocabulary
        WHERE vocabulary_id = 'VANDF') AS valid_start_date,
       TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
       NULL AS invalid_reason
    FROM sources.rxnconso rx1
    JOIN sources.rxnconso rx2 USING (rxcui)
    JOIN sources.rxnrel r1 on rx1.rxcui = r1.rxcui1
    JOIN concept c on c.concept_code = r1.rxcui2 AND c.vocabulary_id = 'RxNorm' AND c.standard_concept = 'S'
    WHERE rx1.sab = 'VANDF'
      AND rx2.sab = 'RXNORM'
      AND rx1.tty IN
      (
		'CD',
		'PT',
		'IN'
		)
      AND r1.rela = (
          CASE WHEN rx2.tty IN ('SCDFP', 'PIN')
          THEN 'has_form'
              WHEN rx2.tty = 'MIN'
              THEN 'part_of'
             END
        )
  AND NOT EXISTS (SELECT 1
                   FROM concept_relationship_stage crs
                   WHERE crs.concept_code_1 = rx1.code
                   AND crs.vocabulary_id_1 = 'VANDF'
                   AND crs.relationship_id = 'Maps to')
;

--7. Fill relationships VANDF to VA Class
ANALYZE concept_stage;

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
SELECT rx_vandf.code AS concept_code_1,
	cs.concept_code AS concept_code_2,
	'VANDF' AS vocabulary_id_1,
	'VA Class' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM concept_stage cs
JOIN sources.rxnrel rxn ON rxn.rxaui1 = cs.concept_id::TEXT
	AND rxn.sab = 'VANDF'
	AND rxn.rela = 'isa'
JOIN sources.rxnconso rx_vandf ON rx_vandf.rxaui = rxn.rxaui2
	AND rx_vandf.sab = 'VANDF'
	AND rx_vandf.tty = 'CD'
JOIN vocabulary v ON v.vocabulary_id = 'VA Class'
WHERE EXISTS ( --make sure we are working with current VANDF concepts, e.g. if RxNorm was updated in the sources after we loaded VANDF
		SELECT 1
		FROM concept_stage c_int
		WHERE c_int.concept_code = rx_vandf.code
			AND c_int.vocabulary_id = 'VANDF'
		);

--8. Append manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--9. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--10. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--11. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

ANALYZE concept_stage, concept_relationship_stage;

--12. Domain and concept class changes for devices
UPDATE concept_stage cs
SET domain_id = 'Device',
	concept_class_id = 'Device'
--Devices defined according to the hierarchy
WHERE (
		EXISTS (
			SELECT 1
			FROM concept_stage cs1
			JOIN concept_relationship_stage crs ON crs.concept_code_1 = cs1.concept_code
				AND crs.vocabulary_id_1 = cs1.vocabulary_id
				AND crs.invalid_reason IS NULL
			JOIN concept_stage cs2 ON cs2.concept_code = crs.concept_code_2
				AND cs2.vocabulary_id = crs.vocabulary_id_2
				AND cs2.vocabulary_id = 'VA Class'
				AND cs2.concept_code ILIKE '%X%'
			WHERE cs1.vocabulary_id = 'VANDF'
				AND cs1.concept_code = cs.concept_code
			)
		--Concepts with mapping left as Drugs
		AND NOT EXISTS (
			SELECT 1
			FROM concept_stage cs1
			JOIN concept_relationship_stage crs ON crs.concept_code_1 = cs1.concept_code
				AND crs.vocabulary_id_1 = cs1.vocabulary_id
				AND crs.invalid_reason IS NULL
				AND crs.relationship_id = 'Maps to'
			WHERE cs1.vocabulary_id = 'VANDF'
				AND cs1.concept_code = cs.concept_code
			)
		)
	OR cs.concept_code IN (
		'4008894', --ALCOHOL PREP PAD
		'4002991', --AMINOHIPPURATE NA 20% INJ
		'4029900', --BARRIER OINTMENT,CRITIC-AID
		'4029724', --BEDSIDE-CARE CLEANSER
		'4003574', --BENTIROMIDE 500MG/7.5ML SOLN,ORAL
		'4036944', --CLEANSING CLOTH,ADULT W/DIMETHICONE
		'4014161', --CRITIC-AID SKIN PASTE
		'4007681', --DYE EVANS BLUE 5MG/ML INJ
		'4005828', --HISTOPLASMIN 1:100 SKIN TEST INJ
		'4037825', --IOBENGUANE I 131 15MCI/ML INJ,SOLN
		'4002035', --IODAMIDE MEGLUMINE 65% INJ
		'4004348', --IOPANOIC ACID 500MG TAB
		'4007149', --IOPHENDYLATE 100% INJ
		'4009328', --IOTROLAN 190MG/ML INJ INTH
		'4026173', --LANTISEPTIC SKIN PROTECTANT OINT,TOP
		'4026174', --LANTISEPTIC THERAPEUTIC CREAM,TOP
		'4013180', --MANGAFODIPIR TRISODIUM 37.9MG/ML INJ,SOLN
		'4007674', --METHYL METHACRYLATE 100% LIQUID
		'4003558', --PHENOLSULFONPHTHALEIN 6MG/ML INJ
		'4003943', --POTASSIUM PERCHLORATE 200MG CAP
		'4008190', --POVIDONE IODINE 10% PAD
		'4008257', --PROPYLIODONE 60% SUSP
		'4012154', --STRONTIUM-89 CL 148MBq,4mCi/10ML INJ
		'4004195', --TYROPANOATE NA 750MG CAP
		'4042933', --CARTRIDGE,ILET
		'4042708', --ENSURE PLUS W/FIBER LIQUID VANILLA
		'4042668', --PHENYLADE 60
		'4042670', --PHENYLADE 60 POWDER.RENST-ORAL
		'4042556', --DIALYSATE,DUOSOL BICARB 25 4K/0CA BRAUN #4556
		'4042575', --RESERVOIR,SIMPLICITY
		'4042375', --DRESSING,FOAM,DERMABLUE PLUS 2IN X 2IN
	    '4043088', --CARTRIDGE,TANDEM MOBI
	    '4043105', --LANCET, VIVAGUARD SAFETY 28G
	    '4043127', --REMEDY SILICONE CREAM,TOP
	    '4043127', --REMEDY NO-RINSE FOAM,TOP
	    '4043165', --DIMETHICONE SOLN,TOP
	    '4043181', --LUBRICANT,ASTROGLIDE LIQUID,TOP
	    '4043214', --CATHERIZATION SET,FOLEY W/O CATH DYNAREX #4926
	    '4043396', --VIBRATING DEVICE,CONSTIPATION
	    '4043399', --DRESSING,URGOCLEAN SILVER
	    '4043452', --CERVICAL CAP
	    '4043472', --BLOOD/GLUCOSE/LEUKOCYTES/NITRITE/PROTEIN TEST
	    '4043509', --DRESSING,OPTIVIEW
	    '4043621', --STIMULATOR,MUSCLE
	    '4043664', --CHIN-UP
	    '4043850', --LIQUID HOPE PEPTIDE FORMULA
	    '4043851', --LIQUID HOPE PEPTIDE HP FORMULA
	    '4043939', --KATE FARMS 1.0 PEPTIDE LIQUID VANILLA
	    '4044114', --BOOST VHC LIQUID CHOCOLATE
	    '4044281', --CONTACT LENS SOLN (LACRIPURE)
	    '4044307', --THICK & EASY CLEAR (NECTAR) PWDR PKT,1.4GM
	    '4044308', --THICK & EASY CLEAR (HONEY) PWDR,PKT,3.2GM
	    '4044333', --KATE FARMS1.5 PEPTIDE LIQUID VANILLA
	    '4044350', --TWOCAL HN LIQUID,1000ML
	    '4044369', --COMPLEAT ORGANIC BLENDS CHICKEN LIQUID
	    '4044372', --PROSOURCE NO CARB
	    '4044374', --PROSOURCE NO CARB LIQUID,ORAL,30ML NEUTRAL
	    '4044379', --JUVEN PWDR PKT,PINAPPLE COCONUT
	    '4044397', --JUVEN PWDR PKT,PINEAPPLE COCONUT
	    '4043166', --PEGULICIANINE
	    '4043186', --BANATROL TF
	    '4043187', --BANATROL TF LIQUID,PKT
	    '4043924', --CONTACT LENS SOLN (TANGIBLE CLEAN)
	    '4044285', --COMPLEAT STANDARD 1.4 CAL LIQUID VANILLA
	    '4044365', --COMPLEAT STANDARD 1.4 CAL LIQUID 1000ML
	    '4044344', --PUSH 20 PLUS LIQUID,ORAL,37.5ML APPLE
	    '4044366', --PUSH 20 PLUS
	    '4044367', --PUSH 20 PLUS LIQUID,ORAL,37.5ML ORANGE
	    '4044368', --PUSH 20 PLUS LIQUID,ORAL,37.5ML BLCHRY
	    '4044294', --KATE FARMS NUTRITION SHAKE STRAWBERRY
	    '4043828' --KATE FARMS 1.4 LIQUID STRAWBERRY
		);

--13. Assigning standard values for valid devices
UPDATE concept_stage
SET standard_concept = 'S'
WHERE domain_id = 'Device'
	AND invalid_reason IS NULL;

--14. Exclude mappings to RxNorm for Devices
UPDATE concept_relationship_stage crs
SET invalid_reason = 'D',
	valid_end_date = GREATEST(crs.valid_start_date, v.latest_update - 1)
FROM concept_stage cs
JOIN vocabulary v ON v.vocabulary_id = 'VA Class'
WHERE cs.concept_code = crs.concept_code_1
	AND cs.vocabulary_id = crs.vocabulary_id_1
	AND crs.invalid_reason IS NULL
	AND crs.relationship_id = 'Maps to'
	--Exclude mappings only for Standard devices
	AND cs.domain_id = 'Device'
	AND cs.standard_concept = 'S'
	--Excluding mapping to itself, if accidentally present
	AND NOT (
		crs.concept_code_1 = crs.concept_code_2
		AND crs.vocabulary_id_1 = crs.vocabulary_id_2
		);

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script