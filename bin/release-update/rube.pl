#!/usr/bin/perl
#
# Rube is the script that extracts all required data and does most of the 
# magic juju in order to update the wotreplays.org database for a new release.
#
# It requires Inline::Python, and uses libraries from the Rube/ folder. 
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Mango;
use Mojo::Log;
use Module::Load;
use Try::Tiny qw/try catch/;

my $wot_folder      = undef;
my $res_u_folder    = undef;
my $site_folder     = undef;
my $img_folder      = undef;
my $version         = undef;
my $mconn           = 'mongodb://localhost:27017';
my $dbname          = 'wotreplays';

my @only            = ();
my @default         = (qw/Language Achievements/);

GetOptions(
    'wot-folder=s'  =>  \$wot_folder,
    'resu-folder=s' =>  \$res_u_folder,
    'site-folder=s' =>  \$site_folder,
    'img-folder=s'  =>  \$img_folder,
    'version=s'     =>  \$version,
    'mongo=s'       =>  \$mconn,
    'db=s'          =>  \$dbname,
    'only=s@'       =>  \@only,
);


my $mango = Mango->new($mconn);
my $db    = $mango->db($dbname);
my $log   = Mojo::Log->new(level => 'debug');

$log->info('Rube starting import');
$log->info("\tsite folder: $site_folder");
$log->info("\twot folder: $wot_folder");
$log->info("\tres_u folder: $res_u_folder");
$log->info("\timg folder: $img_folder");
$log->info("\tversion: $version");

@only = @default if(scalar(@only) < 1);


foreach my $action (@only) {
    my $module = sprintf('Rube::%s', $action);

    $log->debug('Processing with ' . $module);
    try {
        load $module;
        my $m = $module->new(wot_folder => $wot_folder, res_u_folder => $res_u_folder, log => $log, version => $version, img_folder => $img_folder, site_folder => $site_folder);
        $m->install($db);
    } catch {
        $log->error('Failed: ' . $_);
    };
}

$log->info('Done with import');
