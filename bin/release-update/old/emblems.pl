#!/usr/bin/perl
use strict;
use FindBin;
use lib ("$FindBin::Bin/lib","$FindBin::Bin/../lib","$FindBin::Bin/../../lib");
use WR;
use WR::XMLReader;
use Mango;
use Mango::BSON;
use JSON::XS;
use XML::Simple;
use File::Slurp qw/read_file/;
use Data::Dumper;

die 'Usage: emblems.pl <path to emblem file>', "\n" unless($ARGV[0]);

my $efile = $ARGV[0];

my $reader = WR::XMLReader->new(filename => $efile);
my $list   = $reader->parse;

my $storage = [];

foreach my $gname (keys(%$list)) {
    my $group = $list->{$gname};
    next if($group->{notInShop});

    foreach my $emblem (@{$group->{emblems}->{emblem}}) {
        my $tex = $emblem->{texName};
        my $id  = $emblem->{id};
        $id =~ s/\D+//g;
        $id += 0;

        $tex =~ s|gui/maps/vehicles/decals/player_stickers|customization/stickers|g;
        $tex =~ s/\.dds/\.png/g;

        push(@$storage, {
            _id => sprintf('emblem-%d', $id),
            type => 'emblem',
            wot_id => $id,
            icon => $tex,
            i18n => $emblem->{userString},
        });
    }
}

my $mango = Mango->new('mongodb://localhost:27017/');
my $coll  = $mango->db('wot-replays')->collection('data.customization');

$coll->save($_) for(@$storage);

__END__
$VAR1 = {
          'group4' => {
                        'priceFactor' => '1.0',
                        'userString' => '#vehicle_customization:emblem/signs',
                        'emblems' => {
                                       'emblem' => [
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_48',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_48.dds',
                                                       'id' => 401
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_43',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_43.dds',
                                                       'id' => 402
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_46',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_46.dds',
                                                       'id' => 403
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_59',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_59.dds',
                                                       'id' => 404
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_45',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_45.dds',
                                                       'id' => 405
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_44',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_44.dds',
                                                       'id' => 406
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_36',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_36.dds',
                                                       'id' => 407
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_41',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_41.dds',
                                                       'id' => 408
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_42',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_42.dds',
                                                       'id' => 409
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_10',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_10.dds',
                                                       'id' => 410
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_11',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_11.dds',
                                                       'id' => 411
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_12',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_12.dds',
                                                       'id' => 412
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_13',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_13.dds',
                                                       'id' => 413
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_14',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_14.dds',
                                                       'id' => 414
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_15',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_15.dds',
                                                       'id' => 415
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_16',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_16.dds',
                                                       'id' => 416
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_17',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_17.dds',
                                                       'id' => 417
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_18',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_18.dds',
                                                       'id' => 418
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_19',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_19.dds',
                                                       'id' => 419
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_20',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_20.dds',
                                                       'id' => 420
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_21',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_21.dds',
                                                       'id' => 421
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_22',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_22.dds',
                                                       'id' => 422
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_23',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_23.dds',
                                                       'id' => 423
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_24',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_24.dds',
                                                       'id' => 424
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_25',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_25.dds',
                                                       'id' => 425
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_26',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_26.dds',
                                                       'id' => 426
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_27',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_27.dds',
                                                       'id' => 427
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_28',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_28.dds',
                                                       'id' => 428
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_29',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_29.dds',
                                                       'id' => 429
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_30',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_30.dds',
                                                       'id' => 430
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_31',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_31.dds',
                                                       'id' => 431
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_32',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_32.dds',
                                                       'id' => 432
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_33',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_33.dds',
                                                       'id' => 433
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_34',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_34.dds',
                                                       'id' => 434
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_35',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_35.dds',
                                                       'id' => 435
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_7',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_07.dds',
                                                       'id' => 436
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_37',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_37.dds',
                                                       'id' => 437
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_38',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_38.dds',
                                                       'id' => 438
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_39',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_39.dds',
                                                       'id' => 439
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_40',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_40.dds',
                                                       'id' => 440
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_8',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_08.dds',
                                                       'id' => 441
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_9',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_09.dds',
                                                       'id' => 442
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_2',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_02.dds',
                                                       'id' => 443
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_6',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_06.dds',
                                                       'id' => 444
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_5',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_05.dds',
                                                       'id' => 445
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_3',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_03.dds',
                                                       'id' => 446
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_47',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_47.dds',
                                                       'id' => 447
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_1',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_01.dds',
                                                       'id' => 448
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_49',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_49.dds',
                                                       'id' => 449
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_50',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_50.dds',
                                                       'id' => 450
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_51',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_51.dds',
                                                       'id' => 451
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_52',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_52.dds',
                                                       'id' => 452
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_53',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_53.dds',
                                                       'id' => 453
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_54',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_54.dds',
                                                       'id' => 454
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_55',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_55.dds',
                                                       'id' => 455
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_56',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_56.dds',
                                                       'id' => 456
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_57',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_57.dds',
                                                       'id' => 457
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_58',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_58.dds',
                                                       'id' => 458
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_4',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_04.dds',
                                                       'id' => 459
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_60',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_60.dds',
                                                       'id' => 460
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_61',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_61.dds',
                                                       'id' => 461
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_62',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_62.dds',
                                                       'id' => 462
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_63',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_63.dds',
                                                       'id' => 463
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_64',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_64.dds',
                                                       'id' => 464
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_65',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_65.dds',
                                                       'id' => 465
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_66',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_66.dds',
                                                       'id' => 466
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_67',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_67.dds',
                                                       'id' => 467
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_68',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_68.dds',
                                                       'id' => 468
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_69',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_69.dds',
                                                       'id' => 469
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_70',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_70.dds',
                                                       'id' => 470
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_71',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_71.dds',
                                                       'id' => 471
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_72',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_72.dds',
                                                       'id' => 472
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_73',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_73.dds',
                                                       'id' => 473
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_74',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_74.dds',
                                                       'id' => 474
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_75',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_75.dds',
                                                       'id' => 475
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_76',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_76.dds',
                                                       'id' => 476
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_77',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_77.dds',
                                                       'id' => 477
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_78',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_78.dds',
                                                       'id' => 478
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_80',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_80.dds',
                                                       'id' => 480
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_81',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_81.dds',
                                                       'id' => 481
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_82',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_82.dds',
                                                       'id' => 482
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_83',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_83.dds',
                                                       'id' => 483
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_84',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_84.dds',
                                                       'id' => 484
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_85',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_85.dds',
                                                       'id' => 485
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_86',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_86.dds',
                                                       'id' => 486
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group4/signs_87',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/signs/sticker_87.dds',
                                                       'id' => 487
                                                     }
                                                   ]
                                     }
                      },
          'auto' => {
                      'priceFactor' => '1.0',
                      'userString' => '#vehicle_customization:emblem/group1',
                      'emblems' => {
                                     'germany_bundecross' => {
                                                               'texName' => 'gui/maps/vehicles/decals/germany_bundecross.dds',
                                                               'id' => 7
                                                             },
                                     'germany_cross' => {
                                                          'texName' => 'gui/maps/vehicles/decals/germany_cross.dds',
                                                          'id' => 2
                                                        },
                                     'ussr_star' => {
                                                      'userString' => '#vehicle_customization:emblem/group1/star',
                                                      'texName' => 'gui/maps/vehicles/decals/ussr_star.dds',
                                                      'id' => 1
                                                    },
                                     'china_kuomintang' => {
                                                             'texName' => 'gui/maps/vehicles/decals/china_kuomintang.dds',
                                                             'id' => 9
                                                           },
                                     'britain_color' => {
                                                          'texName' => 'gui/maps/vehicles/decals/britain_color.dds',
                                                          'id' => 6
                                                        },
                                     'french_rose' => {
                                                        'texName' => 'gui/maps/vehicles/decals/french_rose.dds',
                                                        'id' => 4
                                                      },
                                     'alpha_tester' => {
                                                         'texName' => 'gui/maps/vehicles/decals/alpha_tester.dds',
                                                         'id' => 10
                                                       },
                                     'china_star' => {
                                                       'texName' => 'gui/maps/vehicles/decals/china_star.dds',
                                                       'id' => 5
                                                     },
                                     'beta_tester' => {
                                                        'texName' => 'gui/maps/vehicles/decals/beta_tester.dds',
                                                        'id' => 11
                                                      },
                                     'usa_star' => {
                                                     'texName' => 'gui/maps/vehicles/decals/usa_star.dds',
                                                     'id' => 3
                                                   },
                                     'japanese_sun' => {
                                                         'texName' => 'gui/maps/vehicles/decals/japanese_sun.dds',
                                                         'id' => 8
                                                       }
                                   },
                      'notInShop' => bless( do{\(my $o = '1')}, 'boolean' )
                    },
          'group2' => {
                        'priceFactor' => '1.0',
                        'userString' => '#vehicle_customization:emblem/battle',
                        'emblems' => {
                                       'emblem' => [
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_1',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_01.dds',
                                                       'id' => 201
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_2',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_02.dds',
                                                       'id' => 202
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_3',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_03.dds',
                                                       'id' => 203
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_4',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_04.dds',
                                                       'id' => 204
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_5',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_05.dds',
                                                       'id' => 205
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_6',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_06.dds',
                                                       'id' => 206
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_7',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_07.dds',
                                                       'id' => 207
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_8',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_08.dds',
                                                       'id' => 208
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_9',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_09.dds',
                                                       'id' => 209
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_10',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_10.dds',
                                                       'id' => 210
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_11',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_11.dds',
                                                       'id' => 211
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_12',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_12.dds',
                                                       'id' => 212
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_13',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_13.dds',
                                                       'id' => 213
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_14',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_14.dds',
                                                       'id' => 214
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_15',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_15.dds',
                                                       'id' => 215
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_16',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_16.dds',
                                                       'id' => 216
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_17',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_17.dds',
                                                       'id' => 217
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_18',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_18.dds',
                                                       'id' => 218
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_19',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_19.dds',
                                                       'id' => 219
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_20',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_20.dds',
                                                       'id' => 220
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_21',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_21.dds',
                                                       'id' => 221
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_22',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_22.dds',
                                                       'id' => 222
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_23',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_23.dds',
                                                       'id' => 223
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_24',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_24.dds',
                                                       'id' => 224
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_25',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_25.dds',
                                                       'id' => 225
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_26',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_26.dds',
                                                       'id' => 226
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_27',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_27.dds',
                                                       'id' => 227
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group2/battle_28',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/battle/sticker_28.dds',
                                                       'id' => 228
                                                     }
                                                   ]
                                     }
                      },
          'group1' => {
                        'priceFactor' => '1.0',
                        'userString' => '#vehicle_customization:emblem/animals',
                        'emblems' => {
                                       'emblem' => [
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_1',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_01.dds',
                                                       'id' => 101
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_2',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_02.dds',
                                                       'id' => 102
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_3',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_03.dds',
                                                       'id' => 103
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_4',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_04.dds',
                                                       'id' => 104
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_5',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_05.dds',
                                                       'id' => 105
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_6',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_06.dds',
                                                       'id' => 106
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_7',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_07.dds',
                                                       'id' => 107
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_8',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_08.dds',
                                                       'id' => 108
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_9',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_09.dds',
                                                       'id' => 109
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_10',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_10.dds',
                                                       'id' => 110
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_11',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_11.dds',
                                                       'id' => 111
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_12',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_12.dds',
                                                       'id' => 112
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_13',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_13.dds',
                                                       'id' => 113
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_14',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_14.dds',
                                                       'id' => 114
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_15',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_15.dds',
                                                       'id' => 115
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_16',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_16.dds',
                                                       'id' => 116
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_17',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_17.dds',
                                                       'id' => 117
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_18',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_18.dds',
                                                       'id' => 118
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_19',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_19.dds',
                                                       'id' => 119
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_20',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_20.dds',
                                                       'id' => 120
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_21',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_21.dds',
                                                       'id' => 121
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_22',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_22.dds',
                                                       'id' => 122
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_23',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_23.dds',
                                                       'id' => 123
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_24',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_24.dds',
                                                       'id' => 124
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_25',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_25.dds',
                                                       'id' => 125
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_26',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_26.dds',
                                                       'id' => 126
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_27',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_27.dds',
                                                       'id' => 127
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_28',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_28.dds',
                                                       'id' => 128
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_29',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_29.dds',
                                                       'id' => 129
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_30',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_30.dds',
                                                       'id' => 130
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_31',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_31.dds',
                                                       'id' => 131
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group1/animal_32',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/animals/sticker_32.dds',
                                                       'id' => 132
                                                     }
                                                   ]
                                     }
                      },
          'group5' => {
                        'priceFactor' => '0.0',
                        'userString' => '#vehicle_customization:emblem/IGR',
                        'emblems' => {
                                       'emblem' => [
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group5/sticker_01',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/IGR/sticker_01.dds',
                                                       'id' => 5001
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group5/sticker_02',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/IGR/sticker_02.dds',
                                                       'id' => 5002
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group5/sticker_03',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/IGR/sticker_03.dds',
                                                       'id' => 5003
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group5/sticker_04',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/IGR/sticker_04.dds',
                                                       'id' => 5004
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group5/sticker_05',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/IGR/sticker_05.dds',
                                                       'id' => 5005
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group5/sticker_06',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/IGR/sticker_06.dds',
                                                       'id' => 5006
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group5/sticker_07',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/IGR/sticker_07.dds',
                                                       'id' => 5007
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group5/sticker_08',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/IGR/sticker_08.dds',
                                                       'id' => 5008
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group5/sticker_09',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/IGR/sticker_09.dds',
                                                       'id' => 5009
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group5/sticker_10',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/IGR/sticker_10.dds',
                                                       'id' => 5010
                                                     }
                                                   ]
                                     },
                        'igrType' => 2
                      },
          'group3' => {
                        'priceFactor' => '1.0',
                        'userString' => '#vehicle_customization:emblem/cool',
                        'emblems' => {
                                       'emblem' => [
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_1',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_01.dds',
                                                       'id' => 301
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_2',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_02.dds',
                                                       'id' => 302
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_3',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_03.dds',
                                                       'id' => 303
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_4',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_04.dds',
                                                       'id' => 304
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_5',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_05.dds',
                                                       'id' => 305
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_6',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_06.dds',
                                                       'id' => 306
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_7',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_07.dds',
                                                       'id' => 307
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_8',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_08.dds',
                                                       'id' => 308
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_9',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_09.dds',
                                                       'id' => 309
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_10',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_10.dds',
                                                       'id' => 310
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_11',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_11.dds',
                                                       'id' => 311
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_12',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_12.dds',
                                                       'id' => 312
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_13',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_13.dds',
                                                       'id' => 313
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_14',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_14.dds',
                                                       'id' => 314
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_15',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_15.dds',
                                                       'id' => 315
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_16',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_16.dds',
                                                       'id' => 316
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_17',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_17.dds',
                                                       'id' => 317
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_18',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_18.dds',
                                                       'id' => 318
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_19',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_19.dds',
                                                       'id' => 319
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_20',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_20.dds',
                                                       'id' => 320
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_21',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_21.dds',
                                                       'id' => 321
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_22',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_22.dds',
                                                       'id' => 322
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_23',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_23.dds',
                                                       'id' => 323
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_24',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_24.dds',
                                                       'id' => 324
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_25',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_25.dds',
                                                       'id' => 325
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_26',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_26.dds',
                                                       'id' => 326
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_27',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_27.dds',
                                                       'id' => 327
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_28',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_28.dds',
                                                       'id' => 328
                                                     },
                                                     {
                                                       'userString' => '#vehicle_customization:emblem/group3/cool_29',
                                                       'texName' => 'gui/maps/vehicles/decals/player_stickers/cool/sticker_29.dds',
                                                       'id' => 329
                                                     }
                                                   ]
                                     }
                      }
        };
