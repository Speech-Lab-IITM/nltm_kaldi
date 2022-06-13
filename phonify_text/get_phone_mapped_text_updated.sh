#!/bin/bash

word=$1
valgrind ./unified-parser $word 1 0 0 0

sed -i 's/"aa"/"A"/g' wordpronunciation
sed -i 's/"ii"/"I"/g' wordpronunciation
sed -i 's/"uu"/"U"/g' wordpronunciation
sed -i 's/"ee"/"E"/g' wordpronunciation
sed -i 's/"oo"/"O"/g' wordpronunciation
sed -i 's/"nn"/"N"/g' wordpronunciation

sed -i 's/"ae"/"ऍ"/g' wordpronunciation
sed -i 's/"ag"/"ऽ"/g' wordpronunciation

sed -i 's/"au"/"औ"/g' wordpronunciation
sed -i 's/"axx"/"अ"/g' wordpronunciation
sed -i 's/"ax"/"ऑ"/g' wordpronunciation
sed -i 's/"bh"/"B"/g' wordpronunciation
sed -i 's/"ch"/"C"/g' wordpronunciation
sed -i 's/"dh"/"ध"/g' wordpronunciation
sed -i 's/"dx"/"ड"/g' wordpronunciation
sed -i 's/"dxh"/"ढ"/g' wordpronunciation
sed -i 's/"dxhq"/"T"/g' wordpronunciation
sed -i 's/"dxq"/"D"/g' wordpronunciation
sed -i 's/"ei"/"ऐ"/g' wordpronunciation
sed -i 's/"ai"/"ऐ"/g' wordpronunciation
sed -i 's/"eu"/"உ"/g' wordpronunciation

sed -i 's/"gh"/"घ"/g' wordpronunciation
sed -i 's/"gq"/"G"/g' wordpronunciation
sed -i 's/"hq"/"H"/g' wordpronunciation
sed -i 's/"jh"/"J"/g' wordpronunciation
sed -i 's/"kh"/"ख"/g' wordpronunciation
sed -i 's/"khq"/"K"/g' wordpronunciation
sed -i 's/"kq"/"क"/g' wordpronunciation
sed -i 's/"ln"/"ൾ"/g' wordpronunciation
sed -i 's/"lw"/"ൽ"/g' wordpronunciation
sed -i 's/"lx"/"ള"/g' wordpronunciation
sed -i 's/"mq"/"M"/g' wordpronunciation
sed -i 's/"nd"/"न"/g' wordpronunciation
sed -i 's/"ng"/"ङ"/g' wordpronunciation
sed -i 's/"nj"/"ञ"/g' wordpronunciation
sed -i 's/"nk"/"Y"/g' wordpronunciation

sed -i 's/"nw"/"ൺ"/g' wordpronunciation
sed -i 's/"nx"/"ण"/g' wordpronunciation
sed -i 's/"ou"/"औ"/g' wordpronunciation
sed -i 's/"ph"/"P"/g' wordpronunciation
sed -i 's/"rq"/"R"/g' wordpronunciation
sed -i 's/"rqw"/"ॠ"/g' wordpronunciation
sed -i 's/"rw"/"ർ"/g' wordpronunciation
sed -i 's/"rx"/"र"/g' wordpronunciation
sed -i 's/"sh"/"श"/g' wordpronunciation

sed -i 's/"sx"/"ष"/g' wordpronunciation
sed -i 's/"th"/"थ"/g' wordpronunciation
sed -i 's/"tx"/"ट"/g' wordpronunciation
sed -i 's/"txh"/"ठ"/g' wordpronunciation
sed -i 's/"wv"/"W"/g' wordpronunciation
sed -i 's/"zh"/"Z"/g' wordpronunciation
