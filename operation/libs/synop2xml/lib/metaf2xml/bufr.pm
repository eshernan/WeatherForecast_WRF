########################################################################
# metaf2xml/bufr.pm 2.1
#   process a decoded BUFR message
#
# copyright (c) 2012-2016 metaf2xml
#
# This file is part of metaf2xml.
#
# metaf2xml is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# metaf2xml is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with metaf2xml.  If not, see <http://www.gnu.org/licenses/>.
########################################################################

package metaf2xml::bufr;

########################################################################
# some things strictly Perl
########################################################################
use strict;
use warnings;
# TODO: use -$x instead of 0-$x with Perl 5.14.0+
use 5.010_001;

########################################################################
# export the functions provided by this module
########################################################################
BEGIN {
    require Exporter;

    our @ISA       = qw(Exporter);
    our @EXPORT_OK = qw();
}

END {}

our $VERSION = 2.001;
sub VERSION {
    my ($pkg, $vers) = @_;

    die "$pkg version $vers required--this is version $VERSION\n"
        if $#_ == 1 && $vers != $VERSION;
    return $VERSION;
}

=head1 NAME

metaf2xml::bufr - process a decoded BUFR message

=head1 SYNOPSIS

 use metaf2xml::bufr 2.001;

=head1 DESCRIPTION

This Perl module can be used to process decoded BUFR messages. It has
no public functions and should not be used directly.

=cut

# convert a value (and associated field(s)) to pseudo-BUFR (text) string
sub _val2s {
    my ($val, $assoc) = @_;

    # replace multiple blanks, remove trailing blank
    if (defined $val) {
        $val =~ s/ \K +//g;
        $val =~ s/ $//;
    }
    return   ($assoc
                 ? join('/', '', map { "$_:" . $assoc->{$_} } sort keys %$assoc)
                 : ''
             )
           . (!defined $val
               ? '-'
               : (($val =~ m{ 0\d{5}[/:-]} ? '/' . length($val) : '') . ":$val")
             );
}

# return strings for unprocessed, defined values
sub _not_processed {
    my ($data, $s, $start, $end) = @_;

    return join '',
                map { defined $data->[$_] ? " $s->[$_]" : '' } $start .. $end;
}

sub _str2arr {
    my (@data, @desc, @assoc);

    pos = 0;
    while (m{\G(0\d{5})((?:/\d+:\d+)*)(?:/(\d+))?([:-])}gc) {
        push @desc, $1;
        push @assoc, $2 ? { split m{[/:]}, substr $2, 1 } : undef;
        if (defined $3) {
            push @data, substr $_, pos, $3;
            pos() += $3 + 1;
        } elsif ($4 eq '-') {
            push @data, undef;
            pos()++;
        } else {
            m{\G(?:(.*?) )??(?=0\d{5}[/:-])}gc || /\G(.*)/;
            push @data, $1;
        }
    }
    return \@data, \@desc, \@assoc;
}

sub _K2C {
    return { v => sprintf('%.2f', (shift) - 273.15), u => 'C' };
}

sub _salinity2percent {
    my ($v) = @_;

    return defined $v ? (salinity => sprintf '%.3f', $v / 10) : ();
}

# create assoc array, mark invalid groups, filter out repeater groups
sub _prepare {
    my ($data_old, $desc_old) = @_;
    my (@data, @desc, @assoc, $ii, $assoc_signif);

    $ii = 0;
    while ($ii <= $#$data_old) {
        if ($desc_old->[$ii] eq '031021') {
            $assoc_signif = $data_old->[$ii];
        } elsif ($desc_old->[$ii] eq '999999') {
            push @assoc,
                 defined $assoc_signif ? { $assoc_signif => $data_old->[$ii] }
                                       : undef;
            $ii++;
            push @data, $data_old->[$ii];
            push @desc, $desc_old->[$ii];
        } elsif (!{ map { $_ => 1 } qw(031000 031001 031002 031011 031012) }->{$desc_old->[$ii]})
        {
            push @data, $data_old->[$ii];
            push @desc, $desc_old->[$ii];
            push @assoc, undef;
        }

        $ii++;
    }

    return \@data, \@desc, \@assoc;
}

sub _addRadiationSun {
    my ($report, $rad) = @_;

    for (@{$report->{section3}}) {
        if (exists $_->{radiationSun}) {
            if (   $_->{radiationSun}{sunshinePeriod}{v}
                == $rad->{sunshinePeriod}{v})
            {
                $_->{radiationSun}{s} .= ' ' . $rad->{s};
                delete $rad->{s};
                $_ = { radiationSun => { %{$_->{radiationSun}}, %$rad }};
                delete $_->{radiationSun}{sunshineNotAvailable}
                    if exists $_->{radiationSun}{sunshine};
                return;
            }
        }
    }
    push @{$report->{section3}}, { radiationSun => $rad };
    return;
}

sub _mkWind {
    my ($dir, $speed) = @_;

    return { notAvailable => undef }
        if !defined $dir && !defined $speed;

    return { isCalm => undef }
        if defined $dir && defined $speed && $dir == 0 && $speed == 0;

    return {
        (defined $dir ? (dir => $dir) : (dirNotAvailable => undef)),
        (defined $speed ? (speed => { v => $speed, u => 'MPS' })
                        : (speedNotAvailable => undef))
    };
}

sub _mkSensorHeight {
    my ($have_ground, $have_water, $data, $ii) = @_;

    return (sensorHeight => { v => $data->[$ii], u => 'M' })
        if $have_ground && defined $data->[$ii];
    $ii++
        if $have_ground;
    return (sensorHeight => { v => $data->[$ii], u => 'M', above => 'water' })
        if $have_water && defined $data->[$ii];
    return ();
}

sub _fixMeasurePeriod {
    my ($report, $val, $s) = @_;

    if (defined $$val && $$val > 0) {
        push @{$report->{warning}}, {
            warningType => 'periodInvalid',
            s           => "$$val: $s"
        };
        $$val = -$$val;
    }
    return;
}

# did they just copy CL,CM,CH to 020012,020012,020012?
sub _fixCloudType {
    my ($report, $cloudTypeLow, $cloudTypeMiddle, $cloudTypeHigh, $s) = @_;

    return
        if    !defined $$cloudTypeLow
           && !defined $$cloudTypeMiddle
           && !defined $$cloudTypeHigh;

    if (   (   !defined $$cloudTypeLow
            || ($$cloudTypeLow >= 0 && $$cloudTypeLow <= 9))
        && (   !defined $$cloudTypeMiddle
            || ($$cloudTypeMiddle >= 0 && $$cloudTypeMiddle <= 9))
        && (   !defined $$cloudTypeHigh
            || ($$cloudTypeHigh >= 0 && $$cloudTypeHigh <= 9)))
    {
        push @{$report->{warning}}, {
            warningType => 'cloudTypeInvalid',
            s           => $s
        };
        $$cloudTypeLow += 30
            if defined $$cloudTypeLow;
        $$cloudTypeMiddle += 20
            if defined $$cloudTypeMiddle;
        $$cloudTypeHigh += 10
            if defined $$cloudTypeHigh;
    }
    return;
}

sub _codeTable001003 {
    my ($v) = @_;

    return   defined $v && $v =~ /^[0-6]$/
           ? (region => qw(Antarctic I II III IV V VI)[$v])
           : ();
}

sub _codeTable020054 {
    my ($type, $v) = @_;

    return   !defined $v ? ("cloudType${type}NA" => undef)
           : $v == 0     ? ("cloudType${type}None" => undef)
           : $v >= 500   ? ("cloudType${type}Invisible" => undef)
           :               ("cloudType${type}Dir" => $v);
}

sub _codeTable020012 {
    my ($v) = @_;

    return   ($v // 59) == 59
                      ? { cloudTypeNotAvailable => undef }
           : $v < 10  ? { cloudType => qw(CI CC CS AC AS NS SC ST CU CB)[$v] }
           : $v < 20  ? { cloudTypeHigh     => $v - 10 }
           : $v < 30  ? { cloudTypeMiddle   => $v - 20 }
           : $v < 40  ? { cloudTypeLow      => $v - 30 }
           : $v == 60 ? { cloudTypeHighNA   => undef }
           : $v == 61 ? { cloudTypeMiddleNA => undef }
           : $v == 62 ? { cloudTypeLowNA    => undef }
           :            { invalidFormat     => $v };
}

########################################################################
# _bufr2report
########################################################################
sub _bufr2report {
    my ($data, $desc, $assoc) = @_;
    my (%report, $not_processed_s, $ii, $is_processed);
    my (@s, $val0, $s0, $is_auto, $val, $amdarObs);
    local $_;

    ($data, $desc, $assoc) = _prepare $data, $desc
        unless defined $assoc;

    for (0 .. $#$desc) {
        push @s, $desc->[$_] . _val2s $data->[$_], $assoc->[$_];
    }

    %report = ();

    $_ = "@$desc ";
    $ii = 0;
    $not_processed_s = '';
    while ($ii <= $#$desc) {
        $is_processed = 1;
        pos   = 7 * $ii;
        $val0 = $data->[$ii];
        $s0   = $s[$ii];

        if (   /\G001011 001012 001013/
            && defined $val0
            && !exists $report{callSign})
        {
            # replace non-IA5 characters
            $val0 =~ s/[^ -\x7e]/?/g;
            $s[$ii] =~ s/[^ -\x7e]/?/g;

            $report{callSign} = { s => $s[$ii], id => $val0 };
            $report{isSynop} = undef;
            @{$report{obsStationType}}{qw(s stationType)} = qw(BBXX BBXX);

            if (($data->[$ii + 1] // 509) != 509 || defined $data->[$ii + 2]) {
                $report{displacement} = {
                    s             => "@s[$ii + 1, $ii + 2]",
                    timeBeforeObs => { notAvailable => undef }
                };
                if (defined $data->[$ii + 2] && $data->[$ii + 2] == 0) {
                    $report{displacement}{isStationary} = undef;
                } else {
                    if (defined $data->[$ii + 2]) {
                        $report{displacement}{speed} = [
                            { v => $data->[$ii + 2], u => 'MPS' },
                            { v => $data->[$ii + 2], u => 'MPS' }
                        ];
                    } else {
                        $report{displacement}{speedNotAvailable} = undef;
                    }
                    if (($data->[$ii + 1] // 509) == 509) {
                        $report{displacement}{dirVarAllUnk} = undef;
                    } else {
                        $report{displacement}{dir} = $data->[$ii + 1];
                    }
                }
            }
            $ii += 3;
        } elsif (   /\G001011 001003/
                 && defined $val0
                 && !exists $report{callSign})
        {
            # replace non-IA5 characters
            $val0 =~ s/[^ -\x7e]/?/g;
            $s[$ii] =~ s/[^ -\x7e]/?/g;

            $report{callSign} = {
                s  => "@s[$ii, $ii + 1]",
                id => $val0,
                _codeTable001003 $data->[$ii + 1]
            };
            $report{isSynop} = undef;
            @{$report{obsStationType}}{qw(s stationType)} = qw(OOXX OOXX);
            $ii +=2;
        } elsif (   /\G001001 001002/
                 && (   !exists $report{obsStationId}
                     || !exists $report{obsStationId}{id}))
        {
            $report{obsStationId}{id} =
                                      sprintf '%02d%03d', @$data[$ii .. $ii + 1]
                if defined $val0 && defined $data->[$ii + 1];
            if (exists $report{obsStationId}{s}) {
                $report{obsStationId}{s} .= " @s[$ii, $ii + 1]";
            } else {
                $report{obsStationId}{s} = "@s[$ii, $ii + 1]";
            }
            $report{isSynop} = undef;
            @{$report{obsStationType}}{qw(s stationType)} = qw(AAXX AAXX);
            $ii += 2;
        } elsif (   /\G001101 001102/
                 && (   !exists $report{obsStationId}
                     || !exists $report{obsStationId}{natId})
                 && defined $val0
                 && defined $data->[$ii + 1])
        {
# TODO?
# code table 001101 418: 19 C tables have "CURACAO AND SINT MAARTEN"
#                        all others have "NETHERLANDS ANTILLES AND ARUBA"
            $report{obsStationId}{natId} = {
                countryId    => $val0,
                natStationId => $data->[$ii + 1]
            };
            if (exists $report{obsStationId}{s}) {
                $report{obsStationId}{s} .= " @s[$ii, $ii + 1]";
            } else {
                $report{obsStationId}{s} = "@s[$ii, $ii + 1]";
            }
            $report{isSynop} = undef;
            @{$report{obsStationType}}{qw(s stationType)} = qw(AAXX AAXX);
            $ii += 2;
        } elsif (/\G00101[589]/) {
            my $tag;

            $tag = exists $report{isBuoy} ? 'buoyId' : 'obsStationId';

            if (defined $val0) {
                # replace non-IA5 characters
                $val0 =~ s/[^ -\x7e]/?/g;
                $s[$ii] =~ s/[^ -\x7e]/?/g;

                $report{$tag}{obsStationName} = $val0;
            }
            if (exists $report{$tag}{s}) {
                $report{$tag}{s} .= " $s[$ii]";
            } else {
                $report{$tag}{s} = $s[$ii];
            }
            $ii++;
        } elsif (   /\G001003 001020 001005/
                 && defined $data->[$ii + 1]
                 && defined $data->[$ii + 2]
                 && !exists $report{buoyId})
        {
            $report{buoyId} = {
                s  => "@s[$ii .. $ii + 2]",
                id => sprintf('%d%d%03d', @$data[$ii .. $ii + 2]),
                _codeTable001003 $val0
            };
            $report{isBuoy} = undef;
            @{$report{obsStationType}}{qw(s stationType)} = qw(ZZYY ZZYY);
            $ii += 3;
        } elsif (   /\G001087/
                 && defined $val0
                 && !exists $report{buoyId})
        {
            # https://www.wmo.int/pages/prog/amp/mmop/wmo-number-rules.html
            #   Numbers in the form A1bwnnn are equivalent to the form A1bw00nnn
            $val0 =~ s/^\d\d\K00(?=\d{3}$)//;
            $report{buoyId} = { s  => $s0, id => $val0 };
            $report{isBuoy} = undef;
            @{$report{obsStationType}}{qw(s stationType)} = qw(ZZYY ZZYY);
            $ii++;
        } elsif (   /\G001008/
                 && defined $val0
                 && !exists $report{aircraftId})
        {
            # replace non-IA5 characters
            $val0 =~ s/[^ -\x7e]/?/g;
            $s[$ii] =~ s/[^ -\x7e]/?/g;

            $report{aircraftId} = { s  => $s[$ii], id => $val0 };
            $report{isAmdar} = undef;
            @{$report{obsStationType}}{qw(s stationType)} = qw(AMDAR AMDAR);
            $ii++;
        } elsif (/\G002001/ && ($val0 // -1) < 2) {
            if (($val0 // -1) == 0) {
                $report{reportModifier} = { s => $s0, modifierType => 'AUTO' };
                $is_auto = 'AUTO';
            }
            $ii++;
        } elsif (/\G0020(05|6[12])/ && exists $report{isAmdar}) {
            if (exists $report{amdarInfo}) {
                $report{amdarInfo}{s} .= " $s0";
            } else {
                $report{amdarInfo}{s} = $s0;
            }
            $report{amdarInfo}{ { '05' => 'tempPrecision',
                                   61  => 'navSystem',
                                   62  => 'amdarSystem' }->{$1} } = $val0
                if defined $val0;
            $ii++;
        } elsif (/\G002064/ && $amdarObs) {
            $$amdarObs->{rollAngleQuality} = {
                s                   => $s0,
                rollAngleQualityVal => $val0
            }
                if defined $val0;
            $ii++;
        } elsif (/\G011036/ && exists $report{isAmdar}) {
            push @{$report{section3}}, { maxDerivedVerticalGust => {
                s    => $s0,
                wind => { speed => { v => $val0, u => 'MPS' }}
            }}
                if defined $val0;
            $ii++;
        } elsif (   /\G00500([12]) 00600\1/
                 && (   $amdarObs
                     || (   !exists $report{stationPosition}
                         && !exists $report{aircraftLocation})))
        {
            if (defined $val0 && defined $data->[$ii + 1]) {
                my ($tag, $r, $q);

                $tag = exists $report{isAmdar} ? 'aircraftLocation'
                                               : 'stationPosition';
                $r->{s} = "@s[$ii, $ii + 1]";
                $q = $1 == 1 ? 100000 : 100;
                @$r{qw(lat lon)} = ( { v => $val0,            q => $q },
                                     { v => $data->[$ii + 1], q => $q });
                ($amdarObs ? $$amdarObs->{$tag} : $report{$tag}) = $r;
            }
            $ii += 2;
        } elsif (/\G007010/ && exists $report{isAmdar}) {
            push @{$report{amdarObs}}, {};
            $amdarObs = \$report{amdarObs}[$#{$report{amdarObs}}];
            $$amdarObs->{flightLvl} = {
                s     => $s0,
                level => $val0 / 0.3048 / 100 # given in [M]
            }
                if defined $val0;
            $ii++;
        } elsif (/\G011031/ && exists $report{isAmdar} && $amdarObs) {
            $$amdarObs->{turbulenceAtPA} = {
                s             => $s0,
                turbulenceVal => $val0
            }
                if defined $val0;
            $ii++;
        } elsif (   /\G00800([49])/
                 && defined $val0
                 && (              ($val0 >= 2 && $val0 <= 6)
                     || ($1 == 9 && $val0 >= 0 && $val0 <= 14)))
        {
            $report{phaseOfFlight} = { s => $s0, phaseOfFlightVal => $val0 };
            $ii++;
        } elsif (   /\G007030/
                 && (   !exists $report{stationPosition}
                     || !exists $report{stationPosition}{elevation}))
        {
            if (defined $val0) {
                if (exists $report{stationPosition}) {
                    $report{stationPosition}{s} .= " $s0";
                } else {
                    $report{stationPosition}{s} = $s0;
                }
                $report{stationPosition}{elevation} = { v => $val0, u => 'M' };
            }
            $ii++;
        } elsif (/\G007031/ && !exists $report{barometerElev}) {
            @{$report{barometerElev}}{qw(s v)} = ($s0, $val0);
            $ii++;
        } elsif (/\G004025 008023 010004 011001 011002 012101 013003 008023/) {
            # 302083 First-order statistics of P, W, T, U data
            $is_processed = 0;
            $not_processed_s .= _not_processed $data, \@s, $ii, $ii + 7;
            $ii += 8;
        } elsif (   /\G(008021 )?004001 004002 004003 004004 004005 /gc
                 && (($val = $ii + ($1 ? 1 : 0)) || 1)
                 && defined $val0
                 && defined $data->[$val]
                 && defined $data->[$val + 1]
                 && defined $data->[$val + 2]
                 && defined $data->[$val + 3]
                 && defined $data->[$val + 4])
        {
# TODO?
# code table 008021 30: 1044 C tables have "RESERVED"
#                       all others have "TIME OF OCCURRENCE"
            if (   ((!defined $1 || $val0 == 25) && !exists $report{obsTime})
                || (   defined $1
                    && ($val0 == 26 || $val0 == 0)
                    && !exists $report{lastKnownPosTime}
                    && exists $report{isBuoy}))
            {
                my $tag = defined $1 && ($val0 == 26 || $val0 == 0)
                              ? 'lastKnownPosTime'
                              : 'obsTime';
                $report{$tag} = {
                    s      => "@s[$ii .. $val + 4]",
                    timeAt => {
                        year   => $data->[$val],
                        month  => $data->[$val + 1],
                        day    => $data->[$val + 2],
                        hour   => sprintf('%02d', $data->[$val + 3]),
                        minute => sprintf('%02d', $data->[$val + 4])
                    }
                };
                $ii = $val + 5;
                if (/\G004006/ && ($data->[$ii] // 0) == 0) {
                    $report{$tag}{s} .= " $s[$ii]";
                    $ii++;
                }
            } elsif ((!defined $1 || $val0 == 25) && exists $report{obsTime}) {
                # another observation!
                for (@s[$ii .. $#$desc]) {
                    # replace non-IA5 characters
                    s/[^ -\x7e]/?/g;
                }
                $not_processed_s .= _not_processed $data, \@s, $ii, $#$desc;
                $ii = $#$desc + 1;
            } else {
                # replace non-IA5 characters
                if (defined $val0) {
                    $s[$ii] =~ s/[^ -\x7e]/?/g;
                    $not_processed_s .= ' ' . $s[$ii];
                }
                $is_processed = 0;
                $ii++;
            }
        } elsif (/\G007062 022043 022062/) {
# TODO?
# 022062: 160 B tables have unit '%', scale 2
#         2000, 98000000, 98002001 have unit '%', scale 3
#         all others correctly have unit '‰', scale 2
            push @{$report{waterTempSalDepth}}, {
                s     => "@s[$ii .. $ii + 2]",
                depth => { v => $val0, u => 'M' },
                defined $data->[$ii + 1] ? (temp => _K2C $data->[$ii + 1]) : (),
                _salinity2percent $data->[$ii + 2]
            }
                if    defined $val0
                   && (defined $data->[$ii + 1] || defined $data->[$ii + 2]);
            $ii += 3;
        } elsif (/\G002038 007063 022043 007063/) {
            if (defined $data->[$ii + 2]) {
                if (   ($data->[$ii + 1] // 0) == 0
                    && !exists $report{seaSurfaceTemp})
                {
                    $report{seaSurfaceTemp} = {
                        s    => "@s[$ii .. $ii + 3]",
                        temp => _K2C $data->[$ii + 2],
                        defined $val0 ? (waterTempMeasurement => $val0) : ()
                    };
                } else  {
                    $not_processed_s .= " $s0"
                        if defined $val0;

                    push @{$report{waterTempSalDepth}}, {
                        s     => "@s[$ii + 1 .. $ii + 3]",
                        depth => { v => ($data->[$ii + 1] // 0), u => 'M' },
                        temp  => _K2C $data->[$ii + 2]
                    };
                }
            }
            $ii += 4;
        } elsif (   /\G022043 002033 022059/
                 && !exists $report{salinityMeasurement}
                 && (defined $val0 || defined $data->[$ii + 2]))
        {
            $report{salinityMeasurement} = {
                s => $s[$ii + 1],
                  !defined $data->[$ii + 1] ? (notAvailable => undef)
                : $data->[$ii + 1] =~ /^[0-3]$/
                                  ? (salinityMeasurementInd => $data->[$ii + 1])
                :                   (invalidFormat => $data->[$ii + 1])
            };
            if (!defined $data->[$ii + 2]) {
                $report{salinityMeasurement}{s} .= ' ' . $s[$ii + 2];
                unshift @{$report{section2}}, { seaSurfaceTemp => {
                    s => $s0,
                    defined $val0 ? (temp => _K2C $val0)
                                  : (notAvailable => undef)
                }};
            } else {
                push @{$report{waterTempSalDepth}}, {
                    s     => "@s[$ii, $ii + 2]",
                    depth => { v => 0, u => 'M' },
                    defined $val0 ? (temp => _K2C $val0) : (),
                    _salinity2percent $data->[$ii + 2]
                };
            }
            $ii += 3;
        } elsif (   /\G007063 022049/
                 && !exists $report{seaSurfaceTemp}
                 && ($val0 // 0) == 0)
        {
            $report{seaSurfaceTemp} = {
                s    => "@s[$ii, $ii + 1]",
                temp => _K2C $data->[$ii + 1]
            }
                if defined $data->[$ii + 1];
            $ii += 2;
        } elsif (   /\G02200([12]) 02201\1 02202\1/
                 && (exists $report{isSynop} || exists $report{isBuoy})
                 && !exists $report{qw(waves windWaves)[$1 - 1]})
        {
            if (   defined $val0
                || defined $data->[$ii + 1]
                || defined $data->[$ii + 2])
            {
                $report{qw(waves windWaves)[$1 - 1]} = {
                    s => "@s[$ii .. $ii + 2]",
                         ($data->[$ii + 1] // -1) == 0
                      || ($data->[$ii + 2] // -1) == 0
                    ? (noWaves => undef)
                    : (defined $val0 ? (dir => $val0) : (),
                       defined $data->[$ii + 1]
                           ? (wavePeriod => $data->[$ii + 1]) : (),
                       defined $data->[$ii + 2]
                           ? (height => { v => $data->[$ii + 2], u => 'M'}) : ()
                      )
                };
            }
            $ii += 3;
        } elsif (   (exists $report{isSynop} || exists $report{isBuoy})
                 && (   !exists $report{swell}
                     || $#{$report{swell}{swellData}} == 0)
                 && /\G022003 022013 022023/)
        {
            if (   defined $val0
                || defined $data->[$ii + 1]
                || defined $data->[$ii + 2])
            {
                if (exists $report{swell}) {
                    $report{swell}{s} .= " @s[$ii .. $ii + 2]";
                } else {
                    $report{swell}{s} = "@s[$ii .. $ii + 2]";
                }
                push @{$report{swell}{swellData}}, {
                         ($data->[$ii + 1] // -1) == 0
                      || ($data->[$ii + 2] // -1) == 0
                    ? (noWaves => undef)
                    : (defined $val0 ? (dir => $val0) : (),
                       defined $data->[$ii + 1]
                           ? (wavePeriod => $data->[$ii + 1]) : (),
                       defined $data->[$ii + 2]
                           ? (height => { v => $data->[$ii + 2], u => 'M'}) : ()
                      )
                };
            }
            $ii += 3;
        } elsif (   exists $report{isSynop}
                 && /\G007004 010009/
                 && !exists $report{gpSurface})
        {
            if (defined $val0 && defined $data->[$ii + 1]) {
                $report{gpSurface}{s} = "@s[$ii, $ii + 1]";

                if ({ map { $_ => 1 } qw(1000 925 500 700 850) }->{$val0 / 100})
                {
                    @{$report{gpSurface}}{qw(surface geopotential)} =
                                                ($val0 / 100, $data->[$ii + 1]);
                } else {
                    $report{gpSurface}{invalidFormat} = $report{gpSurface}{s};
                }
            }
            $ii += 2;
        } elsif (   /\G(007032 )?(007033 )?012101 /gc
                 && ($amdarObs || !exists $report{temperature}))
        {
            my $temp;

            $val = $ii;
            $val++
                if $1;
            $val++
                if $2;
            ($amdarObs ? $$amdarObs->{temperature} : $report{temperature}) = {
                s   => "@s[$ii .. $val]",
                air => defined $data->[$val] ? { temp => _K2C $data->[$val] }
                                             : { notAvailable => undef },
                _mkSensorHeight $1, $2, $data, $ii
            };
            $ii = $val + 1;
            $temp = $amdarObs ? $$amdarObs->{temperature}
                              : $report{temperature};

            if (/\G002039 012102 /gc) {
                $not_processed_s .= _not_processed $data, \@s, $ii, $ii + 1;
                $ii += 2;
            }

            if (/\G012103 /gc) {
                $temp->{s} .= " $s[$ii]";
                $temp->{dewpoint} =
                    defined $data->[$ii] && $data->[$ii] > 0
                            ? { temp => _K2C $data->[$ii] }
                            : { notAvailable => undef };
                $ii++;
            }
            if (/\G013003/gc) {
                $report{temperature}{s} .= " $s[$ii]";
                $report{temperature}{relHumid1} = $data->[$ii]
                    if defined $data->[$ii];
                $ii++;
            }
        } elsif (/\G010004/ && !exists $report{stationPressure}) {
            $report{stationPressure} = {
                s        => $s0,
                pressure => { v => sprintf('%.1f', $val0 /100), u => 'hPa' }
            }
                if defined $val0;
            $ii++;
        } elsif (/\G010051/ && !exists $report{SLP}) {
            $report{SLP} = {
                s        => $s0,
                pressure => { v => sprintf('%.1f', $val0 /100), u => 'hPa' }
            }
                if defined $val0;
            $ii++;
        } elsif (   /\G01006([12])( 010063)?/
                 && (   !exists $report{pressureChange}
                     || exists $report{isSynop}))
        {
            $val = $ii + ($2 ? 1 : 0);
            if (defined $val0) {
                my $r;

                $r = {
                    s             => "@s[$ii .. $val]",
                    timeBeforeObs => { hours => (3, 24)[$1 - 1] },
                    pressureChangeVal =>
                               { v => sprintf('%.1f', $val0 / 100), u => 'hPa' }
                };
                if ($2 && defined $data->[$val]) {
                    if ($data->[$val] >= 0 && $data->[$val] <= 8) {
                        $r->{pressureTendency} = $data->[$val];
                    } else {
                        $r->{invalidFormat} = $s[$val];
                        delete $r->{pressureChangeVal};
                    }
                }
                if (!exists $report{pressureChange} && $1 == 1) {
                    $report{pressureChange} = $r;
                } else {
                    push @{$report{section3}}, { pressureChange => $r };
                }
            }
            $ii = $val + 1;
        } elsif (/\G(007032 )?013023/) {
            $val = $1 ? $ii + 1 : $ii;
            push @{$report{section3}}, { precipitation => {
                s             => "@s[$ii .. $val]",
                timeBeforeObs => { hours => 24 },
                $data->[$val] == -0.1
                   ? (precipTraces => undef)
                   : (precipAmount => { v => $data->[$val], u => 'MM' }),
                $1 && defined $val0
                   ? (sensorHeight => { v => $val0, u => 'M' })
                   : ()
            }}
                if defined $data->[$val];
            $ii = $val + 1;
        } elsif (   /\G(007032 )?(002175 002178 )?(?=00402[45] 013011 )/gc
                 && exists $report{isSynop})
        {
            my $sensorHeight;

            if ($1) {
                $sensorHeight = $val0;
                $ii++;
            }
            if ($2) {
                $not_processed_s .= _not_processed $data, \@s, $ii, $ii + 1;
                $ii += 2;
            }
            while (/\G00402([45]) 013011 /gc) {
                if (defined $data->[$ii] && defined $data->[$ii + 1]) {
                    _fixMeasurePeriod \%report, \$data->[$ii],
                                      "$s0 @s[$ii, $ii + 1]";
                    push @{$report{section3}}, { precipitation => {
                            s             => "$s0 @s[$ii, $ii + 1]",
                            timeBeforeObs => {
                                  qw(hours minutes)[$1 - 4] => 0-$data->[$ii] },
                            $data->[$ii + 1] == -0.1
                                 ? (precipTraces => undef)
                                 : (precipAmount => { v => $data->[$ii + 1],
                                                      u => 'MM' }),
                            defined $sensorHeight
                                 ? (sensorHeight => { v => $val0, u => 'M' })
                                 : ()
                    }};
                }
                $ii += 2;
            }
        } elsif (   /\G(007032 )?(007033 )?(033041 )?020001/
                 && !exists $report{visPrev})
        {
            $val = $ii;
            $val++
                if $1;
            $val++
                if $2;
            $val++
                if $3;
            $report{visPrev} = {
                s        => "@s[$ii .. $val]",
                distance => { v => $data->[$val], u => 'M',
                              $3
                           && defined $data->[$val - 1]
                           && ($data->[$val - 1] == 1 || $data->[$val - 1] == 2)
                         ? (q => qw(isGreater isLess)[$data->[$val - 1] - 1])
                         : ()
               },
               _mkSensorHeight $1, $2, $data, $ii
            }
                if defined $data->[$val];
            $ii = $val + 1;
        } elsif (/\G020010/ && !exists $report{totalCloudCover}) {
            $report{totalCloudCover} = {
                    s => $s0,
                      $val0 > 100 && $val0 != 113 ? (invalidFormat => $s0)
                    : $val0 == 113                ? (skyObscured => undef)
                    :                    (oktas => sprintf '%.0f', $val0 / 12.5)
            }
                if defined $val0;
            $ii++;
        } elsif (   /\G008002 020011 020013 020012 020012 020012/
                 && !exists $report{cloudTypes})
        {
            my $s;

            $report{baseLowestCloud} = {
                s        => $s[$ii + 2],
                distance => { v => $data->[$ii + 2], u => 'M' }
            }
                if defined $data->[$ii + 2];

            $s = "@s[$ii, $ii + 1, $ii + 3 .. $ii + 5]";
            if (!defined $data->[$ii + 1] && !defined $data->[$ii + 3]) {
                # ignore
            } elsif (($data->[$ii + 1] // -1) == 9) {
                $report{cloudTypes}{skyObscured} = undef;
            } else {
                _fixCloudType \%report, \@$data[$ii + 3 .. $ii + 5], $s;
                if (   (   defined $data->[$ii + 3]
                        && (   $data->[$ii + 3] < 30
                            || (   $data->[$ii + 3] >= 40
                                && $data->[$ii + 3] != 62)))
                    || (   defined $data->[$ii + 4]
                        && (   $data->[$ii + 4] < 20
                            || (   $data->[$ii + 4] >= 30
                                && $data->[$ii + 4] != 61)))
                    || (   defined $data->[$ii + 5]
                        && (   $data->[$ii + 5] < 10
                            || (   $data->[$ii + 5] >= 20
                                && $data->[$ii + 5] != 60))))
                {
                    $report{cloudTypes}{invalidFormat} = $s;
                } else {
                    if (($data->[$ii + 3] // 62) == 62) {
                        $report{cloudTypes}{cloudTypeLowNA} = undef;
                    } else {
                        $report{cloudTypes}{cloudTypeLow} =
                                                          $data->[$ii + 3] - 30;
                    }
                    if (($data->[$ii + 4] // 61) == 61) {
                        $report{cloudTypes}{cloudTypeMiddleNA} = undef;
                    } else {
                        $report{cloudTypes}{cloudTypeMiddle} =
                                                          $data->[$ii + 4] - 20;
                    }
                    if (($data->[$ii + 5] // 60) == 60) {
                        $report{cloudTypes}{cloudTypeHighNA} = undef;
                    } else {
                        $report{cloudTypes}{cloudTypeHigh} =
                                                          $data->[$ii + 5] - 10;
                    }
                    if (($data->[$ii + 1] // 9) < 9) {
                        if (($val0 // 0) == 0) {
                            if (($report{cloudTypes}{cloudTypeLow} // 0) > 0) {
                                $report{cloudTypes}{oktasLow} = $data->[$ii + 1];
                            } elsif (   exists $report{cloudTypes}{cloudTypeLow}
                                     && (($report{cloudTypes}{cloudTypeMiddle} // 0) > 0))
                            {
                                $report{cloudTypes}{oktasMiddle} = $data->[$ii + 1];
                            } else {
                                $report{cloudTypes}{oktas} = $data->[$ii + 1];
                            }
                        } elsif ($val0 == 7 || $val0 == 8) {
                            $report{cloudTypes}{qw(oktasLow oktasMiddle)[$val0 -7]}
                                                             = $data->[$ii + 1];
                        }
                    }
                }
            }
            $report{cloudTypes}{s} = $s
                if exists $report{cloudTypes};

            $ii += 6;
        } elsif (   exists $report{isSynop}
                 && /\G008002 020011 020012 (033041 )?020013/
                 && (   !defined $val0
                     || (   ($val0 >= 0 && $val0 <= 5)
                         || ($val0 >= 21 && $val0 <= 24))))
        {
            $val = $ii + ($1 ? 4 : 3);

            if (   defined $data->[$val]
                || ($data->[$ii + 1] // 10) <= 9
                || ($data->[$ii + 2] // 59) != 59)
            {
                my $r;

                $r->{s} = "@s[$ii .. $val]";
                if (!defined $data->[$val]) {
                    push @{$r->{sortedArr}}, { cloudBaseNotAvailable => undef };
                } else {
                    push @{$r->{sortedArr}}, { cloudBase => {
                        v => $data->[$val],
                        u => 'M',
                             $1
                          && defined $data->[$val - 1]
                          && ($data->[$val - 1] == 1 || $data->[$val - 1] == 2)
                        ? (q => qw(isGreater isLess)[$data->[$val - 1] - 1])
                        : ()
                    }};
                }
                push @{$r->{sortedArr}}, _codeTable020012 $data->[$ii + 2];
                push @{$r->{sortedArr}}, { cloudOktas => {
                      ($data->[$ii + 1] // 10) > 9 ? (oktasNotAvailable =>undef)
                    : $data->[$ii + 1] == 9        ? (skyObscured => undef)
                    :                                (oktas => $data->[$ii + 1])
                }};
                push @{$report{section3}}, { cloudInfo => $r };
            }
            $ii += 4;
        } elsif (   /\G008002 020011 020012 020014 020017/
                 && exists $report{isSynop}
                 && ($val0 // 0) == 11)
        {
            push @{$report{section4}}, { cloudBelowStation => {
                s          => "@s[$ii .. $ii + 4]",
                cloudOktas =>
                      ($data->[$ii + 1] // 10) > 9
                    ? { oktasNotAvailable => undef }
                    : $data->[$ii + 1] == 9 ? { skyObscured => undef }
                    :                         { oktas => $data->[$ii + 1] },
                cloudTopDescr => $data->[$ii + 4],
                cloudTops     => { v => $data->[$ii + 3], u => 'M' },
                      ($data->[$ii + 2] // 10) > 9
                    ? (cloudTypeNotAvailable => undef)
                    : (cloudType =>
                            qw(CI CC CS AC AS NS SC ST CU CB)[$data->[$ii + 2]])
            }}
                if defined $data->[$ii + 3] && defined $data->[$ii + 4];
            $ii += 5;
        } elsif (/\G011001 011002/ && ($amdarObs || !exists $report{sfcWind})) {
            ($amdarObs ? $$amdarObs->{windAtPA} : $report{sfcWind}) = {
                s    => "@s[$ii .. $ii + 1]",
                wind => _mkWind $val0, $data->[$ii + 1]
            }
                if defined $val0 || defined $data->[$ii + 1];
            $ii += 2;
        } elsif (   /\G(007032 )?(007033 )?(002002 )?008021 004025 011001 011002 /gc
                 && !exists $report{sfcWind}
                 && (($val = $ii + ($1 ? 1 : 0) + ($2 ? 1 : 0) + ($3 ? 1 : 0)) || 1)
                 && defined $data->[$val]
                 && $data->[$val] == 2)
        {
# TODO?
# code table 008021 30: 1044 C tables have "RESERVED"
#                       all others have "TIME OF OCCURRENCE"
            my $have_wind;

            $have_wind = defined $data->[$val + 2] || defined $data->[$val + 3];
            if ($have_wind) {
                $report{sfcWind} = {
                    s => "@s[$ii .. $val + 3]",
                    _mkSensorHeight $1, $2, $data, $ii
                };

                if (defined $data->[$val + 1]) {
                    _fixMeasurePeriod \%report, \$data->[$val + 1],
                                                            $report{sfcWind}{s};
                    $report{sfcWind}{measurePeriod} =
                                       { v => 0-$data->[$val + 1], u => 'MIN' };
                }

                $report{sfcWind}{wind} = _mkWind $data->[$val + 2],
                                                 $data->[$val + 3];
            }
            $ii = $val + 4;

            if (/\G008021/ && !defined $data->[$ii]) {
# TODO?
# code table 008021 30: 1044 C tables have "RESERVED"
#                       all others have "TIME OF OCCURRENCE"
                $report{sfcWind}{s} .= " $s[$ii]"
                    if $have_wind;
                $ii++;
            }
        } elsif (   /\G004025 011016 011017/
                 && (   !(defined $data->[$ii + 1] && defined $data->[$ii + 2])
                     || (   defined $val0
                         && exists $report{sfcWind}
                         && exists $report{sfcWind}{measurePeriod}
                         && $report{sfcWind}{measurePeriod}{v} == 0-$val0)))
        {
            if (defined $data->[$ii + 1] && defined $data->[$ii + 2]) {
                $report{sfcWind}{s} .= " @s[$ii .. $ii + 2]";
                @{$report{sfcWind}{wind}}{qw(windVarLeft windVarRight)}
                                                      = @$data[$ii + 1, $ii + 2]
            }
            $ii += 3;
        } elsif (/\G004025 011043 011041/) {
            if (defined $data->[$ii + 1] || defined $data->[$ii + 2]) {
                _fixMeasurePeriod \%report, \$val0, "@s[$ii .. $ii + 2]";
                push @{$report{section3}}, { highestGust => {
                    s             => "@s[$ii .. $ii + 2]",
                    defined $val0
                        ? (measurePeriod => { v => 0-$val0, u => 'MIN' })
                        : (),
                    wind          => {
                         defined $data->[$ii + 1] ? (dir => $data->[$ii + 1])
                                                  : (dirNotAvailable => undef),
                         defined $data->[$ii + 2]
                             ? (speed => { v => $data->[$ii + 2], u => 'MPS' })
                             : (speedNotAvailable => undef)
                    }
                }};
            }
            $ii += 3;
        } elsif (   /\G004025 011042/
                 && defined $val0
                 && defined $data->[$ii + 1])
        {
            _fixMeasurePeriod \%report, \$val0, "@s[$ii, $ii + 1]";
            push @{$report{section3}}, { highestMeanSpeed => {
                s             => "@s[$ii, $ii + 1]",
                measurePeriod => { v => 10, u => 'MIN' },
                wind          => { speed => { v => $data->[$ii + 1], u=>'MPS'}},
                timeBeforeObs => { hours => -$val0 / 60 }
            }};
            $ii += 2;
        } elsif (/\G007032 004025 012112/) {
            if (defined $val0 && defined $data->[$ii + 1] && $data->[$ii + 2]) {
                _fixMeasurePeriod \%report, \$data->[$ii + 1],
                                  "@s[$ii .. $ii + 2]";
                push @{$report{section3}}, {
                    'tempMin' . ($val0 <= 0.1 ? 'Ground' : '') => {
                        s             => "@s[$ii .. $ii + 2]",
                        sensorHeight  => { v => $val0, u => 'M' },
                        timeBeforeObs => { hours => -$data->[$ii + 1] / 60 },
                        temp          => _K2C $data->[$ii + 2]
                }};
            }
            $ii +=3;
        } elsif (/\G007032 007033 004025 012111 012112/) {
            if (   (defined $data->[$ii + 2] && defined $data->[$ii + 3])
                || (defined $data->[$ii + 2] && defined $data->[$ii + 4]))
            {
                my $s;

                $s = "@s[$ii .. $ii + 4]";
                _fixMeasurePeriod \%report, \$data->[$ii + 2], $s;
                push @{$report{section3}}, { tempExtreme => {
                    s => $s,
                    _mkSensorHeight(1, 1, $data, $ii),
                    tempExtremeMax => {
                        defined $data->[$ii + 3]
                        ? (temp          => _K2C($data->[$ii + 3]),
                           timeBeforeObs => { hours => -$data->[$ii + 2] / 60 })
                        : (notAvailable => undef)
                    },
                    tempExtremeMin => {
                        defined $data->[$ii + 4]
                        ? (temp          => _K2C($data->[$ii + 4]),
                           timeBeforeObs => { hours => -$data->[$ii + 2] / 60 })
                        : (notAvailable => undef)
                    }
                }};
            }
            $ii += 5;
        } elsif (/\G007032 (007033 )?004024 004024 012111 004024 004024 012112/)
        {
# TODO?
# 004024: B tables 2000, 98000000, 98002001 have reference -1024, width 11
#         all others have reference -2048, width 12
            $val = $ii + ($1 ? 2 : 1);
            if (   (   defined $data->[$val]
                    && defined $data->[$val + 1]
                    && defined $data->[$val + 2])
                || (   defined $data->[$val + 3]
                    && defined $data->[$val + 4]
                    && defined $data->[$val + 5]))
            {
                my $s;

                $s = "@s[$ii .. $val + 5]";
                _fixMeasurePeriod \%report, \$data->[$val], $s;
                _fixMeasurePeriod \%report, \$data->[$val + 1], $s;
                _fixMeasurePeriod \%report, \$data->[$val + 3], $s;
                _fixMeasurePeriod \%report, \$data->[$val + 4], $s;
                push @{$report{section3}}, { tempExtreme => {
                    s => $s,
                    _mkSensorHeight(1, $1, $data, $ii),
                    tempExtremeMax => {
                           defined $data->[$val]
                        && defined $data->[$val + 1]
                        && defined $data->[$val + 2]
                               ? (temp          => _K2C($data->[$val + 2]),
                                  timeBeforeObs => $data->[$val + 1] == 0
                                         ? { hours => 0-$data->[$val] }
                                         : { hoursFrom => 0-$data->[$val],
                                             hoursTill => 0-$data->[$val + 1] })
                               : (notAvailable => undef)
                    },
                    tempExtremeMin => {
                           defined $data->[$val + 3]
                        && defined $data->[$val + 4]
                        && defined $data->[$val + 5]
                               ? (temp          => _K2C($data->[$val + 5]),
                                  timeBeforeObs => $data->[$val + 4] == 0
                                         ? { hours => 0-$data->[$val + 3] }
                                         : { hoursFrom => 0-$data->[$val + 3],
                                             hoursTill => 0-$data->[$val + 4] })
                               : (notAvailable => undef)
                }}};
            }
            $ii = $val + 6;
        } elsif (/\G012113/) {
            push @{$report{section3}}, { tempMinGround => {
                s             => $s0,
                temp          => _K2C($val0),
                timeBeforeObs => { hours => 12 }
            }}
                if defined $val0;
            $ii++;
        } elsif (   /\G020003 004024 020004 020005/
                 && !exists $report{weatherSynop})
        {
           #if (defined $val0) {
           #    my $wxIndVal;

           #    $wxIndVal =   $val0 < 100  ? 1
           #                : $val0 < 200  ? 7
           #                : $val0 == 508 ? ($is_auto ? 5 : 2)
           #                : $val0 == 509 ? ($is_auto ? 6 : 3)
           #                :                0;
           #    $report{wxInd} = { s => $wxIndVal, wxIndVal => $wxIndVal }
           #        if $wxIndVal;
           #}

            if (   ($val0 // 509) < 509
                || (defined $data->[$ii + 1] && defined $data->[$ii + 2])
                || (defined $data->[$ii + 1] && defined $data->[$ii + 3]))
            {
                _fixMeasurePeriod \%report, \$data->[$ii + 1],
                                  "@s[$ii .. $ii + 3]";
                $report{weatherSynop} = {
                    s             => "@s[$ii .. $ii + 3]",
                    timeBeforeObs => defined $data->[$ii + 1]
                        ? { hours => 0-$data->[$ii + 1] }
                        : { notAvailable => undef }
                };
                if (!defined $val0 || ($val0 >= 300 && $val0 != 508)) {
                    $report{weatherSynop}{weatherPresentNotAvailable} = undef;
                } elsif ($val0 == 508) {
                   $report{weatherSynop}{NSW} = undef;
                   push @{$report{warning}},
                                          { warningType => 'weatherNotOmitted' }
                       if    (   defined $data->[$ii + 2]
                              && (   $data->[$ii + 2] % 10 != 0
                                  || $data->[$ii + 2] > 19))
                          || (   defined $data->[$ii + 3]
                              && (   $data->[$ii + 3] % 10 != 0
                                  || $data->[$ii + 3] > 19));
                } elsif ($val0 < 100) {
                    $report{weatherSynop}{weatherPresent} = $val0;
                } elsif ($val0 < 200) {
                    $report{weatherSynop}{weatherPresentSimple} = $val0 - 100;
                } else {
                    # must be processed by metaf2xml::parser
                    push @{$report{weatherSynopAdd}}, {
                        s              => $s0,
                        weatherPresent => $val0 - 200,
                    };
                    $report{weatherSynop}{weatherPresentNotAvailable} = undef;
                }

                if (!exists $report{weatherSynop}{NSW}) {
                    for (1, 2) {
                        $val = $data->[$ii + $_ + 1];
                        if (($val // 20) > 19) {
                            $report{weatherSynop}{"weatherPast${_}NotAvailable"}
                                                                        = undef;
                        } else {
                            my $simple;

                            $simple = $val > 9 ? 'Simple' : '';
                            $report{weatherSynop}{"weatherPast$_$simple"} =
                                                                      $val % 10;
                        }
                    }
                }
            }

            $ii += 4;
        } elsif (/\G004025 004025 020003/) {
            if (   defined $val0
                || defined $data->[$ii + 1]
                || defined $data->[$ii + 2])
            {
                _fixMeasurePeriod \%report, \$val0, "@s[$ii .. $ii + 2]";
                push @{$report{section3}}, { weatherSynopAmpl => {
                    s              => "@s[$ii .. $ii + 2]",
                    timeBeforeObs  =>      defined $val0
                                        && defined $data->[$ii + 1]
                                        && $data->[$ii + 1] == 0
                                      ? { hours => -$val0 / 60 }
                                      : { notAvailable => undef },
                    weatherPresent => $data->[$ii + 2]
                }};
            }
            $ii += 3;
        } elsif (/\G020003/ && defined $val0 && $val0 < 100) {
            push @{$report{section3}}, { weatherSynopAdd => {
                s              => $s0,
                weatherPresent => $val0
            }};
            $ii++;
        } elsif (   /\G(020023 020024 |020054 020023 |020054 020025 020026 |020040 020066 |020021 020067 )020027/
                 && ($data->[$ii + length($1) / 7] // 0) == 0)
        {
            # dangerous weather phenomena, but phenomena occurrence = 0
            $ii += length($1) / 7 + 1;
        } elsif (   exists $report{isSynop}
                 && /\G020021 020067 020027/
                 && defined $val0            && $val0 == 1024
                 && defined $data->[$ii + 1]
                 && defined $data->[$ii + 2] && $data->[$ii + 2] == 256)
        {
            push @{$report{section3}}, { wetsnowDeposit => {
                s => "@s[$ii .. $ii + 2]",
                diameter => { v => $data->[$ii + 1] * 1000, u => 'MM' }
            }};
            $ii += 3;
        } elsif (/\G004024 014031/) {
            # TODO: sunshinePeriod/@v=24 != sunshinePeriod/@v=p !?!
            if (defined $val0 && defined $data->[$ii + 1]) {
                _fixMeasurePeriod \%report, \$val0, "@s[$ii, $ii + 1]";
                _addRadiationSun \%report, {
                    s              => "@s[$ii, $ii + 1]",
                    sunshine       => { v => $data->[$ii + 1], u => 'MIN' },
                    sunshinePeriod => { v => 0-$val0, u => 'H' }
                };
            }
            $ii += 2;
        } elsif (/\G004024 014002 014004 014016 014028 014029 014030/) {
# TODO?
# 014002, 014004: 1310 B tables have reference -2048, width 12
#         all others have reference -65536, width 17
# 014028. 014029, 014030: 1146 B tables have width 16
#         all others have width 20
            _fixMeasurePeriod \%report, \$val0, "@s[$ii .. $ii + 6]";
            _addRadiationSun \%report, {
                s => "@s[$ii .. $ii + 5 + (defined $data->[$ii + 6] ? 0 : 1)]",
                defined $data->[$ii + 1]
                    ? (rad4DownwardLongWave => { radiationValue =>
                                 { v => $data->[$ii + 1] / 1000, u => 'kJm2' }})
                    : (),
                defined $data->[$ii + 2]
                    ? (rad6ShortWave => { radiationValue =>
                                 { v => $data->[$ii + 2] / 1000, u => 'kJm2' }})
                    : (),
                defined $data->[$ii + 3] && $data->[$ii + 3] >= 0
                    ? (rad0PosNet => { radiationValue =>
                                 { v => $data->[$ii + 3] / 1000, u => 'kJm2' }})
                    : (),
                defined $data->[$ii + 3] && $data->[$ii + 3] < 0
                    ? (rad1NegNet => { radiationValue =>
                                { v => -$data->[$ii + 3] / 1000, u => 'kJm2' }})
                    : (),
                defined $data->[$ii + 4]
                    ? (rad2GlobalSolar => { radiationValue =>
                                 { v => $data->[$ii + 4] / 1000, u => 'kJm2' }})
                    : (),
                defined $data->[$ii + 5]
                    ? (rad3DiffusedSolar => { radiationValue =>
                                 { v => $data->[$ii + 5] / 1000, u => 'kJm2' }})
                    : (),
                radiationPeriod      => { v => 0-$val0, u => 'H' },
                sunshinePeriod       => { v => 0-$val0, u => 'H' },
                sunshineNotAvailable => undef,
            }
                if    defined $val0
                   && (   defined $data->[$ii + 1]
                       || defined $data->[$ii + 2]
                       || defined $data->[$ii + 3]
                       || defined $data->[$ii + 4]
                       || defined $data->[$ii + 5]);
            push @{$report{section3}}, { radDirectSolar => {
                s               => "$s0 $s[$ii + 6]",
                radiationPeriod => { v => 0-$val0, u => 'H' },
                radiationValue  => { v => $data->[$ii + 6], u => 'kJm2' }
            }}
                if defined $val0 && defined $data->[$ii + 6];
            $ii += 7;
        } elsif (/\G002149/) {
            $report{buoyType} = { s => $s0, buoyTypeInd => $val0 }
                if defined $val0;
            $ii++;
        } elsif (/\G020062/ && defined $val0) {
            my $tag;

            if ($val0 < 10) {
                $tag = 'stateOfGround';
            } else {
                $tag = 'stateOfGroundSnow';
                $val0 -= 10;
            }
            push @{$report{section3}}, { $tag => {
                s           => $s0,
                "${tag}Val" => $val0
            }};
            $ii++;
        } elsif (/\G013013/ && defined $val0) {
# TODO?
# 013013: 98000000 has reference 0
#         all others have reference -2
            push @{$report{section3}}, { snowDepth => {
                s            => $s0,
                precipAmount => { v => $val0 * 100, u => 'CM' }
            }};
            $ii++;
        } elsif (exists $report{isSynop} && /\G((?:007061 012130 )+)007061/) {
            for (1..length($1) / 14) {
                my $len = $_ == length($1) / 14 ? 3 : 2;

                if (defined $data->[$ii] && defined $data->[$ii + 1]) {
                    push @{$report{section5}}, { soilTemp => {
                        s     => "@s[$ii .. $ii + $len - 1]",
                        depth => { v => $data->[$ii], u => 'M' },
                        temp  => _K2C $data->[$ii + 1]
                    }};
                } else {
                    $not_processed_s .= _not_processed $data, \@s,
                                                       $ii, $ii + $len - 1;
                }
                $ii += $len;
            }
        } elsif (exists $report{isSynop} && /\G004024 002004 013033/) {
            if (   defined $val0
                && defined $data->[$ii + 1]
                && defined $data->[$ii + 2])
            {
                _fixMeasurePeriod \%report, \$val0, "@s[$ii .. $ii + 2]";
                push @{$report{section3}}, { evapo => {
                        s => "@s[$ii .. $ii + 2]",
                        timeBeforeObs  => { hours => 0-$val0 },
                        evapoIndicator => $data->[$ii + 1],
                        evapoAmount    => { v => $data->[$ii + 2], u => 'kgm2' }
                }};
            }
            $ii += 3;
        } elsif (   exists $report{isSynop}
                 && /\G(?:008002 020054 ){3}/
                 && defined $val0 && $val0 == 7
                 && defined $data->[$ii + 2] && $data->[$ii + 2] == 8
                 && defined $data->[$ii + 4] && $data->[$ii + 4] == 9)
        {
            push @{$report{section3}}, { cloudTypesDrift => {
                s => "@s[$ii .. $ii + 5]",
                _codeTable020054('Low', $data->[$ii + 1]),
                _codeTable020054('Middle', $data->[$ii + 3]),
                _codeTable020054('High', $data->[$ii + 5])
            }}
                if    defined $data->[$ii + 1]
                   || defined $data->[$ii + 3]
                   || defined $data->[$ii + 5];
            $ii += 6;
        } elsif (exists $report{isSynop} && /\G004024 013012 /gc) {
# TODO?
# 013012: 98000000 has reference 0
#         all others have reference -2
            $val = /\G004024/ && ($data->[$ii + 2] // -1) == 0 ? 2 : 1;
            if (   defined $val0
                && defined $data->[$ii + 1]
                && defined $data->[$ii + $val])
            {
                _fixMeasurePeriod \%report, \$val0, "@s[$ii, $ii + $val]";
                push @{$report{section3}}, { snowFall => {
                    s             => "@s[$ii .. $ii + $val]",
                    timeBeforeObs => { hours => 0-$val0 },
                    precipAmount  => { v => $data->[$ii + 1] / 100, u => 'CM' }
                }};
            }
            $ii += 1 + $val;
        } elsif (   exists $report{isBuoy}
                 && !exists $report{qualityGroup2}
                 && /\G033022 033023 033027/
                 && defined $val0
                 && defined $data->[$ii + 1]
                 && defined $data->[$ii + 2])
        {
# TODO?
# code table 033027 0: 778 C tables have "RADIUS > 1500 M"
#                      all others have "RADIUS >= 1500 M"
            $report{qualityGroup2} = {
                s                   => "@s[$ii .. $ii + 2]",
                qualityTransmission => $val0,
                qualityLocation     => $data->[$ii + 1],
                qualityLocClass     => $data->[$ii + 2]
            };
            $ii += 3;
        } elsif (   exists $report{isBuoy}
                 && !exists $report{drogueType}
                 && /\G002034/)
        {
            $report{drogueType} = {
                s => $s0,
                $val0 =~ /^[0-5]$/ ? (drogueTypeInd => $val0)
                                   : (invalidFormat => $val0)
            }
                if defined $val0;
            $ii++;
        } elsif (   exists $report{isBuoy}
                 && !exists $report{cableLengthDrogue}
                 && /\G007070/)
        {
            $report{cableLengthDrogue} = {
                s      => $s0,
                length => { v => $val0, u => 'M' }
            }
                if defined $val0;
            $ii++;
        } elsif (   exists $report{isBuoy}
                 && !exists $report{batteryVoltage}
                 && /\G025026/)
        {
            $report{batteryVoltage} = {
                s                 => $s0,
                batteryVoltageVal => sprintf '%.1f', $val0
            }
                if defined $val0;
            $ii++;
        } elsif (   exists $report{isBuoy}
                 && !exists $report{submergence}
                 && /\G002190/)
        {
            $report{submergence} = {
                s              => $s0,
                submergenceVal => $val0
            }
                if defined $val0;
            $ii++;
        } else {
            # replace non-IA5 characters
            if (defined $val0) {
                $s[$ii] =~ s/[^ -\x7e]/?/g;
                $not_processed_s .= ' ' . $s[$ii];
            }
            $is_processed = 0;
            $ii++;
        }
    }

    push @{$report{warning}}, {
        warningType => 'notProcessed',
        s           => substr $not_processed_s, 1
    }
        if $not_processed_s ne '';

    # force order for amdarObs
    for my $amdarObs (@{$report{amdarObs}}) {
        for (qw(flightLvl aircraftLocation windAtPA rollAngleQuality temperature
                turbulenceAtPA))
        {
            if (exists $amdarObs->{$_}) {
                push @{$amdarObs->{sortedArr}}, { $_ => $amdarObs->{$_} };
                delete $amdarObs->{$_};
            }
        }
    }

    # complete / force order for amdarInfo
    if (exists $report{amdarInfo}) {
        if (keys(%{$report{amdarInfo}}) == 1) {
            $report{amdarInfo}{notAvailable} = undef;
        } else {
            for (qw(navSystem amdarSystem tempPrecision)) {
                if (exists $report{amdarInfo}{$_}) {
                    push @{$report{amdarInfo}{sortedArr}},
                                               { $_ => $report{amdarInfo}{$_} };
                    delete $report{amdarInfo}{$_};
                }
            }
        }
    }

    $report{msg} = "@s";

    return %report;
}

sub _bufrstr2report {
    return _bufr2report _str2arr;
}

=head1 SEE ALSO

L<http://metaf2xml.sourceforge.net/>

=head1 COPYRIGHT and LICENSE

copyright (c) 2012-2016 metaf2xml @ L<http://metaf2xml.sourceforge.net/>

This file is part of metaf2xml.

metaf2xml is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

metaf2xml is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with metaf2xml.  If not, see L<http://www.gnu.org/licenses/>.

=cut

1;
