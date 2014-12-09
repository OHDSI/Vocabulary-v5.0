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
	peak_code integer, --the id of the top ancestor
	peak_domain_id varchar(20), -- the domain to assign to all its children
	ranked integer -- number for the order in which to assign
);

-- Fill in the various peak concepts
insert into peak (peak_code, peak_domain_id) values (4086921, 'Observation'); -- 'Context-dependent category' that has no ancestor
insert into peak (peak_code, peak_domain_id) values (4008453, 'Observation'); -- root
insert into peak (peak_code, peak_domain_id) values (4320145, 'Provider Specialty');
insert into peak (peak_code, peak_domain_id) values (4185257, 'Place of Service');	  -- Site of care
insert into peak (peak_code, peak_domain_id) values (4169112, 'Drug'); -- Aromatherapy agent
insert into peak (peak_code, peak_domain_id) values (4162709, 'Drug'); -- Pharmaceutical / biologic product
insert into peak (peak_code, peak_domain_id) values (4254051, 'Drug'); --	Drug or medicament
insert into peak (peak_code, peak_domain_id) values (4169265, 'Device');
insert into peak (peak_code, peak_domain_id) values (4128004, 'Device'); -- Surgical material
insert into peak (peak_code, peak_domain_id) values (4124754, 'Device'); -- Graft
insert into peak (peak_code, peak_domain_id) values (4303529, 'Device'); -- Adhesive agent
insert into peak (peak_code, peak_domain_id) values (441840, 'Condition'); -- Clinical Finding
insert into peak (peak_code, peak_domain_id) values (438949, 'Condition'); -- Adverse reaction to primarily systemic agents
insert into peak (peak_code, peak_domain_id) values (4196732, 'Condition'); -- Calculus observation
insert into peak (peak_code, peak_domain_id) values (4041436, 'Measurement'); -- 'Finding by measurement'
insert into peak (peak_code, peak_domain_id) values (443440, 'Observation'); -- 'History finding'
insert into peak (peak_code, peak_domain_id) values (4040739, 'Observation'); -- 'Finding of activity of daily living'
insert into peak (peak_code, peak_domain_id) values (4146314, 'Observation');-- 'Administrative statuses'
		-- 40416814, 'Observation'); Causes of injury and poisoning'
		-- 40418184,  -- '[X]External causes of morbidity and mortality'
insert into peak (peak_code, peak_domain_id) values (4037321, 'Observation'); -- Symptom description
-- insert into peak (peak_code, peak_domain_id) values (4084137,	'Observation');-- Sample observation
insert into peak (peak_code, peak_domain_id) values (4022232, 'Observation'); -- 'Health perception, health management pattern'
insert into peak (peak_code, peak_domain_id) values (4037706, 'Observation'); --'Patient not aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (4279142, 'Observation'); --'Victim status'
insert into peak (peak_code, peak_domain_id) values (4037705, 'Observation'); --'Patient aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (4167037, 'Observation'); --Patient condition finding
insert into peak (peak_code, peak_domain_id) values (4231688, 'Observation'); --'Staff member inattention'
insert into peak (peak_code, peak_domain_id) values (4236719, 'Observation'); --'Staff member ill'
insert into peak (peak_code, peak_domain_id) values (4225233, 'Observation'); --'Staff member distraction'
insert into peak (peak_code, peak_domain_id) values (4134868, 'Observation'); --Staff member fatigued
insert into peak (peak_code, peak_domain_id) values (4134549, 'Observation'); --Staff member inadequately assisted
insert into peak (peak_code, peak_domain_id) values (4134412, 'Observation'); --Staff member inadequately supervised
insert into peak (peak_code, peak_domain_id) values (4037137, 'Observation');--'Family not aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (4038236, 'Observation'); --'Family aware of diagnosis'
insert into peak (peak_code, peak_domain_id) values (4170588, 'Observation'); --Acceptance of illness
insert into peak (peak_code, peak_domain_id) values (4028922, 'Observation'); --	Social context condition
insert into peak (peak_code, peak_domain_id) values (4202797, 'Observation'); -- Drug therapy observations
insert into peak (peak_code, peak_domain_id) values (444035, 'Condition'); --Incontinence
-- insert into peak (peak_code, peak_domain_id) values (4025202, 'Condition'); --Elimination pattern
-- insert into peak (peak_code, peak_domain_id) values (4186437, 'Condition'); -- Urinary elimination alteration
--		4266236, 'Observation'); --'Cancer-related substance' - 4228508
insert into peak (peak_code, peak_domain_id) values (4028908, 'Measurement'); --'Laboratory procedures'
insert into peak (peak_code, peak_domain_id) values (4048365, 'Measurement'); --'Measurement'
-- 		4236002, 'Observation'); --'Allergen class'
-- 		4019381, 'Observation'); --'Biological substance'
--		4240422 -- 'Human body substance'
insert into peak (peak_code, peak_domain_id) values (4038503, 'Measurement');	-- 'Laboratory test finding' - child of excluded Sample observation
insert into peak (peak_code, peak_domain_id) values (4322976, 'Procedure'); --'Procedure'
insert into peak (peak_code, peak_domain_id) values (4126324, 'Procedure'); -- Resuscitate
insert into peak (peak_code, peak_domain_id) values (4119499, 'Procedure'); --DNR
insert into peak (peak_code, peak_domain_id) values (4013513, 'Procedure'); -- Cardiovascular measurement
insert into peak (peak_code, peak_domain_id) values (4175586, 'Observation'); --Family history of procedure
insert into peak (peak_code, peak_domain_id) values (4033224, 'Observation'); --Administrative procedure
insert into peak (peak_code, peak_domain_id) values (4215685, 'Observation'); --Past history of procedure
insert into peak (peak_code, peak_domain_id) values (4082089, 'Observation');-- Procedure contraindicated
insert into peak (peak_code, peak_domain_id) values (4231195, 'Observation');-- Administration of drug or medicament contraindicated
insert into peak (peak_code, peak_domain_id) values (40484042, 'Observation'); --Evaluation of urine specimen
insert into peak (peak_code, peak_domain_id) values (4260907, 'Observation'); -- Drug therapy status
insert into peak (peak_code, peak_domain_id) values (4271693, 'Procedure'); --Blood unit processing - inside Measurements
insert into peak (peak_code, peak_domain_id) values (4070456, 'Procedure'); -- Specimen collection treatments and procedures - - bad child of 4028908	Laboratory procedure
insert into peak (peak_code, peak_domain_id) values (4268709, 'Gender'); -- Gender
insert into peak (peak_code, peak_domain_id) values (4155301, 'Race'); --Ethnic group
insert into peak (peak_code, peak_domain_id) values (4216292, 'Race'); -- Racial group
insert into peak (peak_code, peak_domain_id) values (40642546, 'Metadata'); -- SNOMED CT Model Component
insert into peak (peak_code, peak_domain_id) values (4024728, 'Observation'); -- Linkage concept
insert into peak (peak_code, peak_domain_id) values (4121358, 'Unit'); -- Top unit

-- 2. Ancestors inherit the domain_id and standard_concept of their Peaks. However, the ancestors of Peaks are overlapping.
-- Therefore, the order by which the inheritance is passed depends on the "height" in the hierarchy: The lower the peak, the later it should be run
-- The following creates the right order by counting the number of ancestors: The more ancestors the lower in the hierarchy.
-- This could go wront if a parallel fork happens
UPDATE peak p
   SET p.ranked =
          (SELECT rnk
             FROM (  SELECT ranked.pd AS peak_code, COUNT (*) AS rnk
                       FROM (SELECT DISTINCT
                                    pa.peak_code AS pa, pd.peak_code AS pd
                               FROM peak pa,
                                    snomed_ancestor a,
                                    concept c,
                                    peak pd,
                                    concept c1
                              WHERE     a.ancestor_concept_code = c.concept_code
                                    AND pa.peak_code = c.concept_id
                                    AND a.descendant_concept_code = c1.concept_code
                                    AND pd.peak_code = c1.concept_id
                                    AND C.VOCABULARY_ID=C1.VOCABULARY_ID
                                    AND C.VOCABULARY_ID='SNOMED'
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
         concept c1,
         concept_stage conflict
   WHERE     a.descendant_concept_code IN (SELECT concept_code
                                             FROM (  SELECT child.concept_code,
                                                            COUNT (*)
                                                       FROM (SELECT DISTINCT
                                                                    p.peak_domain_id,
                                                                    a.descendant_concept_code
                                                                       AS concept_code
                                                               FROM peak p,
                                                                    snomed_ancestor a,
                                                                    concept c
                                                              WHERE a.ancestor_concept_code =
                                                                    C.CONCEPT_CODE
                                                                    and C.CONCEPT_ID=p.peak_code
                                                                    and C.VOCABULARY_ID='SNOMED')
                                                            child
                                                   GROUP BY child.concept_code
                                                     HAVING COUNT (*) > 1)
                                                  clash)
         AND c.concept_code = a.ancestor_concept_code
         AND c.concept_code = C1.CONCEPT_CODE
         AND d.peak_code=c1.concept_id
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
   SELECT concept_code, CAST ('Not assigned' AS VARCHAR2 (200)) AS domain_id
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
                           FROM peak p, snomed_ancestor a, concept c
                          WHERE     a.ancestor_concept_code = c.concept_code
                                AND p.peak_code = c.concept_id
                                AND p.ranked = A.ranked
                                AND C.VOCABULARY_ID = 'SNOMED') child
                  WHERE child.concept_code = d.concept_code)
       WHERE d.concept_code IN (SELECT a.descendant_concept_code
                                  FROM peak p, snomed_ancestor a, concept c
                                 WHERE     a.ancestor_concept_code =
                                              c.concept_code
                                       AND p.peak_code = c.concept_id
                                       AND C.VOCABULARY_ID = 'SNOMED');
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
                 AND c.concept_id NOT IN (SELECT DISTINCT peak_code
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

-- 5. Update concept_stage from newly created domains.

CREATE INDEX idx_domain_cc
   ON domain_snomed (concept_code);

UPDATE concept_stage c
   SET c.domain_id =
          (SELECT d.domain_id
             FROM domain_snomed d
            WHERE d.concept_code = c.concept_code)
 WHERE C.VOCABULARY_ID = 'SNOMED';

-- 6. Set standard_concept based on domain_id
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