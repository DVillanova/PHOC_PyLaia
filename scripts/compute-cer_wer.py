#Compute CER and WER scores using jiwer for a complete dataset.
#Input: 
#  gt_file with transcriptions without tags
#  hyp_file with transcriptions without tags
#Output:
#  CER and WER scores
import sys
import re
from jiwer import cer,wer

if len(sys.argv) != 3:
    print("Usage: python compute-cer_wer.py <path_to_gt_file> <path_to_hyp_file>")
    print("<path_to_gt_file>: Path where the ground truth is present, in format LineID Transcription")
    print("<path_to_hyp_file>: Path where the output is present, in format LineID Transcription")

gt_file = open(sys.argv[1], "r")
hyp_file = open(sys.argv[2], "r")

dict_gt = dict()
dict_hyp = dict()

for l in gt_file.readlines():
    try:
        l_id, transcription = l.strip().split(maxsplit=1)
    except:
        l_id = l.strip()
        transcription = ""
    
    cleaned_transcription = re.sub(r'\s+', ' ', transcription)

    dict_gt[l_id] = cleaned_transcription

for l in hyp_file.readlines():
    try:
        l_id, transcription = l.strip().split(maxsplit=1)
    except:
        l_id = l.strip()
        transcription = ""
    
    cleaned_transcription = re.sub(r'\s+', ' ', transcription)

    dict_hyp[l_id] = cleaned_transcription

#Sort dictionaries by l_id
gt_lines = [v for k,v in sorted(dict_gt.items())]
hyp_lines = [v for k,v in sorted(dict_hyp.items())]

#print(gt_lines[127])
#print(hyp_lines[127])

print("Number of lines in GT: ", len(gt_lines))
print("Number of lines in Hyp: ", len(hyp_lines))

print("CER: {}".format(cer(reference=gt_lines, hypothesis=hyp_lines)))
print("WER: {}".format(wer(reference=gt_lines, hypothesis=hyp_lines)))