import sys

if len(sys.argv) != 3:
    print("Usage: python parser_parenthesized_to_bio.py <path_input_file> <path_output_folder>")
    print("path_input_file: path to the input file with Named Entities in parenthesized notation")
    print("path_output_folder: path to the output folder in which to write a file for each line sample in the input file")

path_input_file = sys.argv[1]
input_file = open(path_input_file, "r", encoding="utf-8")

path_output_folder = sys.argv[2]

#Read line-by-line the input file
for line in input_file.readlines():

    line = line.strip()

    try:
        (id_line, text_line) = line.split(maxsplit=1)
    except ValueError:
        #print(curr_hyp)
        id_line = line
        text_line = ""

    #Open output file
    output_file = open(path_output_folder + "/" + id_line + ".bio", "w")

    #Add extra spaces to ensure correct split
    text_line = text_line.replace("<", " <")
    text_line = text_line.replace(">", "> ")
    text_line_split = text_line.split()

    stack_opened_ne = list()
    number_new_nes = 0

    # print(id_line, text_line)
    # print(text_line_split)

    for w in text_line_split:
        #Closing NE
        if "</" in w:
            matching_ne = w[2:-1]
            
            #Skip closing symbols not in stack
            if matching_ne not in stack_opened_ne:
                continue

            #Skip closing symbols in wrong order
            if stack_opened_ne[-1] != matching_ne:
                continue
            else:
                stack_opened_ne.pop()
                if number_new_nes > 0:
                    number_new_nes -= 1
            

        #Start of NE
        elif "<" in w:
            #Skip opened NEs which were already open
            if w != "<persName/>" and w[1:-1] not in stack_opened_ne:
                #Include at the top of the stack
                stack_opened_ne.append(w[1:-1])
                number_new_nes += 1

        #Any other word / symbol
        else:
            if len(stack_opened_ne) > 0:
                reversed_stack = list(reversed(stack_opened_ne))
                tags = " ".join(["B-" + category for category in reversed_stack[:number_new_nes]])
                if number_new_nes < len(stack_opened_ne):
                    tags += " " + " ".join(["I-" + category for category in reversed_stack[number_new_nes:]])
            else:
                tags = "O"
            
            number_new_nes = 0
            output_file.write("{} {}\n".format(w, tags))
            
    

    if len(text_line) == 0:
        output_file.write(". O\n")

    output_file.close()