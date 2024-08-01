--Create source table to be filled during 'load_stage' before stage tables created
CREATE TABLE source (
    scui text,
    cui text,
    concept_code text,
    concept_name text,
    synonum text
);