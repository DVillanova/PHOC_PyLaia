import sys

#Generates partition files at document level
if len(sys.argv) != 4:
    print("Usage: python IAM_generate_part_files.py <tagged_sent_file> <index.words> <output_file>")
    print("<tagged_sent_file>: File with custom sentence split (ne_annotations)")
    print("<index.words>: File with all the tagged GT")
    print("<output_file>: File on which to store the page ids")
    sys.exit(1)
    
        
tagged_sent_file = open(sys.argv[1], "r")
gt_file = open(sys.argv[2], "r")
output_file = open(sys.argv[3], "w")

page_set = set()
dict_doc_to_lines = dict()

#Format of input lines: doc-numpage-numsentence-numword tag
for l in tagged_sent_file.readlines():
    if len(l) > 1:
        w_id, tag = l.split(" ")
        p_id = "-".join(w_id.split("-")[:-2])
        page_set.add(p_id)
    
#Format of lines doc-numpage-numline transcription
for l in gt_file.readlines():
    l_id, transc = l.split(" ", maxsplit = 1)
    p_id = "-".join(l_id.split("-")[:-1])
    
    list_lines = dict_doc_to_lines.get(p_id, list())
    list_lines.append(l_id)
    dict_doc_to_lines[p_id] = list_lines

for p_id in page_set:
    for l in dict_doc_to_lines[p_id]:
        output_file.write(l + "\n")
