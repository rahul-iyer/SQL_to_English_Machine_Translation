#!/bin/zsh

export MOSES_DIR="/home/sviyer/nlidb/src/mosesdecoder/"
alias tok="${MOSES_DIR}/scripts/tokenizer/tokenizer.perl"
alias tcaser="${MOSES_DIR}/scripts/recaser/train-truecaser.perl"
alias tcase="${MOSES_DIR}/scripts/recaser/truecase.perl"
alias ccorpus="${MOSES_DIR}/scripts/training/clean-corpus-n.perl"
alias kenlm="${MOSES_DIR}/bin/lmplz"
alias arpa2bin="${MOSES_DIR}/bin/build_binary"
alias lmq="${MOSES_DIR}/bin/query"
alias tmoses="${MOSES_DIR}/scripts/training/train-model.perl"
alias rmoses="${MOSES_DIR}/bin/moses"
alias nweb="cd ~/nlidb/src/apps"
alias mgiza="/home/sviyer/nlidb/bin/training-tools/mgiza"
alias ptablebin="${MOSES_DIR}/bin/processPhraseTableMin"

# clean up
find ! -name 'train.sh' -type f -exec rm -f {} +
rm -rf corpus giza.* lm model

# # Training/Testing set
echo "select lower(regexp_replace(title, E'[\\n\\r\\u2028]+', ' ', 'g' )) from sqlposts_clean where filter is null and training = 1 " | psql -t stackoverflow sviyer > stackoverflow_training_questions.txt

echo "select lower(regexp_replace(answer, E'[\\n\\r\\u2028]+', ' ', 'g' )) from sqlposts_clean where filter is null and training = 1 " | psql -t stackoverflow sviyer > stackoverflow_training_answers.txt

echo "select lower(regexp_replace(title, E'[\\n\\r\\u2028]+', ' ', 'g' )) from sqlposts_clean where filter is null and training = 2 " | psql -t stackoverflow sviyer > stackoverflow_validation_questions.txt

echo "select lower(regexp_replace(answer, E'[\\n\\r\\u2028]+', ' ', 'g' )) from sqlposts_clean where filter is null and training = 2 " | psql -t stackoverflow sviyer > stackoverflow_validation_answers.txt

tok -l en < stackoverflow_training_questions.txt > stackoverflow_training.nl

tok < stackoverflow_training_answers.txt > stackoverflow_training.sql

ccorpus stackoverflow_training nl sql stackoverflow_training.clean 1 80

# Language Model
#
mkdir -p lm
#
kenlm -o 3 -S 80% -T /tmp < stackoverflow_training.clean.nl > lm/stackoverflow_training.arpa
# 
arpa2bin lm/stackoverflow_training.arpa lm/stackoverflow_training.blm
# 
# Training
tmoses -root-dir . -corpus stackoverflow_training.clean  -f sql -e nl -alignment grow-diag-final-and -reordering msd-bidirectional-fe -lm 0:3:`pwd`/lm/stackoverflow_training.blm -cores 8 -external-bin-dir=/home/sviyer/nlidb/bin/training-tools/ -mgiza -mgiza-cpus 8 -score-options '--NoLex --OnlyDirect'

tok < stackoverflow_validation_answers.txt > stackoverflow_validation.sql

tok -l en < stackoverflow_validation_questions.txt > stackoverflow_validation.nl
 
ccorpus stackoverflow_validation nl sql stackoverflow_validation.clean 1 80
# Testing
rmoses -f model/moses.ini < stackoverflow_validation.sql > stackoverflow_validation_predicted.nl -threads all 2> /tmp/moses.err

# BLEU
python ~/nlidb/src/core/translator/moses.py --predictionFile `pwd`/stackoverflow_validation_predicted.nl --goldFile stackoverflow_validation.nl