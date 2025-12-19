-- replace outdated CIEL reference link in the vocabulary table
UPDATE vocabulary
   SET vocabulary_reference = 'https://app.openconceptlab.org/#/orgs/CIEL/'
WHERE vocabulary_id = 'CIEL';
