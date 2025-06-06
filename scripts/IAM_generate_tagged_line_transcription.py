import sys

if len(sys.argv) != 5:
    print("Usage: python IAM_generate_tagged_line_transcription.py <mode> <path_to_tagged_gt> <path_to_line_gt> <path_output_file>")
    print("<mode>: Tagging notation to employ. Options:")
    print("\t0 - Parenthesized notation")
    print("\t1 - Continuous notation with reject class")
    print("\t2 - Continuous notation without reject class")
    print("\t3 - Continuous notation without reject class, tags in the form <tag>")
    print("<path_to_tagged_gt>: Path where the whole tagged GT is located")
    print("<path_to_line_gt>: Path where the transcription at line level is located")
    print("<path_output_file>: Path on where to store the output")
    sys.exit(1)

tagging_mode = int(sys.argv[1])
tagged_gt_file = open(sys.argv[2], "r")
line_gt_file = open(sys.argv[3], "r")
output_file = open(sys.argv[4], "w")

# Check if number of tags = number of words in line transcriptions
# dict_page_lengths_1 = dict()
# dict_page_lengths_2 = dict()

#Form dictionary: page - list of lists (line transcriptions)
page_line_transc = dict()
for l in line_gt_file.readlines():
    if "#" != l[0]: #Skip header lines
        l_id, _, _, _, _, _, _, _, transc = l.split(sep= " ", maxsplit=8)
        p_id = "-".join(l_id.split("-")[:-1])
        transc = transc.split("|")
        
        list_line_transc = page_line_transc.get(p_id, list())
        list_line_transc.append(transc)
        page_line_transc[p_id] = list_line_transc
        
        # partial_page_length = dict_page_lengths_1.get(p_id, 0)
        # partial_page_length += len(transc)
        # dict_page_lengths_1[p_id] = partial_page_length

#Form a dictionary: page - list of tags (whole page)
page_tags = dict()
for l in tagged_gt_file.readlines():
    if len(l) > 1: #Avoid empty lines
        w_id, tag = l.split(" ")
        p_id = "-".join(w_id.split("-")[:-2])
        
        page_tag_list = page_tags.get(p_id, list())
        page_tag_list.append(tag.strip())
        page_tags[p_id] = page_tag_list
        
        # partial_page_length = dict_page_lengths_2.get(p_id, 0)
        # partial_page_length += 1
        # dict_page_lengths_2[p_id] = partial_page_length

#Check equivalent number of words and tags (split info is on 2nd dict)
# NOTE: Some pages in dict_page_lengths_1 are not present in the other dict
# for p_id in dict_page_lengths_2.keys():
#     if dict_page_lengths_1[p_id] != dict_page_lengths_2[p_id]:
#         print("Number of words and tags does not match in page: ", p_id)
#         print("Words: {}\tTags: {}".format(dict_page_lengths_1[p_id], dict_page_lengths_2[p_id]))

# sys.exit(1)

#Merge tags and line transc into same list
page_tagged_line_transc = dict()
for p_id in page_tags.keys():
    list_line_transc = page_line_transc[p_id]
    page_tag_list = page_tags[p_id]
    
    index_tag = 0
    
    for l in list_line_transc:
        tagged_line_transc = list()
        for w in l:
            w = "".join(w.strip().split(" ")) #Remove spaces inside words
            tagged_line_transc.append([w,page_tag_list[index_tag]])
            index_tag += 1
        
        list_tagged_lines = page_tagged_line_transc.get(p_id, list())
        list_tagged_lines.append(tagged_line_transc)
        page_tagged_line_transc[p_id] = list_tagged_lines
        
#Output to file
for (p_id, list_line_tagged_transc) in page_tagged_line_transc.items():
    out_str = ""
    counter_line = 0
    for l in list_line_tagged_transc:
        out_str += "%s-%02d" % (p_id, counter_line)
        
        prev_tag = "O"
        for [word, tag] in l:
            if tagging_mode == 0:
                #Version for parenthesized tagging
                if prev_tag != "O" and prev_tag != tag: #Closing of tag
                    out_str += " " + "</" + prev_tag + ">"
                if tag != "O" and prev_tag != tag: #Opening of tags
                    out_str += " " + "<" + tag + ">"
                out_str += " " + word
                prev_tag = tag
                
            if tagging_mode == 1:
                #Version for normal continuous tagging
                out_str += " " + word + " @" + tag
            
            if tagging_mode == 2:
                #Version for continuous tagging excluding @O tags
                if tag != "" and tag != "O":
                    out_str += " " + word + " @" + tag
                else:
                    out_str += " " + word

            if tagging_mode == 3:
                #Alternative version for continuous tagging wtithout reject
                if tag != "" and tag != "O":
                    out_str += " " + word + " <" + tag + ">"
                else:
                    out_str += " " + word
        
        #Version for parenthesized tagging
        if tagging_mode == 0 and prev_tag != "O": #Need to close a NE at end of line
             out_str += " " + "</" + prev_tag + ">"
        
        out_str += "\n"  
        counter_line += 1
        
    output_file.write(out_str)

tagged_gt_file.close()
line_gt_file.close()
output_file.close()