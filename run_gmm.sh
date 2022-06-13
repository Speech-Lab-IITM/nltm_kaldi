#!/bin/bash

# Copyright 2013  Bagher BabaAli

#Set the following flags = 1 to run that particular block of code
data_prep=0
prepare_lang=1
mfcc=1
mono=1
tri1=1
tri2=1
tri3=1

dumpdir=`pwd`    #path to store features generated 
data=data
espnet_dir=esp_data
home_dir=`pwd`

train_set=train
dev_set="dev"
recog_sets="dev test"
tag=trial     #experiment tag, so that models are not overwritten; make sure change this if running a new experiment.
expdir=exp_${tag}   

train_cmd=run.pl
decode_cmd=run.pl
decode_nj=32
train_nj=64

. ./utils/parse_options.sh

if [ $data_prep -eq 1 ]; then  
echo ============================================================================
echo "                 Data preparation                      "
echo ============================================================================           

	./data_prep_NLTM.sh $espnet_dir $home_dir

fi

. ./cmd.sh 
[ -f path.sh ] && . ./path.sh

if [ $prepare_lang -eq 1 ]; then  
echo ============================================================================
echo "                 Language model preparation                      "
echo ============================================================================           
	
	# Prepare language model	
	utils/prepare_lang.sh $data/local/dict \
		"!SIL" $data/local/lang $data/lang || exit 1;      

	bash utils/train_lms_srilm.sh $data/$train_set $data/$dev_set $data $data/local/lmDir
	bash utils/arpa2G.sh $data/local/lmDir/lm.gz $data/lang $data/lang
fi

if [ $mfcc -eq 1 ]; then
echo ============================================================================
echo "         MFCC Feature Extration & CMVN for Training and test set           "
echo ============================================================================

	# Now make MFC features.
	# mfccdir=$dumpdir/mfcc_$data
	mfccdir=$dumpdir/mfcc
	for x in $train_set $recog_sets; do 
		steps/make_mfcc.sh --cmd "$train_cmd" --nj "$train_nj" $data/$x $expdir/make_mfcc/$x $mfccdir/$x || exit 1;
	 	steps/compute_cmvn_stats.sh $data/$x $expdir/make_mfcc/$x $mfccdir/$x || exit 1;
	 	utils/fix_data_dir.sh $data/$x || exit 1;
	done
fi

if [ $mono -eq 1 ]; then
echo ============================================================================
echo "                     MonoPhone Training & Decoding                        "
echo ============================================================================

	steps/train_mono.sh  --nj "$train_nj" --cmd "$train_cmd" $data/$train_set $data/lang $expdir/mono || exit 1;
	utils/mkgraph.sh $data/lang $expdir/mono $expdir/mono/graph || exit 1;
  	# steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
    #   $expdir/mono/graph $data/dev $expdir/mono/decode

	for x in $recog_sets; do
		steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
	        $expdir/mono/graph $data/$x $expdir/mono/decode_$x || exit 1;
	done
fi


if [ $tri1 -eq 1 ]; then
echo ============================================================================
echo "           tri1 : Deltas + Delta-Deltas Training & Decoding               "
echo ============================================================================

	steps/align_si.sh --boost-silence 1.28 --nj "$train_nj" --cmd "$train_cmd" $data/$train_set $data/lang $expdir/mono $expdir/mono_ali || exit 1;
	
	# Train tri1, which is deltas + delta-deltas, on train data.
	# Change senones and gauss values to what you want to try with
	for sen in 7000; do
		for gauss in  20; do
			gauss=$(($sen * $gauss))
			steps/train_deltas.sh --cmd "$train_cmd" $sen $gauss $data/$train_set $data/lang $expdir/mono_ali $expdir/tri1_${sen}_${gauss} || exit 1;
	
			#decode happens in the background
		        #(
			utils/mkgraph.sh $data/lang $expdir/tri1_${sen}_${gauss} $expdir/tri1_${sen}_${gauss}/graph || exit 1;
			for x in $recog_sets; do
				steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
	        		$expdir/tri1_${sen}_${gauss}/graph $data/$x $expdir/tri1_${sen}_${gauss}/decode_$x || exit 1;
			done
		        #)&
		done
	done
fi


if [ $tri2 -eq 1 ];then
echo ============================================================================
echo "                 tri2 : LDA + MLLT Training & Decoding                    "
echo ============================================================================

	#Use the best tri1 model to get the tri1 alignments.
	#obtained for sen=2500, gauss=12
	#i.e. say tri1_1600_25600 gives the best WER, then use it here.
	steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
	$data/$train_set $data/lang $expdir/tri1_7000_140000 $expdir/tri1_ali || exit 1;
        
         # Change senones and gauss values to values you  want to try with 
	for sen in 7000; do
		for gauss2 in 20; do
			gauss2=$(($sen * $gauss2))
			steps/train_lda_mllt.sh --cmd "$train_cmd" \
			 --splice-opts "--left-context=3 --right-context=3" \
			$sen $gauss2 $data/$train_set $data/lang $expdir/tri1_ali $expdir/tri2_${sen}_${gauss2} || exit 1;
	
			#decode happens in the background
		     	#(
			utils/mkgraph.sh $data/lang $expdir/tri2_${sen}_${gauss2} $expdir/tri2_${sen}_${gauss2}/graph || exit 1;
			for x in $recog_sets; do
				steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
	 			$expdir/tri2_${sen}_${gauss2}/graph $data/$x $expdir/tri2_${sen}_${gauss2}/decode_$x || exit 1;
			done
			#)&	
		done
	done
fi


if [ $tri3 -eq 1 ];then
echo ============================================================================
echo "                 tri3 : LDA + MLLT + SAT Training & Decoding                    "
echo ============================================================================     

	#Use the best tri2 model to get the tri2 alignments.
	#i.e. say tri2_1600_25600 gives the best WER, then use it here.
	steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
	$data/$train_set $data/lang $expdir/tri2_7000_140000 $expdir/tri2_ali || exit 1

         # Change senones and gauss values to what you want to try with
	for sen in 7000; do
		for gauss2 in 20; do
			gauss2=$(($sen * $gauss2))
			steps/train_sat.sh --cmd "$train_cmd" $sen $gauss2 \
   			$data/$train_set $data/lang $expdir/tri2_ali $expdir/tri3_${sen}_${gauss2} || exit 1;                                           

			#decode happens in the background
			#(
			utils/mkgraph.sh $data/lang $expdir/tri3_${sen}_${gauss2} $expdir/tri3_${sen}_${gauss2}/graph || exit 1;
		        for x in $recog_sets; do
				steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" \
   				$expdir/tri3_${sen}_${gauss2}/graph $data/$x $expdir/tri3_${sen}_${gauss2}/decode_${x} || exit 1;
			done
			#)& 
		done
	done
fi

for x in $expdir/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done
for x in $expdir/*/decode*; do [ -d $x ] && grep SER $x/wer_* | utils/best_wer.sh; done

# for x in $expdir/chain*/tdnn*_sp/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done
# for x in $expdir/chain*/tdnn*_sp/decode*; do [ -d $x ] && grep SER $x/wer_* | utils/best_wer.sh; done
