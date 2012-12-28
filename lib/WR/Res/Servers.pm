package WR::Res::Servers;
use Moose;
use namespace::autoclean;

with 'WR::Role::Catalog';

__PACKAGE__->meta->make_immutable;
