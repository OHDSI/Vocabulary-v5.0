CREATE OR REPLACE FUNCTION ai_pack.ChatGPT (
--https://platform.openai.com/docs/api-reference/chat/create
	pQuery TEXT,
	pModelEngine TEXT DEFAULT 'gpt-3.5-turbo',
	pMaxTokens INT4 DEFAULT 1024,
	pTemperature NUMERIC DEFAULT 0.5,
	pTopProbability NUMERIC DEFAULT 1,
	pFrequencyPenalty NUMERIC DEFAULT 0,
	pPresencePenalty NUMERIC DEFAULT 0
)
RETURNS TABLE (
	chatgpt_reply TEXT,
	log_id INT4
)
AS
$BODY$
  '''
	--https://platform.openai.com/docs/api-reference/chat/create
	engine: ID of the model to use (gpt-4, gpt-3.5-turbo, gpt-3.5-turbo-16k etc). More: https://platform.openai.com/docs/models/gpt-3-5
	max_tokens: Set a limit on the number of tokens per model response. The API supports a maximum of 4096 tokens shared between the prompt (including system message, examples, message history, and user query) and the model's response. One token is roughly four characters for typical English text.
	temperature: What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic. Try adjusting temperature or top_p but not both.
	top_p: Similar to temperature, this controls randomness but uses a different method. Lowering top_p narrows the model's token selection to likelier tokens. Increasing top_p lets the model choose from tokens with both high and low likelihood. Try adjusting temperature or top_p but not both.
	frequency_penalty: Number between -2.0 and 2.0. Positive values penalize new tokens based on their existing frequency in the text so far, decreasing the model's likelihood to repeat the same line verbatim
	presence_penalty: Number between -2.0 and 2.0. Positive values penalize new tokens based on whether they appear in the text so far, increasing the model's likelihood to talk about new topics
  '''
  import subprocess, json, time
  
  gpt_sleep_interval=10 #in seconds
  gpt_sleep_step=5 #in seconds
  
  input_params=json.dumps({
    'pModelEngine': "%s" % pmodelengine,
    'pMaxTokens': "%s" % pmaxtokens,
    'pTemperature': "%s" % ptemperature,
    'pTopProbability': "%s" % ptopprobability,
    'pFrequencyPenalty': "%s" % pfrequencypenalty,
    'pPresencePenalty': "%s" % ppresencepenalty
  })

  chatgpt_log_query = plpy.prepare("SELECT log_id FROM ai_pack.ChatGPT_WriteLog ($1, $2, $3, $4) AS log_id", ["text", "jsonb", "text", "jsonb"])
  sleep_interval=gpt_sleep_interval-gpt_sleep_step

  while True:
      try:
        error_text=res=usage_tokens=None
        sleep_interval+=gpt_sleep_step
        local_time=time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(time.time()))

        proc_result=json.loads(subprocess.check_output(['python3','/data/postgres/chatgpt/chatgpt.py',pquery,pmodelengine,str(pmaxtokens),str(ptemperature),str(ptopprobability),str(pfrequencypenalty),str(ppresencepenalty)],universal_newlines=True,stderr=subprocess.STDOUT))
        res=proc_result['choices'][0]['message']['content']
        usage_tokens=json.dumps(proc_result['usage'])

        sleep_interval=gpt_sleep_interval-gpt_sleep_step #reset sleep counter
      except subprocess.CalledProcessError as e:
        error_text=e.output.splitlines()[-1:][0] #get the last line
      except Exception as e:
        error_text=str(e)
      finally:
        if error_text:
          if 'openai.error.RateLimitError: Rate limit reached' in error_text:
            #plpy.notice ('RateLimitError reached for query "%s", waiting %s seconds...' % (pquery, sleep_interval))
            plpy.notice ('[%s] RateLimitError reached, waiting %s seconds...' % (local_time, sleep_interval))
            time.sleep(sleep_interval)
          elif 'openai.error.Timeout' in error_text:
            #plpy.notice ('Request timed out for query "%s", waiting %s seconds...' % (pquery, sleep_interval))
            plpy.notice ('[%s] Request timed out, waiting %s seconds...' % (local_time, sleep_interval))
            time.sleep(sleep_interval)
          elif 'openai.error.APIError' in error_text:
            plpy.notice ('[%s] APIError, waiting %s seconds...' % (local_time, sleep_interval))
            time.sleep(sleep_interval)
          elif 'openai.error.ServiceUnavailableError' in error_text:
            plpy.notice ('[%s] ServiceUnavailableError, waiting %s seconds...' % (local_time, sleep_interval))
            time.sleep(sleep_interval)
          else:
            plpy.execute(chatgpt_log_query, [pquery, input_params, error_text, None])
            plpy.error (error_text)
        else:
          log_id=plpy.execute(chatgpt_log_query, [pquery, input_params, res, usage_tokens])[0]['log_id']
          return [(res, log_id)]
$BODY$
LANGUAGE 'plpython3u' SECURITY DEFINER COST 1000;