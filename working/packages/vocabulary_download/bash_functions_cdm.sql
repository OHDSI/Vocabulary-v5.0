DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_cdm_prepare (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    unzip -oqjC "$2" "*/PostgreSQL/*ddl*" -d .
    
    #move result to original folder
    cd "$1"
    rm -f *.*
    #fix old versions
    if [ -f "work/OMOP CDM ddl - PostgreSQL.sql" ] ; then
      mv "work/OMOP CDM ddl - PostgreSQL.sql" "work/OMOP CDM postgresql ddl.txt"
    fi
    #fix 4.0.0
    if [ -f "work/CDM V4 DDL.sql" ] ; then
      mv "work/CDM V4 DDL.sql" "work/OMOP CDM postgresql ddl.txt"
    fi
    if [ ! -f "work/OMOP CDM Results postgresql ddl.txt" ] ; then
      touch "work/OMOP CDM Results postgresql ddl.txt"
    fi
    mv work/*.txt .
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;