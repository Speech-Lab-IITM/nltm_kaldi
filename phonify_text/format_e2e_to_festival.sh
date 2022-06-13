# copy txt in e2e format as txt.done.data into this folder
#output - festival_txt.done.data (formatted version)
# sample usage: sh format_e2e_to_festival.sh "txt.done.data"

txtdonedata=$1
cp $txtdonedata txt.done.data
awk '{print $1}' $txtdonedata > header
awk '{$1=""; print $0}' $txtdonedata > only_text
paste -d '~' header only_text | sed 's/~/ \"/' > txt.done.data
sed  -i 's/^/( /g' txt.done.data
sed  -i 's/$/ " )/g' txt.done.data
#sed -i 's/	/ " /2' txt.done.data
