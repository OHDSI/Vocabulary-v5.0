CREATE OR REPLACE FUNCTION cde_split_group(pgroup_id int, pgroup_code character varying [] DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
AS $function$
/*
 * Split the group into separate concepts
 * Example:
 * 	--Split group into a new group
 * 		select * from cde_split_group(15);
 * 
 *  --Detach selected group code values into a new group
 *		select * from cde_split_group(15, ARRAY['A15.5:ICD10CM','A15.5:ICD10','A15.6:ICD10CM','A15.6:ICD10','A15.7:ICD10CM','A15.7:ICD10']);
 */

BEGIN
	
	IF NOT EXISTS(SELECT 1 FROM cde_manual_group WHERE group_id = pgroup_id)
	THEN
			RAISE EXCEPTION 'The supplied group_id does not exist!';
	END IF;

	IF pgroup_code IS NOT NULL AND ARRAY_LENGTH(pgroup_code, 1) > 1 
		AND NOT EXISTS (SELECT 1 FROM cde_manual_group WHERE group_id = pgroup_id AND group_code @> pgroup_code)
	THEN 
			RAISE EXCEPTION 'One or more of the elements sent in the group_code parameter does not match the content of group code for group id=%!',pgroup_id;
	END IF ;

	WITH cte_group_code AS (
		SELECT 	group_id,
				unnest (group_code) as group_code
		FROM cde_manual_group	
		WHERE group_id = pgroup_id )
		INSERT INTO cde_manual_group (sorce_code,sorce_code_description,sorce_vocabulary_id,group_name,group_id,group_code)
		SELECT grm.sorce_code,
				grm.sorce_code_description,
				grm.sorce_vocabulary_id,
				grm.group_name,
				CASE 
					WHEN pgroup_code IS NULL THEN NULL --split
					ELSE nextval('seq_cde_manual_group_id') -- detach
				END AS group_id,
				array_agg(cgc.group_code) AS group_code
		FROM cde_manual_group AS grm
		JOIN cte_group_code cgc ON grm.group_id  = cgc.group_id
		WHERE (pgroup_code IS NULL OR cgc.group_code = ANY (pgroup_code))
		GROUP BY grm.sorce_code,grm.sorce_code_description,grm.sorce_vocabulary_id,grm.group_name;

	
END;
$function$;