package WR::XMLReader;
use Moose;
use namespace::autoclean;
use IO::File;
use Data::Dumper;
use boolean;

use constant SEEK_SET => 0;
use constant SEEK_CUR => 1;
use constant SEEK_END => 2;

use constant PACKED_HEADER => 0x62a14e45;
use constant INT_TO_BASE_64 => [ 'A'..'Z', 'a'..'z', '0'..'9', '+', '/' ];

has 'filename' => (is => 'ro', isa => 'Str', required => 1);
has 'fh'       => (is => 'ro', isa => 'IO::File', required => 1, lazy => 1, builder => '_build_fh');

our $LEVEL = 0;

sub log {
    my $self = shift;

    print "\t" x $LEVEL, join(' ', @_), "\n";
}

sub die {
    my $self = shift;

    die "\t" x $LEVEL, join(' ', @_), "\n";
}

sub _build_fh {
    my $self = shift;

    if(my $fh = IO::File->new($self->filename)) {
        $fh->binmode(':raw');
        return $fh;
    } else {
        $self->die('Could not open ', $self->filename, ': ', $!);
    }
}

sub read_asciiz {
    my $self = shift;
    my $str  = '';
    my $c    = -1;

    $self->log('read_asciiz');

    while($c != 0) {
        if(my $r = $self->fh->read(my $buf, 1)) {
            $c = ord($buf);
            $str .= $buf if($c > 0);
        } else {
            return undef;
        }
    }

    $self->log('read_asciiz: result: ', $str);

    return $str;
}

sub read_dictionary {
    my $self = shift;
    my $dict = [];

    $self->log('read_dictionary');

    while(my $str = $self->read_asciiz()) {
        push(@$dict, $str);
    }

    $self->log('read_dictionary: result: [', join(', ', @$dict), ']');

    return $dict;
}

sub read_data_descriptor {
    my $self = shift;
    my $buf;

    $self->log('read_data_descriptor');
   
    if($self->fh->read($buf, 4)) {
        my $self_end_and_type = unpack('L<', $buf);
    
        $self->die('read_data_descriptor: end_and_type undef, buf is: [', $buf, ']') unless(defined($self_end_and_type));

        my $desc = {
            end => $self_end_and_type & 0x0fffffff, 
            type => ($self_end_and_type >> 28) + 0,

            address => $self->fh->tell(),
        };

        $self->log('read_data_descriptor: result: address: ', $desc->{address}, ' end: ', $desc->{end});
        return $desc;
    } else {
        $self->die('read_data_descriptor: read failed');
    }
}

sub read_element_descriptors {
    my $self = shift;
    my $num  = shift;
    my $list = [];
    my $buf;

    $self->log('read_element_descriptors');

    while($num-- > 0) {
        if($self->fh->read( $buf, 2)) {
            my $name_index = unpack('v*', $buf);
            my $descriptor = $self->read_data_descriptor();
            push(@$list, {
                name_index => $name_index,
                descriptor => $descriptor,
            });
        } else {
            $self->die('read_element_descriptors: read failed');
        }
    }
    return $list;
}

sub read_data {
    my $self = shift;
    my $dict = shift;
    my $element = shift;
    my $offset = shift;
    my $descriptor = shift;

    $self->log('read_data');

    my $length = $descriptor->{end} - $offset;

    $self->log('read_data: descriptor->start: ', $descriptor->{address}, ' fh->tell: ', $self->fh->tell, ' descriptor->end: ', $descriptor->{end}, ' offset: ', $offset, ' length: ', $length);

    if($descriptor->{type} == 0x0) {
        $self->read_element($dict, $element);
    } elsif($descriptor->{type} == 0x1) {
        $element->{text} = $self->read_string($length);
    } elsif($descriptor->{type} == 0x2) {
        $element->{text} = $self->read_number($length);
    } elsif($descriptor->{type} == 0x3) {
        $element->{text} = $self->read_float($length);
    } elsif($descriptor->{type} == 0x4) {
        $element->{text} = $self->read_boolean($length);
    } elsif($descriptor->{type} == 0x5) {
        $element->{text} = $self->read_base64($length);
    } else {
        $self->die('unknown element type: ', $descriptor->{type});
    }
    return $descriptor->{end}; 
}

sub parse {
    my $self = shift;
    my $fname = shift;
    my $buf;

    $self->fh->seek(0, SEEK_SET);
    $self->fh->read($buf, 4);
    my $header = unpack('I', $buf);

    $self->die('Not a packed XML file') unless($header == PACKED_HEADER);

    $self->fh->seek(5, SEEK_SET);

    $self->log('start');
    my $dict = $self->read_dictionary();
    my $root = {};
    $self->read_element($dict, $root);
    $self->log('done');
    return $root;
}

sub read_string {
    my $self = shift;
    my $len  = shift;
    my $str;

    $self->log('read_string');
   
    $self->fh->read($str, $len);

    $self->log('read_string: result: ', $str);

    return $str;
}

sub byte_array_to_base_64 {
    my $self = shift;
    my $barr = shift;
    my $len  = scalar(@$barr);
    my $num_full_groups = int($len / 3);
    my $num_bytes_in_partial_group = int($len - 3 * $num_full_groups);
    my $res = '';

    my $in_cursor = 0;
    for(my $i = 0; $i < $num_full_groups; $i++) {
        my $byte0 = $barr->[$in_cursor++] & 0xff; 
        my $byte1 = $barr->[$in_cursor++] & 0xff; 
        my $byte2 = $barr->[$in_cursor++] & 0xff; 

        $res .= $self->INT_TO_BASE_64->[$byte0 >> 2];
        $res .= $self->INT_TO_BASE_64->[ ($byte0 << 4) & 0x3f | ($byte1 >> 4) ];
        $res .= $self->INT_TO_BASE_64->[ ($byte1 << 2) & 0x3f | ($byte2 >> 6) ];
        $res .= $self->INT_TO_BASE_64->[ $byte2 & 0x3f ];
    }

    if($num_bytes_in_partial_group != 0) {
        my $byte0 = $barr->[$in_cursor++] & 0xff;
        $res .= $self->INT_TO_BASE_64->[$byte0 >> 2];

        if($num_bytes_in_partial_group == 1) {
            $res .= $self->INT_TO_BASE_64->[($byte0 << 4) & 0x3f];
            $res .= '==';
        } else {
            my $byte1 = $barr->[$in_cursor++] & 0xff;
            $res .= $self->INT_TO_BASE_64->[ ($byte0 << 4) & 0x3f | ($byte1 >> 4) ];
            $res .= $self->INT_TO_BASE_64->[ ($byte1 << 2) & 0x3f ];
            $res .= '=';
        }
    }
    return $res;
}

sub read_little_endian_float {  
    my $self = shift;
    
    $self->fh->read(my $buf, 4);
    return unpack('f<', $buf);
}

sub read_float {
    my $self = shift;
    my $len  = shift;
    my $n    = int($len/4);
    my $res  = '';
        
    for(my $i = 0; $i < $n; $i++) {
        if($i != 0) {
            $res .= ' ';
        }
        $res .= sprintf('%.f', $self->read_little_endian_float());
    }
    return $res;
}

sub read_base64 {
    my $self = shift;
    my $len  = shift;

    $self->log('read_base64');
    $self->fh->read(my $tmp, $len);
    return $self->byte_array_to_base_64([ split(//, $tmp) ]);
}

sub read_number {
    my $self = shift;
    my $len  = shift;

    $self->log('read_number');
   
    $self->fh->read(my $buf, $len);
    if($len == 1) {
        return unpack('c<', $buf);
    } elsif($len == 2) {
        return unpack('S<', $buf);
    } elsif($len == 4) {
        return unpack('L<', $buf);
    }
}

sub read_boolean {
    my $self = shift;
    my $len  = shift;

    $self->log('read_boolean');

    if($len == 1) {
        $self->fh->read(my $buf, $len);
        my $b = unpack('C<', $buf);
        return true if($b == 1);
        $self->die('boolean error');
    } else {
        return 0;
    }
}

sub read_element {
    my $self = shift;
    my $dict = shift;
    my $element = shift;
    my $buf;

    $LEVEL++;

    $self->log('read_element');

    $self->fh->read($buf, 2);

    my $children_number = unpack('S<', $buf);

    $self->log('read_element: have ', $children_number, ' children');

    my $data_descriptor = $self->read_data_descriptor();
    my $children = $self->read_element_descriptors($children_number);

    if($children_number > 0) {
        my $offset = $self->read_data($dict, $element, 0, $data_descriptor);
        $self->log('read data, new offset: ', $offset);
        my $cc = 0;
        foreach my $c (@$children) {
            my $node = {};
            $self->log('reading child: ', ++$cc);
            $offset = $self->read_data($dict, $node, $offset, $c->{descriptor});

            # fix the node 
            if(scalar(keys(%$node)) == 1 && defined($node->{text})) {
                $element->{$dict->[$c->{name_index}]} = $node->{text};
            } else {
                $element->{$dict->[$c->{name_index}]} = $node;
            }
        }
    } else {
        $self->log('no children?');
    }

    $LEVEL--;
}

__PACKAGE__->meta->make_immutable;
