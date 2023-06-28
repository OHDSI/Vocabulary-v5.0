import os
import json


def get_directory_structure(startpath):
    if not os.path.exists(startpath):
        raise ValueError(f"Invalid path: {startpath}")

    directory_tree = {}

    for root, dirs, files in os.walk(startpath):
        subtree = directory_tree
        subdirs = root.replace(startpath, '').strip(os.sep).split(os.sep)

        for subdir in subdirs:
            subtree = subtree.setdefault(subdir, {})
        
        if files:
            subtree["_files"] = files

    return directory_tree


def save_as_json(data, output_file):
    with open(output_file, 'w') as file:
        json.dump(data, file, indent=4)


# Specify the path of the directory you want to print
directory_path = './'

# Specify the output file
output_file = './directory_structure.json'

# Generate the directory structure
directory_structure = get_directory_structure(directory_path)

# Save directory structure to a JSON file
save_as_json(directory_structure, output_file)
