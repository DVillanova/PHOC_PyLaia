import sys

if len(sys.argv) != 3:
    print("Usage: python parser_parenthesized_to_continuous.py <path_index_input_file> <path_index_output_file>")
    print("path_index_input_file: path to the input file at word level with Named Entities with continuous notation")
    print("path_index_output_file: path to the output file which will employ parenthesized notation for the Named Entiites")

path_index_input_file = sys.argv[1]
index_input_file = open(path_index_input_file, 'r')

path_index_output_file = sys.argv[2]
index_output_file = open(path_index_output_file, 'w')

for line in index_input_file.readlines():

    try:
        (id_line, text_line) = line.split(maxsplit=1)
    except ValueError:
        #print(curr_hyp)
        id_line = line
        text_line = ""

    #Add spacing to punctuation marks
    text_line = text_line.replace(",", " ,")
    text_line = text_line.replace(".", " .")
    text_line = text_line.replace(";", " ;")
    text_line = text_line.replace(":", " :")

    text_line_split = text_line.split()
    stack_opened_ne = list()
    transformed_text_line = ""

    for w in text_line_split:
        #Separate word@tag2@tag1 into [word, tag2, tag1]
        w_split_reversed = w.split("@")
        #Reverse into [tag1, tag2, word]
        w_split_reversed.reverse()

        tags = w_split_reversed[:-1]
        transformed_w = ""
        
        str_opened_tags = ""
        str_closed_tags = ""

        for index, tag in enumerate(tags, start=1):
            #Tags opening
            if index > len(stack_opened_ne):
                opened_tag = "<" + tag + "> "
                str_opened_tags = str_opened_tags + opened_tag
                stack_opened_ne.append(tag)

            #Does not match tag with corresponding tag in Stack
            elif tag != stack_opened_ne[index-1]:
                #Tags closure up to stack length = index - 1
                while index <= len(stack_opened_ne):
                    closed_tag = "</" + stack_opened_ne.pop() + "> "
                    str_closed_tags = str_closed_tags + closed_tag
                
                #New Tag Opening
                opened_tag = "<" + tag + "> "
                str_opened_tags = str_opened_tags + opened_tag
                stack_opened_ne.append(tag)
            
            #In another case tags are equal:
            #(index <= len(stack_opened_ne) and tag == stack_opened_ne[index-1])
        
        #Tags have been left to close
        while len(tags) < len(stack_opened_ne):
            closed_tag = "</" + stack_opened_ne.pop() + "> "
            str_closed_tags = str_closed_tags + closed_tag

        transformed_w = str_closed_tags + str_opened_tags + w_split_reversed[-1] + " "
        transformed_text_line = transformed_text_line + transformed_w

    transformed_text_line = transformed_text_line.replace(" .", ".")
    transformed_text_line = transformed_text_line.replace(" ,", ",")
    transformed_text_line = transformed_text_line.replace(" ;", ";")
    transformed_text_line = transformed_text_line.replace(" :", ":")

    if transformed_text_line == "":
        transformed_text_line = " "

    output_line = id_line + " " + transformed_text_line
    index_output_file.write(output_line + "\n")