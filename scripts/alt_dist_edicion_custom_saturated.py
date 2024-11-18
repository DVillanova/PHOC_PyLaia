import sys
import os
#WORKS INSIDE THE DOCKER ENV
#ALT. VERSION TO WORK WITH CONTINUOUS NOTATION
if len(sys.argv) != 3:
    print("Uso: python dist_edicion_custom_saturated.py <path_to_folder_ne_gt> <path_to_folder_ne_hyp>")
    sys.exit(1)

root_dir = "/root/directorioTrabajo/HTR-NER/NER_IAM/"
path_ne_gt = sys.argv[1]
path_ne_hyp = sys.argv[2]

#Cost = saturated CER or WER
def calc_dist_sus(dec_ne, gt_ne, char_level):
    #Check same tags
    if dec_ne.split("@")[1] != gt_ne.split("@")[1]:
        return 2.0
    
    clean_dec_ne = dec_ne.split("@")[0]
    clean_gt_ne = gt_ne.split("@")[0]

    if not char_level: #Transform word into list with 1 word
        clean_dec_ne = clean_dec_ne.split()
        clean_gt_ne = clean_gt_ne.split()
    
    #Tuples of (dist, corr.  )
    vec_dist_pre = [(i, 0) for i in range(len(clean_gt_ne) + 1)]
    vec_dist_act = [(0, 0)] * (len(clean_gt_ne) + 1)

    for j in range(len(clean_dec_ne)):
        vec_dist_act[0] = (j+1, 0)
        for i in range(len(clean_gt_ne)):
            dist_ins = (vec_dist_act[i][0] + 1, vec_dist_act[i][1])
            dist_bor = (vec_dist_pre[i+1][0] + 1, vec_dist_pre[i+1][1])
            
            cost_sus = 0 if clean_dec_ne[j] == clean_gt_ne[i] else 1
            dist_sus = (vec_dist_pre[i][0] + cost_sus, vec_dist_pre[i][1] + (1-cost_sus))

            vec_dist_act[i+1] = min(dist_ins, dist_bor, dist_sus)
            # print(dist_ins, dist_bor, dist_sus)
            # print(i, j, clean_dec_ne[j], clean_gt_ne[i], cost_sus, vec_dist_act[i+1])
        
        vec_dist_pre, vec_dist_act = vec_dist_act, vec_dist_pre
    
    #Saturated edit distance
    ed_dist = 2*min(float(vec_dist_pre[-1][0]) / float(len(clean_gt_ne)), 1.0)

    return ed_dist


def calc_dist_ed(dec_ne_list, gt_ne_list, char_level):
    vec_dist_pre = [i for i in range(len(gt_ne_list) + 1)]
    vec_dist_act = [0] * (len(gt_ne_list) + 1)

    for j in range(len(dec_ne_list)):
        vec_dist_act[0] = j+1
        for i in range(len(gt_ne_list)):
            dist_ins = vec_dist_act[i] + 1
            dist_bor = vec_dist_pre[i+1] + 1
            dist_sus = vec_dist_pre[i] + calc_dist_sus(dec_ne_list[j], gt_ne_list[i], char_level)
            
            vec_dist_act[i+1] = min(dist_ins, dist_bor, dist_sus) 
    
        vec_dist_pre, vec_dist_act = vec_dist_act, vec_dist_pre

    return vec_dist_pre[-1]


file_list = open(os.path.join(root_dir, "TMP/test.lst"), "r")
test_list = list(map(lambda x: x.strip()+'.txt', file_list.readlines()))
file_list.close()

#VARIABLES
num_dist_wer = 0.0
den_dist_wer = 0.0
num_dist_cer = 0.0
den_dist_cer = 0.0

for test_filename in test_list:
    exists_gt = True       
    exists_dec = True
    
    dec_ne_list = list()
    gt_ne_list = list()

    #Hypotheses
    try:
        with open(path_ne_hyp + "/" + test_filename, "r") as f:
            #print(f.name)
            dec_ne_list = list(map(lambda x: x.strip(), f.readlines()))
            last_w = dec_ne_list.pop() #Remove empty line at the end
            if len(last_w) > 0:
                dec_ne_list.append(last_w)
    except:

        exists_dec = False

    #Ground Truth
    try:
        with open(path_ne_gt + "/" + test_filename, "r") as f:
            #print(f.name)
            gt_ne_list = list(map(lambda x: x.strip(), f.readlines()))
            last_w = gt_ne_list.pop() #Remove empty line at the end
            if len(last_w) > 0:
                gt_ne_list.append(last_w)
    except:
        exists_gt = False

    #print(test_filename)
    #print(dec_ne_list)
    #print(gt_ne_list)
    

    #No GT nor Hypothesis file for the line, continue with the test list
    if (not exists_dec) and (not exists_gt):
        continue

    #print(len(dec_ne_list) + len(gt_ne_list))

    #Add number of NE to denominator of the division1
    den_dist_wer = den_dist_wer + len(dec_ne_list) + len(gt_ne_list)
    den_dist_cer = den_dist_cer + len(dec_ne_list) + len(gt_ne_list)

    #Only one file exists (XOR) ==> Count as errors
    if exists_dec ^ exists_gt:
        num_dist_wer = num_dist_wer + len(dec_ne_list) + len(gt_ne_list)
        num_dist_cer = num_dist_cer + len(dec_ne_list) + len(gt_ne_list)
        continue
        
    #If both files are opened, compute edit distance
    num_dist_wer = num_dist_wer + calc_dist_ed(dec_ne_list, gt_ne_list, False)
    num_dist_cer = num_dist_cer + calc_dist_ed(dec_ne_list, gt_ne_list, True)

print("ERROR (WER) = {}".format(num_dist_wer*100.0/den_dist_wer))
print("ERROR (CER) = {}".format(num_dist_cer*100.0/den_dist_cer))