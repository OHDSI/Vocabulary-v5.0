-- Todo:
-- drug_strength
-- Brands
-- mapping Ingredients
-- mapping Forms
-- mapping units

-- 1. Update latest_update field to new date 
/*
BEGIN
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
*/
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=to_date('20160325','yyyymmdd'), vocabulary_version='dm+d Version 3.2.0' WHERE vocabulary_id='dm+d'; 
COMMIT;

-- 2. Create drug_concept_stage

drop table drug_concept_stage purge;
CREATE TABLE drug_concept_stage NOLOGGING AS SELECT * FROM concept_stage WHERE 1=0;
ALTER TABLE drug_concept_stage ADD insert_id NUMBER;   
INSERT /*+ APPEND */
      INTO  drug_concept_stage (concept_id,
                               concept_name,
                               domain_id,
                               vocabulary_id,
                               concept_class_id,
                               standard_concept,
                               concept_code,
                               valid_start_date,
                               valid_end_date,
                               invalid_reason,
                               insert_id)
   --Forms
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'INFO/DESC') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Dose Form' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'INFO/CD') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'INFO/CDDT'), '1970-01-01'), 'YYYY-MM-DD') AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason,
          3 AS insert_id
     FROM f_lookup2 t_xml,
          TABLE (XMLSEQUENCE (t_xml.xmlfield.EXTRACT ('LOOKUP/FORM/INFO'))) t
   UNION ALL
   --deprecated Forms
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'INFO/DESC') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Dose Form' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          NVL(TO_DATE (EXTRACTVALUE (VALUE (t), 'INFO/CDDT'), 'YYYY-MM-DD') - 1, (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')) AS valid_end_date,
          'U' AS invalid_reason,
          4 AS insert_id
     FROM f_lookup2 t_xml,
          TABLE (XMLSEQUENCE (t_xml.xmlfield.EXTRACT ('LOOKUP/FORM/INFO'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'INFO/CDPREV') IS NOT NULL
  UNION ALL
   --Ingredients
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'ING/NM') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Ingredient' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'ING/ISID') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'ING/ISIDDT'), '1970-01-01'), 'YYYY-MM-DD') AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'ING/INVALID') = '1'
             THEN
                (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'ING/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          7 AS insert_id
     FROM f_ingredient2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('INGREDIENT_SUBSTANCES/ING'))) t
   UNION ALL
   --deprecated Ingredients
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'ING/NM') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Ingredient' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'ING/ISIDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          NVL(TO_DATE (EXTRACTVALUE (VALUE (t), 'ING/ISIDDT'), 'YYYY-MM-DD') - 1, (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')) AS valid_end_date,
          'U' AS invalid_reason,
          8 AS insert_id
     FROM f_ingredient2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('INGREDIENT_SUBSTANCES/ING'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'ING/ISIDPREV') IS NOT NULL
   UNION ALL
   --VTMs (Ingredients)
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'VTM/NM') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Ingredient' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VTM/VTMID') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'VTM/VTMIDDT'), '1970-01-01'), 'YYYY-MM-DD') AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VTM/INVALID') = '1'
             THEN
                (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VTM/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          9 AS insert_id
     FROM f_vtm2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('VIRTUAL_THERAPEUTIC_MOIETIES/VTM'))) t
   UNION ALL
   --deprecated VTMs
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'VTM/NM') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Ingredient' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VTM/VTMIDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          NVL(TO_DATE (EXTRACTVALUE (VALUE (t), 'VTM/VTMIDDT'), 'YYYY-MM-DD') - 1, (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')) AS valid_end_date,
          'U' AS invalid_reason,
          10 AS insert_id
     FROM f_vtm2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('VIRTUAL_THERAPEUTIC_MOIETIES/VTM'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'VTM/VTMIDPREV') IS NOT NULL
   UNION ALL
   --VMPs (generic or clinical drugs)
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'VMP/NM') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Clinical Drug' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VMP/VPID') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'VMP/VTMIDDT'), '1970-01-01'), 'YYYY-MM-DD') AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VMP/INVALID') = '1'
             THEN
                (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VMP/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          11 AS insert_id
     FROM f_vmp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('VIRTUAL_MED_PRODUCTS/VMPS/VMP'))) t
   UNION ALL
   --deprecated VMPs
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'VMP/NM') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Clinical Drug' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VMP/VPIDPREV') AS concept_code,
          TO_DATE ('19700101', 'yyyymmdd') AS valid_start_date,
          NVL(TO_DATE (EXTRACTVALUE (VALUE (t), 'VMP/VPIDDT'), 'YYYY-MM-DD') - 1, (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')) AS valid_end_date,
          'U' AS invalid_reason,
          12 AS insert_id
     FROM f_vmp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('VIRTUAL_MED_PRODUCTS/VMPS/VMP'))) t
    WHERE EXTRACTVALUE (VALUE (t), 'VMP/VPIDPREV') IS NOT NULL
   UNION ALL
   -- AMPs (branded drugs)
   SELECT NULL AS concept_id,
          SUBSTR (EXTRACTVALUE (VALUE (t), 'AMP/DESC'), 1, 255)
             AS concept_name,
          CASE EXTRACTVALUE (VALUE (t), 'AMP/LIC_AUTHCD')
		  WHEN '0002' THEN 'Device'
		  WHEN '0000' THEN 'Unknown'
		  WHEN '0003' THEN 'Unknown'
		  ELSE 'Drug'
		  END AS domain_id,
          'dm+d' AS vocabulary_id,
          'Branded Drug' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'AMP/APID') AS concept_code,
          TO_DATE (NVL (EXTRACTVALUE (VALUE (t), 'AMP/NMDT'), '1970-01-01'),
                   'YYYY-MM-DD')
             AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'AMP/INVALID') = '1'
             THEN
                (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'AMP/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          13 AS insert_id
     FROM f_amp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT ('ACTUAL_MEDICINAL_PRODUCTS/AMPS/AMP'))) t
   UNION ALL
   --VMPPs (Clinical Drug Box)
   SELECT NULL AS concept_id,
          SUBSTR (EXTRACTVALUE (VALUE (t), 'VMPP/NM'), 1, 255)
             AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Clinical Drug Box' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'VMPP/VPPID') AS concept_code,
          TO_DATE ('1970-01-01', 'YYYY-MM-DD') AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VMPP/INVALID') = '1'
             THEN
                (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'VMPP/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          14 AS insert_id
     FROM f_vmpp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT (
                   'VIRTUAL_MED_PRODUCT_PACK/VMPPS/VMPP'))) t
   UNION ALL
   --AMPPs (Branded Drug Box)
   SELECT NULL AS concept_id,
          SUBSTR (EXTRACTVALUE (VALUE (t), 'AMPP/NM'), 1, 255)
             AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Branded Drug Box' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'AMPP/APPID') AS concept_code,
          TO_DATE ('1970-01-01', 'YYYY-MM-DD') AS valid_start_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'AMPP/INVALID') = '1'
             THEN
                (SELECT latest_update - 1 FROM vocabulary WHERE vocabulary_id = 'dm+d')
             ELSE
                TO_DATE ('20991231', 'yyyymmdd')
          END
             AS valid_end_date,
          CASE
             WHEN EXTRACTVALUE (VALUE (t), 'AMPP/INVALID') = '1' THEN 'D'
             ELSE NULL
          END
             AS invalid_reason,
          15 AS insert_id
     FROM f_ampp2 t_xml,
          TABLE (
             XMLSEQUENCE (
                t_xml.xmlfield.EXTRACT (
                   'ACTUAL_MEDICINAL_PROD_PACKS/AMPPS/AMPP'))) t
   UNION ALL
   --Suppliers
   SELECT NULL AS concept_id,
          EXTRACTVALUE (VALUE (t), 'INFO/DESC') AS concept_name,
          'Drug' AS domain_id,
          'dm+d' AS vocabulary_id,
          'Supplier' AS concept_class_id,
          NULL AS standard_concept,
          EXTRACTVALUE (VALUE (t), 'INFO/CD') AS concept_code,
          TO_DATE ('1970-01-01', 'YYYY-MM-DD') AS valid_start_date,
          TO_DATE ('20991231', 'yyyymmdd') AS valid_end_date,
          NULL AS invalid_reason,
          16 AS insert_id
     FROM f_lookup2 t_xml,
          TABLE (XMLSEQUENCE (t_xml.xmlfield.EXTRACT ('LOOKUP/SUPPLIER/INFO'))) t;
COMMIT;                   
                   
-- Delete duplicates, first of all concepts with invalid_reason='D', then 'U', last of all 'NULL'
DELETE FROM drug_concept_stage
  WHERE ROWID NOT IN (SELECT LAST_VALUE (ROWID) OVER (PARTITION BY concept_code ORDER BY invalid_reason, ROWID ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
FROM drug_concept_stage);                   
COMMIT;    
