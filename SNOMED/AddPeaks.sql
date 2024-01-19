CREATE OR REPLACE FUNCTION dev_snomed.AddPeaks ()
RETURNS void AS
$BODY$
BEGIN

--21.1.1
DROP TABLE IF EXISTS peak;
CREATE UNLOGGED TABLE peak (
	peak_code BIGINT, --the id of the top ancestor
	peak_domain_id VARCHAR(20), -- the domain to assign to all its children
	valid_start_date DATE, --a date when a peak with a mentioned Domain was introduced
	valid_end_date DATE, --a date when a peak with a mentioned Domain was deprecated
	levels_down INT, --a number of levels down in hierarchy the peak has effect. When levels_down IS NOT NULL, this peak record won't affect the priority of another peaks
	ranked INT -- number for the order in which to assign the Domain. The more "ranked" is, the later it updates the Domain in the script.
	);

--21.1.2 Fill in the various peak concepts
INSERT INTO peak
SELECT a.*, NULL FROM ( VALUES
-- Outdated
	--2014-Dec-18
	(218496004,         'Condition',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20170810', 'YYYYMMDD')), -- Adverse reaction to primarily systemic agents

	(162565002,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Patient aware of diagnosis
	(418138009,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Patient condition finding
	(405503005,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Staff member inattention
	(405536006,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Staff member ill
	(405502000,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Staff member distraction
	(398051009,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Staff member fatigued
	(398087002,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Staff member inadequately assisted
	(397976005,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Staff member inadequately supervised
	(162568000,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Family not aware of diagnosis
	(162567005,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Family aware of diagnosis
	(42045007,          'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Acceptance of illness
	(108329005,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Social context condition
	(108252007,         'Measurement',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Laboratory procedures
	(118246004,         'Measurement',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Laboratory test finding' - child of excluded Sample observation
	(442564008,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Evaluation of urine specimen
	(64108007,          'Procedure',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Blood unit processing - inside Measurements
	(258666001,         'Unit',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20190211', 'YYYYMMDD')), -- Top unit
	(243796009,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Situation with explicit context
	(420056007,         'Drug',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Aromatherapy agent
	(373873005,         'Drug',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Pharmaceutical / biologic product
	(404684003,         'Condition',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Clinical Finding
	(313413008,         'Condition',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Calculus observation
	(162566001,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), --Patient not aware of diagnosis
	(71388002,          'Procedure',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Procedure
	(304252001,         'Procedure',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Resuscitate
	(304253006,         'Procedure',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150104', 'YYYYMMDD')), -- DNR
	(297249002,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Family history of procedure
	(416940007,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Past history of procedure
	(183932001,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Procedure contraindicated
	(438833006,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Administration of drug or medicament contraindicated
	(410684002,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Drug therapy status
	(17636008,          'Procedure',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Specimen collection treatments and procedures - - bad child of 4028908 Laboratory procedure
	(106237007,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Linkage concept
	(260667007,         'Device',       TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Graft
	(309298003,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), --Drug therapy observations

	--2014-Dec-31
	(369443003,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- bedpan
	(398146001,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- armband
	(272181003,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- clinical equipment and/or device
	(445316008,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- component of optical microscope
	(419818001,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- Contact lens storage case
	(228167008,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- Corset
	(42380001,          'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- Ear plug, device
	(1333003,           'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- Emesis basin, device
	(360306007,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- Environmental control system
	(33894003,          'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- Experimental device
	(116250002,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- filter
	(59432006,          'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- ligature
	(360174002,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- nabeya capsule
	(311767007,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- special bed
	(360173008,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- watson capsule
	(367561004,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150518', 'YYYYMMDD')), -- xenon arc photocoagulator
	(226465004,         'Observation',  TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Drinks
	(419572002,         'Observation',  TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- alcohol agent, exception of drug
	(413674002,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20150104', 'YYYYMMDD')), -- Body material
	--2015-Jan-04
	(304253006,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- DNR
	(105590001,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Substances
	(123038009,         'Specimen',     TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Specimen
	(48176007,          'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Social context
	(272379006,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Events
	(260787004,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Physical object
	(362981000,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Qualifier value
	(363787002,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Observable entity
	(410607006,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Organism
	(419891008,         'Note Type',    TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20151009', 'YYYYMMDD')), -- Record artifact
	(78621006,          'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Physical force
	(123037004,   		'Spec Anatomic Site', TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Body structure
	(118956008,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Body structure, altered from its original anatomical structure, reverted from 123037004
	(254291000,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20181107', 'YYYYMMDD')), -- Staging / Scales
	(370115009,         'Metadata',     TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Special Concept
	(308916002,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Environment or geographical location
	(413674002,         'Observation',  TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Body material

	--2015-Jan-19
	(80631005,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Clinical stage finding
	(281037003,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Child health observations
	(105499002,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Convalescence
	(301886001,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Drawing up knees
	(298304004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Finding of balance
	(298339004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Finding of body control
	(300577008,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Finding of lesion
	(298325004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Finding of movement
	(427955007,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Finding related to status of agreement with prior finding
	(118222006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- General finding of observation of patient
	(249857004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Loss of midline awareness
	(300232005,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Oral cavity, dental and salivary finding
	(364830008,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Position of body and posture - finding
	(248982007,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Pregnancy, childbirth and puerperium finding
	(128254003,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Respiratory auscultation finding
	(397773008,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Surgical contraindication
	(386053000,         'Measurement',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20150311', 'YYYYMMDD')), -- evaluation procedure
	(127789004,         'Measurement',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20150311', 'YYYYMMDD')), -- laboratory procedure categorized by method
	(395557000,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Tumor finding
	(422989001,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Appendix with tumor involvement, with perforation not at tumor
	(384980008,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Atelectasis AND/OR obstructive pneumonitis of entire lung associated with direct extension of malignant neoplasm
	(396895006,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Endocrine pancreas tumor finding
	(422805009,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Erosion of esophageal tumor into bronchus
	(423018005,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Erosion of esophageal tumor into trachea
	(399527001,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Invasive ovarian tumor omental implants present
	(399600009,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Lymphoma finding
	(405928008,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Renal sinus vessel involved by tumor
	(405966006,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Renal tumor finding
	(385356007,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Tumor stage finding
	(13104003,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Clinical stage I
	(60333009,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Clinical stage II
	(50283003,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Clinical stage III
	(2640006,           'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Clinical stage IV
	(385358008,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Dukes stage finding
	(385362002,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- FIGO stage finding for gynecological malignancy
	(405917009,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Intergroup rhabdomyosarcoma study post-surgical clinical group finding
	(409721000,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- International neuroblastoma staging system stage finding
	(385389007,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Lymphoma stage finding
	(396532004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Stage I: Tumor confined to gland, 5 cm or less
	(396533009,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Stage II: Tumor confined to gland, greater than 5 cm
	(396534003,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Stage III: Extraglandular extension of tumor without other organ involvement
	(396535002,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Stage IV: Distant metastasis or extension into other organs
	(399517007,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Tumor stage cannot be determined
	(67101007,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- TX category
	(385385001,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- pT category finding
	(385382003,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Node category finding
	(385380006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Metastasis category finding
	(386702006,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Victim of abuse
	(95930005,          'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Victim of neglect
	(248536006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Finding of functional performance and activity
	(37448008,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Disturbance in intuition
	(12200008,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Impaired insight
	(5988002,           'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Lack of intuition
	(1230003,           'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- No diagnosis on Axis I
	(10125004,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- No diagnosis on Axis II
	(51112002,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- No diagnosis on Axis III
	(54427008,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- No diagnosis on Axis IV
	(37768003,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- No diagnosis on Axis V
	(6811007,           'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Prejudice
	(405533003,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Adverse incident outcome categories
	(304252001,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Resuscitate
	(69449002,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Drug action
	(79899007,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Drug interaction
	(365858006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Prognosis/outlook finding
	(444332001,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Aware of prognosis
	(444143004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Carries emergency treatment
	(251859005,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Dialysis finding
	(422704000,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Difficulty obtaining contraception
	(217315002,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Onset of illness
	(162511002,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Rare history finding
	(300893006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Nutritional finding
	(424092004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Questionable explanation of injury
	(397745006,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), --Medical contraindication
	--2015-May-18
	(421967003,         'Drug',         TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- drug dose form
	(424387007,         'Drug',         TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- dose form by site prepared for
	(421563008,         'Drug',         TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- complementary medicine dose form
	--2015-Oct-09
	(419891008,         'Type Concept', TO_DATE('20151009', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Record artifact

	--2015-Aug-17
	(46680005,          'Measurement',  TO_DATE('20150817', 'YYYYMMDD'), TO_DATE('20170810', 'YYYYMMDD')), -- Vital signs
	--2016-Mar-22
	(57797005,          'Procedure',    TO_DATE('20160322', 'YYYYMMDD'), TO_DATE('20171024', 'YYYYMMDD')), -- Termination of pregnancy
	--2017-Mar_14
	(225831004,         'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Finding relating to advocacy
	(134436002,         'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Lifestyle
	(386091000,         'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Finding related to compliance with treatment
	(424092004,         'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Questionable explanation of injury
	(749211000000106,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- NHS Sickle Cell and Thalassaemia Screening Programme family origin
	(91291000000109,    'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Health of the Nation Outcome Scale interpretation
	(900781000000102,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Noncompliance with dietetic intervention
	(784891000000108,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Injury inconsistent with history given
	(863811000000102,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Injury within last 48 hours
	(920911000000100,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Appropriate use of accident and emergency service
	(927031000000106,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Inappropriate use of walk-in centre
	(927041000000102,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Inappropriate use of accident and emergency service
	(927901000000101,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Inappropriate triage decision
	(927921000000105,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Appropriate triage decision
	(921071000000100,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Appropriate use of walk-in centre
	(962871000000107,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Aware of overall cardiovascular disease risk
	(968521000000109,   'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Inappropriate use of general practitioner service

	--2017-Aug-30
	(424122007,         'Observation',  TO_DATE('20170830', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- ECOG performance status finding

	--history:off
	--2017-Aug-25
	(7895008,           'Observation',  TO_DATE('20170825', 'YYYYMMDD'), TO_DATE('20171116', 'YYYYMMDD')), -- Poisoning caused by drug AND/OR medicinal substance
	(55680006,          'Observation',  TO_DATE('20170825', 'YYYYMMDD'), TO_DATE('20171116', 'YYYYMMDD')), -- Drug overdose
	(292545003,         'Observation',  TO_DATE('20170825', 'YYYYMMDD'), TO_DATE('20171116', 'YYYYMMDD')), -- Oxitropium adverse reaction --somehow it sneaks through domain definition above, so define this one separately
	--2017-Nov-16
	(698289004,         'Observation',  TO_DATE('20171116', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Hooka whatever Observation  -- http://forums.ohdsi.org/t/hookah-concept/3515
	--2018-Feb-08
	--Azaribine, Pegaptanib sodium, Cutaneous aerosol, Pegaptanib, etc. - exclusion without nice hierarchy
	(373447009,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')),
	(416058004,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')),
	(387111009,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')),
	(423490007,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')),
	(1536005,           'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')),
	(386925003,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')),
	(126154004,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')),
	(61483006,          'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')),
	(373749006,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')),
	--2018-Oct-06
	(414916001,         'Condition',    TO_DATE('20181006', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Obesity

	--2018-Nov-07
	(254291000,         'Measurement',  TO_DATE('20181107', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Staging / Scales [AVOF-1295]
	--2019-Feb-11
	(118226009,         'Observation',  TO_DATE('20190211', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Temporal finding
	(418038007,         'Observation',  TO_DATE('20190211', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Propensity to adverse reactions to substance
	--2020-Mar-17
	(41769001,          'Condition',    TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20200428', 'YYYYMMDD')), -- Disease suspected
	--2020-Nov-04
	(734539000,         'Drug',         TO_DATE('20201104', 'YYYYMMDD'), TO_DATE('20210211', 'YYYYMMDD')), -- Effector
	--2020-Nov-10
	(766739005,         'Drug',         TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Substance categorized by disposition
	--2020-Nov-24
	(397745006,         'Observation',  TO_DATE('20201124', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Medical contraindication
	(364108009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Lymph node observable
	--2021-Oct-27
	(62305002,          'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Disorder of language
	(289161009,         'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Finding of appetite
	(309298003,         'Observation',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Drug therapy finding
	(271807003,         'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Eruption
	(402752000,         'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Dermatosis resulting from cytotoxic therapy
	--2022-05-04
	(365726006,         'Condition',    TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Finding related to ability to process information accurately
	(365737007,         'Condition',    TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Finding related to ability to process information at normal speed
	(365748000,         'Condition',    TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Finding related to ability to analyze information
	(59274003,          'Condition',    TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Intentional drug overdose
	(401783003,         'Device',       TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Disposable insulin U100 syringe+needle
	(401826003,         'Device',       TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Hypodermic U100 insulin syringe sterile single use / single patient use 0.5ml with 12mm needle 0.33mm/29gauge
	(401830000,         'Device',       TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Hypodermic U100 insulin syringe sterile single use / single patient use 1ml with 12mm needle 0.33mm/29gauge
	(91723000,          'Spec Anatomic Site',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Anatomical structure
	(284648005,         'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Dietary intake finding
	(911001000000101,   'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Serum norclomipramine measurement
	(288533004,         'Meas Value',   TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Change values
	(782964007,         'Condition',    TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Genetic disease
	(237834000,         'Condition',    TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Disorder of stature
	(400038003,         'Condition',    TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Congenital malformation syndrome
	(162300006,         'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Unilateral headache
	(428264009,         'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Painful gait
	(905231000000103,   'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Imbalanced intake of fibre
	(896531000000104,   'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Imbalanced dietary intake of fat
	(735643002,         'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Short stature of childhood
	(948391000000106,   'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- O/E - antalgic gait
	(43528001,          'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Distomolar supernumerary tooth
	(163166004,         'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- O/E - tongue examined
	(231466009,         'Condition',    TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Acute drug intoxication

-- Relevant
	--Model Comp
	--history:on
	(138875005,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150104', 'YYYYMMDD')), -- root
	(138875005,         'Metadata',     TO_DATE('20150104', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- root
	--history:off
	(900000000000441003,'Metadata',     TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SNOMED CT Model Component

	--Clinical Finding
	(365873007,         'Gender',       TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Gender
	(307824009,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Administrative statuses
	(305058001,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Patient encounter status
	(118233009,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of activity of daily living
	(365854008,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- History finding
	(105729006,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Health perception, health management pattern
	(162408000,         'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Symptom description

	(124083000,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Urobilinogenemia
	(71922006,         	'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Immune defect
	(413296003,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Depression requiring intervention
	(106146005,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Reflex finding
	(103020000,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adrenarche
	(405729008,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hematochezia
	(300391003,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of appearance of stool
	(300393000,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of odor of stool
	(165816005,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- HIV positive
	(106019003,         'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of elimination pattern
	(72670004,         	'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Sign
	   --history:on
	(365605003,         'Measurement',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20170810', 'YYYYMMDD')), -- Body measurement finding
	(365605003,         'Observation',  TO_DATE('20170810', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Body measurement finding
	--history:off
	--history:on
	(448717002,         'Measurement',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20170810', 'YYYYMMDD')), -- Decline in Edinburgh postnatal depression scale score
	(448717002,         'Condition',    TO_DATE('20170810', 'YYYYMMDD'), TO_DATE('20231013', 'YYYYMMDD')), -- Decline in Edinburgh postnatal depression scale score
	--history:off
	--history:on
	(449413009,         'Measurement',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20170810', 'YYYYMMDD')), -- Decline in Edinburgh postnatal depression scale score at 8 months
	(449413009,         'Condition',    TO_DATE('20170810', 'YYYYMMDD'), TO_DATE('20231013', 'YYYYMMDD')), -- Decline in Edinburgh postnatal depression scale score at 8 months
	--history:off
	--history:on
	--TODO: Check this peak after mapping
	(441742003,         'Measurement',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20170810', 'YYYYMMDD')), -- Evaluation finding
	(441742003,         'Condition',    TO_DATE('20170810', 'YYYYMMDD'), TO_DATE('20201104', 'YYYYMMDD')), -- Evaluation finding
	(441742003,         'Measurement',  TO_DATE('20201104', 'YYYYMMDD'), TO_DATE('20201210', 'YYYYMMDD')), -- Evaluation finding
	(441742003,         'Condition',    TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Evaluation finding
	--history:off
	(13197004,          'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Contraception
	--history:on
	(284530008,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20160322', 'YYYYMMDD')), -- Communication, speech and language finding
	(284530008,         'Observation',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20211027', 'YYYYMMDD')), -- Communication, speech and language finding
	--history:off
	(364721000000101,   'Measurement',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- DFT: dynamic function test
	(365980008,         'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Tobacco use and exposure - finding
	(129843006,         'Observation',  TO_DATE('20170314', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Health management finding
	(118227000,         'Condition',    TO_DATE('20170810', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Vital signs finding
	(473010000,         'Condition',    TO_DATE('20171116', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hypersensitivity condition
	(419199007,         'Observation',  TO_DATE('20170825', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allergy to substance
	(365574009,         'Observation',  TO_DATE('20171116', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Life event finding
	--[AVOF-1295]
	(125123008,         'Measurement',  TO_DATE('20181107', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Organ Weight
	(125125001,         'Observation',  TO_DATE('20181107', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Abnormal organ weight
	(125124002,         'Observation',  TO_DATE('20181107', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal organ weight
	(268444004,         'Measurement',  TO_DATE('20181107', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Radionuclide red cell mass measurement

	(366154003,        'Observation',  	TO_DATE('20190211', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Respiratory flow rate - finding
	(397731000,         'Race',         TO_DATE('20190827', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Ethnic group finding

	(365866002,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of HIV status
	(438508001,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Virus present

	(871000124102,      'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Virus not detected
	(426000000,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Fever greater than 100.4 Fahrenheit
	(164304001,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - hyperpyrexia - greater than 40.5 degrees Celsius
	(163633002,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E -skin temperature abnormal
	(164294007,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - rectal temperature
	(164295008,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - core temperature
	(164300005,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - temperature normal
	(164303007,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - temperature elevated
	(164293001,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - groin temperature
	(164301009,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - temperature low
	(164292006,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - axillary temperature
	(275874003,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - oral temperature
	(315632006,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - tympanic temperature
	(274308003,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - hyperpyrexia
	(164285001,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - fever - general
	(164290003,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - method fever registered
	(162913005,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - rate of respiration

	(29164008,          'Condition',    TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Disturbance in speech
	(288579009,         'Condition',    TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Difficulty communicating
	(288576002,         'Condition',    TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Unable to communicate
	(229621000,         'Condition',    TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Disorder of fluency
	(365341008,         'Observation',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding related to ability to perform community living activities
	(365031000,         'Observation',  TO_DATE('20201124', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding related to ability to perform activities of everyday life
	(365242003,         'Observation',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding related to ability to perform domestic activities
	(1240591000000102,  'Measurement',	TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Severe acute respiratory syndrome coronavirus 2 not detected

	(1240581000000104,  'Measurement',	TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Severe acute respiratory syndrome coronavirus 2 detected
	(129063003,         'Observation',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Instrumental activity of daily living
	(863903001,         'Observation',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allergy to vaccine product

	(268935007,         'Condition',    TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- On examination - peripheral pulses right leg
	(268936008,         'Condition',    TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- On examination - peripheral pulses left leg
	(164399004,         'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - skin scar
	(165815009,         'Condition',    TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- HIV negative
	(365956009,         'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of sexual orientation

	(106028002,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Musculoskeletal finding
	--history:on
	(65367001,          'Observation',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Victim status
	(65367001,          'Condition',    TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20150311', 'YYYYMMDD')), -- Victim status
	(65367001,          'Observation',  TO_DATE('20150311', 'YYYYMMDD'), TO_DATE('20170106', 'YYYYMMDD')), -- Victim status
	(65367001,          'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Victim status
	--history:off
	(106132005,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Speech finding
	(248982007,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pregnancy, childbirth and puerperium finding
	(106089007,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Metabolic finding
	(714628002,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Prediabetes
	(419026008,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Effect of exposure to physical force
	(300848003,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Mass of body structure
	(84452004,         	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hormone abnormality
	(299691001,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of blood, lymphatics and immune system
	(69328002,         	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Distress
	(267038008,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Edema
	(65124004,      	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Swelling
	(276438008,      	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Swelling / lump finding
	(36456004,         	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Mental state finding
	(1157237004,        'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Altered perception
	(25470001000004105, 'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cognitive impairment due to multiple sclerosis
	(386806002,        	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Impaired cognition
	(423884000,        	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Repetitious behavior
	(26628009,      	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Disturbance in thinking
	(25786006,      	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Abnormal behaviour
	(112630007,      	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Abnormal facies
	(131148009,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bleeding
	(22253000,         	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pain
	(45352006,         	'Condition',   	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Spasm
	(247348008,        	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Tenderness
	(48694002,         	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Anxiety
	(102943000,        	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Personality change
	(113381000119100,  	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Codependency
	(404640003,        	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dizziness
	(102957003,        	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Neurological finding
	(431950004,        	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bloodstream finding
	(118235002,        	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Eye / vision finding
	(106048009,        	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Respiratory finding
	(300577008,        	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of lesion
	(247441003,       	'Condition',   	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Erythema
	(225552003,    	    'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Wound finding
	(246556002,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Central nervous system finding
	(300862005,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Mass of body region
	(302292003,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of trunk structure
	(298314008,    	    'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding related to coordination / incoordination
	(248402002,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- General finding of soft tissue
	(302293008,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of limb structure
	(298325004,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of movement
	(43029002,         	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Abnormal posture
	(118254002,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of head and neck region
	(361055000,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Misuses drugs
	(414252009,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of back
	(106030000,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Muscle finding
	(106129007,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Motor function behavior finding
	(816081007,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Extracellular fluid volume depletion
	(386617003,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Digestive system finding
	(8659000,         	'Condition', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Ectopic production of endocrine substance
	(415531008,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Skin AND/OR mucosa finding
	(51178009,         	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Sudden infant death syndrome
	(39104002,         	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Illness
	(248457000,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Rigor - symptom
	--history:on
	(48340000,          'Condition',    TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Incontinence
	(48340000,          'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Incontinence
	--history:off
	(165232002,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Urinary incontinence
	(72042002,         	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Incontinence of feces
	(1086911000119107,  'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Complete fecal incontinence
	(737585009,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Abulia
	(609555007,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Diastolic heart failure stage A
	(609556008,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Systolic heart failure stage A
	(277850002,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Diogenes syndrome
	(248279007,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Frailty
	(248548009,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Nocturnal dyspnea
	(247845000,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Specific fear
	(268637002,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Psychosexual dysfunction
	(272030005,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Syncope
	(63384009,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Distorted body image
	(29738008,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Proteinuria
	(61373006,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bacteriuria
	(274769005,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Albuminuria
	(53397008,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Biliuria
	(45154002,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Glycosuria
	(68600005,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hemoglobinuria
	(737176000,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hypermagnesuria
	(762434003,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hypomagnesuria
	(762434003,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hypomagnesuria
	(274783007,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Ketonuria
	(123769001,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Methemoglobinuria
	(48165008,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Myoglobinuria
	(165517008,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Neutropenia
	(165518003,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Neutrophilia
	(50820005,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cytopenia
	(129647005,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hypoglobulinemia
	(119249001,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Agammaglobulinemia
	(119250001,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hypogammaglobulinemia
	(3761000119104,  	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hypotestosteronism
	(64088006,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hyperviscosity
	(47872005,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hypoviscosity
	(37097005,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Erythroblastosis
	(46049004,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Reticulocytosis
	(123806003,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bisalbuminemia
	(81647003,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Increased serum protein level
	(250243009,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dacrocytosis
	(373372005,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Histological grade finding
	(372048000,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pregnancy with abnormal glucose tolerance test
	(1156100006,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pregnancy with normal glucose tolerance test
	(84445001,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Joint stiffness
	(67374007,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Instability of joint
	(302690004,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Encopresis
	(416113008,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Disorder characterized by fever
	(103075007,  		'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Humoral immune defect

	(397852001,         'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- V/Q - Ventilation/perfusion ratio
	(302083008,         'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of Apgar score
	(413347006,         'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of American Society of Anesthesiologists physical status classification
	(881501000000104,   'Measurement',  TO_DATE('20230928', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Gross Motor Function Classification System for Cerebral Palsy level finding
	(61481000000106,    'Measurement',  TO_DATE('20230928', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- MACS for Children with Cerebral Palsy 4-18 years - Level I
	(61501000000102,    'Measurement',  TO_DATE('20230928', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- MACS for Children with Cerebral Palsy 4-18 years - Level II
	(61511000000100,    'Measurement',  TO_DATE('20230928', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- MACS for Children with Cerebral Palsy 4-18 years - Level III
	(61521000000106,    'Measurement',  TO_DATE('20230928', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- MACS for Children with Cerebral Palsy 4-18 years - Level IV
	(1321791000000109,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgA detection result equivocal
	(1321771000000105,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgA detection result negative
	(1321761000000103,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgA detection result positive
	(1321781000000107,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgA detection result unknown
	(1321541000000108,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgG detection result positive
	(1321591000000103,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgG detection result equivocal
	(1321571000000102,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgG detection result negative
	(1321641000000107,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgG detection result unknown
	(1321631000000103,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgM detection result equivocal
	(1321561000000109,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgM detection result negative
	(1321551000000106,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgM detection result positive
	(1321581000000100,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) IgM detection result unknown
	(1322901000000109,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antibody detection result indeterminate
	(1322911000000106,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antibody detection result unknown
	(1322901000000109,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antibody detection result indeterminate
	(1322801000000101,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result indeterminate
	(1322791000000100,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result negative
	(1322781000000102,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result positive
	(1322821000000105,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result unknown
	(1324601000000106,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) RNA detection result positive
	(260246004,        	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Visual acuity finding
	(302082003,        	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of birth length
	--history: on
	(118245000,         'Measurement',  TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Measurement finding
	(118245000,         'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measurement finding
	--history:off
	(250520004,        	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dairy food test finding
	(719724007,        	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Deoxyribonucleic acid of Campylobacter not detected
	(719707001,        	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Deoxyribonucleic acid of Salmonella not detected
	(251342007,        	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dermatological test finding
	(790741000000104,   'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Equivocal immunology finding
	(307577005,    		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of Heaf test
	(62117008,		  	'Measurement',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bacterial antibody increase, paired specimens
	(365408009,		 	'Measurement',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- ECG waveform - finding
	(395536008,		 	'Measurement',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Surgical margin finding
	(165014009,		 	'Measurement',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allergy test positive
	(165009005,		 	'Measurement',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allergy testing - no reaction
	(1236949008,        'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of placental volume
	(1187035007,        'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Blood viscosity below reference range
	(298717003,        	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of measures of thorax
	(366147009,        	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Respiratory measurements - finding
	(249131000,        	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of amniotic fluid volume
	(34641000087106,    'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hematology test outside reference range

	(705075002,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Able to see
	(719749006,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Able to see using assistive device
	(264786003,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Amsler chart finding
	(82132006,         	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal visual acuity
	(170728008,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Poor visual acuity
	(13164000,         	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Reduced visual acuity
	(264944004,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Visual acuity PL - accurate projection
	(264943005,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Visual acuity PL - inaccurate projection
	(422256009,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Counts fingers - distance vision
	(424348007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Difficulty seeing distant objects
	(277754002,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Ocular test distance as specified
	(830128004,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal near vision
	(260296003,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Perceives light only
	(260295004,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Sees hand movements
	(427013000,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Alcohol consumption during pregnancy
	(424712007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Difficulty following postpartum diet
	(289750007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of involution of uterus
	(249211006,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Lochia finding
	(271880003,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- O/E - specified examination findings
	(365441007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Drive - finding
	(371078007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of eating pattern
	(106131003,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Mood finding
	(58424009,        	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Overeating
	(248536006,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of functional performance and activity
	(827031005,    	    'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Site of injection normal
	(302288005,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal coordination
	(27086002,         	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal physical attitude
	(86678000,         	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal station
	(300561007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Genitourinary tract normal
	(364940007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Handedness finding
	(445327005,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal shape of extremity
	(301178004,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal venous return in limb vein
	(116329008,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of walking
	(764925004,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal lower limb movement and sensation and circulation
	(764924000,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal upper limb movement and sensation and circulation
	(736706004,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dentofacial function normal
	(860970003,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal eye proper
	(246723000,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Ocular muscle balance normal
	(301924000,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal globe
	(840673007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Head normal
	(840674001,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal neck region
	(426792009,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cervical spine normal
	(300196000,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Ear normal
	(426792009,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cervical spine normal
	(300196000,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Ear normal
	(301225007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Larynx normal
	(364777007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Eating, feeding and drinking abilities - finding
	(365448001,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Social and personal history finding
	(79015004,         	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Worried
	(364734006,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Quality of construction of footwear - finding
	(129879003,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Parenting finding
	(1149345007,        'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Excessive weight gain during pregnancy
	(364826005,    	    'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding related to ability to perform breast-feeding
	(243826008,    	    'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Antenatal care status
	(116336009,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Eating / feeding / drinking finding
	(289159000,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Thirst finding
	(250869005,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Equipment finding
	(127362006,         'Observation',  TO_DATE('20160322', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Previous pregnancies
	(365449009,         'Observation',  TO_DATE('20230928', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Demographic history finding
	(373060007,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Device status
	(108329005,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Social context finding
	(224959009,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal physiological development
	(294854007,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allergy to albumin solution
	(107651007,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Quantity finding
	(72724002,         	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Morphology findings
	(251440000,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Neuroelectrophysiology finding
	(123978000,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Functional disorder not identified
	(299475005,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of temperature of foot
	(299902004,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of temperature sense
	(366718006,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Joint temperature
	(299475005,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of temperature of foot
	(225577002,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Stoma finding
	(370994008,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Seizure free
	(365670007,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Odor of specimen - finding
	(247950007,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Sleep behavior finding
	(281459007,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bending of spinal fixation device
	(365861007,         'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of immune status
	(1144566001,        'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Managing to control withdrawal symptoms
	(365690003,        	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Presence of organism - finding
	(365698005,        	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Organism growth - finding
	(278542003,        	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dental appliance or restoration finding
	(118192006,        	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding relating to self-concept
	(341000119102,      'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Tattoo of skin
	--Piercing
	(698015006,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(1281807004,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(1260230003,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(1260232006,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(1260221006,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(1260220007,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(1260222004,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(23506009,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal flora
	(275530009,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Amputee - limb
	(247522004,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hair finding
	(365853002,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Imaging finding
	(404509004,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Large gram-negative coccobacilli
	(123830001,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bacteria morphologically consistent with Actinomyces spp
	(723529006,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Extracellular Gram-negative diplococcus
	(734445005,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Gram-positive bacilli in chains
	(734446006,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Gram-positive bacilli in palisades
	(61609004,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Gram-positive cocci in chains
	(734444009,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Gram-positive cocci in chains, clusters, and pairs
	(70003006,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Gram-positive cocci in clusters
	(734447002,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Intracellular Gram-negative diplococcus
	(404510009,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Large gram-negative rods
	(404511008,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Large gram-positive rods
	(442670009,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Motile microorganism
	(15173006,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Rare organisms
	(427824002,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Small Gram-negative rods
	(722945007,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Androgen excess caused by drug
	(56709009,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Target cell of immunologic reaction
	(313424005,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- At increased risk of disease
	(70733008,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Limitation of joint movement
	(870752006,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding related to health literacy
	(365949003,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Health-related behavior finding
	(1260078007,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Maternal breastfeeding
	(417186004,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Precipitous drop in hematocrit
	(409683007,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Stable hematocrit
	(870578004,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Persistent abnormal electrolytes
	(251399004,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Lactose tolerance
	(444138006,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Speckled antinuclear antibody pattern
	(124875007,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Acquisition of new antigens
	(166165005,      	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Antibody studies normal
	(471841000124105,   'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Analyte not reportable due to high human immunodeficiency virus antibody
	(365705006,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Antimicrobial susceptibility - finding
	(442703001,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Aspiration test negative for air during procedure
	(442718000,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Aspiration test negative for blood during procedure
	(442710007,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Aspiration test negative for cerebrospinal fluid during procedure
	(365855009,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Biopsy finding
	(250247005,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bite cells
	(165547005,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Blast cells present
	(124989003,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cell center alteration
	(124978005,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cell division alteration
	(124991006,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Centriole alteration
	(124990007,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Centrosphere alteration
	(365857001,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Child examination finding
	(301833004,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- CSU = no abnormality
	(124983002,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cytokinetic alteration
	(93771000119109,   	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Diagnosis deferred
	(723663001,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Diagnosis not made
	(301120008,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Electrocardiogram finding
	(370351008,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Endoscopy finding
	(414253004,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of cellular component of blood
	(168457008,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Gross pathology - NAD
	(450241000124104,   'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Gynecological examination normal
	(250537006,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Histopathology finding
	(397918000,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Human leukocyte antigen type
	(444059002,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hypercholesterolemia well controlled
	(252097006,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hypersensitivity finding
	(395034001,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Immune complex observation
	(395034001,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Immune complex observation
	(197411000000101,   'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Isolate finding
	(124877004,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Loss of isoantigens
	(124876008,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Loss of normal antigens
	(250429001,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Macroscopic specimen observation
	(444589003,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Malignant neoplasm detection during interval between recommended screening examinations
	(167940002,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Marrow megakaryocyte increase
	(395538009,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Microscopic specimen observation
	(385466000,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Minimum inhibitory concentration finding
	(723745006,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Morphological description only, with differential diagnosis
	(723745006,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Morphological description only, with differential diagnosis
	(85728002,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Morphologic description only
	(732973003,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Morphologic diagnosis, additional studies required
	(15656008,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Morphologic diagnosis deferred
	(125112009,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Morphology within normal limits
	(164716009,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Neurological diagnostic procedure - normal
	(8821000175107,   	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Neurovascular deficit
	(442689009,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Nonmotile microorganism
	(734878005,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal cellular hormonal pattern
	(289342000,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal CTG tracing
	(309162003,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal histology findings
	(66552009,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- No tissue received
	(719790009,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Nucleic acid amplification not detected
	(404523002,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Organism not viable
	(124873000,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Plasma membrane antigenic alteration
	(124992004,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Polar body alteration
	(250435001,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Presence of cells
	(365687009,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Presence of crystals - finding
	(365613002,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Presence of hemoglobin - finding
	(124874006,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Production of fetal antigens
	(442666001,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Reliable screening not possible due to prematurity of subject
	--Sample characteristics
	(281261001,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(281283002,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(281282007,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(281281000,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),
	(840851000000100,   'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),

	(395028008,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Skin sample observation
	(125154007,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Specimen unsatisfactory for evaluation
	(363171000000104,   'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Timed collection of specimen
	(842211000000104,   'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Timed sample series
	(118207001,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding related to molecular conformation
	(106221001,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Genetic finding
	(719756000,   		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hemosiderin laden macrophages seen
	(458471000124109,  	'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- High risk of adverse medication event
	(168452002,  		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Forensic examination normal
	(123828003,  		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Fungal organisms morphologically consistent with Candida species
	(107645002,  		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Size finding
	(1149085006,  		'Observation',  TO_DATE('20230927', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Satisfied with management of pain
	(366636003,			'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Facial appearance finding
	(281457009,			'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Breakage of bone fixation device
	(6071000119100,		'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Upper respiratory tract allergy
	(451321000124108,	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Needs maximal assistance
	(451311000124100,	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Needs moderate assistance
	(442076002,			'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Early satiety
	(716366009,			'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Requires continuous home oxygen supply
	(428264009,			'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Painful gait
	(236556004,			'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bloodstained peritoneal dialysis effluent
	(25911000175109,	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Eyelid normal
	(413585005,			'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Aspiration into respiratory tract
	(364747001,			'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Presentation of fetus - finding
	(1231194004,		'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal visual motion detection
	(1149054002,		'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal reproductive system function
	(1260401008,		'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Epiphyseal closure
	(1220629002,		'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Impaired response to stem cell mobilization procedure
	(366140006,			'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Method of breathing - finding
	(365430005,			'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of urine appearance
	(118231006,			'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Communication finding
	(105721009,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- General problem AND/OR complaint
	(110302009,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Clenching teeth
	(714527000,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Decreased mandibular vestibule depth
	(714526009,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Decreased maxillary vestibular depth
	(789510003,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dental arch length loss
	(278655007,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dental center-line finding
	(110323003,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Distal step occlusion of primary dentition
	(698066001,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Edentulous interarch space limited
	(710011009,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Edentulous muscle attachment
	(289144006,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of food in mouth
	(709027003,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of location and extent of edentulous area of oral cavity
	(699749004,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Narrow mandibular arch form
	(699751000,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Narrow maxillary arch form
	(711635006,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal periapical tissue
	(714482007,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Normal periodontal tissue
	(609433001,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hypersensitivity disposition
	(1236949008,        'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of placental volume
	(118228005,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Functional finding
	(301346001,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of appearance of lip
	(1209208002,        'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pale face
	(59901004,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cheek biting
	(711292003,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Decrease of chin to throat length
	(711291005,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Increase of chin to throat length
	(710781009,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Deep mentolabial sulcus
	(737034006,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Obtuse nasolabial angle
	(471397004,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Long lower third of face
	(699440004,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Long middle third of face
	(1209208002,        'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pale face
	(767358005,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Shallow mentolabial sulcus
	(73595000,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Stress
	(106126000,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Emotional state finding
	(42688000,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Preoccupation of thought
	(1177022006,        'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Colonization of respiratory tract with Pneumocystis jirovecii
	(127325009,        	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Procedure related finding
	(30693006,       	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Aerophagy
	(1217022005,       	'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Colonization of genitourinary tract by Streptococcus agalactiae
	(283021003, 	    'Observation',  	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Mobile tooth
	(86569001, 	      	'Observation',  	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Postpartum state
	(248727005, 	    'Observation',  	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Venous finding
	(298180004, 	    'Observation',  	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding of range of joint movement
	(252041008, 	    'Observation',  	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Micturition finding

	--history:on
	(710954001,         'Measurement',  TO_DATE('20200317', 'YYYYMMDD'), TO_DATE('20220504', 'YYYYMMDD')), -- Bacteria present
	(710954001,         'Condition',    TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20230914', 'YYYYMMDD')), -- Bacteria present
	(710954001,         'Observation',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bacteria present
	--history:off

	--Context-dependent
	(395098000,         'Condition',    TO_DATE('20200518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Disorder confirmed
	(443938003,         'Observation',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Procedure carried out on subject

	--Disorder
	--history:on
	(282100009,         'Observation',  TO_DATE('20170825', 'YYYYMMDD'), TO_DATE('20171116', 'YYYYMMDD')), -- Adverse reaction caused by substance
	--(282100009,         'Observation',  TO_DATE('20180820', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adverse reaction caused by substance
	--history:off
	--(293104008,         'Observation',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adverse reaction to vaccine product
	(28926001,          'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Eruption due to drug
	(402752000,         'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dermatosis resulting from cytotoxic therapy
	(407674008,         'Condition',    TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Aspirin-induced asthma
	(10628711000119101, 'Condition',    TO_DATE('20171116', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allergic contact dermatitis caused by plant (this is only one child of 419199007 Allergy to substance that has exact condition mentioned
	(424909003,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Toxic retinopathy
	(312963001,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Methanol retinopathy
	(82545002,         	'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Blood transfusion reaction
	(234992005,         'Condition',    TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Plasma cell gingivitis
	(418634005,         'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allergic reaction to substance

	(64572001,         	'Condition', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Disease
	(193570009,         'Condition', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cataract
	(702809001,         'Condition', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Drug reaction with eosinophilia and systemic symptoms
	(238986007,         'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Chemical-induced dermatological disorder
	(702809001,         'Condition', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Drug reaction with eosinophilia and systemic symptoms
	(422593004,         'Condition',    TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Acute renal failure due to ACE inhibitor

	(232032008, 		'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Drug-induced retinopathy
	(448177004,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adverse drug interaction
	(294842007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hematological agents allergy
	--history:on
	(62014003,          'Condition',    TO_DATE('20170810', 'YYYYMMDD'), TO_DATE('20180820', 'YYYYMMDD')), -- Adverse reaction to drug
	(62014003,          'Observation',  TO_DATE('20180820', 'YYYYMMDD'), TO_DATE('20201110', 'YYYYMMDD')), -- Adverse reaction to drug
	--(62014003,          'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adverse reaction to drug
	--history: off
	(956271000000104,   'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Aliskiren allergy
	(1104821000000102,  'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allergy to diagnostic dye
	(201551000000109,   'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allergy to plasters
	(956291000000100,   'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Prasugrel allergy
	(956311000000104,   'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Ticagrelor allergy	--Location
	(325651000000108,   'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Contact allergy
	(275322007,   		'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Scar
	(281647001,         'Observation',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adverse reaction
	(20558004,         	'Condition',  	TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adverse effect of radiation therapy
	(403753000,         'Condition',  	TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adverse cutaneous reaction to acupuncture
	(402763002,         'Condition',  	TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adverse cutaneous reaction to diagnostic procedure
	(56317004,         	'Condition',  	TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Alopecia
	(112401000119106,   'Condition',  	TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Lesion of conjunctiva
	(15250008,   		'Condition',  	TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Disorder of cornea
	(402150002,   		'Condition',  	TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Insect bite reaction

	--Location
	--history:on
	(43741000,      'Place of Service', TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20210217', 'YYYYMMDD')), -- Site of care
	(43741000,      'Visit',            TO_DATE('20210217', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Site of care
	--history:off
	(223496003,      	'Geography',    TO_DATE('20210217', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Geographical and/or political region of the world

	--Observable Entity
	(46680005,          'Measurement',  TO_DATE('20150817', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Vital signs
	(364712009,         'Measurement',  TO_DATE('20150817', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Laboratory test observable

	(310611001,         'Measurement',  TO_DATE('20170830', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cardiovascular measure
	(310611001,         'Measurement',  TO_DATE('20170830', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cardiovascular measure
	(248627000,         'Measurement',  TO_DATE('20171116', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pulse characteristics

	(251880004,         'Measurement',  TO_DATE('20181107', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Respiratory measure [AVOF-1295]

	(1145214003,        'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Histologic feature of proliferative mass
	(246464006,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Function
	(28263002,         	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Crying
	(364665006,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Ability to perform function / activity

	(364678006,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Neuromuscular blockade observable
	(364681001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Waveform observable
	(373629008,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Capillary carbon dioxide tension
	(364048003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Respiratory observable
	(364080001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Feature of left ventricle
	(364081002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Feature of right ventricle
	(364309009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Duration measure of menstruation
	(373063009,         'Measurement',  TO_DATE('20201130', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Substance observable
	(364644000,         'Measurement',  TO_DATE('20201130', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Functional observable
	(364566003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of joint
	(364684009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Body product observable
	(364711002,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Specific test feature
	(373063009,         'Measurement',  TO_DATE('20201130', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Substance observable
	(396277003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Fluid observable
	(386725007,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Body temperature
	(434912009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Blood glucose concentration
	(934171000000101,   'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Blood lead level
	(934191000000102,   'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Blood lead level
	(1107241000000102,  'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Calcium substance concentration in plasma adjusted for albumin
	(1107251000000104,  'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Calcium substance concentration in serum adjusted for albumin
	(434910001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Interstitial fluid glucose concentration
	(395527009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Microscopic specimen observable
	(246116008,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Lesion size
	(439260001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Thromboelastography observable
	(364362002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Obstetric investigative observable
	(364200006,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of urination
	(1240461000000109,  'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measurement of Severe acute respiratory syndrome coronavirus 2 antibody
	(364575001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bone observable
	(804361000000106,   'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bone density scan due date
	(405043008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bone healing status
	(364576000,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Form of bone
	(364577009,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Movement of bone
	(703489001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Anogenital distance
	(246792000,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Eye measure
	(364499003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of lower limb
	(364313002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of menstruation
	(364036001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of nose
	(364247002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of vagina
	(364259003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of uterus
	(364278003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of gravid uterus
	(364467009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of upper limb
	(364276004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of uterine contractions
	(364292009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of cervix
	(364295006,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of ovary
	(364486001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of hand
	(364519002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of foot
	(397274003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Exophthalmometry measurement
	(363978004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of lacrimation
	(364309009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Duration measure of menstruation
	(363939003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of globe
	(248326004,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Body measure
	(302132005,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- American Society of Anesthesiologists physical status class
	(250808000,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Arteriovenous difference
	(364097007,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Feature of pulmonary arterial pressure
	(399048009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Main pulmonary artery peak velocity
	(252091007,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Distal vessel patency
	(364679003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Intracerebral vascular observable
	(398992002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pulmonary vein feature
	(251191008,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cardiac axis
	(251131006,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- AH interval
	(251127000,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Effective refractory period
	(251132004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- HV interval
	(251133009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Wenckebach cycle length
	(408719002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cardiac end-diastolic volume
	(408718005,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cardiac end-systolic volume
	(364077002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Characteristic of heart sound
	(399137004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Feature of left atrium
	(364080001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Feature of left ventricle
	(364081002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Feature of right ventricle
	(364082009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Heart valve feature
	(364067004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cardiac investigative observable
	(399231008,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cardiovascular orifice observable
	(364071001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cardiovascular shunt feature
	(364068009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- ECG feature
	(371846000,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pulmonary valve flow
	(397417004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Regurgitant flow
	(399301000,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Regurgitant fraction
	(248326004,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Body measure
	(396238001,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Tumor measureable
	(371508000,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Tumour stage
	(246116008,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Lesion size
	(364566003,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of joint
	(249948009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Grade of muscle power
	(364574002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of skeletal muscle
	(364580005,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Musculoskeletal measure
	(252124009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Test distance
	(434911002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Plasma glucose concentration
	(935051000000108,   'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Serum adjusted calcium concentration
	(399435001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Specimen measurable
	(102485007,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Personal risk factor
	(364684009,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Body product observable
	(250430006,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Color of specimen
	(115598002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Consistency of specimen
	(314037008,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Serum appearance
	(412835001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Calculus appearance
	(250434002,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Odor of specimen
	(250822000,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Inspiration/expiration time ratio
	(250811004,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Minute volume
	(302132005,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- American Society of Anesthesiologists physical status class
	(250808000,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Arteriovenous difference
	(364678006,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Neuromuscular blockade observable
	(364681001,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Waveform observable
	(373629008,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Capillary carbon dioxide tension
	(397504000,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Organ AND/OR tissue microscopically involved by tumor
	(371509008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Status of peritumoral lymphocyte response
	(404977008,       	'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Skeletal functioning status
	(364055001,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Respiratory characteristics of chest
	(404988002,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Respiratory gas exchange status
	(404996007,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Airway patency status
	(75098008,          'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Flow history
	(364055001,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Respiratory characteristics of chest
	(400987003,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Asthma trigger
	(364053008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Characteristic of respiratory tract function
	(364049006,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Lower respiratory tract observable
	(366874008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Number of asthma exacerbations in past year
	(723245007,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Number of chronic obstructive pulmonary disease exacerbations in past year
	(364062005,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Respiration observable

	(871562009,         'Measurement',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Detection of Severe acute respiratory syndrome coronavirus 2
	(1240471000000102,  'Measurement',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measurement of Severe acute respiratory syndrome coronavirus 2 antigen
	(80943009,          'Measurement',  TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Risk factor

	(263605001,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Length dimension of neoplasm
	(4370001000004107,  'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Length of excised tissue specimen
	(443527007,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Number of lymph nodes containing metastatic neoplasm in excised specimen
	(396236002,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Depth of invasion by tumour
	(396239009,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Horizontal extent of stromal invasion by tumour
	(371490004,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Distance of tumour from anal verge
	(258261001,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Tumour volume
	(371503009,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Tumour weight
	(444916005,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Percentage of carcinoma in situ in neoplasm
	(444775005,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Average intensity of positive staining neoplastic cells
	(385404000,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Tumour quantitation
	(405930005,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Number of tumour nodules
	(385300008,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Linear extent of involvement of carcinoma
	(444025001,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Number of lymph nodes examined by microscopy in excised specimen
	(444644009,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Number fraction of oestrogen receptors in neoplasm using immune stain
	(445366002,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Number fraction of progesterone receptors in neoplasm using immune stain
	(399514000,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Distance of anterior margin of tumour base from limbus of cornea at cut edge, after sectioning
	(396988001,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Distance of posterior margin of tumour base from edge of optic disc, after sectioning
	(405921002,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Percentage of tumour involved by necrosis
	(396987006,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Distance from anterior edge of tumour to limbus of cornea at cut edge, after sectioning
	(786458005,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Self reported usual body weight
	(409652008,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Population statistic
	(165109007,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Basal metabolic rate
	(7928001,           'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Body oxygen consumption
	(698834005,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Metabolic equivalent of task
	(251836004,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Nitrogen balance
	(16206004,          'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Oxygen delivery
	(251831009,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Oxygen extraction ratio
	(251832002,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Oxygen uptake
	(74427007,          'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Respiratory quotient
	(251838003,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Total body potassium
	(409652008,         'Measurement',  TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Population statistic


	(871560001,			'Measurement',  TO_DATE('20230712', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Detection of ribonucleic acid of severe acute respiratory syndrome coronavirus 2 using polymerase chain reaction (observable entity)
	(363870007,        	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Mental state, behavior / psychosocial function observable
	(1099121000000104,  'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Young Townson FootSkin Hydration Scale for Diabetic Neuropathy level
	(865939009,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Active insulin time
	(872121000000100,  	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Frequency of hyperglycaemic episodes
	(712656006,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Frequency of hypoglycemia attack
	(789480007,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Insulin dose
	(736101003,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Insulin infusion rate
	(789496005,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Insulin to carbohydrate ratio
	(874181000000108,  	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Time since last hyperglycaemic episode
	(442547005,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Number of alcohol units consumed on heaviest drinking day
	(228330005,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Total time drunk alcohol
	(228329000,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Time since stopped drinking
	(103208001,        	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Erythrocyte sedimentation rate
	(417595002,        	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cell feature
	(165581004,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- International normalized ratio
	(368481000000103,  	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bowel cancer screening programme: faecal occult blood result
	(364465001,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Size of upper limb
	(299220001,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Leg size
	(249363002,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adenoids size
	(364032004,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Size of nose
	(364231004,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Size of vagina
	(364224003,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Size of vulval structure
	(248944004,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Uterus size
	(248913008,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Uterine cervix size
	(248955004,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Ovary size
	(364472000,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Size of clavicle
	(364470008,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Size of scapula
	(363953003,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Size of pupil
	(363937001,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Size of globe
	(422149008,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Optic disc size
	(249050003,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Fetus size
	(364616001,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of fetus
	(251682005,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Fetal kick count
	(249046005,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Number of fetal hearts heard
	(363983007,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Visual acuity
	(311528003,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Visual scanning speed
	(251794006,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Refraction
	(246648006,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Visual image size
	(423083007,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Glaucoma hemifield test
	(419862005,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Accommodative amplitude
	(251837008,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Total body water
	(364333003,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of labor
	(364564000,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Range of joint movement
	(364286003,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adenoids size
	(364539003,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of skin
	(264752007,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Grading values
	(1285654008,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Identification of bacteria by matrix assisted laser desorption ionization time of flight mass spectrometry
	(363891000119100,  	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Identification of bacteria in sputum by culture
	(1285667006,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Identification of fungus by matrix assisted laser desorption ionization time of flight mass spectrometry
	(365931000119109,  	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Identification of organism in respiratory smear by Gram stain
	(365971000119107,  	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Identification of organism in smear by Gram stain
	(372431000119101,  	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Identification of organism in wet smear by potassium hydroxide preparation
	(375771000119100,  	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Identification of ova and parasites in fecal smear by concentration and trichrome stain
	(143481000237106,  	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Fluid chemistry observable
	(143471000237109,  	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Microbiology laboratory observable
	(1290195007,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Detection of antibody to infective organism
	(4401000237103,  	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Mass concentration ratio of immunoglobulin G antibody to albumin in cerebrospinal fluid
	(143441000237100,  	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Clinical chemistry observable
	(164835000,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Limb length
	(106054005,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Lung volume AND/OR capacity
	(70337006,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cardiovascular function
	(11953005,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Renal function
	(130953005,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Rate of urine output, function
	(985791000000107,  	'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Total fluid estimated need
	(364400009,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Feature of fluid loss
	(1179058006,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Estimated quantity of intake of fluid
	(364399002,  		'Measurement',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measure of fluid intake

	(363884002,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Recognition observable
	(6769007,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Attention
	(311718005,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cognitive discrimination
	(363885001,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Characteristic of intellect
	(312012004,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cognitive function: awareness
	(311534005,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Conceptualization
	(247583006,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Decision making
	(311507007,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Executive cognitive functions
	(870552008,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Health literacy
	(311544007,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Information processing
	(27026000,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Insight
	(247572002,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Intellect
	(22851009,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Intelligence
	(311841007,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Intelligibility
	(85721008,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Intuition
	(61909002,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Language
	(69998004,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Intelligibility
	(311841007,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Learning
	(363886000,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Learning observable
	(312016001,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Metacognition
	(43173001,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Orientation
	(81742003,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Perception
	(71565002,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Personality
	(247581008,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Problem solving
	(311545008,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Processing accuracy
	(311546009,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Processing capacity
	(304685003,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Processing speed
	(363884002,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Recognition observable
	(307081003,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Spatial awareness
	(311552005,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Spatial orientation
	(698829006,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Straightforward decision making
	(88952004,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Thinking
	(311505004,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Visual processing
	(363871006,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Mental state
	(363910003,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Characteristic of psychosocial functioning
	(363887009,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Memory observable
	(363896009,        	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Behavior observable
	(364287007,  		'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Feature of consistency of cervical mucous

	-- Physical Object
	(303624006,        	'Device', 		TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Musculoskeletal device
	(303620002,        	'Device', 		TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Urogenital device
	(360009006,        	'Device', 		TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pressure garments
	(272179000,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Domestic, office and garden artifact
	(705620005,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Floor mat
	(456151000124107,   'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Foreign body
	(80519002,        	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hospital furniture, device
	(312201009,        	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Instrument of aggression
	(50833004,        	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Paper
	(303491000,        	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Personal effects and clothing
	(278211009,        	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Printed material
	(261324000,        	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Vehicle
	(709280007,        	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Walking surface of room
	(61284002,        	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Machine
	(105799003,        	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Household device
	(40188005,        	'Observation', 	TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Household accessory

	--Pharma/Biol Product
	--history:on
	(373783004,         'Observation',  TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20190418', 'YYYYMMDD')), -- dietary product, exception of Pharmaceutical / biologic product
	(373783004,         'Device',       TO_DATE('20190418', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- dietary product, exception of Pharmaceutical / biologic product
	--history:off
	--history:on
	(49062001,          'Device',       TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20141231', 'YYYYMMDD')), -- Device
	(49062001,          'Device',       TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Device
	--history:off
	(763087004,         'Drug',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Medicinal product categorized by therapeutic role
	(2949005,           'Device',  		TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- diagnostic aid
	(410652009,         'Device',       TO_DATE('20171128', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Blood product [AVOF-731]
	(709080004,         'Observation', TO_DATE('20180821', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Diagnostic allergen product
	(407935004,         'Device',      TO_DATE('20190418', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Contrast media
	(768697005,         'Device',      TO_DATE('20190418', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Barium and barium compound product -- contrast media subcathegory
	(116178008,         'Device',      TO_DATE('20190418', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dialysis fluid
	(327838005,         'Device',      TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Intravenous nutrition
	(226311003,         'Device',      TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dietary fiber supplementation
	(411115002,         'Device',      TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Drug-device combination product
	(12222501000001106, 'Device',		TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Virtual radiopharmaceutical moiety
	(736542009,         'Drug',  		TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Pharmaceutical dose form
--	(736478001,         'Drug',  		TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Basic dose form

	--Procedure
	--history:on
	(122869004,         'Measurement', TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), --Measurement
	(122869004,         'Measurement', TO_DATE('20150311', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Measurement
	--history:off
	--history:on
	(113021009,         'Procedure',   TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20150119', 'YYYYMMDD')), -- Cardiovascular measurement
	(113021009,         'Procedure',   TO_DATE('20150311', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cardiovascular measurement
	--history:off
	(14734007,          'Observation', TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Administrative procedure

	(429159005,         'Procedure',   TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Child psychotherapy
	(15220000,          'Measurement', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Laboratory test
	(225365006,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Care regime
	(309466006,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Clinical observation regime
	(225318000,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Personal and environmental management regime
	(133877004,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Therapeutic regimen
	(225367003,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Toileting regime
	(308335008,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Patient encounter procedure
	(225288009,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Environmental care procedure
	(239516002,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Monitoring procedure
	(389084004,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Staff related procedure
	(228114008,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Child health procedures
	(389067005,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Community health procedure
	(59524001,          'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Blood bank procedure
	(243114000,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Support
	(372038002,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Advocacy
	(110461004,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adjunctive care
	(303163003,         'Observation', TO_DATE('20150119', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Treatments administered under the provisions of the law

	(278414003,         'Procedure',   TO_DATE('20160616', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pain management
	(363259005,         'Observation', TO_DATE('20160616', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Patient management procedure

	(268444004,         'Measurement', TO_DATE('20181107', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Radionuclide red cell mass measurement

	(108246006,         'Measurement', TO_DATE('20191113', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Tonometry AND/OR tonography procedure
	(61746007,          'Measurement', TO_DATE('20200312', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Taking patient vital signs
	(117617002,         'Measurement', TO_DATE('20200428', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Immunohistochemistry procedure
	(404933001,         'Measurement', TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Berg balance test
	(1321161000000104,  'Visit',       TO_DATE('20200518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Household quarantine to prevent exposure of community to contagion
	(1321151000000102,  'Visit',       TO_DATE('20200518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Reverse self-isolation of uninfected subject to prevent exposure to contagion
	(1321141000000100,  'Visit',       TO_DATE('20200518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Reverse isolation of household to prevent exposure of uninfected subject to contagion
	(1321131000000109,  'Visit',       TO_DATE('20200518', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Self quarantine and similar

	(20135006,          'Measurement', TO_DATE('20210127', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Screening procedure

	(59000001,          'Procedure',   TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Surgical pathology consultation and report on referred slides prepared elsewhere

	(373110003,         'Procedure',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Emergency procedure
	(118292001,         'Procedure',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Removal
	(128967005,         'Procedure',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Exercise challenge
	(91251008,       	'Procedure',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Physical therapy procedure
	(711540006,       	'Procedure',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- MRI of breast for screening
	(31687009,       	'Procedure',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Multiphasic screening procedure
	(444783004,       	'Procedure',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Screening colonoscopy
	(24623002,       	'Procedure',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Screening mammography
	(3421000175104,     'Procedure',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Video screen time assessment
	(472824009,    	 	'Procedure',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Fetal echocardiography screening
	(716035006,    	 	'Procedure',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Scintimammography for malignant neoplasm screening
	(88884005,          'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Alpha-1-antitrypsin phenotyping
	(851211000000105,   'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Assessment of sedation level
	(37859006,          'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pulmonary ventilation perfusion study
	(30058000,          'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Therapeutic drug monitoring assay
	(441967009,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Evaluation of cerebrospinal fluid
	(104145007,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hemoglobin electrophoresis
	(430509005,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Examination of fluid specimen
	(401289003,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Methicillin resistant Staphylococcus aureus screening test
	(413063005,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Acinetobacter species screening test
	(395142003,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allergy screening test
	(401300000,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Atypical pneumonia screening test
	(252144003,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Biochemical test
	(164790002,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Breath test
	(400984005,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Congenital hypothyroidism screening test
	(391898007,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Fetal oxytocin stress test
	(269817005,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Glucose-6-phosphate dehydrogenase test
	(395059005,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hemoglobinopathy screening test
	(391541008,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Glandular fever screening test
	(425732004,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hemorrhagic fever virus serology screening test
	(394981005,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- HEp-2 cell autoantibody screening test
	(391541008,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Glandular fever screening test
	(391513009,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- ICT malaria screening test
	(108253002,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Laboratory test panel
	(314094003,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Lupus anticoagulant screening test
	(395118002,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Metabolic screening test
	(252243002,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pancreatic function test
	(442220001,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Progesterone withdrawal test
	(52424002,         	'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Provocative test
	(395056003,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Rotavirus screening test
	(314098000,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Rubella screening test
	(53309004,         	'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Skin test
	(15695009,         	'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Stimulation test
	(50947004,         	'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Suppression test
	(314089003,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Thrombophilia screening test
	(391364009,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Toxoplasma screening test
	(395057007,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Trichomonas screening test
	(395161004,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Triple screening test
	(840285005,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Vestibular evoked myogenic potential test
	(401129008,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- von Willebrand screening test
	(408268003,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- 24 hour Bence-Jones screening test
	(413013000,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- 24 hour urine screening for urinary stone formation measurement
	(164961002,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Physiological function tests
	(252567006,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Sleep latency test
	(164807004,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Special female genital test
	(164822009,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Special male genital test
	(164814002,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Postcoital test
	(252222003,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Gastrointestinal tract function test
	(167252002,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Urine pregnancy test
	(252801000,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Ophthalmological test
	(445536008,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Assessment using assessment scale
	(250221001,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Detection of hemoglobin
	(42106004,         	'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Capillary fragility test
	(252468003,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Digital rewarming test
	(840707001,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allen test for arterial competency
	(252441003,         'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Buerger's test
	(31724009,         	'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Measurement of venous pressure
	(21727005,         	'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Audiometric test
	(77667008,         	'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Therapeutic drug monitoring, qualitative
	(183452005,         'Observation', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Emergency hospital admission
	(183851006,         'Observation', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Referral to clinic
	(105396008,         'Observation', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Visit of patient by chaplain
	(699823003,    	    'Observation', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Provision of written information
	(229252009,    	    'Observation', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Active joint movements
	(84478008,    	    'Observation', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Occupational therapy
	(12799001,    	    'Observation', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Physiotherapy class activities
	(409073007,    	    'Observation', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Education
	(252314007,  		'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Blood transfusion test
	(16830007,  		'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Visual acuity testing
	(441813004,  		'Measurement', TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Evaluation of peritoneal fluid

	--Qualifier Value
	(260245000,         'Meas Value',   TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Finding Value
	--history:on
	(284009009,         'Drug',         TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20171116', 'YYYYMMDD')), -- Route of administration value
	(284009009,         'Route',        TO_DATE('20171116', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Route of administration value
	--history:off
	--history:on
	(385285004,         'Drug',         TO_DATE('20150518', 'YYYYMMDD'), TO_DATE('20230925', 'YYYYMMDD')), -- dialysis dosage form
	(385285004,  		'Device',       TO_DATE('20230925', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Dialysis dosage form
	--history:off

	(421347001,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Cutaneous aerosol
	(105904009,         'Drug',         TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Type of drug preparation

	(767524001,         'Unit',         TO_DATE('20190211', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --  Unit of measure (Top unit)
	(8653201000001106,  'Drug',         TO_DATE('20190827', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --dm+d value

	(260299005,         'Meas Value',   TO_DATE('20201117', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Number [AVOF-2893]
	(272063003,         'Meas Value',   TO_DATE('20201117', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Alphanumeric[AVOF-2893]

	(371234007,         'Meas Value',   TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Color modifier
	(272104009,         'Meas Value',   TO_DATE('20220504', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Absolute times
	(297289008,         'Language',  	TO_DATE('20221030', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --World languages

	(276135000,         'Meas Value Operator',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Mathematical sign

	(423335001,  		'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Device form

	(10984111000001107, 'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Medicated plaster
	(385281008,  		'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Radiopharmaceutical dosage form
	(278474008,  		'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Types of contrast medium
	(9906801000001108,  'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Nebuliser
	(90213003,         	'Meas Value',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --False positive
	(61707005,         	'Meas Value',   TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --False negative
	(420719007,         'Route',   		TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Intraventricular route

-- Social context
	--history:on
	(223366009,   'Provider Specialty', TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20190201', 'YYYYMMDD')), -- Healthcare professional
	(223366009,         'Provider',     TO_DATE('20190201', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Healthcare professional
	--history:off
	(372148003,         'Race',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Ethnic group
	(415229000,         'Race',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Racial group
	(125677006,         'Relationship', TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Relationship
	(224620002,         'Observation', 	TO_DATE('20230925', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Human aid to communication

	--Substance
	(264301008,         'Observation',  TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Psychoactive substance of abuse - non-pharmaceutical
	(289964002,         'Device',       TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Surgical material
	(418920007,         'Device',       TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Adhesive agent
	(255922001,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dental material
	(118417008,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Filling material
	(445214009,         'Device',       TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- corneal storage medium
	--history:on
	(373782009,         'Observation',  TO_DATE('20141231', 'YYYYMMDD'), TO_DATE('20180208', 'YYYYMMDD')), -- diagnostic substance, exception of drug
	(373782009,         'Device',       TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- diagnostic substance, exception of drug
	--history:off
	(410942007,         'Drug',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Drug or medicament
	(111160004,         'Drug',         TO_DATE('20141218', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Sodium iodide (131-I)
	(385420005,         'Device',       TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Contrast media
	(419148000,         'Device',       TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Diagnostic dye
	(766886003,         'Device',       TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Technetium (99m-Tc) bicisate
	(373222005,         'Device',       TO_DATE('20180208', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Disinfectants and cleansers
	(332525008,         'Device',       TO_DATE('20190418', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')),  --Camouflaging preparations
	(771387000,         'Drug',         TO_DATE('20200312', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Substance with effector mechanism of action

	(418672000,         'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Vitreoretinal surgical agent
	(373517009,         'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Protective agent (for skin)
	(109192009,         'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Hysteroscopy fluid
	(14399003,          'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Iodine radioisotope
	(373569004,         'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Flea and tick agent
	(373545003,         'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Replacement agent
	(373724007,         'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Colloidal oatmeal powder
	(289122001,         'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cosmetic material
	(256673003,         'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Mucosa, skin and subcutaneous material
	(256899007,         'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Cardiovascular material
	(418588009,         'Device',       TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dusting powder agent

	(255640000,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Biocide
	(301054007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Phytochemical
	(106181007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Immunologic substance
	(418297009,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pharmaceutical base or inactive agent
	(419556005,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Medical gas
	(57795002,         	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Chemical element
	(412232009,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Microbial agent
	(762766007,         'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), --Edible substance
	(33638001,       	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Isotope
	(767266004,       	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Iodine and iodine compound
	(28268006,       	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pregnanediol
	(71159008,       	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Pregnanetriol
	(771388005,       	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Molecular messenger
	(43218009,       	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Allo-cortols
	(706932000,       	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Free progesterone
	(61789006,       	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Dye
	(301434004,       	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Turpentine or derivative
	(409893003,       	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Bisacodyl metabolites
	(47389008,       	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Methyl tert-butyl ether
	(706933005,       	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Free phenytoin
	(68329003,       	'Observation',  TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Fuller's earth
	(39248411000001101, 'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Sodium iodide (131-I)
	(1368003, 			'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Iodine-131
	(33271006, 			'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Iodohippurate (131-I) sodium
	(33785000, 			'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Iodine (125-I) liothyronine
	(432884004,			'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Chlorotoxin (131-I)
	(765010006, 		'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Iodine (131-I) labeled monoclonal antibody
	(765117007,			'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Iodine (131-I) ethiodized oil
	(373273002,         'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- General inhalation anesthetic
	(373703002,  		'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Intravenous fluids and electrolytes
	(373523004,  		'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Skin antifungal agent
	(417901007,  		'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Oxymetazoline
	(255955006,  		'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Local anesthetic allergen
	(406463001,  		'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')), -- Drug allergen
	(782573007,  		'Drug',         TO_DATE('20230914', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD')) -- Glycerol phenylbutyrate

) AS a

UNION ALL

SELECT b.* FROM (VALUES
	--history:on
	(364066008,         'Measurement',  TO_DATE('20201110', 'YYYYMMDD'), TO_DATE('20201210', 'YYYYMMDD'), NULL), --Cardiovascular observable
	(364066008,         'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 1), --Cardiovascular observable
	(364066008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0), --Cardiovascular observable
	--history:off
	(405805006,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0), --Cardiac resuscitation outcome
	(405801002,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0), --Coronary reperfusion type
	(364072008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0), --Cardiac feature
	(364087003,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0),  --Blood vessel feature
	(364069001,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0),  --Cardiac conduction system feature
	(427751006,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0),  --Extent of cardiac perfusion defect
	(429162008,         'Observation',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0),  --Extent of myocardial stress ischemia
	(1099111000000105,  'Measurement',  TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 1),  --Thrombolysis In Myocardial Infarction risk score for unstable angina or non-ST-segment-elevation myocardial infarction
	(24942001,  		'Condition',  	TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0),  --Urobilinogenuria
	(18165001,  		'Condition',  	TO_DATE('20201210', 'YYYYMMDD'), TO_DATE('20991231', 'YYYYMMDD'), 0)  --Jaundice
				) as b
;

END;
$BODY$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;