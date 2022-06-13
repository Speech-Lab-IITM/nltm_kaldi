#!/usr/local/bin/perl

$txt=$ARGV[0];
%lexicon={};
%phones={};

$textdata="";

open($text,"<$txt");
while($line =<$text>){
	#print "line : $line\n";
	my ($uttid,$data)=split(/"/,$line);
    $data =~ s/"(.*?)"/$1/s;
    $uttid =~ s/\(//s;
    $uttid =~ s/^\s+|\s+$//g;
    $data =~ s/[#%&\$*+()!?\.\,\']//g;
	$data =~ s/-//g;
    $data =~ s/\s+/ /g;
    @words =  split(/ /, $data);
    $textdata=$textdata."$uttid ";
    foreach $word(@words)
    {
    	if(length($word)>0){
	    	#print "word : $word\n";
	    	system("bash get_phone_mapped_text.sh $word");
	    	if(open(F2, "<wordpronunciation")){
				while(<F2>) {
					chomp;
					$_ =~ s/\(set\! wordstruct \'\(//g;
					$_ =~ s/\)//g;
					$_ =~ s/[0 ]//g;
					$_ =~ s/\(//g;
					$_ =~ s/\"\"/ /g;
					$_ =~ s/\"//g;
					$comb = $_;
					$comb =~ s/ //g;
					$lexicon{$comb}=$_;
					chomp($comb);
					$textdata=$textdata."$comb ";
					#print "$_\t$comb \n";
					@monos =  split(/ /, $_);
					foreach $mono(@monos){
						$phones{$mono}=1;
						#print "$mono\n";
					}
				}
				close(F2);
			}	
		}
		
    }
    $textdata=$textdata."\n";
}
close($txt);
open($textdatafile,">data/text");
print $textdatafile $textdata;
close($textdatafile);
