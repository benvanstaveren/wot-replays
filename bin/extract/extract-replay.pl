#!/usr/bin/perl
use strict;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use WR::Parser::LLFile;
use Crypt::Blowfish;
use IO::File;
use Compress::Zlib;

use constant WOT_BF_KEY_STR => 'DE 72 BE A0 DE 04 BE B1 DE FE BE EF DE AD BE EF';
use constant WOT_BF_KEY     => join('', map { chr(hex($_)) } (split(/\s/, WOT_BF_KEY_STR)));

print 'key length: ', length(WOT_BF_KEY), "\n";

my $parser = WR::Parser::LLFile->new(file => $ARGV[0]);
my $bf = Crypt::Blowfish->new(WOT_BF_KEY);

$parser->save_data(to => sprintf('%s.extracted', $ARGV[0]));

my $in  = IO::File->new(sprintf('%s.extracted', $ARGV[0]));
my $out = IO::File->new(sprintf('>%s.decrypted', $ARGV[0]));

$in->binmode(1);
$out->binmode(1);

my $buffer;
while(my $bread = $in->read($buffer, 8)) {
    # padding should sort this out, yes?
    my $d = $bf->decrypt($buffer);
    $out->write($d);
}
$in->close();
$out->close();

$in = IO::File->new(sprintf('%s.decrypted', $ARGV[0]));
$in->binmode(1);

my $decrypted_content;
while(my $bread = $in->read($buffer, 1024)) {
    $decrypted_content .= $buffer;
}

# attempt to decompress shit
my $raw = uncompress($decrypted_content);

