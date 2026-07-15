-- MONDO ontology is stored as a JSON file
CREATE TABLE mondo_json (
    id SERIAL PRIMARY KEY,
    version DATE,
    source_json JSONB NOT NULL,
    ts DATE DEFAULT CURRENT_DATE,
    download_url TEXT DEFAULT 'https://purl.obolibrary.org/obo/mondo.json'  -- Corrected typo: 'download_ulr' to 'download_url'
);

CREATE INDEX idx_mondo_json_gin
ON mondo_json
USING GIN (source_json);

CREATE INDEX idx_mondo_json_pathops
ON mondo_json
USING GIN (source_json jsonb_path_ops);

CREATE INDEX idx_mondo_jsonb_ops
ON mondo_json
USING GIN (source_json jsonb_ops);


-- MONDO ontology sssom mapping mappings
CREATE TABLE mondo_sssom_maps
(
    subject_id            text,
    subject_label         text,
    predicate_id          text,
    object_id             text,
    object_label          text,
    mapping_justification text
)
;
