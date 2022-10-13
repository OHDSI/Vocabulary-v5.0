--Update  of CGI needed to preserve IDs for cases where Gene-Protein is fully equivalent to gdna alteration (1 protein level affect- 1 DNA alteration)
--Leftover codes will be deprecated
UPDATE concept c
SET concept_code = s.concept_code,
	valid_start_date = CASE 
		WHEN s.valid_start_date < TO_DATE('20180216', 'yyyymmdd')
			THEN s.valid_start_date
		ELSE TO_DATE('20180216', 'yyyymmdd')
		END
FROM (
	WITH tab AS (
			SELECT b.concept_id,
				TRIM(SUBSTR(REGEXP_SPLIT_TO_TABLE(a.gdna, '__'), 1, 50)) AS concept_code,
				b.valid_start_date
			FROM dev_cgi.genomic_cgi_source a
			JOIN concept b ON CONCAT (
					a.gene,
					':',
					REGEXP_REPLACE(a.protein, 'p.', '')
					) = b.concept_code
				AND b.vocabulary_id = 'CGI'
			)
	SELECT concept_id,
		concept_code,
		valid_start_date
	FROM tab
	WHERE concept_id IN (
			SELECT concept_id
			FROM tab
			GROUP BY 1
			HAVING COUNT(DISTINCT concept_code) = 1
			)
	) AS s
WHERE c.concept_id = s.concept_id
	AND c.vocabulary_id = 'CGI';

--Set correct validity for 37 concepts
UPDATE concept c
SET valid_end_date = CURRENT_DATE,
	invalid_reason = 'D'
WHERE c.vocabulary_id = 'CGI'
	AND concept_code NOT LIKE '%:g.%';