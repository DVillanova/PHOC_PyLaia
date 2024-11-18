import sys
import os
import copy

#WORKS INSIDE THE DOCKER ENV
if len(sys.argv) != 5:
    print("Usage: python macro_edit_dist_tag_f1.py <path_tagging_symbols_file> <path_partition_file>")
    print("\t<path_folder_ne_gt> <path_folder_ne_hyp>")
    sys.exit(1)

#FUNC. TO COMPUTE TP, FP, FN FOR 2 SEQUENCES OF DIFFERENT LENGTH OF NE TAGS
def calc_dist_ed(dec_ne_list, gt_ne_list, dict_tag_to_id):
    partial_mat_tp_fp_fn = dict()
    for cat in dict_tag_to_id.keys(): #Initialize each row in matrix to 0s
        partial_mat_tp_fp_fn[cat] = [0, 0, 0]
    vec_dist_pre = [[0, partial_mat_tp_fp_fn]]
    
    #Initialize tp_fp_fn matrix for each cell
    for i in range(1,len(gt_ne_list)+1):
        partial_mat_tp_fp_fn = copy.deepcopy(partial_mat_tp_fp_fn)
        ne_tag = gt_ne_list[i-1]        
        partial_mat_tp_fp_fn[ne_tag][2] = partial_mat_tp_fp_fn[ne_tag][2] + 1
        vec_dist_pre.append([i, partial_mat_tp_fp_fn])
    # print(vec_dist_pre)
    
    for j in range(len(dec_ne_list)):
        dec_ne_tag = dec_ne_list[j]
        partial_mat_tp_fp_fn = copy.deepcopy(vec_dist_pre[0][1])
        partial_mat_tp_fp_fn[dec_ne_tag][1] = partial_mat_tp_fp_fn[dec_ne_tag][1] + 1
        vec_dist_act = [[j+1, partial_mat_tp_fp_fn]]
        
        
        for i in range(len(gt_ne_list)):
            dist_ins = vec_dist_act[i][0] + 1
            dist_bor = vec_dist_pre[i+1][0] + 1
            
            cost_sus = 0 if dec_ne_list[j] == gt_ne_list[i] else 999
            dist_sus = vec_dist_pre[i][0] + cost_sus

            #Decide which path to take and append to vec.
            if min(dist_ins, dist_bor, dist_sus) == dist_sus:
                #Perform substitution (TP)
                partial_mat_tp_fp_fn = copy.deepcopy(vec_dist_pre[i][1])
                partial_mat_tp_fp_fn[gt_ne_list[i]][0] = partial_mat_tp_fp_fn[gt_ne_list[i]][0] + 1
            elif min(dist_ins, dist_bor, dist_sus) == dist_bor:
                #Perform deletion (FP)
                partial_mat_tp_fp_fn = copy.deepcopy(vec_dist_pre[i+1][1])
                partial_mat_tp_fp_fn[dec_ne_list[j]][1] = partial_mat_tp_fp_fn[dec_ne_list[j]][1] + 1
            else:
                #Perform insertion (FN)
                partial_mat_tp_fp_fn = copy.deepcopy(vec_dist_act[i][1])
                partial_mat_tp_fp_fn[gt_ne_list[i]][2] = partial_mat_tp_fp_fn[gt_ne_list[i]][2] + 1
            
            vec_dist_act.append([min(dist_ins, dist_bor, dist_sus), partial_mat_tp_fp_fn])
        
        vec_dist_pre = vec_dist_act
        vec_dist_act = None
    
    return vec_dist_pre[-1][1] #Return matrix of TP, FP and FN


tagging_symbols_file = open(sys.argv[1], 'r')
partition_file = open(sys.argv[2], 'r')
path_ne_gt = sys.argv[3]
path_ne_hyp = sys.argv[4]

dict_tag_to_id = dict()

counter_categories = 0
for l in tagging_symbols_file.readlines():
    l = l.strip()
    if "@" in l and l != "@O":
        dict_tag_to_id[l.replace("@", "")] = counter_categories
        counter_categories += 1
    
mat_tp_fp_fn = dict()
for cat in dict_tag_to_id.keys(): #Initialize each row in matrix to 0s
    mat_tp_fp_fn[cat] = [0, 0, 0]
    
for l_filename in partition_file.readlines():
    l_filename = l_filename.strip()
    
    path_file_hyp = os.path.join(path_ne_hyp, l_filename + ".txt")
    path_file_gt = os.path.join(path_ne_gt, l_filename + ".txt")
    
    # print("File GT: ", path_file_hyp)
    # print("File Hyp: ", path_file_gt)
    
    exists_file_hyp = os.path.exists(path_file_hyp)
    file_hyp = None
    if exists_file_hyp:
        file_hyp = open(path_file_hyp, 'r')
    
    exists_file_gt = os.path.exists(path_file_gt)
    file_gt = None
    if exists_file_gt:
        file_gt = open(path_file_gt, 'r')
    
    if not exists_file_hyp and exists_file_gt:
        #All the NEs are False Negatives
        for l in file_gt.readlines():
            ne_tag = l.strip().split("@")[1]
            mat_tp_fp_fn[ne_tag][2] = mat_tp_fp_fn[ne_tag][2] + 1

    if exists_file_hyp and not exists_file_gt:
        #All the NEs are False Positives
        for l in file_hyp.readlines():
            ne_tag = l.strip().split("@")[1]
            mat_tp_fp_fn[ne_tag][1] = mat_tp_fp_fn[ne_tag][1] + 1
            
    if exists_file_hyp and exists_file_gt:
        #Compute edit distance between sequences
        dec_ne_list = [l.strip().split("@")[1] for l in file_hyp.readlines()]
        gt_ne_list = [l.strip().split("@")[1] for l in file_gt.readlines()]
        partial_mat_tp_fp_fn = calc_dist_ed(dec_ne_list, gt_ne_list, dict_tag_to_id)
        
        #Add calculated TP, FP and FN to each row in the matrix
        for (cat, partial_list_tp_fp_fn) in partial_mat_tp_fp_fn.items():
            list_tp_fp_fn = mat_tp_fp_fn[cat]
            list_tp_fp_fn[0] = list_tp_fp_fn[0] + partial_list_tp_fp_fn[0]
            list_tp_fp_fn[1] = list_tp_fp_fn[1] + partial_list_tp_fp_fn[1]
            list_tp_fp_fn[2] = list_tp_fp_fn[2] + partial_list_tp_fp_fn[2]
            
            mat_tp_fp_fn[cat] = list_tp_fp_fn

#Output results to terminal output
sum_precision = 0
sum_recall = 0

for (cat, list_tp_fp_fn) in mat_tp_fp_fn.items():
    print("========================")
    print("Category: {}".format(cat))
    print("========================")
    
    if list_tp_fp_fn[0] > 0 and list_tp_fp_fn[1] > 0 and list_tp_fp_fn[2] > 0:
        precision = list_tp_fp_fn[0] / (list_tp_fp_fn[0] + list_tp_fp_fn[1])
        recall = list_tp_fp_fn[0] / (list_tp_fp_fn[0] + list_tp_fp_fn[2])
        f1 = 2 * (precision * recall) / (precision + recall)
        
        sum_precision += precision
        sum_recall += recall
        
        
        print("Precision: {}".format(precision))
        print("\tTP: {} - \tFP: {}".format(list_tp_fp_fn[0], list_tp_fp_fn[1]))
        print("Recall: {}".format(recall))
        print("\tTP: {} - \tFN: {}".format(list_tp_fp_fn[0], list_tp_fp_fn[2]))
        print("F1 score: {}".format(f1))
    else:
        print("CATEGORY ELIMINATED")
        counter_categories -= 1


precision = sum_precision / counter_categories
recall = sum_recall / counter_categories
f1 = 2 * (precision * recall) / (precision + recall)
print("========================")
print("GLOBAL MEAN:")
print("========================")
print("Precision: {}".format(precision))
print("Recall: {}".format(recall))
print("F1 score: {}".format(f1))

