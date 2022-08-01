--6.3.1. Backup concept_relationship_manual table and concept_manual table.
DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT TO_CHAR(CURRENT_DATE, 'YYYY_MM_DD')
        INTO update;
        EXECUTE FORMAT('create table %I as select * from concept_relationship_manual',
                       'concept_relationship_manual_backup_' || update);

    END
$body$;

--restore concept_relationship_manual table (run it only if something went wrong)
/*TRUNCATE TABLE dev_read.concept_relationship_manual;
INSERT INTO dev_read.concept_relationship_manual
SELECT * FROM dev_read.concept_relationship_manual_backup_2022_05_26;*/

DO
$body$
    DECLARE
        update text;
    BEGIN
        SELECT TO_CHAR(CURRENT_DATE, 'YYYY_MM_DD')
        INTO update;
        EXECUTE FORMAT('create table %I as select * from concept_manual',
                       'concept_manual_backup_' || update);

    END
$body$;

--restore concept_manual table (run it only if something went wrong)
/*TRUNCATE TABLE dev_read.concept_manual;
INSERT INTO dev_read.concept_manual
SELECT * FROM dev_read.concept_manual_backup_2022_05_26;*/

--6.3.2. Create read_mapped table and pre-populate it with the resulting manual table of the previous read refresh.
--TRUNCATE TABLE dev_read.read_mapped;
CREATE TABLE dev_read.read_mapped
(
read_code VARCHAR,
read_name VARCHAR,
repl_by_relationship VARCHAR,
repl_by_id INT,
repl_by_code VARCHAR,
repl_by_name VARCHAR,
repl_by_domain VARCHAR,
repl_by_vocabulary VARCHAR);

--TRUNCATE dev_read.read_new_concept
CREATE TABLE dev_read.read_new_concept
(
concept_name VARCHAR,
domain_id VARCHAR,
vocabulary_id VARCHAR,
concept_class_id VARCHAR,
concept_code VARCHAR
		);

UPDATE concept_manual cs
	SET concept_name = cm.concept_name,
		domain_id = cm.domain_id,
		concept_class_id = cm.concept_class_id,
		standard_concept = NULL,
		valid_start_date = current_date,
		valid_end_date = to_date('20991231','yyyymmdd'),
		invalid_reason = NULL
	FROM dev_read.read_new_concept cm
	WHERE cm.concept_code = cs.concept_code
		AND cm.vocabulary_id = cs.vocabulary_id;

INSERT INTO concept_manual (
		concept_name,
		domain_id,
		vocabulary_id,
		concept_class_id,
		standard_concept,
		concept_code,
		valid_start_date,
		valid_end_date,
		invalid_reason
		)
	SELECT concept_name,
		domain_id,
		vocabulary_id,
		concept_class_id,
		NULL AS standard_concept,
		concept_code,
		current_date as valid_start_date,
		to_date('20991231','yyyymmdd') as valid_end_date,
		NULL AS invalid_reason
	FROM dev_read.read_new_concept cm
	WHERE NOT EXISTS (
			SELECT 1
			FROM concept_manual cs_int
			WHERE cs_int.concept_code = cm.concept_code
				AND cs_int.vocabulary_id = cm.vocabulary_id
			);

--6.3.3. Select concepts to map and add them to the manual file in the spreadsheet editor.

--6.3.5. Truncate the read_mapped table. Save the spreadsheet as the read_mapped table and upload it into the working schema.
TRUNCATE TABLE dev_read.read_mapped;

--6.3.8. Deprecate all mappings that differ from the new version of resulting mapping file.
UPDATE concept_relationship_manual crm
SET invalid_reason = 'D',
    valid_end_date = current_date

--SELECT * FROM concept_relationship_manual crm --use this SELECT for QA
WHERE invalid_reason IS NULL --deprecate only what's not yet deprecated in order to preserve the original deprecation date

    AND concept_code_1 IN (SELECT read_code FROM dev_read.read_mapped) --work only with the codes presented in the manual file of the current vocabulary refresh

    AND NOT EXISTS (SELECT 1 --don't deprecate mapping if the same exists in the current manual file
                    FROM dev_read.read_mapped rl
                    WHERE rl.read_code = crm.concept_code_1 --the same source_code is mapped
                        AND rl.repl_by_code = crm.concept_code_2 --to the same concept_code
                        AND rl.repl_by_vocabulary = crm.vocabulary_id_2 --of the same vocabulary
                        AND rl.repl_by_relationship = crm.relationship_id --with the same relationship
        )
;


--6.3.9. Insert new and corrected mappings into the concept_relationship_manual table.
with mapping AS -- select all new codes with their mappings from manual file
    (
        SELECT DISTINCT read_code AS concept_code_1,
               repl_by_code AS concept_code_2,
               'Read' AS vocabulary_id_1, -- set current vocabulary name as vocabulary_id_1
               repl_by_vocabulary AS vocabulary_id_2,
               repl_by_relationship AS relationship_id,
               current_date AS valid_start_date, -- set the date of the refresh as valid_start_date
               to_date('20991231','yyyymmdd') AS valid_end_date,
               NULL AS invalid_reason -- make all new mappings valid
        FROM dev_read.read_mapped
        WHERE repl_by_id != 0 -- select only codes with mapping to standard concepts
    )
-- insert new mappings into concept_relationship_manual table
INSERT INTO concept_relationship_manual(concept_code_1, concept_code_2, vocabulary_id_1, vocabulary_id_2, relationship_id, valid_start_date, valid_end_date, invalid_reason)
(
        SELECT concept_code_1,
            concept_code_2,
            vocabulary_id_1,
            vocabulary_id_2,
            relationship_id,
            valid_start_date,
            valid_end_date,
            invalid_reason
     FROM mapping m
        -- don't insert codes with mapping if the same exists in the current manual file
        WHERE (concept_code_1, --the same source_code is mapped
               concept_code_2, --to the same concept_code
               vocabulary_id_1,
               vocabulary_id_2, --of the same vocabulary
               relationship_id, --with the same relationship
               invalid_reason)
        NOT IN (SELECT concept_code_1,
                       concept_code_2,
                       vocabulary_id_1,
                       vocabulary_id_2,
                       relationship_id,
                       invalid_reason FROM concept_relationship_manual
            )
    )
;

SELECT * FROM concept_manual;


