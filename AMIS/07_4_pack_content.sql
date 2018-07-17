-- drop table if exists stp_1;
-- drop table if exists stp_2;
-- drop table if exists stp_3;
-- drop table if exists stp_tp1;
DROP TABLE IF EXISTS stp_1;
CREATE TABLE stp_1 AS
SELECT enr,
	wsstf,
	'1' AS num,
	TPACK_1 AS TPACK
FROM source_table_pack
WHERE TPACK_1 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'2' AS num,
	TPACK_2 AS TPACK
FROM source_table_pack
WHERE TPACK_2 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'3' AS num,
	TPACK_3 AS TPACK
FROM source_table_pack
WHERE TPACK_3 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'4' AS num,
	TPACK_4 AS TPACK
FROM source_table_pack
WHERE TPACK_4 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'5' AS num,
	TPACK_5 AS TPACK
FROM source_table_pack
WHERE TPACK_5 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'6' AS num,
	TPACK_6 AS TPACK
FROM source_table_pack
WHERE TPACK_6 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'7' AS num,
	TPACK_7 AS TPACK
FROM source_table_pack
WHERE TPACK_7 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'8' AS num,
	TPACK_8 AS TPACK
FROM source_table_pack
WHERE TPACK_8 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'9' AS num,
	TPACK_9 AS TPACK
FROM source_table_pack
WHERE TPACK_9 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'10' AS num,
	TPACK_10 AS TPACK
FROM source_table_pack
WHERE TPACK_10 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'11' AS num,
	TPACK_11 AS TPACK
FROM source_table_pack
WHERE TPACK_11 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'12' AS num,
	TPACK_12 AS TPACK
FROM source_table_pack
WHERE TPACK_12 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'13' AS num,
	TPACK_13 AS TPACK
FROM source_table_pack
WHERE TPACK_13 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'14' AS num,
	TPACK_14 AS TPACK
FROM source_table_pack
WHERE TPACK_14 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'15' AS num,
	TPACK_15 AS TPACK
FROM source_table_pack
WHERE TPACK_15 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'16' AS num,
	TPACK_16 AS TPACK
FROM source_table_pack
WHERE TPACK_16 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'17' AS num,
	TPACK_17 AS TPACK
FROM source_table_pack
WHERE TPACK_17 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'18' AS num,
	TPACK_18 AS TPACK
FROM source_table_pack
WHERE TPACK_18 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'19' AS num,
	TPACK_19 AS TPACK
FROM source_table_pack
WHERE TPACK_19 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'20' AS num,
	TPACK_20 AS TPACK
FROM source_table_pack
WHERE TPACK_20 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'21' AS num,
	TPACK_21 AS TPACK
FROM source_table_pack
WHERE TPACK_21 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'22' AS num,
	TPACK_22 AS TPACK
FROM source_table_pack
WHERE TPACK_22 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'23' AS num,
	TPACK_23 AS TPACK
FROM source_table_pack
WHERE TPACK_23 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'24' AS num,
	TPACK_24 AS TPACK
FROM source_table_pack
WHERE TPACK_24 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'25' AS num,
	TPACK_25 AS TPACK
FROM source_table_pack
WHERE TPACK_25 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'26' AS num,
	TPACK_26 AS TPACK
FROM source_table_pack
WHERE TPACK_26 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'27' AS num,
	TPACK_27 AS TPACK
FROM source_table_pack
WHERE TPACK_27 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'28' AS num,
	TPACK_28 AS TPACK
FROM source_table_pack
WHERE TPACK_28 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'29' AS num,
	TPACK_29 AS TPACK
FROM source_table_pack
WHERE TPACK_29 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'30' AS num,
	TPACK_30 AS TPACK
FROM source_table_pack
WHERE TPACK_30 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'31' AS num,
	TPACK_31 AS TPACK
FROM source_table_pack
WHERE TPACK_31 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'32' AS num,
	TPACK_32 AS TPACK
FROM source_table_pack
WHERE TPACK_32 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'33' AS num,
	TPACK_33 AS TPACK
FROM source_table_pack
WHERE TPACK_33 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'34' AS num,
	TPACK_34 AS TPACK
FROM source_table_pack
WHERE TPACK_34 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'35' AS num,
	TPACK_35 AS TPACK
FROM source_table_pack
WHERE TPACK_35 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'36' AS num,
	TPACK_36 AS TPACK
FROM source_table_pack
WHERE TPACK_36 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'37' AS num,
	TPACK_37 AS TPACK
FROM source_table_pack
WHERE TPACK_37 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'38' AS num,
	TPACK_38 AS TPACK
FROM source_table_pack
WHERE TPACK_38 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'39' AS num,
	TPACK_39 AS TPACK
FROM source_table_pack
WHERE TPACK_39 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'40' AS num,
	TPACK_40 AS TPACK
FROM source_table_pack
WHERE TPACK_40 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'41' AS num,
	TPACK_41 AS TPACK
FROM source_table_pack
WHERE TPACK_41 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'42' AS num,
	TPACK_42 AS TPACK
FROM source_table_pack
WHERE TPACK_42 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'43' AS num,
	TPACK_43 AS TPACK
FROM source_table_pack
WHERE TPACK_43 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'44' AS num,
	TPACK_44 AS TPACK
FROM source_table_pack
WHERE TPACK_44 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'45' AS num,
	TPACK_45 AS TPACK
FROM source_table_pack
WHERE TPACK_45 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'46' AS num,
	TPACK_46 AS TPACK
FROM source_table_pack
WHERE TPACK_46 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'47' AS num,
	TPACK_47 AS TPACK
FROM source_table_pack
WHERE TPACK_47 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'48' AS num,
	TPACK_48 AS TPACK
FROM source_table_pack
WHERE TPACK_48 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'49' AS num,
	TPACK_49 AS TPACK
FROM source_table_pack
WHERE TPACK_49 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'50' AS num,
	TPACK_50 AS TPACK
FROM source_table_pack
WHERE TPACK_50 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'51' AS num,
	TPACK_51 AS TPACK
FROM source_table_pack
WHERE TPACK_51 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'52' AS num,
	TPACK_52 AS TPACK
FROM source_table_pack
WHERE TPACK_52 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'53' AS num,
	TPACK_53 AS TPACK
FROM source_table_pack
WHERE TPACK_53 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'54' AS num,
	TPACK_54 AS TPACK
FROM source_table_pack
WHERE TPACK_54 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'55' AS num,
	TPACK_55 AS TPACK
FROM source_table_pack
WHERE TPACK_55 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'56' AS num,
	TPACK_56 AS TPACK
FROM source_table_pack
WHERE TPACK_56 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'57' AS num,
	TPACK_57 AS TPACK
FROM source_table_pack
WHERE TPACK_57 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'58' AS num,
	TPACK_58 AS TPACK
FROM source_table_pack
WHERE TPACK_58 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'59' AS num,
	TPACK_59 AS TPACK
FROM source_table_pack
WHERE TPACK_59 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'60' AS num,
	TPACK_60 AS TPACK
FROM source_table_pack
WHERE TPACK_60 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'61' AS num,
	TPACK_61 AS TPACK
FROM source_table_pack
WHERE TPACK_61 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'62' AS num,
	TPACK_62 AS TPACK
FROM source_table_pack
WHERE TPACK_62 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'63' AS num,
	TPACK_63 AS TPACK
FROM source_table_pack
WHERE TPACK_63 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'64' AS num,
	TPACK_64 AS TPACK
FROM source_table_pack
WHERE TPACK_64 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'65' AS num,
	TPACK_65 AS TPACK
FROM source_table_pack
WHERE TPACK_65 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'66' AS num,
	TPACK_66 AS TPACK
FROM source_table_pack
WHERE TPACK_66 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'67' AS num,
	TPACK_67 AS TPACK
FROM source_table_pack
WHERE TPACK_67 IS NOT NULL

UNION

SELECT enr,
	wsstf,
	'68' AS num,
	TPACK_68 AS TPACK
FROM source_table_pack
WHERE TPACK_68 IS NOT NULL;

UPDATE source_table_pack
SET tpack_1 = replace(translate(tpack_1, '[]', '()'), ')+(', '+');

DROP TABLE IF EXISTS stp_tp1;
CREATE TABLE stp_tp1 AS
SELECT enr,
	pack_size,
	amounts,
	wsstf,
	drug_code,
	box_size,
	(string_to_array(translate(amounts, '()', ''), '+')) [wsstf::int4] amount,
	tpack_1
FROM (
	SELECT enr,
		(
			SELECT count(*)
			FROM source_table_pack
			WHERE enr = stp.enr
			) pack_size,
		substring(tpack_1, '(\(((\d+x)?[[:digit:].,]+(g|mg|ml|cm sup2)?[., ]*\+?)+\))') amounts,
		wsstf,
		drug_code,
		substring(tpack_1, '(\d+)x')::int4 AS box_size,
		tpack_1
	FROM source_table_pack stp
	) AS s0;

UPDATE stp_tp1
SET amount = regexp_replace(amount, 'x.*$', '', 'g');

UPDATE stp_tp1
SET amount = 1
WHERE amount ~ '(g|mg|ml|cm sup2)';

UPDATE stp_tp1
SET amount = NULL
WHERE NOT amount ~ '^\d+$';

UPDATE stp_tp1
SET amount = NULL,
	box_size = NULL
WHERE coalesce(length(amounts) - length(replace(amounts, '+', '')), 0) + 1 < pack_size;


DROP TABLE IF EXISTS stp_2;
CREATE TABLE stp_2 AS
SELECT 'OMOP' || nextval('new_voc') AS concept_code,
	q.*
FROM (
	SELECT DISTINCT enr,
		num
	FROM stp_1
	WHERE (
			SELECT max(num::int4)
			FROM stp_1 q
			WHERE q.enr = stp_1.enr
			) > 1
	ORDER BY enr,
		num
	) q;

UPDATE stp_1
SET tpack = replace(translate(tpack, '[]', '()'), ')+(', '+');

DROP TABLE IF EXISTS stp_3;
CREATE TABLE stp_3 AS
SELECT concept_code,
	enr,
	pack_size,
	amounts,
	wsstf,
	drug_code,
	box_size,
	(string_to_array(translate(amounts, '()', ''), '+')) [wsstf::int4] amount,
	tpack
FROM (
	SELECT stp_2.concept_code,
		stp_1.enr,
		(
			SELECT count(*)
			FROM source_table_pack
			WHERE enr = stp_1.enr
			) pack_size,
		substring(stp_1.tpack, '(\(((\d+x)?[[:digit:].,]+(g|mg|ml|cm sup2)?[., ]*\+?)+\))') amounts,
		stp_1.wsstf,
		stp.drug_code,
		substring(stp_1.tpack, '(\d+)x')::int4 AS box_size,
		stp_1.tpack
	FROM stp_1
	JOIN stp_2 ON stp_1.enr = stp_2.enr
		AND stp_1.num = stp_2.num
	JOIN source_table_pack stp ON stp.enr = stp_1.enr
		AND stp.wsstf = stp_1.wsstf
	) AS s0;

UPDATE stp_3
SET amount = regexp_replace(amount, 'x.*$', '', 'g');

UPDATE stp_3
SET amount = 1
WHERE amount ~ '(g|mg|ml|cm sup2)';

UPDATE stp_3
SET amount = NULL
WHERE NOT amount ~ '^\d+$';

UPDATE stp_3
SET amount = NULL,
	box_size = NULL
WHERE coalesce(length(amounts) - length(replace(amounts, '+', '')), 0) + 1 < pack_size;

-- insert new packs into drug_concept_stage

-- see 08_drug_concept_stage

truncate table pc_stage;

-- insert into pack content
INSERT INTO pc_stage
SELECT enr AS PACK_CONCEPT_CODE,
	drug_code AS DRUG_CONCEPT_CODE,
	amount::FLOAT,
	box_size
FROM stp_tp1

UNION ALL

SELECT concept_code AS PACK_CONCEPT_CODE,
	drug_code AS DRUG_CONCEPT_CODE,
	amount::FLOAT,
	box_size
FROM stp_3;