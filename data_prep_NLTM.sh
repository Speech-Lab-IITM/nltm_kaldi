#!/bin/bash

#Usage: data_prep_NLTM.sh data_in_espnet_format home_directory_where_you_want_the_data_folder

espnet_dir=$1
home_dir=$2
curr_dir=`pwd`

if [ -d ${home_dir}/data ]; then
      rm -r ${home_dir}/data
fi
# rm -r ${home_dir}/data
mkdir -p "${home_dir}/data"
cp -r ${espnet_dir}/* ${home_dir}/data/

# cat ${home_dir}/data/train/text ${home_dir}/data/dev/text ${home_dir}/data/test/text > ${home_dir}/cumulative_text
cp ${home_dir}/data/train/text ${home_dir}/cumulative_text
ids=$(awk '{print $1}' ${home_dir}/cumulative_text)
ext_ids=$(sed 's/\t/@/1' ${home_dir}/cumulative_text | awk 'BEGIN{FS="@"} {print $1}')
if [ "$ids" = "$ext_ids" ]; then
    c=1

    else
        c=2
fi

if [ $c -eq 1  ]; then
    sed 's/\t/@/1' ${home_dir}/cumulative_text | awk 'BEGIN{FS="@"} {print $2}' > ${home_dir}/just_transcription

    elif [ $c -eq 2  ]; then
        sed 's/ /@/1' ${home_dir}/cumulative_text | awk 'BEGIN{FS="@"} {print $2}' > ${home_dir}/just_transcription
fi

# sed 's/ /@/1' ${home_dir}/cumulative_text | awk 'BEGIN{FS="@"} {print $2}' > ${home_dir}/just_transcription
rm ${home_dir}/cumulative_text
grep -o -E '\w+' just_transcription | sort -u -f > uniq_word_list
num_uniq_words=`wc -l uniq_word_list | awk '{print $1}'`
rm ${home_dir}/just_transcription
awk '{printf("test_%04d %s\n", NR, $0)}' ${home_dir}/uniq_word_list > ${home_dir}/phonify_text/format_word_text
rm ${home_dir}/uniq_word_list
cd ${home_dir}/phonify_text
bash format_e2e_to_festival.sh format_word_text
rm format_word_text
perl text_lexicon.pl txt.done.data
rm txt.done.data
sed 's/ /@/1' data/text | awk 'BEGIN{FS="@"} {print $2}' | sed 's/ /\t/1' | sed 's/\s*$//' > ${home_dir}/data/lexicon.txt
cd $curr_dir

mkdir -p "${home_dir}/data/local/dict"
mv ${home_dir}/data/lexicon.txt ${home_dir}/data/local/dict/lexicon.txt
num_lex_entries=`wc -l ${home_dir}/data/local/dict/lexicon.txt | awk '{print $1}'`

if [ $num_uniq_words -ne $num_lex_entries  ]; then
    echo "All the unique words do not seem to have the phone split in the lexicon file"
fi

echo '!SIL   SIL' >> ${home_dir}/data/local/dict/lexicon.txt

cat ${home_dir}/data/local/dict/lexicon.txt | awk '{for(n=2;n<=NF;n++) seen[$n]=1; } END{print "SIL"; for (w in seen) { print w; }}' \
 >${home_dir}/data/local/dict/phone.list

echo SIL > ${home_dir}/data/local/dict/silence_phones.txt
echo SIL > ${home_dir}/data/local/dict/optional_silence.txt
grep -v -w SIL ${home_dir}/data/local/dict/phone.list > ${home_dir}/data/local/dict/nonsilence_phones.txt
touch ${home_dir}/data/local/dict/extra_questions.txt # list of "extra questions"-- empty; we don't
