--Change of vocabulary license requirements and vocabulary_reference for CO-CONNECT family of the vocabularies
--AVOC-4015
UPDATE vocabulary 
SET vocabulary_name = replace(vocabulary_name, 'IQVIA ', ''),
    vocabulary_reference = 'https://co-connect.ac.uk/'
WHERE vocabulary_id IN ('CO-CONNECT', 'CO-CONNECT TWINS', 'CO-CONNECT MIABIS');

UPDATE vocabulary_conversion
SET available = NULL,
    URL = NULL
WHERE vocabulary_id_v5 IN ('CO-CONNECT', 'CO-CONNECT TWINS', 'CO-CONNECT MIABIS');