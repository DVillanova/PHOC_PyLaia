import sys
import os

if len(sys.argv) != 3:
    print("Usage: python ne_files_to_cont_notation.py <path_to_input_ne_directory> <path_to_output_ne_directory>")
    print("<path_to_ne_directory>: Path where the LINE.txt files are stored, each containing")
    print("\tthe detected Named Entities in the corresponding LINE.")
    print("<path_to_output_ne_directory>: Path on where to store the result for each LINE")
    sys.exit(1)

output_ne_directory = sys.argv[2]
input_ne_directory = sys.argv[1]

for filename in os.listdir(input_ne_directory):
    input_ne_file = open(os.path.join(input_ne_directory, filename), 'r')
    output_ne_file = open(os.path.join(output_ne_directory, filename), 'w')
    
    for ne in input_ne_file.readlines():
        ne_tag = ne.split()[0].replace("<", "").replace(">", "")
        ne_words = ne.split()[1:-1]
        
        out_str = ""
        for w in ne_words:
            out_str += w + "@" + ne_tag + "\n"
        
        output_ne_file.write(out_str)
    
    input_ne_file.close()
    output_ne_file.close()
