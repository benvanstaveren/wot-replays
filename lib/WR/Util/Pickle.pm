package WR::Util::Pickle;
use Mojo::Base '-base';
use Mango::BSON;
use IO::String;

has 'data'      =>  undef;
has 'fh'        =>  sub { my $self = shift; IO::String->new($self->data) };

use Scalar::Util qw/refaddr/;

use WR::Util::Pickle::None;

# this is a ghetto implementation of an unpickler, it expects a string of data in the 'data' attribute

has 'result'    => undef;
has 'stack'     => sub { [] };
has 'memo'      => sub { [] };
has 'bread'     => 0;

use constant PICKLE_OPS => {
    MARK        =>  '(',
    STOP        =>  '.',
    POP         =>  '0',
    POP_MARK    =>  '1',
    DUP         =>  '2',
    FLOAT       =>  'F',
    INT         =>  'I',
    BININT      =>  'J',
    BININT1     =>  'K',
    LONG        =>  'L',
    BININT2     =>  'M',
    NONE        =>  'N',
    PERSID      =>  'P',
    BINPERSID   =>  'Q',
    REDUCE      =>  'R',
    STRING      =>  'S',
    BINSTRING   =>  'T',
    SHORT_BINSTRING => 'U',
    UNICODE     =>  'V',
    BINUNICODE  =>  'X',
    APPEND      =>  'a',
    BUILD       =>  'b',
    GLOBAL      =>  'c',
    DICT        =>  'd',
    EMPTY_DICT  =>  '}',
    APPENDS     =>  'e',
    GET         =>  'g',
    BINGET      =>  'h',
    INST        =>  'i',
    LONG_BINGET =>  'j',
    LIST        =>  'l',
    EMPTY_LIST  =>  ']',
    OBJ         =>  'o',
    PUT         =>  'p',
    BINPUT      =>  'q',
    LONG_BINPUT =>  'r',
    SETITEM     =>  's',
    TUPLE       =>  't',
    EMPTY_TUPLE =>  ')',
    SETITEMS    =>  'u',
    BINFLOAT    =>  'G',
    TRUE        =>  'I01\n',
    FALSE       =>  'I00\n',
    PROTO       =>  "\x80",
    NEWOBJ      =>  "\x81",
    EXT1        =>  "\x82",
    EXT2        =>  "\x83",
    EXT4        =>  "\x84",
    TUPLE1      =>  "\x85",
    TUPLE2      =>  "\x86",
    TUPLE3      =>  "\x87",
    NEWTRUE     =>  "\x88",
    NEWFALSE    =>  "\x89",
    LONG1       =>  "\x8a",
    LONG4       =>  "\x8b",
};

use constant PICKLE_OPS_REVERSE => { map { __PACKAGE__->PICKLE_OPS->{$_} => $_ } (keys(%{__PACKAGE__->PICKLE_OPS})) };

sub push        { push(@{shift->stack}, shift) }
sub pop         { return pop(@{shift->stack}) }
sub at          { return shift->stack->[shift] }
sub set_at      { 
    my $self = shift;
    my $idx  = shift;
    my $val  = shift;

    $self->stack->[$idx] = $val;
}
sub is_mark     { shift and return (ref(shift) eq 'WR::Util::Pickle::Mark') ? 1 : 0 }
sub marker      { 
    my $self = shift;
    my $slen = scalar(@{$self->stack}) - 1;

    while($slen >= 0) {
        return $slen if($self->is_mark($self->at($slen)));
        $slen--;
    }
    die 'IndexError', "\n"; 
}

sub readline {
    my $self = shift;
    my $b;

    while($self->fh->read(my $c, 1)) {
        $self->bread($self->bread + 1);
        $b .= $c;
        return $b if(ord($c) == ord("\x0a"));
    }
    return undef;
}

sub unpickle { shift->load(@_) }
sub load {
    my $self = shift;

    $self->stack([]);
    $self->memo([]);
    $self->result(undef);

    while($self->fh->read(my $buf, 1)) {
        if(my $protoname = $self->PICKLE_OPS_REVERSE->{$buf}) {
            my $m = sprintf('handle_%s', $protoname);
            if($self->can($m)) {
                $self->$m();
            } else {
                die 'UnhandledOperation ', $protoname, "\n";
            }
            return $self->result if($protoname eq 'STOP');
        }
    }
    return undef; # signifies an EOF
}

sub handle_STOP {
    my $self = shift;

    $self->result($self->pop);
}

sub handle_PERSID           { die 'PERSID unsupported' }
sub handle_BINPERSID        { die 'BINPERSID unsupported' }
sub handle_INST             { die 'INST unsupported' }
sub handle_OBJ              { die 'OBJ unsupported' }
sub handle_NEWOBJ           { die 'NEWOBJ unsupported' }
sub handle_GLOBAL           { die 'GLOBAL unsupported' }
sub handle_REDUCE           { die 'REDUCE unsupported' }

sub handle_NONE             { shift->push(WR::Util::Pickle::None->new()) }
sub handle_NEWFALSE         { shift->push(Mango::BSON::bson_false) }
sub handle_NEWTRUE          { shift->push(Mango::BSON::bson_true) }

sub handle_INT { 
    my $self = shift;
    
    chomp(my $data = $self->readline);

    # python has this thing here for integers maybe being
    # booleans, however, fuck it

    $self->push($data + 0);
}

sub handle_BININT {
    my $self = shift;
    
    $self->fh->read(my $t, 4);
    $self->bread($self->bread + 4);
    $self->push(unpack('i', $t) + 0);
}

sub handle_BININT1 {
    my $self = shift;
    
    $self->fh->read(my $t, 1);
    $self->bread($self->bread + 1);
    $self->push(unpack('C', $t) + 0);
}

sub handle_BININT2 {
    my $self = shift;

    $self->fh->read(my $t, 2);
    $self->bread($self->bread + 2);
    $self->push(unpack('S', $t) + 0);
}

sub handle_LONG {
    my $self = shift;

    chomp(my $data = $self->readline);
    $self->push(substr($data, 0, length($data) - 1) + 0); # 21351235L ... drop the L off
}

sub handle_LONG1 {
    my $self = shift;
   
    $self->fh->read(my $t, 1);
    $self->bread($self->bread + 1);
    my $l = ord($t);
    $self->fh->read(my $b, $l);
    $self->bread($self->bread + $l);

    if(length($b) % 4 == 0) {
        # we need to pad it up 
        while(length($b) % 4 != 0) {
            $b .= "\x00";
        }
    }

    $self->push(unpack('l<', $b) + 0);
}

sub handle_LONG4 {
    my $self = shift;

    $self->fh->read(my $t, 4);
    $self->bread($self->bread + 4);
    my $l = unpack('i', $t);

    $self->fh->read(my $b, $l);
    $self->bread($self->bread + $l);

    if(length($b) % 4 == 0) {
        # we need to pad it up 
        while(length($b) % 4 != 0) {
            $b .= "\x00";
        }
    }
    $self->push(unpack('l<', $b) + 0);
}

sub handle_FLOAT {
    my $self = shift;

    chomp(my $data = $self->readline);
    $self->push($data + 0);
}

sub handle_BINFLOAT {
    my $self = shift;

    $self->fh->read(my $t, 8);
    $self->bread($self->bread + 8);
    $self->push(unpack('d>', $t) + 0);
}

sub handle_PROTO {
    my $self = shift;
    
    $self->fh->read(my $t, 1);
    $self->bread($self->bread + 1);
    my $v = ord($t);
    die 'unsupported protocol version', "\n" if($v < 0 || $v > 2);
}

sub handle_BINSTRING {
    my $self = shift;

    $self->fh->read(my $len, 4);
    $self->bread($self->bread + 4);
    $self->fh->read(my $string, unpack('i', $len));
    $self->bread($self->bread + unpack('i', $len));
    $self->push($string);
}

sub handle_SHORT_BINSTRING {
    my $self = shift;

    $self->fh->read(my $len, 1);
    $self->bread($self->bread + 1);
    $self->fh->read(my $string, unpack('C', $len));
    $self->bread($self->bread + unpack('C', $len));
    $self->push($string);
}

sub handle_STRING {
    my $self = shift;
    my $str  = $self->readline || die 'stringError', "\n";

    chomp($str); 
    $self->push($str);
}

sub handle_UNICODE { shift->handle_STRING }
sub handle_BINUNICODE { shift->handle_BINSTRING }

sub handle_TUPLE {
    my $self = shift;
    my $k = $self->marker();
    $self->set_at($k => [ splice(@{$self->stack}, $k + 1) ]);
}

sub handle_EMPTY_TUPLE { shift->push([]) }
sub handle_TUPLE1 {
    my $self = shift;
    $self->push([$self->pop]);
}

sub handle_TUPLE2 {
    my $self = shift;
    my $a = $self->pop;
    my $b = $self->pop;

    $self->push([$b, $a]);
}
    
sub handle_TUPLE3 {
    my $self = shift;
    my $a = $self->pop;
    my $b = $self->pop;
    my $c = $self->pop;

    $self->push([ $c, $b, $a ]);
}

sub handle_EMPTY_LIST { shift->push([]) };
sub handle_EMPTY_DICT { shift->push({}) };

sub handle_LIST {
    my $self = shift;
    my $k = $self->marker;

    $self->set_at($k => [ splice(@{$self->stack}, $k + 1) ]);
}

sub handle_DICT {
    my $self = shift;
    my $k = $self->marker;

    my $items = $self->stack->[$k+1];
    my $d = (defined($items)) ? { @{$items} } : {};
    splice(@{$self->stack}, $k);
    $self->push($d);
}

sub handle_EXT1 {
    my $self = shift;

    $self->fh->read(my $t, 1);
    $self->bread($self->bread + 1);
    $self->push(bless({v => $t}, 'WR::Util::Pickle::ExtensionCode1'));
}

sub handle_EXT2 {
    my $self = shift;

    $self->fh->read(my $t, 2);
    $self->bread($self->bread + 2);
    $self->push(bless({v => $t}, 'WR::Util::Pickle::ExtensionCode2'));
}

sub handle_EXT4 {
    my $self = shift;

    $self->fh->read(my $t, 4);
    $self->bread($self->bread + 4);
    $self->push(bless({v => $t}, 'WR::Util::Pickle::ExtensionCode4'));
}

sub handle_POP { shift->pop }

sub handle_POP_MARK {
    my $self = shift;
    my $k = $self->marker;

    splice(@{$self->stack}, $k);
}

sub handle_DUP {
    my $self = shift;
    my $value = $self->pop;

    $self->push($value);
    $self->push($value);
}
    
sub handle_GET {
    my $self = shift;
   
    chomp(my $i = $self->readline);
    $self->push($self->memo->[$i]);
}

sub handle_BINGET {
    my $self = shift;
    $self->fh->read(my $t, 1);
    $self->bread($self->bread + 1);
    $self->push($self->memo->[ord($t)]);
}

sub handle_LONG_BINGET {
    my $self = shift;
    $self->fh->read(my $t, 4);
    $self->bread($self->bread + 4);
    $self->push($self->memo->[unpack('L', $t)]);
}

sub handle_PUT {
    my $self = shift;
    chomp(my $i = $self->readline);
    $self->memo->[$i] = $self->stack->[-1];
}

sub handle_BINPUT {
    my $self = shift;

    $self->fh->read(my $idx, 1);
    $self->bread($self->bread + 1);
    # top of stack to memo at idx
    $self->memo->[unpack('C', $idx)] = $self->stack->[-1]; 
}

sub handle_LONG_BINPUT {
    my $self = shift;

    $self->fh->read(my $idx, 4);
    $self->bread($self->bread + 4);
    # top of stack to memo at idx
    $self->memo->[unpack('L', $idx)] = $self->stack->[-1]; 
}

sub handle_APPEND {
    my $self = shift;
    my $value = $self->pop;
    CORE::push(@{$self->stack->[-1]}, $value);
}

sub handle_APPENDS {
    my $self = shift;
    my $mark = $self->marker;

    my $list = $self->at($mark - 1);    # list is before the marker
    CORE::push(@$list, splice(@{$self->stack}, $mark + 1)); # and needs everything after the marker added
    $self->pop; # and we pop the marker off teh stack
}

sub _unbox { 
    my $self = shift;
    my $v    = shift;

    return $v if(ref($v));
    $v =~ s/^'//g;
    $v =~ s/'$//g;
    return $v;
}

sub handle_SETITEM {
    my $self = shift;
    my $v = $self->pop;
    my $k = $self->pop;

    # apparently python wraps this stuff in single quotes, so we want to undo that
    $self->stack->[-1]->{$self->_unbox($k)} = $self->_unbox($v);
}

sub handle_SETITEMS {
    my $self = shift;
    my $mark = $self->marker;

    my $h = $self->stack->[$mark - 1];
    my $v = { splice(@{$self->stack}, $mark + 1) };
    foreach my $key (keys(%$v)) {
        next unless(ref($h) && ref($v));
        $h->{$key} = $v->{$key};
    }
    $self->pop; # get rid of the mark
}

sub handle_BUILD {
    my $self = shift;
    my $state = $self->pop;
}

sub handle_MARK {
    my $self = shift;

    $self->push(bless({}, 'WR::Util::Pickle::Mark'));
}

1;
