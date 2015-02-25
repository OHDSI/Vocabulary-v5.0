
--1. Update latest_update field to new date 
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
       SUBSTR (a.LONG_DESCRIPTION, 1, 256) AS concept_name,
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
    (
    SELECT 
      hcpc.concept_code,
      CASE 
        -- A codes
        WHEN hcpc.concept_code IN ('A9150', 'A9152', 'A9153', 'A9155', 'A9180') THEN 'Procedure Drug' -- generic procedure drugs, no mapping possible
        WHEN l3.str = 'Supplies for Radiologic Procedures' THEN '???' -- Level 3: A4641-A4642
        WHEN l3.str = 'Supplies for Radiology Procedures (Radiopharmaceuticals)' THEN '???' -- Level 3: A9500-A9700
        WHEN l2.str = 'Transport Services Including Ambulance' THEN 'Observation' -- Level 2: A0000-A0999
        WHEN l1.str = 'A Codes' THEN 'Device' -- default for Level 1: A0000-A9999
        -- B codes
        WHEN l1.str = 'Enteral AND Parenteral Therapy Supplies' THEN 'Device' -- all of them Level 1: B4000-B9999
        -- C codes
        WHEN hcpc.concept_code = 'C1204' THEN '???' -- Technetium tc 99m tilmanocept, diagnostic, up to 0.5 millicuries
        WHEN hcpc.concept_code like 'C%' AND concept_name like '%Brachytherapy%source%' THEN '???' -- Brachytherapy codes
        WHEN hcpc.concept_code like 'C%' AND concept_name like '%Magnetic resonance% with%' THEN 'Procedure' -- MRIs
        WHEN hcpc.concept_code like 'C%' AND concept_name like '%Trans% echocardiography%' THEN 'Procedure' -- Echocardiography
        WHEN hcpc.concept_code BETWEEN 'C9021' AND 'C9349' THEN 'Procedure Drug' -- various drug products
        WHEN hcpc.concept_code BETWEEN 'C9352' AND 'C9369' THEN 'Device' -- various graft matrix material
        WHEN hcpc.concept_code = 'C9406' THEN '???' -- Iodine i-123 ioflupane, diagnostic, per study dose, up to 5 millicuries
        WHEN hcpc.concept_code BETWEEN 'C9399' AND 'C9497' THEN 'Procedure Drug' 
        WHEN hcpc.concept_code BETWEEN 'C9600' AND 'C9800' THEN 'Procedure'
        WHEN l1.str = 'C Codes - CMS Hospital Outpatient System' THEN 'Device' -- default for Level 1: C1000-C9999
        -- E codes
        WHEN l1.str = 'E-codes' THEN 'Device' -- all of them Level 1: E0100-E9999
        -- G codes
        WHEN l2.str = 'Vaccine Administration' THEN 'Procedure Drug' -- Level 2: G0008-G0010
        WHEN l2.str = 'Semen Analysis' THEN 'Measurement' -- Level 2: G0027-G0027
        WHEN l2.str = 'Screening Services - Cervical' THEN 'Observation' -- Level 2: G0101-G0101
        WHEN hcpc.concept_code = 'G0102' THEN 'Observation' -- Prostate cancer screening; digital rectal examination
        WHEN hcpc.concept_code = 'G0103' THEN 'Measurement' -- Prostate cancer screening; prostate specific antigen test (psa)
        WHEN l2.str = 'Training Services - Diabetes' THEN 'Observation' -- Level 2: G0108-G0109
        WHEN l2.str = 'Screening Services - Cytopathology' THEN 'Measurement' -- Level 2: G0123-G0124
        WHEN l2.str = 'Service, Nurse AND OT' THEN 'Observation' -- Level 2: G0128-G0129
        WHEN l2.str = 'Screening Services - Cytopathology, Other' THEN 'Measurement' -- Level 2: G0141-G0148
        WHEN l2.str = 'Services, Allied Health' THEN 'Observation' -- Level 2: G0151-G0166
        WHEN l2.str = 'Team Conference' THEN 'Observation' -- Level 2: G0175-G0175
        WHEN hcpc.concept_code = 'G0177' THEN 'Observation' -- Training AND educational services related to the care AND treatment of patient's disabling mental health problems per session (45 minutes or more)
        WHEN l2.str = 'Physician Services' THEN 'Observation' -- Level 2: G0179-G0182
        WHEN l2.str = 'Physician Services, Diabetic' THEN 'Observation' -- Level 2: G0245-G0246
        WHEN l2.str = 'Demonstration, INR' THEN 'Observation' -- Level 2: G0248-G0250
        WHEN l2.str = 'Services, Pulmonary Surgery' THEN 'Observation' -- Level 2: G0302-G0305
        WHEN l2.str = 'Laboratory' THEN 'Measurement' -- Level 2: G0306-G0328
        WHEN l2.str = 'Fee, Pharmacy' THEN 'Procedure Drug' -- Level 2: G0333-G0333
        WHEN l2.str = 'Hospice' THEN 'Observation' -- Level 2: G0337-G0337
        WHEN l2.str = 'Services, Observation AND ED' THEN 'Observation' -- Level 2: G0378-G0384
        WHEN l2.str = 'Team, Trauma Response' THEN 'Observation' -- Level 2: G0390-G0390
        WHEN l2.str = 'Examination, Initial Medicare' THEN 'Observation' -- Level 2: G0402-G0402
        WHEN l2.str = 'Electrocardiogram' THEN 'Measurement' -- Level 2: G0403-G0405
        WHEN l2.str = 'Telehealth' THEN 'Observation' -- Level 2: G0406-G0408
        WHEN l2.str = 'Services, Social, Psychological' THEN 'Obsrvation' -- Level 2: G0409-G0411
        WHEN l2.str = 'Pathology, Surgical' THEN 'Measurement' -- Level 2: G0416-G0419
        WHEN hcpc.concept_code IN ('G0428', 'G0429') THEN 'Procedure'
        WHEN hcpc.concept_code IN ('G0431', 'G0432', 'G0433', 'G0434', 'G0435') THEN 'Measurement' -- drug screen, infectious antibodies
        WHEN hcpc.concept_code IN ('G0438', 'G0439') THEN 'Observation' -- annual wellness visit
        WHEN hcpc.concept_code IN ('G0440', 'G0441') THEN 'Procedure' -- allogenic skin substitute
        WHEN hcpc.concept_code IN ('G0442', 'G0443', 'G0444', 'G0445', 'G0446', 'G0447') THEN 'Procedure' -- Various screens AND counseling
        WHEN hcpc.concept_code = 'G0448' THEN 'Procedure' -- Insertion or replacement of a permanent pacing cardioverter-defibrillator system with transvenous lead(s), single or dual chamber with insertion of pacing electrode, cardiac venous system, for left ventricular pacing
        WHEN hcpc.concept_code = 'G0451' THEN 'Observation' -- Development testing, with interpretation AND report, per standardized instrument form
        WHEN hcpc.concept_code = 'G0452' THEN 'Measurement' -- Molecular pathology procedure; physician interpretation AND report
        WHEN hcpc.concept_code = 'G0453' THEN 'Procedure' -- Continuous intraoperative neurophysiology monitoring, from outside the operating room (remote or nearby), per patient, (attention directed exclusively to one patient) each 15 minutes (list IN addition to primary procedure)
        WHEN hcpc.concept_code = 'G0454' THEN 'Observation' -- Physician documentation of face-to-face visit for durable medical equipment determination performed by nurse practitioner, physician assistant or clinical nurse specialist
        WHEN hcpc.concept_code = 'G0455' THEN 'Procedure' -- Preparation with instillation of fecal microbiota by any method, including assessment of donor specimen
        WHEN hcpc.concept_code IN ('G0456', 'G0457') THEN 'Procedure' -- Negative pressure wound therapies
        WHEN hcpc.concept_code = 'G0458' THEN 'Procedure' -- Low dose rate (ldr) prostate brachytherapy services, composite rate
        WHEN hcpc.concept_code = 'G0459' THEN 'Procedure' -- Inpatient telehealth pharmacologic management, including prescription, use, AND review of medication with no more than minimal medical psychotherapy
        WHEN hcpc.concept_code = 'G0460' THEN 'Procedure' -- Autologous platelet rich plasma for chronic wounds/ulcers, incuding phlebotomy, centrifugation, AND all other preparatory procedures, administration AND dressings, per treatment
        WHEN hcpc.concept_code IN ('G0461', 'G0462') THEN 'Measurement' --    Immunohistochemistry or immunocytochemistry
        WHEN hcpc.concept_code = 'G0463' THEN 'Observation' -- Hospital outpatient clinic visit for assessment AND management of a patient
        WHEN hcpc.concept_code = 'G0464' THEN 'Measurement' -- Colorectal cancer screening; stool-based dna AND fecal occult hemoglobin (e.g., kras, ndrg4 AND bmp3)
        WHEN hcpc.concept_code IN ('G0466', 'G0467', 'G0468', 'G0469', 'G0470') THEN 'Observation' -- Federally qualified health center (fqhc) visits
        WHEN hcpc.concept_code = 'G0471' THEN 'Procedure' -- Collection of venous blood by venipuncture or urine sample by catheterization from an individual IN a skilled nursing facility (snf) or by a laboratory on behalf of a home health agency (hha)
        WHEN hcpc.concept_code = 'G0472' THEN 'Measurement' -- Hepatitis c antibody screening, for individual at high risk AND other covered indication(s)
        WHEN hcpc.concept_code = 'G0473' THEN 'Procedure' -- Face-to-face behavioral counseling for obesity, group (2-10), 30 minutes
        WHEN hcpc.concept_code IN ('G0908', 'G0909', 'G0910', 'G0911', 'G0912', 'G0913', 'G0914', 'G0915', 'G0916', 'G0917', 'G0918', 'G0919', 'G0920', 'G0921', 'G0922') THEN 'Observation' -- various documented levels AND assessments
        WHEN l2.str = 'Tositumomab' THEN 'Procedure Drug' -- Level 2: G3001-G3001
        WHEN hcpc.concept_code IN ('G6001', 'G6002', 'G6003', 'G6004', 'G6005', 'G6006', 'G6007', 'G6008', 'G6009', 'G6010', 'G6011', 'G6012', 'G6013', 'G6014', 'G6015', 'G6016', 'G6017') THEN 'Procedure' -- various radiation treatment deliveries
        WHEN hcpc.concept_code IN ('G6018', 'G6019', 'G6020', 'G6021', 'G6022', 'G6023', 'G6024', 'G6025', 'G6027', 'G6028') THEN 'Procedure' -- various ileo/colono/anoscopies
        WHEN hcpc.concept_code BETWEEN 'G6030' AND 'G6058' THEN 'Measurement' -- drug screening
        WHEN l2.str = 'Patient Documentation' THEN 'Observation' -- Level 2: G8126-G9140, mostly Physician Quality Reporting System (PQRS)
        WHEN hcpc.concept_code IN ('G9141', 'G9142') THEN 'Procedure Drug' -- Influenza a (h1n1) immunization administration
        WHEN hcpc.concept_code = 'G9143' THEN 'Measurement' -- Warfarin responsiveness testing by genetic technique using any method, any number of specimen(s)
        WHEN hcpc.concept_code = 'G9147' THEN 'Procedure Drug' -- Outpatient intravenous insulin treatment (oivit) either pulsatile or continuous, by any means, guided by the results of measurements for: respiratory quotient; and/or, urine urea nitrogen (uun); and/or, arterial, venous or capillary glucose; and/or potassi
        WHEN hcpc.concept_code IN ('G9148', 'G9149', 'G9150') THEN 'Observation' -- National committee for quality assurance - medical home levels 
        WHEN hcpc.concept_code IN ('G9151', 'G9152', 'G9153') THEN 'Observation' -- Multi-payer Advanced Primary Care Practice (MAPCP) Demonstration Project
        WHEN hcpc.concept_code = 'G9156' THEN 'Procedure' -- Evaluation for wheelchair requiring face to face visit with physician
        WHEN hcpc.concept_code = 'G9157' THEN 'Procedure' -- Transesophageal doppler measurement of cardiac output (including probe placement, image acquisition, AND interpretation per course of treatment) for monitoring purposes
        WHEN hcpc.concept_code BETWEEN 'G9158' AND 'G9186' THEN 'Observation' -- various neurological functional limitations documentations
        WHEN hcpc.concept_code = 'G9187' THEN 'Observation' -- Bundled payments for care improvement initiative home visit for patient assessment performed by a qualified health care professional for individuals not considered homebound including, but not limited to, assessment of safety, falls, clinical status, fluid
        WHEN hcpc.concept_code BETWEEN 'G9188' AND 'G9472' THEN 'Observation' -- various documentations
        WHEN hcpc.concept_code BETWEEN 'G9000' AND 'G9999' THEN 'Procedure' -- default for Medicare Demonstration Project
        WHEN l1.str = 'Temporary Procedures/Professional Services' THEN 'Procedure' -- default for all Level 1: G0000-G9999
        -- H codes
        WHEN hcpc.concept_code = 'H0003' THEN 'Measurement' -- Alcohol and/or drug screening; laboratory analysis of specimens for presence of alcohol and/or drugs
        WHEN hcpc.concept_code = 'H0030' THEN 'Observation' -- Behavioral health hotline service
        WHEN hcpc.concept_code = 'H0033' THEN 'Procedure Drug' -- Oral medication administration, direct observation
        WHEN hcpc.concept_code IN ('H0048', 'H0049') THEN 'Measurement' -- Alcohol screening
        WHEN hcpc.concept_code BETWEEN 'H0034' AND 'H2037' THEN 'Observation' -- various services
        WHEN l1.str = 'Behavioral Health and/or Substance Abuse Treatment Services' THEN 'Procedure' -- default for all Level 1: H0001-H9999
        -- J codes
        WHEN l1.str = 'J Codes - Drugs' THEN 'Procedure Drug' -- Level 1: J0100-J9999
        -- K codes
        WHEN l1.str = 'Temporary Codes Assigned to Durable Medical Equipment Regional Carriers' THEN 'Device' -- Level 1: K0000-K9999
        -- L codes 
        WHEN l1.str = 'L Codes' THEN 'Device' -- Level 1: L0000-L9999
        -- M codes
        WHEN hcpc.concept_code = 'M0064' THEN 'Observation' -- Brief office visit for the sole purpose of monitoring or changing drug prescriptions used IN the treatment of mental psychoneurotic AND personality disorders
        WHEN l1.str = 'Other Medical Services' THEN 'Procedure' -- Level 1: M0000-M0301
        -- P codes
        WHEN l2.str = 'Chemistry AND Toxicology Tests' THEN 'Measurement' -- Level 2: P2028-P2038
        WHEN l2.str = 'Pathology Screening Tests' THEN 'Measurement' -- Level 2: P3000-P3001
        WHEN l2.str = 'Microbiology Tests' THEN 'Measurement' -- Level 2: P7001-P7001
        WHEN l2.str = 'Miscellaneous Pathology AND Laboratory Services' THEN 'Procedure' -- Level 2: P9010-P9615
        -- Q codes
        WHEN l2.str = 'Cardiokymography (CMS Temporary Codes)' THEN 'Procedure' -- Level 2: Q0035-Q0035
        WHEN l2.str = 'Chemotherapy (CMS Temporary Codes)' THEN 'Procedure Drug' -- Level 2: Q0081-Q0085
        WHEN hcpc.concept_code = 'Q0090' THEN 'Procedure Drug' -- Levonorgestrel-releasing intrauterine contraceptive system, (skyla), 13.5 mg
        WHEN l2.str = 'Smear, Papanicolaou (CMS Temporary Codes)' THEN 'Procedure' -- Level 2: Q0091-Q0091, only getting the smear, no interpretation
        WHEN l2.str = 'Equipment, X-Ray, Portable (CMS Temporary Codes)' THEN 'Observation' -- Level 2: Q0092-Q0092, only setup
        WHEN l2.str = 'Laboratory (CMS Temporary Codes)' THEN 'Measurement' -- Level 2: Q0111-Q0115
        WHEN l2.str = 'Drugs (CMS Temporary Codes)' THEN 'Procedure Drug' -- Level 2: Q0138-Q0181
        WHEN l2.str = 'Miscellaneous Devices (CMS Temporary Codes)' THEN 'Device' -- Level 2: Q0478-Q0509
        WHEN l2.str = 'Fee, Pharmacy (CMS Temporary Codes)' THEN 'Procedure Drug' -- Level 2: Q0510-Q0515
        WHEN l2.str = 'Lens, Intraocular (CMS Temporary Codes)' THEN 'Device' -- Level 2: Q1003-Q1005
        WHEN l2.str = 'Solutions AND Drugs (CMS Temporary Codes)' THEN 'Procedure Drug' -- Level 2: Q2004-Q2052
        WHEN l2.str = 'Brachytherapy Radioelements (CMS Temporary Codes)' THEN '???' -- Level 2: Q3001-Q3001
        WHEN l2.str = 'Telehealth (CMS Temporary Codes)' THEN 'Observation' -- Level 2: Q3014-Q3014
        WHEN hcpc.concept_code IN ('Q3025', 'Q3026') THEN 'Procedure Drug' -- Injection, Interferon beta
        WHEN l2.str = 'Additional Drugs (CMS Temporary Codes)' THEN 'Procedure Drug' -- Level 2: Q3027-Q3028
        WHEN l2.str = 'Test, Skin (CMS Temporary Codes)' THEN 'Measurement' -- Level 2: Q3031-Q3031
        WHEN l2.str = 'Supplies, Cast (CMS Temporary Codes)' THEN 'Device' -- Level 2: Q4001-Q4051
        WHEN l2.str = 'Additional Drug Codes (CMS Temporary Codes)' THEN 'Procedure Drug' -- Level 2: Q4074-Q4082
        WHEN l2.str = 'Skin Substitutes (CMS Temporary Codes)' THEN 'Device' -- Level 2: Q4100-Q4149
        WHEN l2.str = 'Hospice Care (CMS Temporary Codes)' THEN 'Observation' -- Level 2: Q5001-Q5010
        WHEN l2.str = 'Contrast (CMS Temporary Codes)' THEN '???' -- Level 2: Q9951-Q9969
        WHEN hcpc.concept_code BETWEEN 'Q9970' AND 'Q9974' THEN 'Procedure Drug' -- various
        WHEN l2.str = 'Transportation/Setup of Portable Radiology Equipment' THEN 'Observation' -- Level 2: R0070-R0076
        WHEN l1.str = 'Q Codes - Temporary Codes Assigned by CMS' THEN 'Device' -- default for Level 1: Q0000-Q9999
        -- S codes AND T codes 
        WHEN hcpc.concept_code BETWEEN 'S0012' AND 'S0197' THEN 'Procedure Drug'
        WHEN hcpc.concept_code BETWEEN 'S0257' AND 'S0265' THEN 'Procedure'
        WHEN hcpc.concept_code BETWEEN 'S0201' AND 'S0354' THEN 'Observation' -- includes the previous
        WHEN hcpc.concept_code BETWEEN 'S0390' AND 'S0400' THEN 'Procedure'
        WHEN hcpc.concept_code = 'S0592' THEN 'Procedure' -- Comprehensive contact lens evaluation
        WHEN hcpc.concept_code BETWEEN 'S0500' AND 'S0596' THEN 'Device' -- lenses, includes the previous
        WHEN hcpc.concept_code BETWEEN 'S0601' AND 'S0812' THEN 'Procedure'
        WHEN hcpc.concept_code BETWEEN 'S1001' AND 'S1040' THEN 'Device'
        WHEN hcpc.concept_code BETWEEN 'S2053' AND 'S3000' THEN 'Procedure'
        WHEN hcpc.concept_code IN ('S3000', 'S3005') THEN 'Observation' -- Stat lab
        WHEN hcpc.concept_code BETWEEN 'S3600' AND 'S3890' THEN 'Measurement' -- various genetic tests AND prenatal screenings
        WHEN hcpc.concept_code BETWEEN 'S3900' AND 'S3904' THEN 'Procedure' -- EKG AND EMG
        WHEN hcpc.concept_code BETWEEN 'S3905' AND 'S4042' THEN 'Procedure' -- IVF procedures
        WHEN hcpc.concept_code BETWEEN 'S4981' AND 'S5036' THEN 'Procedure Drug' -- various
        WHEN hcpc.concept_code BETWEEN 'S5100' AND 'S5199' THEN 'Observation' -- various care services
        WHEN hcpc.concept_code BETWEEN 'S5497' AND 'S5571' THEN 'Procedure Drug' -- various Insulin pens etc.
        WHEN hcpc.concept_code BETWEEN 'S8032' AND 'S8092' THEN 'Procedure' -- various imaging
        WHEN hcpc.concept_code = 'S8110' THEN 'Measurement' -- Peak expiratory flow rate (physician services)
        WHEN hcpc.concept_code BETWEEN 'S8096' AND 'S8490' THEN 'Device'
        WHEN hcpc.concept_code BETWEEN 'S8930' AND 'S8990' THEN 'Procedure'
        WHEN hcpc.concept_code BETWEEN 'S8999' AND 'S9007' THEN 'Device'
        WHEN hcpc.concept_code BETWEEN 'S9015' AND 'S9075' THEN 'Procedure'
        WHEN hcpc.concept_code BETWEEN 'S9083' AND 'S9088' THEN 'Observation'
        WHEN hcpc.concept_code BETWEEN 'S9090' AND 'S9110' THEN 'Procedure'
        WHEN hcpc.concept_code BETWEEN 'S9117' AND 'S9141' THEN 'Observation' -- various services AND visits
        WHEN hcpc.concept_code = 'S9145' THEN 'Procedure' -- Insulin pump initiation, instruction IN initial use of pump (pump not included)
        WHEN hcpc.concept_code BETWEEN 'S9150' AND 'S9214' THEN 'Observation' -- Home management
        WHEN hcpc.concept_code BETWEEN 'S9325' AND 'S9379' THEN 'Procedure Drug' -- home infusions AND home therapy
        WHEN hcpc.concept_code BETWEEN 'S9381' AND 'S9433' THEN 'Observation'
        WHEN hcpc.concept_code BETWEEN 'S9434' AND 'S9435' THEN 'Device'
        WHEN hcpc.concept_code BETWEEN 'S9436' AND 'S9473' THEN 'Observations' -- various classes AND programs
        WHEN hcpc.concept_code = 'S9474' THEN 'Procedure' -- Enterostomal therapy by a registered nurse certified IN enterostomal therapy, per diem
        WHEN hcpc.concept_code BETWEEN 'S9475' AND 'S9485' THEN 'Observation' -- services
        WHEN hcpc.concept_code = 'S9529' THEN 'Procedure' -- Routine venipuncture for collection of specimen(s), single home bound, nursing home, or skilled nursing facility patient
        WHEN hcpc.concept_code BETWEEN 'S9490' AND 'S9810' THEN 'Procedure Drug' -- more home infusions AND injections
        WHEN hcpc.concept_code BETWEEN 'S9900' AND 'S9999' THEN 'Observation' -- more services, documentations, 
        -- T codes
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
        ELSE 'Procedure'
      END AS domain_id
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
   
UPDATE concept_stage c
   SET domain_id =
          (SELECT t.domain_id
             FROM t_domains t
            WHERE c.concept_code = t.concept_code);
			
UPDATE concept_stage cs
   SET domain_id =
          (SELECT domain_id
             FROM concept c
            WHERE     C.CONCEPT_CODE = CS.CONCEPT_CODE
                  AND C.VOCABULARY_ID = CS.VOCABULARY_ID)
 WHERE NVL(CS.DOMAIN_ID,'???') = '???' AND CS.VOCABULARY_ID = 'HCPCS';
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
     FROM (SELECT LONG_DESCRIPTION, SHORT_DESCRIPTION, HCPC FROM ANWEB_V2) UNPIVOT (DESCRIPTION
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
    ) int_rel WHERE NOT EXISTS
    (select 1 from concept_relationship_stage r where
        int_rel.root=r.concept_code_1
        and int_rel.concept_code_2=r.concept_code_2
        and int_rel.root_vocabulary_id=r.vocabulary_id_1
        and int_rel.vocabulary_id_2=r.vocabulary_id_2
        and r.relationship_id='Maps to'
    );

COMMIT;

--12 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;

--13 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;	

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script