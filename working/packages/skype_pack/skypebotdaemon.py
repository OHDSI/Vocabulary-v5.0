from skpy import Skype, SkypeEventLoop, SkypeNewMessageEvent, SkypeUtils
from config import skype_email, skype_password, skype_tokenfile, db_host, db_port, db_database, db_user, db_password, skype_admin_contact
import sys, psycopg2, re, time
from bs4 import BeautifulSoup, MarkupResemblesLocatorWarning
from threading import Thread
import warnings
warnings.filterwarnings('ignore', category=MarkupResemblesLocatorWarning)

#all mention tag starts with <at id=", then number with colon
#8: means single account, 28: - bot, 19 - group chat, 2 - Skype for Business etc
mentioned_match=re.compile(r'^<at id="\d+:(.+?)">.+?</at>')
clear_match=re.compile(r'^[\t\r\n\v\f\s]+|[\t\r\n\v\f\s]+$')

def db_connect():
    global db_connection
    db_connection=psycopg2.connect(
        host=db_host,
        port=db_port,
        database=db_database,
        user=db_user,
        password=db_password)
    db_connection.set_session(autocommit=True)

def check_db_connection():
    try:
        with db_connection.cursor() as sql:
            sql.execute('SELECT 1;')
    except psycopg2.OperationalError:
        db_connect()

def db_log_query (s_userid, s_username, s_chatid, s_query, s_rawquery):
    check_db_connection()
    with db_connection.cursor() as sql:
        sql.execute('SELECT skype_pack.LogQuery (%s, %s, %s, %s, %s);', (s_userid, s_username, s_chatid, s_query, s_rawquery))

def db_check_allowed_users (s_userid):
    check_db_connection()
    with db_connection.cursor() as sql:
        sql.execute('SELECT 1 FROM skype_pack.skype_allowed_users WHERE skype_userid = %s;', (s_userid,))
        return bool(sql.rowcount)


def clear_string(s):
    s=mentioned_match.sub('', s)
    return clear_match.sub('', s)

class SkypeListener(SkypeEventLoop):
    def __init__(self):
        super(SkypeListener, self).__init__(skype_email, skype_password, skype_tokenfile) #, True, SkypeUtils.Status.Online -- not working with "404 response from PUT" error
        #self.setPresence() - not working (setting status Online)
    def onEvent(self, event):
        if isinstance(event, SkypeNewMessageEvent): 
            for request in self.contacts.requests():
                print ('{0} [info]: new request from user {1}'.format(time.strftime('%Y%m%d %H:%M:%S'), request.user.id))
                if db_check_allowed_users(request.user.id):
                    request.accept()

            mentioned=mentioned_match.search(event.msg.content)
            is_botmentioned=True if (mentioned and mentioned.group(1)==self.userId) else False
            is_singlechat=event.msg.chatId.startswith('8:')
            content=clear_string(event.msg.content)

            if not (event.msg.userId == self.userId) and content and ((is_botmentioned and not is_singlechat) or (is_singlechat and not (mentioned and not is_botmentioned))) and db_check_allowed_users(event.msg.userId):
                try:
                    db_log_query(event.msg.userId, str(self.contacts[event.msg.userId].name), event.msg.chatId, BeautifulSoup(content,'html.parser').get_text(), content)
                except Exception as ex:
                    skype.contacts[skype_admin_contact].chat.sendMsg('{0}:\r{1}'.format(event.msg.bold('Fatal error'), ex), rich=True)

class SkypeQueueListener(Thread):
    def __init__(self):
        Thread.__init__(self)
        self.daemon = True
        self.start()
    def run(self):
        while True:
            check_db_connection()
            try:
                with db_connection.cursor() as sql:
                    sql.execute('SELECT skype_pack.RunQueue ();')
            except Exception as ex:
                print ('{0} [db error]: {1}'.format(time.strftime('%Y%m%d %H:%M:%S'), ex))
            finally:
                time.sleep(1)

while True:
    try:
        db_connect()
        skype = Skype(skype_email, skype_password, skype_tokenfile)
        skype.contacts[skype_admin_contact].chat.sendMsg("I'm online")

        SkypeQueueListener()
        SkypeListener().loop()
    except Exception as ex:
        print ('{0} [error]: {1}'.format(time.strftime('%Y%m%d %H:%M:%S'), ex))
        time.sleep(10)
    finally:
        db_connection.close()
        skype.conn.sess.close()