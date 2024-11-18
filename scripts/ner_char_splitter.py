import sys
import codecs

if len(sys.argv) != 3:
    print("Uso: python3 ner_char_splitter.py <input_file> <output_file>")
    print("<input_file>: Path to file with transcription with separation at the word level.")
    print("<output_file>: Path to save the file that will be generated with separation at character level.")

path_in_file = sys.argv[1]
in_file = codecs.open(path_in_file, 'r')

path_out_file = sys.argv[2]
out_file = codecs.open(path_out_file, 'w')

content_in_file = in_file.readlines()

for line in content_in_file:
    #Separate through spaces, take first word that is the file of the file
    split_line = line.split()
    processed_str = split_line[0]

    for i in range(1,len(split_line)):
        word_i = split_line[i]
        #If word i is a tag
        if word_i[0] == "<":            
            #Look if there was previously a label and print Space in that case
            word_i_prev = split_line[i-1]
            if word_i_prev[0] == "<":
                processed_str += " <space>"

            processed_str += " " + word_i

        else:
            #Separate by spaces
            for j in range(len(word_i)):
                processed_str += " " + word_i[j]
            
            #If it is not the last word and does not have a label in front
            if i != (len(split_line)-1) and split_line[i+1][0] != "<": 
                processed_str += " <space>"
    
    #Write the processed line
    out_file.write(processed_str+"\n")
