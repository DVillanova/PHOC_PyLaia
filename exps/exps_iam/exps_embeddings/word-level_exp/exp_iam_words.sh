# set -e
#EXPERIMENT TO RUN WORD-LEVEL RECOGNITION IN CONLL
export LC_NUMERIC=C.UTF-8;

#Conda environment with local installation of PyLaia
conda activate exps_embeddings

#Variables, parameters and routes
BatchSize=8
WorkDir=/home/dvillano/
ScriptsDir=${WorkDir}/scripts/
PartDir=${DataDir}/partitions/
HomeDataDir=/data/dvillano/iam/
DataDir=/data/dvillano/iam/DATA_WORDS
TextDir=${HomeDataDir}/6_WORDS_TEXT
LangDir=${HomeDataDir}/6_WORDS_TEXT
CharDir=${LangDir}/char
ModelDir=${HomeDataDir}/6_WORDS_model
TmpDir=${HomeDataDir}/6_WORDS_TMP
NerDir=${HomeDataDir}/NER
NerNoRepDir=${HomeDataDir}/NER-NoRep
KenLmDir=${WorkDir}/kenlm/build/bin/

#img_dirs=$(find ${DataDir}/lines -mindepth 2 -maxdepth 2 -type d)
#img_dirs=$(cat $WorkDir/iam/lines_dirs.txt)
img_dirs=$(find ${DataDir}/imgs -mindepth 2 -maxdepth 2 -type d)

mkdir $DataDir/imgs/all_imgs/
for dir in $img_dirs; do
  cp $dir/* $DataDir/imgs/all_imgs/
done

echo $img_dirs | sed 's/ /,/g' > $WorkDir/iam/words_dirs.txt
#Here need to add manually [ ] symbols to words_dirs.txt
echo "[$DataDir/imgs/all_imgs]" > $WorkDir/iam/words_dirs.txt
img_dirs=$(cat $WorkDir/iam/words_dirs.txt)
##################################################################################################################################################################################
cd $WorkDir
rm -rf ${TextDir}
mkdir ${TextDir}

cp ${DataDir}/transcriptions/index.words ${TextDir}/index.words

mkdir -p ${CharDir}
cd ${CharDir}

cat ${TextDir}/index.words | awk '{
        printf("%s", $1);
        for(i=2;i<=NF;++i) {
                if($i!~"<"){  
                        for(j=1;j<=length($i);++j) 
                                printf(" %s", substr($i, j, 1));
                        if ((i < NF) && ($(i+1)!~"<")) printf(" <space>");
                }else{ 
                        printf " "$i" ";
                        if (i < NF) printf("<space>");
                }; 
        }
        printf("\n");
}' | sed 's/#/<stroke>/g' > char.total.txt

#Copy symb.txt file with symbols from CONLL and IAM
cp $HomeDataDir/6_PHOC_TMP/symb.txt $CharDir/symb.txt

#GENERATE .TXT FILES WITH LINE ID AND TRANSCRIPTION
#FROM .LST FILES (PARTITION) AND INDEX.WORDS
rm -rf ${TmpDir}
mkdir ${TmpDir}
cd ${TmpDir}

cp ${PartDir}/test.lst ./test.lst
cp ${PartDir}/train.lst ./train.lst
cp ${PartDir}/val.lst ./val.lst

for f in $(<./train.lst); do grep "${f}\b" ${TextDir}/index.words;
done > ./train.txt
for f in $(<./test.lst); do grep "${f}\b" ${TextDir}/index.words;
done > ./test.txt
for f in $(<./val.lst); do grep "${f}\b" ${TextDir}/index.words;
done > ./val.txt

cp $DataDir/transcriptions/train_words.txt ./train.txt
cp $DataDir/transcriptions/val_words.txt ./val.txt
cp $DataDir/transcriptions/test_words.txt ./test.txt


# CREATION CHAR.TRAIN CHAR.VAL CHAR.TEST
cat train.txt |
awk '{
  printf("%s", $1);
  for(i=2;i<=NF;++i) {
    if($i!~"<"){  
      for(j=1;j<=length($i);++j) 
        printf(" %s", substr($i, j, 1));
      if ((i < NF) && ($(i+1)!~"<")) printf(" <space>");
    }else{ 
      printf " "$i" ";
      if (i < NF) printf("<space>");
    }; 
  }
  printf("\n");
}' | sed 's/#/<stroke>/g' > char.train.txt

cat val.txt |
awk '{
  printf("%s", $1);
  for(i=2;i<=NF;++i) {
    if($i!~"<"){  
      for(j=1;j<=length($i);++j) 
        printf(" %s", substr($i, j, 1));
      if ((i < NF) && ($(i+1)!~"<")) printf(" <space>");
    }else{ 
      printf " "$i" ";
      if (i < NF) printf("<space>");
    }; 
  }
  printf("\n");
}' | sed 's/#/<stroke>/g' > char.val.txt

cat test.txt |
awk '{
  printf("%s", $1);
  for(i=2;i<=NF;++i) {
    if($i!~"<"){  
      for(j=1;j<=length($i);++j) 
        printf(" %s", substr($i, j, 1));
      if ((i < NF) && ($(i+1)!~"<")) printf(" <space>");
    }else{ 
      printf " "$i" ";
      if (i < NF) printf("<space>");
    }; 
  }
  printf("\n");
}' | sed 's/#/<stroke>/g' > char.test.txt


#symb.txt from CONLL2003 and IAM (without <eps> symbol)
cp $HomeDataDir/../conll2003/synthetic_lines/all/symb.txt ./symb.txt


cd ${WorkDir}
rm -rf ${ModelDir}
mkdir ${ModelDir}

#Creation of the optical model.

#TODO: TRY REDUCING THE NUMBER RNN_UNITS 256 => 128 or 64
nice pylaia-htr-create-model \
  --save_model true \
  --common.train_path ${ModelDir} \
  --common.model_filename model \
  --logging.level INFO \
  --crnn.cnn_kernel_size [3,3,3,3] \
  --crnn.num_input_channels 3 \
  --fixed_input_height 0 \
  --crnn.cnn_dilation [1,1,1,1] \
  --crnn.cnn_num_features [16,32,64,96] \
  --crnn.cnn_batchnorm [True,True,True,True] \
  --crnn.cnn_activation [LeakyReLU,LeakyReLU,LeakyReLU,LeakyReLU] \
  --crnn.cnn_poolsize [2,2,0,2] \
  --crnn.rnn_type LSTM \
  --crnn.rnn_layers 3 \
  --crnn.rnn_units 64 \
  --crnn.rnn_dropout 0.5 \
  --crnn.lin_dropout 0.5 \
  --common.checkpoint va_cer \
  ${TmpDir}/symb.txt

#--crnn.use_masks true \
#--cnn_num_features 16 32 64 96 \

#PRETRAINING ON IAM WORDS DATASET (low patience, no need to train too much)
img_dirs="[$DataDir/imgs/all_imgs/]"

#cd /home/dvillano/word_embeddings_pylaia
#pip install .
#rm -rf /home/dvillano/word_embeddings_pylaia/build
nice pylaia-htr-train-ctc \
--common.train_path ${ModelDir} \
--common.model_filename model \
--logging.level INFO \
--logging.to_stderr_level INFO \
--logging.filepath $HomeDataDir/train-crnn.log \
--logging.overwrite True \
--trainer.progress_bar_refresh_rate 10 \
--data.batch_size ${BatchSize} \
--optimizer.learning_rate 0.0003 \
--train.augment_training True \
--train.early_stopping_patience 50 \
--data.color_mode RGB \
--train.delimiters ["<space>"] \
--trainer.gpus [2] \
--trainer.auto_select_gpus False \
--common.monitor va_cer \
--train.checkpoint_k 1 \
--trainer.terminate_on_nan False \
--trainer.check_val_every_n_epoch 10 \
${TmpDir}/symb.txt $img_dirs \
$TmpDir/char.train.txt \
$TmpDir/char.val.txt
#--train.resume 999 \  
#$HomeDataDir/../conll2003/synthetic_lines/all/char.train.txt \

#RESUMING TRAINING
pip install .; nice pylaia-htr-train-ctc \
--common.train_path ${ModelDir} \
--common.model_filename model \
--logging.level INFO \
--logging.to_stderr_level INFO \
--logging.filepath $HomeDataDir/train-crnn.log \
--logging.overwrite True \
--trainer.progress_bar_refresh_rate 10 \
--data.batch_size ${BatchSize} \
--optimizer.learning_rate 0.0003 \
--train.augment_training True \
--train.early_stopping_patience 50 \
--data.color_mode RGB \
--train.delimiters ["<space>"] \
--trainer.gpus [2] \
--trainer.auto_select_gpus False \
--common.monitor va_cer \
--train.checkpoint_k 1 \
--train.resume 999 \
--trainer.terminate_on_nan False \
--trainer.check_val_every_n_epoch 10 \
${TmpDir}/symb.txt $img_dirs \
$HomeDataDir/../conll2003/synthetic_lines/all/char.train.txt \
$HomeDataDir/../conll2003/synthetic_lines/all/char.valid.txt


#Save copy in original_experiment
mkdir $ModelDir/original_experiment/
cp $ModelDir/experiment/epoch=*-lowest_va_ecer.ckpt \
$ModelDir/original_experiment/

ExpName=$(ls $ModelDir/original_experiment/)

#Modify the monitors to reset the values to 100.0 in all callbacks
python $ScriptsDir/reset_checkpoint_monitors.py \
$ModelDir/original_experiment/$ExpName

#Copy the new checkpoint to model
cp $ModelDir/modified_monitor/$ExpName $ModelDir/


#Optical model training ON IAM
img_dirs=$(cat $WorkDir/iam/lines_dirs.txt)

nice pylaia-htr-train-ctc \
--common.train_path ${ModelDir} \
--common.model_filename model \
--logging.level INFO \
--logging.to_stderr_level INFO \
--logging.filepath $HomeDataDir/train-crnn.log \
--logging.overwrite True \
--trainer.progress_bar_refresh_rate 10 \
--data.batch_size ${BatchSize} \
--optimizer.learning_rate 0.0003 \
--train.augment_training True \
--train.early_stopping_patience 50 \
--data.color_mode RGB \
--train.delimiters ["<space>"] \
--trainer.gpus [1] \
--trainer.auto_select_gpus False \
--common.monitor va_cer \
--train.checkpoint_k 1 \
--train.resume 999 \
--trainer.terminate_on_nan False \
${TmpDir}/symb.txt $img_dirs \
${TmpDir}/char.train.txt \
${TmpDir}/char.val.txt

#
#syms img_dirs [img_dirs...] tr_txt_table va_txt_table



mkdir ${TmpDir}/decode
cd ${TmpDir}/decode 

#Decodification Test and Val for Wer
#CER (SPACE = "<SPACE>", JOIN_STR = " ")

#Decoding at char level => Model has to be chosen manually (for now)
nice pylaia-htr-decode-ctc \
  --common.train_path ${ModelDir} \
  --common.model_filename model \
  --common.checkpoint ${ModelDir}/experiment/epoch=277-lowest_va_cer.ckpt \
  --logging.level INFO \
  --logging.to_stderr_level INFO \
  --logging.filepath $HomeDataDir/test-crnn.log \
  --logging.overwrite True \
  --trainer.progress_bar_refresh_rate 10 \
  --data.batch_size ${BatchSize} \
  --data.color_mode RGB \
  --trainer.gpus [1] \
  --trainer.auto_select_gpus False \
  --common.monitor va_cer \
  --trainer.terminate_on_nan False \
  --decode.use_symbols True \
  --decode.separator " " \
  --decode.join_string " " \
  --decode.output_space "<space>" \
  --img_dirs $img_dirs \
  ${TmpDir}/symb.txt ${TmpDir}/test.lst > ${TmpDir}/decode/test.txt

#Decoding at word level (need to process with sed)
# nice pylaia-htr-decode-ctc \
#   --common.train_path ${ModelDir} \
#   --common.model_filename model \
#   --logging.level INFO \
#   --logging.to_stderr_level INFO \
#   --logging.filepath $HomeDataDir/test-crnn.log \
#   --logging.overwrite True \
#   --trainer.progress_bar_refresh_rate 10 \
#   --data.batch_size ${BatchSize} \
#   --data.color_mode RGB \
#   --trainer.gpus [1] \
#   --trainer.auto_select_gpus False \
#   --common.monitor va_cer \
#   --trainer.terminate_on_nan False \
#   --decode.use_symbols True \
#   --decode.separator " " \
#   --decode.join_string "" \
#   --decode.output_space " " \
#   --img_dirs $img_dirs \
#   ${TmpDir}/symb.txt ${TmpDir}/test.lst > ${TmpDir}/decode/wordtest.txt
# #--decode.segmentation char \
# sed -i 's/<space>/ /g' wordtest.txt

awk '{
  printf("%s ", $1);
  for (i=2;i<=NF;++i) {
    if ($i == "<space>")
      printf(" ");
    else
      printf("%s", $i);
  }
  printf("\n");
}' ${TmpDir}/decode/test.txt > ${TmpDir}/decode/wordtest.txt;

#BIO format GT
mkdir $TmpDir/bio_labels
rm $TmpDir/bio_labels/*
python $ScriptsDir/parser_continuous_to_bio.py \
${TmpDir}/test.txt $TmpDir/bio_labels/

#python $ScriptsDir/parser_continuous_to_bio.py ${TmpDir}/train.txt $TmpDir/bio_labels_train/
#python $ScriptsDir/parser_continuous_to_bio.py ${TmpDir}/val.txt $TmpDir/bio_labels_val/

#BIO format output
mkdir $TmpDir/decode/bio_labels
rm $TmpDir/decode/bio_labels/*
python $ScriptsDir/parser_continuous_to_bio.py \
${TmpDir}/decode/wordtest.txt ${TmpDir}/decode/bio_labels/

#Compute evaluation metrics and send to $HomeDataDir/results_baseline.txt
ie-eval all --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/bio_labels/ \
> ${HomeDataDir}/results_synthetic_0.txt

ie-eval nerval --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/bio_labels/ \
>> ${HomeDataDir}/results_synthetic_0.txt

#Evaluate CER and WER to see quality of transcriptions without tags
#Process output (wordtest.txt) to remove the tags
sed 's/<C>//g' $TmpDir/decode/wordtest.txt > $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<G>//g' $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<L>//g' $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<N>//g' $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<P>//g' $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<T>//g' $TmpDir/decode/wordtest_no_tags.txt

#Remove line IDs from file
# cut -f 2- -d " " $TmpDir/decode/wordtest_no_tags.txt > $TmpDir/decode/wordtest_no_tags_no_lineids.txt

#Process GT file to remove the tags
sed 's/<C>//g' $TmpDir/test.txt > $TmpDir/test_no_tags.txt
sed -i 's/<G>//g' $TmpDir/test_no_tags.txt
sed -i 's/<L>//g' $TmpDir/test_no_tags.txt
sed -i 's/<N>//g' $TmpDir/test_no_tags.txt
sed -i 's/<P>//g' $TmpDir/test_no_tags.txt
sed -i 's/<T>//g' $TmpDir/test_no_tags.txt

#Remove line IDs from file
# cut -f 2- -d " " $TmpDir/test_no_tags.txt > $TmpDir/test_no_tags_no_lineids.txt

#Computation of CER and WER
python $ScriptsDir/compute-cer_wer.py $TmpDir/test_no_tags.txt $TmpDir/decode/wordtest_no_tags.txt >> $HomeDataDir/results_synthetic_0.txt
cat $HomeDataDir/results_synthetic_0.txt



#####################################
# INCLUDING EXTERNAL LANGUAGE MODEL #
#####################################
#Merge all conll2003 data and IAM train and validation into a single file (everything except IAM test)
cut -f 3- -d " " $HomeDataDir/../conll2003/synthetic_lines/all/index.words > $TextDir/conll2003_words.txt
cp $TextDir/conll2003_words.txt $TextDir/lm_words_train.txt
cut -f 2- -d " " $TmpDir/train.txt >> $TextDir/lm_words_train.txt
cut -f 2- -d " " $TmpDir/val.txt >> $TextDir/lm_words_train.txt
#add <space> symbols between words (sed)
sed 's/ / <space> /g' -i $TextDir/lm_words_train.txt

#Same for char level transcriptions
cut -f 2- -d " " $HomeDataDir/../conll2003/synthetic_lines/all/char.train.txt > $TextDir/conll2003_chars.txt
cut -f 2- -d " " $HomeDataDir/../conll2003/synthetic_lines/all/char.valid.txt >> $TextDir/conll2003_chars.txt
cp $TextDir/conll2003_chars.txt $TextDir/lm_chars_train.txt
cut -f 2- -d " " $TmpDir/char.train.txt >> $TextDir/lm_chars_train.txt
cut -f 2- -d " " $TmpDir/char.val.txt >> $TextDir/lm_chars_train.txt

#Build word level LM
$KenLmDir/lmplz \
  --order 3 \
  --text $TextDir/lm_words_train.txt \
  --arpa $LangDir/model_words.arpa \
  --discount_fallback

#Build character level LM
$KenLmDir/lmplz \
  --order 6 \
  --text $TextDir/lm_chars_train.txt \
  --arpa $LangDir/model_chars.arpa \
  --discount_fallback

#Build tokens.txt and lexicon.txt files for chars
cut -f 1 -d " " $TmpDir/symb.txt > $LangDir/tokens.txt
sed -r 's/(.*)/\1 \1/' $LangDir/tokens.txt > $LangDir/lexicon.txt

#Finally decoding with help of character LM
img_dirs=$(cat $WorkDir/iam/lines_dirs.txt)

nice pylaia-htr-decode-ctc \
  --common.train_path ${ModelDir} \
  --common.model_filename model \
  --common.checkpoint ${ModelDir}/experiment/epoch=277-lowest_va_cer.ckpt \
  --logging.level INFO \
  --logging.to_stderr_level INFO \
  --logging.filepath $HomeDataDir/test-crnn.log \
  --logging.overwrite True \
  --trainer.progress_bar_refresh_rate 10 \
  --data.batch_size ${BatchSize} \
  --data.color_mode RGB \
  --trainer.gpus [1] \
  --trainer.auto_select_gpus False \
  --common.monitor va_cer \
  --trainer.terminate_on_nan False \
  --decode.use_symbols True \
  --decode.separator " " \
  --decode.join_string " " \
  --decode.output_space "<space>" \
  --decode.use_language_model True \
  --decode.language_model_path $LangDir/model_chars.arpa \
  --decode.language_model_weight 1.5 \
  --decode.tokens_path $LangDir/tokens.txt \
  --decode.lexicon_path $LangDir/lexicon.txt \
  --img_dirs $img_dirs \
  ${TmpDir}/symb.txt ${TmpDir}/test.lst > ${TmpDir}/decode/with_char_lm/test.txt

#Generate word-level output
awk '{
  printf("%s ", $1);
  for (i=2;i<=NF;++i) {
    if ($i == "<space>")
      printf(" ");
    else
      printf("%s", $i);
  }
  printf("\n");
}' ${TmpDir}/decode/with_char_lm/test.txt > ${TmpDir}/decode/with_char_lm/wordtest.txt;

mkdir $TmpDir/decode/with_char_lm/bio_labels
rm $TmpDir/decode/with_char_lm/bio_labels/*
python $ScriptsDir/parser_continuous_to_bio.py \
${TmpDir}/decode/with_char_lm/wordtest.txt ${TmpDir}/decode/with_char_lm/bio_labels/

#Evaluation
echo "\n\nWith 6-gram character LM" >> $HomeDataDir/results_synthetic_0.txt

ie-eval all --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/with_char_lm/bio_labels/ \
>> ${HomeDataDir}/results_synthetic_0.txt

ie-eval nerval --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/with_char_lm/bio_labels/ \
>> ${HomeDataDir}/results_synthetic_0.txt

#Evaluate CER and WER to see quality of transcriptions without tags
#Process output (wordtest.txt) to remove the tags
sed 's/<C>//g' $TmpDir/decode/with_char_lm/wordtest.txt > $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<G>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<L>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<N>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<P>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<T>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt

#Computation of CER and WER
python $ScriptsDir/compute-cer_wer.py \
$TmpDir/test_no_tags.txt \
$TmpDir/decode/with_char_lm/wordtest_no_tags.txt >> $HomeDataDir/results_synthetic_0.txt
cat $HomeDataDir/results_synthetic_0.txt