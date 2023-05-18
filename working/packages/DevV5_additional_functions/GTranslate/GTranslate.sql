CREATE OR REPLACE FUNCTION devv5.GTranslate(pInputTable text, pInputField text, pOutputField text, pDestLang text default 'en', pSrcLang text default 'auto')
RETURNS void AS
$BODY$
/*
Function for translation using googletrans python module

Parameters:
pInputTable - the name of the input table with untranslated strings (required)
pInputField - the name of the field in that table containing the input rows (required)
pOutputField - the name of the field in that table where to put the translation (required)
pDestLang - the language to translate the source text into.
	The value should be one of the language codes listed in https://py-googletrans.readthedocs.io/en/latest/#googletrans-languages (optional, default 'en')
pSrcLang - the language of the source text.
	The value should be one of the language codes listed in https://py-googletrans.readthedocs.io/en/latest/#googletrans-languages (optional, if not specified, the system will attempt to identify the source language automatically, default 'auto')

Usage:
--run in the schema where you have the input table
DO $_$
BEGIN
	PERFORM devv5.GTranslate(
		pInputTable    =>'input_table',
		pInputField    =>'field_with_foreign_names',
		pOutputField   =>'field_with_translated_names',
		pDestLang      =>'en'
	);
END $_$;

Example:
--let's create an input table with 10 rows in Korean
CREATE TABLE input_table AS
SELECT concept_synonym_name AS foreign_string,
	NULL::TEXT AS translated_string
FROM devv5.concept_synonym
WHERE language_concept_id = 4175771 LIMIT 10;

Note: the output field in the input table must be in TEXT type, because we don't know in advance how many characters the translation will take

--now run the function
DO $_$
BEGIN
	PERFORM devv5.GTranslate(
		pInputTable    =>'input_table',
		pInputField    =>'foreign_string',
		pOutputField   =>'translated_string',
		pDestLang      =>'en'
	);
END $_$;

Note:
As we use a third-party module + Google Translate service, then there is no guarantee that the function will work correctly.
Therefore, in case of an error during translation, a string with the error text (with the !ERROR prefix) will be written to the output field, so always check this with a query like
SELECT * FROM input_table WHERE translated_string LIKE '!ERROR: %' LIMIT 100;

Algorithm:
All input rows are divided into groups - the so-called "buckets".
These buckets are passed one by one to the python module py_gtranslate that knows how to work with them, a batch translation takes place on the side of Google services, and then the function writes this translation according to each row in this bucket.
If an error occurs, all lines from that bucket are marked as "!ERROR: <error_text>" in the output field. This approach allows us to optimize network delays and save the translation for those rows that had no problems with translation.
The algorithm also allows you to restart the function on the same table, it will skip all rows where there is already a translation (the output field has already been filled in during the previous run, or, for example, as a result of manual editing/translation by a medical),
but will try to re-translate all rows with an error.

Limitations:
1. Each input row cannot be more than 1000 characters.
2. To avoid being subject to Google's request limit, the function can only have one instance running.

Performance:
During the tests, the function demonstrated the translation of 10k rows in about 11 minutes. It all depends on the level of network delays between our server and Google servers (and its load), and the number of characters in the input rows.
*/
DECLARE
	iMaxStringLength CONSTANT int4 := 1000;
	iMaxPacketLength CONSTANT int4 := 5000 /*bucket size or googletrans limit*/ - iMaxStringLength;
	iDelay CONSTANT float := 0; --delay between calls to py_gtranslate(), in seconds. but it looks like we don't need it...
	iOutputType text;
	iCurrentPct INT2;
	iProcessedPct INT2:=0;
	r_src record;
	r_out record;
	z int4;
BEGIN

	IF NOT PG_TRY_ADVISORY_XACT_LOCK(HASHTEXT('GTranslate')) THEN
		RAISE EXCEPTION 'Function GTranslate already in use';
	END IF;

	pInputTable:=LOWER(pInputTable);

	EXECUTE FORMAT ($$
		SELECT COUNT(*) FROM %1$I WHERE LENGTH(%2$I) > %3$s;
	$$, pInputTable, pInputField, iMaxStringLength) INTO z;
	IF z>0 THEN
		RAISE EXCEPTION 'There are % rows in the table, that exceed the allowed length limit (%)', z, iMaxStringLength;
	END IF;

	EXECUTE FORMAT ($$
		SELECT PG_TYPEOF (%2$I) FROM %1$I LIMIT 1;
	$$, pInputTable, pOutputField) INTO iOutputType;
	IF iOutputType IS NULL THEN
		RAISE EXCEPTION 'The table is empty';
	END IF;
	IF iOutputType<>'text' THEN
		RAISE EXCEPTION 'The output field must be in TEXT type, not %', iOutputType;
	END IF;

	--aggregate rows to string buckets, then iterate one by one and translate
	FOR r_src IN EXECUTE FORMAT ($$
		SELECT ARRAY_AGG(s1.input_str) AS array_str,
			ROW_NUMBER() OVER () AS bucket_id,
			COUNT(*) OVER () AS buckets_cnt
		FROM (
			SELECT input_str,
				SUM(LENGTH(s0.input_str)) OVER (
					ORDER BY RANDOM() --shuffle rows to get more filled buckets
					) / %4$s AS virtual_group --to each row we assign a virtual group, each of which is guaranteed not to exceed the overall maximum length (iMaxPacketLength+iMaxStringLength)
			FROM (
				SELECT DISTINCT %2$I AS input_str
				FROM %1$I
				WHERE NULLIF(%2$I, '') IS NOT NULL --input field not empty
					AND (
						NULLIF(%3$I, '') IS NULL --output field is empty (input field not already translated)
						OR LEFT(%3$I, 7) = '!ERROR:' --re-translation marker if there was an error
						)
				) AS s0
			) s1
		GROUP BY s1.virtual_group;
	$$, pInputTable, pInputField, pOutputField, iMaxPacketLength)
	LOOP
		IF r_src.bucket_id=1 THEN --raise this notice only once
			RAISE NOTICE 'Number of buckets: %', r_src.buckets_cnt;
		END IF;

		BEGIN
			EXECUTE FORMAT ($$
				UPDATE %1$I AS s SET %3$I = t.translated_text
				FROM devv5.py_gtranslate($1, %4$L, %5$L) AS t
				WHERE s.%2$I = t.original_text;
			$$, pInputTable, pInputField, pOutputField, pDestLang, pSrcLang)
			USING r_src.array_str;

			EXCEPTION WHEN OTHERS THEN
				EXECUTE FORMAT ($$
					UPDATE %1$I
					SET %3$I = CONCAT('!ERROR: ', %4$L)
					WHERE %2$I = ANY($1);
				$$, pInputTable, pInputField, pOutputField, SQLERRM)
				USING r_src.array_str;
		END;

		--calculating the percentage of buckets processed
		iCurrentPct:=100*r_src.bucket_id/r_src.buckets_cnt;
		IF iCurrentPct>=10 AND iCurrentPct<100 THEN
			IF LEFT(iCurrentPct::TEXT,1)>LEFT(iProcessedPct::TEXT,1) THEN
				iProcessedPct:=iCurrentPct;
				RAISE NOTICE '% of buckets were processed',iProcessedPct::TEXT||'%';
			END IF;
		END IF;

		IF iDelay>0 AND r_src.buckets_cnt>1 AND r_src.bucket_id<>r_src.buckets_cnt THEN --delay only if we have more than one bucket, and currently we're not processing the latest
			PERFORM pg_sleep(iDelay);
		END IF;
	END LOOP;

	RAISE NOTICE '100%% of buckets were processed';
END;
$BODY$
LANGUAGE 'plpgsql' STRICT;

REVOKE EXECUTE ON FUNCTION devv5.GTranslate FROM PUBLIC;