/*******************************************************************************
Script to update all domain_id and standard_concept fields to records in SNOMED

This script expects the following tables ready:
- concept_stage, with class_concept_id already filled
- snomed_ancestor: same as concept_ancestor except 
  - only containing snomed concetps
  - all records participate (no removal where standard_concept is null)
  - instead of concept_id use concept_code
********************************************************************************/


-- 1. Manually create table with "Peaks" = ancestors of records that are all of the same domain
-- drop table peak;
create table peak (
	peak_code varchar(20), --the id of the top ancestor
	peak_domain_id varchar(20), -- the domain to assign to all its children
	ranked integer -- number for the order in which to assign
);

-- Fill in the various peak concepts
insert into peak (peak_code, peak_domain_id) values (243796009, 'Observation'); -- 'Context-dependent category' that has no ancestor
insert into peak (peak_code, peak_domain_id) values (138875005, 'Observation'); -- root
insert into peak (peak_code, peak_domain_id) values (223366009, 'Provider Specialty');
insert into peak (peak_code, peak_domain_id) values (43741000, 'Place of Service');	  -- Site of care
insert into peak (peak_code, peak_domain_id) values (420056007, 'Drug'); -- Aromatherapy agent
insert into peak (peak_code, peak_domain_id) values (373873005, 'Drug'); -- Pharmaceutical / biologic product
insert into peak (peak_code, peak_domain_id) values (410942007, 'Drug'); --	Drug or medicament
insert into peak (peak_code, peak_domain_id) values (49062001, 'Device');
insert into peak (peak_code, peak_domain_id) values (289964002, 'Device'); -- Surgical material
insert into peak (peak_code, peak_domain_id) values (260667007, 'Device'); -- Graft
insert into peak (peak_code, peak_domain_id) values (418920007, 'Device'); -- Adhesive agent
insert into peak (peak_code, peak_domain_id) values (404684003, 'Condition'); -- Clinical Finding
insert into peak (peak_code, peak_domain_id) values (218496004, 'Condition'); -- Adverse reaction to primarily systemic agents
insert into peak (peak_code, peak_domain_id) values (313413008, 'Condition'); -- Calculus observation
insert into peak (peak_code, peak_domain_id) values (118245000, 'Measurement'); -- 'Finding by measurement'
insert into peak (peak_code, peak_domain_id) values (365854008, 'Observation'); -- 'History finding'
insert into peak (peak_code, peak_domain_id) values (118233009, 'Observation'); -- 'Finding of activity of daily living'
insert into peak (peak_code, peak_domain_id) values (307824009, 'Observation');-- 'Administrative statuses'
		-- 40416814, 'Observation'); Causes of injury and poisoning'
		-- 40418184,  -- '[X]External causes of morbidity and mortality'
insert into peak (peak_code, peak_domain_id) values (162408000, 'Observation'); -- Symptom description
-- insert into peak (peak_code, peak_domain_id) values (4084137,	'Observation');-- Sample observation
insert into peak (peak_code, peak_domain_id) values (105729006, 'Observation'); -- 'Health perception, health management pattern'
insert into peak (peak_code, peak_domain_id) values (162566001, 'Observation'); --'Patient not aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (65367001, 'Observation'); --'Victim status'
insert into peak (peak_code, peak_domain_id) values (162565002, 'Observation'); --'Patient aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (418138009, 'Observation'); --Patient condition finding
insert into peak (peak_code, peak_domain_id) values (405503005, 'Observation'); --'Staff member inattention'
insert into peak (peak_code, peak_domain_id) values (405536006, 'Observation'); --'Staff member ill'
insert into peak (peak_code, peak_domain_id) values (405502000, 'Observation'); --'Staff member distraction'
insert into peak (peak_code, peak_domain_id) values (398051009, 'Observation'); --Staff member fatigued
insert into peak (peak_code, peak_domain_id) values (398087002, 'Observation'); --Staff member inadequately assisted
insert into peak (peak_code, peak_domain_id) values (397976005, 'Observation'); --Staff member inadequately supervised
insert into peak (peak_code, peak_domain_id) values (162568000, 'Observation');--'Family not aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (162567005, 'Observation'); --'Family aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (42045007, 'Observation'); --Acceptance of illness
insert into peak (peak_code, peak_domain_id) values (108329005, 'Observation'); --	Social context condition
insert into peak (peak_code, peak_domain_id) values (309298003, 'Observation'); -- Drug therapy observations
insert into peak (peak_code, peak_domain_id) values (48340000, 'Condition'); --Incontinence
-- insert into peak (peak_code, peak_domain_id) values (4025202, 'Condition'); --Elimination pattern
-- insert into peak (peak_code, peak_domain_id) values (4186437, 'Condition'); -- Urinary elimination alteration
--		4266236, 'Observation'); --'Cancer-related substance' - 4228508
insert into peak (peak_code, peak_domain_id) values (108252007, 'Measurement'); --'Laboratory procedures'
insert into peak (peak_code, peak_domain_id) values (122869004, 'Measurement'); --'Measurement'
-- 		4236002, 'Observation'); --'Allergen class'
-- 		4019381, 'Observation'); --'Biological substance'
--		4240422 -- 'Human body substance'
insert into peak (peak_code, peak_domain_id) values (118246004, 'Measurement');	-- 'Laboratory test finding' - child of excluded Sample observation
insert into peak (peak_code, peak_domain_id) values (71388002, 'Procedure'); --'Procedure'
insert into peak (peak_code, peak_domain_id) values (304252001, 'Procedure'); -- Resuscitate
insert into peak (peak_code, peak_domain_id) values (304253006, 'Procedure'); --DNR
insert into peak (peak_code, peak_domain_id) values (113021009, 'Procedure'); -- Cardiovascular measurement
insert into peak (peak_code, peak_domain_id) values (297249002, 'Observation'); --Family history of procedure
insert into peak (peak_code, peak_domain_id) values (14734007, 'Observation'); --Administrative procedure
insert into peak (peak_code, peak_domain_id) values (416940007, 'Observation'); --Past history of procedure
insert into peak (peak_code, peak_domain_id) values (183932001, 'Observation');-- Procedure contraindicated
insert into peak (peak_code, peak_domain_id) values (438833006, 'Observation');-- Administration of drug or medicament contraindicated
insert into peak (peak_code, peak_domain_id) values (442564008, 'Observation'); --Evaluation of urine specimen
insert into peak (peak_code, peak_domain_id) values (410684002, 'Observation'); -- Drug therapy status
insert into peak (peak_code, peak_domain_id) values (64108007, 'Procedure'); --Blood unit processing - inside Measurements
insert into peak (peak_code, peak_domain_id) values (17636008, 'Procedure'); -- Specimen collection treatments and procedures - - bad child of 4028908	Laboratory procedure
insert into peak (peak_code, peak_domain_id) values (365873007, 'Gender'); -- Gender
insert into peak (peak_code, peak_domain_id) values (372148003, 'Race'); --Ethnic group
insert into peak (peak_code, peak_domain_id) values (415229000, 'Race'); -- Racial group
insert into peak (peak_code, peak_domain_id) values (900000000000441003, 'Metadata'); -- SNOMED CT Model Component
insert into peak (peak_code, peak_domain_id) values (106237007, 'Observation'); -- Linkage concept
insert into peak (peak_code, peak_domain_id) values (258666001, 'Unit'); -- Top unit
insert into peak (peak_code, peak_domain_id) values (260245000, 'Meas Value'); -- Meas Value
insert into peak (peak_code, peak_domain_id) values (125677006, 'Relationship'); -- Relationship

-- 2. Ancestors inherit the domain_id and standard_concept of their Peaks. However, the ancestors of Peaks are overlapping.
-- Therefore, the order by which the inheritance is passed depends on the "height" in the hierarchy: The lower the peak, the later it should be run
-- The following creates the right order by counting the number of ancestors: The more ancestors the lower in the hierarchy.
-- This could go wrong if a parallel fork happens
UPDATE peak p
   SET p.ranked =
          (SELECT rnk
             FROM (  SELECT ranked.pd AS peak_code, COUNT (*) AS rnk
                       FROM (SELECT DISTINCT
                                    pa.peak_code AS pa, pd.peak_code AS pd
                               FROM peak pa,
                                    snomed_ancestor a,
                                    peak pd
                              WHERE     a.ancestor_concept_code = pa.peak_code
                                    AND a.descendant_concept_code = pd.peak_code
                                    ) ranked
                   GROUP BY ranked.pd) r
            WHERE r.peak_code = p.peak_code);

-- 3. Find clashes, where one child has two or more Peak concepts as ancestors and display them with ordered by levels of separation
-- Currently these clashes are dealt with by precedence, not through rank. This might need to change
-- Also, this script needs to do this within a rank. Not done yet.
SELECT conflict.concept_name AS child,
         min_levels_of_separation AS MIN,
         d.peak_domain_id,
         c.concept_name AS peak,
         c.concept_class_id AS peak_class_id
    FROM snomed_ancestor a,
         concept_stage c,
         peak d,
         concept_stage conflict
   WHERE     a.descendant_concept_code IN (SELECT concept_code
                                             FROM (  SELECT child.concept_code,
                                                            COUNT (*)
                                                       FROM (SELECT DISTINCT
                                                                    p.peak_domain_id,
                                                                    a.descendant_concept_code
                                                                       AS concept_code
                                                               FROM peak p,
                                                                    snomed_ancestor a
                                                              WHERE a.ancestor_concept_code =
                                                                    p.peak_code)
                                                            child
                                                   GROUP BY child.concept_code
                                                     HAVING COUNT (*) > 1)
                                                  clash)
         AND c.concept_code = a.ancestor_concept_code
         AND c.concept_code = d.peak_code
         AND conflict.concept_code = a.descendant_concept_code
ORDER BY conflict.concept_name, min_levels_of_separation, c.concept_name;

-- 4. Find other peak concepts (orphans) that are missed from the above manual list, and assign them a domain_id based on heuristic. 
-- Peak concepts are those ancestors that are not also descendants somewhere, except in their own record
-- If there are mistakes, the manual list needs be updated and everything re-run
INSERT INTO peak -- before doing that check first out without the insert
   SELECT DISTINCT
          c.concept_code AS peak_code,
          CASE
             WHEN c.concept_class_id = 'Clinical finding'
             THEN
                'Condition'
             WHEN c.concept_class_id = 'Model component'
             THEN
                'Metadata'
             WHEN c.concept_class_id = 'Observable entity'
             THEN
                'Observation'
             WHEN c.concept_class_id = 'Organism'
             THEN
                'Observation'
             WHEN c.concept_class_id = 'Pharmaceutical / biologic product'
             THEN
                'Drug'
             ELSE
                'Manual'
          END
             AS peak_domain_id,
          NULL AS ranked
     FROM snomed_ancestor a, concept_stage c
    WHERE     a.ancestor_concept_code NOT IN (SELECT DISTINCT
                                                     descendant_concept_code
                                                FROM snomed_ancestor
                                               WHERE ancestor_concept_code !=
                                                        descendant_concept_code)
          AND c.concept_code = a.ancestor_concept_code
          AND c.vocabulary_id='SNOMED';


-- 5. Start building domains, preassign all them with "Not assigned"
-- drop table domain_snomed purge;
CREATE TABLE domain_snomed
AS
   SELECT concept_code, CAST ('Not assigned' AS VARCHAR2 (20)) AS domain_id
     FROM concept_stage
    WHERE vocabulary_id = 'SNOMED';

-- 6. Pass out domain_ids
-- Method 1: Assign domains to children of peak concepts in the order rank, and within rank by order of precedence
-- Do that for all peaks by order of ranks. The highest first, the lower ones second, etc.

BEGIN
   FOR A IN (  SELECT DISTINCT ranked
                 FROM peak
                WHERE ranked IS NOT NULL
             ORDER BY ranked)
   LOOP
      UPDATE domain_snomed d
         SET d.domain_id =
                (SELECT child.peak_domain_id
                   FROM (SELECT DISTINCT
                                -- if there are two conflicting domains in the rank (both equally distant from the ancestor) then use precedence
                                FIRST_VALUE (
                                   p.peak_domain_id)
                                OVER (
                                   PARTITION BY a.descendant_concept_code
                                   ORDER BY
                                      DECODE (peak_domain_id,
                                              'Measurement', 1,
                                              'Procedure', 2,
                                              'Device', 3,
                                              'Condition', 4,
                                              'Provider', 5,
                                              'Drug', 6,
                                              'Gender', 7,
                                              'Race', 8,
                                              10) -- everything else is Observation
                                                 )
                                   AS peak_domain_id,
                                a.descendant_concept_code AS concept_code
                           FROM peak p, snomed_ancestor a
                          WHERE     a.ancestor_concept_code = p.peak_code
                                AND p.ranked = A.ranked) child
                  WHERE child.concept_code = d.concept_code)
       WHERE d.concept_code IN (SELECT a.descendant_concept_code
                                  FROM peak p, snomed_ancestor a
                                 WHERE     a.ancestor_concept_code = p.peak_code);
   END LOOP;

   COMMIT;
END;

-- Check orphans whether they contain mixed children with different multiple concept_class_ids or domains. 
-- If they have mixed children, the concept_class_id-based heuristic might create problems
-- Add those to the peak table (including assigning domains to the various descendants) and re-run
  SELECT DISTINCT orphan.concept_code,
                  orphan.concept_name,
                  child.concept_class_id,
                  d.domain_id
    FROM (SELECT DISTINCT c.concept_code, concept_name
            FROM snomed_ancestor a, concept_stage c
           WHERE     a.ancestor_concept_code NOT IN (SELECT DISTINCT
                                                            descendant_concept_code
                                                       FROM snomed_ancestor
                                                      WHERE ancestor_concept_code !=
                                                               descendant_concept_code)
                 AND c.concept_code = a.ancestor_concept_code
                 AND c.concept_code NOT IN (SELECT DISTINCT peak_code
                                            FROM peak)) orphan
         JOIN snomed_ancestor a
            ON a.ancestor_concept_code = orphan.concept_code
         JOIN domain_snomed d ON d.concept_code = a.descendant_concept_code
         JOIN concept child ON child.concept_code = a.descendant_concept_code
ORDER BY 1;

-- Method 2: For those that slipped through the cracks assign domains by using the class_concept_id
-- Check out which these are and potentially fix and re-run Method 1
UPDATE domain_snomed d
   SET d.domain_id =
          (SELECT CASE c.concept_class_id
                     WHEN 'Clinical Finding' THEN 'Condition'
                     WHEN 'Procedure' THEN 'Procedure'
                     WHEN 'Pharma/Biol Product' THEN 'Drug'
                     WHEN 'Physical Object' THEN 'Device'
                     WHEN 'Model comp' THEN 'Metadata'
                     ELSE 'Observation'
                  END
             FROM concept_stage c
            WHERE     c.concept_code = d.concept_code
                  AND C.VOCABULARY_ID = 'SNOMED')
 WHERE d.domain_id = 'Not assigned';

-- 7. Update concept_stage from newly created domains.

CREATE INDEX idx_domain_cc
   ON domain_snomed (concept_code);

UPDATE concept_stage c
   SET c.domain_id =
          (SELECT d.domain_id
             FROM domain_snomed d
            WHERE d.concept_code = c.concept_code)
 WHERE C.VOCABULARY_ID = 'SNOMED';



UPDATE concept_stage c
   SET c.domain_id = 'Route'
 WHERE concept_code IN ('255560000',
                        '255582007',
                        '258160008',
                        '260540009',
                        '260548002',
                        '264049007',
                        '263887005',
                        '372468001',
                        '72607000',
                        '359540000',
                        '90028008');

UPDATE concept_stage c
   SET c.domain_id = 'Spec Anatomic Site'
 WHERE concept_class_id = 'Body Structure';

UPDATE concept_stage c
   SET c.domain_id = 'Specimen'
 WHERE concept_class_id = 'Specimen';

UPDATE concept_stage c
   SET c.domain_id = 'Meas Value Operator'
 WHERE concept_code IN ('255560000',
                        '255582007',
                        '258160008',
                        '260540009',
                        '260548002',
                        '264049007',
                        '263887005',
                        '372468001',
                        '72607000',
                        '359540000',
                        '90028008');

UPDATE concept_stage c
   SET c.domain_id = 'Spec Disease Status'
 WHERE concept_code IN ('21594007', '17621005', '263654008');

-- 8. Set standard_concept based on domain_id
UPDATE concept_stage c
   SET c.standard_concept =
          CASE c.domain_id
             WHEN 'Drug' THEN NULL                         -- Drugs are RxNorm
             WHEN 'Metadata' THEN NULL                      -- Not used in CDM
             WHEN 'Race' THEN NULL                             -- Race are CDC
             WHEN 'Provider Specialty' THEN NULL
             WHEN 'Place of Service' THEN NULL
             WHEN 'Unit' THEN NULL                           -- Units are UCUM
             ELSE 'S'
          END
 WHERE C.VOCABULARY_ID = 'SNOMED';