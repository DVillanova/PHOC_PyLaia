# set -e

export LC_NUMERIC=C.UTF-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

conda activate exps_embeddings
#Variables, parameters and routes for Docker
GPU=0
BatchSize=4
WorkDir=/home/dvillanova/expsKronos/dvillano/
ScriptsDir=${WorkDir}/scripts/
HomeDataDir=/home/dvillanova/expsKronos/data/popp/
ConllModelDir=${HomeDataDir}/../conll2003/PHOC_SYNTHETIC_model
DataDir=$HomeDataDir/data/
TextDir=${HomeDataDir}/SCRATCH_PHOC_TEXT
PartDir=${HomeDataDir}/PARTITIONS/
LangDir=${HomeDataDir}/SCRATCH_PHOC_lang
CharDir=${LangDir}/char
ModelDir=${HomeDataDir}/SCRATCH_PHOC_model
TmpDir=${HomeDataDir}/SCRATCH_PHOC_TMP
NerDir=${HomeDataDir}/NER
NerNoRepDir=${HomeDataDir}/NER-NoRep

KenLmDir=${WorkDir}/kenlm/build/bin/

#img_dirs=$(find ${DataDir}/lines -mindepth 2 -maxdepth 2 -type d)+
img_dirs="[${DataDir}/Lines/test/,${DataDir}/Lines/train/,${DataDir}/Lines/val/]"


##################################################################################################################################################################################

#Generate partition files
cd $DataDir
mkdir $PartDir
cut -f 3 -d "/" $DataDir/train_ids.txt | cut -f 1 -d "." > $PartDir/train.lst
cut -f 3 -d "/" $DataDir/test_ids.txt | cut -f 1 -d "." > $PartDir/test.lst
cut -f 3 -d "/" $DataDir/val_ids.txt | cut -f 1 -d "." > $PartDir/val.lst

rm -rf ${TextDir}
mkdir ${TextDir}
#To generate index.words we have to remove Lines/test/  .png from line ids => awk
cut -f 3- -d "/" $DataDir/test_text.txt | sed "s/.png//g" > $DataDir/formatted_test_text.txt
cut -f 3- -d "/" $DataDir/test.txt | sed "s/.png//g" > $DataDir/formatted_test.txt
cut -f 3- -d "/" $DataDir/train_text.txt | sed "s/.png//g" > $DataDir/formatted_train_text.txt
cut -f 3- -d "/" $DataDir/train.txt | sed "s/.png//g" > $DataDir/formatted_train.txt
cut -f 3- -d "/" $DataDir/val_text.txt | sed "s/.png//g" > $DataDir/formatted_val_text.txt
cut -f 3- -d "/" $DataDir/val.txt | sed "s/.png//g" > $DataDir/formatted_val.txt

#Parse text to continuous notation (a tag for each word) just for evaluation
python $ScriptsDir/parse_popp_data.py $DataDir/formatted_test.txt $DataDir/formatted_parsed_test.txt
python $ScriptsDir/parse_popp_data.py $DataDir/formatted_train.txt $DataDir/formatted_parsed_train.txt
python $ScriptsDir/parse_popp_data.py $DataDir/formatted_val.txt $DataDir/formatted_parsed_val.txt

gawk '{
  printf("%s ", $1);
  for (i=2;i<=NF;++i) {
    if ($i == "<space>")
      printf(" ");
    else
      printf("%s", $i);
  }
  printf("\n");
}' $DataDir/formatted_parsed_train.txt > $DataDir/formatted_parsed_train_text.txt;

gawk '{
  printf("%s ", $1);
  for (i=2;i<=NF;++i) {
    if ($i == "<space>")
      printf(" ");
    else
      printf("%s", $i);
  }
  printf("\n");
}' $DataDir/formatted_parsed_test.txt > $DataDir/formatted_parsed_test_text.txt;

gawk '{
  printf("%s ", $1);
  for (i=2;i<=NF;++i) {
    if ($i == "<space>")
      printf(" ");
    else
      printf("%s", $i);
  }
  printf("\n");
}' $DataDir/formatted_parsed_val.txt > $DataDir/formatted_parsed_val_text.txt;

cat $DataDir/formatted_parsed_test_text.txt > $TextDir/index.words
cat $DataDir/formatted_parsed_train_text.txt >> $TextDir/index.words
cat $DataDir/formatted_parsed_val_text.txt >> $TextDir/index.words

sed 's/</ </g' $TextDir/index.words > $TextDir/index.words_with_space

# Create char dir
cd ${WorkDir}
rm -rf ${CharDir}
mkdir -p ${CharDir}
cd ${CharDir}

cat ${TextDir}/index.words_with_space | gawk '{
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
        if(NF==1) {
          printf(" \n");
        } else {
          printf("\n");
        }
        
}' | sed 's/#/<stroke>/g' > char.total.txt

#Extract vocabulary and number of symbols in vocabulary
cat char.total.txt | cut -f 2- -d\  | tr \  \\n| sort -u -V | gawk 'BEGIN{   N=0;   printf("%-12s %d\n", "<eps>", N++);   printf("%-12s %d\n", "<ctc>", N++);  }NF==1{  printf("%-12s %d\n", $1, N++);}' >  symb.txt
# NSYMBOLS=$(sed -n '${ s|.* ||; p; }' "symb.txt");


#COPY .TXT FILES WITH LINE ID AND TRANSCRIPTION
rm -rf ${TmpDir}
mkdir ${TmpDir}
cd ${TmpDir}

cp ${PartDir}/test.lst ./test.lst
cp ${PartDir}/train.lst ./train.lst
cp ${PartDir}/val.lst ./val.lst

cp $DataDir/formatted_parsed_test_text.txt $TmpDir/test.txt
cp $DataDir/formatted_parsed_train_text.txt $TmpDir/train.txt
cp $DataDir/formatted_parsed_val_text.txt $TmpDir/val.txt

# CREATION CHAR.TRAIN CHAR.VAL CHAR.TEST
cp $DataDir/formatted_parsed_test.txt $TmpDir/char.test.txt
cp $DataDir/formatted_parsed_train.txt $TmpDir/char.train.txt
cp $DataDir/formatted_parsed_val.txt $TmpDir/char.val.txt

#Get symb.txt in an alternate way (without <eps> symbol)
for p in train test val; do cat char.${p}.txt | cut -f 2- -d " "  |
tr \  \\n; done | sort -u -V | gawk 'BEGIN{
  N=0;
  printf("%-12s %d\n", "<ctc>", N++);
}NF==1{
  printf("%-12s %d\n", $1, N++);
}' >  symb.txt

#symb.txt from CONLL2003 and IAM (without <eps> symbol)
cp $HomeDataDir/../conll2003/synthetic_lines/all/symb.txt $TmpDir/symb.txt

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
  ${TmpDir}/symb.txt

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
--trainer.check_val_every_n_epoch 10 \
--train.augment_training True \
--train.early_stopping_patience 50 \
--data.color_mode RGB \
--train.delimiters ["<space>"] \
--trainer.gpus [$GPU] \
--trainer.auto_select_gpus False \
--common.monitor va_cer \
--train.checkpoint_k 1 \
--trainer.terminate_on_nan False \
$HomeDataDir/../conll2003/synthetic_lines/all/symb.txt $img_dirs \
${TmpDir}/char.train.txt \
${TmpDir}/char.val.txt


mkdir ${TmpDir}/decode
cd ${TmpDir}/decode 

#Decodification Test and Val for Wer
#CER (SPACE = "<SPACE>", JOIN_STR = " ")

#Decoding at char level => Model has to be chosen manually (for now)
nice pylaia-htr-decode-ctc \
  --common.train_path ${ModelDir} \
  --common.model_filename model \
  --common.checkpoint ${ModelDir}/experiment/epoch=759-lowest_va_ecer.ckpt \
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

  
sed 's/ <stroke>//g' $TmpDir/decode/test.txt > $TmpDir/decode/k
cp $TmpDir/decode/test.txt $TmpDir/decode/original_test.txt
mv $TmpDir/decode/k $TmpDir/decode/test.txt


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
ie-eval all --label-dir ${TmpDir}/bio_labels/ --prediction-dir ${TmpDir}/decode/bio_labels/ > ${HomeDataDir}/results_phoc_scratch.txt

ie-eval nerval --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/bio_labels/ \
>> ${HomeDataDir}/results_phoc_scratch.txt

cat $HomeDataDir/results_phoc_scratch.txt


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
python $ScriptsDir/compute-cer_wer.py $TmpDir/test_no_tags.txt $TmpDir/decode/wordtest_no_tags.txt >> $HomeDataDir/results_phoc_scratch.txt
cat $HomeDataDir/results_phoc_scratch.txt


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
  --common.checkpoint ${ModelDir}/experiment/epoch=759-lowest_va_ecer.ckpt \
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

sed 's/ <stroke>//g' $TmpDir/decode/with_char_lm/test.txt > $TmpDir/decode/with_char_lm/k
cp $TmpDir/decode/with_char_lm/test.txt $TmpDir/decode/with_char_lm/original_test.txt
mv $TmpDir/decode/with_char_lm/k $TmpDir/decode/with_char_lm/test.txt


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
echo "\n\nWith 6-gram character LM" >> $HomeDataDir/results_phoc_scratch.txt

ie-eval all --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/with_char_lm/bio_labels/ \
>> ${HomeDataDir}/results_phoc_scratch.txt

ie-eval nerval --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/with_char_lm/bio_labels/ \
>> ${HomeDataDir}/results_phoc_scratch.txt

#Evaluate CER and WER to see quality of transcriptions without tags
#Process output (wordtest.txt) to remove the tags
sed 's/<[^>]*>//g' $TmpDir/decode/with_char_lm/wordtest.txt > $TmpDir/decode/with_char_lm/wordtest_no_tags.txt

#Computation of CER and WER
python $ScriptsDir/compute-cer_wer.py \
$TmpDir/test_no_tags.txt \
$TmpDir/decode/with_char_lm/wordtest_no_tags.txt >> $HomeDataDir/results_phoc_scratch.txt
cat $HomeDataDir/results_phoc_scratch.txt