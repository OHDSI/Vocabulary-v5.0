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
		    -- Modifiers:
            WHEN concept_class_id = 'HCPCS Modifier'
		            AND (
		                concept_code BETWEEN 'A1' AND 'A9'
                        OR concept_code BETWEEN 'AU' AND 'AY'
                        OR concept_code BETWEEN 'K0' AND 'KA'
                        OR concept_code BETWEEN 'LR' AND 'LS'
                        OR concept_code BETWEEN 'V5' AND 'V7'
                        OR concept_code IN
                           ('BA', 'BO', 'EM', 'GQ', 'JC', 'JD', 'KC', 'KF', 'KS', 'NB', 'PL', 'Q0', 'QH', 'SC', 'TC', 'TW', 'UE')
                         )
		        THEN 'Device'
            WHEN concept_class_id = 'HCPCS Modifier'
		            AND (
		                concept_code BETWEEN 'G1' AND 'G5'
                        OR concept_code IN
                           ('ED', 'EE', 'PT')
                         )
		        THEN 'Measurement'
            WHEN concept_class_id = 'HCPCS Modifier'
		            AND concept_code IN ('KM', 'KN')
		        THEN 'Procedure'
            WHEN concept_class_id = 'HCPCS Modifier'
		        THEN 'Observation'
		    -- A codes
		    WHEN concept_code BETWEEN 'A0420' AND 'A0436'
		        OR concept_code IN (
		            'A0170',
		            'A0380',
		            'A0390',
		            'A0888',
					'A9160',
					'A9170'
					)
		        THEN 'Observation'
			WHEN concept_code IN (
			        'A4248',
		            'A4260',
		            'A4800',
		            'A4801',
		            'A4802',
			        'A9153',
		            'A9513',
		            'A9517',
		            'A9527',
		            'A9530',
		            'A9534',
		            'A9535',
		            'A9543',
		            'A9545',
		            'A9563',
                    'A9574',
                    'A9564',
                    'A9590',
                    'A9600',
                    'A9604',
                    'A9605',
                    'A9606',
                    'A9607'
			                     )
				THEN 'Drug'
		    WHEN concept_code IN (
					'A4736',
					'A4737',
					'A9152',
					'A9180'
					)
				THEN 'Procedure'
		    WHEN concept_code LIKE 'A%'
		        THEN 'Device'
			-- B codes
			WHEN (concept_code LIKE 'B%'
			        AND concept_class_id = 'HCPCS')
				THEN 'Device'
					-- C codes
			WHEN concept_code IN (
					'C1360',
					'C1450'
					)
				THEN 'Procedure'
			WHEN concept_code IN (
					'C1024',
			        'C1084',
			        'C1086',
			        'C1166',
			        'C1167',
			        'C1178',
			        'C1203',
			        'C1207',
			        'C1774'
					)
				THEN 'Drug'
		    WHEN concept_code LIKE 'C1%'
		        OR concept_code LIKE 'C2%'
		        OR concept_code LIKE 'C3%'
		        OR concept_code LIKE 'C4%'
				THEN 'Device'
            WHEN concept_code BETWEEN 'C5271' AND 'C5278'
		        THEN 'Procedure'
			WHEN concept_code LIKE 'C5%'
			    OR concept_code LIKE 'C6%'
			    THEN 'Device'
			WHEN concept_code BETWEEN 'C7500' AND 'C7571'
			    THEN 'Procedure'
			WHEN concept_code LIKE 'C79%'
			    THEN 'Observation'
			WHEN concept_code BETWEEN 'C8001' AND 'C8014'
			    OR concept_code BETWEEN 'C8900' AND 'C8955'
			    OR concept_code IN ('C8957')
			    THEN 'Procedure'
			WHEN concept_code LIKE 'C8%'
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
                    'C9461',
                    'C9610',
                    'C9898',
                    'C9899'
                    )
                    OR concept_code BETWEEN 'C9349' AND 'C9407'
                     AND concept_code != 'C9399'
                    OR concept_code BETWEEN 'C9500' AND 'C9507'
                    OR concept_code BETWEEN 'C9701' AND 'C9703'
                    OR concept_code BETWEEN 'C9705' AND 'C9711'
                    OR concept_code BETWEEN 'C9804' AND 'C9817'
                THEN 'Device'
            WHEN concept_code BETWEEN 'C9600' AND 'C9610'
                     OR concept_code BETWEEN 'C9712' AND 'C9817'
                     OR concept_code IN (
                        'C9700',
                        'C9704',
                        'C9901'
                        )
                 THEN 'Procedure'
		    WHEN concept_code LIKE 'C9%'
		        THEN 'Drug'
					-- D codes
			WHEN concept_code BETWEEN 'D0120' AND 'D0191'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'D0210' AND 'D0350'
				THEN 'Device'
			WHEN concept_code BETWEEN 'D0360' AND 'D0415'
				    OR concept_code = 'D0417'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'D0416' AND 'D0460'
				THEN 'Measurement'
			WHEN concept_code = 'D0501'
				THEN 'Measurement'
			WHEN concept_code BETWEEN 'D0470' AND 'D1208'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'D1310' AND 'D1330'
				THEN 'Observation'
			WHEN concept_code = 'D1352'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'D1351' AND 'D2970'
				THEN 'Device'
			WHEN concept_code IN (
					'D1352',
					'D1555'
					)
				THEN 'Procedure'
			WHEN concept_code IN (
					'D5860',
					'D5861'
			        )
				OR concept_code BETWEEN 'D5911' AND 'D5999'
			    THEN 'Device'
			WHEN concept_code BETWEEN 'D6053' AND 'D6985'
				THEN 'Device'
			WHEN concept_code BETWEEN 'D2971' AND 'D9248'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'D9610' AND 'D9630'
				THEN 'Drug'
			WHEN concept_code BETWEEN 'D9910' AND 'D9999'
				THEN 'Procedure'
					-- E codes

			WHEN (concept_code LIKE 'E%')
				THEN 'Device' -- all of them Level 1: E0100-E9999
					-- G codes
			WHEN concept_code IN ('G0002', 'G0025')
				THEN 'Device'
		    WHEN concept_code BETWEEN 'G0008' AND 'G0010'
		        OR concept_code IN (
		            'G0138',
		            'G0377',
		            'G0533'
		            )
		        THEN 'Drug'
		    WHEN concept_code IN (
		            'G0006',
		            'G0128',
		            'G0129',
		            'G0146',
		            'G0337',
		            'G0454'
		            )
		        THEN 'Observation'
		    WHEN concept_code IN (
		            'G0107',
		            'G0026',
		            'G0027',
		            'G0183',
		            'G0298',
		            'G0306',
		            'G0307',
		            'G0328',
		            'G0394',
		            'G0450',
		            'G0461',
		            'G0462',
		            'G0464',
		            'G0472',
		            'G0499',
		            'G0567',
		            'G0659'
		                         )
		        OR concept_code BETWEEN 'G0101' AND 'G0106'
		        OR concept_code BETWEEN 'G0117' AND 'G0124'
		        OR concept_code BETWEEN 'G0141' AND 'G0148'
		        OR concept_code BETWEEN 'G0430' AND 'G0435'
		        OR concept_code BETWEEN 'G0475' AND 'G0483'
                THEN 'Measurement'
		    WHEN concept_code BETWEEN 'G0001' AND 'G0018'
		        OR concept_code BETWEEN 'G0030' AND 'G0047'
		        OR concept_code BETWEEN 'G0125' AND 'G0137'
		        OR concept_code BETWEEN 'G0165' AND 'G0174'
		        OR concept_code BETWEEN 'G0184' AND 'G0239'
		        OR concept_code BETWEEN 'G0251' AND 'G0295'
		        OR concept_code BETWEEN 'G0336' AND 'G0367'
		        OR concept_code BETWEEN 'G0396' AND 'G0405'
		        OR concept_code BETWEEN 'G0410' AND 'G0424'
		        OR concept_code BETWEEN 'G0440' AND 'G0449'
		        OR concept_code BETWEEN 'G0452' AND 'G0460'
		        OR concept_code BETWEEN 'G0501' AND 'G0506'
		        OR concept_code BETWEEN 'G0515' AND 'G0571'
		        OR concept_code BETWEEN 'G0680' AND 'G0685'
		        OR concept_code IN (
		            'G0178',
		            'G0242',
		            'G0243',
		            'G0247',
		            'G0297',
		            'G0329',
		            'G0389',
		            'G0392',
		            'G0393',
		            'G0428',
		            'G0429',
		            'G0453',
		            'G0465',
		            'G0471',
		            'G0473',
		            'G0491',
		            'G0492',
		            'G0500',
		            'G0571',
		            'G0498'
		                    )
		        THEN 'Procedure'
			WHEN concept_code LIKE 'G0%'
				THEN 'Observation'
		    WHEN concept_code LIKE 'G1%'
		        THEN 'Observation'
		    WHEN concept_code IN (
                    'G2000',
                    'G2023',
                    'G2024',
		            'G2102',
                    'G2170',
                    'G2171',
                    'G2250'
		            )
		        OR concept_code BETWEEN 'G2010' AND 'G2011'
		        OR concept_code BETWEEN 'G2023' AND 'G2024'
		        OR concept_code BETWEEN 'G2067' AND 'G2075'
		        THEN 'Procedure'
		    WHEN concept_code LIKE 'C2%'
		        THEN 'Observation'
			WHEN concept_code = 'G3001'
				THEN 'Drug'
			WHEN concept_code LIKE 'G3%'
				THEN 'Procedure'
		    WHEN concept_code BETWEEN 'G0499' AND 'G0570'
		        THEN 'Procedure'
			WHEN concept_code LIKE 'G4%'
				THEN 'Observation'
			WHEN concept_code BETWEEN 'G6001' AND 'G6028'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'G6030' AND 'G6058'
				THEN 'Measurement'
			WHEN concept_code LIKE 'G8%'
				THEN 'Observation'
		    WHEN concept_code BETWEEN 'G9639' AND 'G9641'
		        OR concept_code IN (
		            'G9016',
		            'G9147',
		            'G9156',
		            'G9157',
		            'G9654',
		            'G9756',
		            'G9757',
		            'G9770',
		            'G9839',
		            'G9937'
		            )
		        THEN 'Procedure'
		    WHEN concept_code BETWEEN 'G9017' AND 'G9020'
		            OR concept_code BETWEEN 'G9033' AND 'G9036'
		            OR concept_code BETWEEN 'G9141' AND 'G9142'
		        THEN 'Drug'
		    WHEN concept_code = 'G9143'
		        THEN 'Measurement'
	        WHEN concept_code LIKE 'G9%'
		        THEN 'Observation'
					-- H codes
			WHEN concept_code IN ('H0003', 'H0049')
				THEN 'Measurement'
			WHEN concept_code BETWEEN 'H0001' AND 'H0020'
			        OR concept_code BETWEEN 'H0021' AND 'H0032'
			        OR concept_code IN ('H0033', 'H0048')
				THEN 'Procedure'
			WHEN concept_code LIKE 'H%'
				THEN 'Observation'
					-- J codes
		    WHEN concept_code BETWEEN 'J7303' AND 'J7304'
		            OR (concept_code BETWEEN 'J7341' AND 'J7350'
		            AND concept_code NOT IN ('J7342', 'J7345'))
		        THEN 'Device'
		    WHEN concept_code LIKE 'J%'
		            AND length(concept_code)>2
		        THEN 'Drug'
					-- K codes
		    WHEN concept_code BETWEEN 'K0140' AND 'K0146'
		        OR concept_code BETWEEN 'K0166' AND 'K0167'
		        OR concept_code BETWEEN 'K0503' AND 'K0528'
		        OR concept_code IN (
		                            'K0124',
		                            'K0412',
		                            'K0418',
		                            'K0453'
		                           )
		        THEN 'Drug'
            WHEN concept_code IN ('K0285', 'K0449', 'K1034')
		        THEN 'Observation'
			WHEN concept_code = 'K0124'
				THEN 'Procedure'
			WHEN concept_code LIKE 'K%'
				THEN 'Device'
					-- L codes
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
		    WHEN (concept_code LIKE 'L%')
		        THEN 'Device'
			-- M codes
			WHEN concept_code IN (
					'M0075',
					'M0076',
					'M0100',
					'M0300',
					'M0301',
                    'M0302',
					'M0235',
			        'M0236'
			        )
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'M0220' AND 'M0250'
			        OR concept_code = 'M0201'
				THEN 'Drug'
		    WHEN concept_code LIKE 'M%'
		        THEN 'Observation'
					-- P codes
			WHEN concept_code BETWEEN 'P2028' AND 'P2038'
			        OR concept_code BETWEEN 'P3000' AND 'P3001'
			        OR concept_code IN ('P7001', 'P9100')
				THEN 'Measurement'
			WHEN concept_code BETWEEN 'P9041' AND 'P9042'
			        OR concept_code BETWEEN 'P9045' AND 'P9048'
				THEN 'Drug'
            WHEN concept_code IN ('P9603', 'P9604')
		        THEN 'Observation'
			WHEN concept_code BETWEEN 'P9612' AND 'P9615'
			        OR concept_class_id = 'HCPCS Class'
			        OR concept_code IN ('P9100')
				THEN 'Procedure'
		    WHEN concept_code LIKE 'P%'
		        THEN 'Device'
			-- Q codes
			WHEN concept_code IN (
			    'Q0035',
			    'Q0091',
			    'Q0188',
			    'Q0235',
			    'Q4078',
			    'Q4082',
			    'Q9987'
			        )
			        OR concept_code BETWEEN 'Q0081' AND 'Q0085'
				THEN 'Procedure'
			WHEN concept_code IN (
					'Q0061',
			        'Q3031'
					)
			        OR concept_code BETWEEN 'Q0111' AND 'Q0115'
				THEN 'Measurement'
			WHEN concept_code BETWEEN 'Q0477' AND 'Q0509'
			        OR concept_code BETWEEN 'Q1001' AND 'Q1005'
			        OR concept_code BETWEEN 'Q0182' AND 'Q0185'
			        OR concept_code BETWEEN 'Q9945' AND 'Q9969'
			        OR concept_code BETWEEN 'Q9982' AND 'Q9983'
			        OR concept_code in (
			        'Q3001',
			        'Q9988',
			        'Q9994'
			        )
				THEN 'Device'
		    WHEN concept_code BETWEEN 'Q0510' AND 'Q0521'
		            AND concept_code != 'Q0515'
		             OR concept_code BETWEEN 'Q3000' AND 'Q3012'
		             OR concept_code BETWEEN 'Q3014' AND 'Q3020'
		             OR concept_code BETWEEN 'Q5001' AND 'Q5010'
		             OR concept_code BETWEEN 'Q9001' AND 'Q9004'
		            OR concept_code in (
		                'Q0086',
		                'Q0092',
		                'Q0186',
		                'Q2052',
		                'Q4078'
		                 )
		        THEN 'Observation'
		    WHEN (concept_code LIKE 'Q0%'
                    OR concept_code LIKE 'Q2%'
                    OR concept_code LIKE 'Q3%'
                    OR concept_code BETWEEN 'Q4052' AND 'Q4099'
                    OR concept_code LIKE 'Q5%'
                    OR concept_code LIKE 'Q9%')
		        THEN 'Drug'
		    WHEN concept_code LIKE 'Q4%'
		        THEN 'Device'
					-- R codes
			WHEN concept_code LIKE 'R%'
				THEN 'Observation'
					-- S codes
			WHEN concept_code BETWEEN 'S0201' AND 'S0342'
			         OR concept_code BETWEEN 'S4030' AND 'S4031'
			         OR concept_code BETWEEN 'S5016' AND 'S5021'
			         OR concept_code BETWEEN 'S5025' AND 'S5036'
			         OR concept_code BETWEEN 'S5100' AND 'S5199'
			         OR concept_code BETWEEN 'S9097' AND 'S9098'
			         OR concept_code BETWEEN 'S9200' AND 'S9214'
			         OR concept_code BETWEEN 'S9381' AND 'S9430'
			         OR concept_code BETWEEN 'S9436'AND 'S9473'
					 OR concept_code BETWEEN 'S9476' AND 'S9485'
			         OR concept_code IN (
			            'S0400',
			            'S3600',
			            'S9083',
			            'S9088',
			            'S9127'
			            )
				THEN 'Observation'
			WHEN concept_code BETWEEN 'S0345' AND 'S0347'
				    OR concept_code BETWEEN 'S0390' AND 'S0395'
				    OR concept_code BETWEEN 'S0601' AND 'S0820'
				    OR concept_code BETWEEN 'S2050' AND 'S3000'
				    OR concept_code BETWEEN 'S3005' AND 'S3601'
				    OR concept_code BETWEEN 'S3900' AND 'S3906'
				    OR (concept_code BETWEEN 'S4005' AND 'S4042'
			         AND concept_code != 'S4024')
				    OR concept_code BETWEEN 'S5180' AND 'S5181'
				    OR concept_code BETWEEN 'S5497' AND 'S5523'
				    OR concept_code BETWEEN 'S5550' AND 'S5553'
				    OR concept_code BETWEEN 'S8001' AND 'S8093'
				    OR concept_code BETWEEN 'S8930' AND 'S8990'
				    OR concept_code BETWEEN 'S9015' AND 'S9075'
				    OR concept_code BETWEEN 'S9090' AND 'S9110'
				    OR concept_code BETWEEN 'S9123' AND 'S9129'
				    OR (concept_code BETWEEN 'S9325' AND 'S9379'
				    AND concept_name LIKE 'Home%therapy%')
			        OR concept_code BETWEEN 'S9490' AND 'S9810'
			        OR concept_code IN (
			            'S0592',
			            'S5000',
			            'S5001',
			            'S5022',
			            'S9085',
			            'S9085',
			            'S9145'
			            )
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'S0500' AND 'S0596'
				    OR concept_code BETWEEN 'S1001' AND 'S1040'
				    OR concept_code BETWEEN 'S4988' AND 'S4989'
				    OR concept_code BETWEEN 'S5560' AND 'S5571'
				    OR (concept_code BETWEEN 'S8095' AND 'S8490'
				            AND concept_code != 'S8110')
				    OR concept_code BETWEEN 'S8999' AND 'S9007'
				    OR concept_code BETWEEN 'S9432' AND 'S9435'
			        OR concept_code IN (
			            'S1091',
			            'S4024',
			            'S5002',
			            'S5003',
			            'S5002',
			            'S5003'
			        )
				THEN 'Device'
			WHEN concept_code BETWEEN 'S0009' AND 'S0198'
			        OR concept_code BETWEEN 'S4990' AND 'S4995'
			        OR concept_code BETWEEN 'S5010' AND 'S5014'
			        OR concept_code IN ('S1090', 'S4981')
				THEN 'Drug'
			WHEN concept_code IN ('S0830', 'S8110')
                    OR concept_code BETWEEN 'S3618' AND 'S3890'
                    OR concept_code BETWEEN 'S4980' AND 'S5014'
				THEN 'Measurement'
					-- T codes
			WHEN concept_code BETWEEN 'T1502' AND 'T1503'
			         OR concept_code BETWEEN 'T2A' AND 'T2C'
				THEN 'Procedure'
			WHEN concept_code BETWEEN 'T1A' AND 'T1H'
		        THEN 'Measurement'
			WHEN concept_code BETWEEN 'T1500' AND 'T1999'
                    OR concept_code BETWEEN 'T2028' AND 'T2029'
                    OR concept_code BETWEEN 'T4521' AND 'T4545'
                    OR concept_code BETWEEN 'T5001' AND 'T5999'
				THEN 'Device'
			WHEN concept_code LIKE 'T%'
				THEN 'Observation'
					-- U codes
			WHEN concept_code LIKE 'U%'
				THEN 'Measurement'
					-- V codes
			WHEN concept_code BETWEEN 'V2624' AND 'V2626'
			     OR concept_code BETWEEN 'V5011' AND 'V5020'
				 OR concept_code IN (
				    'V2628',
				    'V2785',
				    'V5010',
				    'V5336'
				    )
				THEN 'Procedure'
			WHEN concept_code = 'V5008'
			    OR concept_code BETWEEN 'V5362' AND 'V5364'
				THEN 'Measurement'
		    WHEN concept_code BETWEEN 'V2787' AND 'V2788'
		            OR concept_code IN (
		            'V2799',
		            'V5275',
		            'V5299'
		            )
		        THEN 'Observation'
			WHEN concept_code LIKE 'V%'
				THEN 'Device'
            ELSE COALESCE(hcpc.domain_id, 'Observation') -- use 'observation' in other cases
            END AS domain_id
    FROM concept_stage hcpc
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
AND c.standard_concept IS NULL
AND c.invalid_reason IS NULL;

-- At the end, the concept_stage, concept_relationship_stage and concept_synonym_stage tables are ready to be fed into the generic_update script