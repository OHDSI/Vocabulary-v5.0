--Revision of Type and Condition Status concepts [AVOF-2568]
--add new vocabulary='OMOP Type Concept'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Type Concept',
	pVocabulary_name		=> 'OMOP Type Concept',
	pVocabulary_reference	=> 'OMOP generated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> 'Y',
	pClick_default			=> 'Y',
	pAvailable				=> NULL,
	pURL					=> NULL,
	pClick_disabled			=> 'Y'
);
END $_$;

--preparing before de-standardization
--deprecate 'Maps to' to 'Type Concept' with 'S' (incl. self)
UPDATE concept_relationship cr
SET invalid_reason = 'D',
	valid_end_date = CURRENT_DATE
FROM concept c
WHERE cr.relationship_id = 'Maps to'
	AND cr.invalid_reason IS NULL
	AND cr.concept_id_2 = c.concept_id
	AND c.domain_id = 'Type Concept'
	AND c.standard_concept = 'S';

--reverse, deprecate 'Mapped from' from 'Type Concept' with 'S' (incl. self)
UPDATE concept_relationship cr
SET invalid_reason = 'D',
	valid_end_date = CURRENT_DATE
FROM concept c
WHERE cr.relationship_id = 'Mapped from'
	AND cr.invalid_reason IS NULL
	AND cr.concept_id_1 = c.concept_id
	AND c.domain_id = 'Type Concept'
	AND c.standard_concept = 'S';

--set standard_concept = NULL for all current domain_id = 'Type Concept'
UPDATE concept
SET standard_concept = NULL
WHERE domain_id = 'Type Concept'
	AND standard_concept IS NOT NULL;

--add new 'Type Concept' concepts
DO $BODY$
DECLARE
A RECORD;
BEGIN
	FOR A IN (
		SELECT 
		$$DO $_$
			BEGIN
				PERFORM vocabulary_pack.AddNewConcept(
					pConcept_name     =>'$$||s0.new_concepts||$$',
					pDomain_id        =>'Type Concept',
					pVocabulary_id    =>'Type Concept',
					pConcept_class_id =>'Type Concept',
					pStandard_concept =>'S',
					pValid_start_date => CURRENT_DATE
				);
			END $_$;$$ as ddl_code
		FROM (SELECT UNNEST(ARRAY ['Case Report Form', 'Claim', 'Claim authorization', 'Claim discharge record', 'Claim enrolment record', 'Cost record', 'Death Certificate', 'Dental claim',
		'EHR', 'EHR administration record', 'EHR admission note', 'EHR ancillary report', 'EHR billing record', 'EHR chief complaint', 'EHR discharge record', 'EHR discharge summary',
		'EHR dispensing record', 'EHR emergency room note', 'EHR encounter record', 'EHR episode record', 'EHR inpatient note', 'EHR medication list', 'EHR note', 'EHR nursing report',
		'EHR order', 'EHR outpatient note', 'EHR Pathology report', 'EHR physical examination', 'EHR planned dispensing record', 'EHR prescription', 'EHR prescription issue record',
		'EHR problem list', 'EHR radiology report', 'EHR referral record', 'External CDM instance', 'Facility claim', 'Facility claim detail', 'Facility claim header',
		'Geographic isolation record', 'Government report', 'Health Information Exchange record', 'Health Risk Assessment', 'Healthcare professional filled survey', 'Hospital cost',
		'Inpatient claim', 'Inpatient claim detail', 'Inpatient claim header', 'Lab', 'Mail order record', 'NLP', 'Outpatient claim', 'Outpatient claim detail', 'Outpatient claim header',
		'Patient filled survey', 'Patient or payer paid record', 'Patient reported cost', 'Patient self-report', 'Payer system record (paid premium)', 'Payer system record (primary payer)',
		'Payer system record (secondary payer)', 'Pharmacy claim', 'Pre-qualification time period', 'Professional claim', 'Professional claim detail', 'Professional claim header',
		'Provider charge list price', 'Provider financial system', 'Provider incurred cost record', 'Randomization record', 'Reference lab', 'Registry', 'Standard algorithm',
		'Standard algorithm from claims', 'Standard algorithm from EHR', 'Survey', 'Urgent lab', 'US Social Security Death Master File', 'Vision claim']) AS new_concepts) s0
	) LOOP
		EXECUTE A.ddl_code;
	END LOOP;
END $BODY$;

--add some manual 'Is a' and 'Subsumes'
--direct mappings
INSERT INTO concept_relationship
SELECT c1.concept_id AS concept_id_1,
	c2.concept_id AS concept_id_2,
	'Is a' AS relationship_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM
	concept c1
JOIN (
	SELECT concept_name_1, concept_name_2 FROM (
		VALUES ('Claim authorization', 'Claim'),
		('Claim discharge record', 'Claim'),
		('Claim enrolment record', 'Claim'),
		('Dental claim', 'Claim'),
		('EHR administration record', 'EHR'),
		('EHR admission note', 'EHR'),
		('EHR ancillary report', 'EHR'),
		('EHR billing record', 'EHR'),
		('EHR chief complaint', 'EHR'),
		('EHR discharge record', 'EHR'),
		('EHR discharge summary', 'EHR'),
		('EHR dispensing record', 'EHR'),
		('EHR emergency room note', 'EHR'),
		('EHR encounter record', 'EHR'),
		('EHR episode record', 'EHR'),
		('EHR inpatient note', 'EHR'),
		('EHR medication list', 'EHR'),
		('EHR note', 'EHR'),
		('EHR nursing report', 'EHR'),
		('EHR order', 'EHR'),
		('EHR outpatient note', 'EHR'),
		('EHR Pathology report', 'EHR'),
		('EHR physical examination', 'EHR'),
		('EHR planned dispensing record', 'EHR prescription'),
		('EHR prescription', 'EHR'),
		('EHR prescription issue record', 'EHR prescription'),
		('EHR problem list', 'EHR'),
		('EHR radiology report', 'EHR'),
		('EHR referral record', 'EHR'),
		('Facility claim', 'Claim'),
		('Facility claim detail', 'Facility claim'),
		('Facility claim header', 'Facility claim'),
		('Healthcare professional filled survey', 'Survey'),
		('Inpatient claim', 'Claim'),
		('Inpatient claim detail', 'Inpatient claim'),
		('Inpatient claim header', 'Inpatient claim'),
		('Outpatient claim', 'Claim'),
		('Outpatient claim detail', 'Outpatient claim'),
		('Outpatient claim header', 'Outpatient claim'),
		('Patient filled survey', 'Patient self-report'),
		('Patient filled survey', 'Survey'),
		('Patient or payer paid record', 'Cost record'),
		('Patient reported cost', 'Cost record'),
		('Patient reported cost', 'Patient self-report'),
		('Payer system record (paid premium)', 'Cost record'),
		('Payer system record (primary payer)', 'Cost record'),
		('Payer system record (secondary payer)', 'Cost record'),
		('Pharmacy claim', 'Claim'),
		('Professional claim', 'Claim'),
		('Professional claim detail', 'Professional claim'),
		('Professional claim header', 'Professional claim'),
		('Provider charge list price', 'Cost record'),
		('Provider financial system', 'Cost record'),
		('Provider incurred cost record', 'Cost record'),
		('Reference lab', 'Lab'),
		('Standard algorithm from claims', 'Standard algorithm'),
		('Standard algorithm from EHR', 'Standard algorithm'),
		('Urgent lab', 'Lab'),
		('Vision claim', 'Claim')
	) AS v (concept_name_1, concept_name_2)
) AS j ON j.concept_name_1=c1.concept_name
JOIN concept c2 ON c2.concept_name=j.concept_name_2 and c2.vocabulary_id='Type Concept'
WHERE c1.vocabulary_id='Type Concept';

--reverse mappings
INSERT INTO concept_relationship
SELECT c2.concept_id AS concept_id_1,
	c1.concept_id AS concept_id_2,
	'Subsumes' AS relationship_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM
	concept c1
JOIN (
	SELECT concept_name_1, concept_name_2 FROM (
		VALUES ('Claim authorization', 'Claim'),
		('Claim discharge record', 'Claim'),
		('Claim enrolment record', 'Claim'),
		('Dental claim', 'Claim'),
		('EHR administration record', 'EHR'),
		('EHR admission note', 'EHR'),
		('EHR ancillary report', 'EHR'),
		('EHR billing record', 'EHR'),
		('EHR chief complaint', 'EHR'),
		('EHR discharge record', 'EHR'),
		('EHR discharge summary', 'EHR'),
		('EHR dispensing record', 'EHR'),
		('EHR emergency room note', 'EHR'),
		('EHR encounter record', 'EHR'),
		('EHR episode record', 'EHR'),
		('EHR inpatient note', 'EHR'),
		('EHR medication list', 'EHR'),
		('EHR note', 'EHR'),
		('EHR nursing report', 'EHR'),
		('EHR order', 'EHR'),
		('EHR outpatient note', 'EHR'),
		('EHR Pathology report', 'EHR'),
		('EHR physical examination', 'EHR'),
		('EHR planned dispensing record', 'EHR prescription'),
		('EHR prescription', 'EHR'),
		('EHR prescription issue record', 'EHR prescription'),
		('EHR problem list', 'EHR'),
		('EHR radiology report', 'EHR'),
		('EHR referral record', 'EHR'),
		('Facility claim', 'Claim'),
		('Facility claim detail', 'Facility claim'),
		('Facility claim header', 'Facility claim'),
		('Healthcare professional filled survey', 'Survey'),
		('Inpatient claim', 'Claim'),
		('Inpatient claim detail', 'Inpatient claim'),
		('Inpatient claim header', 'Inpatient claim'),
		('Outpatient claim', 'Claim'),
		('Outpatient claim detail', 'Outpatient claim'),
		('Outpatient claim header', 'Outpatient claim'),
		('Patient filled survey', 'Patient self-report'),
		('Patient filled survey', 'Survey'),
		('Patient or payer paid record', 'Cost record'),
		('Patient reported cost', 'Cost record'),
		('Patient reported cost', 'Patient self-report'),
		('Payer system record (paid premium)', 'Cost record'),
		('Payer system record (primary payer)', 'Cost record'),
		('Payer system record (secondary payer)', 'Cost record'),
		('Pharmacy claim', 'Claim'),
		('Professional claim', 'Claim'),
		('Professional claim detail', 'Professional claim'),
		('Professional claim header', 'Professional claim'),
		('Provider charge list price', 'Cost record'),
		('Provider financial system', 'Cost record'),
		('Provider incurred cost record', 'Cost record'),
		('Reference lab', 'Lab'),
		('Standard algorithm from claims', 'Standard algorithm'),
		('Standard algorithm from EHR', 'Standard algorithm'),
		('Urgent lab', 'Lab'),
		('Vision claim', 'Claim')
	) AS v (concept_name_1, concept_name_2)
) AS j ON j.concept_name_1=c1.concept_name
JOIN concept c2 ON c2.concept_name=j.concept_name_2 and c2.vocabulary_id='Type Concept'
WHERE c1.vocabulary_id='Type Concept';

--add new vocabulary='OMOP Condition Status'
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddNewVocabulary(
	pVocabulary_id			=> 'Condition Status',
	pVocabulary_name		=> 'OMOP Condition Status',
	pVocabulary_reference	=> 'OMOP generated',
	pVocabulary_version		=> NULL,
	pOMOP_req				=> 'Y',
	pClick_default			=> 'Y',
	pAvailable				=> NULL,
	pURL					=> NULL,
	pClick_disabled			=> 'Y'
);
END $_$;

--add new concept_class='OMOP Condition Status'
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewConceptClass(
		pConcept_class_id		=>'Condition Status',
		pConcept_class_name		=>'OMOP Condition Status'
	);
END $_$;

--add new domain='OMOP Condition Status'
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewDomain(
		pDomain_id		=>'Condition Status',
		pDomain_name	=>'OMOP Condition Status'
	);
END $_$;

--add new 'Condition Status' concepts
DO $BODY$
DECLARE
A RECORD;
BEGIN
	FOR A IN (
		SELECT 
		$$DO $_$
			BEGIN
				PERFORM vocabulary_pack.AddNewConcept(
					pConcept_name     =>'$$||s0.new_concepts||$$',
					pDomain_id        =>'Condition Status',
					pVocabulary_id    =>'Condition Status',
					pConcept_class_id =>'Condition Status',
					pStandard_concept =>'S',
					pValid_start_date => CURRENT_DATE
				);
			END $_$;$$ as ddl_code
		FROM (SELECT UNNEST(ARRAY ['Admission diagnosis', 'Cause of death', 'Condition to be diagnosed by procedure', 'Confirmed diagnosis', 'Contributory cause of death',
		'Death diagnosis', 'Discharge diagnosis', 'Immediate cause of death', 'Postoperative diagnosis', 'Preliminary diagnosis', 'Preoperative diagnosis', 'Primary admission diagnosis',
		'Primary diagnosis', 'Primary discharge diagnosis', 'Primary referral diagnosis', 'Referral diagnosis', 'Resolved condition', 'Secondary admission diagnosis',
		'Secondary diagnosis', 'Secondary discharge diagnosis', 'Secondary referral diagnosis', 'Underlying cause of death']) AS new_concepts) s0
	) LOOP
		EXECUTE A.ddl_code;
	END LOOP;
END $BODY$;

--add some manual 'Is a' and 'Subsumes'
--direct mappings
INSERT INTO concept_relationship
SELECT c1.concept_id AS concept_id_1,
	c2.concept_id AS concept_id_2,
	'Is a' AS relationship_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM
	concept c1
JOIN (
	SELECT concept_name_1, concept_name_2 FROM (
		VALUES ('Cause of death', 'Death diagnosis'),
		('Contributory cause of death', 'Cause of death'),
		('Immediate cause of death', 'Cause of death'),
		('Primary admission diagnosis', 'Admission diagnosis'),
		('Primary admission diagnosis', 'Primary diagnosis'),
		('Primary discharge diagnosis', 'Discharge diagnosis'),
		('Primary discharge diagnosis', 'Primary diagnosis'),
		('Primary referral diagnosis', 'Referral diagnosis'),
		('Primary referral diagnosis', 'Primary diagnosis'),
		('Secondary admission diagnosis', 'Admission diagnosis'),
		('Secondary admission diagnosis', 'Secondary diagnosis'),
		('Secondary discharge diagnosis', 'Discharge diagnosis'),
		('Secondary discharge diagnosis', 'Secondary diagnosis'),
		('Secondary referral diagnosis', 'Referral diagnosis'),
		('Secondary referral diagnosis', 'Secondary diagnosis'),
		('Underlying cause of death', 'Cause of death')
	) AS v (concept_name_1, concept_name_2)
) AS j ON j.concept_name_1=c1.concept_name
JOIN concept c2 ON c2.concept_name=j.concept_name_2 and c2.vocabulary_id='Condition Status'
WHERE c1.vocabulary_id='Condition Status';

--reverse mappings
INSERT INTO concept_relationship
SELECT c2.concept_id AS concept_id_1,
	c1.concept_id AS concept_id_2,
	'Subsumes' AS relationship_id,
	CURRENT_DATE AS valid_start_date,
	TO_DATE('20991231', 'yyyymmdd') AS valid_end_date,
	NULL AS invalid_reason
FROM
	concept c1
JOIN (
	SELECT concept_name_1, concept_name_2 FROM (
		VALUES ('Cause of death', 'Death diagnosis'),
		('Contributory cause of death', 'Cause of death'),
		('Immediate cause of death', 'Cause of death'),
		('Primary admission diagnosis', 'Admission diagnosis'),
		('Primary admission diagnosis', 'Primary diagnosis'),
		('Primary discharge diagnosis', 'Discharge diagnosis'),
		('Primary discharge diagnosis', 'Primary diagnosis'),
		('Primary referral diagnosis', 'Referral diagnosis'),
		('Primary referral diagnosis', 'Primary diagnosis'),
		('Secondary admission diagnosis', 'Admission diagnosis'),
		('Secondary admission diagnosis', 'Secondary diagnosis'),
		('Secondary discharge diagnosis', 'Discharge diagnosis'),
		('Secondary discharge diagnosis', 'Secondary diagnosis'),
		('Secondary referral diagnosis', 'Referral diagnosis'),
		('Secondary referral diagnosis', 'Secondary diagnosis'),
		('Underlying cause of death', 'Cause of death')
	) AS v (concept_name_1, concept_name_2)
) AS j ON j.concept_name_1=c1.concept_name
JOIN concept c2 ON c2.concept_name=j.concept_name_2 and c2.vocabulary_id='Condition Status'
WHERE c1.vocabulary_id='Condition Status';