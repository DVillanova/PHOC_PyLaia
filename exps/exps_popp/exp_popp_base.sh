# set -e

export LC_NUMERIC=C.UTF-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8


# conda activate exps_embeddings
conda activate exps_benchmark
#Variables, parameters and routes for Docker
GPU=1
BatchSize=8
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


#Optical model training.
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
  --train.checkpoint_k 3 \
  --trainer.terminate_on_nan False \
  ${TmpDir}/symb.txt $img_dirs ${TmpDir}/char.train.txt \
  ${TmpDir}/char.val.txt
#--train.resume True \
#syms img_dirs [img_dirs...] tr_txt_table va_txt_table

mkdir ${TmpDir}/decode
cd ${TmpDir}/decode 

#Decodification Test and Val for Wer
#CER (SPACE = "<SPACE>", JOIN_STR = " ")

#Decoding at char level
nice pylaia-htr-decode-ctc \
  --common.train_path ${ModelDir} \
  --common.model_filename model \
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
  ${TmpDir}/symb.txt ${TmpDir}/test.lst > ${TmpDir}/decode/test.txt

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
mkdir $TmpDir/bio_labels
rm $TmpDir/bio_labels/*
python $ScriptsDir/parser_continuous_to_bio.py \
${TmpDir}/test.txt $TmpDir/bio_labels/

#BIO format output
mkdir $TmpDir/decode/bio_labels
rm $TmpDir/decode/bio_labels/*
python $ScriptsDir/parser_continuous_to_bio.py \
${TmpDir}/decode/wordtest.txt ${TmpDir}/decode/bio_labels/

#Compute evaluation metrics and send to $HomeDataDir/results_baseline.txt
ie-eval all --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/bio_labels/ \
> ${HomeDataDir}/results_baseline.txt

ie-eval nerval --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/bio_labels/ \
>> ${HomeDataDir}/results_baseline.txt

#Evaluate CER and WER to see quality of transcriptions without tags
#Process output (wordtest.txt) to remove the tags
sed 's/<B>//g' $TmpDir/decode/wordtest.txt > $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<C>//g' $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<E>//g' $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<F>//g' $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<K>//g' $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<L>//g' $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<N>//g' $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<O>//g' $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<P>//g' $TmpDir/decode/wordtest_no_tags.txt
sed -i 's/<S>//g' $TmpDir/decode/wordtest_no_tags.txt


#Remove line IDs from file
# cut -f 2- -d " " $TmpDir/decode/wordtest_no_tags.txt > $TmpDir/decode/wordtest_no_tags_no_lineids.txt

#Process GT file to remove the tags
sed 's/<B>//g' $TmpDir/test.txt > $TmpDir/test_no_tags.txt
sed -i 's/<C>//g' $TmpDir/test_no_tags.txt
sed -i 's/<E>//g' $TmpDir/test_no_tags.txt
sed -i 's/<F>//g' $TmpDir/test_no_tags.txt
sed -i 's/<K>//g' $TmpDir/test_no_tags.txt
sed -i 's/<L>//g' $TmpDir/test_no_tags.txt
sed -i 's/<N>//g' $TmpDir/test_no_tags.txt
sed -i 's/<O>//g' $TmpDir/test_no_tags.txt
sed -i 's/<P>//g' $TmpDir/test_no_tags.txt
sed -i 's/<S>//g' $TmpDir/test_no_tags.txt

#Remove line IDs from file
# cut -f 2- -d " " $TmpDir/test_no_tags.txt > $TmpDir/test_no_tags_no_lineids.txt

#Computation of CER and WER
python $ScriptsDir/compute-cer_wer.py $TmpDir/test_no_tags.txt $TmpDir/decode/wordtest_no_tags.txt >> $HomeDataDir/results_baseline.txt
cat $HomeDataDir/results_baseline.txt

#####################################
# INCLUDING EXTERNAL LANGUAGE MODEL #
#####################################
#Merge train and validation into a single file
cut -f 2- -d " " $TmpDir/char.train.txt > $TextDir/lm_chars_train.txt
cut -f 2- -d " " $TmpDir/char.val.txt >> $TextDir/lm_chars_train.txt

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
mkdir $TmpDir/decode/with_char_lm/
rm $TmpDir/decode/with_char_lm/*

nice pylaia-htr-decode-ctc \
  --common.train_path ${ModelDir} \
  --common.model_filename model \
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
echo "\n\nWith 6-gram character LM" >> $HomeDataDir/results_baseline.txt

ie-eval all --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/with_char_lm/bio_labels/ \
>> ${HomeDataDir}/results_baseline.txt

ie-eval nerval --label-dir ${TmpDir}/bio_labels/ \
--prediction-dir ${TmpDir}/decode/with_char_lm/bio_labels/ \
>> ${HomeDataDir}/results_baseline.txt

#Evaluate CER and WER to see quality of transcriptions without tags
#Process output (wordtest.txt) to remove the tags
sed 's/<B>//g' $TmpDir/decode/with_char_lm/wordtest.txt > $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<C>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<E>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<F>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<K>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<L>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<N>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<O>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<P>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt
sed -i 's/<S>//g' $TmpDir/decode/with_char_lm/wordtest_no_tags.txt

#Computation of CER and WER
python $ScriptsDir/compute-cer_wer.py \
$TmpDir/test_no_tags.txt \
$TmpDir/decode/with_char_lm/wordtest_no_tags.txt >> $HomeDataDir/results_baseline.txt
cat $HomeDataDir/results_baseline.txt









































######################################
# REST OF THE SCRIPT FOR REFERENCE   #
# (DO NOT EXECUTE THE NEXT COMMANDS) #
# TODO: REMOVE IN FINAL VERSION      #
######################################


######################################################################################################
## NER GT

cd ${WorkDir}

mkdir ${NerDir}
cd ${NerDir}
$ScriptsDir/extractNER-GT_GW.sh ${TextDir}/index.words 

cd -
mkdir ${NerNoRepDir}
cd ${NerNoRepDir}
$ScriptsDir/extractNER-GT-noRep.sh ${TextDir}/index.words


########################################################################################################################
################# Language Model #######################################################################################
########################################################################################################################

# Force alignment

# Obtaining confMats
cd ${TmpDir}/decode

pylaia-htr-netout-rgb \
 --show_progress_bar True \
 --print_args True \
 --train_path ${ModelDir} \
 --model_filename model \
 --logging_level info \
 --logging_also_to_stderr info \
 --logging_file CMs-crnn.log  \
 --batch_size ${BatchSize} \
 --output_transform log_softmax \
 --output_matrix confMats_ark-test.txt \
 $img_dirs ${TmpDir}/test.lst

pylaia-htr-netout-rgb \
 --show_progress_bar True \
 --print_args True \
 --train_path ${ModelDir} \
 --model_filename model \
 --logging_level info \
 --logging_also_to_stderr info \
 --logging_file CMs-crnn.log  \
 --batch_size ${BatchSize} \
 --output_transform log_softmax \
 --output_matrix confMats_ark-validation.txt \
 $img_dirs ${TmpDir}/val.lst

gawk '{print $1}' ${TmpDir}/symb.txt > ${TmpDir}/decode/chars.lst


#Processing development feature samples into Kaldi format
########################Y###################################################################################
mkdir -p $TmpDir/decode/test

copy-matrix "ark,t:confMats_ark-validation.txt" "ark,scp:test/confMats_alp0.3-validation.ark,test/confMats_alp0.3-validation.scp"
copy-matrix "ark,t:confMats_ark-test.txt" "ark,scp:test/confMats_alp0.3-test.ark,test/confMats_alp0.3-test.scp"

# Prepare Kaldi's lang directories
############################################################################################################
# Preparing Lexic (L)
cd ${LangDir}
mkdir lm

cp $TmpDir/decode/chars.lst ./chars.lst
#awk 'NR>1{print $1}' ./char/symb.txt > chars.lst



BLANK_SYMB="<ctc>"                        # BLSTM non-character symbol
WHITESPACE_SYMB="<space>"                 # White space symbol
DUMMY_CHAR="<DUMMY>"                      # Especial HMM used for modelling "</s>" end-sentence

$ScriptsDir/prepare_lang_cl-ds.sh lm ./chars.lst "${BLANK_SYMB}" "${WHITESPACE_SYMB}" "${DUMMY_CHAR}"

cd lm/

# Preparing LM (G)

for f in $(<${PartDir}/train.lst); do
 nn=`basename ${f/.png/}`; grep $nn ../char/char.total.txt;
done | cut -d " " -f 2- | ngram-count -vocab ../chars.lst -text - -lm lang/LM.arpa -order 8 -wbdiscount1 -kndiscount -interpolate

#The generated grammar is probabilistic but probabilities do not add 1 (scores are used)
$ScriptsDir/prepare_lang_test-ds.sh lang/LM.arpa lang lang_test "$DUMMY_CHAR"

# python $ScriptsDir/generate_categorical_sfsa_gw.py $LangDir/lm/lang/phones.txt $WorkDir/CAT_FST/Categorical.fst
# $ScriptsDir/prepare_lang_test_categorical.sh $WorkDir/CAT_FST/Categorical.fst lang lang_test "$DUMMY_CHAR"


##########################################################################################################
# Prepare HMM models
##########################################################################################################
# Create HMM topology file
cd $ModelDir
mkdir -p HMMs/train
ln -s $TmpDir/decode/test/ .

phones_list=( $(cat ${LangDir}/lm/lang_test/phones/{,non}silence.int) )
featdim=$(feat-to-dim scp:test/confMats_alp0.3-test.scp - 2>/dev/null)
dummyID=$(gawk -v d="$DUMMY_CHAR" '{if (d==$1) print $2}' ${LangDir}/lm/lang/phones.txt)
blankID=$(gawk -v bs="${BLANK_SYMB}" '{if (bs==$1) print $2}' ${LangDir}/lm/lang/pdf_blank.txt)

HMM_LOOP_PROB=0.5                         # Self-Loop HMM-state probability
HMM_NAC_PROB=0.5                          # BLSTM-NaC HMM-state probability

$ScriptsDir/create_proto_rnn-ds.sh $featdim ${HMM_LOOP_PROB} ${HMM_NAC_PROB} HMMs/train ${dummyID} ${blankID} ${phones_list[@]}





# Compose FSTs
############################################################################################################

mkdir HMMs/test
$ScriptsDir/mkgraph.sh --mono --transition-scale 1.0 --self-loop-scale 1.0 $LangDir/lm/lang_test HMMs/train/new.mdl HMMs/train/new.tree HMMs/test/graph

############################################################################################################



# Lattice Generation
############################################################################################################
cd $TmpDir/decode
mkdir lattices

ASF=0.818485839158                        # Acoustic Scale Factor
MAX_NUM_ACT_STATES=2007483647             # Maximum number of active states
BEAM_SEARCH=15                            # Beam search
LATTICE_BEAM=12                           # Lattice generation beam
N_CORES=1     

latgen-faster-mapped --verbose=2 --allow-partial=true --acoustic-scale=${ASF} --max-active=${MAX_NUM_ACT_STATES} --beam=${BEAM_SEARCH} --lattice-beam=${LATTICE_BEAM} --max-mem=4194304 $ModelDir/HMMs/train/new.mdl $ModelDir/HMMs/test/graph/HCLG.fst scp:test/confMats_alp0.3-test.scp "ark:|gzip -c > lattices/lat-test.gz" ark,t:lattices/RES-test 2>lattices/LOG-Lats-test
latgen-faster-mapped --verbose=2 --allow-partial=true --acoustic-scale=${ASF} --max-active=${MAX_NUM_ACT_STATES} --beam=${BEAM_SEARCH} --lattice-beam=${LATTICE_BEAM} --max-mem=4194304 $ModelDir/HMMs/train/new.mdl $ModelDir/HMMs/test/graph/HCLG.fst scp:test/confMats_alp0.3-validation.scp "ark:|gzip -c > lattices/lat-validation.gz" ark,t:lattices/RES-validation 2>lattices/LOG-Lats-validation


# Final Evaluation
###########################################################################################################
ASF=1.39176532 
WIP=-1.16902908

cd lattices

$ScriptsDir/score.sh --wip $WIP --lmw $ASF $ModelDir/HMMs/test/graph/words.txt "ark:gzip -c -d lat-test.gz |" $LangDir/char/char.total.txt hypotheses-test 2>log
$ScriptsDir/score.sh --wip $WIP --lmw $ASF $ModelDir/HMMs/test/graph/words.txt "ark:gzip -c -d lat-validation.gz |" $LangDir/char/char.total.txt hypotheses-validation 2>log


simplex.py -v -m "${ScriptsDir}/opt_gsf-wip_cl.sh {$ASF} {$WIP}" > result-simplex

ASF=1.27216049 
WIP=-0.76260881

$ScriptsDir/score.sh --wip $WIP --lmw $ASF $ModelDir/HMMs/test/graph/words.txt "ark:gzip -c -d lat-test.gz |" $LangDir/char/char.total.txt hypotheses-test 2>log


# Pass the category language model and generate output
# lattice-lmrescore --lm-scale=1.0 "ark:gzip -c -d lat-test.gz |" ${LangDir}/lm/lang_test/G_cat.fst "ark:|gzip -c > rescored_lat-test.gz"
# lattice-lmrescore --lm-scale=1.0 "ark:gzip -c -d lat-validation.gz |" ${LangDir}/lm/lang_test/G_cat.fst "ark:|gzip -c > rescored_lat-validation.gz"
# $ScriptsDir/score.sh --wip $WIP --lmw $ASF $ModelDir/HMMs/test/graph/words.txt "ark:gzip -c -d rescored_lat-test.gz |" $LangDir/char/char.total.txt rescored_hypotheses-test 2>log
# $ScriptsDir/score.sh --wip $WIP --lmw $ASF $ModelDir/HMMs/test/graph/words.txt "ark:gzip -c -d rescored_lat-validation.gz |" $LangDir/char/char.total.txt rescored_hypotheses-validation 2>log

#Rescoring Latice -> Pass language model -> generate output (somewhat worse results)
# lattice-scale --acoustic-scale=${ASF} "ark:gzip -c -d lat-test.gz |" ark:- | \
# lattice-add-penalty --word-ins-penalty=${WIP} ark:- ark:- | \
# lattice-lmrescore --lm-scale=1.0 ark:- ${LangDir}/lm/lang_test/G_cat.fst "ark:|gzip -c > rescored_lat-test.gz"
# lattice-best-path "ark:gzip -c -d rescored_lat-test.gz |" ark,t:rescored_hypotheses-test

# lattice-scale --acoustic-scale=${ASF} "ark:gzip -c -d lat-validation.gz |" ark:- | \
# lattice-add-penalty --word-ins-penalty=${WIP} ark:- ark:- | \
# lattice-lmrescore --lm-scale=1.0 ark:- ${LangDir}/lm/lang_test/G_cat.fst "ark:|gzip -c > rescored_lat-validation.gz"
# lattice-best-path "ark:gzip -c -d rescored_lat-validation.gz |" ark,t:rescored_hypotheses-validation

echo -e "\nGenerating file of hypotheses: hypotheses_t" 1>&2
int2sym.pl -f 2- $LangDir/lm/lang_test/words.txt hypotheses-test > hypotheses-test_t
int2sym.pl -f 2- $LangDir/lm/lang_test/words.txt hypotheses-validation > hypotheses-validation_t

# int2sym.pl -f 2- $LangDir/lm/lang_test/words.txt rescored_hypotheses-test > rescored_hypotheses-test_t
# int2sym.pl -f 2- $LangDir/lm/lang_test/words.txt rescored_hypotheses-validation > rescored_hypotheses-validation_t


#Combine the outputs so that the Output of the Rescore is taken and the other in case of doubt
# python $ScriptsDir/combine_hypotheses_files.py rescored_hypotheses-test_t hypotheses-test_t combined_hypotheses-test_t
# python $ScriptsDir/combine_hypotheses_files.py rescored_hypotheses-validation_t hypotheses-validation_t combined_hypotheses-validation_t 

############################################################################################################

mkdir word-lm

# Get word-level transcript hypotheses
gawk '{
  printf("%s ", $1);
  for (i=2;i<=NF;++i) {
    if ($i == "<space>")
      printf(" ");
    else
      printf("%s", $i);
  }
  printf("\n");
}' hypotheses-test_t > word-lm/hyp_word-test.txt;

gawk '{
  printf("%s ", $1);
  for (i=2;i<=NF;++i) {
    if ($i == "<space>")
      printf(" ");
    else
      printf("%s", $i);
  }
  printf("\n");
}' hypotheses-validation_t > word-lm/hyp_word-validation.txt;

# gawk '{
#   printf("%s ", $1);
#   for (i=2;i<=NF;++i) {
#     if ($i == "<space>")
#       printf(" ");
#     else
#       printf("%s", $i);
#   }
#   printf("\n");
# }' combined_hypotheses-test_t > word-lm/combined_hyp_word-test.txt;

# gawk '{
#   printf("%s ", $1);
#   for (i=2;i<=NF;++i) {
#     if ($i == "<space>")
#       printf(" ");
#     else
#       printf("%s", $i);
#   }
#   printf("\n");
# }' combined_hypotheses-validation_t > word-lm/combined_hyp_word-validation.txt;


#Align the output to generate hypothesis with trac 1-best and correct tagging
# python $ScriptsDir/align_hypotheses.py word-lm/hyp_word-validation.txt word-lm/combined_hyp_word-validation.txt \
# word-lm/aligned_hypotheses-validation.txt

# python $ScriptsDir/align_hypotheses.py word-lm/hyp_word-test.txt word-lm/combined_hyp_word-test.txt \
# word-lm/aligned_hypotheses-test.txt

# python $ScriptsDir/align_hypotheses.py hypotheses-validation_t  combined_hypotheses-validation_t  \
# aligned_hypotheses-validation_t > log.txt

# python $ScriptsDir/align_hypotheses.py hypotheses-test_t combined_hypotheses-test_t \
# aligned_hypotheses-test_t > log.txt

# #ALIGNMENT AT WORD LEVEL
# python $ScriptsDir/align_hypotheses_wer.py hypotheses-validation_t  combined_hypotheses-validation_t  \
# wer_aligned_hypotheses-validation_t > log.txt

# python $ScriptsDir/align_hypotheses_wer.py hypotheses-test_t combined_hypotheses-test_t \
# wer_aligned_hypotheses-test_t > log.txt


# gawk '{
#   printf("%s ", $1);
#   for (i=2;i<=NF;++i) {
#     if ($i == "<space>")
#       printf(" ");
#     else
#       printf("%s", $i);
#   }
#   printf("\n");
# }' aligned_hypotheses-test_t > word-lm/aligned_hyp_word-test.txt;

# gawk '{
#   printf("%s ", $1);
#   for (i=2;i<=NF;++i) {
#     if ($i == "<space>")
#       printf(" ");
#     else
#       printf("%s", $i);
#   }
#   printf("\n");
# }' aligned_hypotheses-validation_t  > word-lm/aligned_hyp_word-validation.txt;

# gawk '{
#   printf("%s ", $1);
#   for (i=2;i<=NF;++i) {
#     if ($i == "<space>")
#       printf(" ");
#     else
#       printf("%s", $i);
#   }
#   printf("\n");
# }' wer_aligned_hypotheses-test_t > word-lm/wer_aligned_hyp_word-test.txt;

# gawk '{
#   printf("%s ", $1);
#   for (i=2;i<=NF;++i) {
#     if ($i == "<space>")
#       printf(" ");
#     else
#       printf("%s", $i);
#   }
#   printf("\n");
# }' wer_aligned_hypotheses-validation_t  > word-lm/wer_aligned_hyp_word-validation.txt;


echo "==============" >> $WorkDir/not_parenthesized_res_exp.txt
echo "Results after adding LM" >> $WorkDir/not_parenthesized_res_exp.txt

#cd $TmpDir/decode/
#Compute CER/WER.
if $(which compute-wer &> /dev/null); then
  echo "Test cer" >> $WorkDir/not_parenthesized_res_exp.txt
  compute-wer --mode=present  ark:$LangDir/char/char.total.txt ark:hypotheses-test_t | grep WER | sed -r 's|%WER|%CER|g' >> $WorkDir/not_parenthesized_res_exp.txt;
  echo "Test wer" >> $WorkDir/not_parenthesized_res_exp.txt
  compute-wer --mode=present  ark:$LangDir/char/word.total.txt ark:word-lm/hyp_word-test.txt |  grep WER >> $WorkDir/not_parenthesized_res_exp.txt;

  # echo "Test cer (COMBINED)" >> $WorkDir/not_parenthesized_res_exp.txt
  # compute-wer --mode=present  ark:$LangDir/char/char.total.txt ark:combined_hypotheses-test_t | grep WER | sed -r 's|%WER|%CER|g' >> $WorkDir/not_parenthesized_res_exp.txt;
  # echo "Test wer (COMBINED)" >> $WorkDir/not_parenthesized_res_exp.txt
  # compute-wer --mode=present  ark:$LangDir/char/word.total.txt ark:word-lm/combined_hyp_word-test.txt |  grep WER >> $WorkDir/not_parenthesized_res_exp.txt;

  # echo "Test cer (ALIGNED)" >> $WorkDir/not_parenthesized_res_exp.txt
  # compute-wer --mode=present  ark:$LangDir/char/char.total.txt ark:aligned_hypotheses-test_t | grep WER | sed -r 's|%WER|%CER|g' >> $WorkDir/not_parenthesized_res_exp.txt;
  # echo "Test wer (ALIGNED)" >> $WorkDir/not_parenthesized_res_exp.txt
  # compute-wer --mode=present  ark:$LangDir/char/word.total.txt ark:word-lm/aligned_hyp_word-test.txt |  grep WER >> $WorkDir/not_parenthesized_res_exp.txt;

  # echo "Test cer (WER ALIGNED)" >> $WorkDir/not_parenthesized_res_exp.txt
  # compute-wer --mode=present  ark:$LangDir/char/char.total.txt ark:wer_aligned_hypotheses-test_t | grep WER | sed -r 's|%WER|%CER|g' >> $WorkDir/not_parenthesized_res_exp.txt;
  # echo "Test wer (WER ALIGNED)" >> $WorkDir/not_parenthesized_res_exp.txt
  # compute-wer --mode=present  ark:$LangDir/char/word.total.txt ark:word-lm/wer_aligned_hyp_word-test.txt |  grep WER >> $WorkDir/not_parenthesized_res_exp.txt;


  sed 's/\([.,:;?]\)/ \1/g;s/\([¿¡]\)/\1 /g' word-lm/hyp_word-test.txt > SeparateSimbols-wordtest.txt
  sed 's/\([.,:;?]\)/ \1/g;s/\([¿¡]\)/\1 /g' $LangDir/char/word.total.txt > SeparateSimbols-word.txt
  sed 's/ \.line/\.line/g;s/ \.r\([0-9]\)/\.r\1/g;s/ \.region/\.region/g' -i SeparateSimbols-word.txt
  sed 's/ \.line/\.line/g;s/ \.r\([0-9]\)/\.r\1/g;s/ \.region/\.region/g' -i SeparateSimbols-wordtest.txt
  sed 's/</ </g' SeparateSimbols-wordtest.txt | sed 's/>/> /g' | sed 's/  / /g' > k; mv k SeparateSimbols-wordtest.txt
  sed 's/</ </g' SeparateSimbols-word.txt | sed 's/>/> /g' | sed 's/  / /g' > k; mv k SeparateSimbols-word.txt

  

  echo "Test wer separate" >> $WorkDir/not_parenthesized_res_exp.txt
  compute-wer --mode=present ark:SeparateSimbols-word.txt ark:SeparateSimbols-wordtest.txt >> $WorkDir/not_parenthesized_res_exp.txt

  echo "Test wer separate (fixed)" >> $WorkDir/not_parenthesized_res_exp.txt
  python $ScriptsDir/fix_separate_symb_output_alt.py $TmpDir/decode/lattices/SeparateSimbols-wordtest.txt $TmpDir/decode/lattices/fixed_SeparateSimbols-wordtest.txt
  python $ScriptsDir/fix_separate_symb_output_alt.py $TmpDir/decode/lattices/SeparateSimbols-word.txt $TmpDir/decode/lattices/fixed_SeparateSimbols-word.txt
  compute-wer --mode=present ark:fixed_SeparateSimbols-word.txt ark:fixed_SeparateSimbols-wordtest.txt >> $WorkDir/not_parenthesized_res_exp.txt

  # sed 's/\([.,:;?]\)/ \1/g;s/\([¿¡]\)/\1 /g' word-lm/combined_hyp_word-test.txt > SeparateSimbols-wordtest.txt
  # sed 's/ \.line/\.line/g;s/ \.r\([0-9]\)/\.r\1/g' -i SeparateSimbols-wordtest.txt
  # sed 's/</ </g' SeparateSimbols-wordtest.txt | sed 's/>/> /g' | sed 's/  / /g' > k; mv k SeparateSimbols-wordtest.txt

  # echo "Test wer separate (COMBINED)" >> $WorkDir/not_parenthesized_res_exp.txt
  # compute-wer --mode=present ark:SeparateSimbols-word.txt ark:SeparateSimbols-wordtest.txt >> $WorkDir/not_parenthesized_res_exp.txt

  # sed 's/\([.,:;?]\)/ \1/g;s/\([¿¡]\)/\1 /g' word-lm/aligned_hyp_word-test.txt > SeparateSimbols-wordtest.txt
  # sed 's/ \.line/\.line/g;s/ \.r\([0-9]\)/\.r\1/g' -i SeparateSimbols-wordtest.txt
  # sed 's/</ </g' SeparateSimbols-wordtest.txt | sed 's/>/> /g' | sed 's/  / /g' > k; mv k SeparateSimbols-wordtest.txt

  # echo "Test wer separate (ALIGNED)" >> $WorkDir/not_parenthesized_res_exp.txt
  # compute-wer --mode=present ark:SeparateSimbols-word.txt ark:SeparateSimbols-wordtest.txt >> $WorkDir/not_parenthesized_res_exp.txt

  # sed 's/\([.,:;?]\)/ \1/g;s/\([¿¡]\)/\1 /g' word-lm/wer_aligned_hyp_word-test.txt > SeparateSimbols-wordtest.txt
  # sed 's/ \.line/\.line/g;s/ \.r\([0-9]\)/\.r\1/g' -i SeparateSimbols-wordtest.txt
  # sed 's/</ </g' SeparateSimbols-wordtest.txt | sed 's/>/> /g' | sed 's/  / /g' > k; mv k SeparateSimbols-wordtest.txt

  # echo "Test wer separate (WER ALIGNED)" >> $WorkDir/not_parenthesized_res_exp.txt
  # compute-wer --mode=present ark:SeparateSimbols-word.txt ark:SeparateSimbols-wordtest.txt >> $WorkDir/not_parenthesized_res_exp.txt

  echo "--------------" >> $WorkDir/not_parenthesized_res_exp.txt
  echo "Val cer" >> $WorkDir/not_parenthesized_res_exp.txt
  compute-wer --mode=present  ark:$LangDir/char/char.total.txt ark:hypotheses-validation_t |   grep WER | sed -r 's|%WER|%CER|g' >> $WorkDir/not_parenthesized_res_exp.txt;

  echo "Val wer" >> $WorkDir/not_parenthesized_res_exp.txt
  compute-wer --mode=present  ark:$LangDir/char/word.total.txt ark:word-lm/hyp_word-validation.txt |  grep WER >> $WorkDir/not_parenthesized_res_exp.txt;

  sed 's/\([.,:;?]\)/ \1/g;s/\([¿¡]\)/\1 /g' word-lm/hyp_word-validation.txt > SeparateSimbols-wordvalidation.txt
  sed 's/ \.line/\.line/g;s/ \.r\([0-9]\)/\.r\1/g' -i SeparateSimbols-wordvalidation.txt
  sed 's/</ </g' SeparateSimbols-wordvalidation.txt | sed 's/>/> /g' | sed 's/  / /g' > k; mv k SeparateSimbols-wordvalidation.txt

  echo "Val wer separate" >> $WorkDir/not_parenthesized_res_exp.txt
  compute-wer --mode=present ark:SeparateSimbols-word.txt ark:SeparateSimbols-wordvalidation.txt >> $WorkDir/not_parenthesized_res_exp.txt

  #rm Separate*

else
  echo "ERROR: Kaldi's compute-wer was not found in your PATH!" >&2;
fi;

##########################################################################
## ORACLE METRICS

# $ScriptsDir/oracle_transc.sh $TmpDir $LangDir/lm/lang $TmpDir/decode/lattices/

# int2sym.pl -f 2- $LangDir/lm/lang_test/words.txt $TmpDir/decode/lattices/oracle_transc.txt > $TmpDir/decode/lattices/oracle_transc_t

# #CALC CER WITH ORACLE_TRANSC
# echo "ORACLE CER" >> $WorkDir/not_parenthesized_res_exp.txt
# compute-wer --mode=present  ark:$lang/../../char/char.total.txt ark:$TmpDir/decode/lattices/oracle_transc_t | grep WER | sed -r 's|%WER|%CER|g' >> $WorkDir/not_parenthesized_res_exp.txt

# #CALC WER
# gawk '{
#   printf("%s ", $1);
#   for (i=2;i<=NF;++i) {
#     if ($i == "<space>")
#       printf(" ");
#     else
#       printf("%s", $i);
#   }
#   printf("\n");
# }' $TmpDir/decode/lattices/oracle_transc_t > $TmpDir/decode/lattices/word-lm/oracle_transc-test.txt;

# sed 's/\([.,:;?]\)/ \1/g;s/\([¿¡]\)/\1 /g' $TmpDir/decode/lattices/word-lm/oracle_transc-test.txt > $TmpDir/decode/lattices/SeparateSimbols-wordtest.txt
# sed 's/ \.line/\.line/g;s/ \.r\([0-9]\)/\.r\1/g' -i $TmpDir/decode/lattices/SeparateSimbols-wordtest.txt
# sed 's/</ </g' $TmpDir/decode/lattices/SeparateSimbols-wordtest.txt | sed 's/>/> /g' | sed 's/  / /g' > k; mv k $TmpDir/decode/lattices/SeparateSimbols-wordtest.txt

# echo "ORACLE WER (SEPARATE)" >> $WorkDir/not_parenthesized_res_exp.txt
# compute-wer --mode=present ark:$TmpDir/decode/lattices/SeparateSimbols-word.txt ark:$TmpDir/decode/lattices/SeparateSimbols-wordtest.txt >> $WorkDir/not_parenthesized_res_exp.txt


##########################################################################
## Evaluation Precision - Recall
cd $TmpDir/decode/

# python $ScriptsDir/fix_separate_symb_output.py $TmpDir/decode/SeparateSimbols-wordtest.txt $TmpDir/decode/fixed_SeparateSimbols-wordtest.txt
# python $ScriptsDir/fix_separate_symb_output.py $TmpDir/decode/SeparateSimbols-word.txt $TmpDir/decode/fixed_SeparateSimbols-word.txt

cd $TmpDir
for f in $(<$PartDir/test.lst); do grep "${f}\b" ${TmpDir}/decode/lattices/fixed_SeparateSimbols-word.txt; done > ./fixed_SeparateSimbols-GT_test.txt

mkdir $WorkDir/PREC-REC
cd $WorkDir/PREC-REC/

rm -rf $WorkDir/PREC-REC/6_NOT_PARENTHESIZED_NER-GT
mkdir $WorkDir/PREC-REC/6_NOT_PARENTHESIZED_NER-GT
cd $WorkDir/PREC-REC/6_NOT_PARENTHESIZED_NER-GT
python $ScriptsDir/extract_ner_not_parenthesized_gw.py $TmpDir/fixed_SeparateSimbols-GT_test.txt ./
for f in *; do sed 's/^ //g' -i $f; done
cd ..

rm -rf $WorkDir/PREC-REC/6_NOT_PARENTHESIZED_NER-DECODE
mkdir $WorkDir/PREC-REC/6_NOT_PARENTHESIZED_NER-DECODE
cd $WorkDir/PREC-REC/6_NOT_PARENTHESIZED_NER-DECODE
python $ScriptsDir/extract_ner_not_parenthesized_gw.py $TmpDir/decode/lattices/fixed_SeparateSimbols-wordtest.txt ./
for f in *; do sed 's/^ //g' -i $f; done
cd ..

# ORACLE

# rm -rf $WorkDir/PREC-REC/ORACLE_NER
# mkdir $WorkDir/PREC-REC/ORACLE_NER
# cd $WorkDir/PREC-REC/ORACLE_NER
# $ScriptsDir/extractNERHip2.sh $TmpDir/decode/lattices/word-lm/oracle_transc-test.txt .
# for f in *; do sed 's/^ //g' -i $f; done

# cd ..

# mkdir $WorkDir/PREC-REC/NER-GT
# cd $WorkDir/PREC-REC/NER-GT
# $ScriptsDir/extractNER-GT_GW.sh $TmpDir/SeparateSimbols-GT_test.txt .
# for f in *; do sed 's/^ //g' -i $f; done

# cd ..

#NER NORMAL
python $ScriptsDir/calc_prec_rec.py ./6_NOT_PARENTHESIZED_NER-GT ./6_NOT_PARENTHESIZED_NER-DECODE >> $WorkDir/not_parenthesized_res_exp.txt
python $ScriptsDir/alt_dist_edicion_custom_saturated.py ./6_NOT_PARENTHESIZED_NER-GT ./6_NOT_PARENTHESIZED_NER-DECODE >> $WorkDir/not_parenthesized_res_exp.txt


# echo "ORACLE NER RESULTS" >> $WorkDir/not_parenthesized_res_exp.txt
# python $ScriptsDir/calc_prec_rec.py ./NER-GT ./ORACLE_NER >> $WorkDir/not_parenthesized_res_exp.txt
# python $ScriptsDir/alt_dist_edicion_custom_saturated.py ./NER-GT ./ORACLE_NER >> $WorkDir/not_parenthesized_res_exp.txt