-- DROP FUNCTION vocabulary_download.py_get_eortc_qlq(text, text);

CREATE OR REPLACE FUNCTION vocabulary_download.py_get_eortc_qlq(p_auth_token text, p_save_folder text)
 RETURNS void
 LANGUAGE plpython3u
AS $BODY$
import requests
import time
import os
from bs4 import BeautifulSoup

html_file = os.path.join(p_save_folder, 'itemlibrary.eortc.org.html')
with open(html_file, 'r', encoding='utf-8') as file:
    content = file.read()

soup = BeautifulSoup(content, 'html.parser')

# Extracting questionnaire IDs
links = soup.find_all('a', {'class': 'questionnaireListItem_link__5einU d-flex'})
questionnaire_ids = [link['href'].split('=')[1] for link in links if link.get('href')]

# Setting headers for HTTP request
headers = {
    "Accept": "application/json, text/plain, */*",
    "Accept-Encoding": "gzip, deflate, br, zstd",
    "Accept-Language": "en-US,en;q=0.9,ru;q=0.8",
    "Authorization": f"Bearer {p_auth_token}",
    "Connection": "keep-alive",
    "Host": "itemlibrary-api.eortc.org",
    "Origin": "https://itemlibrary.eortc.org",
    "Referer": "https://itemlibrary.eortc.org/questionnaires/?id=",
    "Sec-Fetch-Dest": "empty",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Site": "same-site",
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36",
    "sec-ch-ua": "\"Chromium\";v=\"96\", \"Google Chrome\";v=\"96\", \"Not-A.Brand\";v=\"99\"",
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": "\"Linux\""
}

#questionnaire_ids = ["11"]

# Delete all existing JSON files in the directory
for file_name in os.listdir(p_save_folder):
    if file_name.endswith('.json'):
        os.remove(os.path.join(p_save_folder, file_name))

# Make requests to the API and save the responses
for id in questionnaire_ids:
    url = f"https://itemlibrary-api.eortc.org/api/questionnaires/{id}/details/en"
    headers["Referer"] += id
    response = requests.get(url, headers=headers)

    # Save the answer to a .gz file
    file_path = os.path.join(p_save_folder, f'response_{id}.json')
    with open(file_path, 'wb') as f:
        f.write(response.content)

    time.sleep(2)

$BODY$;
