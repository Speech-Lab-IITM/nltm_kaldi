

# Copyright 2020  Vishwas M Shetty

# Code to extract zipped wav files
# The final expected data structure:
# NPTEL_IITM_English_Challenge/Train_Dev
# --> transcription_dictionary
#   --> Trans_and_dict 
# --> wav
#   --> IITM/<wav files>
#   --> NPTEL/<course ids>/<wav files>

#Usage: data_prep_IIT.sh /home/vishwas/NPTEL_IITM_English_Challenge/Train_Dev/wav /home/vishwas/NPTEL_IITM_English_Challenge/Train_Dev/transcription_dictionary/Trans_and_dict

audio_dir=$1  # "Absolute" path to NPTEL_IITM_English_Challenge/Train_Dev/wav
data=$2     # "Absolute" path to NPTEL_IITM_English_Challenge/Train_Dev/transcription_dictionary/Trans_and_dict
home_dir=$3

#NOTE: the files should be named "train_NPTEL_IITM", "dev_IITM" and "dev_NPTEL". If giving others names please update the arguments below.
train_set=train  #train_NPTEL_IITM
recog_sets="dev"  #"dev_IITM dev_NPTEL"

for i in $train_set $recog_sets; do
    mkdir -p "${home_dir}/data/${i}"
done

mkdir -p "${home_dir}/data/local"
cp -r ${data}/dictionary/ ${home_dir}/data/local/
mv ${home_dir}/data/local/dictionary ${home_dir}/data/local/dict
mv ${home_dir}/data/local/dict/Hindi_lexicon.txt ${home_dir}/data/local/dict/lexicon.txt

#sed -i 's/<Noise\/>/!SIL/1' ${home_dir}/data/local/dict/lexicon.txt
echo '!SIL   SIL' >> ${home_dir}/data/local/dict/lexicon.txt

cat ${home_dir}/data/local/dict/lexicon.txt | awk '{for(n=2;n<=NF;n++) seen[$n]=1; } END{print "SIL"; for (w in seen) { print w; }}' \
 >${home_dir}/data/local/dict/phone.list

echo SIL > ${home_dir}/data/local/dict/silence_phones.txt
echo SIL > ${home_dir}/data/local/dict/optional_silence.txt
grep -v -w SIL ${home_dir}/data/local/dict/phone.list > ${home_dir}/data/local/dict/nonsilence_phones.txt
touch ${home_dir}/data/local/dict/extra_questions.txt # list of "extra questions"-- empty; we don't
 # have things like tone or word-positions or stress markings.

for x in train dev; do
    for y in segments spk2utt text utt2dur utt2spk wav.scp; do
        cp ${data}/transcription/${x}_Hindi/${y} ${home_dir}/data/${x}/
    done
done

# updating wav.scp with the absolute path to downloaded wav file directory. Optional
for folder in $train_set $recog_sets; do
    sed -i 's|Audio\/|'${audio_dir}'|g' ${home_dir}/data/${folder}/wav.scp
done