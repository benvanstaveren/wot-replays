package WR::Parser;
use Mojo::Base 'WR::Parser::Base';
use Module::Load;

sub version_to_numeric {
    my $self = shift;
    my $v    = shift;

    # you would imagine that a simple , separator would work, but... WG fucked up. Again.
    my @ver = split(/\,/, $v);
    shift(@ver);
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

    return $wgfix[0] * 10000 + $wgfix[1] * 100 + $wgfix[2];
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
    load($monkey_patch_module);

    our @ISA = ( $monkey_patch_module ); # clobber the fuck out of that

    return $self;
}

1;
