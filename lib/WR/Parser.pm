package WR::Parser;
use Mojo::Base 'WR::Parser::Versions::Base';
use Module::Load;
use Try::Tiny qw/try catch/;

sub version_to_numeric {
    my $self = shift;
    my $v    = shift;

    # you would imagine that a simple , separator would work, but... WG fucked up. Again.
    my @ver = split(/\,/, $v);
    my @wgfix = ();
    while(@ver) {
        my $a = shift(@ver);
        $a =~ s/^\s+//g;
        $a =~ s/\s+$//g; # ffffuck
        if($a =~ /\s+/) {
            push(@wgfix, (split(/\s+/, $a)));
        } else {
            push(@wgfix, $a);
        }
    }

    return $wgfix[0] * 1000000 + $wgfix[1] * 10000 + $wgfix[2] * 100 + $wgfix[3];
}

sub new {
    my $package = shift;
    my $self    = $package->SUPER::new(@_);

    bless($self, $package);

    my $meta = $self->decode_block(1);
    my $v    = $self->version_to_numeric($meta->{'clientVersionFromExe'});

    $self->version($v);

    return $self if($v <= 81000);

    my $monkey_patch_module = sprintf('WR::Parser::Versions::v%d', $v);
    try {
        load($monkey_patch_module);
    } catch {
        die q|It seems there's no parser for this World of Tanks version (| . $v . q|); either this replay is too old, or it's too new!| . "\n";
    };
    our @ISA = ( $monkey_patch_module ); # clobber the fuck out of that
    return $self;
}

1;
