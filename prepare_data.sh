# #!/bin/bash

# # This scripts prepares training and dev data for GEC.
# # Author: shamil.cm@gmail.com


# # PREREQUISITES:
# # Update the paths directory to point to the following extracted corpora
# #   - Lang-8 Learner Corpora v2 .dat file
# #   - NUCLE

set -e
set -x

source ./paths.sh

# paths to raw data files
NUCLE_DIR=$DATA_DIR/NUCLE
LANG8_DIR=$DATA_DIR/lang-8

# path to scripts directories
M2_SCRIPTS=$SCRIPTS_DIR/m2_scripts
MOSES_SCRIPTS=$SCRIPTS_DIR/moses_scripts
LANG8_SCRIPTS=$SCRIPTS_DIR/lang-8_scripts
NLTK_SCRIPTS=$SCRIPTS_DIR/nltk_scripts

REPLACE_UNICODE=$MOSES_SCRIPTS/replace-unicode-punctuation.perl
REMOVE_NON_PRINT=$MOSES_SCRIPTS/remove-non-printing-char.perl
NORMALIZE_PUNCT=$MOSES_SCRIPTS/normalize-punctuation.perl
TOKENIZER="python $NLTK_SCRIPTS/word-tokenize.py"




# NUCLE
#########
echo "[`date`] Preparing NUCLE data..." >&2
mkdir -p $NUCLE_DIR/tmp
tar -xvzf $NUCLE_DIR/NUCLE3.2.tar.gz -C $NUCLE_DIR/tmp
mkdir -p $NUCLE_DIR/nucle-dev
mkdir -p $NUCLE_DIR/nucle-train
python $M2_SCRIPTS/sort_m2.py  -i $NUCLE_DIR/tmp/release3.2/data/conll14st-preprocessed.m2 \
                     -o $NUCLE_DIR/tmp/nucle.sort.m2 -m 1 --output-remaining-lines
python $M2_SCRIPTS/get_num_lines.py  -i $NUCLE_DIR/tmp/nucle.sort.m2 \
                             --output_m2_prefix $NUCLE_DIR/tmp/nucle.split -n 4 --shuffle

cat $NUCLE_DIR/tmp/nucle.split.1.m2 > $NUCLE_DIR/nucle-dev/nucle-dev.m2
( cat $NUCLE_DIR/tmp/nucle.split.[234].m2 ; cat $NUCLE_DIR/tmp/nucle.sort.m2.rem ) > $NUCLE_DIR/tmp/nucle.combined.m2
python $M2_SCRIPTS/get_num_lines.py -i $NUCLE_DIR/tmp/nucle.combined.m2 --output_m2_prefix $NUCLE_DIR/tmp/nucle-train -n 1 --shuffle
cat $NUCLE_DIR/tmp/nucle-train.1.m2 > $NUCLE_DIR/nucle-train/nucle-train.m2

python $M2_SCRIPTS/convert_m2_to_parallel.py   $NUCLE_DIR/nucle-train/nucle-train.m2 \
                                     $NUCLE_DIR/nucle-train/nucle-train.tok.src \
                                     $NUCLE_DIR/nucle-train/nucle-train.tok.trg
python $M2_SCRIPTS/convert_m2_to_parallel.py   $NUCLE_DIR/nucle-dev/nucle-dev.m2 \
                                     $NUCLE_DIR/nucle-dev/nucle-dev.tok.src \
                                     $NUCLE_DIR/nucle-dev/nucle-dev.tok.trg
# removing empty target sentence pairs
paste $NUCLE_DIR/nucle-dev/nucle-dev.tok.src $NUCLE_DIR/nucle-dev/nucle-dev.tok.trg | awk -F $'\t' '$2!=""' > $NUCLE_DIR/nucle-dev/nucle-dev.non_empty.tok.src-trg
cut $NUCLE_DIR/nucle-dev/nucle-dev.non_empty.tok.src-trg -f1 > $NUCLE_DIR/nucle-dev/nucle-dev.non_empty.tok.src
cut $NUCLE_DIR/nucle-dev/nucle-dev.non_empty.tok.src-trg -f2 > $NUCLE_DIR/nucle-dev/nucle-dev.non_empty.tok.trg
rm $NUCLE_DIR/nucle-dev/nucle-dev.non_empty.tok.src-trg


# LANG-8 v2
#############
# # Preparation of Lang-8 data
echo "[`date`] Preparing Lang-8 data... (NOTE:Can take several hours, due to LangID.py filtering...)" >&2
L2=English  # Learning language, i.e. extract only English learners text

mkdir -p $LANG8_DIR
mkdir -p $LANG8_DIR/tmp
python $LANG8_SCRIPTS/extract.py -i $LANG8_DIR/lang-8-20111007-L1-v2.dat -o $LANG8_DIR/tmp/ -l2 $L2
cat $LANG8_DIR/tmp/lang-8-20111007-L1-v2.dat.processed | perl -p -e 's@\[sline\].*?\[\\/sline\]@@sg' | sed 's/\[\\\/sline\]//g' | sed 's/\[\\\/f-[a-zA-Z]*\]//g' | sed 's/\[f-[a-zA-Z]*\]//g' | sed 's/rŠëyËb¢{//g' > $LANG8_DIR/tmp/lang-8.$L2.cleanedup
rm $LANG8_DIR/tmp/lang-8-20111007-L1-v2.dat.processed
python $LANG8_SCRIPTS/langidfilter.py $LANG8_DIR/tmp/lang-8.$L2.cleanedup > $LANG8_DIR/tmp/lang-8.$L2.extracted
rm $LANG8_DIR/tmp/lang-8.$L2.cleanedup
python $LANG8_SCRIPTS/get_parallel.py -i $LANG8_DIR/tmp/lang-8.$L2.extracted -o lang-8 -d $LANG8_DIR/tmp/

for EXT in src trg; do
    cat $LANG8_DIR/tmp/lang-8.$EXT | $REPLACE_UNICODE | $REMOVE_NON_PRINT | sed  's/\\"/\"/g' | sed 's/\\t/ /g' | $NORMALIZE_PUNCT |  $TOKENIZER  > $LANG8_DIR/lang-8-train.tok.$EXT
done



# Preparing the concatenated training data.
cat $NUCLE_DIR/nucle-train/nucle-train.tok.src $LANG8_DIR/lang-8-train.tok.src > $DATA_DIR/train.tok.src
cat $NUCLE_DIR/nucle-train/nucle-train.tok.trg $LANG8_DIR/lang-8-train.tok.trg > $DATA_DIR/train.tok.trg
$MOSES_SCRIPTS/clean-corpus-n.perl $DATA_DIR/train.tok src trg $DATA_DIR/train.clean.tok 1 80

# Create hyperlink to the processed data in the current directory
ln -s $NUCLE_DIR/nucle-dev/nucle-dev.non_empty.tok.src dev.tok.src
ln -s $NUCLE_DIR/nucle-dev/nucle-dev.non_empty.tok.trg dev.tok.trg
ln -s $NUCLE_DIR/nucle-dev/nucle-dev.tok.src dev.all.tok.src
ln -s $NUCLE_DIR/nucle-dev/nucle-dev.m2 dev.all.m2
