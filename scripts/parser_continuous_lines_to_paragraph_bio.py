import sys, re

#This parser works with nested entities in continuous notation assuming that for:
# Washington@placeName@persName or Washington<placeName><persName>
# The word Washington would be a place inside the name of a person, represented as:
# <persName> ... <placeName> Washington </placeName> </persName> in XML notation

if len(sys.argv) != 3:
    print("Usage: python parser_continuous_lines_to_paragraph_bio.py <path_index_input_file> <path_output_folder>")
    print("path_index_input_file: path to the input file at word level with Named Entities with continuous notation.")
    print("path_output_folder: path to the output folder in which to store one output file per line.")

path_index_input_file = sys.argv[1]
index_input_file = open(path_index_input_file, 'r')

path_output_folder = sys.argv[2]

dict_docs_to_lines = dict()

for line in index_input_file.readlines():

    try:
        (id_line, text_line) = line.strip().split(maxsplit=1)
    except ValueError:
        #print(curr_hyp)
        id_line = line
        text_line = ""

    #Doc id is all the filename except line number
    if "." not in id_line:
        id_doc = "-".join(id_line.strip().split("-")[:-1])
        line_number = id_line.strip().split("-")[-1]
    else:
        id_doc = ".".join(id_line.strip().split(".")[:-1])
        line_number = id_line.strip().split(".")[-1]

    # output_file = open(path_output_folder + id_line + ".bio", "w")

    #Add spacing to punctuation marks
    text_line = text_line.replace(",", " ,")
    text_line = text_line.replace(".", ".")
    text_line = text_line.replace(";", " ;")
    text_line = text_line.replace(":", " :")

    #Remove spaces between tags and words (for GT)
    text_line = text_line.replace("@C", "@C ")
    text_line = text_line.replace("@G", "@G ")
    text_line = text_line.replace("@L", "@L ")
    text_line = text_line.replace("@N", "@N ")
    text_line = text_line.replace("@P", "@P ")
    text_line = text_line.replace("@T", "@T ")
    text_line = text_line.replace(" @", "@")

    text_line = text_line.replace("<C>", "<C> ")
    text_line = text_line.replace("<G>", "<G> ")
    text_line = text_line.replace("<L>", "<L> ")
    text_line = text_line.replace("<N>", "<N> ")
    text_line = text_line.replace("<P>", "<P> ")
    text_line = text_line.replace("<T>", "<T> ")
    text_line = text_line.replace(" <", "<")

    text_line_split = text_line.strip().split()
    stack_opened_ne = list()
    line_str = ""

    # if id_line == "a04-096-01":
    #     print(text_line)
    #     print(text_line_split)

    for w in text_line_split:
        output_str = ""
        if "@" not in w and "<" not in w: #This word has no tag
            output_str = w + " O" + "\n"
            line_str += output_str

            #Remove all the NEs from the stack
            stack_opened_ne = list()

        elif "@" in w: #This word has at least one tag (@)
            tags = w.split("@")[1:]
            tags.reverse()

            # Fix to work without nested NEs
            tags = [tags[-1]]

            w = w.split("@")[0]

            #Remove tags without words
            if len(w) == 0:
                continue

            if len(tags) > len(stack_opened_ne): #We are opening a new NE (tags[0])
                output_str = w + " B-" + "I-".join(tags) + "\n"
            elif tags == stack_opened_ne: #We keep the same category as before
                output_str = w + " I-" + "I-".join(tags) + "\n"
            elif len(tags) == len(stack_opened_ne) and tags != stack_opened_ne:
                output_str = w + " B-" + "I-".join(tags) + "\n"
            else: #We are closing a NE
                output_str = w + " I-" + "I-".join(tags) + "\n"

            stack_opened_ne = tags
            line_str += output_str
        elif "<" in w: #This word has at least one tag (<>)
            w = w.replace(">", "")
            tags = w.split("<")[1:]
            tags.reverse()

            # Fix to work without nested NEs
            tags = [tags[-1]]

            w = w.split("<")[0]

            #Remove tags without words
            if len(w) == 0:
                continue

            if len(tags) > len(stack_opened_ne): #We are opening a new NE (tags[0])
                output_str = w + " B-" + "I-".join(tags) + "\n"
            elif tags == stack_opened_ne: #We keep the same category as before
                output_str = w + " I-" + "I-".join(tags) + "\n"
            elif len(tags) == len(stack_opened_ne) and tags != stack_opened_ne:
                output_str = w + " B-" + "I-".join(tags) + "\n"
            else: #We are closing a NE
                output_str = w + " I-" + "I-".join(tags) + "\n"

            stack_opened_ne = tags
            line_str += output_str

        # if id_line == "a04-096-01":
        #     print(output_str)

    #Retrieve dict with line transcriptions from doc
    dict_lines = dict_docs_to_lines.get(id_doc, dict())
    #Place BIO formatted transcription in the dict
    dict_lines[line_number] = line_str
    #Update document dict
    dict_docs_to_lines[id_doc] = dict_lines

#After all the database has been processed, write to file
for (doc_id, dict_lines) in dict_docs_to_lines.items():
    output_file = open(path_output_folder + "/" + doc_id + ".bio", "w")
    for (_, output_str) in dict_lines.items():
        output_file.write(output_str)