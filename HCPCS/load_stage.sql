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
* Authors: Timur Vakhitov, Christian Reich, Anna Ostropolets, Dmitry Dymshyts, Alexander Davydov, Masha Khitrun
* Date: 2024
**************************************************************************/

--1. Update latest_update field to new date 
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
SELECT vocabulary_pack.CutConceptName(a.long_description) AS concept_name,
	c.domain_id AS domain_id,
	v.vocabulary_id,
	CASE
		WHEN LENGTH(a.hcpc) = 2
			THEN 'HCPCS Modifier'
		ELSE 'HCPCS'
		END AS concept_class_id,
	CASE
		WHEN a.term_dt IS NOT NULL
			AND a.xref1 IS NOT NULL -- !!means the concept is updated
			THEN NULL
		ELSE 'S' -- in other cases it's standard
		END AS standard_concept,
	a.hcpc AS concept_code,
	COALESCE(a.add_date, a.act_eff_dt) AS valid_start_date,
	COALESCE(a.term_dt, TO_DATE('20991231', 'yyyymmdd')) AS valid_end_date,
	CASE
		WHEN a.term_dt IS NULL
			THEN NULL
		WHEN a.xref1 IS NULL
			THEN NULL -- zombie concepts
		ELSE 'U' -- upgraded
		END AS invalid_reason
FROM sources.anweb_v2 a
JOIN vocabulary v ON v.vocabulary_id = 'HCPCS'
LEFT JOIN concept c ON c.concept_code = a.betos
	AND c.concept_class_id = 'HCPCS Class'
	AND c.vocabulary_id = 'HCPCS';

--4. Insert other existing HCPCS concepts that are absent in the source (zombie concepts)
INSERT INTO concept_stage (
	concept_name,
	vocabulary_id,
	concept_class_id,
	standard_concept,
	concept_code,
	valid_start_date,
	valid_end_date,
	invalid_reason
	)
SELECT c.concept_name,
	c.vocabulary_id,
	c.concept_class_id,
	CASE 
		WHEN c.concept_class_id = 'HCPCS Class'
			THEN 'C'
		ELSE c.standard_concept
		END AS standard_concept,
	c.concept_code,
	c.valid_start_date,
	c.valid_end_date,
	c.invalid_reason
FROM concept c
WHERE c.vocabulary_id = 'HCPCS'
ON CONFLICT DO NOTHING;

--5 Update domain_id in concept_stage
--5.1. Part 1. Update domain_id defined by rules
WITH t_domains
AS (
	SELECT hcpc.concept_code,
		CASE 
			WHEN concept_name LIKE '%per session%'
				THEN 'Procedure'
					-- A codes
			WHEN concept_code IN (
					'A4248',
					'A4802',
					'A9513',
					'A9517',
					'A9527',
					'A9530',
					'A9534',
					'A9543',
					'A9545',
					'A9563',
					'A9576',
					'A9564',
					'A9590',
					'A9600',
					'A9604',
					'A9605',
					'A9606',
					'A9607'
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
					'A4802',
					'A9152',
					'A9153',
					'A9180',
					'A9155',
					'A9160',
					'A9170'
					)
				AND l2.str <> 'Transport Services Including Ambulance'
				THEN 'Device' -- default for Level 1: A0000-A9999
			WHEN l2.str = 'Transport Services Including Ambulance'
				THEN 'Observation' -- Level 2: A0000-A0999
			WHEN concept_code IN (
					'A9160',
					'A9170'
					)
				THEN 'Observation'
			WHEN concept_code IN (
					'A4736',
					'A4737',
					'A9152',
					'A9180'
					)
				THEN 'Procedure'
			WHEN concept_code = 'A9153'
				THEN 'Drug' --Vitamin preparations
			WHEN concept_code = 'A9155'
				THEN 'Device' --Artificial saliva, 30 ml
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
					'C1360',
					'C1450'
					)
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'C7500' AND 'C7571'
			    OR concept_code BETWEEN 'C8004' AND 'C8006'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'C7900' AND 'C7903'
				THEN 'Observation'
			WHEN concept_code IN (
					'C9702',
					'C9708',
					'C9711'
					)
				THEN 'Device'
			WHEN concept_code IN (
					'C8953',
					'C8954',
					'C8955'
					)
				THEN 'Procedure'
			WHEN concept_code = 'C9060'
				THEN 'Device'
			WHEN concept_code IN (
					'C9060',
					'C9067',
					'C9068',
					'C9100',
					'C9102',
					'C9123',
					'C9150',
					'C9156',
			        'C9176',
					'C9200',
					'C9201',
					'C9221',
					'C9222',
					'C9246',
					'C9247',
			        'C9300',
					'C9458',
					'C9459',
					'C9461'
					) -- Contrast agent's
				THEN 'Device'
			WHEN concept_code BETWEEN 'C9000'
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
				THEN 'Procedure' -- Unclassified drugs or biologicals
			WHEN concept_code BETWEEN 'C9408'
					AND 'C9497'
				THEN 'Drug'
			WHEN concept_code BETWEEN 'C9600'
					AND 'C9803'
					OR concept_code = 'C9901'
				THEN 'Procedure'
			WHEN concept_code IN ('C9703','C9610')
				THEN 'Device'
			WHEN l1.str = 'C Codes - CMS Hospital Outpatient System'
				THEN 'Device' -- default for Level 1: C1000-C9999
					-- D codes
			WHEN concept_code BETWEEN 'D0120'
					AND 'D0191'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'D0210'
					AND 'D0350'
				THEN 'Device'
			WHEN concept_code BETWEEN 'D0360'
					AND 'D0415'
				OR concept_code = 'D0417'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'D0416'
					AND 'D0460'
				THEN 'Measurement'
			WHEN concept_code = 'D0501'
				THEN 'Measurement'
			WHEN concept_code BETWEEN 'D0470'
					AND 'D1208'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'D1310'
					AND 'D1330'
				THEN 'Observation' --Counselling
			WHEN concept_code = 'D1352'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'D1351'
					AND 'D2970'
				THEN 'Device'
			WHEN concept_code IN (
					'D1352',
					'D1555'
					)
				THEN 'Procedure'
			WHEN concept_code IN (
					'D5860',
					'D5861')
				OR concept_code BETWEEN 'D5911'
					AND 'D5999'
			THEN 'Device'
			WHEN concept_code BETWEEN 'D6053'
					AND 'D6985'
				THEN 'Device'
			WHEN concept_code BETWEEN 'D2971'
					AND 'D9248'
				THEN 'Procedure' -- D-code procedures
			WHEN concept_code BETWEEN 'D9610'
					AND 'D9630'
				THEN 'Drug'
			WHEN concept_code BETWEEN 'D9910'
					AND 'D9999'
				THEN 'Procedure'
					-- E codes
			WHEN concept_code like 'E%'
			       AND length(concept_code) >2
				THEN 'Device' -- all of them Level 1: E0100-E9999
					-- G codes
		    WHEN concept_code BETWEEN 'G0011'
		        AND 'G0013' -- HIV pre-exposure prophylaxis
		        THEN 'Procedure'
			WHEN l2.str = 'Vaccine Administration'
				THEN 'Drug' -- Level 2: G0008-G0010
			WHEN concept_code = 'G0002'
				THEN 'Device'
			WHEN concept_code BETWEEN 'G0019' AND 'G0024'
				OR concept_code BETWEEN 'G0028' AND 'G0029'
				THEN 'Observation' --Health services
			WHEN concept_code = 'G0025'
				THEN 'Device'
			WHEN concept_code IN (
					'G0026',
					'G0027'
					)
				THEN 'Measurement' -- Level 2: G0027-G0027
			WHEN concept_code BETWEEN 'G0048'
					AND 'G0067'
				THEN 'Observation' -- codes added in 2022, MIPS specialty sets for particular medical specialties
			WHEN concept_code BETWEEN 'G0068'
					AND 'G0090'
				THEN 'Observation' -- Professional services and fees
			WHEN concept_code BETWEEN 'G0101'
					AND 'G0107'
				THEN 'Measurement'
			WHEN l2.str = 'Diabetes Management Training Services'
				THEN 'Observation' -- Level 2: G0108-G0109
			WHEN concept_code BETWEEN 'G0110'
					AND 'G0116'
				THEN 'Observation' -- Education
			WHEN concept_code BETWEEN 'G0117'
					AND 'G0124'
				THEN 'Measurement' -- Screening procedures
			WHEN concept_code BETWEEN 'G0128'
					AND 'G0129'
				THEN 'Observation' -- Level 2: G0128-G0129 previously 'Service, Nurse AND OT'
			WHEN concept_code BETWEEN 'G0141'
					AND 'G0148'
					AND concept_code <> 'G0146'
				THEN 'Measurement' -- G0141-G0148 Screening cytopathology
			WHEN concept_code IN ('G0146', 'G0140')
				THEN 'Observation' --Principal illness navigation
			WHEN concept_code BETWEEN 'G0151'
					AND 'G0164'
				THEN 'Observation' -- Level 2: G0151-G0166 previously 'Services, Allied Health'
			WHEN concept_code BETWEEN 'G0165'
					AND 'G0174'
				THEN 'Procedure'
			WHEN concept_code = 'G0175'
				THEN 'Observation' -- Level 2: G0175-G0175 previously 'Team Conference'
			WHEN concept_code BETWEEN 'G0179'
					AND 'G0182'
				THEN 'Observation' -- Level 2: G0179-G0182 previously 'Physician Services'
			WHEN concept_code IN ('G0202',
                'G0183')
				THEN 'Measurement'
			WHEN concept_code BETWEEN 'G0237'
					AND 'G0239'
				THEN 'Procedure' -- Level 2: G0237-G0239 previously 'Therapeutic Procedures'
			WHEN concept_code BETWEEN 'G0240'
					AND 'G0241' -- Critical care services
				THEN 'Observation'
			WHEN concept_code BETWEEN 'G0244'
					AND 'G0246'
				THEN 'Observation' -- Level 2: G0245-G0246  'Physician Services, Diabetic'
			WHEN concept_code BETWEEN 'G0248'
					AND 'G0250'
				THEN 'Observation' -- Level 2: G0248-G0250 previously 'Demonstration, INR'
			WHEN concept_code IN (
					'G0293',
					'G0294',
					'G0296')
				THEN 'Observation'
			WHEN concept_code = 'G3001'
				THEN 'Drug' -- Level 2: G3001-G3001 previously 'Tositumomab'
			WHEN concept_code BETWEEN 'G0300'
					AND 'G0305'
				THEN 'Observation' -- Level 2: G0302-G0305 previously 'Services, Pulmonary Surgery'
			WHEN concept_code IN (
					'G0306',
					'G0307',
					'G0328'
					)
				THEN 'Measurement'
			WHEN concept_code BETWEEN 'G0308'
					AND 'G0327'
				THEN 'Observation' -- ESRD services
			WHEN concept_code = 'G0333'
				THEN 'Observation' -- Level 2: G0333-G0333 previously 'Fee, Pharmacy'
			WHEN concept_code = 'G0337'
				THEN 'Observation' -- Level 2: G0337-G0337 previously 'Hospice'
			WHEN concept_code BETWEEN 'G0369'
					AND 'G0376' -- Fees
				THEN 'Observation'
			WHEN l2.str = 'Hospital Services: Observation and Emergency Department'
				THEN 'Observation' -- Level 2: G0378-G0384
			WHEN l2.str = 'Trauma Response Team'
				THEN 'Observation' -- Level 2: G0390-G0390
			WHEN l2.str = 'Home Sleep Study Test'
				THEN 'Procedure' --G0398-G0400
			WHEN l2.str = 'Initial Examination for Medicare Enrollment'
				THEN 'Observation' -- Level 2: G0402-G0402
			WHEN l2.str = 'Electrocardiogram'
				THEN 'Procedure' -- Level 2: G0403-G0405 -- changed to procedure because there could be various results
			WHEN l2.str = 'Follow-up Telehealth Consultation'
				THEN 'Observation' -- Level 2: G0406-G0408
			WHEN concept_code = 'G0409'
				THEN 'Observation'
			WHEN concept_code IN ('G0410', 'G0411')
				THEN 'Procedure' -- Psychotherapy
			WHEN concept_code BETWEEN 'G0416'
					AND 'G0419'
				THEN 'Procedure' -- Level 2: G0416-G0419 previously 'Pathology, Surgical'
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
			WHEN concept_code BETWEEN 'G0442'
					AND 'G0447'
				THEN 'Procedure' -- Various screens AND counseling
			WHEN concept_code = 'G0448'
				THEN 'Procedure' -- Insertion or replacement of a permanent pacing cardioverter-defibrillator system with transvenous lead(s), single or dual chamber with insertion of pacing electrode, cardiac venous system, for left ventricular pacing
			WHEN concept_code = 'G0450'
				THEN 'Measurement' -- SCREENING FOR SEXUALLY TRANSMITTED INFECTIONS CHLAMYDIA
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
				THEN 'Procedure' -- Autologous platelet rich plasma for chronic wounds/ulcers, including phlebotomy, centrifugation, AND all other preparatory procedures, administration AND dressings, per treatment
			WHEN concept_code IN (
					'G0461',
					'G0462'
					)
				THEN 'Measurement' -- Immunohistochemistry or immunocytochemistry
			WHEN concept_code = 'G0463'
				THEN 'Observation' -- Hospital outpatient clinic visit for assessment AND management of a patient
			WHEN concept_code = 'G0464'
				THEN 'Measurement' -- Colorectal cancer screening; stool-based dna AND fecal occult hemoglobin (e.g., kras, ndrg4 AND bmp3)
			WHEN concept_code BETWEEN 'G0466'
					AND 'G0470'
				THEN 'Observation' -- Federally qualified health center (fqhc) visits
			WHEN concept_code = 'G0471'
				THEN 'Procedure' -- Collection of venous blood by venipuncture or urine sample by catheterization from an individual in a skilled nursing facility (snf) or by a laboratory on behalf of a home health agency (hha)
			WHEN concept_code = 'G0472'
				THEN 'Measurement' -- Hepatitis c antibody screening, for individual at high risk AND other covered indication(s)
			WHEN concept_code = 'G0473'
				THEN 'Procedure' -- Face-to-face behavioral counseling for obesity, group (2-10), 30 minutes
			WHEN concept_code BETWEEN 'G0475'
					AND 'G0483'
				THEN 'Measurement' -- Lab tests
			WHEN concept_code = 'G0490'
				THEN 'Observation'
			WHEN concept_code BETWEEN 'G0493'
					AND 'G0496'
				THEN 'Observation'
			WHEN concept_code BETWEEN 'G0507'
					AND 'G0514'
				THEN 'Observation' -- Preventive services
			WHEN concept_code IN ('G0659',
                'G0567')
				THEN 'Measurement'
			WHEN concept_code = 'G2250'
				THEN 'Procedure' --	Remote assessment of recorded video and/or images
			WHEN concept_code BETWEEN 'G0908'
					AND 'G2252'
				AND concept_code NOT BETWEEN 'G2067'
					AND 'G2075'
				AND concept_code NOT IN (
					'G2000',
					'G2010',
					'G2011',
					'G2023',
					'G2024',
					'G2102',
					'G2170',
					'G2171'
					)
				THEN 'Observation' -- various documented levels AND assessments
			WHEN concept_code BETWEEN 'G2067'
					AND 'G2075'
				THEN 'Procedure'
			WHEN concept_code IN (
					'G2000',
					'G2010',
					'G2011',
					'G2023',
					'G2024'
					'G2102',
					'G2170',
					'G2171'
					)
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'G2086'
					AND 'G2088'
				THEN 'Procedure' -- Office-based treatment for opioid use disorder
			WHEN concept_code = 'G3001'
				THEN 'Drug' -- Administration and supply of tositumomab, 450 mg
			WHEN concept_code BETWEEN 'G4000'
					AND 'G4038'
				THEN 'Observation' -- codes added in 2022, MIPS specialty sets for particular medical specialties
			WHEN concept_code BETWEEN 'G6001'
					AND 'G6017'
				THEN 'Procedure' -- various radiation treatment deliveries
			WHEN concept_code BETWEEN 'G6018'
					AND 'G6028'
				THEN 'Procedure' -- various endoscopies
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
			WHEN concept_code BETWEEN 'G9481'
					AND 'G9490'
				THEN 'Observation' -- Visits
			WHEN concept_code IN (
					'G9639',
					'G9641',
					'G9654',
					'G9770',
					'G9937',
					'G9839'
					)
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'G9679'
					AND 'G9684'
				THEN 'Observation'
			WHEN concept_code BETWEEN 'G9514'
					AND 'G9517'
				THEN 'Observation'
			WHEN concept_code IN (
					'G9771',
					'G9773',
					'G9812',
					'G9601',
					'G9602'
					)
				THEN 'Observation'
			WHEN concept_code = 'G9642' -- Current smoker
				THEN 'Observation'
			WHEN l2.str IN (
					'Quality Measures: Miscellaneous',
					'Quality Measures',
					'Demonstration Project'
					)
				THEN 'Observation'
			WHEN concept_code IN (
					'G9752',
					'G9756',
					'G9757',
					'G9643'
					)
				THEN 'Procedure' -- Emergency surgery, Elective surgery, Surgical procedures that included the use of silicone oil
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
					AND 'H2041'
				THEN 'Observation' -- various services
			WHEN l1.str = 'Behavioral Health and/or Substance Abuse Treatment Services'
				THEN 'Procedure' -- default for all Level 1: H0001-H9999
					-- J codes
			WHEN concept_code IN (
					'J7303',
					'J7304',
					'J7341'
					)
				THEN 'Device'
			WHEN concept_code = 'J7345'
				THEN 'Drug' -- Aminolevulinic acid hcl for topical administration, 10% gel, 10 mg
			WHEN concept_code BETWEEN 'J7343'
					AND 'J7350'
				THEN 'Device'
			WHEN concept_code IN (
					'J7051',
					'J1815',
					'J1817',
					'J2050',
					'J3535',
					'J7140',
					'J7150',
					'J7599',
					'J8999',
					'J9999'
					)
				THEN 'Procedure'
			WHEN l1.str = 'J Codes - Drugs'
				THEN 'Drug' -- Level 1: J0100-J9999
					-- K codes
			WHEN concept_code LIKE 'K%'
				AND concept_code NOT IN (
					'K0124',
					'K0285',
					'K0449',
					'K1034'
					)
				THEN 'Device' -- Durable Medical Equipment For Medicare Administrative Contractors
			WHEN concept_code = 'K0124'
				THEN 'Procedure' -- Monoclonal antibodies
			WHEN concept_code IN (
					'K0285',
					'K0449',
					'K1034'
					)
				THEN 'Observation'
					-- L codes
			WHEN l1.str = 'L Codes'
				AND concept_code NOT IN (
					'L4200',
					'L5310',
					'L5311',
					'L5330',
					'L5340',
					'L7500',
					'L9999'
					)
				THEN 'Device' -- Level 1: L0000-L9999
			WHEN concept_code IN (
					'L4200',
					'L7500',
					'L9999'
					)
				THEN 'Observation'
			WHEN concept_code IN (
					'L5310',
					'L5311',
					'L5330',
					'L5340'
					)
				THEN 'Procedure'
					-- M codes
			WHEN concept_code IN (
					'M0075', --Cellular therapy
					'M0076', --Prolotherapy
					'M0100', --Intragastric hypothermia using gastric freezing
					'M0201', -- Covid-19 vaccine administration
					'M0300', --Iv chelation therapy (chemical endarterectomy)
					'M0301', --Fabric wrapping of abdominal aneurysm
					'M0235', -- Intravenous infusion, monoclonal antibody products
			        'M0236'
			                     ) --Fabric wrapping of abdominal aneurysm
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'M0220'
					AND 'M0250'
				THEN 'Drug'
			WHEN l1.str = 'Other Medical Services'
				THEN 'Observation' -- Level 1: M0000-M0301
					-- P codes
			WHEN l2.str = 'Chemistry and Toxicology Tests'
				THEN 'Measurement' -- Level 2: P2028-P2038
			WHEN l2.str = 'Pathology Screening Tests'
				THEN 'Measurement' -- Level 2: P3000-P3001
			WHEN l2.str = 'Microbiology Tests'
				THEN 'Measurement' -- Level 2: P7001-P7001
			WHEN concept_code = 'P9012'
				THEN 'Device' -- Cryoprecipitate
			WHEN concept_code LIKE 'P90%'
				AND concept_code NOT BETWEEN 'P9041'
					AND 'P9048'
				THEN 'Device' -- All other P90% - blood components (AVOF-707)
			WHEN concept_code = 'P9044'
				THEN 'Device'
			WHEN concept_code BETWEEN 'P9041'
					AND 'P9043'
				OR concept_code BETWEEN 'P9045'
					AND 'P9048'
				THEN 'Drug' --Albumin preparations
			WHEN l2.str = 'Miscellaneous Pathology and Laboratory Services'
				THEN 'Procedure' -- Level 2: P9010-P9100
			WHEN l2.str = 'Catheterization for Specimen Collection'
				THEN 'Procedure' -- Level 2: P9612-P9615
					-- Q codes
			WHEN l2.str = 'Cardiokymography (CMS Temporary Codes)'
				THEN 'Procedure' -- Level 2: Q0035-Q0035
			WHEN l2.str = 'Chemotherapy (CMS Temporary Codes)'
				OR concept_code BETWEEN 'Q0081'
					AND 'Q0085'
				THEN 'Procedure' -- Level 2: Q0081-Q0085
			WHEN concept_code IN (
					'Q0061',
					'Q0065'
					)
				THEN 'Measurement'
			WHEN concept_code = 'Q0090'
				THEN 'Drug' -- Levonorgestrel-releasing intrauterine contraceptive system, (skyla), 13.5 mg
			WHEN l2.str = 'Smear, Papanicolaou (CMS Temporary Codes)'
				THEN 'Procedure' -- Level 2: Q0091-Q0091, only getting the smear, no interpretation
			WHEN l2.str = 'Equipment, X-Ray, Portable (CMS Temporary Codes)'
				THEN 'Observation' -- Level 2: Q0092-Q0092, only setup
			WHEN l2.str = 'Laboratory (CMS Temporary Codes)'
				THEN 'Measurement' -- Level 2: Q0111-Q0115
			WHEN concept_code in ('Q0188', 'Q0235')
				THEN 'Procedure'
		    WHEN concept_code BETWEEN 'Q0136'
					AND 'Q0249'
				AND concept_code NOT BETWEEN 'Q0182'
					AND 'Q0188'
				THEN 'Drug'
			WHEN concept_code IN (
					'Q0182',
					'Q0183',
					'Q0184',
					'Q0185'
					)
				THEN 'Device'
			WHEN concept_code = 'Q0186'
				THEN 'Observation'
			WHEN l2.str = 'Ventricular Assist Devices (CMS Temporary Codes)'
				THEN 'Device' -- Level 2: Q0477-Q0509
			WHEN concept_code BETWEEN 'Q0510'
					AND 'Q0514' -- Fees
				THEN 'Observation'
			WHEN concept_code = 'Q0515'
				THEN 'Drug'
			WHEN concept_code BETWEEN 'Q0516' AND 'Q0521'
				THEN 'Observation'
			WHEN concept_code BETWEEN 'Q1001'
					AND 'Q1005'
				THEN 'Device' -- Intraocular lens
			WHEN concept_code BETWEEN 'Q2001'
					AND 'Q2051'
				THEN 'Drug'
			WHEN concept_code = 'Q2052'
				THEN 'Observation'
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
			WHEN concept_code = 'Q3031'
				THEN 'Measurement' -- Collagen skin test
			WHEN l2.str = 'Supplies, Cast (CMS Temporary Codes)'
				THEN 'Device' -- Level 2: Q4001-Q4051
			WHEN concept_code BETWEEN 'Q4052'
					AND 'Q4099'
				AND concept_code <> 'Q4078'
				THEN 'Drug'
			WHEN concept_code = 'Q4078'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'Q4100'
					AND 'Q4433'
				THEN 'Device' -- Tissue substitutes
			WHEN l2.str = 'Hospice Care (CMS Temporary Codes)'
				THEN 'Observation' --Level 2: Q5001-Q5010
			WHEN concept_code BETWEEN 'Q5101'
					AND 'Q5131'
				THEN 'Drug'
			WHEN concept_code BETWEEN 'Q9941'
					AND 'Q9944'
				THEN 'Drug'
			WHEN concept_code BETWEEN 'Q9945'
					AND 'Q9969'
				THEN 'Device' -- Contrast Agents
			WHEN concept_code = 'Q9977'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'Q9970'
					AND 'Q9995'
				AND concept_code NOT IN (
					'Q9982',
					'Q9983',
					'Q9987',
					'Q9988',
					'Q9994'
					)
				THEN 'Drug'
			WHEN concept_code IN (
					'Q9982',
					'Q9983',
					'Q9988',
					'Q9994'
					)
				THEN 'Device'
			WHEN concept_code = 'Q9987' --Pathogen test for platelets
				THEN 'Procedure'
					-- R codes
			WHEN concept_code BETWEEN 'R0070'
					AND 'R0076'
				THEN 'Observation' --Transportation of equipment
					-- S codes
			WHEN concept_code BETWEEN 'S0009'
					AND 'S0198' --'Non-Medicare Drugs'
				THEN 'Drug'
			WHEN concept_code BETWEEN 'S0201'
					AND 'S0342' -- 'Provider Services'
				THEN 'Observation' -- includes the previous
			WHEN concept_code BETWEEN 'S0345'
					AND 'S0347'
				THEN 'Procedure' -- ECG monitoring
			WHEN concept_code BETWEEN 'S0390'
					AND 'S0395'
				THEN 'Procedure'
			WHEN concept_code = 'S0400'
				THEN 'Observation'
			WHEN concept_code = 'S0592'
				THEN 'Procedure' -- Comprehensive contact lens evaluation
			WHEN concept_code BETWEEN 'S0500'
					AND 'S0596'
				THEN 'Device' -- lenses, includes the previous
			WHEN concept_code BETWEEN 'S0601'
					AND 'S0820'
				THEN 'Procedure'
			WHEN concept_code = 'S0830'
				THEN 'Measurement' -- Ultrasound pachymetry
			WHEN concept_code BETWEEN 'S1001'
					AND 'S1040'
				THEN 'Device'
			WHEN concept_code = 'S1090'
				THEN 'Drug' -- Mometasone furoate sinus implant, 370 micrograms
			WHEN concept_code = 'S1091'
				THEN 'Device' -- Stent, non-coronary, temporary, with delivery system
			WHEN concept_code BETWEEN 'S2050'
					AND 'S3000'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'S3005'
					AND 'S3601'
				THEN 'Observation'
			WHEN concept_code BETWEEN 'S3618'
					AND 'S3890'
				THEN 'Measurement' -- various genetic tests AND prenatal screenings
			WHEN concept_code BETWEEN 'S3900'
					AND 'S3906'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'S4030'
					AND 'S4031'
				THEN 'Observation' -- Sperm procurement and cryopreservation services
			WHEN concept_code = 'S4024'
		        THEN 'Device'
		    WHEN concept_code BETWEEN 'S4005'
					AND 'S4042'
				THEN 'Procedure' -- IVF procedures
			WHEN concept_code BETWEEN 'S4988'
					AND 'S4989'
				THEN 'Device' -- Contraceptive implant
			WHEN concept_code IN (
					'S5000',
					'S5001'
					)
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'S4980'
					AND 'S5014'
				AND concept_code NOT IN (
					'S5002',
					'S5003'
					)
				THEN 'Drug' -- various
			WHEN concept_code IN (
					'S5002',
					'S5003'
					)
				THEN 'Device' -- parenteral nutrition
			WHEN concept_code BETWEEN 'S5016'
					AND 'S5021'
				THEN 'Observation'
			WHEN concept_code = 'S5022'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'S5025'
					AND 'S5036'
				THEN 'Observation'
			WHEN concept_code BETWEEN 'S5180'
					AND 'S5181'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'S5100'
					AND 'S5199'
				THEN 'Observation' -- various care services
			WHEN concept_code BETWEEN 'S5497'
					AND 'S5523'
				THEN 'Procedure' -- Home infusion therapy
			WHEN concept_code BETWEEN 'S5550'
					AND 'S5553'
				THEN 'Procedure' -- various Insulin forms
			WHEN concept_code BETWEEN 'S5560'
					AND 'S5571'
				THEN 'Device' -- various Insulin delivery devices
			WHEN concept_code BETWEEN 'S8001'
					AND 'S8093'
				THEN 'Procedure' -- various imaging
			WHEN concept_code = 'S8110'
				THEN 'Measurement' -- Peak expiratory flow rate (physician services)
			WHEN concept_code BETWEEN 'S8095'
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
			WHEN concept_code = 'S9085'
				THEN 'Procedure' --Meniscal allograft transplantation
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
			WHEN concept_code BETWEEN 'S9200'
					AND 'S9214'
				THEN 'Observation' -- Home management
			WHEN concept_code BETWEEN 'S9325'
					AND 'S9379'
				AND concept_name LIKE 'Home%therapy%'
				THEN 'Procedure' -- home infusions AND home therapy without exact drugs, per diem
			WHEN concept_code BETWEEN 'S9381'
					AND 'S9430'
				THEN 'Observation'
			WHEN concept_code BETWEEN 'S9432'
					AND 'S9435'
				THEN 'Device' -- Medical food
			WHEN concept_code BETWEEN 'S9436'AND 'S9473'
					OR concept_code BETWEEN 'S9476' AND 'S9485'
				THEN 'Observation' -- Educational classes and management programs
			WHEN concept_code BETWEEN 'S9490'
					AND 'S9810'
				THEN 'Procedure' -- Home infusion therapy, exact group of drugs
					-- T codes
			WHEN concept_code = 'T1006'
				THEN 'Procedure' -- Alcohol and/or substance abuse services, family/couple counseling
			WHEN concept_code = 'T1500'
				THEN 'Device'
			WHEN concept_code IN (
					'T1502',
					'T1503'
					)
				THEN 'Procedure' -- Administration of medication without saying which one (Administration of medication, other than oral and/or injectable, by a health care agency/professional, per visit)
			WHEN concept_code BETWEEN 'T1505'
					AND 'T1999'
				THEN 'Device'
			WHEN concept_code IN (
					'T2028',
					'T2029'
					)
				THEN 'Device'
			WHEN concept_code BETWEEN 'T4521'
					AND 'T5999'
				THEN 'Device'
			WHEN l1.str = 'Temporary National Codes Established by Private Payers'
				THEN 'Observation' -- Default for Level 1: S0000-S9999 AND Level 1: T1000-T9999
					-- U codes
			WHEN concept_code LIKE 'U%'
				THEN 'Measurement'
					-- V codes
			WHEN concept_code BETWEEN 'V2624'
					AND 'V2626'
				OR concept_code = 'V2628'
				THEN 'Procedure' -- Working on ocular prosthesis
			WHEN concept_code IN (
					'V2785',
					'V2787',
					'V2788'
					)
				THEN 'Procedure' -- Processing or correcting procedure
			WHEN concept_code = 'V2799'
				THEN 'Observation' -- Vision item or service, miscellaneous
			WHEN concept_code IN (
					'V5008',
					'V5010'
					)
				THEN 'Measurement' -- Hearing screening AND assessment of hearing aide
			WHEN concept_code IN (
					'V5011',
					'V5014'
					)
				THEN 'Procedure' -- fitting of hearing aide
			WHEN concept_code = 'V5020'
				THEN 'Observation' -- Conformity evaluation
			WHEN concept_code = 'V5275' -- Ear impression, each
					OR concept_code = 'V5299' --Hearing service, miscellaneous
				THEN 'Observation'
			WHEN concept_code BETWEEN 'V5300'
					AND 'V5364'
					AND concept_code <> 'V5336'
				THEN 'Measurement' -- various screening
			WHEN concept_code = 'V5336'
				THEN 'Procedure'
			WHEN l1.str = 'V Codes'
				THEN 'Device' -- default for Level 1: V0000-V5999 Vision AND hearing services
			ELSE COALESCE(hcpc.domain_id, 'Observation') -- use 'observation' in other cases
			END AS domain_id
	FROM concept_stage hcpc
	LEFT JOIN (
		SELECT code,
			(ARRAY(SELECT UNNEST(REGEXP_MATCHES(code, '[A-Z]\d{4}', 'g')))) [1] AS lo,
			(ARRAY(SELECT UNNEST(REGEXP_MATCHES(code, '[A-Z]\d{4}', 'g')))) [2] AS hi,
			str
		FROM sources.mrconso
		WHERE sab = 'HCPCS'
			AND code LIKE 'Level 1%'
		) l1 ON hcpc.concept_code BETWEEN l1.lo
			AND l1.hi
	LEFT JOIN (
		SELECT code,
			(ARRAY(SELECT UNNEST(REGEXP_MATCHES(code, '[A-Z]\d{4}', 'g')))) [1] AS lo,
			(ARRAY(SELECT UNNEST(REGEXP_MATCHES(code, '[A-Z]\d{4}', 'g')))) [2] AS hi,
			str
		FROM sources.mrconso
		WHERE sab = 'HCPCS'
			AND code LIKE 'Level 2%'
		) l2 ON hcpc.concept_code BETWEEN l2.lo
			AND l2.hi
	LEFT JOIN (
		SELECT code,
			(ARRAY(SELECT UNNEST(REGEXP_MATCHES(code, '[A-Z]\d{4}', 'g')))) [1] AS lo,
			(ARRAY(SELECT UNNEST(REGEXP_MATCHES(code, '[A-Z]\d{4}', 'g')))) [2] AS hi,
			str
		FROM sources.mrconso
		WHERE sab = 'HCPCS'
			AND code LIKE 'Level 3%'
		) l3 ON hcpc.concept_code BETWEEN l3.lo
			AND l3.hi
	WHERE LENGTH(concept_code) > 2
	)
UPDATE concept_stage cs
SET domain_id = t.domain_id
FROM t_domains t
WHERE cs.concept_code = t.concept_code
	AND cs.concept_class_id <> 'HCPCS Class';

-- 5.2. If some codes do not have domain_id pick it up from existing concept table
UPDATE concept_stage cs
SET domain_id = c.domain_id
FROM concept c
WHERE c.concept_code = cs.concept_code
	AND c.vocabulary_id = cs.vocabulary_id
	AND cs.domain_id IS NULL
	AND cs.vocabulary_id = 'HCPCS';

--5.3. Insert missing codes from manual extraction and assign domains to those concepts can't be assigned automatically
--ProcessManualConcepts
DO
$_$
    BEGIN
        PERFORM VOCABULARY_PACK.ProcessManualConcepts();
    END
$_$;

--5.4. Since nobody really cares about Modifiers domain, in case it's not covered by the concept_manual, set it to Observation
UPDATE concept_stage
SET domain_id = 'Observation'
WHERE domain_id IS NULL
	AND concept_class_Id = 'HCPCS Modifier';

--6. Fill concept_synonym_stage
INSERT INTO concept_synonym_stage (
	synonym_concept_code,
	synonym_name,
	synonym_vocabulary_id,
	language_concept_id
	)
SELECT DISTINCT s0.hcpc AS synonym_concept_code,
	s0.synonym_name,
	'HCPCS' AS synonym_vocabulary_id,
	4180186 AS language_concept_id -- English
FROM (
	SELECT vocabulary_pack.CutConceptSynonymName(short_description) AS synonym_name,
		hcpc
	FROM sources.anweb_v2
	
	UNION ALL
	
	SELECT vocabulary_pack.CutConceptSynonymName(long_description) AS synonym_name,
		hcpc
	FROM sources.anweb_v2
	) AS s0;

--6.1. Add synonyms from the manual table (concept_synonym_manual)
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualSynonyms();
END $_$;

--7. Add upgrade relationships
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
		COALESCE(a.add_date, a.act_eff_dt) AS valid_start_date,
		TO_DATE('20991231', 'yyyymmdd') AS valid_end_date
	FROM sources.anweb_v2 a,
		sources.anweb_v2 b
	WHERE a.xref1 = b.hcpc
		AND a.term_dt IS NOT NULL
		AND b.term_dt IS NULL
	
	UNION ALL
	
	SELECT a.hcpc AS concept_code_1,
		a.xref2,
		COALESCE(a.add_date, a.act_eff_dt),
		TO_DATE('20991231', 'yyyymmdd')
	FROM sources.anweb_v2 a,
		sources.anweb_v2 b
	WHERE a.xref2 = b.hcpc
		AND a.term_dt IS NOT NULL
		AND b.term_dt IS NULL
	
	UNION ALL
	
	SELECT a.hcpc AS concept_code_1,
		a.xref3,
		COALESCE(a.add_date, a.act_eff_dt),
		TO_DATE('20991231', 'yyyymmdd')
	FROM sources.anweb_v2 a,
		sources.anweb_v2 b
	WHERE a.xref3 = b.hcpc
		AND a.term_dt IS NOT NULL
		AND b.term_dt IS NULL
	
	UNION ALL
	
	SELECT a.hcpc AS concept_code_1,
		a.xref4,
		COALESCE(a.add_date, a.act_eff_dt),
		TO_DATE('20991231', 'yyyymmdd')
	FROM sources.anweb_v2 a,
		sources.anweb_v2 b
	WHERE a.xref4 = b.hcpc
		AND a.term_dt IS NOT NULL
		AND b.term_dt IS NULL
	
	UNION ALL
	
	SELECT a.hcpc AS concept_code_1,
		a.xref5,
		COALESCE(a.add_date, a.act_eff_dt),
		TO_DATE('20991231', 'yyyymmdd')
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

--8. Add all other 'Concept replaced by' and hierarchical relationships for zombie concepts
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
FROM concept_relationship r
JOIN concept c ON c.concept_id = r.concept_id_1
	AND c.vocabulary_id = 'HCPCS'
JOIN concept c1 ON c1.concept_id = r.concept_id_2
	AND c1.vocabulary_id = 'HCPCS'
WHERE r.relationship_id IN (
		'Concept replaced by',
		'Concept same_as to',
		'Concept alt_to to',
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

--9. Working with replacement mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.CheckReplacementMappings();
END $_$;

--10. Update names of zombie concepts
UPDATE concept_stage cs
SET concept_name = CASE 
		WHEN LENGTH(concept_name) <= 242
			THEN concept_name || ' (Deprecated)'
		ELSE LEFT(concept_name, 239) || '... (Deprecated)'
		END,
	invalid_reason = CASE 
		WHEN cs.invalid_reason = 'U'
			THEN cs.invalid_reason
		ELSE NULL
		END,
	standard_concept = CASE 
		WHEN cs.invalid_reason = 'U'
			THEN NULL
		ELSE 'S'
		END
WHERE valid_end_date < TO_DATE('20991231', 'YYYYMMDD')
	AND concept_name NOT LIKE '%(Deprecated)'
	AND concept_class_id <> 'HCPCS Class';

--11. Drugs should be non-standard:
UPDATE concept_stage
SET standard_concept = NULL
WHERE domain_id = 'Drug'
AND vocabulary_id = 'HCPCS';

--12. Append manual changes
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualConcepts();
END $_$;

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.ProcessManualRelationships();
END $_$;

--13. Add mapping from deprecated to fresh concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.AddFreshMAPSTO();
	PERFORM VOCABULARY_PACK.AddFreshMapsToValue();
	PERFORM VOCABULARY_PACK.AddPropagatedHierarchyMapsTo(null, '{RxNorm}', null);
END $_$;

--14. Deprecate 'Maps to' mappings to deprecated and upgraded concepts
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeprecateWrongMAPSTO();
END $_$;

--15. Delete ambiguous 'Maps to' mappings
DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.DeleteAmbiguousMAPSTO();
END $_$;

--16. All non-standard "zombie" concepts should be deprecated:
UPDATE concept_stage c
SET invalid_reason = 'D'
WHERE c.valid_end_date < current_date
AND c.standard_concept is null;

-- At the end, the concept_stage, concept_relationship_stage and concept_synonym_stage tables are ready to be fed into the generic_update script