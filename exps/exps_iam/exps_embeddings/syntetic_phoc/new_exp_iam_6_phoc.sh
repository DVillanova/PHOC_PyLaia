# set -e

export LC_NUMERIC=C.UTF-8;

conda activate exps_embeddings

#Variables, parameters and routes for Docker
BatchSize=4
GPU=1
WorkDir=/home/dvillanova/expsKronos/dvillano/
ScriptsDir=${WorkDir}/scripts/
HomeDataDir=/home/dvillanova/expsKronos/data/iam/
PartDir=${HomeDataDir}/PARTITIONS/
DataDir=$HomeDataDir/DATA
ConllModelDir=${HomeDataDir}/../conll2003/PHOC_SYNTHETIC_model

TextDir=${HomeDataDir}/6_PHOC_TEXT
LangDir=${HomeDataDir}/6_PHOC_TEXT
CharDir=${LangDir}/char
ModelDir=${HomeDataDir}/6_PHOC_model
TmpDir=${HomeDataDir}/6_PHOC_TMP
NerDir=${HomeDataDir}/NER
NerNoRepDir=${HomeDataDir}/NER-NoRep
KenLmDir=${WorkDir}/kenlm/build/bin/

#img_dirs=$(find ${DataDir}/lines -mindepth 2 -maxdepth 2 -type d)+
img_dirs=$(cat $WorkDir/exps/iam_lines_dirs.txt)

##################################################################################################################################################################################
cd $WorkDir
rm -rf ${TextDir}
mkdir ${TextDir}
cd $TextDir

#Generation of GT with continuous tagging w.o. reject class
python $ScriptsDir/IAM_generate_tagged_line_transcription.py 3 \
       $HomeDataDir/ne_annotations/iam_all_custom_6_all.txt $DataDir/ascii/lines.txt \
       $TextDir/index.words

# Create data dir
cd ${WorkDir}
rm -rf ${CharDir}
mkdir -p ${CharDir}
cd ${CharDir}

cat ${TextDir}/index.words | gawk '{
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

#Extract vocabulary and number of symbols in vocabulary
cat char.total.txt | cut -f 2- -d\  | tr \  \\n| sort -u -V | gawk 'BEGIN{   N=0;   printf("%-12s %d\n", "<eps>", N++);   printf("%-12s %d\n", "<ctc>", N++);  }NF==1{  printf("%-12s %d\n", $1, N++);}' >  symb.txt
# NSYMBOLS=$(sed -n '${ s|.* ||; p; }' "symb.txt");


#Generate partition files
# mkdir $PartDir
# cd ${PartDir}

# python $ScriptsDir/IAM_generate_part_files.py $HomeDataDir/ne_annotations/iam_train_custom_6_all.txt $TextDir/index.words $PartDir/train.lst
# python $ScriptsDir/IAM_generate_part_files.py $HomeDataDir/ne_annotations/iam_test_custom_6_all.txt $TextDir/index.words $PartDir/test.lst
# python $ScriptsDir/IAM_generate_part_files.py $HomeDataDir/ne_annotations/iam_valid_custom_6_all.txt $TextDir/index.words $PartDir/val.lst


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

# CREATION CHAR.TRAIN CHAR.VAL CHAR.TEST
for f in $(<./train.lst); do grep "${f}\b" ${TextDir}/index.words; done |
gawk '{
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

for f in $(<./val.lst); do grep "${f}\b" ${TextDir}/index.words; done |
gawk '{
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

for f in $(<./test.lst); do grep "${f}\b" ${TextDir}/index.words; done |
gawk '{
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

#Save copy in original_experiment+
mkdir $ModelDir
mkdir $ModelDir/experiment/
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



#Optical model training ON IAM
img_dirs=$(cat $WorkDir/exps/iam_lines_dirs.txt)

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

#Decodification Test and Val for Wer
#CER (SPACE = "<SPACE>", JOIN_STR = " ")

#Decoding at char level => Model has to be chosen manually (for now)
nice pylaia-htr-decode-ctc \
  --common.train_path ${ModelDir} \
  --common.model_filename model \
  --common.checkpoint ${ModelDir}/experiment/epoch=282-lowest_va_ecer.ckpt \
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
ie-eval all --label-dir ${TmpDir}/bio_labels/ --prediction-dir ${TmpDir}/decode/bio_labels/ > ${HomeDataDir}/results_phoc_6.txt

ie-eval nerval --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/bio_labels/ \
>> ${HomeDataDir}/results_phoc_6.txt

cat $HomeDataDir/results_phoc_6.txt

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
python $ScriptsDir/compute-cer_wer.py $TmpDir/test_no_tags.txt $TmpDir/decode/wordtest_no_tags.txt >> $HomeDataDir/results_phoc_6.txt
cat $HomeDataDir/results_phoc_6.txt



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
  --common.checkpoint ${ModelDir}/experiment/epoch=282-lowest_va_ecer.ckpt \
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
echo "\n\nWith 6-gram character LM" >> $HomeDataDir/results_phoc_6.txt

ie-eval all --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/with_char_lm/bio_labels/ \
>> ${HomeDataDir}/results_phoc_6.txt

ie-eval nerval --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/with_char_lm/bio_labels/ \
>> ${HomeDataDir}/results_phoc_6.txt

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
$TmpDir/decode/with_char_lm/wordtest_no_tags.txt >> $HomeDataDir/results_phoc_6.txt
cat $HomeDataDir/results_phoc_6.txt