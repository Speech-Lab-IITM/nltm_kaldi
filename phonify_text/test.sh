#!/bin/bash
echo $1 > passed_from_lexicon

#locale -a >> passed_from_lexicon
abc=`cat passed_from_lexicon`	
valagrind unified-parser $abc 1 0 0 0 >> passed_from_lexicon
