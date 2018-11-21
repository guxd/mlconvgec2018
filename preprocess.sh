#!/bin/bash

set -x

source ./paths.sh

## paths to training and development datasets
src_ext=src
trg_ext=trg
train_data_prefix=$DATA_DIR/train
dev_data_prefix=$DATA_DIR/dev
dev_data_m2=$DATA_DIR/dev.all.m2

# path to subword nmt
SUBWORD_NMT=$SOFTWARE_DIR/subword-nmt
# path to Fairseq-Py
FAIRSEQ=$SOFTWARE_DIR/fairseq

######################
# subword segmentation
mkdir -p $MODEL_DIR/bpe_model
bpe_operations=30000
cat $train_data_prefix.tok.$trg_ext | python $SUBWORD_NMT/learn_bpe.py -s $bpe_operations > $MODEL_DIR/bpe_model/train.bpe.model
mkdir -p $DATA_DIR/processed/
python $SCRIPTS_DIR/apply_bpe.py -c $MODEL_DIR/bpe_model/train.bpe.model < $train_data_prefix.tok.$src_ext > $DATA_DIR/processed/train.all.src
python $SCRIPTS_DIR/apply_bpe.py -c $MODEL_DIR/bpe_model/train.bpe.model < $train_data_prefix.tok.$trg_ext > $DATA_DIR/processed/train.all.trg
python $SCRIPTS_DIR/apply_bpe.py -c $MODEL_DIR/bpe_model/train.bpe.model < $dev_data_prefix.tok.$src_ext > $DATA_DIR/processed/dev.src
python $SCRIPTS_DIR/apply_bpe.py -c $MODEL_DIR/bpe_model/train.bpe.model < $dev_data_prefix.tok.$trg_ext > $DATA_DIR/processed/dev.trg
cp $dev_data_m2 $DATA_DIR/processed/dev.m2
cp $dev_data_prefix.all.tok.$src_ext $DATA_DIR/processed/dev.input.txt

##########################
#  getting annotated sentence pairs only
python $SCRIPTS_DIR/get_diff.py  $DATA_DIR/processed/train.all src trg > $DATA_DIR/processed/train.annotated.src-trg
cut -f1  $DATA_DIR/processed/train.annotated.src-trg > $DATA_DIR/processed/train.src
cut -f2  $DATA_DIR/processed/train.annotated.src-trg > $DATA_DIR/processed/train.trg


#########################
# preprocessing
python $FAIRSEQ/preprocess.py --source-lang src --target-lang trg --trainpref $DATA_DIR/processed/train --validpref $DATA_DIR/processed/dev --testpref  $DATA_DIR/processed/dev --nwordssrc 30000 --nwordstgt 30000 --destdir $DATA_DIR/processed/bin

