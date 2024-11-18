import sys
import os

if len(sys.argv) != 3:
    print("Usage: python extract_ner_gw.py <path_word_transc_file> <path_output_dir>")
    print("<path_word_transc_file>: Path to the input file with word-level transcription and parenthesized tagging")
    print("<path_output_dir>: Path to the directory on which to store the output files (one per line)")
    sys.exit(1)
    
input_file = open(sys.argv[1], 'r')
output_dir = sys.argv[2]

for l in input_file.readlines():
    l_id, transc = l.split(" ", maxsplit=1)
    
    detected_ne = "O" #Null type of Named Entity
    counter = 0 #Counting the number of words in each NE
    out_str = ""
    
    for w in transc.split(" "):
        w = w.strip() #Remove \n from words at end of line
        if "</" in w: #Closing of a NE => Reset to default
            detected_ne = "O"
            counter = 0
        elif "<" in w: #Opening of NE
            tag = w.replace("<", "").replace(">", "")
            detected_ne = tag
            counter = 0
        else: #Normal word
            if detected_ne != "O":
                out_str += "{}@{}\n".format(w, detected_ne)
                counter += 1
            
            if detected_ne != "O" and counter > 999: #Early closing of NE (heuristic)
                detected_ne = "O"
                counter = 0 
    
    if len(out_str) > 0:    
        output_file = open(os.path.join(output_dir, l_id + ".txt"), 'w')
        output_file.write(out_str)
        output_file.close()