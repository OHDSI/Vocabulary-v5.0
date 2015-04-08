--1. Update latest_update field to new date 
BEGIN
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
ALTER TABLE vocabulary ADD latest_update DATE;
update vocabulary set latest_update=to_date('20141112','yyyymmdd'), vocabulary_version='2015 Annual Alpha Numeric HCPCS File' where vocabulary_id='HCPCS'; commit;

-- 2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
ALTER SESSION SET SKIP_UNUSABLE_INDEXES = TRUE; --disables error reporting of indexes and index partitions marked UNUSABLE
ALTER INDEX idx_cs_concept_code UNUSABLE;
ALTER INDEX idx_cs_concept_id UNUSABLE;
ALTER INDEX idx_concept_code_1 UNUSABLE;
ALTER INDEX idx_concept_code_2 UNUSABLE;

--3. Create concept_stage from HCPCS
INSERT INTO concept_stage (concept_id,
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
CREATE TABLE t_domains nologging AS
--create temporary table with domain_id defined by rules
    (
    SELECT 
      hcpc.concept_code,
      case 
        --review by name with exlusions
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

--if some codes does not have domain_id pick it up from existing concept table
UPDATE concept_stage cs
   SET domain_id =
          (SELECT domain_id
             FROM concept c
            WHERE     C.CONCEPT_CODE = CS.CONCEPT_CODE
                  AND C.VOCABULARY_ID = CS.VOCABULARY_ID)
WHERE CS.DOMAIN_ID IS NULL AND CS.VOCABULARY_ID = 'HCPCS';
COMMIT;

--Procedure codes are handled as Procedures, but this might change in near future. 
--Therefore, we are keeping an interim domain_id='Procedure Drug'
UPDATE concept_stage
   SET domain_id = 'Procedure'
 WHERE domain_id = 'Procedure Drug';
COMMIT;

DROP TABLE t_domains PURGE;

--5 Create CONCEPT_SYNONYM_STAGE
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   synonym_vocabulary_id,
                                   language_concept_id)
   SELECT DISTINCT NULL AS synonym_concept_id,
                   HCPC AS synonym_concept_code,
                   DESCRIPTION AS synonym_name,
                   'HCPCS' AS synonym_vocabulary_id,
                   4093769 AS language_concept_id                   -- English
     FROM (SELECT LONG_DESCRIPTION, SHORT_DESCRIPTION, HCPC FROM ANWEB_V2) UNPIVOT (DESCRIPTION --take both LONG_DESCRIPTION and SHORT_DESCRIPTION
                                                                           FOR DESCRIPTIONS
                                                                           IN (LONG_DESCRIPTION,
                                                                              SHORT_DESCRIPTION));
COMMIT;

--6  Load concept_relationship_stage from the existing one. The reason is that there is no good source for these relationships, and we have to build the ones for new codes from UMLS and manually
INSERT INTO concept_relationship_stage (concept_id_1,
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
          AND C1.CONCEPT_ID = r.concept_id_2; 
COMMIT;

--7 Add upgrade relationships
INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT NULL AS concept_id_1,
                   NULL AS concept_id_2,
                   concept_code_1,
                   concept_code_2,
                   'Concept replaced by' AS relationship_id,
                   'HCPCS' AS vocabulary_id_1,
                   'HCPCS' AS vocabulary_id_2,
                   valid_start_date,
                   valid_end_date,
                   'U' AS invalid_reason
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
                  AND B.TERM_DT IS NULL);
COMMIT;		  


--8 Create hierarchical relationships between HCPCS and HCPCS class
INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT
          NULL AS concept_id_1,
          NULL AS concept_id_2,
          A.HCPC AS concept_code_1,
          A.BETOS AS concept_code_2,
          'Is a' AS relationship_id,
          'HCPCS' AS vocabulary_id_1,
          'HCPCS Class' AS vocabulary_id_2,
          COALESCE (A.ADD_DATE, A.ACT_EFF_DT) AS valid_start_date,
          COALESCE (A.TERM_DT, TO_DATE ('20991231', 'yyyymmdd'))
             AS valid_end_date,
          CASE
             WHEN TERM_DT IS NULL THEN NULL
             WHEN XREF1 IS NULL THEN 'D'                         -- deprecated
             ELSE 'U'                                              -- upgraded
          END
             AS invalid_reason
     FROM ANWEB_V2 a
    WHERE A.BETOS IS NOT NULL;
COMMIT;	

--9 Create text for Medical Coder with new codes and mappings
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

--10 Append resulting file from Medical Coder (in concept_relationship_stage format) to concept_relationship_stage

--11. Add mapping from deprecated to fresh concepts
INSERT  /*+ APPEND */  INTO concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
    SELECT 
      root,
      concept_code_2,
      root_vocabulary_id,
      vocabulary_id_2,
      'Maps to',
      (SELECT latest_update FROM vocabulary WHERE vocabulary_id=root_vocabulary_id),
      TO_DATE ('31.12.2099', 'dd.mm.yyyy'),
      NULL
    FROM 
    (
        SELECT root_vocabulary_id, root, concept_code_2, vocabulary_id_2 FROM (
          SELECT root_vocabulary_id, root, concept_code_2, vocabulary_id_2, dt,  ROW_NUMBER() OVER (PARTITION BY root_vocabulary_id, root ORDER BY dt DESC) rn
            FROM (
                SELECT 
                      concept_code_2, 
                      vocabulary_id_2,
                      valid_start_date AS dt,
                      CONNECT_BY_ROOT concept_code_1 AS root,
                      CONNECT_BY_ROOT vocabulary_id_1 AS root_vocabulary_id,
                      CONNECT_BY_ISLEAF AS lf
                FROM concept_relationship_stage
                WHERE relationship_id IN ( 'Concept replaced by',
                                               'Concept same_as to',
                                               'Concept alt_to to',
                                               'Concept poss_eq to',
                                               'Concept was_a to',
                                               'Original maps to'
                                             )
                      and NVL(invalid_reason, 'X') <> 'D'
                CONNECT BY  
                NOCYCLE  
                PRIOR concept_code_2 = concept_code_1
                      AND relationship_id IN ( 'Concept replaced by',
                                               'Concept same_as to',
                                               'Concept alt_to to',
                                               'Concept poss_eq to',
                                               'Concept was_a to',
                                               'Original maps to'
                                             )
                       AND vocabulary_id_2=vocabulary_id_1                     
                       AND NVL(invalid_reason, 'X') <> 'D'
                                   
                START WITH relationship_id IN ('Concept replaced by',
                                               'Concept same_as to',
                                               'Concept alt_to to',
                                               'Concept poss_eq to',
                                               'Concept was_a to',
                                               'Original maps to'
                                              )
                      AND NVL(invalid_reason, 'X') <> 'D'
          ) sou 
          WHERE lf = 1
        ) 
        WHERE rn = 1
    ) int_rel WHERE NOT EXISTS -- only new mapping we don't already have
    (select 1 from concept_relationship_stage r where
        int_rel.root=r.concept_code_1
        and int_rel.concept_code_2=r.concept_code_2
        and int_rel.root_vocabulary_id=r.vocabulary_id_1
        and int_rel.vocabulary_id_2=r.vocabulary_id_2
        and r.relationship_id='Maps to'
    );

COMMIT;

--12 Proceudre Drugs who have a mapping to a Drug concept should not also be recorded as Procedures (no Standard Concepts)
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
                 FROM concept_relationship_stage r, concept_stage c2
                WHERE     r.concept_code_1 = cs.concept_code
                      AND r.vocabulary_id_1 = cs.vocabulary_id
                      AND r.concept_code_2 = c2.concept_code
                      AND r.vocabulary_id_2 = c2.vocabulary_id
                      AND r.invalid_reason IS NULL
                      AND r.relationship_id = 'Maps to'
                      AND c2.domain_id = 'Drug')
       AND standard_concept IS NOT NULL;
COMMIT;

--13 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;

--14 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;	

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script