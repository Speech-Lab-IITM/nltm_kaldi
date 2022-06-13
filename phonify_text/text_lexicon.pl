#!/usr/local/bin/perl

$txt=$ARGV[0];
%lexicon={};
%phones={};

$textdata="";

open($text,"<$txt");
while($line =<$text>){
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
	    	system("valgrind ./unified-parser   $word   1 0 0 0");
	    	
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
					$lexicon{$comb}=$_;
					chomp($comb);
					$textdata=$textdata.$word." $comb ";
					
					@monos =  split(/ /, $_);
					foreach $mono(@monos){
						$phones{$mono}=1;
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
