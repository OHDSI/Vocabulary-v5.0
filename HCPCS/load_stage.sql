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

--1. Update latest_update field to new date 
BEGIN
   DEVV5.VOCABULARY_PACK.SetLatestUpdate (pVocabularyName        => 'HCPCS',
                                          pVocabularyDate        => TO_DATE ('20151028', 'yyyymmdd'),
                                          pVocabularyVersion     => '2016 Alpha Numeric HCPCS File',
                                          pVocabularyDevSchema   => 'DEV_HCPCS');
END;
COMMIT;

-- 2. Truncate all working tables
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;

--3. Create concept_stage from HCPCS
INSERT /*+ APPEND */ INTO concept_stage (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT NULL AS concept_id,
       SUBSTR(CASE WHEN LENGTH(LONG_DESCRIPTION)>255 AND SHORT_DESCRIPTION IS NOT NULL THEN SHORT_DESCRIPTION ELSE LONG_DESCRIPTION END,1,255) AS concept_name,
       c.domain_id AS domain_id,
       v.vocabulary_id,
       CASE WHEN LENGTH (HCPC) = 2 THEN 'HCPCS Modifier' ELSE 'HCPCS' END
          AS concept_class_id,
       CASE WHEN TERM_DT IS NOT NULL THEN NULL ELSE 'S' END
          AS standard_concept,
       HCPC AS concept_code,
       COALESCE (ADD_DATE, ACT_EFF_DT) AS valid_start_date,
       COALESCE (TERM_DT, TO_DATE ('20991231', 'yyyymmdd')) AS valid_end_date,
       CASE
          WHEN TERM_DT IS NULL THEN NULL
          WHEN XREF1 IS NULL THEN 'D'                            -- deprecated
          ELSE 'U'                                                 -- upgraded
       END
          AS invalid_reason
  FROM ANWEB_V2 a
       JOIN vocabulary v ON v.vocabulary_id = 'HCPCS'
       LEFT JOIN concept c
          ON     c.concept_code = A.BETOS
             AND c.concept_class_id = 'HCPCS Class'
             AND C.VOCABULARY_ID = 'HCPCS';
COMMIT;					  

--4 Update domain_id in concept_stage
--4.1. Part 1
CREATE TABLE t_domains nologging AS
--create temporary table with domain_id defined by rules
    (
    SELECT 
      hcpc.concept_code,
      case 
        --review by name with exclusions
        when concept_code in ('A9152', 'A9153', 'A9180') then 'Observation' 
        when concept_code = 'A9155' then 'Drug' --Artificial saliva, 30 ml
        when hcpc.concept_code  in ('G0404', 'G0405', 'G0403') then 'Measurement' -- ECG
        when hcpc.concept_code = 'V5299' then 'Observation'
        when concept_code in ('A4221', 'A4305', 'A4306', 'A4595', 'B4216', 'B4220', 'B4222', 'B4224') then 'Device'
        when CONCEPT_NAME like '%per session%' then 'Procedure'
        when concept_code in ('A4736', 'A4737') then 'Procedure'
        when concept_code =  'G0177' then 'Procedure'
        when concept_code between 'S9490' and 'S9562' then 'Procedure' -- Home infusion therapy, exact group of drugs
        when concept_code in  ('G0177', 'G0424') then 'Procedure'
        when (CONCEPT_NAME like '%per diem%'  --time periods
        or CONCEPT_NAME like '%per month%' 
        or CONCEPT_NAME like '%per week%'
        or CONCEPT_NAME like '%per%minutes%'
        or cONCEPT_NAME like '%per hour%'
        or cONCEPT_NAME like '%waiver%'
        or cONCEPT_NAME like '%per%day%') then 'Observation'
         -- A codes
        when l3.str = 'Supplies for Radiologic Procedures' then 'Device' -- Level 3: A4641-A4642
        when l3.str = 'Supplies for Radiology Procedures (Radiopharmaceuticals)' then 'Device' -- Level 3: A9500-A9700
        when l2.str = 'Transport Services Including Ambulance' then 'Observation' -- Level 2: A0000-A0999
        when l1.str = 'A Codes' then 'Device' -- default for Level 1: A0000-A9999
        -- B codes
        when l1.str = 'Enteral and Parenteral Therapy Supplies' then 'Device' -- all of them Level 1: B4000-B9999
        -- C codes
        when concept_code = 'C1204' then 'Device' -- Technetium tc 99m tilmanocept, diagnostic, up to 0.5 millicuries
        when concept_code like 'C%' and concept_name like '%Brachytherapy%source%' then 'Device' -- Brachytherapy codes
        when concept_code like 'C%' and concept_name like '%Magnetic resonance% with%' then 'Procedure' -- MRIs
        when concept_code like 'C%' and concept_name like '%Trans% echocardiography%' then 'Procedure' -- Echocardiography
        when concept_code between 'C9021' and 'C9349' then 'Drug' -- various drug products
        when concept_code between 'C9352' and 'C9369' then 'Device' -- various graft matrix material
        when concept_code = 'C9406' then 'Device' -- Iodine i-123 ioflupane, diagnostic, per study dose, up to 5 millicuries
        when concept_code = 'C9399' then 'Procedure'
        when concept_code between 'C9406' and 'C9497' then 'Drug' 
        when concept_code between 'C9600' and 'C9800' then 'Procedure'
        when l1.str = 'C Codes - CMS Hospital Outpatient System' then 'Device' -- default for Level 1: C1000-C9999
        -- E codes
        when l1.str = 'E-codes' then 'Device' -- all of them Level 1: E0100-E9999
        -- G codes
        when concept_code in  ('G0101' ,'G0102') then 'Procedure'
        when concept_code in  'G0177' then 'Procedure'
        when l2.str = 'Vaccine Administration' then 'Procedure' -- Level 2: G0008-G0010
        when l2.str = 'Semen Analysis' then 'Measurement' -- Level 2: G0027-G0027
        when l2.str = 'Screening Services - Cervical' then 'Observation' -- Level 2: G0101-G0101
        when concept_code = 'G0102' then 'Observation' -- Prostate cancer screening; digital rectal examination
        when concept_code = 'G0103' then 'Measurement' -- Prostate cancer screening; prostate specific antigen test (psa)
        when l2.str = 'Training Services - Diabetes' then 'Observation' -- Level 2: G0108-G0109
        when l2.str = 'Screening Services - Cytopathology' then 'Measurement' -- Level 2: G0123-G0124
        when l2.str = 'Service, Nurse and OT' then 'Observation' -- Level 2: G0128-G0129
        when l2.str = 'Screening Services - Cytopathology, Other' then 'Measurement' -- Level 2: G0141-G0148
        when l2.str = 'Services, Allied Health' then 'Observation' -- Level 2: G0151-G0166
        when l2.str = 'Team Conference' then 'Observation' -- Level 2: G0175-G0175
        when concept_code = 'G0177' then 'Observation' -- Training and educational services related to the care and treatment of patient's disabling mental health problems per session (45 minutes or more)
        when l2.str = 'Physician Services' then 'Observation' -- Level 2: G0179-G0182
        when l2.str = 'Physician Services, Diabetic' then 'Observation' -- Level 2: G0245-G0246
        when l2.str = 'Demonstration, INR' then 'Observation' -- Level 2: G0248-G0250
        when l2.str = 'Services, Pulmonary Surgery' then 'Observation' -- Level 2: G0302-G0305
        when l2.str = 'Laboratory' then 'Measurement' -- Level 2: G0306-G0328
        when l2.str = 'Fee, Pharmacy' then 'Procedure' -- Level 2: G0333-G0333
        when l2.str = 'Hospice' then 'Observation' -- Level 2: G0337-G0337
        when l2.str = 'Services, Observation and ED' then 'Observation' -- Level 2: G0378-G0384
        when l2.str = 'Team, Trauma Response' then 'Observation' -- Level 2: G0390-G0390
        when l2.str = 'Home Sleep Study Test' then 'Procedure' --G0398-G0400  
        when l2.str = 'Examination, Initial Medicare' then 'Observation' -- Level 2: G0402-G0402
        when l2.str = 'Electrocardiogram' then 'Procedure' -- Level 2: G0403-G0405 -- changed to procedure because there could be various results
        when l2.str = 'Telehealth' then 'Observation' -- Level 2: G0406-G0408
        when l2.str = 'Services, Social, Psychological' then 'Observation' -- Level 2: G0409-G0411
        when l2.str = 'Pathology, Surgical' then 'Procedure' -- Level 2: G0416-G0419
        when concept_code in ('G0428', 'G0429') then 'Procedure'
        when concept_code in ('G0431', 'G0432', 'G0433', 'G0434', 'G0435') then 'Measurement' -- drug screen, infectious antibodies
        when concept_code in ('G0438', 'G0439') then 'Observation' -- annual wellness visit
        when concept_code in ('G0440', 'G0441') then 'Procedure' -- allogenic skin substitute
        when concept_code in ('G0442', 'G0443', 'G0444', 'G0445', 'G0446', 'G0447') then 'Procedure' -- Various screens and counseling
        when concept_code = 'G0448' then 'Procedure' -- Insertion or replacement of a permanent pacing cardioverter-defibrillator system with transvenous lead(s), single or dual chamber with insertion of pacing electrode, cardiac venous system, for left ventricular pacing
        when concept_code = 'G0451' then 'Observation' -- Development testing, with interpretation and report, per standardized instrument form
        when concept_code = 'G0452' then 'Measurement' -- Molecular pathology procedure; physician interpretation and report
        when concept_code = 'G0453' then 'Procedure' -- Continuous intraoperative neurophysiology monitoring, from outside the operating room (remote or nearby), per patient, (attention directed exclusively to one patient) each 15 minutes (list in addition to primary procedure)
        when concept_code = 'G0454' then 'Observation' -- Physician documentation of face-to-face visit for durable medical equipment determination performed by nurse practitioner, physician assistant or clinical nurse specialist
        when concept_code = 'G0455' then 'Procedure' -- Preparation with instillation of fecal microbiota by any method, including assessment of donor specimen
        when concept_code in ('G0456', 'G0457') then 'Procedure' -- Negative pressure wound therapies
        when concept_code = 'G0458' then 'Procedure' -- Low dose rate (ldr) prostate brachytherapy services, composite rate
        when concept_code = 'G0459' then 'Procedure' -- Inpatient telehealth pharmacologic management, including prescription, use, and review of medication with no more than minimal medical psychotherapy
        when concept_code = 'G0460' then 'Procedure' -- Autologous platelet rich plasma for chronic wounds/ulcers, incuding phlebotomy, centrifugation, and all other preparatory procedures, administration and dressings, per treatment
        when concept_code in ('G0461', 'G0462') then 'Measurement' --    Immunohistochemistry or immunocytochemistry
        when concept_code = 'G0463' then 'Observation' -- Hospital outpatient clinic visit for assessment and management of a patient
        when concept_code = 'G0464' then 'Measurement' -- Colorectal cancer screening; stool-based dna and fecal occult hemoglobin (e.g., kras, ndrg4 and bmp3)
        when concept_code in ('G0466', 'G0467', 'G0468', 'G0469', 'G0470') then 'Observation' -- Federally qualified health center (fqhc) visits
        when concept_code = 'G0471' then 'Procedure' -- Collection of venous blood by venipuncture or urine sample by catheterization from an individual in a skilled nursing facility (snf) or by a laboratory on behalf of a home health agency (hha)
        when concept_code = 'G0472' then 'Measurement' -- Hepatitis c antibody screening, for individual at high risk and other covered indication(s)
        when concept_code = 'G0473' then 'Procedure' -- Face-to-face behavioral counseling for obesity, group (2-10), 30 minutes
        when concept_code in ('G0908', 'G0909', 'G0910', 'G0911', 'G0912', 'G0913', 'G0914', 'G0915', 'G0916', 'G0917', 'G0918', 'G0919', 'G0920', 'G0921', 'G0922') then 'Observation' -- various documented levels and assessments
        when l2.str = 'Tositumomab' then 'Procedure' -- Level 2: G3001-G3001
        when concept_code in ('G6001', 'G6002', 'G6003', 'G6004', 'G6005', 'G6006', 'G6007', 'G6008', 'G6009', 'G6010', 'G6011', 'G6012', 'G6013', 'G6014', 'G6015', 'G6016', 'G6017') then 'Procedure' -- various radiation treatment deliveries
        when concept_code in ('G6018', 'G6019', 'G6020', 'G6021', 'G6022', 'G6023', 'G6024', 'G6025', 'G6027', 'G6028') then 'Procedure' -- various ileo/colono/anoscopies
        when concept_code between 'G6030' and 'G6058' then 'Measurement' -- drug screening
        when l2.str = 'Patient Documentation' then 'Observation' -- Level 2: G8126-G9140, mostly Physician Quality Reporting System (PQRS)
        when concept_code in ('G9141', 'G9142') then 'Drug' -- Influenza a (h1n1) immunization administration
        when concept_code = 'G9143' then 'Measurement' -- Warfarin responsiveness testing by genetic technique using any method, any number of specimen(s)
        when concept_code = 'G9147' then 'Procedure' -- Outpatient intravenous insulin treatment (oivit) either pulsatile or continuous, by any means, guided by the results of measurements for: respiratory quotient; and/or, urine urea nitrogen (uun); and/or, arterial, venous or capillary glucose; and/or potassi
        when concept_code in ('G9148', 'G9149', 'G9150') then 'Observation' -- National committee for quality assurance - medical home levels 
        when concept_code in ('G9151', 'G9152', 'G9153') then 'Observation' -- Multi-payer Advanced Primary Care Practice (MAPCP) Demonstration Project
        when concept_code = 'G9156' then 'Procedure' -- Evaluation for wheelchair requiring face to face visit with physician
        when concept_code = 'G9157' then 'Procedure' -- Transesophageal doppler measurement of cardiac output (including probe placement, image acquisition, and interpretation per course of treatment) for monitoring purposes
        when concept_code between 'G9158' and 'G9186' then 'Observation' -- various neurological functional limitations documentations
        when concept_code = 'G9187' then 'Observation' -- Bundled payments for care improvement initiative home visit for patient assessment performed by a qualified health care professional for individuals not considered homebound including, but not limited to, assessment of safety, falls, clinical status, fluid
        when concept_code between 'G9188' and 'G9472' then 'Observation' -- various documentations
        when concept_code between 'G9000' and 'G9999' then 'Procedure' -- default for Medicare Demonstration Project
        when l1.str = 'Temporary Procedures/Professional Services' then 'Procedure' -- default for all Level 1: G0000-G9999
        -- H codes
        when concept_code = 'H0003' then 'Measurement' -- Alcohol and/or drug screening; laboratory analysis of specimens for presence of alcohol and/or drugs
        when concept_code = 'H0030' then 'Observation' -- Behavioral health hotline service
        when concept_code = 'H0033' then 'Procedure' -- Oral medication administration, direct observation
        when concept_code in ('H0048', 'H0049') then 'Measurement' -- Alcohol screening
        when concept_code between 'H0034' and 'H2037' then 'Observation' -- various services
        when l1.str = 'Behavioral Health and/or Substance Abuse Treatment Services' then 'Procedure' -- default for all Level 1: H0001-H9999
        -- J codes
        when l1.str = 'J Codes - Drugs' then 'Drug' -- Level 1: J0100-J9999
        -- K codes
        when l1.str = 'Temporary Codes Assigned to Durable Medical Equipment Regional Carriers' then 'Device' -- Level 1: K0000-K9999
        -- L codes 
        when l1.str = 'L Codes' then 'Device' -- Level 1: L0000-L9999
        -- M codes
        when concept_code = 'M0064' then 'Observation' -- Brief office visit for the sole purpose of monitoring or changing drug prescriptions used in the treatment of mental psychoneurotic and personality disorders
        when l1.str = 'Other Medical Services' then 'Procedure' -- Level 1: M0000-M0301
        -- P codes -- 
        when l2.str = 'Chemistry and Toxicology Tests' then 'Measurement' -- Level 2: P2028-P2038
        when l2.str = 'Pathology Screening Tests' then 'Measurement' -- Level 2: P3000-P3001
        when l2.str = 'Microbiology Tests' then 'Measurement' -- Level 2: P7001-P7001
        when concept_code between 'P9041' and 'P9048' then 'Procedure Drug'
        when l2.str = 'Miscellaneous Pathology and Laboratory Services' then 'Procedure' -- Level 2: P9010-P9615
        -- Q codes
        when l2.str = 'Cardiokymography (CMS Temporary Codes)' then 'Procedure' -- Level 2: Q0035-Q0035
        when l2.str = 'Chemotherapy (CMS Temporary Codes)' then 'Procedure' -- Level 2: Q0081-Q0085
        when concept_code = 'Q0090' then 'Device' -- Levonorgestrel-releasing intrauterine contraceptive system, (skyla), 13.5 mg
        when l2.str = 'Smear, Papanicolaou (CMS Temporary Codes)' then 'Procedure' -- Level 2: Q0091-Q0091, only getting the smear, no interpretation
        when l2.str = 'Equipment, X-Ray, Portable (CMS Temporary Codes)' then 'Observation' -- Level 2: Q0092-Q0092, only setup
        when l2.str = 'Laboratory (CMS Temporary Codes)' then 'Measurement' -- Level 2: Q0111-Q0115
        when l2.str = 'Drugs (CMS Temporary Codes)' then 'Drug' -- Level 2: Q0138-Q0181
        when l2.str = 'Miscellaneous Devices (CMS Temporary Codes)' then 'Device' -- Level 2: Q0478-Q0509
        when l2.str = 'Fee, Pharmacy (CMS Temporary Codes)' then 'Observation' -- Level 2: Q0510-Q0515  -why u decide that this is procedure drug?
        when l2.str = 'Lens, Intraocular (CMS Temporary Codes)' then 'Device' -- Level 2: Q1003-Q1005
        when l2.str = 'Solutions and Drugs (CMS Temporary Codes)' then 'Procedure Drug' -- Level 2: Q2004-Q2052
        when l2.str = 'Brachytherapy Radioelements (CMS Temporary Codes)' then 'Device' -- Level 2: Q3001-Q3001
        when l2.str = 'Telehealth (CMS Temporary Codes)' then 'Observation' -- Level 2: Q3014-Q3014
        when concept_code in ('Q3025', 'Q3026') then 'Procedure Drug' -- Injection, Interferon beta
        when l2.str = 'Additional Drugs (CMS Temporary Codes)' then 'Procedure Drug' -- Level 2: Q3027-Q3028
        when l2.str = 'Test, Skin (CMS Temporary Codes)' then 'Measurement' -- Level 2: Q3031-Q3031
        when l2.str = 'Supplies, Cast (CMS Temporary Codes)' then 'Device' -- Level 2: Q4001-Q4051
        when l2.str = 'Additional Drug Codes (CMS Temporary Codes)' then 'Procedure Drug' -- Level 2: Q4074-Q4082
        -- S codes
        when concept_code between 'S0012' and 'S0197' then 'Procedure Drug'
        when concept_code between 'S0257' and 'S0265' then 'Procedure'
        when concept_code between 'S0201' and 'S0354' then 'Observation' -- includes the previous
        when concept_code between 'S0390' and 'S0400' then 'Procedure'
        when concept_code = 'S0592' then 'Procedure' -- Comprehensive contact lens evaluation
        when concept_code between 'S0500' and 'S0596' then 'Device' -- lenses, includes the previous
        when concept_code between 'S0601' and 'S0812' then 'Procedure'
        when concept_code between 'S1001' and 'S1040' then 'Device'
        when concept_code = 'S1090' then 'Device' -- Mometasone furoate sinus implant, 370 micrograms
        when concept_code between 'S2053' and 'S3000' then 'Procedure'
        when concept_code in ('S3000', 'S3005') then 'Observation' -- Stat lab
        when concept_code in ('S3600', 'S3601') then 'Observation'-- stat lab
        when concept_code between 'S3600' and 'S3890' then 'Measurement' -- various genetic tests and prenatal screenings
        when concept_code between 'S3900' and 'S3904' then 'Procedure' -- EKG and EMG
        when concept_code between 'S3905' and 'S4042' then 'Procedure' -- IVF procedures
        when concept_code between 'S4981' and 'S5014' then 'Procedure Drug' -- various

        when concept_code between 'S5035' and 'S5036' then 'Observation'
        when concept_code between 'S5100' and 'S5199' then 'Observation' -- various care services
        when concept_code between 'S5497' and 'S5523' then 'Observation' -- Home infusion therapy
        when concept_code between 'S5550' and 'S5553' then 'Procedure Drug' -- various Insulin forms
        when concept_code between 'S5560' and 'S5571' then 'Device' -- various Insulin delivery devices
        when concept_code = 'S8030' then 'Procedure' --Scleral application of tantalum ring(s) for localization of lesions for proton beam therapy
        when concept_code between 'S8032' and 'S8092' then 'Procedure' -- various imaging
        when concept_code = 'S8110' then 'Measurement' -- Peak expiratory flow rate (physician services)
        when concept_code between 'S8096' and 'S8490' then 'Device'
        when concept_code between 'S8930' and 'S8990' then 'Procedure'
        when concept_code between 'S8999' and 'S9007' then 'Device'
        when concept_code between 'S9015' and 'S9075' then 'Procedure'
        when concept_code between 'S9083' and 'S9088' then 'Observation'
        when concept_code between 'S9090' and 'S9110' then 'Procedure'
        when concept_code between 'S9117' and 'S9141' then 'Observation' -- various services and visits
        when concept_code = 'S9145' then 'Procedure' -- Insulin pump initiation, instruction in initial use of pump (pump not included)
        when concept_code between 'S9150' and 'S9214' then 'Observation' -- Home management
        when concept_code between 'S9325' and 'S9379' then 'Observation' -- home infusions and home therapy without exact drugs, per diem
        when concept_code between 'S9381' and 'S9433' then 'Observation'
        when concept_code between 'S9434' and 'S9435' then 'Device'
          -- T codes
          when concept_code = 'T1006' then 'Procedure' -- Alcohol and/or substance abuse services, family/couple counseling
                WHEN hcpc.concept_code IN ('T1502', 'T1503') THEN 'Procedure Drug' -- Administration of medication
                WHEN hcpc.concept_code BETWEEN 'T1505' AND 'T1999' THEN 'Device' -- 
                WHEN hcpc.concept_code IN ('T2028', 'T2029') THEN 'Device'
                WHEN hcpc.concept_code BETWEEN 'T4521' AND 'T5999' THEN 'Device'
                WHEN l1.str = 'Temporary National Codes Established by Private Payers' THEN 'Observation' -- default for Level 1: S0000-S9999 AND Level 1: T1000-T9999
                -- V codes
                WHEN hcpc.concept_code = 'V2785' THEN 'Procedure' -- Processing, preserving AND transporting corneal tissue
                WHEN hcpc.concept_code BETWEEN 'V2624' AND 'V2626' THEN 'Procedure' -- working on ocular prosthesis
                WHEN hcpc.concept_code IN ('V5008', 'V5010') THEN 'Procedure' -- Hearing screening AND assessment of hearing aide
                WHEN hcpc.concept_code IN ('V5011', 'V5014') THEN 'Procedure' -- fitting of hearing aide
                WHEN hcpc.concept_code = 'V5020' THEN 'Observation' -- Conformity evaluation
                WHEN hcpc.concept_code = 'V5275' THEN 'Observation' -- Ear impression, each
                WHEN hcpc.concept_code BETWEEN 'V5299' AND 'V5364' THEN 'Procedure' -- various screening
                WHEN l1.str = 'V Codes' THEN 'Device' -- default for Level 1: V0000-V5999 Vision AND hearing services

        else 'Observation' -- use 'observation' in other cases
         end AS domain_id
    FROM concept_stage hcpc
    LEFT JOIN (
      SELECT 
        code,
        regexp_substr(code, '[A-Z]\d{4}', 10) AS lo,
        regexp_substr(code, '[A-Z]\d{4}', 16) AS hi,
        str
      FROM umls.mrconso where sab='MTHHH' AND instr(code, 'Level 1') != 0
    ) l1 ON hcpc.concept_code BETWEEN l1.lo AND l1.hi
    LEFT JOIN (
      SELECT 
        code,
        regexp_substr(code, '[A-Z]\d{4}', 10) AS lo,
        regexp_substr(code, '[A-Z]\d{4}', 16) AS hi,
        str
      FROM umls.mrconso where sab='MTHHH' AND instr(code, 'Level 2') != 0
    ) l2 ON hcpc.concept_code BETWEEN l2.lo AND l2.hi
    LEFT JOIN (
      SELECT 
        code,
        regexp_substr(code, '[A-Z]\d{4}', 10) AS lo,
        regexp_substr(code, '[A-Z]\d{4}', 16) AS hi,
        str
      FROM umls.mrconso where sab='MTHHH' AND instr(code, 'Level 3') != 0
    ) l3 ON hcpc.concept_code BETWEEN l3.lo AND l3.hi
    WHERE LENGTH(concept_code)>2
);

CREATE INDEX tmp_idx_cs
   ON t_domains (concept_code)
   NOLOGGING;

--update concept_stage from temporary table   
UPDATE concept_stage c
   SET domain_id =
          (SELECT t.domain_id
             FROM t_domains t
            WHERE c.concept_code = t.concept_code);
COMMIT;

--4.2. Part 2 (for HCPCS Modifiers)
begin
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='A1'; --Dressing for one wound
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='A2'; --Dressing for two wounds
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='A3'; --Dressing for three wounds
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='A4'; --Dressing for four wounds
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='A5'; --Dressing for five wounds
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='A6'; --Dressing for six wounds
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='A7'; --Dressing for seven wounds
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='A8'; --Dressing for eight wounds
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='A9'; --Dressing for nine or more wounds
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AA'; --Anesthesia services performed personally by anesthesiologist
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AD'; --Medical supervision by a physician: more than four concurrent anesthesia procedures
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AE'; --Registered dietician
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AF'; --Specialty physician
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AG'; --Primary physician
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AH'; --Clinical psychologist
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AI'; --Principal physician of record
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AJ'; --Clinical social worker
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AK'; --Non participating physician
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AM'; --Physician, team member service
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AO'; --Alternate payment method declined by provider of service
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AP'; --Determination of refractive state was not performed in the course of diagnostic ophthalmological examination
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AQ'; --Physician providing a service in an unlisted health professional shortage area (hpsa)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AR'; --Physician provider services in a physician scarcity area
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AS'; --Physician assistant, nurse practitioner, or clinical nurse specialist services for assistant at surgery
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AT'; --Acute treatment (this modifier should be used when reporting service 98940, 98941, 98942)
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AU'; --Item furnished in conjunction with a urological, ostomy, or tracheostomy supply
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AV'; --Item furnished in conjunction with a prosthetic device, prosthetic or orthotic
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AW'; --Item furnished in conjunction with a surgical dressing
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AX'; --Item furnished in conjunction with dialysis services
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AY'; --Item or service furnished to an esrd patient that is not for the treatment of esrd
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='AZ'; --Physician providing a service in a dental health professional shortage area for the purpose of an electronic health record incentive payment
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='BA'; --Item furnished in conjunction with parenteral enteral nutrition (pen) services
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='BL'; --Special acquisition of blood and blood products
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='BO'; --Orally administered nutrition, not by feeding tube
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='BP'; --The beneficiary has been informed of the purchase and rental options and has elected to purchase the item
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='BR'; --The beneficiary has been informed of the purchase and rental options and has elected to rent the item
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='BU'; --The beneficiary has been informed of the purchase and rental options and after 30 days has not informed the supplier of his/her decision
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CA'; --Procedure payable only in the inpatient setting when performed emergently on an outpatient who expires prior to admission
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CB'; --Service ordered by a renal dialysis facility (rdf) physician as part of the esrd beneficiary's dialysis benefit, is not part of the composite rate, and is separately reimbursable
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CC'; --Procedure code change (use 'cc' when the procedure code submitted was changed either for administrative reasons or because an incorrect code was filed)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CD'; --Amcc test has been ordered by an esrd facility or mcp physician that is part of the composite rate and is not separately billable
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CE'; --Amcc test has been ordered by an esrd facility or mcp physician that is a composite rate test but is beyond the normal frequency covered under the rate and is separately reimbursable based on medical necessity
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CF'; --Amcc test has been ordered by an esrd facility or mcp physician that is not part of the composite rate and is separately billable
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CG'; --Policy criteria applied
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CH'; --0 percent impaired, limited or restricted
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CI'; --At least 1 percent but less than 20 percent impaired, limited or restricted
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CJ'; --At least 20 percent but less than 40 percent impaired, limited or restricted
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CK'; --At least 40 percent but less than 60 percent impaired, limited or restricted
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CL'; --At least 60 percent but less than 80 percent impaired, limited or restricted
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CM'; --At least 80 percent but less than 100 percent impaired, limited or restricted
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CN'; --100 percent impaired, limited or restricted
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CP'; --Adjunctive service related to a procedure assigned to a comprehensive ambulatory payment classification (c-apc) procedure, but reported on a different claim
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CR'; --Catastrophe/disaster related
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CS'; --Gulf oil 2010 spill related
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='CT'; --Computed tomography services furnished using equipment that does not meet each of the attributes of the national electrical manufacturers association (nema) xr-29-2013 standard
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='DA'; --Oral health assessment by a licensed health professional other than a dentist
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='E1'; --Upper left, eyelid
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='E2'; --Lower left, eyelid
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='E3'; --Upper right, eyelid
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='E4'; --Lower right, eyelid
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='EA'; --Erythropoetic stimulating agent (esa) administered to treat anemia due to anti-cancer chemotherapy
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='EB'; --Erythropoetic stimulating agent (esa) administered to treat anemia due to anti-cancer radiotherapy
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='EC'; --Erythropoetic stimulating agent (esa) administered to treat anemia not due to anti-cancer radiotherapy or anti-cancer chemotherapy
update concept_stage set domain_id='Measurement' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='ED'; --Hematocrit level has exceeded 39% (or hemoglobin level has exceeded 13.0 g/dl) for 3 or more consecutive billing cycles immediately prior to and including the current cycle
update concept_stage set domain_id='Measurement' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='EE'; --Hematocrit level has not exceeded 39% (or hemoglobin level has not exceeded 13.0 g/dl) for 3 or more consecutive billing cycles immediately prior to and including the current cycle
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='EJ'; --Subsequent claims for a defined course of therapy, e.g., epo, sodium hyaluronate, infliximab
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='EM'; --Emergency reserve supply (for esrd benefit only)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='EP'; --Service provided as part of medicaid early periodic screening diagnosis and treatment (epsdt) program
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='ET'; --Emergency services
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='EX'; --Expatriate beneficiary
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='EY'; --No physician or other licensed health care provider order for this item or service
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='F1'; --Left hand, second digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='F2'; --Left hand, third digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='F3'; --Left hand, fourth digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='F4'; --Left hand, fifth digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='F5'; --Right hand, thumb
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='F6'; --Right hand, second digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='F7'; --Right hand, third digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='F8'; --Right hand, fourth digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='F9'; --Right hand, fifth digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='FA'; --Left hand, thumb
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='FB'; --Item provided without cost to provider, supplier or practitioner, or full credit received for replaced device (examples, but not limited to, covered under warranty, replaced due to defect, free samples)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='FC'; --Partial credit received for replaced device
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='FP'; --Service provided as part of family planning program
update concept_stage set domain_id='Measurement' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='G1'; --Most recent urr reading of less than 60
update concept_stage set domain_id='Measurement' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='G2'; --Most recent urr reading of 60 to 64.9
update concept_stage set domain_id='Measurement' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='G3'; --Most recent urr reading of 65 to 69.9
update concept_stage set domain_id='Measurement' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='G4'; --Most recent urr reading of 70 to 74.9
update concept_stage set domain_id='Measurement' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='G5'; --Most recent urr reading of 75 or greater
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='G6'; --Esrd patient for whom less than six dialysis sessions have been provided in a month
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='G7'; --Pregnancy resulted from rape or incest or pregnancy certified by physician as life threatening
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='G8'; --Monitored anesthesia care (mac) for deep complex, complicated, or markedly invasive surgical procedure
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='G9'; --Monitored anesthesia care for patient who has history of severe cardio-pulmonary condition
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GA'; --Waiver of liability statement issued as required by payer policy, individual case
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GB'; --Claim being re-submitted for payment because it is no longer covered under a global payment demonstration
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GC'; --This service has been performed in part by a resident under the direction of a teaching physician
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GD'; --Units of service exceeds medically unlikely edit value and represents reasonable and necessary services
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GE'; --This service has been performed by a resident without the presence of a teaching physician under the primary care exception
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GF'; --Non-physician (e.g. nurse practitioner (np), certified registered nurse anesthetist (crna), certified registered nurse (crn), clinical nurse specialist (cns), physician assistant (pa)) services in a critical access hospital
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GG'; --Performance and payment of a screening mammogram and diagnostic mammogram on the same patient, same day
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GH'; --Diagnostic mammogram converted from screening mammogram on same day
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GJ'; --opt out physician or practitioner emergency or urgent service
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GK'; --Reasonable and necessary item/service associated with a ga or gz modifier
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GL'; --Medically unnecessary upgrade provided instead of non-upgraded item, no charge, no advance beneficiary notice (abn)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GM'; --Multiple patients on one ambulance trip
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GN'; --Services delivered under an outpatient speech language pathology plan of care
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GO'; --Services delivered under an outpatient occupational therapy plan of care
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GP'; --Services delivered under an outpatient physical therapy plan of care
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GQ'; --Via asynchronous telecommunications system
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GR'; --This service was performed in whole or in part by a resident in a department of veterans affairs medical center or clinic, supervised in accordance with va policy
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GS'; --Dosage of erythropoietin stimulating agent has been reduced and maintained in response to hematocrit or hemoglobin level
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GT'; --Via interactive audio and video telecommunication systems
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GU'; --Waiver of liability statement issued as required by payer policy, routine notice
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GV'; --Attending physician not employed or paid under arrangement by the patient's hospice provider
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GW'; --Service not related to the hospice patient's terminal condition
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GX'; --Notice of liability issued, voluntary under payer policy
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GY'; --Item or service statutorily excluded, does not meet the definition of any medicare benefit or, for non-medicare insurers, is not a contract benefit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='GZ'; --Item or service expected to be denied as not reasonable and necessary
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='H9'; --Court-ordered
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HA'; --Child/adolescent program
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HB'; --Adult program, non geriatric
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HC'; --Adult program, geriatric
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HD'; --Pregnant/parenting women's program
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HE'; --Mental health program
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HF'; --Substance abuse program
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HG'; --Opioid addiction treatment program
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HH'; --Integrated mental health/substance abuse program
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HI'; --Integrated mental health and intellectual disability/developmental disabilities program
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HJ'; --Employee assistance program
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HK'; --Specialized mental health programs for high-risk populations
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HL'; --Intern
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HM'; --Less than bachelor degree level
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HN'; --Bachelors degree level
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HO'; --Masters degree level
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HP'; --Doctoral level
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HQ'; --Group setting
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HR'; --Family/couple with client present
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HS'; --Family/couple without client present
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HT'; --Multi-disciplinary team
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HU'; --Funded by child welfare agency
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HV'; --Funded state addictions agency
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HW'; --Funded by state mental health agency
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HX'; --Funded by county/local agency
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HY'; --Funded by juvenile justice agency
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='HZ'; --Funded by criminal justice agency
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='J1'; --Competitive acquisition program no-pay submission for a prescription number
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='J2'; --Competitive acquisition program, restocking of emergency drugs after emergency administration
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='J3'; --Competitive acquisition program (cap), drug not available through cap as written, reimbursed under average sales price methodology
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='J4'; --Dmepos item subject to dmepos competitive bidding program that is furnished by a hospital upon discharge
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='JA'; --Administered intravenously
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='JB'; --Administered subcutaneously
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='JC'; --Skin substitute used as a graft
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='JD'; --Skin substitute not used as a graft
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='JE'; --Administered via dialysate
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='JF'; --Compounded drug
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='JW'; --Drug amount discarded/not administered to any patient
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='K0'; --Lower extremity prosthesis functional level 0 - does not have the ability or potential to ambulate or transfer safely with or without assistance and a prosthesis does not enhance their quality of life or mobility.
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='K1'; --Lower extremity prosthesis functional level 1 - has the ability or potential to use a prosthesis for transfers or ambulation on level surfaces at fixed cadence. typical of the limited and unlimited household ambulator.
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='K2'; --Lower extremity prosthesis functional level 2 - has the ability or potential for ambulation with the ability to traverse low level environmental barriers such as curbs, stairs or uneven surfaces.  typical of the limited community ambulator.
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='K3'; --Lwr ext prost functnl lvl 3
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='K4'; --Lwr ext prost functnl lvl 4
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KA'; --Add on option/accessory for wheelchair
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KB'; --Beneficiary requested upgrade for abn, more than 4 modifiers identified on claim
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KC'; --Replacement of special power wheelchair interface
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KD'; --Drug or biological infused through dme
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KE'; --Bid under round one of the dmepos competitive bidding program for use with non-competitive bid base equipment
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KF'; --Item designated by fda as class iii device
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KG'; --Dmepos item subject to dmepos competitive bidding program number 1
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KH'; --Dmepos item, initial claim, purchase or first month rental
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KI'; --Dmepos item, second or third month rental
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KJ'; --Dmepos item, parenteral enteral nutrition (pen) pump or capped rental, months four to fifteen
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KK'; --Dmepos item subject to dmepos competitive bidding program number 2
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KL'; --Dmepos item delivered via mail
update concept_stage set domain_id='Procedure' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KM'; --Replacement of facial prosthesis including new impression/moulage
update concept_stage set domain_id='Procedure' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KN'; --Replacement of facial prosthesis using previous master model
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KO'; --Single drug unit dose formulation
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KP'; --First drug of a multiple drug unit dose formulation
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KQ'; --Second or subsequent drug of a multiple drug unit dose formulation
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KR'; --Rental item, billing for partial month
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KS'; --Glucose monitor supply for diabetic beneficiary not treated with insulin
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KT'; --Beneficiary resides in a competitive bidding area and travels outside that competitive bidding area and receives a competitive bid item
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KU'; --Dmepos item subject to dmepos competitive bidding program number 3
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KV'; --Dmepos item subject to dmepos competitive bidding program that is furnished as part of a professional service
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KW'; --Dmepos item subject to dmepos competitive bidding program number 4
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KX'; --Requirements specified in the medical policy have been met
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KY'; --Dmepos item subject to dmepos competitive bidding program number 5
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='KZ'; --New coverage not implemented by managed care
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='L1'; --Provider attestation that the hospital laboratory test(s) is not packaged under the hospital opps
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='LC'; --Left circumflex coronary artery
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='LD'; --Left anterior descending coronary artery
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='LL'; --Lease/rental (use the 'll' modifier when dme equipment rental is to be applied against the purchase price)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='LM'; --Left main coronary artery
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='LR'; --Laboratory round trip
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='LS'; --Fda-monitored intraocular lens implant
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='LT'; --Left side (used to identify procedures performed on the left side of the body)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='M2'; --Medicare secondary payer (msp)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='MS'; --Six month maintenance and servicing fee for reasonable and necessary parts and labor which are not covered under any manufacturer or supplier warranty
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='NB'; --Nebulizer system, any type, fda-cleared for use with specific drug
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='NR'; --New when rented (use the 'nr' modifier when dme which was new at the time of rental is subsequently purchased)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='NU'; --New equipment
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='P1'; --A normal healthy patient
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='P2'; --A patient with mild systemic disease
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='P3'; --A patient with severe systemic disease
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='P4'; --A patient with severe systemic disease that is a constant threat to life
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='P5'; --A moribund patient who is not expected to survive without the operation
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='P6'; --A declared brain-dead patient whose organs are being removed for donor purposes
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='PA'; --Surgical or other invasive procedure on wrong body part
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='PB'; --Surgical or other invasive procedure on wrong patient
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='PC'; --Wrong surgery or other invasive procedure on patient
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='PD'; --Diagnostic or related non diagnostic item or service provided in a wholly owned or operated entity to a patient who is admitted as an inpatient within 3 days
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='PI'; --Positron emission tomography (pet) or pet/computed tomography (ct) to inform the initial treatment strategy of tumors that are biopsy proven or strongly suspected of being cancerous based on other diagnostic testing
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='PL'; --Progressive addition lenses
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='PM'; --Post mortem
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='PO'; --Services, procedures and/or surgeries provided at off-campus provider-based outpatient departments
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='PS'; --Positron emission tomography (pet) or pet/computed tomography (ct) to inform the subsequent treatment strategy of cancerous tumors when the beneficiary's treating physician determines that the pet study is needed to inform subsequent anti-tumor strategy
update concept_stage set domain_id='Measurement' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='PT'; --Colorectal cancer screening test; converted to diagnostic test or other procedure
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='Q0'; --Investigational clinical service provided in a clinical research study that is in an approved clinical research study
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='Q1'; --Routine clinical service provided in a clinical research study that is in an approved clinical research study
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='Q2'; --Hcfa/ord demonstration project procedure/service
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='Q3'; --Live kidney donor surgery and related services
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='Q4'; --Service for ordering/referring physician qualifies as a service exemption
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='Q5'; --Service furnished by a substitute physician under a reciprocal billing arrangement
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='Q6'; --Service furnished by a locum tenens physician
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='Q7'; --One class a finding
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='Q8'; --Two class b findings
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='Q9'; --One class b and two class c findings
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QC'; --Single channel monitoring
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QD'; --Recording and storage in solid state memory by a digital recorder
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QE'; --Prescribed amount of oxygen is less than 1 liter per minute (lpm)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QF'; --Prescribed amount of oxygen exceeds 4 liters per minute (lpm) and portable oxygen is prescribed
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QG'; --Prescribed amount of oxygen is greater than 4 liters per minute(lpm)
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QH'; --Oxygen conserving device is being used with an oxygen delivery system
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QJ'; --Services/items provided to a prisoner or patient in state or local custody, however the state or local government, as applicable, meets the requirements in 42 cfr 411.4 (b)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QK'; --Medical direction of two, three, or four concurrent anesthesia procedures involving qualified individuals
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QL'; --Patient pronounced dead after ambulance called
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QM'; --Ambulance service provided under arrangement by a provider of services
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QN'; --Ambulance service furnished directly by a provider of services
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QP'; --Documentation is on file showing that the laboratory test(s) was ordered individually or ordered as a cpt-recognized panel other than automated profile codes 80002-80019, g0058, g0059, and g0060.
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QS'; --Monitored anesthesia care service
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QT'; --Recording and storage on tape by an analog tape recorder
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QW'; --Clia waived test
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QX'; --Crna service: with medical direction by a physician
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QY'; --Medical direction of one certified registered nurse anesthetist (crna) by an anesthesiologist
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='QZ'; --Crna service: without medical direction by a physician
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='RA'; --Replacement of a dme, orthotic or prosthetic item
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='RB'; --Replacement of a part of a dme, orthotic or prosthetic item furnished as part of a repair
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='RC'; --Right coronary artery
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='RD'; --Drug provided to beneficiary, but not administered "incident-to" 
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='RE'; --Furnished in full compliance with fda-mandated risk evaluation and mitigation strategy (rems)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='RI'; --Ramus intermedius coronary artery
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='RR'; --Rental (use the 'rr' modifier when dme is to be rented)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='RT'; --Right side (used to identify procedures performed on the right side of the body)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SA'; --Nurse practitioner rendering service in collaboration with a physician
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SB'; --Nurse midwife
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SC'; --Medically necessary service or supply
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SD'; --Services provided by registered nurse with specialized, highly technical home infusion training
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SE'; --State and/or federally-funded programs/services
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SF'; --Second opinion ordered by a professional review organization (pro) per section 9401, p.l. 99-272 (100% reimbursement - no medicare deductible or coinsurance)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SG'; --Ambulatory surgical center (asc) facility service
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SH'; --Second concurrently administered infusion therapy
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SJ'; --Third or more concurrently administered infusion therapy
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SK'; --Member of high risk population (use only with codes for immunization)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SL'; --State supplied vaccine
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SM'; --Second surgical opinion
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SN'; --Third surgical opinion
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SQ'; --Item ordered by home health
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SS'; --Home infusion services provided in the infusion suite of the iv therapy provider
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='ST'; --Related to trauma or injury
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SU'; --Procedure performed in physician's office (to denote use of facility and equipment)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SV'; --Pharmaceuticals delivered to patient's home but not utilized
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SW'; --Services provided by a certified diabetic educator
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SY'; --Persons who are in close contact with member of high-risk population (use only with codes for immunization)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='SZ'; --Habilitative services
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='T1'; --Left foot, second digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='T2'; --Left foot, third digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='T3'; --Left foot, fourth digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='T4'; --Left foot, fifth digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='T5'; --Right foot, great toe
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='T6'; --Right foot, second digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='T7'; --Right foot, third digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='T8'; --Right foot, fourth digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='T9'; --Right foot, fifth digit
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TA'; --Left foot, great toe
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TC'; --Technical component
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TD'; --Rn
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TE'; --Lpn/lvn
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TF'; --Intermediate level of care
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TG'; --Complex/high tech level of care
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TH'; --Obstetrical treatment/services, prenatal or postpartum
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TJ'; --Program group, child and/or adolescent
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TK'; --Extra patient or passenger, non-ambulance
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TL'; --Early intervention/individualized family service plan (ifsp)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TM'; --Individualized education program (iep)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TN'; --Rural/outside providers' customary service area
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TP'; --Medical transport, unloaded vehicle
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TQ'; --Basic life support transport by a volunteer ambulance provider
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TR'; --School-based individualized education program (iep) services provided outside the public school district responsible for the student
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TS'; --Follow-up service
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TT'; --Individualized service provided to more than one patient in same setting
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TU'; --Special payment rate, overtime
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TV'; --Special payment rates, holidays/weekends
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='TW'; --Back-up equipment
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='U1'; --Medicaid level of care 1, as defined by each state
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='U2'; --Medicaid level of care 2, as defined by each state
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='U3'; --Medicaid level of care 3, as defined by each state
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='U4'; --Medicaid level of care 4, as defined by each state
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='U5'; --Medicaid level of care 5, as defined by each state
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='U6'; --Medicaid level of care 6, as defined by each state
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='U7'; --Medicaid level of care 7, as defined by each state
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='U8'; --Medicaid level of care 8, as defined by each state
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='U9'; --Medicaid level of care 9, as defined by each state
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UA'; --Medicaid level of care 10, as defined by each state
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UB'; --Medicaid level of care 11, as defined by each state
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UC'; --Medicaid level of care 12, as defined by each state
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UD'; --Medicaid level of care 13, as defined by each state
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UE'; --Used durable medical equipment
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UF'; --Services provided in the morning
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UG'; --Services provided in the afternoon
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UH'; --Services provided in the evening
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UJ'; --Services provided at night
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UK'; --Services provided on behalf of the client to someone other than the client (collateral relationship)
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UN'; --Two patients served
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UP'; --Three patients served
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UQ'; --Four patients served
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='UR'; --Five patients served
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='US'; --Six or more patients served
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='V5'; --Vascular catheter (alone or with any other vascular access)
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='V6'; --Arteriovenous graft (or other vascular access not including a vascular catheter)
update concept_stage set domain_id='Device' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='V7'; --Arteriovenous fistula only (in use with two needles)
update concept_stage set domain_id='Condition' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='V8'; --Infection present
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='V9'; --No infection present
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='VP'; --Aphakic patient
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='XE'; --Separate encounter, a service that is distinct because it occurred during a separate encounter
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='XP'; --Separate practitioner, a service that is distinct because it was performed by a different practitioner
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='XS'; --Separate structure, a service that is distinct because it was performed on a separate organ/structure
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='XU'; --Unusual non-overlapping service, the use of a service that is distinct because it does not overlap usual components of the main service
update concept_stage set domain_id='Observation' where vocabulary_id='HCPCS' and concept_class_id='HCPCS Modifier' and concept_code='ZA'; --Novartis/sandoz
end;
COMMIT;

--if some codes does not have domain_id pick it up from existing concept table
UPDATE concept_stage cs
   SET domain_id =
          (SELECT domain_id
             FROM concept c
            WHERE     C.CONCEPT_CODE = CS.CONCEPT_CODE
                  AND C.VOCABULARY_ID = CS.VOCABULARY_ID)
WHERE CS.DOMAIN_ID IS NULL AND CS.VOCABULARY_ID = 'HCPCS';
COMMIT;

--Procedure Drug codes are handled as Procedures, but this might change in near future. 
--Therefore, we are keeping an interim domain_id='Procedure Drug'
UPDATE concept_stage
   SET domain_id = 'Procedure'
 WHERE domain_id = 'Procedure Drug';
COMMIT;

DROP TABLE t_domains PURGE;

--5 Create CONCEPT_SYNONYM_STAGE
INSERT /*+ APPEND */ INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT DISTINCT NULL AS synonym_concept_id,
                   HCPC AS synonym_concept_code,
                   DESCRIPTION AS synonym_name,
                   'HCPCS' AS synonym_vocabulary_id,
                   4180186 AS language_concept_id                   -- English
     FROM (SELECT LONG_DESCRIPTION, SHORT_DESCRIPTION, HCPC FROM ANWEB_V2) UNPIVOT (DESCRIPTION --take both LONG_DESCRIPTION and SHORT_DESCRIPTION
                                                                           FOR DESCRIPTIONS
                                                                           IN (LONG_DESCRIPTION,
                                                                              SHORT_DESCRIPTION));
COMMIT;

--6 Insert existing concepts with concept_class_id = 'HCPCS Class'
INSERT /*+ APPEND */ INTO  concept_stage
   SELECT *
     FROM concept
    WHERE vocabulary_id = 'HCPCS' AND concept_class_id = 'HCPCS Class';
COMMIT;	

--7 Run HCPCS/procedure_drug.sql. This will create all the input files for MapDrugVocabulary.sql

--8 Run the generic working/MapDrugVocabulary.sql. This will produce a concept_relationship_stage with HCPCS to RxNorm relatoinships

--9 Add all other relationships from the existing one. The reason is that there is no good source for these relationships, and we have to build the ones for new codes from UMLS and manually
INSERT /*+ APPEND */ INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT NULL AS concept_id_1,
          NULL AS concept_id_2,
          c.concept_code AS concept_code_1,
          c1.concept_code AS concept_code_2,
          r.relationship_id AS relationship_id,
          c.vocabulary_id AS vocabulary_id_1,
          c1.vocabulary_id AS vocabulary_id_2,
          r.valid_start_date,
          r.valid_end_date,
          r.invalid_reason
     FROM concept_relationship r, concept c, concept c1
    WHERE     c.concept_id = r.concept_id_1
          AND c.vocabulary_id = 'HCPCS'
          AND c1.concept_id = r.concept_id_2
		  AND r.relationship_id NOT IN ('Concept replaced by','Is a') --we add it below
		  AND NOT (c1.vocabulary_id='RxNorm' AND r.relationship_id='Maps to'); 
COMMIT;

--10 Add upgrade relationships
INSERT /*+ APPEND */ INTO  concept_relationship_stage (
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT concept_code_1,
                   concept_code_2,
                   'Concept replaced by' AS relationship_id,
                   'HCPCS' AS vocabulary_id_1,
                   'HCPCS' AS vocabulary_id_2,
                   valid_start_date,
                   valid_end_date,
                   NULL AS invalid_reason
     FROM (SELECT A.HCPC AS concept_code_1,
                  A.XREF1 AS concept_code_2,
                  COALESCE (A.ADD_DATE, A.ACT_EFF_DT) AS valid_start_date,
                  COALESCE (A.TERM_DT, TO_DATE ('20991231', 'yyyymmdd'))
                     AS valid_end_date
             FROM ANWEB_V2 a, ANWEB_V2 b
            WHERE     A.XREF1 = B.HCPC
                  AND A.TERM_DT IS NOT NULL
                  AND B.TERM_DT IS NULL
           UNION ALL
           SELECT A.HCPC AS concept_code_1,
                  A.XREF2,
                  COALESCE (A.ADD_DATE, A.ACT_EFF_DT),
                  COALESCE (A.TERM_DT, TO_DATE ('20991231', 'yyyymmdd'))
             FROM ANWEB_V2 a, ANWEB_V2 b
            WHERE     A.XREF2 = B.HCPC
                  AND A.TERM_DT IS NOT NULL
                  AND B.TERM_DT IS NULL
           UNION ALL
           SELECT A.HCPC AS concept_code_1,
                  A.XREF3,
                  COALESCE (A.ADD_DATE, A.ACT_EFF_DT),
                  COALESCE (A.TERM_DT, TO_DATE ('20991231', 'yyyymmdd'))
             FROM ANWEB_V2 a, ANWEB_V2 b
            WHERE     A.XREF3 = B.HCPC
                  AND A.TERM_DT IS NOT NULL
                  AND B.TERM_DT IS NULL
           UNION ALL
           SELECT A.HCPC AS concept_code_1,
                  A.XREF4,
                  COALESCE (A.ADD_DATE, A.ACT_EFF_DT),
                  COALESCE (A.TERM_DT, TO_DATE ('20991231', 'yyyymmdd'))
             FROM ANWEB_V2 a, ANWEB_V2 b
            WHERE     A.XREF4 = B.HCPC
                  AND A.TERM_DT IS NOT NULL
                  AND B.TERM_DT IS NULL
           UNION ALL
           SELECT A.HCPC AS concept_code_1,
                  A.XREF5,
                  COALESCE (A.ADD_DATE, A.ACT_EFF_DT),
                  COALESCE (A.TERM_DT, TO_DATE ('20991231', 'yyyymmdd'))
             FROM ANWEB_V2 a, ANWEB_V2 b
            WHERE     A.XREF5 = B.HCPC
                  AND A.TERM_DT IS NOT NULL
                  AND B.TERM_DT IS NULL) i
    WHERE NOT EXISTS
             (SELECT 1
                FROM concept_relationship_stage crs_int
               WHERE     crs_int.concept_code_1 = i.concept_code_1
                     AND crs_int.concept_code_2 = i.concept_code_2
                     AND crs_int.vocabulary_id_1 = 'HCPCS'
                     AND crs_int.vocabulary_id_2 = 'HCPCS'
                     AND crs_int.relationship_id = 'Concept replaced by');
COMMIT;		  

--11 Working with replacement mappings
BEGIN
   DEVV5.VOCABULARY_PACK.CheckReplacementMappings;
END;
COMMIT;

--12 Deprecate 'Maps to' mappings to deprecated and upgraded concepts
BEGIN
   DEVV5.VOCABULARY_PACK.DeprecateWrongMAPSTO;
END;
COMMIT;			

--13 Create hierarchical relationships between HCPCS and HCPCS class
INSERT /*+ APPEND */ INTO concept_relationship_stage (
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT
          A.HCPC AS concept_code_1,
          A.BETOS AS concept_code_2,
          'Is a' AS relationship_id,
          'HCPCS' AS vocabulary_id_1,
          'HCPCS' AS vocabulary_id_2,
          COALESCE (A.ADD_DATE, A.ACT_EFF_DT) AS valid_start_date,
          COALESCE (A.TERM_DT, TO_DATE ('20991231', 'yyyymmdd'))
             AS valid_end_date,
          CASE
             WHEN TERM_DT IS NULL THEN NULL
             WHEN XREF1 IS NULL THEN 'D'                         -- deprecated
             ELSE NULL                                             -- upgraded
          END
             AS invalid_reason
     FROM ANWEB_V2 a
    JOIN concept c
          ON     c.concept_code = A.BETOS
             AND c.concept_class_id = 'HCPCS Class'
             AND c.VOCABULARY_ID = 'HCPCS'
			 AND c.invalid_reason IS NULL; 
COMMIT;	

--14 Add all other 'Concept replaced by' relationships
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT c.concept_code AS concept_code_1,
          c1.concept_code AS concept_code_2,
          r.relationship_id AS relationship_id,
          c.vocabulary_id AS vocabulary_id_1,
          c1.vocabulary_id AS vocabulary_id_2,
          r.valid_start_date,
          r.valid_end_date,
          r.invalid_reason
     FROM concept_relationship r, concept c, concept c1
    WHERE     c.concept_id = r.concept_id_1
          AND c.vocabulary_id = 'HCPCS'
          AND c1.concept_id = r.concept_id_2
          AND r.relationship_id IN ('Concept replaced by',
                                    'Concept same_as to',
                                    'Concept alt_to to',
                                    'Concept poss_eq to',
                                    'Concept was_a to')
          AND r.invalid_reason IS NULL
          AND (SELECT COUNT (*)
                 FROM concept_relationship r_int
                WHERE     r_int.concept_id_1 = r.concept_id_1
                      AND r_int.relationship_id = r.relationship_id
                      AND r_int.invalid_reason IS NULL) = 1
          AND NOT EXISTS
                 (SELECT 1
                    FROM concept_relationship_stage crs
                   WHERE     crs.concept_code_1 = c.concept_code
                         AND crs.vocabulary_id_1 = c.vocabulary_id
                         AND crs.relationship_id = r.relationship_id);
COMMIT;						 

--15 Create text for Medical Coder with new codes and mappings
SELECT NULL AS concept_id_1,
       NULL AS concept_id_2,
       c.concept_code AS concept_code_1,
       u2.scui AS concept_code_2,
       CASE
          WHEN c.domain_id = 'Procedure' THEN 'HCPCS - SNOMED proc'
          WHEN c.domain_id = 'Measurement' THEN 'HCPCS - SNOMED meas'
          ELSE 'HCPCS - SNOMED obs'
       END
          AS relationship_id, -- till here strawman for concept_relationship to be checked and filled out, the remaining are supportive information to be truncated in the return file
       c.concept_name AS cpt_name,
       u2.str AS snomed_str,
       sno.concept_id AS snomed_concept_id,
       sno.concept_name AS snomed_name
  FROM concept_stage c
       LEFT JOIN
       (                                         -- UMLS record for HCPCS code
        SELECT DISTINCT cui, scui
          FROM UMLS.mrconso
         WHERE sab IN ('HCPCS') AND suppress NOT IN ('E', 'O', 'Y')) u1
          ON u1.scui = concept_code                  -- join UMLS for code one
       LEFT JOIN
       (                        -- UMLS record for SNOMED code of the same cui
        SELECT DISTINCT
               cui,
               scui,
               FIRST_VALUE (
                  str)
               OVER (PARTITION BY scui
                     ORDER BY DECODE (tty,  'PT', 1,  'PTGB', 2,  10))
                  AS str
          FROM UMLS.mrconso
         WHERE sab IN ('SNOMEDCT_US') AND suppress NOT IN ('E', 'O', 'Y')) u2
          ON u2.cui = u1.cui
       LEFT JOIN concept sno
          ON sno.vocabulary_id = 'SNOMED' AND sno.concept_code = u2.scui -- SNOMED concept
 WHERE     NOT EXISTS
              (                        -- only new codes we don't already have
               SELECT 1
                 FROM concept co
                WHERE     co.concept_code = c.concept_code
                      AND co.vocabulary_id = 'HCPCS')
       AND c.vocabulary_id = 'HCPCS'
       AND c.concept_class_id IN ('HCPCS', 'HCPCS Modifier');

--16 Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage
BEGIN
   DEVV5.VOCABULARY_PACK.ProcessManualRelationships;
END;
COMMIT;

--17 Add mapping from deprecated to fresh concepts
BEGIN
   DEVV5.VOCABULARY_PACK.AddFreshMAPSTO;
END;
COMMIT;	   

--18 Delete ambiguous 'Maps to' mappings
BEGIN
   DEVV5.VOCABULARY_PACK.DeleteAmbiguousMAPSTO;
END;
COMMIT;		 

--19 All the codes that have mapping to RxNorm should get domain_id='Drug'
UPDATE concept_stage cs
   SET cs.domain_id='Drug'
 WHERE     EXISTS
-- existing in concept_relationship
              (SELECT 1
                 FROM concept_relationship r, concept c1, concept c2
                WHERE     r.concept_id_1 = c1.concept_id
                      AND r.concept_id_2 = c2.concept_id
                      AND r.invalid_reason IS NULL
                      AND r.relationship_id = 'Maps to'
                      AND c2.vocabulary_id = 'RxNorm'
                      AND c1.concept_code = cs.concept_code
                      AND c1.vocabulary_id = cs.vocabulary_id
               UNION ALL
-- new in concept_relationship_stage
               SELECT 1
                 FROM concept_relationship_stage r
                WHERE     r.concept_code_1 = cs.concept_code
                      AND r.vocabulary_id_1 = cs.vocabulary_id
                      AND r.invalid_reason IS NULL
                      AND r.relationship_id = 'Maps to'
                      AND r.vocabulary_id_2 = 'RxNorm')
       AND cs.domain_id<>'Drug';
COMMIT;

--20 Procedure Drugs who have a mapping to a Drug concept should not also be recorded as Procedures (no Standard Concepts)
UPDATE concept_stage cs
   SET cs.standard_concept = NULL
 WHERE     EXISTS
              (SELECT 1
                 FROM concept_relationship r, concept c1, concept c2
                WHERE     r.concept_id_1 = c1.concept_id
                      AND r.concept_id_2 = c2.concept_id
                      AND r.invalid_reason IS NULL
                      AND r.relationship_id = 'Maps to'
                      AND c2.domain_id = 'Drug'
                      AND c1.concept_code = cs.concept_code
                      AND c1.vocabulary_id = cs.vocabulary_id
               UNION ALL
               SELECT 1
                 FROM concept_relationship_stage r, concept c2
                WHERE     r.concept_code_1 = cs.concept_code
                      AND r.vocabulary_id_1 = cs.vocabulary_id
                      AND r.concept_code_2 = c2.concept_code
                      AND r.vocabulary_id_2 = c2.vocabulary_id
                      AND r.invalid_reason IS NULL
                      AND r.relationship_id = 'Maps to'
                      AND c2.domain_id = 'Drug')
       AND cs.standard_concept IS NOT NULL;
COMMIT;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script