-- DDL for a table with reused concepts:
CREATE TABLE reused_concepts
(
       concept_id INT,
       concept_code VARCHAR(20),
	   old_concept_name VARCHAR(255),
	   new_concept_name VARCHAR(255),
	   vocabulary_id VARCHAR(50),
	   reused_code_effdate DATE
)
;

-- concept_metadata DDL:
CREATE TABLE concept_meta_bypass
(
concept_id INT,
reuse_status JSONB,
concept_type VARCHAR(20),
phi_status boolean NOT NULL DEFAULT FALSE,
    FOREIGN KEY (concept_id)
    REFERENCES concept (concept_id)
)
;

-- Insert example:
INSERT INTO concept_meta_bypass (concept_id, reuse_status)
SELECT
    rr.concept_id,
    jsonb_build_array(
        jsonb_build_object(   'reuse_type', 'true reuse',
            'reuse_cycle', jsonb_build_array(
                jsonb_build_object(
                    'concept_name', rr.new_concept_name,
                    'valid_start_date', rr.reused_code_effdate,
                    'valid_end_date', '2099-12-31'
                ),
                            jsonb_build_object(
                    'concept_name', c.concept_name,
                    'valid_start_date', c.valid_start_date,
                    'valid_end_date',c.valid_end_date
                )

            )
        )
    )
FROM
    reused_concepts rr
JOIN concept c ON rr.concept_id = c.concept_id
;

-- JSON parsing:
 WITH data AS (
  SELECT
    concept_id,
    jsonb_array_elements(reuse_status) AS reuse_element,
        jsonb_array_elements( jsonb_array_elements(reuse_status)->'reuse_cycle') AS cycle_element
  FROM
concept_meta_bypass
)
SELECT
  concept_id,
  reuse_element->>'reuse_type' AS reuse_type,
  cycle_element->>'concept_name' AS concept_name,
  to_date(cycle_element->>'valid_start_date', 'YYYY-MM-DD') AS valid_start_date,
  to_date(cycle_element->>'valid_end_date', 'YYYY-MM-DD') AS valid_end_date
FROM
  data
ORDER BY
  concept_id, valid_start_date
 ;