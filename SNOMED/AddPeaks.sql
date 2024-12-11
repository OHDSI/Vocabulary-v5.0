CREATE OR REPLACE FUNCTION dev_snomed.AddPeaks ()
RETURNS VOID AS
$BODY$
BEGIN
	DROP TABLE IF EXISTS peak;
	CREATE UNLOGGED TABLE peak (
		peak_code TEXT, --the id of the top ancestor
		peak_domain_id VARCHAR(20), -- the domain to assign to all its children
		valid_start_date DATE, --a date when a peak with a mentioned Domain was introduced
		valid_end_date DATE, --a date when a peak with a mentioned Domain was deprecated
		levels_down INT, --a number of levels down in hierarchy the peak has effect. When levels_down IS NOT NULL, this peak record won't affect the priority of another peaks
		ranked INT, -- number for the order in which to assign the Domain. The more ranked is, the later it updates the Domain in the script.
		PRIMARY KEY (peak_code, valid_end_date)
	);

	--21.1.2 Fill in the various peak concepts
	INSERT INTO peak
	VALUES
		--Outdated
		--2014-Dec-18
		('218496004',			'Condition',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20170810', 'YYYYMMDD'),	NULL), -- Adverse reaction to primarily systemic agents
		('162565002',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Patient aware of diagnosis
		('418138009',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Patient Condition finding
		('405503005',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Staff member inattention
		('405536006',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Staff member ill
		('405502000',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Staff member distraction
		('398051009',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Staff member fatigued
		('398087002',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Staff member inadequately assisted
		('397976005',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Staff member inadequately supervised
		('162568000',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Family not aware of diagnosis
		('162567005',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Family aware of diagnosis
		('42045007', 			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Acceptance of illness
		('108329005',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Social context Condition
		('108252007',			'Measurement',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Laboratory procedures
		('118246004',			'Measurement',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Laboratory test finding' - child of excluded Sample observation
		('442564008',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Evaluation of urine specimen
		('64108007',			'Procedure',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Blood unit processing - inside Measurements
		('258666001',			'Unit',			TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20190211', 'YYYYMMDD'),	NULL), -- Top unit
		('243796009',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Situation with explicit context
		('420056007',			'Drug',			TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Aromatherapy agent
		('373873005',			'Drug',			TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Pharmaceutical / biologic product
		('313413008',			'Condition',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Calculus observation
		('162566001',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), --Patient not aware of diagnosis
		--('71388002', 			'Procedure',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Procedure
		('304252001',			'Procedure',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Resuscitate
		('304253006',			'Procedure',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150104', 'YYYYMMDD'),	NULL), -- DNR
		('297249002',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Family history of procedure
		('416940007',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Past history of procedure
		('183932001',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Procedure contraindicated
		('438833006',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Administration of drug or medicament contraindicated
		('410684002',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Drug therapy status
		('17636008', 			'Procedure',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Specimen collection treatments and procedures - - bad child of 4028908 Laboratory procedure
		('106237007',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Linkage concept
		('260667007',			'Device',		TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Graft
		('309298003',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), --Drug therapy observations

		--2014-Dec-31
		('369443003',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- bedpan
		('398146001',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- armband
		('272181003',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- clinical equipment and/or device
		('445316008',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- component of optical microscope
		('419818001',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- Contact lens storage case
		('228167008',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- Corset
		('42380001',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- Ear plug, device
		('1333003',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- Emesis basin, device
		('360306007',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- Environmental control system
		('33894003',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- Experimental device
		('116250002',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- filter
		('59432006',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- ligature
		('360174002',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- nabeya capsule
		('311767007',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- special bed
		('360173008',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- watson capsule
		('367561004',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150518', 'YYYYMMDD'),	NULL), -- xenon arc photocoagulator
		('226465004',			'Observation',  TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Drinks
		('419572002',			'Observation',  TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- alcohol agent, exception of drug
		('413674002',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20150104', 'YYYYMMDD'),	NULL), -- Body material
		--2015-Jan-04
		('304253006',			'Observation',  TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- DNR
		('105590001',			'Observation',  TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Substances
		('123038009',			'Specimen',  	TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Specimen
		('48176007',			'Observation',  TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Social context
		('272379006',			'Observation',  TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Events
		('260787004',			'Observation',  TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Physical object
		('362981000',			'Observation',  TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Qualifier value
		('363787002',			'Observation',  TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Observable entity
		('410607006',			'Observation',  TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Organism
		('419891008',			'Note Type',	TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20151009', 'YYYYMMDD'),	NULL), -- Record artifact
		('78621006',			'Observation',  TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Physical force
		('123037004',			'Spec Anatomic Site',	TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Body structure
		('118956008',			'Observation',  TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Body structure, altered from its original anatomical structure, reverted from 123037004
		('254291000',			'Observation',  TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20181107', 'YYYYMMDD'),	NULL), -- Staging / Scales
		('370115009',			'Metadata',  	TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Special Concept
		('308916002',			'Observation',  TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Environment or geographical location
		('413674002',			'Observation',  TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Body material

		--2015-Jan-19
		('80631005',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Clinical stage finding
		('281037003',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Child health observations
		('105499002',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Convalescence
		('301886001',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Drawing up knees
		('298304004',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Finding of balance
		('298339004',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Finding of body control
		('300577008',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Finding of lesion
		('298325004',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Finding of movement
		('427955007',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Finding related to status of agreement with prior finding
		('118222006',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- General finding of observation of patient
		('249857004',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Loss of midline awareness
		('300232005',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Oral cavity, dental and salivary finding
		('364830008',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Position of body and posture - finding
		('248982007',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Pregnancy, childbirth and puerperium finding
		('128254003',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Respiratory auscultation finding
		('397773008',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Surgical contraindication
		('386053000',			'Measurement',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20150311', 'YYYYMMDD'),	NULL), -- evaluation procedure
		('127789004',			'Measurement',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20150311', 'YYYYMMDD'),	NULL), -- laboratory procedure categorized by method
		('395557000',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Tumor finding
		('422989001',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Appendix with tumor involvement, with perforation not at tumor
		('384980008',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Atelectasis AND/OR obstructive pneumonitis of entire lung associated with direct extension of malignant neoplasm
		('396895006',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Endocrine pancreas tumor finding
		('422805009',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Erosion of esophageal tumor into bronchus
		('423018005',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Erosion of esophageal tumor into trachea
		('399527001',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Invasive ovarian tumor omental implants present
		('399600009',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Lymphoma finding
		('405928008',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Renal sinus vessel involved by tumor
		('405966006',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Renal tumor finding
		('385356007',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Tumor stage finding
		('13104003',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Clinical stage I
		('60333009',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Clinical stage II
		('50283003',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Clinical stage III
		('2640006',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Clinical stage IV
		('385358008',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Dukes stage finding
		('385362002',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- FIGO stage finding for gynecological malignancy
		('405917009',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Intergroup rhabdomyosarcoma study post-surgical clinical group finding
		('409721000',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- International neuroblastoma staging system stage finding
		('385389007',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Lymphoma stage finding
		('396532004',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Stage I: Tumor confined to gland, 5 cm or less
		('396533009',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Stage II: Tumor confined to gland, greater than 5 cm
		('396534003',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Stage III: Extraglandular extension of tumor without other organ involvement
		('396535002',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Stage IV: Distant metastasis or extension into other organs
		('399517007',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Tumor stage cannot be determined
		('67101007',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- TX category
		('385385001',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- pT category finding
		('385382003',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Node category finding
		('385380006',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Metastasis category finding
		('386702006',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Victim of abuse
		('95930005',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Victim of neglect
		('248536006',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Finding of functional performance and activity
		('37448008',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Disturbance in intuition
		('12200008',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Impaired insight
		('5988002',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Lack of intuition
		('1230003',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- No diagnosis on Axis I
		('10125004',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- No diagnosis on Axis II
		('51112002',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- No diagnosis on Axis III
		('54427008',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- No diagnosis on Axis IV
		('37768003',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- No diagnosis on Axis V
		('6811007',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Prejudice
		('405533003',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Adverse incident outcome categories
		('304252001',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Resuscitate
		('69449002',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Drug action
		('79899007',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Drug interaction
		('365858006',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Prognosis/outlook finding
		('444332001',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Aware of prognosis
		('444143004',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Carries emergency treatment
		('251859005',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Dialysis finding
		('422704000',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Difficulty obtaining contraception
		('217315002',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Onset of illness
		('162511002',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Rare history finding
		('300893006',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Nutritional finding
		('424092004',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Questionable explanation of injury
		('397745006',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), --Medical contraindication
		--2015-May-18
		('421967003',			'Drug',			TO_DATE('20150518', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- drug dose form
		('424387007',			'Drug',			TO_DATE('20150518', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- dose form by site prepared for
		('421563008',			'Drug',			TO_DATE('20150518', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- complementary medicine dose form
		--2015-Oct-09
		('419891008',			'Type Concept',	TO_DATE('20151009', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Record artifact

		--2015-Aug-17
		('46680005',			'Measurement',	TO_DATE('20150817', 'YYYYMMDD'),	TO_DATE('20170810', 'YYYYMMDD'),	NULL), -- Vital signs
		--2016-Mar-22
		('57797005',			'Procedure',	TO_DATE('20160322', 'YYYYMMDD'),	TO_DATE('20171024', 'YYYYMMDD'),	NULL), -- Termination of pregnancy
		--2017-Mar_14
		('225831004',			'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Finding relating to advocacy
		('134436002',			'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Lifestyle
		('386091000',			'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Finding related to compliance with treatment
		('424092004',			'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Questionable explanation of injury
		('749211000000106',	'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- NHS Sickle Cell and Thalassaemia Screening Programme family origin
		('91291000000109',	'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Health of the Nation Outcome Scale interpretation
		('900781000000102',	'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Noncompliance with dietetic intervention
		('784891000000108',	'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Injury inconsistent with history given
		('863811000000102',	'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Injury within last 48 hours
		('920911000000100',	'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Appropriate use of accident and emergency service
		('927031000000106',	'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Inappropriate use of walk-in centre
		('927041000000102',	'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Inappropriate use of accident and emergency service
		('927901000000101',	'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Inappropriate triage decision
		('927921000000105',	'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Appropriate triage decision
		('921071000000100',	'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Appropriate use of walk-in centre
		('962871000000107',	'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Aware of overall cardiovascular disease risk
		('968521000000109',	'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Inappropriate use of general practitioner service

		--2017-Aug-30
		('424122007',			'Observation',  TO_DATE('20170830', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- ECOG performance status finding

		--history:off
		--2017-Aug-25
		('7895008',			'Observation',  TO_DATE('20170825', 'YYYYMMDD'),	TO_DATE('20171116', 'YYYYMMDD'),	NULL), -- Poisoning caused by drug AND/OR medicinal substance
		('55680006',			'Observation',  TO_DATE('20170825', 'YYYYMMDD'),	TO_DATE('20171116', 'YYYYMMDD'),	NULL), -- Drug overdose
		('292545003',			'Observation',  TO_DATE('20170825', 'YYYYMMDD'),	TO_DATE('20171116', 'YYYYMMDD'),	NULL), -- Oxitropium adverse reaction --somehow it sneaks through domain definition above, so define this one separately
		--2017-Nov-16
		('698289004',			'Observation', 	TO_DATE('20171116', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Hooka whatever Observation  -- http://forums.ohdsi.org/t/hookah-concept/3515
		--2018-Feb-08
		--Azaribine, Pegaptanib sodium, Cutaneous aerosol, Pegaptanib, etc. - exclusion without nice hierarchy
		('373447009',			'Drug',			TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL),
		('416058004',			'Drug',			TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL),
		('387111009',			'Drug',			TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL),
		('423490007',			'Drug',			TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL),
		('1536005',			'Drug',			TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL),
		('386925003',			'Drug',			TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL),
		('126154004',			'Drug',			TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL),
		('61483006',			'Drug',			TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL),
		('373749006',			'Drug',			TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL),
		--2018-Oct-06
		('414916001',			'Condition',	TO_DATE('20181006', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Obesity

		--2018-Nov-07
		('254291000',			'Measurement',	TO_DATE('20181107', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Staging / Scales [AVOF-1295]
		--2019-Feb-11
		('118226009',			'Observation',  TO_DATE('20190211', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Temporal finding
		('418038007',			'Observation',  TO_DATE('20190211', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Propensity to adverse reactions to substance
		--2020-Mar-17
		('1240591000000102',  'Measurement',	TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Severe acute respiratory syndrome coronavirus 2 not detected
		('41769001',			'Condition',	TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20200428', 'YYYYMMDD'),	NULL), -- Disease suspected
		--2020-Nov-04
		('734539000',			'Drug',			TO_DATE('20201104', 'YYYYMMDD'),	TO_DATE('20210211', 'YYYYMMDD'),	NULL), -- Effector
		--2020-Nov-10
		('766739005',			'Drug',			TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Substance categorized by disposition
		--2020-Nov-24
		('397745006',			'Observation',  TO_DATE('20201124', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Medical contraindication
		('364108009',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Lymph node observable
		--2021-Oct-27
		('62305002',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Disorder of language
		('289161009',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Finding of appetite
		('309298003',			'Observation',  TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Drug therapy finding
		('271807003',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Eruption
		('402752000',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Dermatosis resulting from cytotoxic therapy
		('1240581000000104',  'Measurement',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Severe acute respiratory syndrome coronavirus 2 detected
		--2022-05-04
		('365726006',			'Condition',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Finding related to ability to process information accurately
		('365737007',			'Condition',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Finding related to ability to process information at normal speed
		('365748000',			'Condition',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Finding related to ability to analyze information
		('59274003',			'Condition',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Intentional drug overdose
		('401783003',			'Device',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Disposable insulin U100 syringe+needle
		('401826003',			'Device',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Hypodermic U100 insulin syringe sterile single use / single patient use 0.5ml with 12mm needle 0.33mm/29gauge
		('401830000',			'Device',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Hypodermic U100 insulin syringe sterile single use / single patient use 1ml with 12mm needle 0.33mm/29gauge
		('91723000', 			'Spec Anatomic Site',  TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Anatomical structure
		('284648005',			'Observation',  TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Dietary intake finding
		('911001000000101',	'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Serum norclomipramine measurement
		('288533004',			'Meas Value',TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Change values
		('782964007',			'Condition',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Genetic disease
		('237834000',			'Condition',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Disorder of stature
		('400038003',			'Condition',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Congenital malformation syndrome
		('162300006',			'Observation',  TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Unilateral headache
		('428264009',			'Observation',  TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Painful gait
		('905231000000103',	'Observation',  TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Imbalanced intake of fibre
		('896531000000104',	'Observation',  TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Imbalanced dietary intake of fat
		('735643002',			'Observation',  TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Short stature of childhood
		('948391000000106',	'Observation',  TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- O/E - antalgic gait
		('43528001',			'Observation',  TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Distomolar supernumerary tooth
		('163166004',			'Observation',  TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- O/E - tongue examined
		('231466009',			'Condition',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Acute drug intoxication
    --2023-09-14
		('81647003',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Increased serum protein level
		('5277004',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Urinary casts
		('719602003',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Radiologic finding of tumor invasion penetrating colonic serosa
		('102866000',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Abnormal urine
		('77386006',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Pregnancy
		('365636006',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Finding of blood group
		('167911000',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Bone marrow examination abnormal
		('365619003',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Finding of red blood cell morphology
		('397852001',			'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- V/Q - Ventilation/perfusion ratio
		('413347006',			'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Finding of American Society of Anesthesiologists physical status classification
		('881501000000104',	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Gross Motor Function Classification System for Cerebral Palsy level finding
		('61481000000106',	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- MACS for Children with Cerebral Palsy 4-18 years - Level I
		('61501000000102',	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- MACS for Children with Cerebral Palsy 4-18 years - Level II
		('61511000000100',	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- MACS for Children with Cerebral Palsy 4-18 years - Level III
		('61521000000106', 	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- MACS for Children with Cerebral Palsy 4-18 years - Level IV
		('1321791000000109',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgA detection result equivocal
		('1321771000000105',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgA detection result negative
		('1321761000000103',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgA detection result positive
		('1321781000000107',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgA detection result unknown
		('1321541000000108',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgG detection result positive
		('1321591000000103',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgG detection result equivocal
		('1321571000000102',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgG detection result negative
		('1321641000000107',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgG detection result unknown
		('1321631000000103',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgM detection result equivocal
		('1321561000000109',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgM detection result negative
		('1321551000000106',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgM detection result positive
		('1321581000000100',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgM detection result unknown
		('1324601000000106',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) RNA detection result positive*/
		('250520004',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Dairy food test finding
		('719724007',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Deoxyribonucleic acid of Campylobacter not detected
		('719707001',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Deoxyribonucleic acid of Salmonella not detected
		('251342007',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Dermatological test finding
		('790741000000104',	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Equivocal immunology finding
		('62117008',		  	'Measurement',	 TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Bacterial antibody increase, paired specimens
		('365408009',		 	'Measurement',	 TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- ECG waveform - finding
		('165009005',		 	'Measurement',	 TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Allergy testing - no reaction
		('1187035007',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Blood viscosity below reference range
		('298717003',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Finding of measures of thorax
		('34641000087106', 	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Hematology test outside reference range
		('366092004', 		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Eye measurements - finding
		('366158000', 		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Vascular measurements - finding
		('106200001', 		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Hematopoietic system finding
		('365861007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Finding of immune status
		('251440000',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Neuroelectrophysiology finding
		('860970003',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Normal eye proper
		('365853002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Imaging finding
		('404509004',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Large gram-negative coccobacilli*
		('123830001',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Bacteria morphologically consistent with Actinomyces spp*
		('723529006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Extracellular Gram-negative diplococcus*
		('734445005',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Gram-positive bacilli in chains*
		('734446006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Gram-positive bacilli in palisades*
		('61609004',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Gram-positive cocci in chains*
		('734444009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Gram-positive cocci in chains, clusters, and pairs*
		('70003006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Gram-positive cocci in clusters*
		('734447002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Intracellular Gram-negative diplococcus*
		('404510009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Large gram-negative rods*
		('404511008',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Large gram-positive rods*
		('442670009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Motile microorganism*
		('15173006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Rare organisms*
		('427824002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Small Gram-negative rods*
		('722945007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Androgen excess caused by drug
		('444138006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Speckled antinuclear antibody pattern*
		('124875007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Acquisition of new antigens
		('166165005',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Antibody studies normal
		('250247005',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Bite cells
		('124989003',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Cell center alteration
		('124978005',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Cell division alteration
		('124991006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Centriole alteration
		('124990007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Centrosphere alteration
		('365857001',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Child examination finding
		('301833004',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- CSU = no abnormality
		('124983002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Cytokinetic alteration
		('301120008',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Electrocardiogram finding
		('370351008',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Endoscopy finding
		('414253004',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Finding of cellular component of blood
		('168457008',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Gross pathology - NAD
		('450241000124104',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Gynecological examination normal
		('250537006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Histopathology finding
		('397918000',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Human leukocyte antigen type
		('444059002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Hypercholesterolemia well controlled
		('252097006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Hypersensitivity finding
		('395034001',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Immune complex observation
		('124877004',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Loss of isoantigens
		('124876008',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Loss of normal antigens
		('250429001',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Macroscopic specimen observation
		('444589003',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Malignant neoplasm detection during interval between recommended screening examinations
		('167940002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Marrow megakaryocyte increase
		('395538009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Microscopic specimen observation
		('385466000',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Minimum inhibitory concentration finding
		('723745006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Morphological description only, with differential diagnosis
		('85728002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Morphologic description only
		('732973003',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Morphologic diagnosis, additional studies required
		('15656008',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Morphologic diagnosis deferred
		('125112009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Morphology within normal limits
		('164716009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Neurological diagnostic procedure - normal
		('8821000175107',		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Neurovascular deficit
		('734878005',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Normal cellular hormonal pattern
		('289342000',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Normal CTG tracing
		('309162003',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Normal histology findings
		('719790009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Nucleic acid amplification not detected
		('124873000',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Plasma membrane antigenic alteration
		('124992004',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Polar body alteration
		('250435001',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Presence of cells
		('365687009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Presence of crystals - finding
		('365613002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Presence of hemoglobin - finding
		('124874006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Production of fetal antigens
		('442666001',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Reliable screening not possible due to prematurity of subject
		('107645002',  		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Size finding
		('106221001',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Genetic finding
		('365430005',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Finding of urine appearance
		('118228005',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Functional finding
	-- 2024-05-10
		('247619007',			'Condition',  	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'), 	NULL),  -- Thought finding

		--Relevant
		--Model Comp
		--history:on
		('138875005',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150104', 'YYYYMMDD'),	NULL), -- root
		('138875005',			'Metadata',  	TO_DATE('20150104', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- root
		--history:off
		('900000000000441003','Metadata',  	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- SNOMED CT Model Component

		--Clinical Finding
		('365873007',			'Gender',		TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Gender
		('307824009',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Administrative statuses
		('305058001',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Patient encounter status
		('118233009',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of activity of daily living
		('365854008',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- History finding
		('105729006',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Health perception, health management pattern
		('162408000',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Symptom description

		('124083000',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Urobilinogenemia
		('71922006',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Immune defect
		('413296003',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Depression requiring intervention
		('103020000',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Adrenarche
		('405729008',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hematochezia
		('300391003',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of appearance of stool
		('300393000',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of odor of stool
		('165816005',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- HIV positive
		('106019003',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of elimination pattern
		('72670004',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Sign
		--history:on
		('365605003',			'Measurement',	 TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20170810', 'YYYYMMDD'),	NULL), -- Body measurement finding
		('365605003',			'Observation',  TO_DATE('20170810', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Body measurement finding
		--history:off
		--history:on
		('448717002',			'Measurement',	 TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20170810', 'YYYYMMDD'),	NULL), -- Decline in Edinburgh postnatal depression scale score
		('448717002',			'Condition',	TO_DATE('20170810', 'YYYYMMDD'),	TO_DATE('20231013', 'YYYYMMDD'),	NULL), -- Decline in Edinburgh postnatal depression scale score
		--history:off
		--history:on
		('449413009',			'Measurement',	 TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20170810', 'YYYYMMDD'),	NULL), -- Decline in Edinburgh postnatal depression scale score at 8 months
		('449413009',			'Condition',	TO_DATE('20170810', 'YYYYMMDD'),	TO_DATE('20231013', 'YYYYMMDD'),	NULL), -- Decline in Edinburgh postnatal depression scale score at 8 months
		--history:off
		--history:on
		--TODO: Check this peak after mapping
		('441742003',			'Measurement',	 TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20170810', 'YYYYMMDD'),	NULL), -- Evaluation finding
		('441742003',			'Condition',	TO_DATE('20170810', 'YYYYMMDD'),	TO_DATE('20201104', 'YYYYMMDD'),	NULL), -- Evaluation finding
		('441742003',			'Measurement',	 TO_DATE('20201104', 'YYYYMMDD'),	TO_DATE('20201210', 'YYYYMMDD'),	NULL), -- Evaluation finding
		('441742003',			'Condition',	TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Evaluation finding
		--history:off
		('13197004',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Contraception

		('364721000000101',	'Measurement',	 TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- DFT: dynamic function test
		('365980008',			'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Tobacco use and exposure - finding
		('129843006',			'Observation',  TO_DATE('20170314', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Health management finding
		('118227000',			'Condition',	TO_DATE('20170810', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Vital signs finding
		('473010000',			'Condition',	TO_DATE('20171116', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hypersensitivity Condition
		('419199007',			'Observation',  TO_DATE('20170825', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Allergy to substance
		('365574009',			'Observation',  TO_DATE('20171116', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Life event finding
		--[AVOF-1295]
		('125123008',			'Measurement',	TO_DATE('20181107', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Organ Weight
		('125125001',			'Observation',  TO_DATE('20181107', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Abnormal organ weight
		('125124002',			'Observation',  TO_DATE('20181107', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal organ weight

		('366154003',  		'Observation',	TO_DATE('20190211', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Respiratory flow rate - finding
		('397731000',			'Race',			TO_DATE('20190827', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Ethnic group finding

		('365866002',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of HIV status
		('438508001',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Virus present

		('871000124102',		'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Virus not detected
		('426000000',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fever greater than 100.4 Fahrenheit
		('164304001',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - hyperpyrexia - greater than 40.5 degrees Celsius
		('163633002',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E -skin temperature abnormal
		('164294007',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - rectal temperature
		('164295008',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - core temperature
		('164300005',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - temperature normal
		('164303007',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - temperature elevated
		('164293001',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - groin temperature
		('164301009',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - temperature low
		('164292006',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - axillary temperature
		('275874003',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - oral temperature
		('315632006',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - tympanic temperature
		('274308003',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - hyperpyrexia
		('164285001',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - fever - general
		('164290003',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - method fever registered
		('162913005',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - rate of respiration

		('29164008',			'Condition',	TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Disturbance in speech
		('288579009',			'Condition',	TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Difficulty communicating
		('288576002',			'Condition',	TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Unable to communicate
		('229621000',			'Condition',	TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Disorder of fluency
		('365341008',			'Observation',  TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding related to ability to perform community living activities
		('365031000',			'Observation',  TO_DATE('20201124', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding related to ability to perform activities of everyday life
		('365242003',			'Observation',  TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding related to ability to perform domestic activities
		('129063003',			'Observation',  TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Instrumental activity of daily living
		('863903001',			'Observation',  TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Allergy to vaccine product

		('268935007',			'Condition',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- On examination - peripheral pulses right leg
		('268936008',			'Condition',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- On examination - peripheral pulses left leg
		('164399004',			'Observation',  TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - skin scar
		('165815009',			'Condition',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- HIV negative
		('365956009',			'Observation',  TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of sexual orientation

		('106028002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Musculoskeletal finding
		--history:on
		('65367001',			'Observation',  TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Victim status
		('65367001',			'Condition',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20150311', 'YYYYMMDD'),	NULL), -- Victim status
		('65367001',			'Observation',  TO_DATE('20150311', 'YYYYMMDD'),	TO_DATE('20170106', 'YYYYMMDD'),	NULL), -- Victim status
		('65367001',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Victim status
		--history:off
		('106132005',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Speech finding
		('248982007',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pregnancy, childbirth and puerperium finding
		('106089007',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Metabolic finding
		('714628002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Prediabetes
		('419026008',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Effect of exposure to physical force
		('300848003',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Mass of body structure
		('84452004',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hormone abnormality
		('299691001',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of blood, lymphatics and immune system
		('69328002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Distress
		('267038008',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Edema
		('65124004',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Swelling
		('276438008',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Swelling / lump finding
		('1157237004',		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Altered perception
		('25470001000004105',	'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cognitive impairment due to multiple sclerosis
		('386806002', 	 	'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Impaired cognition
		('423884000',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Repetitious behavior
		('26628009',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Disturbance in thinking
		('25786006',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Abnormal behaviour
		('112630007',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Abnormal facies
		('131148009',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bleeding
		('22253000',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pain
		('45352006',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Spasm
		('247348008',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Tenderness
		('48694002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Anxiety
		('102943000',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Personality change
		('113381000119100',  	'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Codependency
		('404640003',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dizziness
		('102957003',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Neurological finding
		('431950004',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bloodstream finding
		('118235002',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Eye / vision finding
		('106048009',		  	'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Respiratory finding
		('300577008',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of lesion
		('247441003', 		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Erythema
		('225552003', 		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Wound finding
		('246556002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Central nervous system finding
		('300862005',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Mass of body region
		('302292003',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of trunk structure
		('298314008', 		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding related to coordination / incoordination
		('248402002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- General finding of soft tissue
		('302293008',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of limb structure
		('298325004',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of movement
		('43029002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Abnormal posture
		('118254002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of head and neck region
		('361055000',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Misuses drugs
		('414252009',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of back
		('106030000',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Muscle finding
		('106129007',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Motor function behavior finding
		('816081007',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Extracellular fluid volume depletion
		('386617003',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Digestive system finding
		('8659000',			'Condition', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Ectopic production of endocrine substance
		('415531008',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Skin AND/OR mucosa finding
		('51178009',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Sudden infant death syndrome
		('39104002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Illness
		('248457000',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Rigor - symptom
		--history:on
		('48340000',			'Condition',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Incontinence
		('48340000',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Incontinence
		--history:off
		('165232002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Urinary incontinence
		('72042002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Incontinence of feces
		('1086911000119107',  'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Complete fecal incontinence
		('737585009',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Abulia
		('609555007',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Diastolic heart failure stage A
		('609556008',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Systolic heart failure stage A
		('277850002',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Diogenes syndrome
		('248279007',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Frailty
		('248548009',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Nocturnal dyspnea
		('247845000',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Specific fear
		('268637002',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Psychosexual dysfunction
		('272030005',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Syncope
		('271787007',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Collapse
		('63384009',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Distorted body image
		('29738008',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Proteinuria
		('61373006',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bacteriuria
		('274769005',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Albuminuria
		('53397008',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Biliuria
		('45154002',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Glycosuria
		('68600005',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hemoglobinuria
		('737176000',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hypermagnesuria
		('762434003',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hypomagnesuria
		('274783007',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Ketonuria
		('123769001',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Methemoglobinuria
		('48165008',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Myoglobinuria
		('10917810000001008',	'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Myoglobinuria
		('165517008',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Neutropenia
		('165518003',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Neutrophilia
		('50820005',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cytopenia
		('129647005',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hypoglobulinemia
		('119249001',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Agammaglobulinemia
		('119250001',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hypogammaglobulinemia
		('59828008',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hemolytic crisis
		('123770000',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Methemalbuminemia
		('89627008',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hyponatremia

		('3761000119104',  	'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hypotestosteronism
		('64088006',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hyperviscosity
		('47872005',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hypoviscosity
		('37097005',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Erythroblastosis
		('46049004',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Reticulocytosis
		('123806003',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bisalbuminemia
		('1162569002',  	'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Postoperative bacteremia
		('250243009',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dacrocytosis
		('373372005',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Histological grade finding
		('372048000',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pregnancy with abnormal glucose tolerance test
		('1156100006',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pregnancy with normal glucose tolerance test
		-- Joint stiffness
		('84445001',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('249912007',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('249917001',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('298241001',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('249915009',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('249914008',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('298232006',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('249913002',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('40144003',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('202510005',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('249918006',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('298231004',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('249916005',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),

		('300857009',  		'Condition', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Mass of urinary system structure
		('20154006',  		'Condition', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pneumatouria
		('300474003',  		'Condition', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of urine output
		('76023003',  		'Condition', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Impairment of urinary concentration

		('67374007',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Instability of joint
		('302690004',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Encopresis
		('416113008',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Disorder characterized by fever
		('103075007',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Humoral immune defect
		('42341009',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Agnosia
		('27206009',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Agraphia
		('102996009',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cryesthesia
		('32566006',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dysmetria
		('39051003',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Kernig's sign
		('70537007',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hegar's sign
		('9686009',  			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Goodell's sign
		('15311007',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Erichsen's sign
		('441461000',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Destot sign
		('44717005',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Chvostek sign
		('413814005',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Chadwick's sign
		('70651004',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Calkin's sign
		('82345001',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Brudzinski's sign

		('37057007',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Psychophysiologic disorder
		('386661006',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fever
		('48188009',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Azoospermia
		('162274004',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Visual symptoms
		('106134006',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Perception AND/OR perception disturbance
		('12479006',  		'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Compulsive behavior
		('301366005',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pain of truncal structure
		('309524007',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Mass pf trunk
		('724386005',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Lesion of genitalia
		('106102002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Abnormal urinary product
		('21639008',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hypervolemia
		('312087002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Disorder following clinical procedure
		('14760008',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Constipation
		('62315008',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Diarrhea
		('250411006',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bone marrow finding
		('76612001',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hypercoagulability state
		('302083008',			'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of Apgar score

		('260246004',  		    'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Visual acuity finding
		('302082003',  		    'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of birth length
		('307577005', 		    'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of Heaf test
		('395536008',		 	'Measurement',	 TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Surgical margin finding
		('1236949008',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of placental volume
		('249131000',  		    'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of amniotic fluid volume

		('705075002',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Able to see
		('719749006',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Able to see using assistive device
		('264786003',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Amsler chart finding
		('82132006',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal visual acuity
		('170728008',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Poor visual acuity
		('13164000',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Reduced visual acuity
		('264944004',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Visual acuity PL - accurate projection
		('264943005',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Visual acuity PL - inaccurate projection
		('422256009',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Counts fingers - distance vision
		('424348007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Difficulty seeing distant objects
		('277754002',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Ocular test distance as specified
		('45089002',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal vision
		('301979008',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of color vision
		('246638009',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Interference with vision
		('260296003',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Perceives light only
		('260295004',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Sees hand movements
		('427013000',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Alcohol consumption during pregnancy
		('424712007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Difficulty following postpartum diet
		('289750007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of involution of uterus
		('249211006',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Lochia finding
		('271880003',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- O/E - specified examination findings
		('371078007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of eating pattern
		('106131003',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Mood finding
		('58424009',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Overeating
		('248536006',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of functional performance and activity
		('827031005', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Site of injection normal
		('302288005',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal coordination
		('27086002',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal physical attitude
		('86678000',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal station
		('300561007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Genitourinary tract normal
		('364940007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Handedness finding
		('445327005',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal shape of extremity
		('301178004',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal venous return in limb vein
		('116329008',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of walking
		('764925004',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal lower limb movement and sensation and circulation
		('764924000',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal upper limb movement and sensation and circulation
		('736706004',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dentofacial function normal
		('246723000',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Ocular muscle balance normal
		('301924000',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal globe
		('840673007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Head normal
		('840674001',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal neck region
		('426792009',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cervical spine normal
		('300196000',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Ear normal
		('301225007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Larynx normal
		('364777007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Eating, feeding and drinking abilities - finding
		('365448001',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Social and personal history finding
		('79015004',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Worried
		('364734006',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Quality of construction of footwear - finding
		('129879003',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Parenting finding
		('1149345007', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Excessive weight gain during pregnancy
		('364826005', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding related to ability to perform breast-feeding
		('243826008', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Antenatal care status
		('116336009',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Eating / feeding / drinking finding
		('289159000',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Thirst finding
		('250869005',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Equipment finding
		('127362006',			'Observation',  TO_DATE('20160322', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Previous pregnancies
		('365449009',			'Observation',  TO_DATE('20230928', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Demographic history finding
		('373060007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Device status
		('108329005',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Social context finding
		('224959009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal physiological development
		('294854007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Allergy to albumin solution
		('107651007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Quantity finding
		('123978000',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Functional disorder not identified
		('299475005',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of temperature of foot
		('299902004',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of temperature sense
		('366718006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Joint temperature
		('225577002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Stoma finding
		('225580001',		  	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of stoma device
		('370994008',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Seizure free
		('365670007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Odor of specimen - finding
		('247950007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Sleep behavior finding
		('281459007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bending of spinal fixation device
		('1144566001',		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Managing to control withdrawal symptoms
		('365698005',  		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Organism growth - finding
		('278542003',  		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dental appliance or restoration finding
		('118192006',  		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding relating to self-concept
		('341000119102',		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Tattoo of skin
		--Piercing
		('698015006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('1281807004',		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('1260230003',		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('1260232006',		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('1260221006',		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('1260220007',		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('1260222004',		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('275530009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Amputee - limb
		('247522004',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hair finding
		('56709009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Target cell of immunologic reaction*
		('313424005',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- At increased risk of disease
		('70733008',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Limitation of joint movement
		('870752006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding related to health literacy
		('365949003',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Health-related behavior finding
		('1260078007',		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Maternal breastfeeding
		('471841000124105',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Analyte not reportable due to high human immunodeficiency virus antibody
		('93771000119109',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Diagnosis deferred
		('723663001',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Diagnosis not made
		('197411000000101',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Isolate finding
		('442689009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Nonmotile microorganism
		('66552009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- No tissue received
		('404523002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Organism not viable

		--Sample characteristics
		('281261001',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Sample container finding
		('125152006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Specimen satisfactory for evaluation
		('67736002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Specimen poorly fixed
		('373880007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Specimen rejected / not processed
		('397212007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('399606003',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('397206002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('372428000',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('105812000',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('7705008',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('73784008',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('397332005',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('397315006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('395528004',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('67135005',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('58178000',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('7667005',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('84567002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('54192004',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('63038006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('397879002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('43515008',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('103611008',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('281283002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('281282007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('281281000',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('840851000000100',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('281278005',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('281279002',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('281276009',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('168124002',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('118128002',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('118129005',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('118127007',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('281284008',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('281280004',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('281277000',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),

		('395028008',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Skin sample observation
		('125154007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Specimen unsatisfactory for evaluation
		('363171000000104',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Timed collection of specimen
		('842211000000104',	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Timed sample series
		('458471000124109',  	'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- High risk of adverse medication event
		('168452002',  		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Forensic examination normal
		('123828003',  		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fungal organisms morphologically consistent with Candida species
		('1149085006',  		'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Satisfied with management of pain
		('366636003',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Facial appearance finding
		('281457009',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Breakage of bone fixation device
		('6071000119100',		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Upper respiratory tract allergy
		('451321000124108',	'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Needs maximal assistance
		('451311000124100',	'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Needs moderate assistance
		('442076002',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Early satiety
		('716366009',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Requires continuous home oxygen supply
		('428264009',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Painful gait
		('236556004',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bloodstained peritoneal dialysis effluent
		('25911000175109',	'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Eyelid normal
		('413585005',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Aspiration into respiratory tract
		('364747001',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Presentation of fetus - finding
		('1231194004',		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal visual motion detection
		('1149054002',		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal reproductive system function
		('1260401008',		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Epiphyseal closure
		('1220629002',		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Impaired response to stem cell mobilization procedure
		('366140006',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Method of breathing - finding
		('118231006',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Communication finding
		('105721009',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- General problem AND/OR complaint
		('110302009',			'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Clenching teeth
		('714527000',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Decreased mandibular vestibule depth
		('714526009',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Decreased maxillary vestibular depth
		('789510003',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dental arch length loss
		('278655007',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dental center-line finding
		('110323003',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Distal step occlusion of primary dentition
		('698066001',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Edentulous interarch space limited
		('710011009',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Edentulous muscle attachment
		('289144006',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of food in mouth
		('709027003',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of location and extent of edentulous area of oral cavity
		('699749004',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Narrow mandibular arch form
		('699751000',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Narrow maxillary arch form
		('711635006',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal periapical tissue
		('714482007',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal periodontal tissue
		('609433001',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hypersensitivity disposition
		('301346001',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of appearance of lip
		('1209208002', 		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pale face
		('59901004',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cheek biting
		('711292003',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Decrease of chin to throat length
		('711291005',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Increase of chin to throat length
		('710781009',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Deep mentolabial sulcus
		('737034006',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Obtuse nasolabial angle
		('471397004',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Long lower third of face
		('699440004',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Long middle third of face
		('767358005',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Shallow mentolabial sulcus
		('73595000',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Stress
		('106126000',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Emotional state finding
		('42688000',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Preoccupation of thought
		('1177022006',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Colonization of respiratory tract with Pneumocystis jirovecii
		('127325009',  		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Procedure related finding
		('30693006', 			'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Aerophagy
		('1217022005', 		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Colonization of genitourinary tract by Streptococcus agalactiae
		('283021003', 		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Mobile tooth
		('86569001', 			'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Postpartum state
		('248727005', 		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Venous finding
		('298180004', 		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of range of joint movement
		('252041008', 		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Micturition finding
		('36456004',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Mental state finding
		('118244001',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding by percussion
		('247700009',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal perception
		('102500002',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Good neonatal Condition at birth
		('297976006',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of temperature of skin
		--history: on
		('106146005',			'Condition', 	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Reflex finding
		('106146005',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Reflex finding
		--history: off
		('299956006',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal sensation
		('5271000124101', 	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal cranial nerves
    	('398018000',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Inadequate anesthetic assessment
		('1156330008',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal respiratory system
		('106098005',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Urinary system finding
		('366256008',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 	NULL),  --Finding of bowel action

		--history:on
		('710954001',			'Measurement',	 TO_DATE('20200317', 'YYYYMMDD'),	TO_DATE('20220504', 'YYYYMMDD'),	NULL), -- Bacteria present
		('710954001',			'Condition',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Bacteria present
		('710954001',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Bacteria present
		('710954001',			'Measurement',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bacteria present
		--history:off
		--history:on
		('284530008',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20160322', 'YYYYMMDD'),	NULL), -- Communication, speech and language finding
		('284530008',			'Observation',  TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20211027', 'YYYYMMDD'),	NULL), -- Communication, speech and language finding
		('284530008',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Communication, speech and language finding
		--history:off
		('83507006',			'Condition',  	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 	NULL),  -- Delusions
		('387712008',			'Condition',  	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 	NULL),  -- Neonatal jaundice
		('1295289001',			'Condition',  	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 	NULL),  -- Maternal perinatal jaundice
		('78164000',			'Condition',  	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 	NULL),  -- Feeding problem
		('289906003',			'Condition',  	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 	NULL),  -- Female genital tract problem
		('18523001',			'Observation',	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Nudity
		('299698007',			'Observation',	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Feeding poor
		('1269562006',			'Observation',	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- At increased risk for postpartum disorder
        -- history:on
		('366147009',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Respiratory measurements - finding
		('366147009',  		'Condition',	 TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Respiratory measurements - finding
        --history: off

        -- history:on
		('1322901000000109',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antibody detection result indeterminate
		('1322901000000109',  'Condition',	     TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antibody detection result indeterminate
		('1322911000000106',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antibody detection result unknown
		('1322911000000106',  'Condition',	     TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antibody detection result unknown
		('1322801000000101',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result indeterminate
		('1322801000000101',  'Condition',	     TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result indeterminate
		('1322791000000100',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result negative
		('1322791000000100',  'Condition',	     TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result negative
		('1322781000000102',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result positive
		('1322781000000102',  'Condition',	     TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result positive
		('1322821000000105',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result unknown
		('1322821000000105',  'Condition',	     TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result unknown
        --history: off

		('118188004',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of neonate
		('366334007',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Condition of amniotic fluid - finding
		('406122000',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Head finding
		('1402001',			    'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fear
		('301113001',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of heart rate
		('366255007',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Swallowing pattern - finding
		('88111009',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Altered bowel function
		('298378000',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of neck region
		('297268004',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Ear, nose and throat finding
		('118952005',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Joint finding
		('301097002',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of right ventricle
		('30473006',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pain in pelvis
		('82423001',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Chronic pain
		('21522001',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Abdominal pain
		('274667000',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Jaw pain
		('300856000',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Mass of urogenital structure
		('309529002',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Lung mass
		('76039005',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Disturbance of attention
		('271840007',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Abnormal feces
		('300284004',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of esophagus
		('279055000',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Obstetric pain
		('366373007',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Facial skeletal pattern - finding
		('195675009',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cardiac akinesia
		('37706002',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hypokinesis of cardiac wall
		('168603006',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Plain X-ray of pelvis normal
		('301830001',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Urine finding
		('112623001',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Mottling
		('301257008',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Respiratory finding of chest
		('87486003',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Aphasia
    --history: on
		('118242002',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Finding by palpation
		('118242002',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding by palpation
    --history: off
		('413347006',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of American Society of Anesthesiologists physical status classification
		('881501000000104',		'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Gross Motor Function Classification System for Cerebral Palsy level finding

		('364986009',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding related to ability to perform functions for speech
		('364936003',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding related to ability to control posture
		('364739001',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fetal gestation at delivery - finding
		('301338002',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of head circumference
		('28487002',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of arrangement of fetus
		('385348009',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Breslow depth finding for melanoma
		('289761004',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of cervical dilatation
		('289824002',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of measures of cervix
		('200144004',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Deliveries by cesarean
		('271607001',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Excessive hair growth
		('247308000',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of conductivity of sound
		('248878009',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Vaginal wall finding
		('278040002',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Loss of hair
		('60862001',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Tinnitus
		('162349004',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Noises in ear
		('289826000',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of device of cervix
		('105501005',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dependence on enabling machine or device
		('289568008',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of vaginal liquor
		('118180006',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding related to amniotic fluid function
		('416822007',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of movement of sacrum
		('298181000',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Range of joint movement increased
		('366258009',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding related to awareness of bowel function
		('366420008',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Peripheral reflex finding
		('250004004',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Peripheral skeletomuscular gait disorder
		('366308004',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Galant's reflex finding
		('366251003',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Anal sphincter tone - finding
		('449368009',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Stopped smoking during pregnancy
		('722494001',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Nicotine user
-- Evaluation Findings:
		--history: on
		('118245000',			'Measurement',	 TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Measurement finding
		('118245000',			'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measurement finding
		--history:off
		('250373003',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Blood transfusion finding
		('250228007',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Red blood cell finding
		('37253000',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Decreased osmotic fragility
		('165543009',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Immature white blood cells
		('89327000',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Increased heme-heme interaction
		('75083006',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Increased osmotic fragility
		('250356000',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Thrombotic tendency observations
		('365633003',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Platelet morphology - finding
		('414660003',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Megakaryocyte finding
		('30257002',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Abnormal fibrinolysis
		('365634009',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Anticoagulant control - finding
		('365627007',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- White blood cell age - finding
		('165107009',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- FAst metabolic rate
		('165108004',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Slow metabolic rate
		('396701002',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of serum tumor marker level
		('310254004',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bone densimetry abnormal
		('449781000',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bone density below reference range
		('102962002',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Abnormal evoked potential
		('250311007',		    'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Platelet finding
		('276993008',		    'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Evoked potential finding
		('49727002',		    'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cough
		('365856005',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Screening finding
		('722945007',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Androgen excess caused by drug
		('48364004',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Circumlocution
		('112089001',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Comprehension dysprosody
		('288446006',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Difficulty performing writing activities
		('288608007',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Difficulty using the elements of language
		('102938007',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Difficulty writing
		('64712007',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Echolalia
		('44515000',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Perseveration
		('127388009',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hypergammaglobulinemia
		('129650008',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hyperalphaglobulinemia
		('129651007',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hyperbetaglobulinemia
		('129646001',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hyperglobulinemia
		('129232009',			'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Analbuminemia
		('605091',			    'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Genetic susceptibility to malignant hyperthermia due to ryanodine receptor 1 gene mutation
		('605904',			    'Condition',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Genetic susceptibility to malignant hyperthermia due to calcium voltage-gated channel subunit alpha1 S gene mutation

		--history: on
		('251399004',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Lactose tolerance
		('251399004',			'Condition',    TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Lactose tolerance
		('417186004',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Precipitous drop in hematocrit
		('417186004',			'Condition',    TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Precipitous drop in hematocrit
		('409683007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Stable hematocrit
		('409683007',			'Condition',    TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Stable hematocrit
		('870578004',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Persistent abnormal electrolytes
		('870578004',			'Condition',    TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Persistent abnormal electrolytes
		('300361008',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Vomit contains blood
		('300361008',			'Condition', 	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	0), -- Vomit contains blood
		('365648009',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'), 	NULL),  --Blood compatibility - finding
		('365648009',			'Condition',    TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 	NULL),  --Blood compatibility - finding
		('366219004',  		    'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Tendency to bleed - finding
		('366219004',  		    'Condition', 	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Tendency to bleed - finding
		('365705006',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Antimicrobial susceptibility - finding*
		('365705006',			'Condition',    TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Antimicrobial susceptibility - finding*
		('365855009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Biopsy finding
		('365855009',			'Condition',    TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Biopsy finding
		('118207001',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Finding related to molecular conformation
		('118207001',			'Condition',    TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding related to molecular conformation
		('719756000',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Hemosiderin laden macrophages seen
		('719756000',			'Condition',    TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hemosiderin laden macrophages seen
		('72724002',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Morphology findings
		('72724002',			'Condition',    TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Morphology findings
		('23506009',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Normal flora
		('23506009',			'Condition',    TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Normal flora


		('442703001',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Aspiration test negative for air during procedure
		('442703001',			'Measurement',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Aspiration test negative for air during procedure
		('442718000',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Aspiration test negative for blood during procedure
		('442718000',			'Measurement',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Aspiration test negative for blood during procedure
		('442710007',			'Observation',  TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Aspiration test negative for cerebrospinal fluid during procedure
		('442710007',			'Measurement',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Aspiration test negative for cerebrospinal fluid during procedure
		--history:off
		('165583001',			'Measurement',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- International normalized ratio outside reference range
		('1156263003',			'Measurement',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of fibrinolysis time
		('250327000',			'Measurement',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Blood coagulation pathway finding
		('165563002',			'Measurement',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Coag./bleeding tests abnormal
		('250412004',			'Measurement',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dipstick test finding
		('445184006',			'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding related to cerebrospinal fluid
		('406115008',			'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Syphilis test finding
		('151271000119102',		'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Abnormal blood test
		('106200001',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hematopoietic system finding
		('413680005',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bone marrow iron finding
		('251406000',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Breath test finding
		('251409007',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- GU test finding
		('304597009',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Helicobacter blood test finding
		('307371007',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Helicobacter CLO test observations
		('406108000',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Human immunodeficiency virus enzyme-linked immunosorbent assay test positive
		('406109008',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Human immunodeficiency virus not detected by enzyme-linked immunosorbent assay
		('165825004',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Infectious titer not detected in blood
		('250421003',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pregnancy test finding
		('365600008',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Rheumatoid factor level - finding
		('315010001',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Polymerase chain reaction observation
		('365427003',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Semen measurement - finding
		('365426007',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of spermatozoa number
		('365713007',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Synovial fluid cell count - finding
		('365709000',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Methylene blue reduction - finding
		('298014004',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of Mantoux test
		('165509000',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- White blood cell count outside reference range
		('897034005',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 antibody detected
		('412730000',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Genetic finding not detected
		('445333001',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Breast cancer genetic marker of susceptibility detected
		('441844008',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Delayed hypersensitivity skin test for histoplasmin negative
		('441814005',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Delayed hypersensitivity skin test for histoplasmin positive
		('412731001',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Genetic finding detected
		('450361000124105',		'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Parasite not detected
		('446394004',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Microbial culture finding
		('365789002',			'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Calculus chemical composition - finding
		('365585006',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Specific antibody level - finding
		('251342007',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dermatological test finding
		('785672002',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of urine substance level
		('366148004',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Respiratory volume - finding
		('897035006',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 antibody not detected
		('1321641000000107',	'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgG detection result unknown
		('47340003',			'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Birth weight finding
		('365665000',			'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- CSF appearance - finding
		('372046001',			'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Glucose tolerance test during pregnancy, childbirth and puerperium outside reference range
		('165014009',		 	'Measurement',	 TO_DATE('20230927', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Allergy test positive
	--Antibody detected
		('1335898006',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('1335900008',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('1335893002',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('1335899003',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),
		('1335903005',		    'Measurement',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),

		('34898007',		    'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bacterial colony morphology
		('106133000',		    'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Language finding
		('609625009',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Finding of pelvic region of trunk
		('609625009',			'Condition', 	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding of pelvic region of trunk
		--history: off
		--history: on
		('365690003',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Presence of organism - finding
		('365690003',  		'Measurement',  TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Presence of organism - finding
		--history: on

		--Context-dependent
		('395098000',			'Condition',	TO_DATE('20200518', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Disorder confirmed
		('443938003',			'Observation',  TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Procedure carried out on subject

		--Disorder
		--history:on
		('282100009',			'Observation',  TO_DATE('20170825', 'YYYYMMDD'),	TO_DATE('20171116', 'YYYYMMDD'),	NULL), -- Adverse reaction caused by substance
		('282100009',		'Observation',  TO_DATE('20180820', 'YYYYMMDD'),	TO_DATE('20241023', 'YYYYMMDD'),	NULL), -- Adverse reaction caused by substance
		--history:off
		('28926001',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Eruption due to drug
		('402752000',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dermatosis resulting from cytotoxic therapy
		('407674008',			'Condition',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Aspirin-induced asthma
		('10628711000119101',	'Condition',	TO_DATE('20171116', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Allergic contact dermatitis caused by plant (this is only one child of 419199007 Allergy to substance that has exact Condition mentioned
		('424909003',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Toxic retinopathy
		('312963001',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Methanol retinopathy
		('82545002',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Blood transfusion reaction
		('234992005',			'Condition',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Plasma cell gingivitis
		('418634005',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20240510', 'YYYYMMDD'),	NULL), -- Allergic reaction to substance

		('64572001',			'Condition', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Disease
		('193570009',			'Condition', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cataract
		('238986007',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Chemical-induced dermatological disorder
		('702809001',			'Condition', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Drug reaction with eosinophilia and systemic symptoms
		('422593004',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Acute renal failure due to ACE inhibitor

		('232032008', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Drug-induced retinopathy
		('448177004',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Adverse drug interaction
		('294842007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hematological agents allergy
		--history:on
		('62014003',			'Condition',	TO_DATE('20170810', 'YYYYMMDD'),	TO_DATE('20180820', 'YYYYMMDD'),	NULL), -- Adverse reaction to drug
		('62014003',			'Observation',  TO_DATE('20180820', 'YYYYMMDD'),	TO_DATE('20201110', 'YYYYMMDD'),	NULL), -- Adverse reaction to drug
		--history: off
		('956271000000104',	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Aliskiren allergy
		('1104821000000102',  'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Allergy to diagnostic dye
		('201551000000109',	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Allergy to plasters
		('956291000000100',	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Prasugrel allergy
		('956311000000104',	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Ticagrelor allergy	--Location
		('325651000000108',	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Contact allergy
		('275322007',			'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Scar
		('281647001',			'Observation',  TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Adverse reaction
		('20558004',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Adverse effect of radiation therapy
		('403753000',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Adverse cutaneous reaction to acupuncture
		('402763002',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Adverse cutaneous reaction to diagnostic procedure
		('56317004',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Alopecia
		('112401000119106',	'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Lesion of conjunctiva
		('15250008',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Disorder of cornea
		('402150002',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Insect bite reaction

		('419076005',			'Condition',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Allergic reaction

		('39579001',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Anaphylaxis
		('724817003',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Disorder of nervous system following procedure
		('205237003',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pneumonitis
		('400088006',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Scarring alopecia
		('302215000',			'Condition',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Thrombocytopenic disorder

		('292045009',			'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Opioid analgesic adverse reaction
		('10851141000119101',	'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Adverse reaction caused by psychotropic
		('402169007',	        'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Scar due to and following procedure

		--Location
		--history:on
		('43741000',			'Place of Service',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20210217', 'YYYYMMDD'),	NULL), -- Site of care
		('43741000',			'Visit',		TO_DATE('20210217', 'YYYYMMDD'),	TO_DATE('20240131', 'YYYYMMDD'),	NULL), -- Site of care
		('43741000',			'Observation',	TO_DATE('20240131', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Site of care
		--history:off
		('223496003',			'Geography',	TO_DATE('20210217', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Geographical and/or political region of the world

		--Observable Entity
		('46680005',			'Measurement',	 TO_DATE('20150817', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Vital signs
		('364712009',			'Measurement',	 TO_DATE('20150817', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Laboratory test observable

		('310611001',			'Measurement',	 TO_DATE('20170830', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cardiovascular measure
		('248627000',			'Measurement',	 TO_DATE('20171116', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pulse characteristics

		('251880004',			'Measurement',	 TO_DATE('20181107', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Respiratory measure [AVOF-1295]

		('1145214003',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Histologic feature of proliferative mass
		('246464006',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Function
		('28263002',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Crying
		('364665006',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Ability to perform function / activity

		('364678006',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Neuromuscular blockade observable
		('364681001',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Waveform observable
		('373629008',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Capillary carbon dioxide tension
		('364048003',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Respiratory observable
		('364080001',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Feature of left ventricle
		('364081002',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Feature of right ventricle
		('364309009',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Duration measure of menstruation
		('373063009',			'Measurement',	 TO_DATE('20201130', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Substance observable
		('364644000',			'Measurement',	 TO_DATE('20201130', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Functional observable
		('364566003',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of joint
		('364684009',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Body product observable
		('364711002',			'Measurement',	 TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Specific test feature
		('396277003',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fluid observable
		('386725007',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Body temperature
		('434912009',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Blood glucose concentration
		('934171000000101',	'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Blood lead level
		('934191000000102',	'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Blood lead level
		('1107241000000102',  'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Calcium substance concentration in plasma adjusted for albumin
		('1107251000000104',  'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Calcium substance concentration in serum adjusted for albumin
		('434910001',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Interstitial fluid glucose concentration
		('395527009',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Microscopic specimen observable
		('246116008',			'Measurement',	 TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Lesion size
		('439260001',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Thromboelastography observable
		('364362002',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Obstetric investigative observable
		('364200006',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of urination
		('1240461000000109',  'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measurement of Severe acute respiratory syndrome coronavirus 2 antibody
		('364575001',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bone observable
		('804361000000106',	'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bone density scan due date
		('405043008',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bone healing status
		('364576000',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Form of bone
		('364577009',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Movement of bone
		('703489001',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Anogenital distance
		('246792000',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Eye measure
		('364499003',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of lower limb
		('364313002',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of menstruation
		('364036001',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of nose
		('364247002',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of vagina
		('364259003',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of uterus
		('364278003',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of gravid uterus
		('364467009',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of upper limb
		('364276004',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of uterine contractions
		('364292009',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of cervix
		('364295006',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of ovary
		('364486001',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of hand
		('364519002',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of foot
		('397274003',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Exophthalmometry measurement
		('363978004',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of lacrimation
		('363939003',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of globe
		('248326004',			'Measurement',	 TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Body measure
		('302132005',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- American Society of Anesthesiologists physical status class
		('250808000',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Arteriovenous difference
		('364097007',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Feature of pulmonary arterial pressure
		('399048009',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Main pulmonary artery peak velocity
		('252091007',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Distal vessel patency
		('364679003',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Intracerebral vascular observable
		('398992002',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pulmonary vein feature
		('251191008',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cardiac axis
		('251131006',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- AH interval
		('251127000',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Effective refractory period
		('251132004',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- HV interval
		('251133009',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Wenckebach cycle length
		('408719002',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cardiac end-diastolic volume
		('408718005',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cardiac end-systolic volume
		('364077002',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Characteristic of heart sound
		('399137004',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Feature of left atrium
		('364082009',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Heart valve feature
		('364067004',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cardiac investigative observable
		('399231008',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cardiovascular orifice observable
		('364071001',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cardiovascular shunt feature
		('364068009',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- ECG feature
		('371846000',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pulmonary valve flow
		('397417004',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Regurgitant flow
		('399301000',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Regurgitant fraction
		('396238001',			'Measurement',	 TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Tumor measureable
		('371508000',			'Measurement',	 TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Tumour stage
		('249948009',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Grade of muscle power
		('364574002',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of skeletal muscle
		('364580005',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Musculoskeletal measure
		('252124009',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Test distance
		('434911002',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Plasma glucose concentration
		('935051000000108',	'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Serum adjusted calcium concentration
		('399435001',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Specimen measurable
		('102485007',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Personal risk factor
		('250430006',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Color of specimen
		('115598002',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Consistency of specimen
		('314037008',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Serum appearance
		('412835001',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Calculus appearance
		('250434002',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Odor of specimen
		('250822000',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Inspiration/expiration time ratio
		('250811004',			'Measurement',	 TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Minute volume
		('397504000',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Organ AND/OR tissue microscopically involved by tumor
		('371509008',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Status of peritumoral lymphocyte response
		('404977008',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Skeletal functioning status
		('364055001',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Respiratory characteristics of chest
		('404988002',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Respiratory gas exchange status
		('404996007',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Airway patency status
		('75098008', 			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Flow history
		('400987003',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Asthma trigger
		('364053008',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Characteristic of respiratory tract function
		('364049006',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Lower respiratory tract observable
		('366874008',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Number of asthma exacerbations in past year
		('723245007',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Number of chronic obstructive pulmonary disease exacerbations in past year
		('364062005',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Respiration observable

		('871562009',			'Measurement',	 TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Detection of Severe acute respiratory syndrome coronavirus 2
		('1240471000000102',  'Measurement',	 TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measurement of Severe acute respiratory syndrome coronavirus 2 antigen
		('80943009', 			'Measurement',	 TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Risk factor

		('263605001',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Length dimension of neoplasm
		('4370001000004107',  'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Length of excised tissue specimen
		('443527007',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Number of lymph nodes containing metastatic neoplasm in excised specimen
		('396236002',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Depth of invasion by tumour
		('396239009',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Horizontal extent of stromal invasion by tumour
		('371490004',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Distance of tumour from anal verge
		('258261001',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Tumour volume
		('371503009',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Tumour weight
		('444916005',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Percentage of carcinoma in situ in neoplasm
		('444775005',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Average intensity of positive staining neoplastic cells
		('385404000',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Tumour quantitation
		('405930005',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Number of tumour nodules
		('385300008',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Linear extent of involvement of carcinoma
		('444025001',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Number of lymph nodes examined by microscopy in excised specimen
		('444644009',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Number fraction of oestrogen receptors in neoplasm using immune stain
		('445366002',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Number fraction of progesterone receptors in neoplasm using immune stain
		('399514000',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Distance of anterior margin of tumour base from limbus of cornea at cut edge, after sectioning
		('396988001',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Distance of posterior margin of tumour base from edge of optic disc, after sectioning
		('405921002',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Percentage of tumour involved by necrosis
		('396987006',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Distance from anterior edge of tumour to limbus of cornea at cut edge, after sectioning
		('786458005',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Self reported usual body weight
		('409652008',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Population statistic
		('165109007',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Basal metabolic rate
		('7928001',  			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Body oxygen consumption
		('698834005',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Metabolic equivalent of task
		('251836004',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Nitrogen balance
		('16206004', 			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Oxygen delivery
		('251831009',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Oxygen extraction ratio
		('251832002',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Oxygen uptake
		('74427007', 			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Respiratory quotient
		('251838003',			'Measurement',	 TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Total body potassium

		('871560001',			'Measurement',	 TO_DATE('20230712', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Detection of ribonucleic acid of severe acute respiratory syndrome coronavirus 2 using polymerase chain reaction (observable entity)
		('363870007',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Mental state, behavior / psychosocial function observable
		('1099121000000104',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Young Townson FootSkin Hydration Scale for Diabetic Neuropathy level
		('865939009',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Active insulin time
		('872121000000100',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Frequency of hyperglycaemic episodes
		('712656006',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Frequency of hypoglycemia attack
		('789480007',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Insulin dose
		('736101003',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Insulin infusion rate
		('789496005',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Insulin to carbohydrate ratio
		('874181000000108',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Time since last hyperglycaemic episode
		('442547005',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Number of alcohol units consumed on heaviest drinking day
		('228330005',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Total time drunk alcohol
		('228329000',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Time since stopped drinking
		('103208001',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Erythrocyte sedimentation rate
		('417595002',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cell feature
		('165581004',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- International normalized ratio
		('368481000000103',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bowel cancer screening programme: faecal occult blood result
		('364465001',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Size of upper limb
		('299220001',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Leg size
		('249363002',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Adenoids size
		('364032004',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Size of nose
		('364231004',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Size of vagina
		('364224003',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Size of vulval structure
		('248944004',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Uterus size
		('248913008',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Uterine cervix size
		('248955004',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Ovary size
		('364472000',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Size of clavicle
		('364470008',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Size of scapula
		('363953003',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Size of pupil
		('363937001',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Size of globe
		('422149008',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Optic disc size
		('249050003',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fetus size
		('364616001',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of fetus
		('251682005',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fetal kick count
		('249046005',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Number of fetal hearts heard
		('363983007',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Visual acuity
		('311528003',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Visual scanning speed
		('251794006',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Refraction
		('246648006',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Visual image size
		('423083007',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Glaucoma hemifield test
		('419862005',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Accommodative amplitude
		('251837008',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Total body water
		('364333003',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of labor
		('364564000',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Range of joint movement
		('364286003',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Adenoids size
		('364539003',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of skin
		('264752007',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Grading values
		('1285654008',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Identification of bacteria by matrix assisted laser desorption ionization time of flight mass spectrometry
		('363891000119100',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Identification of bacteria in sputum by culture
		('1285667006',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Identification of fungus by matrix assisted laser desorption ionization time of flight mass spectrometry
		('365931000119109',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Identification of organism in respiratory smear by Gram stain
		('365971000119107',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Identification of organism in smear by Gram stain
		('372431000119101',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Identification of organism in wet smear by potassium hydroxide preparation
		('375771000119100',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Identification of ova and parasites in fecal smear by concentration and trichrome stain
		('143481000237106',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fluid chemistry observable
		('143471000237109',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Microbiology laboratory observable
		('1290195007',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Detection of antibody to infective organism
		('4401000237103',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Mass concentration ratio of immunoglobulin G antibody to albumin in cerebrospinal fluid
		('143441000237100',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Clinical chemistry observable
		('164835000',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Limb length
		('106054005',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Lung volume AND/OR capacity
		('70337006',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cardiovascular function
		('11953005',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Renal function
		('130953005',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Rate of urine output, function
		('985791000000107',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Total fluid estimated need
		('364400009',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Feature of fluid loss
		('1179058006',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Estimated quantity of intake of fluid
		('364399002',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of fluid intake
		('1465031000000109',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Number of clinically significant hypoglycaemic episodes recorded by point-of-care monitoring of capillary blood glucose
		('1597861000000105',  'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Number of suspend episodes in insulin pump greater than 60 minutes
		('143541000237101',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Urinalysis observable
		('2661000237108',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Transferrin saturation index (Iron saturation/transferrin percent) in serum
		('50851000237104',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- RBCs (red blood cells) in blood smear microscopy qualitative result
		('65201000237103',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fungal precipitin in serum qualitative result
		('50571000237109',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fungal precipitin in plasma qualitative result
		('58601000237101',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Unconjugated E2 (oestradiol) molar concentration in serum
		('50401000237102',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Leucocytes in mid-stream urine microscopy qualitative result
		('50761000237108',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pus cells in mid-stream urine microscopy qualitative result
		('51311000237102',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- RBCs (red blood cells) in mid-stream urine microscopy qualitative result
		('51761000237101',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hyaline casts in mid-stream urine microscopy qualitative result
		('66641000237105',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgM antibody in serum qualitative result
		('54591000237103',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Reticulated platelet percent count in blood
		('55461000237109',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Eosin 5-maleimide labelled red blood cells control MFI (mean fluorescence intensity) in blood
		('55511000237106',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- NK (natural killer) T lymphocyte percent count in blood
		('58481000237107',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Ethyl sulphate mass concentration in hair
		('6961000237104',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Catecholamine molar concentration in 24 hr urine
		('58041000237107',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Prostate health index
		('54031000237108',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Metamyelocyte percent count in blood
		('52641000237100',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Naive B lymphocyte percent count in blood
		('53291000237102',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Medium RNA reticulocyte percent count in blood
		('51151000237100',  	'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Clue cells in high vaginal swab microscopy qualitative result
		('396631001',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Icterus index ordinal value in serumSurgical margin observable
		('364671000',  		'Measurement',	 TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dialysis observable
		('13861000237103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Normirtazepine mass concentration in plasma
		('1241000237101',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Sexual abstinence duration
		('3041000237109',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Dopamine molar concentration in 24 hr urine
		('27921000237101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --HMMA (4-hydroxy-3-methoxymandelic acid)/creatinine molar concentration ratio in urine
		('49921000237109',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Blood group O+ RBC (red blood cell O antigen and Rhesus D antigen positive) in plasma qualitative result
		('50171000237102',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --RhD- blood group (Rhesus D antigen negative red blood cell) in plasma qualitative result
		('50601000237104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Blood group A+ RBC (red blood cell A antigen positive and Rhesus D antigen positive) in plasma qualitative result
		('51071000237108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Blood group AB+ RBC (red blood cell A and B antigen positive and Rhesus D antigen positive) in plasma qualitative result
		('51891000237104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Blood group O- RBC (red blood cell O positive and Rhesus D antigen negative) in plasma qualitative result
		('57541000237101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Noradrenaline molar concentration in urine
		('59481000237100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Blood group AB- RBC (red blood cell A and B antigen positive and Rhesus D antigen negative) in plasma qualitative result
		('66241000237108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Blood group B+ RBC (red blood cell B antigen positive and Rhesus D antigen positive) in plasma qualitative result
		('68691000237103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Complement C3 nephritic factor presence in plasma
		('143451000237102',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Coagulation laboratory observable
		('143461000237104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Fertility testing observable
		('143531000237108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Toxicology laboratory observable
		('568331000005101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Intake of nutritional supplement
		('375911000119106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Differential count of white blood cells by automated method
		('15141000237109',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Red blood cell count in fluid
		('55881000237104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Promyelocyte percent count in blood
		('52251000237104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Blood group B- RBC (red blood cell B antigen positive and Rhesus D antigen negative) in plasma qualitative result
		('49941000237104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Epithelial cells in mid-stream urine microscopy qualitative result
		('567951000005106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Certainty of estimated date of delivery
		('630001000004109',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Presence of metastatic discontinuous spread of malignant neoplasm of colon to pericolic tissue
		('3381000237101',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Glycophorin count percent in plasma
		('56091000237100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Small bowel biopsy weight in small intestine specimen
		('62921000237106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Blood group A- RBC (red blood cell A antigen positive and Rhesus D antigen negative) in plasma qualitative result
		('56881000237106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Collagen/adrenaline closure time in blood
		('57031000237104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Methylglutarylcarnitine molar concentration in plasma
		('57591000237109',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Eosin 5-maleimide labelled red blood cells control MFI (mean fluorescence intensity) in blood
		('60841000237107',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --RhD+ blood group (Rhesus D antigen positive red blood cell) in plasma qualitative result
		('2381000237106',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Immature reticulocyte percent in blood
		('1464821000000102',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of time below level 2 hypoglycaemic threshold to total continuous glucose monitoring time using minimally-invasive continuous glucose monitoring device
		('2541000237108',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Lambda cells percent in serum
		('2601000237109',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Oxcarbazepine metabolite mass concentration in serum
		('2991000237107',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Kappa cells percent in serum
		('3181000237104',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Platelet distribution width percent in blood
		('3741000237106',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --HVMA (homovanillylmandelic acid) molar concentration in 24 hr urine
		('11861000237102',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Oestradiol molar concentration in plasma
		('3771000237102',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Keratin arbitrary concentration in serum
		('31000237108',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Number of days abstinence prior to semen sample production
		('391000237102',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Eicosatrienoic acid molar concentration in serum
		('16151000237103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Normirtazepine mass concentration in serum
		('16181000237107',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --White blood cell count in fluid
		('611000237104',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Smear cells percent in blood
		('4081000237100',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Platelet/neutrophil count ratio in blood
		('4331000237102',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Alpha amino butyrate molar concentration in serum
		('1281000237107',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Free beta HCG (human chorionic gonadotropin) multiple of the median in serum
		('52931000237101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Switched memory B lymphocyte percent count in blood
		('53001000237101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Non-switched memory B lymphocyte percent count in blood
		('53031000237105',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --MCVr (mean cell volume of reticulocytes) in blood
		('53281000237104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Transitional B lymphocyte percent count in blood
		('53931000237106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Euglobulin clot lysis time time in blood
		('54451000237105',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Turbidity index
		('54711000237100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Metamyelocyte count in blood
		('54871000237100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Patient height
		('55161000237100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Blast cell percent count in bone marrow
		('55471000237104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Naive T lymphocyte percent count in blood
		('55491000237100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Patient weight
		('56101000237106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Low RNA reticulocyte percent count in blood
		('56231000237108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --7-Aminonitrazepam mass concentration in oral fluid
		('56411000237103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Blast cell percent count in blood
		('56551000237100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Eosin 5-maleimide labelled red blood cells MFI (mean fluorescence intensity) in blood
		('56661000237103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Thiocyanate molar concentration in serum
		('56801000237103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Plasmablasts percent count in blood
		('57381000237103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --High RNA reticulocyte percent count in blood
		('57711000237107',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Reticulocyte percent count in blood
		('57731000237101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Haemolysis index
		('58051000237105',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Plasma cells percent count in bone marrow aspirate
		('67561000237109',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Carbonate and phosphate percent calculus content
		('67821000237101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --ADAMTS13 (disintegrin and metalloproteinase with thrombospondin type 1 motif 13) enzyme activity in plasma
		('67921000237109',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Calculus weight
		('1290531000000106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Monkeypox virus qualitative result
		('1340001000004103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Number of metastatic discontinuous tumor deposits of primary malignant neoplasm of colon
		('1730561000004108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Presence of metastatic discontinuous spread of primary malignant neoplasm
		('1833121000000106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Wound, Ischemia and foot Infection classification system Wound grade
		('25761000237100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --sFlt-1 (soluble fms-like tyrosine kinase 1)/PlGF (placental growth factor) mass concentration ratio in serum
		('143381000237103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Allergy clinical laboratory observable
		('376201000119106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Differential count of white blood cells by manual method
		('1464671000000104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Mean substance concentration of glucose in capillary blood using minimally-invasive continuous glucose monitoring device
		('1464731000000106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Mean substance concentration of glucose in capillary blood by self-monitoring of blood glucose using blood glucose meter
		('1464741000000102',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Standard deviation of mean substance concentration of glucose in capillary blood using minimally-invasive continuous glucose monitoring device
		('1464751000000104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Standard deviation of mean substance concentration of glucose in capillary blood by self-monitoring of blood glucose using blood glucose meter
		('1464761000000101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Coefficient of variation of mean substance concentration of glucose in capillary blood using minimally-invasive continuous glucose monitoring device
		('1464771000000108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Coefficient of variation of mean substance concentration of glucose in capillary blood by self-monitoring of blood glucose using blood glucose meter
		('1464781000000105',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of time in target glucose range to total glucose monitoring time using minimally-invasive continuous glucose monitoring device
		('1464791000000107',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of time above level 2 hyperglycaemic threshold to total continuous glucose monitoring time using minimally-invasive continuous glucose monitoring device
		('1464801000000106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of time above level 1 hyperglycaemic threshold to total continuous glucose monitoring time using minimally-invasive continuous glucose monitoring device
		('1464831000000100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of time below level 1 hypoglycaemic threshold to total continuous glucose monitoring time using minimally-invasive continuous glucose monitoring device
		('1464841000000109',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of readings in target range to total self-monitored capillary blood glucose readings using blood glucose meter
		('1853701000000102',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Wound, Ischemia and foot Infection classification system Ischemia grade
		('1853711000000100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Wound, Ischemia and foot Infection classification system foot Infection grade
		('1853721000000106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Wound, Ischemia and foot Infection classification system stage
		('2040001000004100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Presence of DNA mismatch repair protein Mlh1 in primary malignant neoplasm of colon by immunohistochemistry
		('2060001000004105',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Presence of tumor bud in primary malignant neoplasm of colon
		('3550001000004108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Presence of receptor tyrosine-protein kinase erbB-2 in primary malignant neoplasm of breast by immunohistochemistry
		('3980001000004105',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Radial location of primary malignant neoplasm in excised breast specimen
		('4050001000004108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Status of progesterone receptor stain in control cells by immunohistochemistry
		('26421000237108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Docosanoate (C22) molar concentration in plasma
		('26901000237105',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Pyridinium crosslinks molar concentration in serum
		('1003521000004104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Number of tumor buds in primary malignant neoplasm of colon in microscopic field 0.785 mm2
		('1030001000004100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Site of excised primary malignant neoplasm of rectosigmoid colon relative to peritoneal reflection
		('1049601000000108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Number of weeks attendance of weight management programme
		('1577281000000108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Fredericson magnetic resonance imaging bone stress injury classification grade
		('1597771000000108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Mean time between replacement of continuous subcutaneous insulin infusion catheter in days
		('1597781000000105',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Mean time between replacement of insulin infusion patch pump in days
		('1597801000000106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of successful data capture time to total expected wear time of insulin pump
		('1597811000000108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of time in closed loop to total expected wear time of continuous automated insulin delivery system
		('1597871000000103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of time spent by insulin pump in manual suspend
		('1597881000000101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of time spent by continuous automated insulin delivery system in low glucose suspend
		('1597891000000104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of time spent by continuous automated insulin delivery system in predictive low glucose suspend
		('6270001000004106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Presence of ulcer in primary malignant melanoma of skin
		('30121000237100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Neurokinin A molar concentration in plasma
		('43871000237100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Plasmodium falciparum antigen arbitrary concentration in serum
		('46051000237109',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Nucleated red blood cells percent in blood
		('50451000237101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Semen viscosity qualitative result
		('551791000124104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Superior transverse sacral axis motion
		('551801000124103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Longitudinal sacral axis motion
		('568121000005101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Irregular blood group antibody observable
		('568131000005103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Rhesus antibody observable
		('568161000005105',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Maternal pre-pregnancy alcoholic beverage intake
		('591201000124109',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Severe acute respiratory syndrome coronavirus 2 vaccination status
		('591251000124108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Oblique sacral axis motion
		('1464851000000107',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of readings above level 2 hyperglycaemic threshold to total self-monitored capillary blood glucose readings using blood glucose meter
		('1464861000000105',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of readings above level 1 hyperglycaemic threshold to total self-monitored capillary blood glucose readings using blood glucose meter
		('1464871000000103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of readings below level 2 hypoglycaemic threshold to total self-monitored capillary blood glucose readings using blood glucose meter
		('1464881000000101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of readings below level 1 hypoglycaemic threshold to total self-monitored capillary blood glucose readings using blood glucose meter
		('1464891000000104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Glucose Management Indicator expressed as substance concentration ratio
		('1464901000000103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Number of clinically significant hypoglycaemic episodes recorded by self-monitoring of capillary blood glucose
		('1464911000000101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Number of clinically significant hypoglycaemic episodes recorded by continuous glucose monitoring device
		('1464921000000107',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Mean duration of hypoglycaemic episodes in minutes
		('1464931000000109',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Mean number of self-monitored capillary blood glucose measurements per day
		('1464941000000100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of successful data capture time to total expected continuous glucose monitoring sensor wear time using minimally-invasive continuous glucose monitoring device
		('1464951000000102',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Mean substance concentration of glucose in capillary blood using point-of-care testing device
		('1464961000000104',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Standard deviation of mean substance concentration of glucose in capillary blood using point-of-care testing device
		('1464971000000106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Coefficient of variation of mean substance concentration of glucose in capillary blood using point-of-care testing device
		('1464981000000108',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of readings in target range to total point-of-care capillary blood glucose readings using blood glucose meter
		('1464991000000105',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of readings above level 2 hyperglycaemic threshold to total point-of-care capillary blood glucose readings using blood glucose meter
		('1465001000000103',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of readings above level 1 hyperglycaemic threshold to total point-of-care capillary blood glucose readings using blood glucose meter
		('1465011000000101',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of readings below level 2 hypoglycaemic threshold to total point-of-care capillary blood glucose readings using blood glucose meter
		('1465021000000107',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of readings below level 1 hypoglycaemic threshold to total point-of-care capillary blood glucose readings using blood glucose meter
		('1465041000000100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Mean number of point-of-care capillary blood glucose measurements per day
		('1505281000000106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Estimated quantity of carbohydrate intake in grams during breakfast meal
		('1515521000000109',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Estimated quantity of carbohydrate intake in grams during lunch meal
		('1515531000000106',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Estimated quantity of carbohydrate intake in grams during evening meal
		('1515541000000102',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Estimated quantity of carbohydrate intake in grams during snack time
		('1515591000000107',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Insulin sensitivity factor - snack time
		('1515761000000107',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentage of continuous glucose monitoring sensor failures to total sensors applied recorded by subject of record
		('1546631000004100',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Presence of direct invasion by primary malignant neoplasm of prostate to nerve
		('5381000237102',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Immature platelet fraction percent in blood
		('5541000237100',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Alternative (AP100) complement pathway haemolytic activity percent in serum
		('6381000237107',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Reactive lymphocyte percent in blood
		('6411000237109',		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Calculated serum osmolarity molar concentration in serum

		('363884002',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Recognition observable
		('6769007',  			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Attention
		('311718005',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cognitive discrimination
		('363885001',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Characteristic of intellect
		('312012004',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cognitive function: awareness
		('311534005',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Conceptualization
		('247583006',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Decision making
		('311507007',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Executive cognitive functions
		('870552008',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Health literacy
		('311544007',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Information processing
		('27026000',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Insight
		('247572002',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Intellect
		('22851009',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Intelligence
		('311841007',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Intelligibility
		('85721008',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Intuition
		('61909002',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Language
		('69998004',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Intelligibility
		('363886000',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Learning observable
		('312016001',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Metacognition
		('43173001',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Orientation
		('81742003',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Perception
		('71565002',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Personality
		('247581008',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Problem solving
		('311545008',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Processing accuracy
		('311546009',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Processing capacity
		('304685003',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Processing speed
		('307081003',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Spatial awareness
		('311552005',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Spatial orientation
		('698829006',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Straightforward decision making
		('88952004',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Thinking
		('311505004',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Visual processing
		('363871006',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Mental state
		('363910003',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Characteristic of psychosocial functioning
		('363887009',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Memory observable
		('363896009',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Behavior observable
		('364287007',  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Feature of consistency of cervical mucous
	--2024-05-10
		('1010511000000108', 'Measurement',  TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Serum T4 level
		('372461000119109',	'Measurement',  TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Lactate in blood
		('246214002',		'Measurement',  TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Number of neoplasms in excised tissue specimen
		('1287180006',		'Measurement',  TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Percentage of primary malignant neoplasm of prostate with Gleason histologic pattern 4
		('1268771007',		'Measurement',  TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Presence of Helicobacter pylori in stool
		('249606000',		'Measurement',  TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Prostate size
		('364351000119103',	'Measurement',  TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Detection of Streptococcus pneumoniae antigen in urine
		('1290323003',		'Measurement',  TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Glaucoma stage
		('374451000119101',	'Measurement',  TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Rheumatoid factor in serum
		('1144301005',		'Measurement',  TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measured quantity of intake of protein and/or protein derivative in 24 hours

		('364324000',		'Measurement',  TO_DATE('20241013', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measure of pregnancy

		-- Physical Object
		('303624006',  		'Device', 		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Musculoskeletal device
		('303620002',  		'Device', 		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Urogenital device
		('360009006',  		'Device', 		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pressure garments
		('272179000',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Domestic, office and garden artifact
		('705620005',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Floor mat
		('456151000124107',	'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Foreign body
		('80519002',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hospital furniture, device
		('312201009',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Instrument of aggression
		('50833004',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Paper
		('303491000',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Personal effects and clothing
		('278211009',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Printed material
		('261324000',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Vehicle
		('709280007',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Walking surface of room
		('61284002',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Machine
		('105799003',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Household device
		('40188005',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Household accessory
		('698101006',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Smoking device
		('129464000',  		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Medical administrative equipment

		--Pharma/Biol Product
		--history:on
		('373783004',			'Observation',  TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20190418', 'YYYYMMDD'),	NULL), -- dietary product, exception of Pharmaceutical / biologic product
		('373783004',			'Device',		TO_DATE('20190418', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- dietary product, exception of Pharmaceutical / biologic product
		--history:off
		--history:on
		('49062001', 			'Device',		TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20141231', 'YYYYMMDD'),	NULL), -- Device
		('49062001', 			'Device',		TO_DATE('20150518', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Device
		--history:off
		('763087004',			'Drug',			TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Medicinal product categorized by therapeutic role
		('2949005',  			'Device',  		TO_DATE('20150518', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- diagnostic aid
		('410652009',			'Device',		TO_DATE('20171128', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Blood product [AVOF-731]
		('709080004',			'Observation',	TO_DATE('20180821', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Diagnostic allergen product
		('407935004',			'Device',		TO_DATE('20190418', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Contrast media
		('768697005',			'Device',		TO_DATE('20190418', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Barium and barium compound product -- contrast media subcathegory
		('116178008',			'Device',		TO_DATE('20190418', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dialysis fluid
		('327838005',			'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Intravenous nutrition
		('226311003',			'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dietary fiber supplementation
		('411115002',			'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Drug-device combination product
		('12222501000001106', 'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Virtual radiopharmaceutical moiety
		('736542009',			'Drug',  		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Pharmaceutical dose form
		('763158003',			'Drug',  		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Medicinal product

		--Procedure
		--history:on
		('122869004',			'Measurement',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), --Measurement
		('122869004',			'Measurement',	TO_DATE('20150311', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Measurement
		--history:off
		--history:on
		('113021009',			'Procedure',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20150119', 'YYYYMMDD'),	NULL), -- Cardiovascular measurement
		('113021009',			'Procedure',	TO_DATE('20150311', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cardiovascular measurement
		--history:off
		('14734007',			'Observation',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Administrative procedure

		('429159005',			'Procedure',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Child psychotherapy
		('15220000', 			'Measurement',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Laboratory test
		('225365006',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Care regime
		('309466006',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Clinical observation regime
		('225318000',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Personal and environmental management regime
		('133877004',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Therapeutic regimen
		('225367003',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Toileting regime
		('308335008',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Patient encounter procedure
		('225288009',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Environmental care procedure
		('239516002',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Monitoring procedure
		('389084004',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Staff related procedure
		('228114008',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Child health procedures
		('389067005',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Community health procedure
		('59524001',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Blood bank procedure
		('243114000',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Support
		('372038002',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Advocacy
		('110461004',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Adjunctive care
		('303163003',			'Observation',	TO_DATE('20150119', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Treatments administered under the provisions of the law

		('278414003',			'Procedure',	TO_DATE('20160616', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pain management
		('363259005',			'Observation',	TO_DATE('20160616', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Patient management procedure

		('268444004',			'Measurement',	TO_DATE('20181107', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Radionuclide red cell mass measurement

		('108246006',			'Measurement',	TO_DATE('20191113', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Tonometry AND/OR tonography procedure
		('61746007', 			'Measurement',	TO_DATE('20200312', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Taking patient vital signs
		('117617002',			'Measurement',	TO_DATE('20200428', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Immunohistochemistry procedure
		('404933001',			'Measurement',	TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Berg balance test
		--history: on
		('1321161000000104',  'Visit',		TO_DATE('20200518', 'YYYYMMDD'),	TO_DATE('20240131', 'YYYYMMDD'),	NULL), --Household quarantine to prevent exposure of community to contagion
		('1321161000000104',  'Observation',	TO_DATE('20240131', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Household quarantine to prevent exposure of community to contagion
		('1321151000000102',  'Visit',		TO_DATE('20200518', 'YYYYMMDD'),	TO_DATE('20240131', 'YYYYMMDD'),	NULL), --Reverse self-isolation of uninfected subject to prevent exposure to contagion
		('1321151000000102',  'Observation',	TO_DATE('20240131', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Reverse self-isolation of uninfected subject to prevent exposure to contagion
		('1321141000000100',  'Visit',		TO_DATE('20200518', 'YYYYMMDD'),	TO_DATE('20240131', 'YYYYMMDD'),	NULL), --Reverse isolation of household to prevent exposure of uninfected subject to contagion
		('1321141000000100',  'Observation',	TO_DATE('20240131', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Reverse isolation of household to prevent exposure of uninfected subject to contagion
		('1321131000000109',  'Visit',		TO_DATE('20200518', 'YYYYMMDD'),	TO_DATE('20240131', 'YYYYMMDD'),	NULL), --Self quarantine and similar
		('1321131000000109',  'Observation',	TO_DATE('20240131', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Self quarantine and similar
		--history: off

		('20135006', 			'Measurement',	TO_DATE('20210127', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Screening procedure

		('59000001', 			'Procedure',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Surgical pathology consultation and report on referred slides prepared elsewhere

		('373110003',			'Procedure',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Emergency procedure
		('118292001',			'Procedure',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Removal
		('128967005',			'Procedure',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Exercise challenge
		('91251008', 			'Procedure',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Physical therapy procedure
		('711540006', 		'Procedure',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- MRI of breast for screening
		('31687009', 			'Procedure',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Multiphasic screening procedure
		('444783004', 		'Procedure',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Screening colonoscopy
		('24623002', 			'Procedure',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Screening mammography
		('3421000175104',  	'Procedure',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Video screen time assessment
		('472824009', 	 	'Procedure',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fetal echocardiography screening
		('716035006', 	 	'Procedure',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Scintimammography for malignant neoplasm screening
		('88884005', 			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Alpha-1-antitrypsin phenotyping
		('851211000000105',	'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Assessment of sedation level
		('37859006', 			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pulmonary ventilation perfusion study
		('30058000', 			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Therapeutic drug monitoring assay
		('441967009',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Evaluation of cerebrospinal fluid
		('104145007',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hemoglobin electrophoresis
		('430509005',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Examination of fluid specimen
		('401289003',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Methicillin resistant Staphylococcus aureus screening test
		('413063005',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Acinetobacter species screening test
		('395142003',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Allergy screening test
		('401300000',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Atypical pneumonia screening test
		('252144003',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Biochemical test
		('164790002',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Breath test
		('400984005',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Congenital hypothyroidism screening test
		('391898007',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fetal oxytocin stress test
		('269817005',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Glucose-6-phosphate dehydrogenase test
		('395059005',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hemoglobinopathy screening test
		('391541008',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Glandular fever screening test
		('425732004',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hemorrhagic fever virus serology screening test
		('394981005',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- HEp-2 cell autoantibody screening test
		('391513009',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- ICT malaria screening test
		('108253002',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Laboratory test panel
		('314094003',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Lupus anticoagulant screening test
		('395118002',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Metabolic screening test
		('252243002',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pancreatic function test
		('442220001',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Progesterone withdrawal test
		('52424002',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Provocative test
		('395056003',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Rotavirus screening test
		('314098000',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Rubella screening test
		('53309004',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Skin test
		('15695009',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Stimulation test
		('50947004',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Suppression test
		('314089003',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Thrombophilia screening test
		('391364009',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Toxoplasma screening test
		('395057007',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Trichomonas screening test
		('395161004',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Triple screening test
		('840285005',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Vestibular evoked myogenic potential test
		('401129008',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- von Willebrand screening test
		('408268003',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- 24 hour Bence-Jones screening test
		('413013000',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- 24 hour urine screening for urinary stone formation measurement
		('164961002',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Physiological function tests
		('252567006',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Sleep latency test
		('164807004',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Special female genital test
		('164822009',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Special male genital test
		('164814002',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Postcoital test
		('252222003',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Gastrointestinal tract function test
		('167252002',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20240510', 'YYYYMMDD'),	NULL), -- Urine pregnancy test
		('252801000',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Ophthalmological test
		('445536008',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Assessment using assessment scale
		('250221001',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Detection of hemoglobin
		('42106004',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Capillary fragility test
		('252468003',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Digital rewarming test
		('840707001',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Allen test for arterial competency
		('252441003',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Buerger's test
		('31724009',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Measurement of venous pressure
		('21727005',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Audiometric test
		('77667008',			'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Therapeutic drug monitoring, qualitative
		('183452005',			'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Emergency hospital admission
		('183851006',			'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Referral to clinic
		('105396008',			'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Visit of patient by chaplain
		('699823003', 		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Provision of written information
		('229252009', 		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Active joint movements
		('84478008', 	 		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Occupational therapy
		('12799001', 	 		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Physiotherapy class activities
		('409073007', 		'Observation',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Education
		('252314007',  		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Blood transfusion test
		('16830007',  		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Visual acuity testing
		('441813004',  		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Evaluation of peritoneal fluid
		('446428008',  		'Measurement',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Evaluation of musculoskeletal system
		('252758009',  		'Procedure', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Electromyography of anal sphincter
		('284393006',  		'Procedure', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Examination of joint
		('363119001',  		'Procedure', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Exploration of musculoskeletal system
		('441958009',  		'Procedure', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Imaging of musculoskeletal system
		('107739004',  		'Procedure', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Musculoskeletal system endoscopy
		('363215001',  		'Procedure', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Musculoskeletal system physical examination
		('447486003',  		'Procedure', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Perioperative evaluation of musculoskelatal system
		('68848009',  		'Procedure', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Transillumination of newborn skull
		('418419008',  		'Procedure', 	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Virtual CT bronchoscopy

		('74036000',  			'Measurement', 	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pregnancy detection examination
		('167592004',  			'Measurement', 	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Examination of feces
		('42987007',  			'Measurement', 	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Vestibular function test
		('165079009',  			'Measurement', 	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Exercise tolerance test
		('3971006',  			'Measurement', 	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Duchenne muscular dystrophy carrier detection
		('44489000',  			'Measurement', 	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cystic fibrosis carrier detection
		('252895004',  			'Measurement', 	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Urodynamic studies
		('59851008',  			'Procedure', 	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Electronystagmogram
		('230937006',  			'Procedure', 	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Procedure for monitoring intracranial pressure
		('390906007',  			'Observation', 	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Follow-up encounter
		('11429006',  			'Observation', 	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Consultation

		('61594008',  			'Measurement', 	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Microbial culture
		('426945003',  			'Procedure', 	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Plain X-ray of bone
		('169443000',  			'Procedure', 	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Preventive procedure
		('223464006',  			'Observation', 	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Procedure education

		--Qualifier Value
		('260245000',			'Meas Value',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Finding Value
		--history:on
		('284009009',			'Drug',			TO_DATE('20150518', 'YYYYMMDD'),	TO_DATE('20171116', 'YYYYMMDD'),	NULL), -- Route of administration value
		('284009009',			'Route', 		TO_DATE('20171116', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Route of administration value
		--history:off
		--history:on
		('385285004',			'Drug',			TO_DATE('20150518', 'YYYYMMDD'),	TO_DATE('20230925', 'YYYYMMDD'),	NULL), -- dialysis dosage form
		('385285004',  		'Device',		TO_DATE('20230925', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Dialysis dosage form
		--history:off

		('421347001',			'Drug',			TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Cutaneous aerosol
		('105904009',			'Drug',			TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Type of drug preparation

		('767524001',			'Unit',			TO_DATE('20190211', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --  Unit of measure (Top unit)
		('8653201000001106',  'Drug',			TO_DATE('20190827', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --dm+d value

		('260299005',			'Meas Value',	TO_DATE('20201117', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Number [AVOF-2893]
		('272063003',			'Meas Value',	TO_DATE('20201117', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Alphanumeric[AVOF-2893]

		('371234007',			'Meas Value',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Color modifier
		('272104009',			'Meas Value',	TO_DATE('20220504', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Absolute times
		('297289008',			'Language',		TO_DATE('20221030', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --World languages

		('276135000',	'Meas Value Operator',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Mathematical sign

		('423335001',  		'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Device form

		('10984111000001107', 'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Medicated plaster
		('385281008',  		'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Radiopharmaceutical dosage form
		('278474008',  		'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Types of contrast medium
		('9906801000001108',  'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Nebuliser
		('90213003',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --False positive
		('61707005',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --False negative
		('272099008',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Descriptor
		('258395000',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Levels
		('258391009',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Classes
		('272423005',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Degrees of severity
		('258237008',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Editions
		('272422000',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Fractions of movement
		('261586004',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Groups
		('415068004',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Percentile value
		('449741000124101',	'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Preparation level
		('261612004',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Stages
		('277975002',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Temperature ranges
		('278159002',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --FAB type values
		('276726000',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Microbiology subtype
		('272397003',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Numerical types
		('272402004',			'Meas Value',	TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Types TH

		('246292004',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Level of arrest
		('134408007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Cycle of change stage
		('309689007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Occult carcinoma - stage

		('420719007',			'Route',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Intraventricular route

		--Social context
		--history:on
		('223366009',			'Provider Specialty',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20190201', 'YYYYMMDD'),	NULL), -- Healthcare professional
		('223366009',			'Provider',  	TO_DATE('20190201', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Healthcare professional
		--history:off
		('372148003',		'Race',			TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Ethnic group
		('415229000',		'Race',			TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Racial group
		('125677006',		'Relationship',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Relationship
		('224620002',		'Observation', 	TO_DATE('20230925', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Human aid to communication
		('1295407004',		'Observation', 	TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- ICD-10 glaucoma staging

		--Staging|Scales
		('258257007',		'Meas Value',	TO_DATE('20240503', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Additional tumour staging descriptor

		--Substance
		('264301008',			'Observation',  TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Psychoactive substance of abuse - non-pharmaceutical
		('289964002',			'Device',		TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Surgical material
		('418920007',			'Device',		TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Adhesive agent
		('255922001',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dental material
		('118417008',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Filling material
		('445214009',			'Device',		TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- corneal storage medium
		--history:on
		('373782009',			'Observation',  TO_DATE('20141231', 'YYYYMMDD'),	TO_DATE('20180208', 'YYYYMMDD'),	NULL), -- diagnostic substance, exception of drug
		('373782009',			'Device',		TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- diagnostic substance, exception of drug
		--history:off
		('410942007',			'Drug',			TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Drug or medicament
		('111160004',			'Drug',			TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Sodium iodide (131-I)
		('385420005',			'Device',		TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Contrast media
		('419148000',			'Device',		TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Diagnostic dye
		('766886003',			'Device',		TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Technetium (99m-Tc) bicisate
		('373222005',			'Device',		TO_DATE('20180208', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Disinfectants and cleansers
		('332525008',			'Device',		TO_DATE('20190418', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL),  --Camouflaging preparations
		('771387000',			'Drug',			TO_DATE('20200312', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Substance with effector mechanism of action

		('418672000',			'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Vitreoretinal surgical agent
		('373517009',			'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Protective agent (for skin)
		('109192009',			'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Hysteroscopy fluid
		('14399003',		 	'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Iodine radioisotope
		('373569004',			'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Flea and tick agent
		('373545003',			'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Replacement agent
		('373724007',			'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Colloidal oatmeal powder
		('289122001',			'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cosmetic material
		('256673003',			'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Mucosa, skin and subcutaneous material
		('256899007',			'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Cardiovascular material
		('418588009',			'Device',		TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dusting powder agent

		('255640000',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Biocide
		('11713004',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Water
		('301054007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Phytochemical
		('106181007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Immunologic substance
		('418297009',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pharmaceutical base or inactive agent
		('419556005',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Medical gas
		('57795002',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Chemical element
		('412232009',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Microbial agent
		('762766007',			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), --Edible substance
		('33638001', 			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Isotope
		('767266004', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Iodine and iodine compound
		('28268006', 			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pregnanediol
		('71159008', 			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Pregnanetriol
		('771388005', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Molecular messenger
		('43218009', 			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Allo-cortols
		('706932000', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Free progesterone
		('61789006', 			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Dye
		('301434004', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Turpentine or derivative
		('409893003', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bisacodyl metabolites
		('47389008', 			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Methyl tert-butyl ether
		('706933005', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Free phenytoin
		('68329003', 			'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Fuller's earth
		('226916002', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Beef
		('1284919009', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Bovine gelatin
		('256363008', 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Animal protein
		('39248411000001101', 'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Sodium iodide (131-I)
		('1368003', 			'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Iodine-131
		('33271006', 			'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Iodohippurate (131-I) sodium
		('33785000', 			'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Iodine (125-I) liothyronine
		('432884004',			'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Chlorotoxin (131-I)
		('765010006', 		'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Iodine (131-I) labeled monoclonal antibody
		('765117007',			'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Iodine (131-I) ethiodized oil
		('373273002',			'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- General inhalation anesthetic
		('373703002',  		'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Intravenous fluids and electrolytes
		('373523004',  		'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Skin antifungal agent
		('417901007',  		'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Oxymetazoline
		('255955006',  		'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Local anesthetic allergen
		('406463001',  		'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Drug allergen
		('782573007',  		'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Glycerol phenylbutyrate
		('441900009',  		'Drug',			TO_DATE('20230914', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Chemical

		('29750002',  		'Drug',			TO_DATE('20240510', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Substance
		('311942001',  		'Device',		TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Disinfectant dye

		('771382006',  		'Drug',	        TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Receptor antagonist
		('116185007',  		'Drug',	        TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Antibody to coagulation factor
		('33278000',  		'Observation',	TO_DATE('20241023', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	NULL), -- Insecticide

		--history:on
		('364066008',			'Observation',	TO_DATE('20201110', 'YYYYMMDD'),	TO_DATE('20201210', 'YYYYMMDD'), NULL), --Cardiovascular observable
		('364066008',			'Measurement',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 1), --Cardiovascular observable
		--history:off
		('405805006',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 0), --Cardiac resuscitation outcome
		('405801002',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 0), --Coronary reperfusion type
		('364072008',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 0), --Cardiac feature
		('364087003',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 0),  --Blood vessel feature
		('364069001',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 0),  --Cardiac conduction system feature
		('427751006',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 0),  --Extent of cardiac perfusion defect
		('429162008',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 0),  --Extent of myocardial stress ischemia
		('301978000',			'Observation',  TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 1),  --Finding of vision of eye
		('1099111000000105',  'Measurement',	TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 1),  --Thrombolysis In Myocardial Infarction risk score for unstable angina or non-ST-segment-elevation myocardial infarction
		('24942001',  		'Condition',	TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 0),  --Urobilinogenuria
		('18165001',  		'Condition',	TO_DATE('20201210', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'), 0),  --Jaundice
--2024-10-21
		-- history:on
		('404684003',			'Condition',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Clinical Finding
		('404684003',			'Condition',	TO_DATE('20241021', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	0), -- Clinical Finding
        -- history:off
        -- history:on
		('71388002', 			'Procedure',	TO_DATE('20141218', 'YYYYMMDD'),	TO_DATE('20230914', 'YYYYMMDD'),	NULL), -- Procedure
		('71388002', 			'Procedure',	TO_DATE('20241021', 'YYYYMMDD'),	TO_DATE('20991231', 'YYYYMMDD'),	0); -- Procedure
        -- history:off
	ANALYZE peak;
END;
$BODY$
LANGUAGE 'plpgsql';