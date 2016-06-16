 

BEGIN
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
ALTER TABLE vocabulary ADD latest_update DATE;
update vocabulary set latest_update=to_date('20160602','yyyymmdd'), vocabulary_version='AMIS 20160602' where vocabulary_id='AMIS';
 commit;
 
ALTER TABLE pack_content
  RENAME COLUMN drug_concept_code TO component_concept_code;
