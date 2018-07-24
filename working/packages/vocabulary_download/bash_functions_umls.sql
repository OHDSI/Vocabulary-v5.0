DO $_$
DECLARE
z text;
BEGIN
  z:=$FUNCTIONBODY$
    CREATE OR REPLACE FUNCTION vocabulary_download.get_umls_prepare (iPath text, iFilename text)
    RETURNS void AS
    $BODY$#!/bin/bash
    #set permissions=775 by default
    umask 002 && \
    cd "$1/work" && \
    f=$(unzip -l "$2" | awk 'NR == 4 {print $4}') && \
    unzip -oq "$2" && \
    cd "$f" && \
    unzip -oq "mmsys.zip" && \
    mkdir -p "done"
    
    #MetaMorphoSys part
    #https://www.nlm.nih.gov/research/umls/implementation_resources/community/mmsys/BatchMetaMorphoSys.html

    #
    # Specify directory containing .RRF or .nlm files
    #

    METADIR="$1/work/$f"

    #
    # Specify output directory
    #
    DESTDIR="$METADIR/done"

    #
    # Specify MetamorphoSys directory
    #
    MMSYS_HOME="$METADIR"

    #
    # Specify CLASSPATH
    #
    CLASSPATH="$MMSYS_HOME:$MMSYS_HOME/lib/jpf-boot.jar"
    #
    # Specify JAVA_HOME
    #
    JAVA_HOME="$MMSYS_HOME/jre/linux"

    #
    # Specify configuration file
    #
    CONFIG_FILE="$(find $METADIR -type f -name user.d.prop)"

    #
    # Run Batch MetamorphoSys
    #
    export METADIR
    export DESTDIR
    export MMSYS_HOME
    export CLASSPATH
    export JAVA_HOME
    cd "$MMSYS_HOME"
    $JAVA_HOME/bin/java -Djava.awt.headless=true -Djpf.boot.config=$MMSYS_HOME/etc/subset.boot.properties \
    -Dlog4j.configurationFile=$MMSYS_HOME/etc/subset.log4j.properties -Dinput.uri=$METADIR \
    -Doutput.uri=$DESTDIR -Dmmsys.config.uri=$CONFIG_FILE -XX:ParallelGCThreads=4 -Xms300M -Xmx5000M org.java.plugin.boot.Boot
    
    #move result to original folder
    cd "$DESTDIR"
    mv "MRCONSO.RRF" "$1" && \
    mv "MRHIER.RRF" "$1" && \
    mv "MRMAP.RRF" "$1" && \
    mv "MRSMAP.RRF" "$1" && \
    mv "MRSAT.RRF" "$1" && \
    mv "MRREL.RRF" "$1"
    $BODY$
    LANGUAGE 'plsh'
    SECURITY DEFINER;
  $FUNCTIONBODY$;
  --convert CRLF to LF for bash
  EXECUTE REPLACE(z,E'\r','');
END $_$;