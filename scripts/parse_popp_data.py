#Read file with POPP dataset notation (one opening symbol per NE) and translate it to continuous notation
import sys

if len(sys.argv) != 3:
    print("Usage: python parse_popp_data.py <path_to_src_file> <path_to_output_file>")
    sys.exit(1)

src_file = open(sys.argv[1], "r", encoding='utf-8')
out_file = open(sys.argv[2], "w", encoding='utf-8')

for l in src_file.readlines():
    current_tag = ""
    word = []
    try:
        img_id, transc = l.strip().split(" ", maxsplit=1)
    except:
        img_id = l.strip()
        transc = ""
    out_str = img_id + " "

    #Read transcription character by character
    for c in transc.split(" "):
        if c == "Ⓑ":
            current_tag = "<B>"
        elif c == "Ⓒ":
            current_tag = "<C>"
        elif c == "Ⓔ":
            current_tag = "<E>"
        elif c == "Ⓕ":
            current_tag = "<F>"
        elif c == "Ⓚ":
            current_tag = "<K>"
        elif c == "Ⓛ":
            current_tag = "<L>"
        elif c == "Ⓝ":
            current_tag = "<N>"
        elif c == "Ⓞ":
            current_tag = "<O>"
        elif c == "Ⓟ":
            current_tag = "<P>"
        elif c == "Ⓢ":
            current_tag = "<S>"
        elif c == "<space>":
            out_str += " ".join(word) + " " + current_tag + " <space> "
            word = []
        else:
            word.append(c)
    
    if len(word) != 0: #End of line
        out_str += " ".join(word) + " " + current_tag
        word = []

    out_file.write(out_str + "\n")

out_file.close()
src_file.close()