/**************************************************************************
* Copyright 2016 Observational Health Data Sciences AND Informatics (OHDSI)
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
* Authors: Timur Vakhitov, Christian Reich, Anna Ostropolets, Dmitry Dymshyts
* Date: 2017
**************************************************************************/

--1. UPDATE latest_UPDATE field to new date 
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'HCPCS',
	pVocabularyDate			=> (SELECT vocabulary_date FROM sources.anweb_v2 LIMIT 1),
	pVocabularyVersion		=> (SELECT vocabulary_version FROM sources.anweb_v2 LIMIT 1),
	pVocabularyDevSchema	=> 'DEV_HCPCS'
);
END $_$;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
TRUNCATE TABLE pack_content_stage;
TRUNCATE TABLE drug_strength_stage;

--3. Create concept_stage from HCPCS
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
SELECT TRIM(SUBSTR(long_description, 1, 255)) AS concept_name,
	c.domain_id AS domain_id,
	v.vocabulary_id,
	CASE 
		WHEN LENGTH(hcpc) = 2
			THEN 'HCPCS Modifier'
		ELSE 'HCPCS'
		END AS concept_class_id,
	CASE 
		WHEN term_dt IS NOT NULL
			AND xref1 IS NOT NULL -- !!means the concept is updated
			THEN NULL
		ELSE 'S' -- in other cases it's standard because of the new deprecation logic
		END AS standard_concept,
	HCPC AS concept_code,
	COALESCE(add_date, act_eff_dt) AS valid_start_date,
	COALESCE(term_dt, TO_DATE('20991231', 'yyyymmdd')) AS valid_end_date,
	CASE 
		WHEN term_dt IS NULL
			THEN NULL
		WHEN xref1 IS NULL
			THEN NULL -- deprecated, but leave alive
		ELSE 'U' -- upgraded
		END AS invalid_reason
FROM sources.anweb_v2 a
JOIN vocabulary v ON v.vocabulary_id = 'HCPCS'
LEFT JOIN concept c ON c.concept_code = a.betos
	AND c.concept_class_id = 'HCPCS Class'
	AND c.vocabulary_id = 'HCPCS';

--3.1 Insert existing concepts that are not covered by concept_stage
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
SELECT c.concept_name,
	c.domain_id,
	c.vocabulary_id,
	c.concept_class_id,
	CASE 
		WHEN coalesce(c.invalid_reason, 'D') = 'D'
			AND c.concept_class_id = 'HCPCS'
			THEN 'S'
		ELSE c.standard_concept
		END AS standard_concept,
	c.concept_code,
	c.valid_start_date,
	c.valid_end_date,
	CASE 
		WHEN c.invalid_reason = 'D'
			AND c.concept_class_id = 'HCPCS'
			THEN NULL
		ELSE c.invalid_reason
		END AS invalid_reason
FROM concept c
WHERE c.vocabulary_id = 'HCPCS'
	AND NOT EXISTS (
		SELECT 1
		FROM concept_stage cs_int
		WHERE cs_int.concept_code = c.concept_code
		)
	AND NOT EXISTS (
		SELECT 1
		FROM concept c_int
		WHERE c_int.concept_code = c.concept_code
			AND c_int.vocabulary_id = 'CDT'
		);

--3.2 Insert missing codes from manual extraction [possible temporary solution]
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
SELECT *
FROM dev_hcpcs.concept_stage_manual m
WHERE NOT EXISTS (
		SELECT concept_code
		FROM concept_stage cs_int
		WHERE cs_int.concept_code = m.concept_code
			AND cs_int.vocabulary_id = m.vocabulary_id
		);

--update from manual if something was changed
UPDATE concept_stage cs
SET concept_name = m.concept_name,
	domain_id = m.domain_id,
	valid_start_date = m.valid_start_date,
	valid_end_date = m.valid_end_date,
	invalid_reason = m.invalid_reason
FROM dev_hcpcs.concept_stage_manual m
WHERE cs.concept_code = m.concept_code
	AND cs.vocabulary_id = m.vocabulary_id
	AND (
		cs.concept_name <> m.concept_name
		OR COALESCE(cs.domain_id,'X') <> COALESCE(m.domain_id,'X')
		OR cs.valid_start_date <> m.valid_start_date
		OR cs.valid_end_date <> m.valid_end_date
		OR COALESCE(cs.invalid_reason, 'X') <> COALESCE(m.invalid_reason, 'X')
		);

--4 UPDATE domain_id in concept_stage
--4.1. Part 1. UPDATE domain_id defined by rules
WITH t_domains
AS (
	SELECT hcpc.concept_code,
		CASE 
			WHEN concept_name LIKE '%per session%'
				THEN 'Procedure'
					-- A codes
			WHEN concept_code IN (
					'A4248',
					'A9527',
					'A9517',
					'A9530',
					'A4802',
					'A9543',
					'A9545',
					'A9563',
					'A9564',
					'A9600',
					'A9604',
					'A9605',
					'A9606'
					)
				THEN 'Drug'
			WHEN l1.str = 'A Codes'
				AND concept_code NOT IN (
					'A4736',
					'A4737',
					'A9527',
					'A9517',
					'A9530',
					'A9606',
					'A9543',
					'A9563',
					'A9564',
					'A9600',
					'A9604',
					'A4248',
					'A4802',
					'A9152',
					'A9153',
					'A9180',
					'A9155'
					)
				AND l2.str != 'Transport Services Including Ambulance'
				THEN 'Device' -- default for Level 1: A0000-A9999
			WHEN l2.str = 'Transport Services Including Ambulance'
				THEN 'Observation' -- Level 2: A0000-A0999
			WHEN concept_code IN (
					'A4736',
					'A4737',
					'A9180'
					)
				THEN 'Procedure'
			WHEN concept_code IN (
					'A9152',
					'A9153'
					)
				THEN 'Observation'
			WHEN concept_code = 'A9155'
				THEN 'Drug' --Artificial saliva, 30 ml
					-- B codes
			WHEN l2.str = 'Enteral and Parenteral Therapy Supplies'
				THEN 'Device' -- all of them Level 1: B4000-B9999
					-- C codes
			WHEN concept_code = 'C1204'
				THEN 'Device' -- Technetium tc 99m tilmanocept, diagnostic, up to 0.5 millicuries
			WHEN concept_code IN (
					'C1178',
					'C9003'
					)
				THEN 'Drug' -- cancer drug
			WHEN concept_code LIKE 'C%'
				AND concept_name LIKE '%Brachytherapy%source%'
				THEN 'Device' -- Brachytherapy codes
			WHEN concept_code LIKE 'C%'
				AND concept_name LIKE '%Magnetic resonance% with%'
				THEN 'Procedure' -- MRIs
			WHEN concept_code LIKE 'C%'
				AND concept_name LIKE '%Trans% echocardiography%'
				THEN 'Procedure' -- Echocardiography
			WHEN concept_code IN (
					'C8953',
					'C8954',
					'C8955'
					)
				THEN 'Procedure'
			WHEN concept_code IN (
					'C9000',
					'C9007',
					'C9008',
					'C9009',
					'C9013'
					)
				THEN 'Drug'
			WHEN concept_code IN (
					'C9200',
					'C9201',
					'C9123',
					'C9102'
					)
				THEN 'Device'
			WHEN concept_code IN (
					'C9246',
					'C9247',
					'C9221',
					'C9222'
					) -- Contrast agent's
				THEN 'Device'
			WHEN concept_code BETWEEN 'C9021'
					AND 'C9348'
				THEN 'Drug' -- various drug products
			WHEN concept_code = 'C9349'
				THEN 'Device'
			WHEN concept_code BETWEEN 'C9352'
					AND 'C9369'
				THEN 'Device' -- various graft matrix material
			WHEN concept_code IN (
					'C9406',
					'C9407'
					)
				THEN 'Device' -- Iodine i-123 ioflupane, diagnostic, per study dose, up to 5 millicuries
			WHEN concept_code = 'C9399'
				THEN 'Drug' -- Unclassified drugs or biologicals
			WHEN concept_code BETWEEN 'C9408'
					AND 'C9497'
				THEN 'Drug'
			WHEN concept_code BETWEEN 'C9600'
					AND 'C9800'
				THEN 'Procedure'
			WHEN l1.str = 'C Codes - CMS Hospital Outpatient System'
				THEN 'Device' -- default for Level 1: C1000-C9999
			WHEN concept_code IN (
					'D5860',
					'D5861',
					'D6970',
					'D6971',
					'D6972',
					'D6973',
					'D0260',
					'D0290',
					'D2970',
					'D6053',
					'D6054',
					'D6078',
					'D6079',
					'D6975'
					)
				THEN 'Device' -- D-codes device
			WHEN concept_code BETWEEN 'D0260'
					AND 'D9242'
				THEN 'Procedure' -- D-code prcedures
					-- E codes
			WHEN l1.str = 'E-codes'
				THEN 'Device' -- all of them Level 1: E0100-E9999
					-- G codes
			WHEN l2.str = 'Vaccine Administration' -- hard to say why it was Procedure but not a drug?
				THEN 'Drug' -- Level 2: G0008-G0010
			WHEN l2.str = 'Semen Analysis'
				THEN 'Measurement' -- Level 2: G0027-G0027
			WHEN concept_code IN (
					'G0101',
					'G0102'
					)
				THEN 'Procedure'
			WHEN concept_code = 'G0103'
				THEN 'Measurement' -- Prostate cancer screening; prostate specific antigen test (psa)
			WHEN l2.str = 'Training Services - Diabetes Management'
				THEN 'Observation' -- Level 2: G0108-G0109
			WHEN l2.str = 'Screening Services - Cytopathology'
				THEN 'Measurement' -- Level 2: G0123-G0124
			WHEN l2.str = 'Service, Nurse AND OT'
				THEN 'Observation' -- Level 2: G0128-G0129
			WHEN l2.str = 'Screening Services - Cytopathology, Other'
				THEN 'Measurement' -- Level 2: G0141-G0148
			WHEN l2.str = 'Services, Allied Health'
				THEN 'Observation' -- Level 2: G0151-G0166
			WHEN l2.str = 'Team Conference'
				THEN 'Observation' -- Level 2: G0175-G0175
			WHEN concept_code = 'G0177'
				THEN 'Procedure'
			WHEN l2.str = 'Physician Services'
				THEN 'Observation' -- Level 2: G0179-G0182
			WHEN l2.str = 'Therapeutic Procedures'
				THEN 'Procedure' -- Level 2: G0237-G0239
			WHEN l2.str = 'Physician Services, Diabetic'
				THEN 'Observation' -- Level 2: G0245-G0246
			WHEN l2.str = 'Demonstration, INR'
				THEN 'Observation' -- Level 2: G0248-G0250
			WHEN l2.str = 'Tositumomab'
				THEN 'Drug' -- Level 2: G3001-G3001
			WHEN l2.str = 'Services, Pulmonary Surgery'
				THEN 'Observation' -- Level 2: G0302-G0305
			WHEN concept_code BETWEEN 'G0308'
					AND 'G0327'
				THEN 'Observation' -- ESRD services
			WHEN l2.str = 'Laboratory'
				THEN 'Measurement' -- Level 2: G0306-G0328
			WHEN l2.str = 'Fee, Pharmacy'
				THEN 'Procedure' -- Level 2: G0333-G0333
			WHEN l2.str = 'Hospice'
				THEN 'Observation' -- Level 2: G0337-G0337
			WHEN l2.str = 'Services, Observation AND ED'
				THEN 'Observation' -- Level 2: G0378-G0384
			WHEN l2.str = 'Team, Trauma Response'
				THEN 'Observation' -- Level 2: G0390-G0390
			WHEN l2.str = 'Home Sleep Study Test'
				THEN 'Procedure' --G0398-G0400  
			WHEN l2.str = 'Initial Examination for Medicare Enrollment'
				THEN 'Observation' -- Level 2: G0402-G0402
			WHEN l2.str = 'Electrocardiogram'
				THEN 'Procedure' -- Level 2: G0403-G0405 -- changed to procedure because there could be various results
			WHEN l2.str = 'Follow-up Telehealth Consultation'
				THEN 'Observation' -- Level 2: G0406-G0408
			WHEN l2.str = 'Psychological Services'
				THEN 'Observation' -- Level 2: G0409-G0411
			WHEN l2.str = 'Pathology, Surgical'
				THEN 'Procedure' -- Level 2: G0416-G0419
			WHEN concept_code = 'G0424'
				THEN 'Procedure'
			WHEN concept_code IN (
					'G0428',
					'G0429'
					)
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'G0430'
					AND 'G0435'
				THEN 'Measurement' -- drug screen, infectious antibodies
			WHEN concept_code IN (
					'G0438',
					'G0439'
					)
				THEN 'Observation' -- annual wellness visit
			WHEN concept_code IN (
					'G0440',
					'G0441'
					)
				THEN 'Procedure' -- allogenic skin substitute
			WHEN concept_code IN (
					'G0442',
					'G0443',
					'G0444',
					'G0445',
					'G0446',
					'G0447'
					)
				THEN 'Procedure' -- Various screens AND counseling
			WHEN concept_code = 'G0448'
				THEN 'Procedure' -- Insertion or replacement of a permanent pacing cardioverter-defibrillator system with transvenous lead(s), single or dual chamber with insertion of pacing electrode, cardiac venous system, for left ventricular pacing
			WHEN concept_code = 'G0451'
				THEN 'Observation' -- Development testing, with interpretation AND report, per standardized instrument form
			WHEN concept_code = 'G0452'
				THEN 'Measurement' -- Molecular pathology procedure; physician interpretation AND report
			WHEN concept_code = 'G0453'
				THEN 'Procedure' -- Continuous intraoperative neurophysiology monitoring, from outside the operating room (remote or nearby), per patient, (attention directed exclusively to one patient) each 15 minutes (list in addition to primary procedure)
			WHEN concept_code = 'G0454'
				THEN 'Observation' -- Physician documentation of face-to-face visit for durable medical equipment determination performed by nurse practitioner, physician assistant or clinical nurse specialist
			WHEN concept_code = 'G0455'
				THEN 'Procedure' -- Preparation with instillation of fecal microbiota by any method, including assessment of donor specimen
			WHEN concept_code IN (
					'G0456',
					'G0457'
					)
				THEN 'Procedure' -- Negative pressure wound therapies
			WHEN concept_code = 'G0458'
				THEN 'Procedure' -- Low dose rate (ldr) prostate brachytherapy services, composite rate
			WHEN concept_code = 'G0459'
				THEN 'Procedure' -- Inpatient telehealth pharmacologic management, including prescription, use, AND review of medication with no more than minimal medical psychotherapy
			WHEN concept_code = 'G0460'
				THEN 'Procedure' -- Autologous platelet rich plasma for chronic wounds/ulcers, incuding phlebotomy, centrifugation, AND all other preparatory procedures, administration AND dressings, per treatment
			WHEN concept_code IN (
					'G0461',
					'G0462'
					)
				THEN 'Measurement' --    Immunohistochemistry or immunocytochemistry
			WHEN concept_code = 'G0463'
				THEN 'Observation' -- Hospital outpatient clinic visit for assessment AND management of a patient
			WHEN concept_code = 'G0464'
				THEN 'Measurement' -- Colorectal cancer screening; stool-based dna AND fecal occult hemoglobin (e.g., kras, ndrg4 AND bmp3)
			WHEN concept_code IN (
					'G0466',
					'G0467',
					'G0468',
					'G0469',
					'G0470'
					)
				THEN 'Observation' -- Federally qualified health center (fqhc) visits
			WHEN concept_code = 'G0471'
				THEN 'Procedure' -- Collection of venous blood by venipuncture or urine sample by catheterization from an individual in a skilled nursing facility (snf) or by a laboratory on behalf of a home health agency (hha)
			WHEN concept_code = 'G0472'
				THEN 'Measurement' -- Hepatitis c antibody screening, for individual at high risk AND other covered indication(s)
			WHEN concept_code = 'G0473'
				THEN 'Procedure' -- Face-to-face behavioral counseling for obesity, group (2-10), 30 minutes
			WHEN concept_code IN (
					'G0908',
					'G0909',
					'G0910',
					'G0911',
					'G0912',
					'G0913',
					'G0914',
					'G0915',
					'G0916',
					'G0917',
					'G0918',
					'G0919',
					'G0920',
					'G0921',
					'G0922'
					)
				THEN 'Observation' -- various documented levels AND assessments
			WHEN concept_code = 'G3001'
				THEN 'Drug' -- Administration and supply of tositumomab, 450 mg
			WHEN concept_code IN (
					'G6001',
					'G6002',
					'G6003',
					'G6004',
					'G6005',
					'G6006',
					'G6007',
					'G6008',
					'G6009',
					'G6010',
					'G6011',
					'G6012',
					'G6013',
					'G6014',
					'G6015',
					'G6016',
					'G6017'
					)
				THEN 'Procedure' -- various radiation treatment deliveries
			WHEN concept_code IN (
					'G6018',
					'G6019',
					'G6020',
					'G6021',
					'G6022',
					'G6023',
					'G6024',
					'G6025',
					'G6027',
					'G6028'
					)
				THEN 'Procedure' -- various ileo/colono/anoscopies
			WHEN concept_code BETWEEN 'G6030'
					AND 'G6058'
				THEN 'Measurement' -- drug screening
					-- Level 2: G8126-G9140, mostly Physician Quality Reporting System (PQRS)				
			WHEN concept_code BETWEEN 'G8006'
					AND 'G8117'
				THEN 'Observation' -- aren't present in UMLS
			WHEN concept_code BETWEEN 'G8126'
					AND 'G8394'
				THEN 'Observation' -- outdated concepts, aren't present in UMLS, so hardcode them
			WHEN concept_code BETWEEN 'G8977'
					AND 'G9012'
				THEN 'Observation' --Functional Limitation, Coordinated Care
			WHEN concept_code IN (
					'G9752',
					'G9756',
					'G9757',
					'G9643'
					)
				THEN 'Procedure' -- Emergency surgery, Elective surgery, Surgical procedures that included the use of silicone oil
			WHEN concept_code IN (
					'G9641',
					'G9639',
					'G9654',
					'G9770',
					'G9937',
					'G9839'
					)
				THEN 'Procedure'
			WHEN concept_code IN (
					'G9141',
					'G9142',
					'G9017',
					'G9018',
					'G9019',
					'G9020',
					'G9033',
					'G9034',
					'G9035',
					'G9036'
					)
				THEN 'Drug' -- Influenza a (h1n1) immunization administration + other drugs 
			WHEN concept_code = 'G9143'
				THEN 'Measurement' -- Warfarin responsiveness testing by genetic technique using any method, any number of specimen(s)
			WHEN concept_code = 'G9147'
				THEN 'Procedure' -- Outpatient intravenous insulin treatment (oivit) either pulsatile or continuous, by any means, guided by the results of measurements for: respiratory quotient; and/or, urine urea nitrogen (uun); and/or, arterial, venous or capillary glucose; and/or potassi
			WHEN concept_code IN (
					'G9148',
					'G9149',
					'G9150'
					)
				THEN 'Observation' -- National committee for quality assurance - medical home levels 
			WHEN concept_code IN (
					'G9151',
					'G9152',
					'G9153'
					)
				THEN 'Observation' -- Multi-payer Advanced Primary Care Practice (MAPCP) Demonstration Project
			WHEN concept_code = 'G9156'
				THEN 'Procedure' -- Evaluation for wheelchair requiring face to face visit with physician
			WHEN concept_code = 'G9157'
				THEN 'Procedure' -- Transesophageal doppler measurement of cardiac output (including probe placement, image acquisition, AND interpretation per course of treatment) for monitoring purposes
			WHEN concept_code BETWEEN 'G9158'
					AND 'G9186'
				THEN 'Observation' -- various neurological functional limitations documentations
			WHEN concept_code = 'G9187'
				THEN 'Observation' -- Bundled payments for care improvement initiative home visit for patient assessment performed by a qualified health care professional for individuals not considered homebound including, but not limited to, assessment of safety, falls, clinical status, fluid
			WHEN concept_code BETWEEN 'G9188'
					AND 'G9472'
				THEN 'Observation' -- various documentations
			WHEN concept_code BETWEEN 'G9473'
					AND 'G9479'
				THEN 'Observation'
			WHEN concept_code BETWEEN 'G9679'
					AND 'G9684'
				THEN 'Observation'
			WHEN concept_code BETWEEN 'G9514'
					AND 'G9517'
				THEN 'Observation'
			WHEN concept_code IN (
					'G0238',
					'G0293',
					'G0294',
					'G0403',
					'G0404',
					'G0405',
					'G0445',
					'G0453',
					'G9771',
					'G9773',
					'G9812',
					'G9601',
					'G9602'
					)
				THEN 'Observation'
					--	WHEN concept_code = 'G9642' -- seems to be Observation, hard to say why they put this here
					--	THEN 'Observation'
			WHEN l2.str IN (
					'Quality Measures - Miscellaneous',
					'Quality Measures',
					'Demonstration Project'
					)
				THEN 'Observation'
			WHEN concept_code BETWEEN 'G9000'
					AND 'G9140'
				THEN 'Procedure' -- default for Medicare Demonstration Project
			WHEN l1.str = 'Temporary Procedures/Professional Services'
				THEN 'Procedure' -- default for all Level 1: G0000-G9999
					-- H codes
			WHEN concept_code = 'H0003'
				THEN 'Measurement' -- Alcohol and/or drug screening; laboratory analysis of specimens for presence of alcohol and/or drugs
			WHEN concept_code = 'H0030'
				THEN 'Observation' -- Behavioral health hotline service
			WHEN concept_code = 'H0033'
				THEN 'Procedure' -- Oral medication administration, direct observation
			WHEN concept_code IN (
					'H0048',
					'H0049'
					)
				THEN 'Measurement' -- Alcohol screening
			WHEN concept_code BETWEEN 'H0034'
					AND 'H2037'
				THEN 'Observation' -- various services
			WHEN l1.str = 'Behavioral Health and/or Substance Abuse Treatment Services'
				THEN 'Procedure' -- default for all Level 1: H0001-H9999
					-- J codes
			WHEN concept_code = 'J7341'
				THEN 'Device'
			WHEN concept_code BETWEEN 'J7343'
					AND 'J7350'
				THEN 'Device'
			WHEN l1.str = 'J Codes - Drugs'
				THEN 'Drug' -- Level 1: J0100-J9999
					-- K codes
			WHEN l1.str = 'Temporary Codes Assigned to Durable Medical Equipment Regional Carriers'
				THEN 'Device' -- Level 1: K0000-K9999
					-- L codes 
			WHEN l1.str = 'L Codes'
				THEN 'Device' -- Level 1: L0000-L9999
					-- M codes
			WHEN concept_code = 'M0064'
				THEN 'Observation' -- Brief office visit for the sole purpose of monitoring or changing drug prescriptions used in the treatment of mental psychoneurotic AND personality disorders
			WHEN l1.str = 'Other Medical Services'
				THEN 'Procedure' -- Level 1: M0000-M0301
					-- P codes
			WHEN concept_code = 'P9012'
				THEN 'Drug' -- Cryoprecipitate, each unit should have domain_id = 'Drug'
			WHEN concept_code LIKE 'P90%'
				AND concept_code NOT BETWEEN 'P9041'
					AND 'P9048'
				THEN 'Device' -- All other P90% - blood components (AVOF-707)
			WHEN l2.str = 'Chemistry AND Toxicology Tests'
				THEN 'Measurement' -- Level 2: P2028-P2038
			WHEN l2.str = 'Pathology Screening Tests'
				THEN 'Measurement' -- Level 2: P3000-P3001
			WHEN l2.str = 'Microbiology Tests'
				THEN 'Measurement' -- Level 2: P7001-P7001
			WHEN concept_code BETWEEN 'P9041'
					AND 'P9048'
				THEN 'Drug'
			WHEN l2.str = 'Miscellaneous Pathology AND Laboratory Services'
				THEN 'Procedure' -- Level 2: P9010-P9615
					-- Q codes
			WHEN concept_code IN (
					'Q0136',
					'Q0137',
					'Q0187',
					'Q2001',
					'Q2002',
					'Q2003',
					'Q4054',
					'Q4055'
					)
				THEN 'Drug'
			WHEN concept_code BETWEEN 'Q9941'
					AND 'Q9944'
				THEN 'Drug'
			WHEN concept_code IN (
					'Q1001',
					'Q1002'
					)
				THEN 'Device'
			WHEN l2.str = 'Cardiokymography (CMS Temporary Codes)'
				THEN 'Procedure' -- Level 2: Q0035-Q0035
			WHEN l2.str = 'Chemotherapy (CMS Temporary Codes)'
				OR concept_code BETWEEN 'Q0081'
					AND 'Q0085'
				THEN 'Procedure' -- Level 2: Q0081-Q0085
			WHEN concept_code = 'Q0090'
				THEN 'Device' -- Levonorgestrel-releasing intrauterine contraceptive system, (skyla), 13.5 mg
			WHEN l2.str = 'Smear, Papanicolaou (CMS Temporary Codes)'
				THEN 'Procedure' -- Level 2: Q0091-Q0091, only getting the smear, no interpretation
			WHEN l2.str = 'Equipment, X-Ray, Portable (CMS Temporary Codes)'
				THEN 'Observation' -- Level 2: Q0092-Q0092, only setup
			WHEN l2.str = 'Laboratory (CMS Temporary Codes)'
				THEN 'Measurement' -- Level 2: Q0111-Q0115
			WHEN l2.str = 'Drugs (CMS Temporary Codes)'
				THEN 'Drug' -- Level 2: Q0138-Q0181
			WHEN concept_code IN (
					'Q0182',
					'Q0183'
					)
				THEN 'Device'
			WHEN l2.str = 'Miscellaneous Devices (CMS Temporary Codes)'
				THEN 'Device' -- Level 2: Q0478-Q0509
			WHEN l2.str = 'Fee, Pharmacy (CMS Temporary Codes)'
				AND concept_code != 'Q0515'
				THEN 'Observation' -- Level 2: Q0510-Q0515
			WHEN concept_code = 'Q0515'
				THEN 'Drug'
			WHEN l2.str = 'Lens, Intraocular (CMS Temporary Codes)'
				OR concept_code = 'Q1003'
				THEN 'Device' -- Level 2: Q1003-Q1005
			WHEN concept_code BETWEEN 'Q2040'
					AND 'Q2043'
				THEN 'Procedure'
			WHEN l2.str = 'Solutions and Drugs (CMS Temporary Codes)'
				AND concept_code NOT IN ('Q2052')
				THEN 'Drug' -- Level 2: Q2004-Q2052
			WHEN l2.str = 'Brachytherapy Radioelements (CMS Temporary Codes)'
				THEN 'Device' -- Level 2: Q3001-Q3001
			WHEN l2.str = 'Telehealth (CMS Temporary Codes)'
				THEN 'Observation' -- Level 2: Q3014-Q3014
			WHEN concept_code IN (
					'Q3025',
					'Q3026'
					)
				THEN 'Drug' -- Injection, Interferon beta
			WHEN l2.str = 'Additional Drugs (CMS Temporary Codes)'
				THEN 'Drug' -- Level 2: Q3027-Q3028
			WHEN l2.str = 'Test, Skin (CMS Temporary Codes)'
				THEN 'Measurement' -- Level 2: Q3031-Q3031
			WHEN l2.str = 'Supplies, Cast (CMS Temporary Codes)'
				THEN 'Device' -- Level 2: Q4001-Q4051
			WHEN l2.str = 'Additional Drug Codes (CMS Temporary Codes)'
				THEN 'Drug' -- Level 2: Q4074-Q4082
			WHEN concept_code BETWEEN 'Q4083'
					AND 'Q4099'
				THEN 'Drug'
			WHEN l2.str = 'Skin Substitutes (CMS Temporary Codes)'
				THEN 'Device' -- Level 2: Q4100-Q4182  
			WHEN l2.str = 'Hospice Care (CMS Temporary Codes)'
				THEN 'Observation' --Level 2: Q5001-Q5010
			WHEN l2.str = 'Contrast Agents'
				OR concept_code BETWEEN 'Q9945'
					AND 'Q9949'
				THEN 'Device' -- Level 2: Q9950-Q9969  
			WHEN concept_code IN (
					'Q5101',
					'Q5102',
					'Q9955',
					'Q9957',
					'Q9972',
					'Q9973',
					'Q9974',
					'Q9979',
					'Q9980',
					'Q9981'
					)
				THEN 'Drug'
			WHEN concept_code IN (
					'Q9968',
					'Q9953',
					'Q9987',
					'Q9988'
					)
				THEN 'Procedure'
			WHEN concept_code IN (
					'Q9982',
					'Q9983',
					'Q9984',
					'Q9956'
					)
				THEN 'Device' --Radiopharmaceuticals	
			WHEN concept_code IN (
					'Q9970',
					'Q9975',
					'Q9976',
					'Q9978',
					'Q9984',
					'Q9985',
					'Q9986',
					'Q9989'
					) -- miscelaneous Q-codes Drugs
				THEN 'Drug'
					-- S codes
			WHEN concept_code BETWEEN 'S0012'
					AND 'S0198' ---'Non-Medicare Drugs'
				THEN 'Drug'
			WHEN concept_code BETWEEN 'S0257'
					AND 'S0265'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'S0390'
					AND 'S0400'
				THEN 'Procedure'
			WHEN l2.str = 'Provider Services'
				THEN 'Observation' -- includes the previous
			WHEN concept_code = 'S0592'
				THEN 'Procedure' -- Comprehensive contact lens evaluation
			WHEN concept_code BETWEEN 'S0500'
					AND 'S0596'
				THEN 'Device' -- lenses, includes the previous
			WHEN concept_code BETWEEN 'S0601'
					AND 'S0812'
				THEN 'Procedure'
			WHEN concept_code IN (
					'S0830',
					'S8004'
					)
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'S1001'
					AND 'S1040'
				THEN 'Device'
			WHEN concept_code = 'S1090'
				THEN 'Drug' -- Mometasone furoate sinus implant, 370 micrograms
			WHEN concept_code BETWEEN 'S2053'
					AND 'S3000'
				THEN 'Procedure'
			WHEN concept_code IN (
					'S3000',
					'S3005'
					)
				THEN 'Observation' -- Stat lab
			WHEN concept_code IN (
					'S3600',
					'S3601'
					)
				THEN 'Observation' -- stat lab
			WHEN concept_code BETWEEN 'S3600'
					AND 'S3890'
				THEN 'Measurement' -- various genetic tests AND prenatal screenings
			WHEN concept_code BETWEEN 'S3900'
					AND 'S3904'
				THEN 'Procedure' -- EKG AND EMG
			WHEN concept_code BETWEEN 'S3905'
					AND 'S4042'
				THEN 'Procedure' -- IVF procedures
			WHEN concept_code BETWEEN 'S4981'
					AND 'S5014'
				THEN 'Drug' -- various
			WHEN concept_code BETWEEN 'S5035'
					AND 'S5036'
				THEN 'Observation'
			WHEN concept_code BETWEEN 'S5100'
					AND 'S5199'
				THEN 'Observation' -- various care services
			WHEN concept_code BETWEEN 'S5497'
					AND 'S5523'
				THEN 'Procedure' -- Home infusion therapy
			WHEN concept_code BETWEEN 'S5550'
					AND 'S5553'
				THEN 'Drug' -- various Insulin forms-- !!discuss with Christian why he decided, it's a Procuderure Drug -> Procedure
			WHEN concept_code BETWEEN 'S5560'
					AND 'S5571'
				THEN 'Device' -- various Insulin delivery devices
			WHEN concept_code = 'S8030'
				THEN 'Procedure' --Scleral application of tantalum ring(s) for localization of lesions for proton beam therapy
			WHEN concept_code BETWEEN 'S8032'
					AND 'S8092'
				THEN 'Procedure' -- various imaging
			WHEN concept_code = 'S8095'
				THEN 'Device'
			WHEN concept_code = 'S8110'
				THEN 'Measurement' -- Peak expiratory flow rate (physician services)
			WHEN concept_code BETWEEN 'S8096'
					AND 'S8490'
				THEN 'Device'
			WHEN concept_code BETWEEN 'S8930'
					AND 'S8990'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'S8999'
					AND 'S9007'
				THEN 'Device'
			WHEN concept_code BETWEEN 'S9015'
					AND 'S9075'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'S9083'
					AND 'S9088'
				THEN 'Observation'
			WHEN concept_code BETWEEN 'S9090'
					AND 'S9110'
				AND concept_code != 'S9098'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'S9123'
					AND 'S9129'
				AND concept_code != 'S9127'
				THEN 'Procedure' -- home therapy
			WHEN concept_code = 'S9145'
				THEN 'Procedure' -- Insulin pump initiation, instruction in initial use of pump (pump not included)
			WHEN concept_code BETWEEN 'S9150'
					AND 'S9214'
				THEN 'Observation' -- Home management
			WHEN concept_code BETWEEN 'S9328'
					AND 'S9379'
				AND concept_name LIKE 'Home%therapy%'
				THEN 'Procedure' -- home infusions AND home therapy without exact drugs, per diem
			WHEN concept_code BETWEEN 'S9381'
					AND 'S9433'
				THEN 'Observation'
			WHEN concept_code BETWEEN 'S9434'
					AND 'S9435'
				THEN 'Device'
			WHEN concept_code BETWEEN 'S9490'
					AND 'S9562'
				THEN 'Procedure' -- Home infusion therapy, exact group of drugs
					-- T codes
			WHEN concept_code IN (
					'T1500',
					'T2006'
					)
				THEN 'Device'
			WHEN concept_code = 'T1006'
				THEN 'Procedure' -- Alcohol and/or substance abuse services, family/couple counseling
			WHEN hcpc.concept_code IN (
					'T1502',
					'T1503'
					)
				THEN 'Procedure' -- Administration of medication without saying which one (Administration of medication, other than oral and/or injectable, by a health care agency/professional, per visit)
			WHEN hcpc.concept_code BETWEEN 'T1505'
					AND 'T1999'
				THEN 'Device'
			WHEN hcpc.concept_code IN (
					'T2028',
					'T2029'
					)
				THEN 'Device'
			WHEN hcpc.concept_code BETWEEN 'T4521'
					AND 'T5999'
				THEN 'Device'
			WHEN l1.str = 'Temporary National Codes Established by Private Payers'
				THEN 'Observation' -- default for Level 1: S0000-S9999 AND Level 1: T1000-T9999
					-- V codes
			WHEN hcpc.concept_code IN (
					'V2785',
					'V2787',
					'V2788'
					)
				THEN 'Procedure' -- Processing or correcting procedure
			WHEN hcpc.concept_code BETWEEN 'V2624'
					AND 'V2626'
				THEN 'Procedure' -- working on ocular prosthesis
			WHEN hcpc.concept_code IN (
					'V5008',
					'V5010'
					)
				THEN 'Procedure' -- Hearing screening AND assessment of hearing aide
			WHEN hcpc.concept_code IN (
					'V5011',
					'V5014'
					)
				THEN 'Procedure' -- fitting of hearing aide
			WHEN hcpc.concept_code = 'V5020'
				THEN 'Observation' -- Conformity evaluation
			WHEN hcpc.concept_code = 'V5275'
				THEN 'Observation' -- Ear impression, each
			WHEN hcpc.concept_code BETWEEN 'V5300'
					AND 'V5364'
				THEN 'Procedure' -- various screening
			WHEN l1.str = 'V Codes'
				THEN 'Device' -- default for Level 1: V0000-V5999 Vision AND hearing services
			ELSE COALESCE(hcpc.domain_id,'Observation') -- use 'observation' in other cases
			END AS domain_id
	FROM concept_stage hcpc
	LEFT JOIN (
		SELECT code,
			(array(SELECT unnest(regexp_matches(code, '[A-Z]\d{4}', 'g')))) [1] AS lo,
			(array(SELECT unnest(regexp_matches(code, '[A-Z]\d{4}', 'g')))) [2] AS hi,
			str
		FROM sources.mrconso
		WHERE sab = 'MTHHH'
			AND code LIKE 'Level 1%'
		) l1 ON hcpc.concept_code BETWEEN l1.lo
			AND l1.hi
	LEFT JOIN (
		SELECT code,
			(array(SELECT unnest(regexp_matches(code, '[A-Z]\d{4}', 'g')))) [1] AS lo,
			(array(SELECT unnest(regexp_matches(code, '[A-Z]\d{4}', 'g')))) [2] AS hi,
			str
		FROM sources.mrconso
		WHERE sab = 'MTHHH'
			AND code LIKE 'Level 2%'
		) l2 ON hcpc.concept_code BETWEEN l2.lo
			AND l2.hi
	LEFT JOIN (
		SELECT code,
			(array(SELECT unnest(regexp_matches(code, '[A-Z]\d{4}', 'g')))) [1] AS lo,
			(array(SELECT unnest(regexp_matches(code, '[A-Z]\d{4}', 'g')))) [2] AS hi,
			str
		FROM sources.mrconso
		WHERE sab = 'MTHHH'
			AND code LIKE 'Level 3%'
		) l3 ON hcpc.concept_code BETWEEN l3.lo
			AND l3.hi
	WHERE LENGTH(concept_code) > 2
	)
UPDATE concept_stage cs
SET domain_id = t.domain_id
FROM t_domains t
WHERE cs.concept_code = t.concept_code;

--4.2. Part 2 (for HCPCS Modifiers)
DO $_$
BEGIN
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='A1'; --Dressing for one wound
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='A2'; --Dressing for two wounds
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='A3'; --Dressing for three wounds
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='A4'; --Dressing for four wounds
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='A5'; --Dressing for five wounds
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='A6'; --Dressing for six wounds
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='A7'; --Dressing for seven wounds
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='A8'; --Dressing for eight wounds
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='A9'; --Dressing for nine or more wounds
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AA'; --Anesthesia services performed personally by anesthesiologist
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AD'; --Medical supervision by a physician: more than four concurrent anesthesia procedures
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AE'; --Registered dietician
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AF'; --Specialty physician
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AG'; --Primary physician
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AH'; --Clinical psychologist
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AI'; --Principal physician of record
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AJ'; --Clinical social worker
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AK'; --Non participating physician
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AM'; --Physician, team member service
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AO'; --Alternate payment method declined by provider of service
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AP'; --Determination of refractive state was not performed in the course of diagnostic ophthalmological examination
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AQ'; --Physician providing a service in an unlisted health professional shortage area (hpsa)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AR'; --Physician provider services in a physician scarcity area
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AS'; --Physician assistant, nurse practitioner, or clinical nurse specialist services for assistant at surgery
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AT'; --Acute treatment (this modifier should be used when reporting service 98940, 98941, 98942)
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AU'; --Item furnished in conjunction with a urological, ostomy, or tracheostomy supply
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AV'; --Item furnished in conjunction with a prosthetic device, prosthetic or orthotic
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AW'; --Item furnished in conjunction with a surgical dressing
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AX'; --Item furnished in conjunction with dialysis services
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AY'; --Item or service furnished to an esrd patient that is not for the treatment of esrd
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='AZ'; --Physician providing a service in a dental health professional shortage area for the purpose of an electronic health record incentive payment
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='BA'; --Item furnished in conjunction with parenteral enteral nutrition (pen) services
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='BL'; --Special acquisition of blood AND blood products
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='BO'; --Orally administered nutrition, not by feeding tube
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='BP'; --The beneficiary has been informed of the purchase AND rental options AND has elected to purchase the item
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='BR'; --The beneficiary has been informed of the purchase AND rental options AND has elected to rent the item
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='BU'; --The beneficiary has been informed of the purchase AND rental options AND after 30 days has not informed the supplier of his/her decision
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CA'; --Procedure payable only in the inpatient setting when performed emergently on an outpatient who expires prior to admission
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CB'; --Service ordered by a renal dialysis facility (rdf) physician as part of the esrd beneficiary's dialysis benefit, is not part of the composite rate, AND is separately reimbursable
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CC'; --Procedure code change (use 'cc' when the procedure code submitted was changed either for administrative reasons or because an incorrect code was filed)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CD'; --Amcc test has been ordered by an esrd facility or mcp physician that is part of the composite rate AND is not separately billable
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CE'; --Amcc test has been ordered by an esrd facility or mcp physician that is a composite rate test but is beyond the normal frequency covered under the rate AND is separately reimbursable based on medical necessity
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CF'; --Amcc test has been ordered by an esrd facility or mcp physician that is not part of the composite rate AND is separately billable
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CG'; --Policy criteria applied
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CH'; --0 percent impaired, limited or restricted
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CI'; --At least 1 percent but less than 20 percent impaired, limited or restricted
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CJ'; --At least 20 percent but less than 40 percent impaired, limited or restricted
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CK'; --At least 40 percent but less than 60 percent impaired, limited or restricted
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CL'; --At least 60 percent but less than 80 percent impaired, limited or restricted
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CM'; --At least 80 percent but less than 100 percent impaired, limited or restricted
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CN'; --100 percent impaired, limited or restricted
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CO';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CP'; --Adjunctive service related to a procedure assigned to a comprehensive ambulatory payment classification (c-apc) procedure, but reported on a different claim
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CR'; --Catastrophe/disaster related
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CS'; --Gulf oil 2010 spill related
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CT'; --Computed tomography services furnished using equipment that does not meet each of the attributes of the national electrical manufacturers association (nema) xr-29-2013 standard
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='CQ';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='DA'; --Oral health assessment by a licensed health professional other than a dentist
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='E1'; --Upper left, eyelid
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='E2'; --Lower left, eyelid
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='E3'; --Upper right, eyelid
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='E4'; --Lower right, eyelid
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='EA'; --Erythropoetic stimulating agent (esa) administered to treat anemia due to anti-cancer chemotherapy
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='EB'; --Erythropoetic stimulating agent (esa) administered to treat anemia due to anti-cancer radiotherapy
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='EC'; --Erythropoetic stimulating agent (esa) administered to treat anemia not due to anti-cancer radiotherapy or anti-cancer chemotherapy
	UPDATE concept_stage SET domain_id='Measurement' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='ED'; --Hematocrit level has exceeded 39% (or hemoglobin level has exceeded 13.0 g/dl) for 3 or more consecutive billing cycles immediately prior to AND including the current cycle
	UPDATE concept_stage SET domain_id='Measurement' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='EE'; --Hematocrit level has not exceeded 39% (or hemoglobin level has not exceeded 13.0 g/dl) for 3 or more consecutive billing cycles immediately prior to AND including the current cycle
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='EJ'; --Subsequent claims for a defined course of therapy, e.g., epo, sodium hyaluronate, infliximab
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='EM'; --Emergency reserve supply (for esrd benefit only)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='EP'; --Service provided as part of medicaid early periodic screening diagnosis AND treatment (epsdt) program
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='ER';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='ET'; --Emergency services
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='EX'; --Expatriate beneficiary
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='EY'; --No physician or other licensed health care provider order for this item or service
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='F1'; --Left hand, second digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='F2'; --Left hand, third digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='F3'; --Left hand, fourth digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='F4'; --Left hand, fifth digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='F5'; --Right hand, thumb
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='F6'; --Right hand, second digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='F7'; --Right hand, third digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='F8'; --Right hand, fourth digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='F9'; --Right hand, fifth digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='FA'; --Left hand, thumb
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='FB'; --Item provided without cost to provider, supplier or practitioner, or full credit received for replaced device (examples, but not limited to, covered under warranty, replaced due to defect, free samples)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='FC'; --Partial credit received for replaced device
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='FP'; --Service provided as part of family planning program
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='G0';
	UPDATE concept_stage SET domain_id='Measurement' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='G1'; --Most recent urr reading of less than 60
	UPDATE concept_stage SET domain_id='Measurement' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='G2'; --Most recent urr reading of 60 to 64.9
	UPDATE concept_stage SET domain_id='Measurement' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='G3'; --Most recent urr reading of 65 to 69.9
	UPDATE concept_stage SET domain_id='Measurement' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='G4'; --Most recent urr reading of 70 to 74.9
	UPDATE concept_stage SET domain_id='Measurement' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='G5'; --Most recent urr reading of 75 or greater
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='G6'; --Esrd patient for whom less than six dialysis sessions have been provided in a month
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='G7'; --Pregnancy resulted from rape or incest or pregnancy certified by physician as life threatening
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='G8'; --Monitored anesthesia care (mac) for deep complex, complicated, or markedly invasive surgical procedure
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='G9'; --Monitored anesthesia care for patient who has history of severe cardio-pulmonary condition
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GA'; --Waiver of liability statement issued as required by payer policy, individual case
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GB'; --Claim being re-submitted for payment because it is no longer covered under a global payment demonstration
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GC'; --This service has been performed in part by a resident under the direction of a teaching physician
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GD'; --Units of service exceeds medically unlikely edit value AND represents reasonable AND necessary services
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GE'; --This service has been performed by a resident without the presence of a teaching physician under the primary care exception
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GF'; --Non-physician (e.g. nurse practitioner (np), certified registered nurse anesthetist (crna), certified registered nurse (crn), clinical nurse specialist (cns), physician assistant (pa)) services in a critical access hospital
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GG'; --Performance AND payment of a screening mammogram AND diagnostic mammogram on the same patient, same day
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GH'; --Diagnostic mammogram converted from screening mammogram on same day
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GJ'; --opt out physician or practitioner emergency or urgent service
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GK'; --Reasonable AND necessary item/service associated with a ga or gz modifier
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GL'; --Medically unnecessary upgrade provided instead of non-upgraded item, no charge, no advance beneficiary notice (abn)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GM'; --Multiple patients on one ambulance trip
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GN'; --Services delivered under an outpatient speech language pathology plan of care
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GO'; --Services delivered under an outpatient occupational therapy plan of care
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GP'; --Services delivered under an outpatient physical therapy plan of care
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GQ'; --Via asynchronous telecommunications system
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GR'; --This service was performed in whole or in part by a resident in a department of veterans affairs medical center or clinic, supervised in accordance with va policy
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GS'; --Dosage of erythropoietin stimulating agent has been reduced AND maintained in response to hematocrit or hemoglobin level
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GT'; --Via interactive audio AND video telecommunication systems
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GU'; --Waiver of liability statement issued as required by payer policy, routine notice
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GV'; --Attending physician not employed or paid under arrangement by the patient's hospice provider
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GW'; --Service not related to the hospice patient's terminal condition
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GX'; --Notice of liability issued, voluntary under payer policy
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GY'; --Item or service statutorily excluded, does not meet the definition of any medicare benefit or, for non-medicare insurers, is not a contract benefit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='GZ'; --Item or service expected to be denied as not reasonable AND necessary
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='H9'; --Court-ordered
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HA'; --Child/adolescent program
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HB'; --Adult program, non geriatric
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HC'; --Adult program, geriatric
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HD'; --Pregnant/parenting women's program
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HE'; --Mental health program
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HF'; --Substance abuse program
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HG'; --Opioid addiction treatment program
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HH'; --Integrated mental health/substance abuse program
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HI'; --Integrated mental health AND intellectual disability/developmental disabilities program
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HJ'; --Employee assistance program
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HK'; --Specialized mental health programs for high-risk populations
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HL'; --Intern
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HM'; --Less than bachelor degree level
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HN'; --Bachelors degree level
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HO'; --Masters degree level
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HP'; --Doctoral level
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HQ'; --Group setting
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HR'; --Family/couple with client present
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HS'; --Family/couple without client present
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HT'; --Multi-disciplinary team
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HU'; --Funded by child welfare agency
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HV'; --Funded state addictions agency
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HW'; --Funded by state mental health agency
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HX'; --Funded by county/local agency
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HY'; --Funded by juvenile justice agency
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='HZ'; --Funded by criminal justice agency
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='J1'; --Competitive acquisition program no-pay submission for a prescription number
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='J2'; --Competitive acquisition program, restocking of emergency drugs after emergency administration
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='J3'; --Competitive acquisition program (cap), drug not available through cap as written, reimbursed under average sales price methodology
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='J4'; --Dmepos item subject to dmepos competitive bidding program that is furnished by a hospital upon discharge
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='JA'; --Administered intravenously
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='JB'; --Administered subcutaneously
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='JC'; --Skin substitute used as a graft
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='JD'; --Skin substitute not used as a graft
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='JE'; --Administered via dialysate
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='JF'; --Compounded drug
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='JW'; --Drug amount discarded/not administered to any patient
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='K0'; --Lower extremity prosthesis functional level 0 - does not have the ability or potential to ambulate or transfer safely with or without assistance AND a prosthesis does not enhance their quality of life or mobility.
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='K1'; --Lower extremity prosthesis functional level 1 - has the ability or potential to use a prosthesis for transfers or ambulation on level surfaces at fixed cadence. typical of the limited AND unlimited household ambulator.
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='K2'; --Lower extremity prosthesis functional level 2 - has the ability or potential for ambulation with the ability to traverse low level environmental barriers such as curbs, stairs or uneven surfaces.  typical of the limited community ambulator.
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='K3'; --Lwr ext prost functnl lvl 3
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='K4'; --Lwr ext prost functnl lvl 4
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KA'; --Add on option/accessory for wheelchair
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KB'; --Beneficiary requested upgrade for abn, more than 4 modifiers identified on claim
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KC'; --Replacement of special power wheelchair interface
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KD'; --Drug or biological infused through dme
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KE'; --Bid under round one of the dmepos competitive bidding program for use with non-competitive bid base equipment
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KF'; --Item designated by fda as class iii device
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KG'; --Dmepos item subject to dmepos competitive bidding program number 1
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KH'; --Dmepos item, initial claim, purchase or first month rental
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KI'; --Dmepos item, second or third month rental
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KJ'; --Dmepos item, parenteral enteral nutrition (pen) pump or capped rental, months four to fifteen
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KK'; --Dmepos item subject to dmepos competitive bidding program number 2
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KL'; --Dmepos item delivered via mail
	UPDATE concept_stage SET domain_id='Procedure' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KM'; --Replacement of facial prosthesis including new impression/moulage
	UPDATE concept_stage SET domain_id='Procedure' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KN'; --Replacement of facial prosthesis using previous master model
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KO'; --Single drug unit dose formulation
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KP'; --First drug of a multiple drug unit dose formulation
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KQ'; --Second or subsequent drug of a multiple drug unit dose formulation
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KR'; --Rental item, billing for partial month
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KS'; --Glucose monitor supply for diabetic beneficiary not treated with insulin
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KT'; --Beneficiary resides in a competitive bidding area AND travels outside that competitive bidding area AND receives a competitive bid item
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KU'; --Dmepos item subject to dmepos competitive bidding program number 3
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KV'; --Dmepos item subject to dmepos competitive bidding program that is furnished as part of a professional service
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KW'; --Dmepos item subject to dmepos competitive bidding program number 4
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KX'; --Requirements specified in the medical policy have been met
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KY'; --Dmepos item subject to dmepos competitive bidding program number 5
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='KZ'; --New coverage not implemented by managed care
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='L1'; --Provider attestation that the hospital laboratory test(s) is not packaged under the hospital opps
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='LC'; --Left circumflex coronary artery
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='LD'; --Left anterior descending coronary artery
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='LL'; --Lease/rental (use the 'll' modifier when dme equipment rental is to be applied against the purchase price)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='LM'; --Left main coronary artery
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='LR'; --Laboratory round trip
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='LS'; --Fda-monitored intraocular lens implant
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='LT'; --Left side (used to identify procedures performed on the left side of the body)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='M2'; --Medicare secondary payer (msp)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='MS'; --Six month maintenance AND servicing fee for reasonable AND necessary parts AND labor which are not covered under any manufacturer or supplier warranty
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='NB'; --Nebulizer system, any type, fda-cleared for use with specific drug
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='NR'; --New when rented (use the 'nr' modifier when dme which was new at the time of rental is subsequently purchased)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='NU'; --New equipment
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='P1'; --A normal healthy patient
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='P2'; --A patient with mild systemic disease
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='P3'; --A patient with severe systemic disease
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='P4'; --A patient with severe systemic disease that is a constant threat to life
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='P5'; --A moribund patient who is not expected to survive without the operation
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='P6'; --A declared brain-dead patient whose organs are being removed for donor purposes
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='PA'; --Surgical or other invasive procedure on wrong body part
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='PB'; --Surgical or other invasive procedure on wrong patient
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='PC'; --Wrong surgery or other invasive procedure on patient
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='PD'; --Diagnostic or related non diagnostic item or service provided in a wholly owned or operated entity to a patient who is admitted as an inpatient within 3 days
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='PI'; --Positron emission tomography (pet) or pet/computed tomography (ct) to inform the initial treatment strategy of tumors that are biopsy proven or strongly suspected of being cancerous based on other diagnostic testing
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='PL'; --Progressive addition lenses
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='PM'; --Post mortem
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='PO'; --Services, procedures and/or surgeries provided at off-campus provider-based outpatient departments
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='PS'; --Positron emission tomography (pet) or pet/computed tomography (ct) to inform the subsequent treatment strategy of cancerous tumors when the beneficiary's treating physician determines that the pet study is needed to inform subsequent anti-tumor strategy
	UPDATE concept_stage SET domain_id='Measurement' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='PT'; --Colorectal cancer screening test; converted to diagnostic test or other procedure
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='Q0'; --Investigational clinical service provided in a clinical research study that is in an approved clinical research study
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='Q1'; --Routine clinical service provided in a clinical research study that is in an approved clinical research study
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='Q2'; --Hcfa/ord demonstration project procedure/service
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='Q3'; --Live kidney donor surgery AND related services
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='Q4'; --Service for ordering/referring physician qualifies as a service exemption
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='Q5'; --Service furnished by a substitute physician under a reciprocal billing arrangement
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='Q6'; --Service furnished by a locum tenens physician
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='Q7'; --One class a finding
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='Q8'; --Two class b findings
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='Q9'; --One class b AND two class c findings
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QB';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QC'; --Single channel monitoring
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QD'; --Recording AND storage in solid state memory by a digital recorder
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QE'; --Prescribed amount of oxygen is less than 1 liter per minute (lpm)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QF'; --Prescribed amount of oxygen exceeds 4 liters per minute (lpm) AND portable oxygen is prescribed
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QG'; --Prescribed amount of oxygen is greater than 4 liters per minute(lpm)
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QH'; --Oxygen conserving device is being used with an oxygen delivery system
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QJ'; --Services/items provided to a prisoner or patient in state or local custody, however the state or local government, as applicable, meets the requirements in 42 cfr 411.4 (b)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QK'; --Medical direction of two, three, or four concurrent anesthesia procedures involving qualified individuals
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QL'; --Patient pronounced dead after ambulance called
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QM'; --Ambulance service provided under arrangement by a provider of services
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QN'; --Ambulance service furnished directly by a provider of services
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QP'; --Documentation is on file showing that the laboratory test(s) was ordered individually or ordered as a cpt-recognized panel other than automated profile codes 80002-80019, g0058, g0059, AND g0060.
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QS'; --Monitored anesthesia care service
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QT'; --Recording AND storage on tape by an analog tape recorder
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QW'; --Clia waived test
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QX'; --Crna service: with medical direction by a physician
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QY'; --Medical direction of one certified registered nurse anesthetist (crna) by an anesthesiologist
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='QZ'; --Crna service: without medical direction by a physician
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='RA'; --Replacement of a dme, orthotic or prosthetic item
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='RB'; --Replacement of a part of a dme, orthotic or prosthetic item furnished as part of a repair
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='RC'; --Right coronary artery
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='RD'; --Drug provided to beneficiary, but not administered "incident-to" 
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='RE'; --Furnished in full compliance with fda-mandated risk evaluation AND mitigation strategy (rems)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='RI'; --Ramus intermedius coronary artery
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='RR'; --Rental (use the 'rr' modifier when dme is to be rented)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='RT'; --Right side (used to identify procedures performed on the right side of the body)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SA'; --Nurse practitioner rendering service in collaboration with a physician
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SB'; --Nurse midwife
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SC'; --Medically necessary service or supply
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SD'; --Services provided by registered nurse with specialized, highly technical home infusion training
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SE'; --State and/or federally-funded programs/services
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SF'; --Second opinion ordered by a professional review organization (pro) per section 9401, p.l. 99-272 (100% reimbursement - no medicare deductible or coinsurance)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SG'; --Ambulatory surgical center (asc) facility service
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SH'; --Second concurrently administered infusion therapy
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SJ'; --Third or more concurrently administered infusion therapy
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SK'; --Member of high risk population (use only with codes for immunization)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SL'; --State supplied vaccine
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SM'; --Second surgical opinion
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SN'; --Third surgical opinion
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SQ'; --Item ordered by home health
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SS'; --Home infusion services provided in the infusion suite of the iv therapy provider
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='ST'; --Related to trauma or injury
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SU'; --Procedure performed in physician's office (to denote use of facility AND equipment)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SV'; --Pharmaceuticals delivered to patient's home but not utilized
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SW'; --Services provided by a certified diabetic educator
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SY'; --Persons who are in close contact with member of high-risk population (use only with codes for immunization)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='SZ'; --Habilitative services
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='T1'; --Left foot, second digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='T2'; --Left foot, third digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='T3'; --Left foot, fourth digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='T4'; --Left foot, fifth digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='T5'; --Right foot, great toe
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='T6'; --Right foot, second digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='T7'; --Right foot, third digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='T8'; --Right foot, fourth digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='T9'; --Right foot, fifth digit
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TA'; --Left foot, great toe
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TC'; --Technical component
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TD'; --Rn
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TE'; --Lpn/lvn
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TF'; --Intermediate level of care
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TG'; --Complex/high tech level of care
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TH'; --Obstetrical treatment/services, prenatal or postpartum
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TJ'; --Program group, child and/or adolescent
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TK'; --Extra patient or passenger, non-ambulance
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TL'; --Early intervention/individualized family service plan (ifsp)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TM'; --Individualized education program (iep)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TN'; --Rural/outside providers' customary service area
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TP'; --Medical transport, unloaded vehicle
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TQ'; --Basic life support transport by a volunteer ambulance provider
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TR'; --School-based individualized education program (iep) services provided outside the public school district responsible for the student
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TS'; --Follow-up service
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TT'; --Individualized service provided to more than one patient in same setting
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TU'; --Special payment rate, overtime
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TV'; --Special payment rates, holidays/weekends
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='TW'; --Back-up equipment
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='U1'; --Medicaid level of care 1, as defined by each state
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='U2'; --Medicaid level of care 2, as defined by each state
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='U3'; --Medicaid level of care 3, as defined by each state
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='U4'; --Medicaid level of care 4, as defined by each state
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='U5'; --Medicaid level of care 5, as defined by each state
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='U6'; --Medicaid level of care 6, as defined by each state
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='U7'; --Medicaid level of care 7, as defined by each state
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='U8'; --Medicaid level of care 8, as defined by each state
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='U9'; --Medicaid level of care 9, as defined by each state
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UA'; --Medicaid level of care 10, as defined by each state
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UB'; --Medicaid level of care 11, as defined by each state
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UC'; --Medicaid level of care 12, as defined by each state
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UD'; --Medicaid level of care 13, as defined by each state
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UE'; --Used durable medical equipment
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UF'; --Services provided in the morning
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UG'; --Services provided in the afternoon
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UH'; --Services provided in the evening
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UJ'; --Services provided at night
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UK'; --Services provided on behalf of the client to someone other than the client (collateral relationship)
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UN'; --Two patients served
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UP'; --Three patients served
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UQ'; --Four patients served
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='UR'; --Five patients served
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='US'; --Six or more patients served
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='V5'; --Vascular catheter (alone or with any other vascular access)
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='V6'; --Arteriovenous graft (or other vascular access not including a vascular catheter)
	UPDATE concept_stage SET domain_id='Device' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='V7'; --Arteriovenous fistula only (in use with two needles)
	UPDATE concept_stage SET domain_id='Condition' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='V8'; --Infection present
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='V9'; --No infection present
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='VP'; --Aphakic patient
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='XE'; --Separate encounter, a service that is distinct because it occurred during a separate encounter
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='XP'; --Separate practitioner, a service that is distinct because it was performed by a different practitioner
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='XS'; --Separate structure, a service that is distinct because it was performed on a separate organ/structure
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='XU'; --Unusual non-overlapping service, the use of a service that is distinct because it does not overlap usual components of the main service
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code='ZA'; --Novartis/sandoz
	--2017 release added domains
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='FX'; --X-ray taken using film
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='PN'; --Non-excepted service provided at an off-campus, outpatient, provider-based department of a hospital
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='V1'; --Demonstration modifier 1
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='V2'; --Demonstration modifier 2
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='V3'; --Demonstration modifier 3
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='ZB'; --Pfizer/hospira
	--2018 release added domains
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='ZC';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='X5';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='X4';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='X3';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='X2';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='X1';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='VM';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='TB';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='QQ';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='JG';
	UPDATE concept_stage SET domain_id='Observation' WHERE vocabulary_id='HCPCS' AND concept_class_id='HCPCS Modifier' AND concept_code ='FY';
END $_$;

--if some codes does not have domain_id pick it up from existing concept table
UPDATE concept_stage cs
SET domain_id = c.domain_id
FROM concept c
WHERE c.concept_code = cs.concept_code
	AND c.vocabulary_id = cs.vocabulary_id
	AND cs.domain_id IS NULL
	AND cs.vocabulary_id = 'HCPCS';

--Procedure Drug codes are handled as Procedures, but this might change in near future. 
--Therefore, we are keeping an interim domain_id='Procedure Drug'
UPDATE concept_stage
SET domain_id = 'Procedure'
WHERE domain_id = 'Procedure Drug';

--4.3. Part 3. Since nobody really cares about Modifiers domain, in case 
UPDATE concept_stage
SET domain_id = 'Observation'
WHERE domain_id IS NULL
	AND concept_class_Id = 'HCPCS Modifier';

--5. Create concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT HCPC AS synonym_concept_code,
	synonym_name,
	'HCPCS' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM (
	SELECT SUBSTR(short_description, 1, 1000) AS synonym_name,
		HCPC
	FROM sources.anweb_v2
	
	UNION
	
	SELECT SUBSTR(long_description, 1, 1000) AS synonym_name,
		HCPC
	FROM sources.anweb_v2
	) AS s0

UNION ALL

VALUES ('U0001','COVID-19 testing in CDC laboratory','HCPCS',4180186),
	('U0002','COVID-19 testing in non-CDC laboratory','HCPCS',4180186);

--6. Run HCPCS/ProcedureDrug.sql. This will create all the input files for MapDrugVocabulary.sql
DO $_$
BEGIN
	PERFORM dev_hcpcs.ProcedureDrug();
END $_$;

--7. Run the HCPCS/MapDrugVocabulary.sql. This will produce a concept_relationship_stage with HCPCS to Rx RxNorm/RxNorm Extension relationships
DO $_$
BEGIN
	PERFORM dev_hcpcs.MapDrugVocabulary();
END $_$;

--8. Add upgrade relationships
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
SELECT DISTINCT concept_code_1,
	concept_code_2,
	'Concept replaced by' AS relationship_id,
	'HCPCS' AS vocabulary_id_1,
	'HCPCS' AS vocabulary_id_2,
	valid_start_date,
	valid_end_date,
	NULL AS invalid_reason
FROM (
	SELECT a.hcpc AS concept_code_1,
		a.xref1 AS concept_code_2,
		coalesce(a.add_date, a.act_eff_dt) AS valid_start_date,
		to_date('20991231', 'yyyymmdd') AS valid_end_date
	FROM sources.anweb_v2 a,
		sources.anweb_v2 b
	WHERE a.xref1 = b.hcpc
		AND a.term_dt IS NOT NULL
		AND b.term_dt IS NULL
	
	UNION ALL
	
	SELECT a.hcpc AS concept_code_1,
		a.xref2,
		coalesce(a.add_date, a.act_eff_dt),
		to_date('20991231', 'yyyymmdd')
	FROM sources.anweb_v2 a,
		sources.anweb_v2 b
	WHERE a.xref2 = b.hcpc
		AND a.term_dt IS NOT NULL
		AND b.term_dt IS NULL
	
	UNION ALL
	
	SELECT a.hcpc AS concept_code_1,
		a.xref3,
		coalesce(a.add_date, a.act_eff_dt),
		to_date('20991231', 'yyyymmdd')
	FROM sources.anweb_v2 a,
		sources.anweb_v2 b
	WHERE a.xref3 = b.hcpc
		AND a.term_dt IS NOT NULL
		AND b.term_dt IS NULL
	
	UNION ALL
	
	SELECT a.hcpc AS concept_code_1,
		a.xref4,
		coalesce(a.add_date, a.act_eff_dt),
		to_date('20991231', 'yyyymmdd')
	FROM sources.anweb_v2 a,
		sources.anweb_v2 b
	WHERE a.xref4 = b.hcpc
		AND a.term_dt IS NOT NULL
		AND b.term_dt IS NULL
	
	UNION ALL
	
	SELECT a.hcpc AS concept_code_1,
		a.xref5,
		coalesce(a.add_date, a.act_eff_dt),
		to_date('20991231', 'yyyymmdd')
	FROM sources.anweb_v2 a,
		sources.anweb_v2 b
	WHERE a.xref5 = b.hcpc
		AND a.term_dt IS NOT NULL
		AND b.term_dt IS NULL
	) i
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = i.concept_code_1
			AND crs_int.concept_code_2 = i.concept_code_2
			AND crs_int.vocabulary_id_1 = 'HCPCS'
			AND crs_int.vocabulary_id_2 = 'HCPCS'
			AND crs_int.relationship_id = 'Concept replaced by'
		);

--9. Create hierarchical relationships between HCPCS AND HCPCS class
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
SELECT DISTINCT a.hcpc AS concept_code_1,
	a.betos AS concept_code_2,
	'Is a' AS relationship_id,
	'HCPCS' AS vocabulary_id_1,
	'HCPCS' AS vocabulary_id_2,
	coalesce(a.add_date, a.act_eff_dt) AS valid_start_date,
	coalesce(a.term_dt, to_date('20991231', 'yyyymmdd')) AS valid_end_date,
	CASE 
		WHEN term_dt IS NULL
			THEN NULL
		WHEN xref1 IS NULL
			THEN 'D' -- deprecated
		ELSE NULL -- upgraded
		END AS invalid_reason
FROM sources.anweb_v2 a
JOIN concept c ON c.concept_code = a.betos
	AND c.concept_class_id = 'HCPCS Class'
	AND c.vocabulary_id = 'HCPCS'
	AND c.invalid_reason IS NULL;

--10. Add all other 'Concept replaced by' relationships
--!! still need to be investigated
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
SELECT c.concept_code AS concept_code_1,
	c1.concept_code AS concept_code_2,
	r.relationship_id AS relationship_id,
	c.vocabulary_id AS vocabulary_id_1,
	c1.vocabulary_id AS vocabulary_id_2,
	r.valid_start_date,
	r.valid_end_date,
	r.invalid_reason
FROM concept_relationship r,
	concept c,
	concept c1
WHERE c.concept_id = r.concept_id_1
	AND c.vocabulary_id = 'HCPCS'
	AND c1.concept_id = r.concept_id_2
	AND r.relationship_id IN (
		'Concept replaced by',
		'Concept same_as to',
		'Concept alt_to to',
		'Concept poss_eq to',
		'Concept was_a to'
		)
	AND r.invalid_reason IS NULL
	AND (
		SELECT COUNT(*)
		FROM concept_relationship r_int
		WHERE r_int.concept_id_1 = r.concept_id_1
			AND r_int.relationship_id = r.relationship_id
			AND r_int.invalid_reason IS NULL
		) = 1
	AND NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs
		WHERE crs.concept_code_1 = c.concept_code
			AND crs.vocabulary_id_1 = c.vocabulary_id
			AND crs.relationship_id = r.relationship_id
		);

--11. These 3 concepts (Buprenorphine/naloxone) are mapped incorrectly by map_drug but correctly in concept_relationship_manual
--will be removed after procedure_drug be fixed
DELETE
FROM concept_relationship_stage
WHERE concept_code_1 IN (
		'J0572',
		'J0573',
		'J0574'
		);

--12. Append manual relationships
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--13. Temporary solution: make concepts that are replaced by the non-existing concepts standard
--CPT4 doesn't have these concepts in sources yet somehow
UPDATE concept_stage cs
SET invalid_reason = NULL,
	standard_concept = 'S'
WHERE NOT EXISTS (
		SELECT 1
		FROM concept_relationship_stage crs_int
		WHERE crs_int.concept_code_1 = cs.concept_code
			AND crs_int.vocabulary_id_1 = cs.vocabulary_id
			AND crs_int.relationship_id IN (
				'Maps to',
				'Concept replaced by',
				'Concept same_as to',
				'Concept alt_to to',
				'Concept poss_eq to',
				'Concept was_a to'
				)
			AND crs_int.invalid_reason IS NULL
		)
	AND cs.invalid_reason = 'U';

--14. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--15. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
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

--18. All the codes that have mapping to RxNorm% should get domain_id='Drug'
UPDATE concept_stage cs
SET domain_id = 'Drug'
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage r
		WHERE r.concept_code_1 = cs.concept_code
			AND r.vocabulary_id_1 = cs.vocabulary_id
			AND r.invalid_reason IS NULL
			AND r.relationship_id = 'Maps to'
			AND r.vocabulary_id_2 LIKE 'RxNorm%'
		)
	AND cs.domain_id <> 'Drug';

--19. All (not only the drugs) concepts having mappings should be NON-standard
UPDATE concept_stage cs
SET standard_concept = NULL
WHERE EXISTS (
		SELECT 1
		FROM concept_relationship_stage r,
			concept c2
		WHERE r.concept_code_1 = cs.concept_code
			AND r.vocabulary_id_1 = cs.vocabulary_id
			AND r.concept_code_2 = c2.concept_code
			AND r.vocabulary_id_2 = c2.vocabulary_id
			AND r.invalid_reason IS NULL
			AND r.relationship_id = 'Maps to'
			AND NOT (
				r.concept_code_1 = r.concept_code_2
				AND r.vocabulary_id_1 = r.vocabulary_id_2
				) --exclude mappings to self
		)
	AND cs.standard_concept IS NOT NULL;

--20. Clean up , remove the 'HCPCS - SNOMED meas', 'HCPCS - SNOMED proc' relationships
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
SELECT a.concept_code,
	b.concept_code,
	a.vocabulary_id,
	b.vocabulary_id,
	relationship_id,
	r.valid_start_date,
	CURRENT_DATE,
	'D'
FROM concept a
JOIN concept_relationship r ON a.concept_id = concept_id_1
	AND r.invalid_reason IS NULL
JOIN concept b ON b.concept_id = concept_id_2
	AND b.vocabulary_id = 'SNOMED'
WHERE a.vocabulary_id = 'HCPCS'
	AND relationship_id IN (
		'HCPCS - SNOMED meas',
		'HCPCS - SNOMED proc'
		);

-- At the end, the three tables concept_stage, concept_relationship_stage AND concept_synonym_stage should be ready to be fed into the generic_update.sql script