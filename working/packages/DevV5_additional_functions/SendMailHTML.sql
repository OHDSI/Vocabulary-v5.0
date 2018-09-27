CREATE OR REPLACE FUNCTION devv5.sendmailhtml (
  recipient text,
  subject text,
  send_message text
)
RETURNS text AS
$body$
import smtplib
import base64
mail_sender = "=your@mail.com="
mail_smtp = "smtp.gmail.com"
mail_port = "587"
recipients = recipient.split(',')
message = ("From: %s\nTo: %s\nSubject: %s\nContent-type: text/html; charset=UTF-8\n\n %s" % (mail_sender,recipient,subject,send_message))
try:
  smtpObj=smtplib.SMTP(mail_smtp,mail_port,timeout=30)
  smtpObj.starttls()
  smtpObj.docmd('AUTH LOGIN', base64.b64encode(mail_sender))
  smtpObj.docmd('=password_in_base64=','')
  smtpObj.sendmail(mail_sender,recipients,message)
  smtpObj.quit()
  message='Ok'
except smtplib.SMTPException as e:
  message='Error: '+str(e)
return message
$body$
LANGUAGE 'plpythonu'
VOLATILE
CALLED ON NULL INPUT
SECURITY DEFINER
COST 100;