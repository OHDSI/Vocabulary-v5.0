--add new vocabulary='NCCD'
DO $_$
BEGIN
    PERFORM VOCABULARY_PACK.AddNewVocabulary(
    pVocabulary_id          => 'NCCD',
    pVocabulary_name        => 'Normalized Chinese Clinical Drug',
    pVocabulary_reference   => 'https://www.ohdsi.org/wp-content/uploads/2020/07/NCCD_RxNorm_Mapping_0728.pdf',
    pVocabulary_version     => NULL,
    pOMOP_req               => NULL,
    pClick_default          => NULL,
    pAvailable              => NULL, -- unrestricted license
    pURL                    => NULL,
    pClick_disabled         => NULL
);
END $_$;
