import os
import sys

if len(sys.argv) != 4:
    print("Usage: python generate_tagged_line_transcription.py <path_to_tagged_gt> <path_to_line_gt> <path_output_file>")
    print("<path_to_tagged_gt>: Path where the whole tagged GT is located")
    print("<path_to_line_gt>: Path where the transcription at line level is located")
    print("<path_output_file>: Path on where to store the output")
    sys.exit(1)

path_tagged_gt = sys.argv[1]
path_line_gt = sys.argv[2]
path_output_file = sys.argv[3]

file_tagged_gt = open(path_tagged_gt, 'r')
file_line_gt = open(path_line_gt, 'r')
file_output = open(path_output_file, 'w')

tagged_words = [[l.split()[0][:3], l.split()[-2], l.split()[-1]] if len(l) > 2 else [] for l in file_tagged_gt.readlines()]

dict_tagged_page_transc= dict()
for t in tagged_words:
    if len(t) > 0:
        list_transc = dict_tagged_page_transc.get(t[0], list())
        list_transc.append([t[1],t[2]])
        dict_tagged_page_transc[t[0]] = list_transc

#print(tagged_page_transc_dict["270"])
#print(len(tagged_page_transc_dict["270"]))

lines_gt = file_line_gt.readlines()
dict_line_transc = dict() #Transcription without tags for each line
dict_page_to_lines = dict() #Map from page id to line ids in page
counter_words_page = dict() 

for l in lines_gt:
    (l_id, l_transc) = l.split(" ", maxsplit=1)
    
    if "XX" in l_id:
        continue
    
    page_id = l_id[:3]
    l_word_transc = []
    page_to_lines_list = dict_page_to_lines.get(page_id, list())
    page_to_lines_list.append(l_id)
    dict_page_to_lines[page_id] = page_to_lines_list
    for w in l_transc.strip().split("|"):
        w = w.replace("-", "") #Eliminate space between characters

        w = w.casefold() #Convert to lowercase

        #Special chars
        w = w.replace("s_pt", ".") #Points
        w = w.replace("s_mi", "-") #Dash at end of line
        w = w.replace("s_cm", ",") #Commas
        w = w.replace("s_sq", ";")
        w = w.replace("s_qo", ":")
        w = w.replace("s_et", "V")
        w = w.replace("s_qt", "'")
        w = w.replace("s_", "") #Symbols before numbers s_8 -> 8
        
        
        l_word_transc.append(w)
    
    dict_line_transc[l_id] = l_word_transc
    counter_words_page[page_id] = counter_words_page.get(page_id, 0) + len(l_word_transc)
    #print(dict_line_transc[l_id])

dict_tagged_line_transc = dict()

for page_id in dict_page_to_lines.keys():
    tagged_page_transc = dict_tagged_page_transc[page_id]
    index_tagged_page_transc = 0
    for l_id in dict_page_to_lines[page_id]:
        dict_tagged_line_transc[l_id] = list()
        line_transc = dict_line_transc[l_id]
        
        for index_line_transc in range(0,len(line_transc)):
            word_transc = line_transc[index_line_transc]
            [tagged_word, tag] = tagged_page_transc[index_tagged_page_transc]
            final_list_words = dict_tagged_line_transc[l_id]

            if tagged_word.casefold() in word_transc.replace("'","").replace("-","").casefold(): #Match between tagged word and orig. transcription
                final_list_words.append([word_transc, tag])
                index_tagged_page_transc += 1
            else:
                final_list_words.append([word_transc, "O"])
            
            dict_tagged_line_transc[l_id] = final_list_words

for l_id in dict_tagged_line_transc.keys():
    out_str = l_id
    prev_tag = "O"
    for [word, tag] in dict_tagged_line_transc[l_id]:
        
        #Version for parenthesized tagging
        if prev_tag != "O" and prev_tag != tag: #Closing of tag
           out_str += " " + "</" + prev_tag + ">"
        if tag != "O" and prev_tag != tag: #Opening of tags
           out_str += " " + "<" + tag + ">"
        out_str += " " + word
        prev_tag = tag

        #Version for normal continuous tagging
        #out_str += " " + word + " @" + tag
        
        #Version for continuous tagging excluding @O tags
        # if tag != "" and tag != "O":
        #     out_str += " " + word + " @" + tag
        # else:
        #     out_str += " " + word

    if prev_tag != "O": #Need to close a NE at end of line
       out_str += " " + "</" + prev_tag + ">"
    
    out_str += "\n"

    file_output.write(out_str)


file_tagged_gt.close()
file_line_gt.close()
file_output.close()