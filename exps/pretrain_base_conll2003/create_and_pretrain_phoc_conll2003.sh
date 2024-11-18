export LC_NUMERIC=C.UTF-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

conda activate exps_embeddings

#Variables, parameters and routes for Docker
BatchSize=8
GPU=1
WorkDir=/home/dvillanova/expsKronos/dvillano/
ScriptsDir=${WorkDir}/scripts/
HomeDataDir=/home/dvillanova/expsKronos/data/conll2003/
# DataDir=/data2/dvillano/iam/DATA
ModelDir=${HomeDataDir}/PHOC_SYNTHETIC_model
img_dirs="[$HomeDataDir/synthetic_lines/all/lines/]"

##################################################################################################################################################################################
cd $WorkDir

cd ${WorkDir}
rm -rf ${ModelDir}
mkdir ${ModelDir}

#Creation of the optical model.
nice pylaia-htr-create-model \
  --save_model true \
  --common.train_path ${ModelDir} \
  --common.model_filename model \
  --logging.level INFO \
  --crnn.cnn_kernel_size [3,3,3,3] \
  --crnn.num_input_channels 3 \
  --fixed_input_height 0 \
  --adaptive_pooling "avgpool-16" \
  --crnn.cnn_dilation [1,1,1,1] \
  --crnn.cnn_num_features [16,32,64,96] \
  --crnn.cnn_batchnorm [True,True,True,True] \
  --crnn.cnn_activation [LeakyReLU,LeakyReLU,LeakyReLU,LeakyReLU] \
  --crnn.cnn_poolsize [2,2,0,2] \
  --crnn.rnn_type LSTM \
  --crnn.rnn_layers 3 \
  --crnn.rnn_units 256 \
  --crnn.rnn_dropout 0.5 \
  --crnn.lin_dropout 0.5 \
  --common.checkpoint va_cer \
  $HomeDataDir/synthetic_lines/all/symb.txt


#--crnn.use_masks true \
#--cnn_num_features 16 32 64 96 \

#PRETRAINING ON CONLL2003 DATASET (low patience, no need to train too much)
img_dirs="[$HomeDataDir/synthetic_lines/all/lines/]"

nice pylaia-htr-train-ctc \
--common.train_path ${ModelDir} \
--common.model_filename model \
--logging.level INFO \
--logging.to_stderr_level INFO \
--logging.filepath $HomeDataDir/train-crnn.log \
--logging.overwrite True \
--trainer.progress_bar_refresh_rate 10 \
--data.batch_size 24 \
--optimizer.learning_rate 0.0003 \
--train.augment_training True \
--train.early_stopping_patience 50 \
--data.color_mode RGB \
--train.delimiters ["<space>"] \
--trainer.gpus [$GPU] \
--trainer.auto_select_gpus False \
--common.monitor va_cer \
--train.checkpoint_k 1 \
--trainer.terminate_on_nan False \
$HomeDataDir/synthetic_lines/all/symb.txt $img_dirs \
$HomeDataDir/synthetic_lines/all/char.train.txt \
$HomeDataDir/synthetic_lines/all/char.valid.txt