-- concept_metadata DDL:
CREATE TABLE concept_meta_bypass
(
concept_id INT,
reuse_status JSONB,
concept_type varchar(20),
phi_status boolean NOT NULL DEFAULT FALSE,
    FOREIGN KEY (concept_id)
    REFERENCES concept (concept_id)
)
;

-- Insert example:
INSERT INTO concept_meta_bypass (concept_id, reuse_status)
VALUES (
  2718917,
  '[
    { "reuse_type": "true_reuse",
      "reuse_cycle": [
        { "concept_name": "Vincristine sulfate, 5 mg",
          "valid_start_date": "1994-01-01",
          "valid_end_date": "2010-12-31"
        },
        { "concept_name": "Injection, teclistamab-cqyv, 0.5 mg",
          "valid_start_date": "2023-07-01",
          "valid_end_date": "2099-12-31"
        }
      ]
    }
  ]'::jsonb
);

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
  concept_id, valid_start_date;