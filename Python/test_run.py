# Test_Run.py - This application parses a set of data files and orders them according to the
# "precedent" key, located in the node_objects module. It is really just a demonstration of
# the MergeSort algorithm, use of classes, file IO and hex->utf8 decode.
# Christopher Phyffer

import os, json, re
import utilities
from node_objects import Word, Sentence, Paragraph

TARGET_DATA_PATH = '.\data'

# Used to determine whether the json data structure is valid, has all of our required keys.
REQUIRED_FIELDS = ['parent_id', 'id', 'precedent', 'type']

# Gather a list of data directories in the TARGET_DATA_PATH
AVAILABLE_DIRECTORIES = []
for f in os.listdir(TARGET_DATA_PATH):
    if os.path.isdir(os.path.join(TARGET_DATA_PATH, f)):
        AVAILABLE_DIRECTORIES.append(f)

# Have the User select a directory from the TARGET_DATA_PATH to parse the data within
for dir_index, data_dir in enumerate(AVAILABLE_DIRECTORIES):
    print("{1} : {0}".format(data_dir, dir_index+1))

target_dir_num = int(input("Please select the data directory #: "))
if not 1 <= target_dir_num < len(AVAILABLE_DIRECTORIES)+1:
    print("Specified Choice (#{}) is not valid".format(target_dir_num))
    exit()

# Specify our target directory.
data_set_name = str(input("What should the output file name be called? (Non Alphanumeric and _ will be stripped.) "))
data_set_name = re.sub('[^a-zA-Z0-9_]', '', data_set_name)
if not data_set_name:
    print("Specify a target filename and/or directory")
    exit()

# Specify the path that our file should be stored.
path_name = str(input("Where should I write this output? (Default is the current directory) : "))
path_name = '.' if path_name == None or path_name == '' else path_name
try:
    if not os.path.isdir(path_name):
        os.mkdir(path_name)
except OSError:
    print ("Creation of the directory {} failed".format(path_name))
    exit()
else:
    print ("Successfully created the directory {}".format(path_name))

# Construct our target directory path
TARGET_DATASET_FOLDER = os.path.join(TARGET_DATA_PATH, AVAILABLE_DIRECTORIES[target_dir_num-1])
print("Looking into data path: `{}`".format(TARGET_DATASET_FOLDER))

# Prepare our data arrays.
sentences = []
words = []

# Gather data files from the specified data directory, make sure they are valid
for root, dirs, files in os.walk(TARGET_DATASET_FOLDER, topdown=True, onerror=None, followlinks=False):
    for name in files:
        file_path = os.path.join( TARGET_DATASET_FOLDER, name)

        with open(os.path.join( TARGET_DATASET_FOLDER, name), 'r') as json_output:
            try:
                data = json.load(json_output)
            except:
                raise ValueError("{} is not a valid json data format.".format(file_path))

            if not utilities.is_valid_json(data, REQUIRED_FIELDS):
                raise ValueError("{} is not a valid json data structure.".format(file_path))
                break

            if data['type'] == 'word':
                words.append(Word(data['parent_id'], data['id'], data['payload'], data['precedent']))
            elif data['type'] == 'sentence':
                sentences.append(Sentence(data['id'], data['precedent']))

# Add corresponding words to the sentences
for sentence in sentences:
    for word in words:
        if word.parent_id == sentence.id:
            sentence.add_word(word)

    sentence.map_precedents_and_order()

# Develop our paragraph from the sentences
paragraph = Paragraph()
paragraph.sentences = sentences
paragraph.map_precedents_and_order()

# Formulate our paragraph. Ensure that the sentences and words are ordered correctly.
print("Resulting Output: *{}*".format(paragraph.formulate_from_sentences()))

# Output our resulting payload to the output file
data_set_name += ".output"
complete_output_path = os.path.join(path_name, data_set_name)
f = open(complete_output_path, "w")
f.write(str(paragraph.get_formatted_payload()))
f.close()

print("Payload written to {}".format(complete_output_path))
