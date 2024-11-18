import sys, re

if len(sys.argv) != 3:
    print("Usage: python parser_continuous_lines_to_paragraph_transcripts.py <path_index_input_file> <path_output_folder>")
    print("path_index_input_file: path to the input file at word level with Named Entities with continuous notation.")
    print("path_output_file: path to the output file in which to print the paragraph transcripts")

path_index_input_file = sys.argv[1]
index_input_file = open(path_index_input_file, 'r')

path_output_file = sys.argv[2]
output_file = open(path_output_file, 'w')

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

    #REMOVE TAGS
    text_line = re.sub(r"<[^>]*>", "", text_line)

    text_line_split = text_line.strip().split()
    line_str = ""

    for w in text_line_split:
        line_str += w + " "


    #Retrieve dict with line transcriptions from doc
    dict_lines = dict_docs_to_lines.get(id_doc, dict())
    #Place transcription in the dict
    dict_lines[line_number] = line_str
    #Update document dict
    dict_docs_to_lines[id_doc] = dict_lines

#After all the database has been processed, write to file
for (doc_id, dict_lines) in sorted(dict_docs_to_lines.items()):
    output_file.write(doc_id + " ")
    for (_, output_str) in sorted(dict_lines.items()):
        output_file.write(output_str)
    output_file.write("\n")