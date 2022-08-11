CREATE OR REPLACE FUNCTION devv5.SendMailHTML (
  recipient text,
  subject text,
  send_message text
)
RETURNS text AS
$body$
import smtplib
import base64
mail_sender = "=your@mail.com="
mail_password = "=app_password="
mail_smtp = "smtp.gmail.com"
mail_port = "587"
recipients = recipient.split(',')
message = ("From: %s\nTo: %s\nSubject: %s\nContent-type: text/html; charset=UTF-8\n\n %s" % (mail_sender,recipient,subject,send_message))
try:
  smtpObj=smtplib.SMTP(mail_smtp,mail_port,timeout=30)
  smtpObj.starttls()
  smtpObj.login(mail_sender,mail_password)
  smtpObj.sendmail(mail_sender,recipients,message)
  smtpObj.quit()
  message='Ok'
except smtplib.SMTPException as e:
  message='Error: '+str(e)
return message
$body$
LANGUAGE 'plpython3u';