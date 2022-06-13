working_dir=$PWD 

#####Creating text in espnet format ####### 

awk '{printf("test_100_%04d %s\n", NR, $0)}' transcription > txt_final
bash format_e2e_to_festival.sh txt_final
