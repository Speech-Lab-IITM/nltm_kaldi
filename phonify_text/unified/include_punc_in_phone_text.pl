#!/usr/bin/perl

# Script to 
# Written by Anusha Prakash (21/6/2019)
# Input: txt_char (Kaldi text in characters- with commas), txt_phone (Kaldi text in phones- without commas)
# Output: txt_phone_with_comma (Kaldi text in phones- with commas)
# Run: perl include_commas_in_phone_text.pl

open(F1, "<txt_char");
my @line_char=<F1>;
close F1;

open(F2, "<txt_phone");
my @line_phone=<F2>;
close F2;

open(W, ">txt_phone_with_comma");

for($j=0; $j < @line_char; $j++){
	chomp($line_char[$j]);
	chomp($line_phone[$j]);
	@words_char = split(/ /, $line_char[$j]);
	@words_phone = split(/ /, $line_phone[$j]);
	for($i = 0; $i < @words_char; $i++) {
		if ($words_char[$i] =~ /,/) {
			$newWord = $words_phone[$i].',';
			print W "$newWord ";
		}
		elsif ($words_char[$i] =~ /\?/) {
			$newWord = $words_phone[$i].'?';
			print W "$newWord ";
		}
		elsif ($words_char[$i] =~ /!/) {
			$newWord = $words_phone[$i].'!';
			print W "$newWord ";
		}
		elsif ($words_char[$i] =~ /\./) {
			$newWord = $words_phone[$i].'.';
			print W "$newWord ";
		}
		else {
			print W "$words_phone[$i] ";
		}
	}
	print W "\n";
}

close W;
