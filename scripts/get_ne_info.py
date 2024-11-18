import sys
import os
import math

root_dir = "/home/dvillanova/hunterFinal/directorioTrabajo/TFM-NER/"
ref_filename = sys.argv[1]
with open(ref_filename, 'r') as file_gt:
    gt_list = list(map(lambda x: x.strip(), file_gt.readlines()))

dict_ne_structures = dict()

counter_mismatch_ne = 0
counter_opened_ne_glob = 0
counter_closed_ne_glob = 0

for line_gt in gt_list:
    stack_ne = list()
    nesting = 0


    transcript = line_gt.split()[1:]
    counter_opened_ne_trans = 0
    counter_closed_ne_trans = 0

    for w in transcript:
        
        if w[0] == "<":
            #print(w)
            if w[1] == "/":
                counter_closed_ne_trans += 1
                nesting -= 1
                stack_ne.append(w)

                #If you close a Named Entity block, add 1 to count and reset Stack
                if nesting == 0:
                    n_occurrences = dict_ne_structures.get(tuple(stack_ne), 0)
                    dict_ne_structures[tuple(stack_ne)] = n_occurrences + 1
                    stack_ne = list()

            elif w[1] != "s":
                counter_opened_ne_trans += 1
                nesting += 1
                stack_ne.append(w)
    
    #If there is Matatch also add the case to the dictionary
    if nesting != 0:
        n_occurrences = dict_ne_structures.get(tuple(stack_ne), 0)
        dict_ne_structures[tuple(stack_ne)] = n_occurrences + 1

    #if counter_opened_ne_trans != counter_closed_ne_trans:
    #    print(line_gt)

    counter_mismatch_ne += abs(counter_opened_ne_trans - counter_closed_ne_trans)
    counter_closed_ne_glob += counter_closed_ne_trans
    counter_opened_ne_glob += counter_opened_ne_trans

#print(counter_mismatch_ne/2)
print("Opened NEs: ", counter_opened_ne_glob)
print("Closed NEs: ", counter_closed_ne_glob)

#print("Types of Named Entities and count:")
#for ne in dict_ne_structures.keys():
#    print(ne, dict_ne_structures[ne])