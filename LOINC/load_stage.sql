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
* Date: 2017
**************************************************************************/

--1. Update latest_update field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'LOINC',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.loinc LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.loinc LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_LOINC'
);
END $_$;

--2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

------------------------
-----CONCEPT_STAGE------
------------------------
--3. Load LOINC concepts indicating Measurements or Observations from the source table of 'sources.loinc' into the CONCEPT_STAGE 
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
SELECT 
   CASE WHEN loinc_num = '66678-4' AND property = 'Hx' AND c.vocabulary_id = 'LOINC' 
	    THEN 'History of Diabetes (regardless of treatment) [PhenX]'
		WHEN loinc_num = '82312-0' 
	    THEN 'History of ' ||REPLACE(long_common_name,'andor','and/or')
		WHEN property = 'Hx' AND   c.vocabulary_id = 'LOINC' AND   long_common_name !~* 'hx|histor|reported|status|narrative|^do you|^have you|^does|^has |education|why you|timing|virtuoso|maestro|grade|received|cause|allergies|in the past'
      THEN 'History of '||long_common_name
   	ELSE long_common_name -- AVOF-819
	  END AS concept_name,
	 CASE WHEN CLASSTYPE IN ('1','2') 
	      AND  (survey_quest_text ~ '\?'
	      	   OR scale_typ = 'Set' 
	      	   OR property IN ('Hx','Addr','Anat','ClockTime','Date','DateRange','Desc','EmailAddr','Instrct','Loc','Pn','Tele','TmStp','TmStpRange','Txt','URI','Xad','Bib') 
	      	   OR (property = 'ID' and system in ('^BPU', '^Patient', 'Vaccine'))
	      	   OR system IN ('^Family member','^Neighborhood','^Brother','^Daughter','^Sister','^Son','^CCD','^Census tract','^Clinical trial protocol', '^Community','*','?','^Contact','^Donor','^Emergency contact','^Event','^Facility', 'Provider', 'Report',  'Repository', 'School', 'Surgical procedure') 
	      	   OR (system IN ('^Patient','*^Patient') AND (scale_typ  IN ('Doc', 'Nar','Nom', 'Ord', 'OrdQn') AND (method_typ NOT IN  ('Apgar') OR method_typ IS NULL) 
	      	   OR property IN ('Arb','Imp','NRat','Num','PrThr','RelRto','Time','Type','Find') AND class NOT IN ('COAG','PULM'))
	      ))
	      AND (long_common_name !~* 'scale|score'  OR long_common_name ~* 'interpretation|rose dyspnea scale')   
	      AND (method_typ != 'Measured' OR method_typ IS NULL)
	      AND loinc_num NOT IN ('65712-2', '65713-0')
	    THEN 'Observation'
		WHEN CLASSTYPE = '1'
			THEN 'Measurement'
		WHEN CLASSTYPE = '2'
			THEN 'Measurement'
		WHEN CLASSTYPE = '3'
			THEN 'Observation'
		WHEN CLASSTYPE = '4'
			THEN 'Observation'
		END AS domain_id,
	v.vocabulary_id,
	CASE WHEN CLASSTYPE IN ('1','2') 
	      AND  (survey_quest_text ~ '\?'
	      	   OR scale_typ = 'Set' 
	      	   OR property IN ('Hx','Addr','Anat','ClockTime','Date','DateRange','Desc','EmailAddr','Instrct','Loc','Pn','Tele','TmStp','TmStpRange','Txt','URI','Xad','Bib') 
	      	   OR (property = 'ID' and system in ('^BPU', '^Patient', 'Vaccine'))
	      	   OR system IN ('^Family member','^Neighborhood','^Brother','^Daughter','^Sister','^Son','^CCD','^Census tract','^Clinical trial protocol', '^Community','*','?','^Contact','^Donor','^Emergency contact','^Event','^Facility', 'Provider', 'Report',  'Repository', 'School', 'Surgical procedure') 
	      	   OR (system IN ('^Patient','*^Patient') AND (scale_typ  IN ('Doc', 'Nar','Nom', 'Ord', 'OrdQn') AND (method_typ NOT IN  ('Apgar') OR method_typ IS NULL) 
	      	   OR property IN ('Arb','Imp','NRat','Num','PrThr','RelRto','Time','Type','Find') AND class NOT IN ('COAG','PULM'))
	      ))
	      AND (long_common_name !~* 'scale|score'  OR long_common_name ~* 'interpretation|rose dyspnea scale')   
	      AND (method_typ != 'Measured' OR method_typ IS NULL)
	      AND loinc_num NOT IN ('65712-2', '65713-0')
	    THEN 'Clinical Observation'
		WHEN CLASSTYPE = '1'
			THEN 'Lab Test'
		WHEN CLASSTYPE ='2'
			THEN 'Clinical Observation'
		WHEN CLASSTYPE ='3'
			THEN 'Claims Attachment'
		WHEN CLASSTYPE ='4'
			THEN 'Survey'
		END AS concept_class_id,
	'S' AS standard_concept,
	LOINC_NUM AS concept_code,
	COALESCE(c.valid_start_date, v.latest_update) AS valid_start_date,
	CASE 
		WHEN STATUS IN (
				'DISCOURAGED',
				'DEPRECATED'
				)
			THEN CASE 
					WHEN C.VALID_END_DATE > V.LATEST_UPDATE
						OR C.VALID_END_DATE IS NULL
						THEN V.LATEST_UPDATE
					ELSE C.VALID_END_DATE
					END
		ELSE TO_DATE('20991231', 'yyyymmdd')
		END AS valid_end_date,
	CASE 
		WHEN EXISTS (
				SELECT 1
				FROM sources.map_to m
				WHERE m.loinc = l.loinc_num
				)
			THEN 'U'
		WHEN STATUS = 'DISCOURAGED'
			THEN 'D'
		WHEN STATUS = 'DEPRECATED'
			THEN 'D'
		ELSE NULL
		END AS invalid_reason
FROM sources.loinc l
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
LEFT JOIN concept c ON c.concept_code = l.LOINC_NUM
	AND c.vocabulary_id = 'LOINC' ; 

--4. Add LOINC Classes from the manual table of 'sources.loinc_class' into the CONCEPT_STAGE
INSERT INTO concept_stage
 (
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
 SELECT concept_name,
 CASE  WHEN concept_name ~* 'history|report|document|miscellaneous|public health'
    THEN 'Observation' else domain_id end,
    vocabulary_id,
    concept_class_id,
    'C',
    concept_code,
    valid_start_date,
	valid_end_date,
	invalid_reason
  FROM sources.loinc_class -- 300
/*--for some reason we have a deficit of source classes (98 classes are absent:
select distinct  class from sources.loinc where class not  in (select distinct concept_code  from  sources.loinc_class)) -- in the future we should add full list of missed classes*/ 
-- add DOCUMENT ONTOLOGY CLASS 
UNION 
select 'Document Ontology' as concept_name, 
'Observation' as domain_id ,
'LOINC' as vocabulary_id , 
'LOINC Class' as concept_class_id, 
'C' as standard_concept,
'DOC.ONTOLOGY' as concept_code, 
'1970-01-01' as valid_start_date,
'2099-12-31' as valid_end_date,
null as invalid_reason
;

--5. Add LOINC Hierarchy concepts (code ~ '^LP'') from the source table of 'sources.loinc_hierarchy' into the CONCEPT_STAGE
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
SELECT DISTINCT SUBSTR(code_text, 1, 255) AS concept_name,
	CASE 
		WHEN (code_text ~* 'directive|^age\s+|lifetime risk|alert|attachment|\s+date|comment|\s+note|consent|identifier|\s+time|\s+number' 
          or code_text ~* 'date and time|coding system|interpretation|status|\s+name|\s+report|\s+id$|s+id\s+|version|instruction|known exposure|priority|ordered|available|requested|issued|flowsheet|\s+term'
          or code_text ~* 'reported|not yet categorized|performed|risk factor|device|administration|\s+route$|suggestion|recommended|narrative|ICD code|reference'
          or code_text ~* 'reviewed|information|intention|^Reason for|^Received|Recommend|provider|subject|summary|time\s+') 
         and code_text !~* 'thrombin time|clotting time|bleeding time|clot formation|kaolin activated time|closure time|protein feed time|Recalcification time|reptilase time|russell viper venom time'
         and code_text !~* 'implanted device|dosage\.vial|isolate|within lymph node|cncer specimen|tumor|chromosome|inversion|bioavailable' -- manually defined word patterns 
         and code ~ '^LP'
			THEN 'Observation' 
		ELSE 'Measurement'
		END AS domain_id,
	'LOINC' AS vocabulary_id,
	'LOINC Hierarchy' AS concept_class_id,
	'C' AS standart_concept,
	code AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_hierarchy
WHERE code LIKE 'LP%'; -- all LOINC Hierarchy concepts have 'LP' in the beginning of a name

/*UNION 
-- add Documentt Ontology concpet to preserve a hierarchy of Document Kind class 
SELECT 'Document ontology' as concept_name,  -- new_part! 'Document ontology' 'LP76352-1' classification concepts is considered to be superior in the hierarchy, but it is absent in the source
'Observation' as domain_id,
'LOINC' AS vocabulary_id,
	'LOINC Hierarchy' AS concept_class_id,
'C' AS standart_concept,
'LP76352-1' as concept_code,
TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason; */

----------------------------------
----COCNEPT_RELATIONSHIP_STAGE----
----------------------------------
--6. Build 'Subsumes' relationships from LOINC Ancestors to Descendants using the sorce table of 'sources.loinc_hierarchy'
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT immediate_parent AS concept_code_1, -- LOINC Ancestor
	code AS concept_code_2, -- LOINC Descendant
	'Subsumes' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_hierarchy
WHERE immediate_parent IS NOT NULL -- when immediate_parent is null then there is no Ancestor
;  
/*
--add 'Subsumes' relationships from 'Documet Ontology' concept to its children taken from LOINC User's Guide 
UNION
SELECT  'LP76352-1' as concept_code_1, 
partnumber as concept_code_2,
'Subsumes' as relationship_id, 
'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
	from (select distinct partnumber   -- list of Documents from LOINC User's Guide (6.3.1 Kind of Document, p.73)
	from sources.loinc_documentontology 
	where partnumber in ('LP173387-4', 'LP173409-6' , 'LP200111-5', 'LP173414-6', 'LP173415-3', 'LP181112-6', 'LP181116-7', 'LP173417-9' , 'LP204161-6', 'LP173418-7', 'LP181207-4', 'LP173421-1'))t1
;  */

--7. Build 'Subsumes' relationships between LOINC Classes using the sorce table of 'sources.loinc_class' and a similarity of a class name beginning (ancestor class_name LIKE descendant class_name || '%'). 
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT l2.concept_code AS concept_code_1, -- LOINC Class Ancestor
	l1.concept_code AS concept_code_2, -- LOINC Class Descendant
	'Subsumes' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_class l1,
	sources.loinc_class l2
WHERE l1.concept_code LIKE l2.concept_code || '%'
	AND l1.concept_code <> l2.concept_code
UNION
--add 'Subsumes' from Document 'DOC' to  Document Ontology Class 'DOC.ONTOLOGY' manually to preserve Document Ontology Hierarhy
SELECT 'DOC' as concept_code_1,
'DOC.ONTOLOGY' as concept_code_2, 
	'Subsumes' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason;
	

--8. Build 'Subsumes' relationships from LOINC Classes to LOINC concepts indicating Measurements or Observations with the use of source tables of 'sources.loinc_class' and  'sources.loinc' to create Multiaxial Hierarchy 
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT l.class AS concept_code_1, -- LOINC Class concept
	l.loinc_num AS concept_code_2, -- LOINC Observation/Measurement concept
	'Subsumes' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_class lc,
	sources.loinc l
WHERE lc.concept_code = l.class; 

--8.1 Delete wrong relationship between  'PANEL.H' class (History & Physical order set) and 38213-5 FLACC pain assessment panel (AVOF-352) (chr(38)=&) 
DELETE
FROM concept_relationship_stage
WHERE concept_code_1 = 'PANEL.H' || chr(38) || 'P'
	AND concept_code_2 = '38213-5'
	AND relationship_id = 'Subsumes'
	;  
--9. Add to the CONCEPT_SYNONYM_STAGE all synonymical names from the source table of  'sources.loinc' 
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	) (
	--values of a 'RelatedNames2' field
	SELECT loinc_num AS synonym_concept_code,
	SUBSTR(relatednames2, 1, 1000) AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
	FROM sources.loinc WHERE relatednames2 IS NOT NULL
	
UNION
-- values of a 'consumer_name' field that were previously used as preffered name in 195 cases
	SELECT LOINC_NUM AS synonym_concept_code,
	consumer_name AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
	FROM sources.loinc 
	where consumer_name IS NOT NULL
	
UNION
--  values of the 'ShortName' field
	SELECT loinc_num AS synonym_concept_code,
	shortname AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
	FROM sources.loinc WHERE shortname IS NOT NULL
	
UNION 
--  'long_common_name' field  values which were changed ('History of')
SELECT loinc_num AS synonym_concept_code,
	long_common_name AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
	FROM sources.loinc  
	where long_common_name not in (select concept_name from concept_stage) 
	)
; -- We do not add synonyms for Answers ('description' field) due to their vague formulation


--10. Add LOINC Answers from the 'sources.loinc_answerslist' and  'sources.loinc_answerslistlink' source tables to the CONCEPT_STAGE
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
SELECT DISTINCT ans_l.displaytext AS concept_name,
	'Meas Value' AS domain_id,
	'LOINC' AS vocabulary_id,
	'Answer' AS concept_class_id,
	'S' AS standard_concept,
	ans_l.answerstringid AS concept_code,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_answerslist ans_l -- Answer containing table
JOIN sources.loinc_answerslistlink ans_l_l ON ans_l_l.answerlistid = ans_l.answerlistid -- 'AnswerListID' field unites Answers with Questions 
JOIN sources.loinc l ON l.loinc_num = ans_l_l.loincnumber -- to confirm the connection of 'AnswerListID' with LOINC concepts indicating Measurements and Observations (currently, all of them are connected)
WHERE ans_l.answerstringid IS NOT NULL --'AnswerStringID' value may be null
; 

--11.  Build 'Has Answer' relationships from LOINC Questions to Answers with the use of such source tables as 'sources.loinc_answerslist' and 'sources.loinc_answerslistlink'
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT ans_l_l.loincnumber AS concept_code_1, -- LOINC Question code
	ans_l.answerstringid AS concept_code_2, -- LOINC Answer code
	'Has Answer' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_answerslist ans_l  -- Answer containing table
JOIN sources.loinc_answerslistlink ans_l_l ON ans_l_l.answerlistid = ans_l.answerlistid -- 'AnswerListID' field unites Answers with Questions 
WHERE ans_l.answerstringid IS NOT NULL -- 'AnswerStringID' may be empty
;

--12. Build 'Panel contains' relationships from LOINC Panels to their descendants with the use of 'sources.loinc_forms' table
INSERT INTO concept_relationship_stage (
	concept_code_1,
	concept_code_2,
	relationship_id,
	vocabulary_id_1,
	vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT DISTINCT parentloinc AS concept_code_1, -- LOINC Panel code
	loinc AS concept_code_2, -- LOINC Descendant code
	'Panel contains' AS relationship_id,
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	TO_DATE('19700101', 'yyyymmdd') AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_forms -- Panel containing table
WHERE loinc <> parentloinc -- to exclude cases when parent and child are represented by the same concept 
; 

--13. Build 'LOINC - SNOMED eq' relationships from LOINC Measurements to  '45767644 LOINC Code System' SNOMED concept  with the use of a 'sources.scccrefset_mapcorrorfull_int' table  (mappings) 
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
SELECT DISTINCT l.maptarget AS concept_code_1, -- LOINC code
	l.referencedcomponentid AS concept_code_2, -- SNOMED code
	'LOINC' AS vocabulary_id_1,
	'SNOMED' AS vocabulary_id_2,
	'LOINC - SNOMED eq' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.scccrefset_mapcorrorfull_int l,
	vocabulary v
WHERE v.vocabulary_id = 'LOINC'
; 


--14. Build 'LOINC - CPT4 eq' relationships  (mappings) from LOINC Measurements to CPT4 Measurements or Procedures with the use of a 'sources.cpt_mrsmap' table  (mappings) 
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
SELECT l.fromexpr AS concept_code_1, -- LOINC code
	UNNEST(STRING_TO_ARRAY(l.toexpr, ',')) AS concept_code_2, -- CPT4 code
	'LOINC' AS vocabulary_id_1,
	'CPT4' AS vocabulary_id_2,
	'LOINC - CPT4 eq' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.cpt_mrsmap l,
	vocabulary v
WHERE v.vocabulary_id = 'LOINC'
; 

--15. Build 'Concept replaced by' relationships for updated LOINC concepts and deprecate already existing replacing mappings with the use of a 'sources.map_to' table 
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
SELECT l.loinc AS concept_code_1, -- updated LOINC concept 
	l.map_to AS concept_code_2, -- replacing LOINC concept 
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	'Concept replaced by' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.map_to l,
	vocabulary v
WHERE v.vocabulary_id = 'LOINC'

UNION ALL
--for some pairs of concepts LOINC gives us a reverse mapping 'Concept replaced by' so we need to deprecate such old mappings 
SELECT c1.concept_code,
	c2.concept_code, 
	c1.vocabulary_id,
	c2.vocabulary_id,
	r.relationship_id, 
	r.valid_start_date,
	(
		SELECT latest_update - 1
		FROM vocabulary
		WHERE vocabulary_id = 'LOINC'
			AND latest_update IS NOT NULL
		),
	'D'
FROM concept c1,
	concept c2,
	concept_relationship r, 
	sources.map_to mt
WHERE c1.concept_id = r.concept_id_1
	AND c2.concept_id = r.concept_id_2
	AND c1.vocabulary_id = 'LOINC'
	AND c2.vocabulary_id = 'LOINC'
	AND r.relationship_id IN (
		'Concept replaced by',
		'Maps to'
		)
	AND r.invalid_reason IS NULL
	AND mt.map_to = c1.concept_code 
	AND mt.loinc = c2.concept_code;
; 
	
--16. Add LOINC Document Ontology concepts with the use of a 'sources.loinc_documentontology' table to the CONCEPT_STAGE
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
SELECT DISTINCT d.partname AS concept_name, -- LOINC Document name
	'Meas Value' AS domain_id,
	'LOINC' AS vocabulary_id,
	CASE d.parttypename
		WHEN 'Document.TypeOfService'
			THEN 'Doc Type of Service'
		WHEN 'Document.SubjectMatterDomain'
			THEN 'Doc Subject Matter'
		WHEN 'Document.Role'
			THEN 'Doc Role'
		WHEN 'Document.Setting'
			THEN 'Doc Setting'
		WHEN 'Document.Kind'
			THEN 'Doc Kind'
		END AS concept_class_id,
	'S' AS standard_concept, -- LOINC Document code
	d.partnumber AS concept_code,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_documentontology d,
	vocabulary v
WHERE v.vocabulary_id = 'LOINC'
	AND d.partname NOT LIKE '{%}' -- decision to exclude  LP173061-5 '{Settings}' and LP187187-2 '{Role}' partnames was probably made due to vague reverse relationship formulations: Concept X 'Has setting' '{Setting}' or Concept Y 'Has role' {Role}. 
	-- But we lost such relations for 2163 concepts (partnumber).
	; 
--select * from sources.loinc_documentontology where  partname  LIKE '{%}'  ;


--17. Build  'Has type of service',  'Has subject matter', 'Has role',  'Has setting', 'Has kind'  reverse relationships  from LOINC concepts indicating Measurements or Observations to LOINC Document Ontology concepts
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
SELECT d.loincnumber AS concept_code_1, -- LOINC Meas/Obs code
	d.partnumber AS concept_code_2, -- LOINC Document code
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	CASE d.parttypename
		WHEN 'Document.TypeOfService'
			THEN 'Has type of service'
		WHEN 'Document.SubjectMatterDomain'
			THEN 'Has subject matter'
		WHEN 'Document.Role'
			THEN 'Has role'
		WHEN 'Document.Setting'
			THEN 'Has setting'
		WHEN 'Document.Kind'
			THEN 'Has kind'
		END AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_documentontology d,
	vocabulary v
WHERE v.vocabulary_id = 'LOINC'
	AND d.partname NOT LIKE '{%}'; 

--18. Add LOINC Group Category and Group hierarchycal concepts to the CONCEPT_STAGE
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
--add LOINC Gruop Categories
SELECT DISTINCT lgt.category AS concept_name, -- LOINC Category name from sources.loinc_grouploincterms
	'Measurement' AS domain_id,
	v.vocabulary_id AS vocabulary_id,
	'LOINC Group' AS concept_class_id,
	'C' AS standard_concept,
	lg.parentgroupid AS concept_code, -- LOINC Category code from sources.loinc_group
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_group lg -- table with codes for LOINC Category concepts
JOIN sources.loinc_grouploincterms lgt ON lg.groupid = lgt.groupid -- table with names for OINC Category concepts
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
WHERE lgt.category IS NOT NULL

UNION ALL
--add LOINC Groups
SELECT lg.lgroup AS concept_name, -- LOINC Group name
	'Measurement' AS domain_id,
	v.vocabulary_id AS vocabulary_id,
	'LOINC Group' AS concept_class_id,
	'C' AS standard_concept,
	lg.groupid AS concept_code, -- LOINC Group code
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_group lg
JOIN vocabulary v ON v.vocabulary_id = 'LOINC' -- what should we do with concepts where a 'status' field = 'Inaсtive'? 'D'?
; 

--19. Build 'Is a' relationships to create a hierarchy for LOINC Group Categories and Groups 
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
	--19.1 from LOINC concepts indicating Measurements and Observations to LOINC Groups using sources.loinc_grouploincterms
SELECT lgt.loincnumber AS concept_code_1, -- LOINC Observation or Measurement concepts 
	lgt.groupid AS concept_code_2, --LOINC Group code
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_grouploincterms lgt
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
JOIN concept_stage cs1 ON cs1.concept_code = lgt.groupid --LOINC Group code
JOIN concept_stage cs2 ON cs2.concept_code = lgt.loincnumber  -- LOINC Observation or Measurement concepts 

UNION ALL
	--19.2 from LOINC Groups to LOINC Group Categories using sources.loinc_group
SELECT lg.groupid AS concept_code_1, -- LOINC Group code as a descendant
	lg.parentgroupid AS concept_code_2, -- LOINC Group Category code as an ancestor
	'LOINC' AS vocabulary_id_1,
	'LOINC' AS vocabulary_id_2,
	'Is a' AS relationship_id,
	v.latest_update AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM sources.loinc_group lg
JOIN vocabulary v ON v.vocabulary_id = 'LOINC'
JOIN concept_stage cs1 ON cs1.concept_code = lg.parentgroupid  -- LOINC Group Category code 
JOIN concept_stage cs2 ON cs2.concept_code = lg.groupid -- LOINC Group code
; 

--20. Add LOINC Group Categories and Groups to the CONCEPT_SYNONYM_STAGE
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
	---- the decision to add LOINC Group Categories and Groups categories as concept_synonym names was probably made to simplify perception of their long descriptions (?)
	-- add proper name of LOINC Group Categories and Groups 
SELECT cs.concept_code AS synonym_concept_code, -- proper name of LOINC Group Categories and Groups 
	cs.concept_name AS synonym_name,
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM concept_stage cs
WHERE cs.concept_class_id = 'LOINC Group'

UNION
-- add long descriptions of LOINC Group Categories and Groups 
SELECT lpga.parentgroupid AS synonym_concept_code, -- LOINC Group Category code
	SUBSTR(lpga.lvalue, 1, 1000) AS synonym_name, -- long description of LOINC Group Categories 
	'LOINC' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM sources.loinc_parentgroupattributes lpga -- table with descriptions of LOINC Group Categories 
; 

--21. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--22. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--23. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
END $_$;

--24. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;