import sys
import codecs

if len(sys.argv) != 3:
    print("Uso: python3 ner_lst_generator.py <file_lst_base> <file_lst_output>")
    print("<file_lst_base>: Path to file .lst with routes from folders czech_charters or similar.")
    print("<file_lst_output>: Path to save the .lst only with the IDs of the images.")


path_in_file = sys.argv[1]
in_file = codecs.open(path_in_file, 'r')

path_out_file = sys.argv[2]
out_file = codecs.open(path_out_file, 'w')

content_in_file = in_file.readlines()

for line in content_in_file:
    split_line = line.split("/")
    out_file.write(split_line[-1])