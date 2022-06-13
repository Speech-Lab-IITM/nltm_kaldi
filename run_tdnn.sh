#!/bin/bash

# steps/info/chain_dir_info.pl exp/chain/tdnn1g_sp
# exp/chain/tdnn1g_sp: num-iters=108 nj=2..8 num-params=8.4M dim=40+100->2854 combine=-0.042->-0.042 (over 2) xent:train/valid[71,107,final]=(-0.975,-0.640,-0.646/-0.980,-0.678,-0.688) logprob:train/valid[71,107,final]=(-0.067,-0.043,-0.042/-0.069,-0.050,-0.049)

set -e -o pipefail

. ./cmd.sh
. ./path.sh

#PLEASE EDIT THE FOLLOWING BEFORE RUNNING THE SCRIPT. Should match the parameters of run_gmm.sh script for the same experiment 
 
# First the options that are passed through to run_ivector_common.sh
# (some of which are also used in this script directly).
stage=0  #0
ivec_stage=1
nj=16
tag=trial    #experiment tag, so that models are not overwritten; make sure change this if running a new experiment.
expdir=exp_${tag}
datadir=/nlsasfs/home/nltm-pilot/vasistal/ASR_project/kaldi_models/kannada/nltm_kaldi/data #Give the absolute path in case your data directory is not present in the current working directory
train_set=train
test_sets="dev test"

#The best hmm-gmm model
gmm=tri3_7000_140000  # this is the source gmm-dir that we'll use for alignments; it
                            # should have alignments for the specified training data.

num_threads_ubm=30

nj_extractor=10
# It runs a JOB with '-pe smp N', where N=$[threads*processes]
num_threads_extractor=4
num_processes_extractor=4

nnet3_affix=      # affix for exp dirs, e.g. it was _cleaned in tedlium.

# Options which are not passed through to run_ivector_common.sh
affix=   #affix for TDNN+LSTM directory e.g. "1a" or "1b", in case we change the configuriation.
common_egs_dir= 
reporting_email=

# LSTM/chain options
train_stage=-10
xent_regularize=0.1
dropout_schedule='0,0@0.20,0.5@0.50,0'

# training chunk-options
chunk_width=140,100,160
# we don't need extra left/right context for TDNN systems.
chunk_left_context=0
chunk_right_context=0

# training options
srand=0
remove_egs=true
num_epochs=10

#decode options
test_online_decoding=false  # if true, it will run the last decoding stage.

# End configuration section.
echo "$0 $@"  # Print the command line for logging

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

ivec_start_stage=0

if [ $ivec_stage -eq 1 ]; then
	local/nnet3/run_ivector_common_IITM.sh \
	--stage $ivec_start_stage --nj $nj \
	--train_set $train_set --gmm $gmm --test_sets "${test_sets}" --data_folder $datadir --exp_folder $expdir \
	--num_threads_ubm $num_threads_ubm \
	--nj_extractor $nj_extractor \
	--num_processes_extractor $num_processes_extractor \
	--num_threads_extractor $num_threads_extractor \
	--nnet3_affix "${nnet3_affix}"
fi

gmm_dir=$expdir/${gmm}
ali_dir=$expdir/${gmm}_ali_${train_set}_sp
lat_dir=$expdir/chain${nnet3_affix}/${gmm}_${train_set}_sp_lats
dir=$expdir/chain${nnet3_affix}/tdnn${affix}_sp
train_data_dir=$datadir/${train_set}_sp_hires
train_ivector_dir=$expdir/nnet3${nnet3_affix}/ivectors_${train_set}_sp_hires
lores_train_data_dir=$datadir/${train_set}_sp
echo "$train_ivector_dir"
# note: you don't necessarily have to change the treedir name
# each time you do a new experiment-- only if you change the
# configuration in a way that affects the tree.
tree_dir=$expdir/chain${nnet3_affix}/tree_a_sp
# the 'lang' directory is created by this script.
# If you create such a directory with a non-standard topology
# you should probably name it differently.
lang=$datadir/lang_chain

. ./utils/parse_options.sh

for f in $train_data_dir/feats.scp $train_ivector_dir/ivector_online.scp \
	$lores_train_data_dir/feats.scp $gmm_dir/final.mdl \
    	$ali_dir/ali.1.gz $gmm_dir/final.mdl; do
  	[ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

if [ $stage -le 12 ]; then
	echo "$0: creating lang directory $lang with chain-type topology"
  	# Create a version of the lang/ directory that has one state per phone in the
  	# topo file. [note, it really has two states.. the first one is only repeated
  	# once, the second one has zero or more repeats.]
	if [ -d $lang ]; then
		if [ $lang/L.fst -nt $datadir/lang/L.fst ]; then
	      		echo "$0: $lang already exists, not overwriting it; continuing"
		    	else
		      	echo "$0: $lang already exists and seems to be older than $datadir/lang..."
		      	echo " ... not sure what to do.  Exiting."
	      		exit 1;
	    	fi
	 else
	 	cp -r $datadir/lang $lang
	    	silphonelist=$(cat $lang/phones/silence.csl) || exit 1;
	    	nonsilphonelist=$(cat $lang/phones/nonsilence.csl) || exit 1;
	    	# Use our special topology... note that later on may have to tune this
	    	# topology.
	    	steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang/topo
	 fi
fi

if [ $stage -le 13 ]; then
	# Get the alignments as lattices (gives the chain training more freedom).
  	# use the same num-jobs as the alignments
  	steps/align_fmllr_lats.sh --nj 20 --cmd "$train_cmd" ${lores_train_data_dir} \
    	$datadir/lang $gmm_dir $lat_dir
  	rm $lat_dir/fsts.*.gz # save space
fi

if [ $stage -le 14 ]; then
  	# Build a tree using our new topology.  We know we have alignments for the
  	# speed-perturbed data (local/nnet3/run_ivector_common.sh made them), so use
  	# those.  The num-leaves is always somewhat less than the num-leaves from
  	#the GMM baseline.
	if [ -f $tree_dir/final.mdl ]; then
     		echo "$0: $tree_dir/final.mdl already exists, refusing to overwrite it."
     		exit 1;
 	fi
  	steps/nnet3/chain/build_tree.sh \
    	  --frame-subsampling-factor 3 \
    	  --context-opts "--context-width=2 --central-position=1" \
    	  --cmd "$train_cmd" 3500 ${lores_train_data_dir} \
    	$lang $ali_dir $tree_dir
fi

if [ $stage -le 15 ]; then
	mkdir -p $dir
  	echo "$0: creating neural net configs using the xconfig parser";

  	num_targets=$(tree-info $tree_dir/tree |grep num-pdfs|awk '{print $2}')
  	learning_rate_factor=$(echo "print(0.5/$xent_regularize)" | python3)
  	tdnn_opts="l2-regularize=0.01 dropout-proportion=0.0 dropout-per-dim-continuous=true"
  	tdnnf_opts="l2-regularize=0.01 dropout-proportion=0.0 bypass-scale=0.66"
  	linear_opts="l2-regularize=0.01 orthonormal-constraint=-1.0"
  	prefinal_opts="l2-regularize=0.01"
  	output_opts="l2-regularize=0.005"

  	mkdir -p $dir/configs
  	cat <<EOF > $dir/configs/network.xconfig
  	input dim=100 name=ivector
  	input dim=40 name=input

  	# please note that it is important to have input layer with the name=input
  	# as the layer immediately preceding the fixed-affine-layer to enable
  	# the use of short notation for the descriptor
  	fixed-affine-layer name=lda input=Append(-1,0,1,ReplaceIndex(ivector, t, 0)) affine-transform-file=$dir/configs/lda.mat

  	# the first splicing is moved before the lda layer, so no splicing here
  	relu-batchnorm-dropout-layer name=tdnn1 $tdnn_opts dim=1024
  	tdnnf-layer name=tdnnf2 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=1
  	tdnnf-layer name=tdnnf3 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=1
  	tdnnf-layer name=tdnnf4 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=1
  	tdnnf-layer name=tdnnf5 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=0
  	tdnnf-layer name=tdnnf6 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  	tdnnf-layer name=tdnnf7 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  	tdnnf-layer name=tdnnf8 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  	tdnnf-layer name=tdnnf9 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  	tdnnf-layer name=tdnnf10 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  	tdnnf-layer name=tdnnf11 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  	tdnnf-layer name=tdnnf12 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  	tdnnf-layer name=tdnnf13 $tdnnf_opts dim=1024 bottleneck-dim=128 time-stride=3
  	linear-component name=prefinal-l dim=192 $linear_opts


  	prefinal-layer name=prefinal-chain input=prefinal-l $prefinal_opts big-dim=1024 small-dim=192
  	output-layer name=output include-log-softmax=false dim=$num_targets $output_opts

  	prefinal-layer name=prefinal-xent input=prefinal-l $prefinal_opts big-dim=1024 small-dim=192
  	output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor $output_opts
EOF
	
  	steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/
fi


if [ $stage -le 16 ]; then
	if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d /scratch1/guruprasad/egs/storage ]; then
    		utils/create_split_dir.pl \
     		/export/b0{3,4,5,6}/$USER/kaldi-data/egs/wsj-$(date +'%m_%d_%H_%M')/s5/$dir/egs/storage /scratch1/guruprasad/egs/storage
  	fi

  	steps/nnet3/chain/train.py --stage=$train_stage \
    	  --cmd="$decode_cmd" \
    	  --feat.online-ivector-dir=$train_ivector_dir \
	  --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
	  --chain.xent-regularize $xent_regularize \
	  --chain.leaky-hmm-coefficient=0.1 \
	  --chain.l2-regularize=0.0 \
	  --chain.apply-deriv-weights=false \
	  --chain.lm-opts="--num-extra-lm-states=2000" \
	  --trainer.dropout-schedule $dropout_schedule \
	  --trainer.add-option="--optimization.memory-compression-level=2" \
	  --trainer.srand=$srand \
	  --trainer.max-param-change=2.0 \
	  --trainer.num-epochs=$num_epochs \
	  --trainer.frames-per-iter=5000000 \
	  --trainer.optimization.num-jobs-initial=1 \
	  --trainer.optimization.num-jobs-final=1 \
	  --trainer.optimization.initial-effective-lrate=0.0005 \
	  --trainer.optimization.final-effective-lrate=0.00005 \
	  --trainer.num-chunk-per-minibatch=128,64 \
	  --trainer.optimization.momentum=0.0 \
	  --egs.chunk-width=$chunk_width \
	  --egs.chunk-left-context=0 \
	  --egs.chunk-right-context=0 \
	  --egs.dir="$common_egs_dir" \
	  --egs.opts="--frames-overlap-per-eg 0" \
	  --cleanup.remove-egs=$remove_egs \
	  --use-gpu=true \
	  --reporting.email="$reporting_email" \
	  --feat-dir=$train_data_dir \
	  --tree-dir=$tree_dir \
	  --lat-dir=$lat_dir \
	  --dir=$dir  || exit 1;
fi

if [ $stage -le 17 ]; then
  	# The reason we are using data/lang here, instead of $lang, is just to
  	# emphasize that it's not actually important to give mkgraph.sh the
  	# lang directory with the matched topology (since it gets the
  	# topology file from the model).  So you could give it a different
  	# lang directory, one that contained a wordlist and LM of your choice,
  	# as long as phones.txt was compatible.

	utils/lang/check_phones_compatible.sh \
    	  $datadir/lang/phones.txt $lang/phones.txt
  	utils/mkgraph.sh \
    	  --self-loop-scale 1.0 $datadir/lang \
    	  $tree_dir $tree_dir/graph || exit 1;

<<"over"
  utils/lang/check_phones_compatible.sh \
    data/lang_test_bd_tgpr/phones.txt $lang/phones.txt
  utils/mkgraph.sh \
    --self-loop-scale 1.0 data/lang_test_bd_tgpr \
    $tree_dir $tree_dir/graph_bd_tgpr || exit 1;
over

fi

if [ $stage -le 18 ]; then
	frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  	rm $dir/.error 2>/dev/null || true

  	for data in $test_sets; do
    	
      		#data_affix=$(echo $data | sed s/test_//)
      		#nspk=$(wc -l <$datadir/${data}_hires/spk2utt)
      		nspk=10
      		#for lmtype in tgpr bd_tgpr; do
        	(
                steps/nnet3/decode.sh \
          	  --acwt 1.0 --post-decode-acwt 10.0 \
          	  --extra-left-context 0 --extra-right-context 0 \
          	  --extra-left-context-initial 0 \
          	  --extra-right-context-final 0 \
          	  --frames-per-chunk $frames_per_chunk \
          	  --nj $nspk --cmd "$decode_cmd"  --num-threads 4 \
          	  --online-ivector-dir $expdir/nnet3${nnet3_affix}/ivectors_${data}_hires \
          	  $tree_dir/graph $datadir/${data}_hires ${dir}/decode_${data} || exit 1
      		#done
:<<"over"
        steps/lmrescore.sh \
          --self-loop-scale 1.0 \
          --cmd "$decode_cmd" $datadir/lang \
        $datadir/${data}_hires ${dir}/decode_${data_affix} || exit 1
	  steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
          data/lang_test_bd_{tgpr,fgconst} \
       data/${data}_hires ${dir}/decode_${lmtype}_${data_affix}{,_fg} || exit 1
over
    	 )|| touch $dir/.error &
  	done
  	wait
  	[ -f $dir/.error ] && echo "$0: there was a problem while decoding" && exit 1
fi

# Not testing the 'looped' decoding separately, because for
# TDNN systems it would give exactly the same results as the
# normal decoding.

if $test_online_decoding && [ $stage -le 19 ]; then
	# note: if the features change (e.g. you add pitch features), you will have to
  	# change the options of the following command line.
  	steps/online/nnet3/prepare_online_decoding.sh \
    	  --mfcc-config conf/mfcc_hires.conf \
    	  $lang $expdir/nnet3${nnet3_affix}/extractor ${dir} ${dir}_online

  	rm ${dir}_online/.error 2>/dev/null || true

  	for data in $test_sets; do
    	(
		data_affix=$(echo $data | sed s/test_//)
	      	nspk=$(wc -l <data/${data}_hires/spk2utt)
	      	# note: we just give it "data/${data}" as it only uses the wav.scp, the
	      	# feature type does not matter.
	      	#for lmtype in tgpr bd_tgpr; do
			steps/online/nnet3/decode.sh \
		  	  --acwt 1.0 --post-decode-acwt 10.0 \
		  	  --nj $nspk --cmd "$decode_cmd" \
		  	$tree_dir/graph ${datadir}/${data} ${dir}_online/decode_${data_affix} || exit 1
      		#done
      		steps/lmrescore.sh \
        	  --self-loop-scale 1.0 \
        	  --cmd "$decode_cmd" data/lang_test_{tgpr,tg} \
        	${datadir}/${data}_hires ${dir}/decode_${data_affix} ${dir}_online/decode_${data_affix} || exit 1
      		steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
        	  ${datadir}/lang  ${datadir}/lang \
       		  ${datadir}/${data}_hires ${dir}/decode_${data_affix} ${dir}_online/decode_${data_affix} || exit 1
    	) || touch ${dir}_online/.error &
  	done
  	wait
  	[ -f ${dir}_online/.error ] && echo "$0: there was a problem while decoding" && exit 1
fi


# if [[ $stage -le 20 ]]; then
# 	main_dir=/speech/datasets/Hindi_English_Tamil_ASR_Challenge_June_2021/Hindi
# 	test_dir=/tts/cs20s029/hindi_english_tamil_asr_challenge/Hindi_ASR_Challenge/asr/data/eval   # directory having the wav.scp and utt2spk files
# 	data_folder=/tts/cs20s029/hindi_english_tamil_asr_challenge/Hindi_ASR_Challenge/asr/data
# 	home_dir=`pwd`

# 	bl_test_sets="eval"
#  <<"over"
# 	local/eval_data_prep.sh ${main_dir}/Audio/ $main_dir $home_dir

# 	# get the spk2utt from utt2spk
# 	utils/utt2spk_to_spk2utt.pl ${test_dir}/utt2spk > ${test_dir}/spk2utt

# 	# copy decoding metadata to another directory and validate
# 	utils/copy_data_dir.sh $test_dir ${test_dir}_hires

# 	for datadir in ${bl_test_sets}; do
# 	    steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
# 	      --cmd "$train_cmd" $data_folder/${datadir}_hires
# 	    steps/compute_cmvn_stats.sh $data_folder/${datadir}_hires
# 	    utils/fix_data_dir.sh $data_folder/${datadir}_hires
# 	done

# 	for data in ${bl_test_sets}; do
# 	    #nspk_nj=$(wc -l <$data_folder/${data}_hires/spk2utt)
# 	    nspk_nj=10
# 	    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "${nspk_nj}" \
# 	      $data_folder/${data}_hires ${exp_dir}/nnet3${nnet3_affix}/extractor \
# 	      ${exp_dir}/nnet3${nnet3_affix}/ivectors_${data}_hires
# 	done
# over

# 	frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
#   	rm $dir/.error 2>/dev/null || true

#   for data in ${bl_test_sets}; do
    	
#       		#data_affix=$(echo $data | sed s/test_//)
#       		#nspk=$(wc -l <$data_folder/${data}_hires/spk2utt)
#       		nspk=10
#       		#for lmtype in tgpr bd_tgpr; do
#         	(
#                 steps/nnet3/decode.sh \
#           	  --acwt 1.0 --post-decode-acwt 10.0 \
#           	  --extra-left-context 0 --extra-right-context 0 \
#           	  --extra-left-context-initial 0 \
#           	  --extra-right-context-final 0 \
#           	  --frames-per-chunk $frames_per_chunk \
#           	  --nj $nspk --cmd "$decode_cmd"  --num-threads 4 \
#           	  --online-ivector-dir $expdir/nnet3/ivectors_${data}_hires \
#           	  $tree_dir/graph $data_folder/${data}_hires ${dir}/decode_${data} || exit 1
#       		#done

#  <<"over"
#         steps/lmrescore.sh \
#           --self-loop-scale 1.0 \
#           --cmd "$decode_cmd" $datadir/lang \
#         $datadir/${data}_hires ${dir}/decode_${data_affix} || exit 1
# 	  steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
#           data/lang_test_bd_{tgpr,fgconst} \
#        data/${data}_hires ${dir}/decode_${lmtype}_${data_affix}{,_fg} || exit 1
# over
			
# 				#steps/get_ctm.sh $test_dir $tree_dir/graph ${dir}/decode_${data}

# 				#lattice-best-path ark:'gunzip -c ${exp_dir}/chain/tdnn${affix}_sp/decode_eval/lat.1.gz |' 'ark,t:|int2sym.pl -f 2- ${exp_dir}/chain/tree_a_sp/graph/words.txt > ${exp_dir}/chain/tdnn${affix}_sp/decode_eval/decoded_text.txt'

# 			run.pl LMWT=15 ${exp_dir}/chain${nnet3_affix}/tdnn${affix}_sp/decode_eval/scoring_kaldi/penalty_0.5/log/best_path.LMWT.log \
# 					lattice-scale --inv-acoustic-scale=LMWT "ark:gunzip -c ${exp_dir}/chain${nnet3_affix}/tdnn${affix}_sp/decode_eval/lat.*.gz|" ark:- \| \
# 					lattice-add-penalty --word-ins-penalty=0.5 ark:- ark:- \| \
# 					lattice-best-path --word-symbol-table=${exp_dir}/chain${nnet3_affix}/tree_a_sp/graph/words.txt ark:- ark,t:- \| \
# 					utils/int2sym.pl -f 2- ${exp_dir}/chain${nnet3_affix}/tree_a_sp/graph/words.txt \| \
# 					cat '>' ${exp_dir}/chain${nnet3_affix}/tdnn${affix}_sp/decode_eval/decoded_text.txt
				
#     	 )|| touch $dir/.error &
#   done
#   	wait
#   	[ -f $dir/.error ] && echo "$0: there was a problem while decoding" && exit 1

# fi

for x in $expdir/chain*/tdnn*_sp/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done
for x in $expdir/chain*/tdnn*_sp/decode*; do [ -d $x ] && grep SER $x/wer_* | utils/best_wer.sh; done

exit 0;
