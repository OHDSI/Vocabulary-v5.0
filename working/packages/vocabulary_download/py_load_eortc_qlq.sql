CREATE OR REPLACE FUNCTION vocabulary_download.py_load_eortc_qlq(p_json_folder text)
 RETURNS void
 LANGUAGE plpython3u
AS $BODY$
import json
import os
from bs4 import BeautifulSoup

# Path to the folder with JSON files
json_folder = p_json_folder
files = os.listdir(json_folder)

insert_questionnaire_query = plpy.prepare("""
    INSERT INTO sources.eortc_questionnaires
    (id, createDate, updateDate, name, code, type, state, phase, gender, chemical, description, additionalInfo, contact, isCustom, authorId, author, questionsStartPosition)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
""", ["integer", "timestamp", "timestamp", "text", "text", "text", "text", "integer", "text", "text", "text", "text", "text", "boolean", "integer", "text", "integer"])

insert_question_query = plpy.prepare("""
    INSERT INTO sources.eortc_questions (id, createDate, updateDate, itemId, position, wording, comment, relatedQuestions, questionnaire_id)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id
""", ["integer", "timestamp", "timestamp", "integer", "integer", "text", "text", "integer[]", "integer"])

insert_item_query = plpy.prepare("""
    INSERT INTO sources.eortc_question_items (code, codePrefix, type, description, direction, underlyingIssue, additionalInfo, conceptDefinition, createDate, updateDate, question_id)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING id
""", ["text", "text", "text", "text", "text", "text", "text", "text", "timestamp", "timestamp", "integer"])

insert_wording_query = plpy.prepare("""
    INSERT INTO sources.eortc_recommended_wordings (item, language, wording, createDate, updateDate) 
    VALUES ($1, $2, $3, $4, $5)
""", ["integer", "text", "text", "timestamp", "timestamp"])

check_language_query = plpy.prepare("""
    SELECT 1 FROM sources.eortc_languages WHERE code = $1
""", ["text"])

insert_languages_query = plpy.prepare("""
    INSERT INTO sources.eortc_languages (code, name) 
    VALUES ($1, $2)
""", ["text", "text"])

for filename in files:
    if filename.endswith('.json'):
        with open(os.path.join(json_folder, filename), 'r', encoding='UTF-8') as f:
            data = json.load(f)

            questionnaire_id = data['id']

            soup = BeautifulSoup(data['description'], 'html.parser')
            description = None if data['description'] == '' or soup.h3 is None else soup.h3.text
            plpy.notice(data['id'])
            
            # Inserting questionnaire data
            plpy.execute(insert_questionnaire_query, [
                data['id'], data['createDate'], data['updateDate'], data['name'], data['code'], 
                data['type'], data['state'], data['phase'], data['gender'], data['chemical'],
                description, data['additionalInfo'], data['contact'], data['isCustom'], 
                data['authorId'], data['author']['name'] if data['author'] else None, data['questionsStartPosition']
            ])
            
            if 'languages' in data:
                for lang in data['languages']:
                    is_exists = plpy.execute(check_language_query, [lang['code']])
                    if not is_exists:
                        plpy.execute(insert_languages_query, [
                            lang['code'], lang['name']
                        ])

            # Processing and inserting questions and question items
            for item in data['questionnaireItems']:
                if 'relatedQuestions' in item:
                    related_questions = item['relatedQuestions']
                else:
                    related_questions = None

                question_id = plpy.execute(insert_question_query, [
                    item['id'], item['createDate'], item['updateDate'], item['itemId'], item['position'], 
                    item['wording'], item['comment'], 
                    related_questions, questionnaire_id
                ])[0]['id']

                item_id = plpy.execute(insert_item_query, [
                    item['item']['code'], item['item']['codePrefix'], item['item']['type'], item['item']['description'],
                    item['item']['direction'], item['item']['underlyingIssue'], item['item']['additionalInfo'],
                    item['item']['conceptDefinition'], item['item']['createDate'], item['item']['updateDate'], question_id
                ])[0]['id']

                for wording in item['item']['recommendedWordings']:
                    plpy.execute(insert_wording_query, [
                        item_id, wording['language'], wording['wording'], wording['createDate'], wording['updateDate']
                    ])
$BODY$;