import torch
import pytorch_lightning
import sys

chkp_src = sys.argv[1]
filename = chkp_src.split("/")[-1]
exp_dir = "/".join(chkp_src.split("/")[:-2])

print(chkp_src)
print(filename)
print(exp_dir)

checkpoint = torch.load(chkp_src)
print("BEFORE:")
print(checkpoint['callbacks'])

# Modify the desired parameters or attributes in the loaded checkpoint
checkpoint['callbacks'][pytorch_lightning.callbacks.early_stopping.EarlyStopping]['best_score'] = torch.tensor(100.0, device='cuda:1')
checkpoint['callbacks'][pytorch_lightning.callbacks.model_checkpoint.ModelCheckpoint]['best_model_score'] = torch.tensor(100.0, device='cuda:1')
checkpoint['callbacks'][pytorch_lightning.callbacks.model_checkpoint.ModelCheckpoint]['current_score'] = torch.tensor(100.0, device='cuda:1')

print("AFTER:")
print(checkpoint['callbacks'])
# Save the modified checkpoint back to a .ckpt file
modified_checkpoint_path = exp_dir + "/modified_monitor/" + filename
torch.save(checkpoint, modified_checkpoint_path)