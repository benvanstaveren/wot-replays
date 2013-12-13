#!/usr/bin/perl
use strict;
use lib qw(lib ../lib ../../lib);
use JSON::XS;
use Data::Localize;
use Data::Localize::Gettext;
use File::Slurp qw/read_file/;
use Mango;

die 'Usage: mongo-components.pl <version>', "\n" unless($ARGV[0]);
my $version = $ARGV[0];

my $text = Data::Localize::Gettext->new(path => sprintf('../etc/res/raw/%s/lang/*_vehicles.po', $version));

my $mango  = Mango->new('mongodb://localhost:27017/');
my $db     = $mango->db('wot-replays');
my $coll   = $db->collection('data.components');

$coll->drop();

my $nations = {
    ussr => 0,
    germany => 1,
    usa => 2,
    china => 3,
    france => 4,
    uk => 5,
    japan => 6,
};

my $tc_names = [qw/reserved vehicle vehicleChassis vehicleTurret vehicleGun vehicleEngine vehicleFuelTank vehicleRadio tankman optionalDevice shell equipment/];
my $tc_id = {};
my $tc_n = {};

my $tc_map = { 
    chassis   => 'vehicleChassis',
    engines   => 'vehicleEngine',
    fueltanks => 'vehicleFuelTank',
    guns      => 'vehicleGun',
    radios    => 'vehicleRadio',
    turrets   => 'vehicleTurret',
};
 
my $i = 0;
foreach my $type (@$tc_names) {
    $tc_id->{$i} = $type;
    $i++;
}
$i = 0;
foreach my $type (@$tc_names) {
    $tc_n->{$type} = $i;
    $i++;
}

sub descr {
    my $name   = shift;
    my $nation = shift;
    my $item   = shift;

    my $tid = $tc_n->{$name} + 0;
    die 'tid = 0 for ', $name, ' nation ', $nation, ' item ', $item, "\n" if($tid == 0);
    my $header = $tid + ($nation << 4);
    my $desc = ($item << 8) + $header;
    return $desc;
}

my @nationlist = ($ARGV[1]) ? ( $ARGV[1] ) : (qw/japan china france germany usa ussr uk/);
my @comptype = ($ARGV[2]) ? ( $ARGV[2] ) : (qw/chassis engines fueltanks guns radios turrets/);

$| = 1;

my $j = JSON::XS->new();

sub fix_us {
    my $us = shift;

    if($us =~ /^#(.*?)\:(.*)/) {
        return $2;
    }
    return $us;
}

for my $country (@nationlist) {
    for my $comptype (@comptype) {
        my $f = sprintf('../../etc/res/raw/%s/components/%s_%s.json', $version, $country, $comptype);
        warn 'processing: ', $f, "\n";
        my $d = read_file($f);
        warn 'read', "\n";
        my $x = $j->decode($d);
        warn 'decode', "\n";

        my $ids = (defined($x->{ids})) ? $x->{ids} : $x;

        foreach my $name (keys(%$ids)) {
            next if($name eq 'text');
            my $id = $x->{ids}->{$name};
            next if($id eq '' || $id == 0);

            my $descr = descr($tc_map->{$comptype}, $nations->{$country}, $id);

            warn 'descr: ', $descr, "\n";

            my $data = {
                _id => $descr,
                country         => $country,
                component       => $comptype,
                component_id    => $id,
            };

            if(defined($x->{shared}) && ref($x->{shared}) && defined($x->{shared}->{$name})) {
                warn 'is shared', "\n";
                my $us   = $x->{shared}->{$name}->{userString};
                my $desc = $x->{shared}->{$name}->{description};

                warn 'label from: ', $us, ' - ', fix_us($us), "\n";
                $data->{label} = (defined($us)) 
                    ? $text->localize_for(lang => sprintf('%s_vehicles', $country), id => fix_us($us))
                    : (defined($name)) 
                        ? $text->localize_for(lang => sprintf('%s_vehicles', $country), id => $name)
                        : sprintf('nolabel:%s', $name);

                warn 'got label: ', $data->{label}, "\n";

                warn 'desc from: ', $desc, "\n";
                $data->{description} = (defined($desc)) ? $text->localize_for(lang => sprintf('%s_vehicles', $country), id => fix_us($desc)) : undef;
                
                if($comptype eq 'guns') {
                    $data->{shots} = [ keys(%{$x->{shared}->{$name}->{shots}}) ];
                }
                $data->{i18n} = $x->{shared}->{$name}->{userString};
            } else {
                warn 'label: from ', $name, "\n";
                $data->{label} = $text->localize_for(lang => sprintf('%s_vehicles', $country), id => $name);
                $data->{description} = '';
                $data->{i18n} = sprintf('#%s_vehicles:%s', $country, $name);
            }

            $coll->insert($data);
            
        }
    }

    my $f = sprintf('../../etc/res/raw/%s/components/%s_%s.json', $version, $country, 'shells');
    warn 'processing: ', $f, "\n";
    my $d = read_file($f);
    my $x = $j->decode($d);

    foreach my $name (keys(%$x)) {
        next if($name eq 'icons');
        my $shell = $x->{$name};
        next if($shell->{id} == 0 || $shell->{id} eq '');
        my $typecomp = descr('shell', $nations->{$country}, $shell->{id});

        my $data = {
            %$shell,
            _id             => $typecomp,
            country         => $country,
            component       => 'shells',
        };
        $data->{component_id} = delete($data->{id});
        $data->{i18n} = $data->{userString};

        if(ref($data->{price}) eq 'HASH') {
            $data->{price} = { unit => 'gold', amount => $data->{price}->{text} + 0 };
        } else {
            $data->{price} = { unit => 'silver', amount => $data->{price} + 0 };
        }

        my $us = delete($data->{userString});
        my $desc = delete($data->{description});
        $data->{ident} = $name;
        $data->{label} = (defined($us)) 
            ? $text->localize_for(lang => sprintf('%s_vehicles', $country), id => fix_us($us)) 
            : (defined($name))
                ? $text->localize_for(lang => sprintf('%s_vehicles', $country), id => $name)
                : sprintf('nolabel:%s', $name);

        $data->{description} = (defined($desc)) ? $text->localize_for(lang => sprintf('%s_vehicles', $country), id => $desc) : '';
        $coll->insert($data, { safe => 1 }) and warn 'saved: ', $name, "\n";
    }
}
