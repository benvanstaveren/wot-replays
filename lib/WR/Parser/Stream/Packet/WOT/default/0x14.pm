package WR::Parser::Stream::Packet::WOT::default::0x14;
use Mojo::Base 'WR::Parser::Stream::Packet';

sub version_wot_numeric {
    my $self = shift;
    my $v    = shift;
    # you would imagine that a simple , separator would work, but... WG managed to have 
    # this fuck up in 0.9.0 for some reason so... 

    my @ver = split(/\,/, $v);
    my @wgfix = ();
    while(@ver) {
        my $a = shift(@ver);
        $a =~ s/^\s+//g;
        $a =~ s/\s+$//g; 
        if($a =~ /\s+/) {
            push(@wgfix, (split(/\s+/, $a)));
        } else {
            push(@wgfix, $a);
        }
    }
    return $wgfix[0] * 1000000 + $wgfix[1] * 10000 + $wgfix[2] * 100 + $wgfix[3];
}

has 'version' => sub {
    my $self = shift;
    my $string = unpack('L/A', $self->payload);

    # string can contain either a fully specced string or that 0, 9, 1, 0 bit from newer replay
    # versions, we want to convert it to numeric
    # 0, 9, 0, 0
    # World of Tanks v.0.8.1 #305

    if($string =~ /World.*v\.(\d+)\.(\d+)\.(\d+) #\d+/) {
        $string = sprintf('%d, %d, %d, 0', $1, $2, $3);
    }

    return $self->version_wot_numeric($string);
};

sub BUILD {
    my $self = shift;

    $self->enable('version');

    return $self;
}

1;
   
