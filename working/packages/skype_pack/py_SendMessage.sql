CREATE OR REPLACE FUNCTION skype_pack.py_SendMessage (config_path text, userid text, chatid text, message text, newline boolean=FALSE, format boolean=FALSE)
RETURNS VOID AS
$BODY$
  #do not call directly, use skype_pack.SendMessage() instead
  from skpy import Skype, SkypeEventLoop, SkypeNewMessageEvent, SkypeMsg
  import sys, re, html
  sys.path.insert(1, config_path)
  from config import skype_email, skype_password, skype_tokenfile
  
  skype = Skype(skype_email, skype_password, skype_tokenfile)
  if not skype.contacts[userid]:
    raise ValueError("userid='{0}' not found in bot's userlist".format(userid))
  
  global message
  message=html.escape(message, quote=False)
  if format:
    #formatting message (very limited support)
    message=re.sub(r'(^|\s)_(.+?)_([\s.,!?]|$)', r'\1<i raw_pre="_" raw_post="_">\2</i>\3', message, 0, re.MULTILINE | re.DOTALL) #italic
    message=re.sub(r'(^|\s)\*(.+?)\*([\s.,!?]|$)', r'\1<b raw_pre="*" raw_post="*">\2</b>\3', message, 0, re.MULTILINE | re.DOTALL) #bold
    message=re.sub(r'(^|\s)~(.+?)~([\s.,!?]|$)', r'\1<s raw_pre="~" raw_post="~">\2</s>\3', message, 0, re.MULTILINE | re.DOTALL) #strike
    message=re.sub(r'(^|\s){code}(.+?){code}([\s.,!?]|$)', r'\1<pre raw_pre="{{code}}" raw_post="{{code}}">\2</pre>\3', message, 0, re.MULTILINE | re.DOTALL) #mono

  if ('8:'+userid)==chatid:
    #personal chat
    skype.contacts[userid].chat.sendMsg(message, rich=True)
  else:
    skype.chats[chatid].sendMsg('{0}{1}{2}'.format(SkypeMsg.mention(skype.contacts[userid]), '\n' if newline else ' ', message), rich=True)

  skype.conn.sess.close()
$BODY$
LANGUAGE 'plpython3u';

REVOKE EXECUTE ON FUNCTION skype_pack.py_SendMessage FROM PUBLIC;