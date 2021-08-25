--fix concept names with invalid dosages [AVOF-2276]
--for table concept
UPDATE concept c
SET concept_name = i.new_name
FROM (
	SELECT s0.concept_id,
		s0.new_name
	FROM (
		SELECT c.concept_id,
			l.aggr_name AS new_name,
			(REGEXP_MATCHES(c.concept_name, '\.([\d])+?([\d])\2{7,}[\d]+')) dig_arr
		FROM concept c
		CROSS JOIN LATERAL(SELECT STRING_AGG(CASE 
						WHEN m ~ '^[\d]+\.[\d]+$'
							THEN TRIM(TRAILING '.' FROM TO_CHAR(ROUND(m::NUMERIC, 5), 'FM9999999999999999999990.999999999999999999999'))
						WHEN m ~ '^\.[\d]+$'
							THEN --without leading zero, e.g. '24 HOUR Rotigotine .166666666666666666666666666666666666667 MG/HOUR Other ...'
								TRIM(TRAILING '.' FROM TO_CHAR(ROUND(('0' || m)::NUMERIC, 5), 'FM9999999999999999999990.999999999999999999999'))
						ELSE m
						END, ' ') AS aggr_name FROM (
				SELECT UNNEST(REGEXP_MATCHES(c.concept_name, '[^ ]+', 'g')) m
				) AS s0) l
		WHERE c.vocabulary_id IN (
				'RxNorm Extension',
				'GRR'
				)
			AND c.concept_name ~ '\.[\d]+([\d])\1{5,}[\d]+'
		) AS s0
	WHERE s0.dig_arr [1] <> s0.dig_arr [2]
	) i
WHERE i.concept_id = c.concept_id;

--same for concept_synonym
UPDATE concept_synonym syn
SET concept_synonym_name = i.new_name
FROM (
	SELECT s0.concept_id,
		s0.old_name,
		s0.new_name
	FROM (
		SELECT c.concept_id,
			syn.concept_synonym_name AS old_name,
			l.aggr_name AS new_name,
			(REGEXP_MATCHES(syn.concept_synonym_name, '\.([\d])+?([\d])\2{7,}[\d]+')) dig_arr
		FROM concept c
		JOIN concept_synonym syn ON syn.concept_id = c.concept_id
		CROSS JOIN LATERAL(SELECT STRING_AGG(CASE 
						WHEN m ~ '^[\d]+\.[\d]+$'
							THEN TRIM(TRAILING '.' FROM TO_CHAR(ROUND(m::NUMERIC, 5), 'FM9999999999999999999990.999999999999999999999'))
						WHEN m ~ '^\.[\d]+$'
							THEN --without leading zero, e.g. '24 HOUR Rotigotine .166666666666666666666666666666666666667 MG/HOUR Other ...'
								TRIM(TRAILING '.' FROM TO_CHAR(ROUND(('0' || m)::NUMERIC, 5), 'FM9999999999999999999990.999999999999999999999'))
						ELSE m
						END, ' ') AS aggr_name FROM (
				SELECT UNNEST(REGEXP_MATCHES(syn.concept_synonym_name, '[^ ]+', 'g')) m
				) AS s0) l
		WHERE c.vocabulary_id IN (
				'RxNorm Extension',
				'GRR'
				)
			AND syn.concept_synonym_name ~ '\.[\d]+([\d])\1{5,}[\d]+'
		) AS s0
	WHERE s0.dig_arr [1] <> s0.dig_arr [2]
	) i
WHERE i.concept_id = syn.concept_id;

--fix column types, invalid values (box_size)
do $$
declare
A record;
begin
--first, drop all views 'r_to_c' (no longer needed, new rxe_builder uses r_to_c as a table)
for A in (
  select schemaname, viewname from pg_views where viewname like 'r_to_c%' --r_to_c, r_to_c2 etc
) loop
  execute 'DROP VIEW '||A.schemaname||'.'||A.viewname;
end loop;
--manual view drops which depends on tables below
drop view dalex.name;

--second, update/alter tables
for A in (
  select schemaname, tablename from pg_tables where tablename in ('relationship_to_concept','pc_stage','ds_stage','drug_strength','drug_strength_stage','pack_content','pack_content_stage')
  and schemaname<>'devv4' --devv4 has its own DDL, types will be corrected automatically
) loop
  case A.tablename
  when 'relationship_to_concept' then execute 'ALTER TABLE '||A.schemaname||'.relationship_to_concept ALTER COLUMN conversion_factor TYPE NUMERIC, ALTER COLUMN precedence TYPE INT2';
  when 'pc_stage' then execute 'ALTER TABLE '||A.schemaname||'.pc_stage ALTER COLUMN amount TYPE INT2, ALTER COLUMN box_size TYPE INT2';
  when 'ds_stage' then execute 'ALTER TABLE '||A.schemaname||'.ds_stage ALTER COLUMN amount_value TYPE NUMERIC, ALTER COLUMN numerator_value TYPE NUMERIC, ALTER COLUMN denominator_value TYPE NUMERIC, ALTER COLUMN box_size TYPE INT2';
  when 'drug_strength' then
    --update relevant tables first due to drug_strength has invalid box_size for int2
    execute 'UPDATE '||A.schemaname||'.concept_relationship cr SET valid_end_date=CURRENT_DATE, invalid_reason=''D'' FROM '||A.schemaname||'.drug_strength ds WHERE ds.drug_concept_id=cr.concept_id_2 AND ds.box_size>=32000 AND cr.relationship_id=''Maps to'' AND cr.invalid_reason IS NULL';
    execute 'UPDATE '||A.schemaname||'.concept_relationship cr SET valid_end_date=CURRENT_DATE, invalid_reason=''D'' FROM '||A.schemaname||'.drug_strength ds WHERE ds.drug_concept_id=cr.concept_id_1 AND ds.box_size>=32000 AND cr.relationship_id=''Mapped from'' AND cr.invalid_reason IS NULL';
    execute 'UPDATE '||A.schemaname||'.concept c SET valid_end_date=CURRENT_DATE, invalid_reason=''D'', standard_concept=NULL FROM '||A.schemaname||'.drug_strength ds WHERE ds.drug_concept_id=c.concept_id AND ds.box_size>=32000';
    execute 'DELETE FROM '||A.schemaname||'.drug_strength WHERE box_size>=32000';
    execute 'ALTER TABLE '||A.schemaname||'.drug_strength ALTER COLUMN amount_value TYPE NUMERIC, ALTER COLUMN numerator_value TYPE NUMERIC, ALTER COLUMN denominator_value TYPE NUMERIC, ALTER COLUMN box_size TYPE INT2';
  when 'drug_strength_stage' then execute 'ALTER TABLE '||A.schemaname||'.drug_strength_stage ALTER COLUMN amount_value TYPE NUMERIC, ALTER COLUMN numerator_value TYPE NUMERIC, ALTER COLUMN denominator_value TYPE NUMERIC';
  when 'pack_content' then execute 'ALTER TABLE '||A.schemaname||'.pack_content ALTER COLUMN amount TYPE INT2, ALTER COLUMN box_size TYPE INT2';
  when 'pack_content_stage' then execute 'ALTER TABLE '||A.schemaname||'.pack_content_stage ALTER COLUMN amount TYPE INT2, ALTER COLUMN box_size TYPE INT2';
  end case;
end loop;
end $$;