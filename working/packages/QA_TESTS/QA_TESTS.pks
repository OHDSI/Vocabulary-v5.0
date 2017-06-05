CREATE OR REPLACE PACKAGE DEVV5.QA_TESTS
    AUTHID CURRENT_USER
IS
    PROCEDURE purge_cache;

    FUNCTION get_summary (table_name IN VARCHAR2, pCompareWith IN VARCHAR2 DEFAULT 'PRODV5')
        RETURN rep_t_GetSummary;

    FUNCTION get_checks (check_id IN NUMBER DEFAULT NULL)
        RETURN rep_t_GetChecks;
END QA_TESTS;
/