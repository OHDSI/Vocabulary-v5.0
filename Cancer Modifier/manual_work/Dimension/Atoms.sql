SELECT *
FROM devv5.concept
WHERE vocabulary_id = 'Cancer Modifier'
and concept_class_id = 'Dimension'
;

SELECT lower(regexp_replace(concept_name, '\(|\)|\:|\>', '' , 'gi'))
FROM devv5.concept
WHERE vocabulary_id = 'Cancer Modifier'
and concept_class_id = 'Dimension'
;

--All words in one column
SELECT word, count(*)
FROM (
  SELECT lower(regexp_split_to_table(regexp_replace(concept_name, '\(|\)|\:|\>', '' , 'gi'), '\s')) as word
FROM devv5.concept
WHERE vocabulary_id = 'Cancer Modifier'
and concept_class_id = 'Dimension'₽
) t
GROUP BY word

--All words in one column
SELECT word, count(*)
FROM (
  SELECT lower(regexp_split_to_table(regexp_replace(concept_name, '\(|\)|\:|\>', '' , 'gi'), '\s')) as word
FROM devv5.concept
WHERE vocabulary_id = 'Cancer Modifier'
and concept_class_id = 'Margin'
) t
GROUP BY word