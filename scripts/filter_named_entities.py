import sys

if len(sys.argv) != 3:
    print("Usage: python filter_named_entities.py <char_tagged_transcription> <output_file>")
    print("<tagged_char_transcription>: Input file with char-level tagged transcription.")
    print("<output_file>: File which will store the line ID and the sequence of tagging symbols in its transcription.")
    
def is_tag(c):
    if "<" in c and c != "<space>":
        return True
    else:
        return False

input_file = open(sys.argv[1], 'r')
output_file = open(sys.argv[2], 'w')

for l in input_file.readlines():
    l_id, transc = l.split(" ", maxsplit=1)
    transc = list(filter(is_tag, transc.split()))
    if len(transc) > 0: #Only write lines with tags
        out_str = "{} {}\n".format(l_id, " ".join(transc))
        output_file.write(out_str)

input_file.close()
output_file.close()