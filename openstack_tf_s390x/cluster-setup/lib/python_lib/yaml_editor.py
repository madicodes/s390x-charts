#!/usr/bin/python3
# -*- coding: utf-8 -*-
import sys

import yaml
import argparse
import logging
import os

FORMAT = '[%(levelname)s-%(asctime)-15s]-%(message)s'
logging.basicConfig(format=FORMAT, level=logging.INFO)


# Convert yaml string to python dictionary
def convert_yaml_to_dictionary(dictionary):
    return yaml.load(dictionary)


# Convert true and false to bool
def check_bool_and_return(value):
    if isinstance(value, str):
        value_lower = value.lower()
        if value_lower == 'false':
            return False
        elif value_lower == 'true':
            return True
        else:
            return value
    else:
        return value


# Recursive search to get to the last element in keys list and add or modify it
def modify_add_value(yaml_dictionary, keys, value, add=False):
    current_dictionary = yaml_dictionary

    # Explore the dictionary using the key in the keys list
    length = len(keys)
    for i in range(length - 1):
        logging.debug(keys[i])
        # Check if the next key is | meaning that is a string
        if keys[i + 1] == '|':
            logging.debug("Converting yaml string to dictionary")
            logging.debug(current_dictionary[keys[i]])
            new_dic = convert_yaml_to_dictionary(current_dictionary[keys[i]])
            yaml_sub_dictionary = modify_add_value(new_dic, keys[i + 2:], value)
            value = yaml.dump(yaml_sub_dictionary, default_flow_style=False)
            keys = keys[:i + 1]
            logging.debug(keys)
            break
        else:
            current_dictionary = current_dictionary[keys[i]]

    # Depending of the method, check if the targeted key exist (modify) or not (add)
    if add and (keys[-1] in current_dictionary.keys()):
        logging.warning("Key to be added already exist %s" % (keys[-1]))
    elif (not add) and (keys[-1] not in current_dictionary.keys()):
        logging.warning("Key to be modified doesn't exist %s " % (keys[-1]))

    # Check if the value to add is a yaml file
    if os.path.isfile(value):
        logging.debug(os.path.isfile(value))
        with open(value, "rb") as yam_file_to_add:
            value = convert_yaml_to_dictionary(yam_file_to_add)

    # Change the last value and return the new dictionary
    current_dictionary[keys[-1]] = check_bool_and_return(value)
    return yaml_dictionary


# Recursive search to get to the last element in keys list and remove it
def remove_key(yaml_dictionary, keys):
    current_dictionary = yaml_dictionary
    length = len(keys)
    for i in range(length - 1):
        if keys[i + 1] == '|':
            logging.debug("Converting yaml string to dictionary")
            logging.debug(current_dictionary[keys[i]])
            new_dic = convert_yaml_to_dictionary(current_dictionary[keys[i]])
            yaml_sub_dictionary = remove_key(new_dic, keys[i + 2:])
            value = yaml.dump(yaml_sub_dictionary, default_flow_style=False)
            keys = keys[:i + 1]
            current_dictionary[keys[-1]] = value
            return yaml_dictionary
        else:
            current_dictionary = current_dictionary[keys[i]]
    try:
        del current_dictionary[keys[-1]]
    except KeyError:
        logging.warning("Key %s does not exist so it can not be remove" % (keys[-1]))
    return yaml_dictionary


# Generate list from input keys
def generate_key_list(keys):
    new_list = []
    for key in keys.split(" "):
        if key.isdigit():
            new_list.append(int(key))
        else:
            new_list.append(str(key))
    return new_list


# Argument parser
def argument_parser():
    parser = argparse.ArgumentParser(
        description='Edit a yaml and modify or delete the value inside. \n There is three methods: \n - add : add a new key to yaml file \n - modify : change an existing value by selecting his key \n - remove : remove a key from the repo \n\n To change the correct element, you need to specify the path to this element. To do so, give the keys to access the element in a string seperated by space.\n Exemple : \"topkey middlekey keywewanttochange\"')
    parser.add_argument('-f', '--file', dest='yaml_file', required=True, help="Path to the yaml file to edit")
    parser.add_argument('-m', '--method', required=True, choices=['add', 'remove', 'modify'])
    parser.add_argument('-k', '--keys', required=True,
                        help='Give the path to the element you want to edit. The path has to be described with space as : "key1 key2 key3". You can also use the character "|" to specify a sub yaml dictionnary store in a string value')
    parser.add_argument('-v', '--value', help='Value to add or modify')
    arguments = parser.parse_args()
    # Check that value is set if add or modify method is selected
    if (arguments.method == 'add' or arguments.method == 'modify') and (arguments.value is None):
        logging.debug(arguments.method)
        parser.error("Value is required for the method add and modify")
    return arguments


if __name__ == "__main__":

    if sys.version_info[0] < 3:
        raise Exception("Python 3 or a more recent version is required.")
    # Get the arguments
    args = argument_parser()
    # Read the yaml file and convert it to a python dictionary
    with open(args.yaml_file, "rb") as yaml_file:
        yaml_file_dictionary = convert_yaml_to_dictionary(yaml_file)

    # Generate the path list
    key_list = generate_key_list(args.keys)

    # Execute the correct action depending of the method call
    if args.method == "modify":
        yaml_file_dictionary = modify_add_value(yaml_file_dictionary, key_list, args.value)
    elif args.method == "add":
        yaml_file_dictionary = modify_add_value(yaml_file_dictionary, key_list, args.value, add=True)
    elif args.method == "remove":
        yaml_file_dictionary = remove_key(yaml_file_dictionary, key_list)
    else:
        print ("Wrong method")

    # Update the yaml file
    logging.debug(yaml_file_dictionary)
    with open(args.yaml_file, "w+") as yaml_file:
        yaml.dump(yaml_file_dictionary, yaml_file, default_flow_style=False)
