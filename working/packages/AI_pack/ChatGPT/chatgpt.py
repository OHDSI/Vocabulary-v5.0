import sys, openai

openai.api_key = 'XYZ'

completion = openai.ChatCompletion.create(
    messages = [{'role':'user','content':sys.argv[1]}],
    model=sys.argv[2],
    max_tokens=int(sys.argv[3]),
    temperature=float(sys.argv[4]),
    top_p=float(sys.argv[5]),
    frequency_penalty=float(sys.argv[6]),
    presence_penalty=float(sys.argv[7])
)

print (completion['choices'][0]['message']['content'])