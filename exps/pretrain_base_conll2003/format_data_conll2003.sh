#Commands used to format the data in conll2003 to generate synthetic line images

#Remove -DOCSTART- lines from the file

# cat train.txt > synthetic_data_train.txt
# cat test.txt >> synthetic_data_train.txt
# cat valid.txt > synthetic_data_valid.txt

# sed -i 's/-DOCSTART- -X- -X- O//g' synthetic_data_train.txt
# sed -i 's/-DOCSTART- -X- -X- O//g' synthetic_data_valid.txt

#Get fields 1 and 4, remove O tags, B- and I- 
cd /home/dvilanova/expsKronos/data/conll2003/
cut -f 1,4 -d\  train.txt | sed 's/ O//g' | sed 's/I-//g' | sed 's/B-//g' > fixed_tagging_synthetic_data_train.txt
cut -f 1,4 -d\  test.txt | sed 's/ O//g' | sed 's/I-//g' | sed 's/B-//g' > fixed_tagging_synthetic_data_test.txt
cut -f 1,4 -d\  valid.txt | sed 's/ O//g' | sed 's/I-//g' | sed 's/B-//g' > fixed_tagging_synthetic_data_valid.txt

#Change spaces for tabs
tr ' ' \\t < fixed_tagging_synthetic_data_train.txt > final_synthetic_data_train.txt
tr ' ' \\t < fixed_tagging_synthetic_data_test.txt >> final_synthetic_data_train.txt
tr ' ' \\t < fixed_tagging_synthetic_data_valid.txt > final_synthetic_data_valid.txt

#Generation of annotations.txt with all the images and lines/ folder with all lines
cat final_synthetic_data_train.txt > final_synthetic_data_all.txt
cat final_synthetic_data_valid.txt >> final_synthetic_data_all.txt

#Run DOC synthesizer for all
cd /home/dvillanova/expsKronos/dvillano/doc_synthesizer
python /home/dvillanova/expsKronos/dvillano/doc_synthesizer/synthesize_doc.py

#Modify DOC synthesizer to work with final_synthetic_data_train.txt
cd /home/dvillanova/expsKronos/dvillano/doc_synthesizer
python /home/dvillanova/expsKronos/dvillano/doc_synthesizer/synthesize_doc.py

#Modify DOC synthesizer to work with final_synthetic_data_valid.txt
cd /home/dvillanova/expsKronos/dvillano/doc_synthesizer
python /home/dvillanova/expsKronos/dvillano/doc_synthesizer/synthesize_doc.py

#GENERATION OF .LST FILES
cd /home/dvillanova/expsKronos/data/conll2003/train_lines/train/
cut -f 1-1 annotations.txt > k
#Remove first line of k
tail -n +2 k > train.lst
rm k

cd /home/dvillanova/expsKronos/data/conll2003/valid_lines/valid/
cut -f 1-1 annotations.txt > k
#Remove first line of k
tail -n +2 k > valid.lst
rm k

#Generation of PyLaia-like word transcriptions
cd /home/dvillanova/expsKronos/data/conll2003/valid_lines/valid/
python /home/dvillanova/expsKronos/dvillano/scripts/synthetic_data_generation/format_conll_word_transcriptions.py \
./

cd /home/dvillanova/expsKronos/data/conll2003/train_lines/train/
python /home/dvillanova/expsKronos/dvillano/scripts/synthetic_data_generation/format_conll_word_transcriptions.py \
./

#Generate "index.words"
cd /home/dvillanova/expsKronos/data/conll2003/synthetic_lines/all/
python /home/dvillanova/expsKronos/dvillano/scripts/synthetic_data_generation/format_conll_word_transcriptions.py \
./
mv word_transcription.txt index.words

#Use .lst files generated earlier to split the data
N_TRAIN=$(wc -l /home/dvillanova/expsKronos/data/conll2003/train_lines/train/train.lst | cut -f 1 -d " ")

#Training annotation and .lst file
cut -f 1-1 annotations.txt > k
tail -n +2 k | head -n $N_TRAIN > train.lst
rm k

head -n $N_TRAIN index.words > train.txt
#for f in $(<./train.lst); do grep "${f}\b" ./index.words;
#done > ./train.txt #This version does not work, some identifiers are prefixes of others

#Validation annotation and .lst file
cut -f 1-1 annotations.txt > k
tail -n +3 k | tail -n +$N_TRAIN > valid.lst
rm k

tail -n +$N_TRAIN index.words | tail -n +2 > valid.txt
#for f in $(<./val.lst); do grep "${f}\b" ./index.words;
#done > ./valid.txt #This version does not work, some identifiers are prefixes of others

#Generation of char-level annotations for training
#add additional space before tag so that it is recognized as a token
sed 's/</ </g' train.txt |
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


#Generation of char-level annotations for validation
#add additional space before tag so that it is recognized as a token
sed 's/</ </g' valid.txt |
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
}' | sed 's/#/<stroke>/g' > char.valid.txt

cd /home/dvillanova/expsKronos/data/conll2003/synthetic_lines/all
cat /home/dvillanova/expsKronos/data/iam/18_NOT_PARENTHESIZED_TMP/char.train.txt > ./char.iam_18.txt
cat /home/dvillanova/expsKronos/data/iam/18_NOT_PARENTHESIZED_TMP/char.test.txt >> ./char.iam_18.txt
cat /home/dvillanova/expsKronos/data/iam/18_NOT_PARENTHESIZED_TMP/char.val.txt >> ./char.iam_18.txt

cat /home/dvillanova/expsKronos/data/iam/6_NOT_PARENTHESIZED_TMP/char.train.txt > ./char.iam_6.txt
cat /home/dvillanova/expsKronos/data/iam/6_NOT_PARENTHESIZED_TMP/char.test.txt >> ./char.iam_6.txt
cat /home/dvillanova/expsKronos/data/iam/6_NOT_PARENTHESIZED_TMP/char.val.txt >> ./char.iam_6.txt

cat /home/dvillanova/expsKronos/data/popp/baseline_TMP/char.train.txt > ./char.popp.txt
cat /home/dvillanova/expsKronos/data/popp/baseline_TMP/char.test.txt >> ./char.popp.txt
cat /home/dvillanova/expsKronos/data/popp/baseline_TMP/char.val.txt >> ./char.popp.txt

cat /home/dvillanova/expsKronos/data/home/baseline_TMP/char.train.txt > ./char.home.txt
cat /home/dvillanova/expsKronos/data/home/baseline_TMP/char.test.txt >> ./char.home.txt
cat /home/dvillanova/expsKronos/data/home/baseline_TMP/char.val.txt >> ./char.home.txt

for p in train valid iam_18 iam_6 popp home; do cat char.${p}.txt | cut -f 2- -d " "  |
tr \  \\n; done | sort -u -V | gawk 'BEGIN{
  N=0;
  printf("%-12s %d\n", "<ctc>", N++);
}NF==1{
  printf("%-12s %d\n", $1, N++);
}' >  symb.txt