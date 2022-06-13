
audio_dir=$1  # "Absolute" path to NPTEL_IITM_English_Challenge/Train_Dev/wav
data=$2     # "Absolute" path to NPTEL_IITM_English_Challenge/Train_Dev/transcription_dictionary/Trans_and_dict
home_dir=$3

eval_set=eval

mkdir -p "${home_dir}/data/${eval_set}"

for x in eval; do
    for y in segments spk2utt utt2dur utt2spk wav.scp; do
        cp ${data}/transcription/${x}_Hindi/${y} ${home_dir}/data/${x}/
    done
done

# updating wav.scp with the absolute path to downloaded wav file directory. Optional
for folder in $eval_set; do
    sed -i 's|Audio\/|'${audio_dir}'|g' ${home_dir}/data/${folder}/wav.scp
done
