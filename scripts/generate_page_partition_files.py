import sys
import os

if len(sys.argv) != 4:
    print("Usage: python generate_page_partition_files.py <path_index.words> <tagged_files_dir> <output_dir>")
    print("<path_index.words>: Path to the index.words file")
    print("<tagged_files_dir>: Directory with GT split by words")
    print("<output_dir>: Directory on which to store the output")
    sys.exit(1)

def generate_page_set(input_file):
    page_ids = set()
    for l in input_file.readlines():
        if len(l) > 3:
            page_ids.add(l[:3])
        
    return page_ids
        
   
path_gt_file = sys.argv[1]
input_dir = sys.argv[2]
output_dir = sys.argv[3]

test_input_file = open(os.path.join(input_dir, "tagged_gw_test.txt"), 'r')
val_input_file = open(os.path.join(input_dir, "tagged_gw_val.txt"), 'r')
train_input_file = open(os.path.join(input_dir, "tagged_gw_train.txt"), 'r')

test_page_ids = generate_page_set(test_input_file)
val_page_ids = generate_page_set(val_input_file)
train_page_ids = generate_page_set(train_input_file)

test_input_file.close()
val_input_file.close()
train_input_file.close()

test_output_file = open(os.path.join(output_dir, "test.lst"), 'w')
val_output_file = open(os.path.join(output_dir, "val.lst"), 'w')
train_output_file = open(os.path.join(output_dir, "train.lst"), 'w')

gt_file = open(path_gt_file, 'r')
page_to_line_dict = dict()
for l in gt_file.readlines():
    p_id = l[:3]
    l_id = l[:6] 
   
    if "X" not in l_id:
        p_l_id_list = page_to_line_dict.get(p_id, list())
        p_l_id_list.append(l_id)
        page_to_line_dict[p_id] = p_l_id_list

for p_id in test_page_ids:
    out_str = ""
    for l_id in page_to_line_dict[p_id]:
        out_str += l_id + "\n"
    test_output_file.write(out_str)

for p_id in val_page_ids:
    out_str = ""
    for l_id in page_to_line_dict[p_id]:
        out_str += l_id + "\n"
    val_output_file.write(out_str)

for p_id in train_page_ids:
    out_str = ""
    for l_id in page_to_line_dict[p_id]:
        out_str += l_id + "\n"
    train_output_file.write(out_str)