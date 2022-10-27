CREATE OR REPLACE FUNCTION devv5.SendMailHTML (
  recipient text,
  subject text,
  send_message text
)
RETURNS text AS
$body$
import smtplib
from email.mime.text import MIMEText
from email.header import Header
mail_sender = "=your@mail.com="
mail_password = "=app_password="
mail_smtp = "smtp.gmail.com"
mail_port = "587"
recipients = recipient.split(',')
message = MIMEText(send_message, 'html', 'utf-8')
message['From'] = mail_sender
message['To'] = recipient
message['Subject'] = Header(subject, 'utf-8')
try:
  smtpObj=smtplib.SMTP(mail_smtp,mail_port,timeout=30)
  smtpObj.starttls()
  smtpObj.login(mail_sender,mail_password)
  smtpObj.sendmail(mail_sender,recipients,message.as_string())
  smtpObj.quit()
  message='Ok'
except smtplib.SMTPException as e:
  message='Error: '+str(e)
return message
$body$
LANGUAGE 'plpython3u';