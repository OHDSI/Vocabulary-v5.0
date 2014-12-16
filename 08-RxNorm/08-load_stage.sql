--1 create tables and indexes: RxNormDDL.sql

--2 download YYYYab-1-meta.nlm (for exemple 2014ab-1-meta.nlm)
--unpack MRCONSO.RRF.aa.gz and MRCONSO.RRF.ab.gz, then run:
--gunzip *.gz
--cat MRCONSO.RRF.aa MRCONSO.RRF.ab > MRCONSO.RRF
--load MRCONSO.RRF with RXNCONSO.ctl

--3 Fix concept_names:
--before create tmp table
create table mrconso_tmp  NOLOGGING as
select DISTINCT
                  FIRST_VALUE (
                     n.AUI)
                  OVER (
                     PARTITION BY n.code
                     ORDER BY
                        DECODE (n.tty,
                                'PT', 1,
                                'PTGB', 2,
                                'SY', 3,
                                'SYGB', 4,
                                'MTH_PT', 5,
                                'FN', 6,
                                'MTH_SY', 7,
                                'SB', 8,
                                10            -- default for the obsolete ones
                                  )) AUI,  
                   FIRST_VALUE (
                     -- take the best str, and remove things like "(procedure)" 
                     REGEXP_REPLACE (n.str, ' \(.*?\)$', '')) 
                  OVER (
                     PARTITION BY n.code
                     ORDER BY
                        DECODE (n.tty,
                                'PT', 1,
                                'PTGB', 2,
                                'SY', 3,
                                'SYGB', 4,
                                'MTH_PT', 5,
                                'FN', 6,
                                'MTH_SY', 7,
                                'SB', 8,
                                10            -- default for the obsolete ones
                                  )) str,                                  
                  n.code                                                                
             FROM mrconso n
            WHERE n.sab = 'SNOMEDCT_US';
			
--then update
UPDATE concept c
   SET c.concept_name =
          (         
           SELECT str
             FROM mrconso_tmp m_tmp
            WHERE m_tmp.code = c.concept_code)
 WHERE     EXISTS
              (        -- the concept_name is identical to the str of a record
               SELECT 1
                 FROM mrconso m
                WHERE     m.code = c.concept_code
                      AND m.sab = 'SNOMEDCT_US'
                      AND c.vocabulary_id = 'SNOMED'
                      AND TRIM (c.concept_name) = TRIM (m.str)
                      AND m.tty <> 'PT' -- anything that is not the preferred term
                                       )
       AND c.invalid_reason IS NULL -- only active ones. The inactive ones often only have obsolete tty anyway
       AND c.vocabulary_id = 'SNOMED';
	   

--4 Get all the other ones in ('PT', 'PTGB', 'SY', 'SYGB', 'MTH_PT', 'FN', 'MTH_SY', 'SB') into concept_synonym_stage
INSERT INTO concept_synonym_stage (synonym_concept_id,
                                   synonym_concept_code,
                                   synonym_name,
                                   language_concept_id)
   SELECT NULL,
          m.code,
          SUBSTR (m.str, 1, 256),
          4093769 -- English
     FROM mrconso m LEFT JOIN mrconso_tmp m_tmp ON m.aui = m_tmp.aui
    WHERE m.sab = 'SNOMEDCT_US' AND m_tmp.aui IS NULL
	   
			