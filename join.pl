#!/usr/bin/perl


my $join_command="gs -dNOPAUSE -sDEVICE=pdfwrite -sPAPERSIZE=a4 -sOUTPUTFILE=<OUTPUTFILE> -dBATCH ";
my $outfile = $ARGV[-1];
$ARGV[-1] = "";
$join_command =~ s/<OUTPUTFILE>/$outfile/;

for $file (@ARGV) {
	$join_command = $join_command . " " . $file;
}
print $join_command;
$result=`$join_command`;
print $result;
