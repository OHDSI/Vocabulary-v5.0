CREATE OR REPLACE FUNCTION vocabulary_pack.CheckAllVocabularies (
)
RETURNS void AS
$body$
declare
        cVocab devv5.vocabulary_access%rowtype;
        cRet                   VARCHAR (1000);
        cOldDate               DATE;
        cNewDate               DATE;
        cOldVersion            VARCHAR (100);
        cNewVersion            VARCHAR (100);
        cMailText              VARCHAR (20000);
        crlf                   VARCHAR (4) := '<br>';
        email         CONSTANT VARCHAR (1000):=('timur.vakhitov@firstlinesoftware.com');
        cHTML_OK      CONSTANT VARCHAR (100) := '<font color=''green''>&#10004;</font> ';
        cHTML_ERROR   CONSTANT VARCHAR (100) := '<font color=''red''>&#10008;</font> ';
begin
    FOR cVocab IN (SELECT DISTINCT vocabulary_id FROM devv5.vocabulary_access ORDER BY vocabulary_id)
        LOOP
            BEGIN
                SELECT old_date, new_date, old_version, new_version into cOldDate, cNewDate, cOldVersion, cNewVersion FROM vocabulary_pack.CheckVocabularyUpdate (cVocab.vocabulary_id);

                IF COALESCE(cOldDate::varchar, cNewDate::varchar, cOldVersion, cNewVersion) IS NOT NULL
                THEN
                    cRet:=COALESCE(cOldDate::varchar,cOldVersion) || ' -> ' || COALESCE(cNewDate::varchar,cNewVersion);
                    
                    cRet := '<b>' || cVocab.vocabulary_id || '</b> is updated! [' || cRet || ']';

                    IF cMailText IS NULL
                    THEN
                        cMailText := cHTML_OK || cRet;
                    ELSE
                        cMailText := cMailText || crlf || cHTML_OK || cRet;
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    cRet := '<b>' || cVocab.vocabulary_id || '</b> returns error:' || crlf || SQLERRM;

                    IF cMailText IS NULL
                    THEN
                        cMailText := cHTML_ERROR || cRet;
                    ELSE
                        cMailText := cMailText || crlf || cHTML_ERROR || cRet;
                    END IF;
            END;
        END LOOP;

        IF cMailText IS NOT NULL
        THEN
            perform devv5.SendMailHTML (email, 'Vocabulary checks notification', cMailText);
        END IF;
        
end;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;