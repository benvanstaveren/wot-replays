package WR::Parser::Stream::Packet::WOT::default::0xffffffff;
use Mojo::Base 'WR::Parser::Stream::Packet';
use mro 'c3';

sub BUILD { shift->maybe::next::method(@_) }

1;
