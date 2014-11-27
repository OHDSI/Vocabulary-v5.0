INSERT INTO CONCEPT_STAGE (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
   SELECT DISTINCT
	      NULL,
          coalesce(kv2.description_long, kv2.description, kv2.description_short),
          NULL,
          'Read',
          'Read',
          NULL,
          kv2.readcode || kv2.termcode,
          TO_DATE ('20141001', 'yyyymmdd'),
          TO_DATE ('20991231', 'yyyymmdd'),
          NULL
     FROM keyv2 kv2;

	 
INSERT INTO concept_relationship_stage (concept_id_1,
                                        concept_id_2,
                                        concept_code_1,
                                        concept_code_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
   SELECT DISTINCT
          NULL,
          NULL,
          RSCCT.ReadCode || RSCCT.TermCode,
          -- pick the best map: mapstatus=1, then is_assured=1, then target concept is fresh, then newest date
          FIRST_VALUE (
             RSCCT.conceptid)
          OVER (
             PARTITION BY RSCCT.readcode || RSCCT.termcode
             ORDER BY
                RSCCT.mapstatus DESC,
                RSCCT.is_assured DESC,
                RSCCT.effectivedate DESC),
          'Maps to',
          TO_DATE ('20141001', 'yyyymmdd'),
          TO_DATE ('20991231', 'yyyymmdd'),
          NULL
     FROM RCSCTMAP2_UK RSCCT
     

COMMIT;