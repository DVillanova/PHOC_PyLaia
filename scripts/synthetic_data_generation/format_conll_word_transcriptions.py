#From annotations.txt file generated by doc_synthesizer.py, change the format to
#compile a file with "image_id\stagged_transcription\n". This file will be later used
#to generate PyLaia character level transcriptions.

import sys

if len(sys.argv) != 2:
    print("Usage: python format_conll_word_transcriptions.py <path_to_annotations_file>")
    print("<path_to_annotations_file>: Path to directory where the annotations.txt file is.")
    print("     The output of the process will be stored in this same directory")
    sys.exit(1)

path_to_annotations_file = sys.argv[1]
annotations_file = open(path_to_annotations_file + "/annotations.txt", "r")
output_file = open(path_to_annotations_file + "/word_transcription.txt", "w")

#We skip the first line which contains a header
for l in annotations_file.readlines()[1:]:
    (image_id, transcription, tags) = l.split("\t")

    list_transcription = transcription.strip().split()
    list_tags = tags.strip().split()
    #Sanity check
    if len(list_transcription) != len(list_tags):
        print("Error in {}: len of transcription does not match len of tags".format(image_id))
        sys.exit(1)
    
    output_str = image_id
    for (i, w_i) in enumerate(list_transcription):
        t_i = list_tags[i]

        #Remap tagging to IAM: LOC -> L, ORG -> G, PER -> P
        #MISC remains as its own category
        if t_i == "LOC":
            t_i = "L"
        if t_i == "ORG":
            t_i = "G"
        if t_i == "PER":
            t_i = "P"

        #Only add the tag to the file if is not "reject"
        if t_i != "O":
            output_str += " {}<{}>".format(w_i, t_i)
        else:
            output_str += " {}".format(w_i)
        

    output_str += "\n"
    output_file.write(output_str)

annotations_file.close()
output_file.close()

    