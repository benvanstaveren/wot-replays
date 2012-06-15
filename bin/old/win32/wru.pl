#!perl
use strict;
use warnings;

# here so PAR::Packer can pick them up early
use Win32::GUI();
use Win32::GUI::BitmapInline ();
use Win32::TieRegistry ( Delimiter => q{/} );
use IO::File;
use Mojo::UserAgent;
use WRU::Core;
WRU::Core->new()->start();
