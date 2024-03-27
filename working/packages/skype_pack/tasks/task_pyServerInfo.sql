CREATE OR REPLACE FUNCTION skype_pack.task_pyServerInfo (pTaskCommand TEXT, pSkypeUserID TEXT, pSkypeChatID TEXT, pLogID INT4)
RETURNS VOID AS
$BODY$
  import psutil, time
  from psutil._common import bytes2human

  crlf='\r\n'
  delimiter='\t'
  
  sql=plpy.prepare("SELECT SendMessage (pSkypeUserID=>$1, pMessage=>$2, pSkypeChatID=>$3, pNewLine=>TRUE, pQueryLogID=>$4, pFormat=>TRUE);", ["text", "text", "text", "int4"])
  sqlFrmt=plpy.prepare("SELECT FormatTableData (pTEXT=>$1);", ["text"])
  
  def formatTableData (message):
    return plpy.execute(sqlFrmt, [message])[0]['formattabledata']

  #cpu usage
  cores_count=psutil.cpu_count(logical=False)
  title='CPU load average (+percentage of physical cores ('+str(cores_count)+')):'+crlf
  header=delimiter.join(['L_avg (1 min)', 'L_avg (5 mins)', 'L_avg (15 mins)'])+crlf
  loadavg=psutil.getloadavg()
  data=delimiter.join([
    str(round(loadavg[0],2))+' ('+str(round(loadavg[0]*100/cores_count,2))+'%)',
    str(round(loadavg[1],2))+' ('+str(round(loadavg[1]*100/cores_count,2))+'%)',
    str(round(loadavg[2],2))+' ('+str(round(loadavg[2]*100/cores_count,2))+'%)'])
  ret='{0}{1}{2}{3}'.format(title, '{code}', formatTableData(header+data), '{code}')
  
  #disk usage
  start_time=time.time()
  disk_io_counter=psutil.disk_io_counters()
  start_read_bytes=disk_io_counter.read_bytes
  start_write_bytes=disk_io_counter.write_bytes
  start_busy_time=disk_io_counter.busy_time
  start_read_count=disk_io_counter.read_count
  start_write_count=disk_io_counter.write_count

  time.sleep(2)

  disk_io_counter=psutil.disk_io_counters()
  end_read_bytes=disk_io_counter.read_bytes
  end_write_bytes=disk_io_counter.write_bytes
  end_busy_time=disk_io_counter.busy_time
  end_read_count=disk_io_counter.read_count
  end_write_count=disk_io_counter.write_count
  end_time=time.time()

  time_diff=end_time - start_time
  read_speed=(end_read_bytes - start_read_bytes)/time_diff
  write_speed=(end_write_bytes - start_write_bytes)/time_diff
  read_count=str(round((end_read_count - start_read_count)/time_diff))
  write_count=str(round((end_write_count - start_write_count)/time_diff))
  time_diff=time_diff*10**3 #convert to milliseconds
  busy_percent=str(round((end_busy_time - start_busy_time)/time_diff*100,2))+'%'

  #convert to megabytes/s
  read_h=bytes2human(read_speed)+'/s'
  write_h=bytes2human(write_speed)+'/s'

  title='HDD utilization (read speed, write speed, number of reads, number of writes, % utilization):'+crlf
  header=delimiter.join(['Read_speed', 'Write_speed', 'R_count', 'W_count', '%Util'])+crlf
  data=delimiter.join([read_h, write_h, read_count, write_count, busy_percent])
  ret+=crlf+crlf+'{0}{1}{2}{3}'.format(title, '{code}', formatTableData(header+data), '{code}')

  #HDD space usage
  title='HDD space usage (DB data) in /data:'+crlf
  header=delimiter.join(['Total', 'Used', 'Free', '%Used'])+crlf
  disk=psutil.disk_usage('/data')
  data=delimiter.join([
    bytes2human(disk.total),
    bytes2human(disk.used),
    bytes2human(disk.free),
    str(disk.percent)+'%'
    ])
  ret+=crlf+crlf+'{0}{1}{2}{3}'.format(title, '{code}', formatTableData(header+data), '{code}')

  #memory usage
  title='Memory usage:'+crlf
  header=delimiter.join(['Total_RAM', '%RAM_used', 'Total_Swap', '%Swap_used'])+crlf
  memory=psutil.virtual_memory()
  swap=psutil.swap_memory()
  data=delimiter.join([
    bytes2human(memory.total),
    #bytes2human(memory.available),
    str(memory.percent)+'%',
    bytes2human(swap.total),
    str(swap.percent)+'%'
    ])
  ret+=crlf+crlf+'{0}{1}{2}{3}'.format(title, '{code}', formatTableData(header+data), '{code}')

  plpy.execute(sql, [pskypeuserid, ret, pskypechatid, plogid])
$BODY$
LANGUAGE 'plpython3u'
SET search_path = skype_pack, pg_temp;

REVOKE EXECUTE ON FUNCTION skype_pack.task_pyServerInfo FROM PUBLIC;

DO $_$
BEGIN
	PERFORM skype_pack.AddTask(
	pTaskCommand			=> 'server info',
	pTaskProcedureName		=> 'task_pyServerInfo',
	pTaskDescription		=> 'Shows server information (CPU usage, memory, etc.)',
	pTaskType				=> 'instant'
	);
END $_$;