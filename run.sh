
## This script is to run the complete GEC system on any given test set

set -e
set -x

source paths.sh

if [ $# -ge 4 ]; then
    input_file=$1
    output_dir=$2
    device=$3
    model_path=$4
    if [ $# -eq 6 ]; then
        reranker_weights=$5
        reranker_feats=$6
    fi
else
    echo "Please specify the paths to the input_file and output directory"
    echo "Usage: `basename $0` <input_file> <output_dir> <gpu-device-num(e.g: 0)> <path to model_file/dir> [optional args: <path-to-reranker-weights> <featuers,e.g:eo,eolm]"   >&2
    echo "Example: ./run.sh ./data/test/conll14st-test/conll14st-test.tok.src ./outputs/tmmp/ 0 models/mlconv/model1000/checkpoint13.pt"
fi



if [[ -d "$model_path" ]]; then
    models=`ls $model_path/*pt | tr '\n' ' ' | sed "s| \([^$]\)| --path \1|g"`
    echo $models
elif [[ -f "$model_path" ]]; then
    models=$model_path
elif [[ ! -e "$model_path" ]]; then
    echo "Model path not found: $model_path"
fi


FAIRSEQ=$SOFTWARE_DIR/fairseq
NBEST_RERANKER=$SOFTWARE_DIR/nbest-reranker


beam=12
nbest=$beam

mkdir -p $output_dir
python $SCRIPTS_DIR/apply_bpe.py -c $MODEL_DIR/bpe_model/train.bpe.model < $input_file > $output_dir/input.bpe.txt

# running fairseq on the test data
CUDA_VISIBLE_DEVICES=$device python $FAIRSEQ/generate.py --source-lang src --target-lang trg --no-progress-bar --path $models --beam $beam --nbest $beam $DATA_DIR/processed/bin < $output_dir/input.bpe.txt > $output_dir/output.bpe.nbest.txt

# getting best hypotheses
cat $output_dir/output.bpe.nbest.txt | grep "^H"  | python -c "import sys; x = sys.stdin.readlines(); x = ' '.join([ x[i] for i in range(len(x)) if(i%$nbest == 0) ]); print(x)" | cut -f3 > $output_dir/output.bpe.txt

# debpe
cat $output_dir/output.bpe.txt | sed 's|@@ ||g' | sed '$ d' > $output_dir/output.tok.txt

# additionally re-rank outputs
if [ $# -eq 6  ];  then
    if [ $reranker_feats == "eo" ]; then
        featstring="EditOps(name='EditOps0')"
    elif [ $reranker_feats == "eolm" ]; then
        featstring="EditOps(name='EditOps0'), LM('LM0', '$MODEL_DIR/lm/94Bcclm.trie', normalize=False), WordPenalty(name='WordPenalty0')"
    fi
    $SCRIPTS_DIR/nbest_reformat.py -i $output_dir/output.bpe.nbest.txt --debpe > $output_dir/output.tok.nbest.reformat.txt
    $NBEST_RERANKER/augmenter.py -s $input_file -i $output_dir/output.tok.nbest.reformat.txt -o $output_dir/output.tok.nbest.reformat.augmented.txt -f "$featstring"
    $NBEST_RERANKER/rerank.py -i $output_dir/output.tok.nbest.reformat.augmented.txt -w $reranker_weights -o $output_dir --clean-up
    mv $output_dir/output.tok.nbest.reformat.augmented.txt.reranked.1best $output_dir/output.reranked.tok.txt
fi
