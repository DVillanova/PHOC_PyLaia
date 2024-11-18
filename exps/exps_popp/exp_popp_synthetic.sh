# set -e

export LC_NUMERIC=C.UTF-8;

conda activate exps_synthetic
#Variables, parameters and routes for Docker
GPU=0
BatchSize=4
WorkDir=/home/dvillanova/expsKronos/dvillano/
ScriptsDir=${WorkDir}/scripts/
HomeDataDir=/home/dvillanova/expsKronos/data/popp/

DataDir=$HomeDataDir/data/
TextDir=${HomeDataDir}/baseline_TEXT
PartDir=${HomeDataDir}/PARTITIONS/
LangDir=${HomeDataDir}/baseline_lang
CharDir=${LangDir}/char
ModelDir=${HomeDataDir}/baseline_model
TmpDir=${HomeDataDir}/baseline_TMP
NerDir=${HomeDataDir}/NER
NerNoRepDir=${HomeDataDir}/NER-NoRep
ConllModelDir=${HomeDataDir}/../conll2003/BASELINE_SYNTHETIC_model


KenLmDir=${WorkDir}/kenlm/build/bin/

img_dirs="[${DataDir}/Lines/test/,${DataDir}/Lines/train/,${DataDir}/Lines/val/]"

########################################################################################

#Save copy in original_experiment
mkdir $ModelDir/experiment/
rm $ModelDir/experiment/*
cp $ConllModelDir/model $ModelDir/

mkdir $ModelDir/original_experiment/
rm $ModelDir/original_experiment/*
mkdir $ModelDir/modified_monitor/
rm $ModelDir/modified_monitor/*
cp $ConllModelDir/experiment/epoch=*-lowest_va_ecer.ckpt \
$ModelDir/original_experiment/

ExpName=$(ls $ModelDir/original_experiment/)

#Modify the monitors to reset the values to 100.0 in all callbacks
python $ScriptsDir/reset_checkpoint_monitors.py \
$ModelDir/original_experiment/$ExpName

#Copy the new checkpoint to model
cp $ModelDir/modified_monitor/$ExpName $ModelDir/experiment/

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
--trainer.gpus [$GPU] \
--trainer.auto_select_gpus False \
--common.monitor va_cer \
--train.checkpoint_k 1 \
--trainer.terminate_on_nan False \
--train.resume 999 \
$HomeDataDir/../conll2003/synthetic_lines/all/symb.txt $img_dirs \
${TmpDir}/char.train.txt \
${TmpDir}/char.val.txt
#
#syms img_dirs [img_dirs...] tr_txt_table va_txt_table

mkdir ${TmpDir}/decode
cd ${TmpDir}/decode 

#Decodification Test and for WER
#CER (SPACE = "<SPACE>", JOIN_STR = " ")
#Decoding at char level => Model has to be chosen manually (for now)
nice pylaia-htr-decode-ctc \
  --common.train_path ${ModelDir} \
  --common.model_filename model \
  --common.checkpoint ${ModelDir}/experiment/epoch=351-lowest_va_ecer.ckpt \
  --logging.level INFO \
  --logging.to_stderr_level INFO \
  --logging.filepath $HomeDataDir/test-crnn.log \
  --logging.overwrite True \
  --trainer.progress_bar_refresh_rate 10 \
  --data.batch_size ${BatchSize} \
  --data.color_mode RGB \
  --trainer.gpus [$GPU] \
  --trainer.auto_select_gpus False \
  --common.monitor va_cer \
  --trainer.terminate_on_nan False \
  --decode.use_symbols True \
  --decode.separator " " \
  --decode.join_string " " \
  --decode.output_space "<space>" \
  --img_dirs $img_dirs \
  $HomeDataDir/../conll2003/synthetic_lines/all/symb.txt ${TmpDir}/test.lst > ${TmpDir}/decode/test.txt

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

sed 's/ <stroke>//g' $TmpDir/decode/test.txt > $TmpDir/decode/k
cp $TmpDir/decode/test.txt $TmpDir/decode/original_test.txt
mv $TmpDir/decode/k $TmpDir/decode/test.txt

gawk '{
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
rm -r $TmpDir/bio_labels
mkdir $TmpDir/bio_labels
python $ScriptsDir/parser_continuous_to_bio.py \
${TmpDir}/test.txt $TmpDir/bio_labels/

#python $ScriptsDir/parser_continuous_to_bio.py ${TmpDir}/train.txt $TmpDir/bio_labels_train/
#python $ScriptsDir/parser_continuous_to_bio.py ${TmpDir}/val.txt $TmpDir/bio_labels_val/

#BIO format output
rm -r $TmpDir/decode/bio_labels
mkdir $TmpDir/decode/bio_labels
python $ScriptsDir/parser_continuous_to_bio.py \
${TmpDir}/decode/wordtest.txt ${TmpDir}/decode/bio_labels/

#Compute evaluation metrics and send to $HomeDataDir/results_baseline.txt
ie-eval all --label-dir ${TmpDir}/bio_labels/ --prediction-dir ${TmpDir}/decode/bio_labels/ > ${HomeDataDir}/results_synthetic.txt

ie-eval nerval --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/bio_labels/ \
>> ${HomeDataDir}/results_synthetic.txt

cat $HomeDataDir/results_synthetic.txt

#Evaluate CER and WER to see quality of transcriptions without tags
#Process output (wordtest.txt) to remove the tags
sed 's/<[^>]*>//g' $TmpDir/decode/wordtest.txt > $TmpDir/decode/wordtest_no_tags.txt

#Remove line IDs from file
# cut -f 2- -d " " $TmpDir/decode/wordtest_no_tags.txt > $TmpDir/decode/wordtest_no_tags_no_lineids.txt

#Process GT file to remove the tags
sed 's/<[^>]*>//g' $TmpDir/test.txt > $TmpDir/test_no_tags.txt

#Remove line IDs from file
# cut -f 2- -d " " $TmpDir/test_no_tags.txt > $TmpDir/test_no_tags_no_lineids.txt

#Computation of CER and WER
python $ScriptsDir/compute-cer_wer.py $TmpDir/test_no_tags.txt $TmpDir/decode/wordtest_no_tags.txt >> $HomeDataDir/results_synthetic.txt
cat $HomeDataDir/results_synthetic.txt



#####################################
# INCLUDING EXTERNAL LANGUAGE MODEL #
#####################################
#Merge train and valid into a single chars file
cut -f 2- -d " " $TmpDir/char.train.txt > $TextDir/lm_chars_train.txt
cut -f 2- -d " " $TmpDir/char.val.txt >> $TextDir/lm_chars_train.txt

#Build character level LM
$KenLmDir/lmplz \
  --order 6 \
  --text $TextDir/lm_chars_train.txt \
  --arpa $LangDir/model_chars.arpa \
  --discount_fallback

#Build tokens.txt and lexicon.txt files for chars
cut -f 1 -d " " $HomeDataDir/../conll2003/synthetic_lines/all/symb.txt > $LangDir/tokens.txt
sed -r 's/(.*)/\1 \1/' $LangDir/tokens.txt > $LangDir/lexicon.txt

mkdir $TmpDir/decode/with_char_lm/

nice pylaia-htr-decode-ctc \
  --common.train_path ${ModelDir} \
  --common.model_filename model \
  --common.checkpoint ${ModelDir}/experiment/epoch=351-lowest_va_ecer.ckpt \
  --logging.level INFO \
  --logging.to_stderr_level INFO \
  --logging.filepath $HomeDataDir/test-crnn.log \
  --logging.overwrite True \
  --trainer.progress_bar_refresh_rate 10 \
  --data.batch_size $BatchSize \
  --data.color_mode RGB \
  --trainer.gpus [$GPU] \
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
  $HomeDataDir/../conll2003/synthetic_lines/all/symb.txt ${TmpDir}/test.lst > ${TmpDir}/decode/with_char_lm/test.txt

#Generate word-level output
gawk '{
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
echo "\n\nWith 6-gram character LM" >> $HomeDataDir/results_synthetic.txt

ie-eval all --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/with_char_lm/bio_labels/ \
>> ${HomeDataDir}/results_synthetic.txt

ie-eval nerval --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/with_char_lm/bio_labels/ \
>> ${HomeDataDir}/results_synthetic.txt

#Evaluate CER and WER to see quality of transcriptions without tags
#Process output (wordtest.txt) to remove the tags
sed 's/<[^>]*>//g' $TmpDir/decode/with_char_lm/wordtest.txt > $TmpDir/decode/with_char_lm/wordtest_no_tags.txt

#Computation of CER and WER
python $ScriptsDir/compute-cer_wer.py \
$TmpDir/test_no_tags.txt \
$TmpDir/decode/with_char_lm/wordtest_no_tags.txt >> $HomeDataDir/results_synthetic.txt
cat $HomeDataDir/results_synthetic.txt