import sys

if len(sys.argv) != 4:
    print("Usage: python remove_tagging.py <path_tagging_symbols_file> <path_tagged_char_transcription_file> <path_output_file>")
    print("<path_tagging_symbols_file>: Path to the file with the vocabulary to remove from the tagged transcriptions")
    print("<path_tagged_char_transcription_file>: Path to the input file with char level tagged transcriptions")
    print("<path_output_file>: Path to the output file on which to store the transcriptions without tags")
    
tagging_symbols_file = open(sys.argv[1], 'r') #Special symb.txt file
tagged_transcription_file = open(sys.argv[2], 'r') #hypotheses-test_t
output_file = open(sys.argv[3], 'w')

tagging_symbols = set()
for l in tagging_symbols_file.readlines():
    tagging_symbols.add(l.strip())

tagging_symbols_file.close()
    
for l in tagged_transcription_file.readlines():
    #print(l)
    list_l = l.strip().split(" ", maxsplit = 1)
    if len(list_l) == 1:
        output_file.write(l.strip() + "\n")
    else:
        l_id = list_l[0]
        transc = " "+list_l[1]
        for t in tagging_symbols:
            transc = transc.replace(" "+t, "") #Remove tag and character separator
        
        output_file.write("{} {}\n".format(l_id, transc))

tagged_transcription_file.close()
output_file.close()