package WR::Util::Config;
use Mojo::Base '-base';
use Mojo::Util qw(decode slurp);
use WR::Util::HashTable;

sub load {
    my $package = shift;
    my $file    = shift;

    my $content = decode('UTF-8', slurp($file));
    my $config  = eval 'package WR::Util::Config::Sandbox; no warnings; use Mojo::Base -strict; ' . $content;
    die 'Could not load configuration from ', $file, ': ', $@ if(!$config && $@);
    die 'Configuration file ', $file, ' did not return a hash reference', "\n" unless(ref($config) eq 'HASH');
    return WR::Util::HashTable->new(data => $config);
}

1;
