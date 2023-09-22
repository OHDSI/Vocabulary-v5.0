CREATE OR REPLACE FUNCTION ai_pack.ChatGPT (
	pQuery TEXT,
	pModelEngine TEXT DEFAULT 'gpt-3.5-turbo',
	pMaxTokens INT4 DEFAULT 1024,
	pTemperature NUMERIC DEFAULT 0.5,
	pTopProbability NUMERIC DEFAULT 1,
	pFrequencyPenalty NUMERIC DEFAULT 0,
	pPresencePenalty NUMERIC DEFAULT 0
)
RETURNS TEXT AS
$BODY$
  '''
	--https://platform.openai.com/docs/api-reference/chat/create
	engine: ID of the model to use (gpt-3.5-turbo, gpt-3.5-turbo-16k etc). More: https://platform.openai.com/docs/models/gpt-3-5
	max_tokens: Set a limit on the number of tokens per model response. The API supports a maximum of 4096 tokens shared between the prompt (including system message, examples, message history, and user query) and the model's response. One token is roughly four characters for typical English text.
	temperature: What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic. Try adjusting temperature or top_p but not both.
	top_p: Similar to temperature, this controls randomness but uses a different method. Lowering top_p narrows the model's token selection to likelier tokens. Increasing top_p lets the model choose from tokens with both high and low likelihood. Try adjusting temperature or top_p but not both.
	frequency_penalty: Number between -2.0 and 2.0. Positive values penalize new tokens based on their existing frequency in the text so far, decreasing the model's likelihood to repeat the same line verbatim
	presence_penalty: Number between -2.0 and 2.0. Positive values penalize new tokens based on whether they appear in the text so far, increasing the model's likelihood to talk about new topics
  '''
  import subprocess, json, time, re
  
  gpt_sleep_interval=5
  
  input_params=json.dumps({
    'pModelEngine': "%s" % pmodelengine,
    'pMaxTokens': "%s" % pmaxtokens,
    'pTemperature': "%s" % ptemperature,
    'pTopProbability': "%s" % ptopprobability,
    'pFrequencyPenalty': "%s" % pfrequencypenalty,
    'pPresencePenalty': "%s" % ppresencepenalty
  })
  plan = plpy.prepare("INSERT INTO ai_pack.chatgpt_log VALUES (DEFAULT, $1, $2, CLOCK_TIMESTAMP(), SESSION_USER, $3)", ["text", "jsonb", "text"])
  
  while True:
      try:
        res=subprocess.check_output(['python3','/data/postgres/chatgpt/chatgpt.py',pquery,pmodelengine,str(pmaxtokens),str(ptemperature),str(ptopprobability),str(pfrequencypenalty),str(ppresencepenalty)],universal_newlines=True,stderr=subprocess.STDOUT)
        plpy.execute(plan, [pquery, input_params, res])
        return res
      except subprocess.CalledProcessError as e:
        plpy.execute(plan, [pquery, input_params, e.output])
        error_text=e.output
        if 'raise self.handle_error_response(' in error_text:
          error_text=re.search(r'.*raise self\.handle_error_response\((?:\r\n|\r|\n)(.+)', error_text).group(1)
          if 'openai.error.RateLimitError' in error_text:
            plpy.notice ('RateLimitError reached for query "%s", waiting %s seconds...' % (pquery, gpt_sleep_interval))
            time.sleep(gpt_sleep_interval)
          else:
            plpy.error (error_text)
      else:
        plpy.error (error_text)
$BODY$
LANGUAGE 'plpython3u' SECURITY DEFINER;
