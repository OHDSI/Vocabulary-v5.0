DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_ndc_spl_prepare (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    unzip -oq "$2*.zip" -d . 2> >(grep -v "were successfully processed")
    
    #getting xml-files
    rm -rf "xmlfolder"
    mkdir "xmlfolder"
    unzip -oq "homeopathic/*.zip" "*.xml" -d "xmlfolder" 2> >(grep -v "were successfully processed")
    unzip -oq "otc/*.zip" "*.xml" -d "xmlfolder" 2> >(grep -v "were successfully processed")
    unzip -oq "prescription/*.zip" "*.xml" -d "xmlfolder" 2> >(grep -v "were successfully processed")
    unzip -oq "other/*.zip" "*.xml" -d "xmlfolder" 2> >(grep -v "were successfully processed")
    
    #create index-file
    find "xmlfolder" -maxdepth 1 -name "*.xml" > allxmlfilelist.dat
    
    #cleaning
    rm -rf homeopathic
    rm -rf otc
    rm -rf prescription
    rm -rf other
    
    #move result to original folder
    cd "$1"
    rm -f *.*
    mv work/*.txt .
    mv work/allxmlfilelist.dat .
    mv work/xmlfolder .
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;