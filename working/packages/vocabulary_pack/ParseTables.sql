CREATE OR REPLACE FUNCTION vocabulary_pack.ParseTables (
  pDDL_sql text
)
RETURNS TABLE (
  table_name varchar,
  column_name varchar,
  ordinal_position int,
  column_default varchar,
  is_nullable varchar,
  column_type varchar,
  character_maximum_length int
) AS
$BODY$
DECLARE
  cDevSchema constant varchar(100):='dev_cdm_'||md5(random()::varchar||clock_timestamp()::varchar);
  crlfSQL constant varchar(4):=E'\r\n';
BEGIN
  EXECUTE 'CREATE USER '||cDevSchema||' WITH PASSWORD ''123''; CREATE SCHEMA AUTHORIZATION '||cDevSchema;
  EXECUTE 'SET LOCAL SEARCH_PATH TO '||cDevSchema;
  EXECUTE 'DO $DDLSctipt$ BEGIN '||crlfSQL||pDDL_sql||crlfSQL||' END $DDLSctipt$';
  RETURN QUERY
    SELECT i.table_name::VARCHAR,
        i.column_name::VARCHAR,
        i.ordinal_position::INT,
        CASE 
            WHEN i.column_default LIKE 'nextval(%::regclass)'
                THEN NULL
            ELSE i.column_default
            END column_default,
        i.is_nullable::VARCHAR,
        --i.data_type,
        CASE 
            WHEN i.column_default LIKE 'nextval(%::regclass)'
                THEN CASE i.udt_name
                        WHEN 'int2'
                            THEN 'smallserial'
                        WHEN 'int4'
                            THEN 'serial'
                        WHEN 'int8'
                            THEN 'bigserial'
                        END
            ELSE CASE i.udt_name
                    WHEN 'int2'
                        THEN 'smallint'
                    WHEN 'int4'
                        THEN 'integer'
                    WHEN 'int8'
                        THEN 'bigint'
                    ELSE i.udt_name::VARCHAR
                    END
            END column_type,
        i.character_maximum_length::INT
    FROM information_schema.columns i
    WHERE i.table_schema = cDevSchema;
  
  RESET SEARCH_PATH;
  EXECUTE 'DROP SCHEMA '||cDevSchema||' CASCADE';
  EXECUTE 'DROP USER '||cDevSchema;
END;
$BODY$
LANGUAGE 'plpgsql' SECURITY DEFINER
SET client_min_messages = error;

REVOKE EXECUTE ON FUNCTION vocabulary_pack.ParseTables FROM PUBLIC, role_read_only;