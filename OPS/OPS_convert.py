# -*- coding: utf-8 -*-
"""
This script is used to parse OPS claml format xml files to create
csv files for import as sources into the dev vocab server
 run by executing the "run" command with two arguments:
    e.g. - run OPS_convert ops2020.xml "ops2020.csv"
 this will consume and parse a file called ops2020.xml and will create two
 result csv files 
   - a file ops2020.csv with all OPS codes, their superclasses and "modifiedBy" entries
   - a file mod_ops2020.csv containing all modifiers 

 This script uses the python-claml project: https://pypi.org/project/python-claml/
 (you need to install it by pip: pip install python-claml)
"""
import sys
import time

from python_claml import claml
from python_claml.claml_types import ClaML

label_str = ''
modByCode = ''

import_file = sys.argv[1]
export_file = sys.argv[2]
mod_export_file =  'mod_' + sys.argv[2]

# import_file = 'ops2020_tst.xml'
# export_file = 'ops2020_tst.csv'
# mod_export_file = 'mod_ops2020_tst.csv'


#print(import_file)

def to_string(nodes): # get the text node
    """
    Serialise a forest of DOM nodes to text,
    using the data fields of text nodes.
    :param nodes: the forest of DOM nodes
    :return: a concatenation of string representations.
    """
    result = []
    for node in nodes:
        if node.nodeType == node.TEXT_NODE:
            result.append(node.data)
        else:
            result.append(to_string(node.childNodes))
    return ''.join(result)



def parse_file(import_file: str) -> ClaML: # main logic section
    # global variables 
    global label_str
    label_str = ''
    global modByCode
    modByCode = ''
    """
    Parse a ClaML file and write one line per Class read
    :param import_file: the input file name
    """
    with open(import_file, 'r', encoding=("utf-8")) as input_file:
        print('Reading file contents from {} ...'.format(import_file), file=sys.stderr)
        start = time.perf_counter()
        contents = input_file.read()
        mid = time.perf_counter()
        print('Parsing ClaML document ...', file=sys.stderr)
        classification = claml.CreateFromDocument(contents)
        classification: ClaML = claml.CreateFromDocument(contents)
        end = time.perf_counter()
        print('Took {:f}s, reading: {:f}s, parsing: {:f}s\n'.format(
            end - start,
            mid - start,
            end - mid
        ), file=sys.stderr)
        
        start = time.perf_counter()
        print('Writing export document {} ...'.format(export_file), file=sys.stderr)
        f = open(export_file, "w", encoding=("utf-8")) #open codes-file in overwrite mode
        print('{}|{}|{}|{}'.format(
           'Code',
           'Label DE',
           'SuperClass',
           'ModifiedBy'
        ), file=f) 
        f.close()
        
        f = open(export_file, "a", encoding=("utf-8")) #open in append mode

        """
        get all the codes
        """
        for cls in classification.Class:
            for superClass in cls.SuperClass:
                 for rubric in cls.Rubric:
                    if rubric.kind == 'preferred' and cls.kind == 'category':
                        label_str = ''
                        for label in rubric.Label:
                            nodes = label.toDOM().childNodes
                            label_str = to_string(nodes)
                 # clear string in case this class has no modifier
                 modByCode = '' 
                 for modBy in cls.ModifiedBy:
                     modByCode = str(modBy.code)

                 print('{}|{}|{}|{}'.format(
                        cls.code,
                        label_str,
                        superClass.code,
                        modByCode
                        ), file=f)

        f.close()

        f = open(mod_export_file, "w", encoding=("utf-8")) #open mod-file in overwrite mode
        print('{}|{}|{}|{}'.format(
           'modifier',
           'Code',
           'Label DE',
           'SuperClass'
        ), file=f) 
        f.close()
        print('Writing modifier export document {} ...'.format(mod_export_file), file=sys.stderr)
        f = open(mod_export_file, "a", encoding=("utf-8")) #open in append mode

        """
        get all the modifiers
        """
        for cls in classification.ModifierClass:
                for rubric in cls.Rubric:
                    if rubric.kind == 'preferred':# and cls.kind == 'category':

                        for label in rubric.Label:
                            nodes = label.toDOM().childNodes
                            label_str = to_string(nodes)

                            print('{}|{}|{}|{}'.format(
                                cls.modifier,
                                cls.code,
                                label_str,
                                cls.SuperClass.code #SuperClass is not iterated here
                            ), file=f)

        f.close()


        end = time.perf_counter()
        print('Took {:f}s \n'.format(
            end - start
        ), file=sys.stderr)
        
        return classification


if __name__ == '__main__':
    # if len(sys.argv) < 2:
    #     print('Usage: {} <input.xml> <output.csv> '.format(sys.argv[0]), file=sys.stderr)
    #     sys.exit()
    #result = parse_file(sys.argv[1])
    result = parse_file(import_file)

# global scope

base_text = ''

# sys.exit()