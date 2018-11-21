#!/bin/bash


set -e
set -x

source ./paths.sh

# downloading test data files (CoNLL-2013 and CoNLL-2014)
mkdir -p $DATA_DIR/tmp
wget http://www.comp.nus.edu.sg/~nlp/conll14st/conll14st-test-data.tar.gz -O $DATA_DIR/tmp/conll14st.tar.gz

# uncompressing the files
tar -xvzf $DATA_DIR/tmp/conll14st.tar.gz -C $DATA_DIR/tmp/

mkdir -p $DATA_DIR/test

mkdir -p $DATA_DIR/test/conll14st-test

CONLL2014_M2=$DATA_DIR/tmp/conll14st-test-data/noalt/official-2014.combined.m2
CONLL2014_0_M2=$DATA_DIR/tmp/conll14st-test-data/noalt/official-2014.0.m2
CONLL2014_1_M2=$DATA_DIR/tmp/conll14st-test-data/noalt/official-2014.1.m2
echo $CONLL2014_M2
cp $CONLL2014_M2 $DATA_DIR/test/conll14st-test/conll14st-test.m2
cat $DATA_DIR/test/conll14st-test/conll14st-test.m2 | grep "^S" | cut -d' '  -f2- > $DATA_DIR/test/conll14st-test/conll14st-test.tok.src

rm -r $DATA_DIR/tmp
