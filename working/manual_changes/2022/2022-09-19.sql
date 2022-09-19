--add new domain='Note'
DO $_$
BEGIN
	PERFORM vocabulary_pack.AddNewDomain(
		pDomain_id		=>'Note',
		pDomain_name	=>'Note'
	);
END $_$;