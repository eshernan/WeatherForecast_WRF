#!/usr/bin/perl

########################################################################
# metaf2xml.pl 2.1
#   example script to parse and print METAR/TAF/SYNOP/BUOY/AMDAR messages
#
# copyright (c) 2006-2016 metaf2xml
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
########################################################################

########################################################################
# some things strictly Perl
########################################################################
use strict;
use warnings;
use 5.010_001;

=head1 NAME

metaf2xml.pl - parse and print METAR/TAF/SYNOP/BUOY/AMDAR messages

=head1 SYNOPSIS

 metaf2xml.pl [OPTION]... [MESSAGE]...

=head1 DESCRIPTION

This script is an example interface to the Perl module C<metaf2xml::parser>.
Messages can be specified as arguments, each message in single or double quotes.
If no messages are given as arguments but the option -f is given, messages are
read from the specified file. If neither arguments nor option -f are given,
messages are read from the standard input.

The input is expected to consist of one message per line and in the format
specified by the I<WMO Manual No. 306>, B<without modifications due to
distribution> like providing the initial part of messages only once for
several messages or appending an "=" (equal sign) to terminate a message,
and parts of the WMO header prepended according to the option -H.
The program C<metafsrc2raw.pl> can be used to create messages with the required
format from files provided by various public Internet servers.

=head1 DEPENDENCIES

The Perl module C<metaf2xml::parser> is required.

=head1 OPTIONS

=over

=item -v

print version of metaf2xml.pl and exit

=item -H I<0..5>

which parts of the WMO header (C<TTAA[II] CCCC DDHHMM [BBB]>) are
prepended to each message. See the parameter
L<metaf2xml::src2raw/wmo_prefix>(3pm)
for a description of the WMO header and its parts.

=item -T {C<SPECI>|C<TAF>}

(initial) default message type (default: C<METAR>).
An input line consisting only of one of the keywords C<METAR>, C<SPECI> or
C<TAF> changes the default message type for all following messages.
If the option -H1, -H2, -H3, -H4 or -H5 is given, the message type for each
message is taken from the WMO header.

If a message starts with:

=over

=item C<METAR>, C<SPECI> or C<TAF>

this is used as message type for this message.

=item C<AAXX>, C<BBXX> or C<OOXX>

the message type SYNOP is used for this message.

=item C<ZZYY>

the message type BUOY is used for this message.

=item C<AMDAR>

the message type AMDAR is used for this message.

=item B<FXXYYY>C<:> or B<FXXYYY>C</> or B<FXXYYY>C<->

the message type BUFR is used for this message. See
L<Processing of decoded BUFR messages|metaf2xml::parser/Processing-of-decoded-BUFR-messages>
in L<metaf2xml::parser|metaf2xml::parser>(3pm) for a description of the format.

=back

=item -D

include DOCTYPE and reference to the DTD

=item -S I<xslt_file>

include reference to the stylesheet I<xslt_file>

=item -f I<msg_file>

read input from I<msg_file> (or standard input if it is C<->)

=item -o I<out_file>

enables writing the data to I<out_file> (or standard output if it is C<->)

=back

Without the option -o, no output is generated.

=head1 ARGUMENTS

If any arguments are given, they are processed as messages; the option C<-f>
and standard input are not used in this case.

=head1 EXIT STATUS

If an invalid option was provided or an error was encountered while writing
output or the file specified with -f cannot be opened, the script will exit
with status 1, otherwise it will exit with status 0.

=head1 EXAMPLES

Parse a METAR message and write the XML to the standard output:

 metaf2xml.pl -o- "YUDO 090600Z 00000KT CAVOK 22/15 Q1021 NOSIG"

or the same for a SYNOP message:

 metaf2xml.pl -o- "AAXX 17124 74486 32566 63616 10067 20022 39972"

Parse several METAR, TAF, SYNOP, BUOY and AMDAR messages and write the XML
to the file F<example.xml>:

 metaf2xml.pl -o example.xml << EOF
METAR
SBGL 172300Z 24007KT 9999 TS FEW015 FEW030CB BKN100 25/21 Q1013
TAF
SBGL 172130Z 1800/1906 21010KT 7000 BKN015 TX26/1800Z TN17/1823Z PROB30 TEMPO 1801/1805 4000 TSRA BKN015 FEW025CB BECMG 1808/1810 4000 BR BKN008 BECMG 1812/1814 19010KT 6000 NSW BKN012 RMK PGZ
METAR
KJFK 172351Z 14003KT 10SM CLR 14/05 A3036 RMK AO2 SLP280 T01440050 10189 20144 55002
TAF
KJFK 172320Z 1800/1906 VRB04KT P6SM SKC FM181600 18008KT P6SM SKC FM190200 VRB05KT P6SM SKC
METAR
RJTT 172330Z 35009KT CAVOK 22/16 Q1020 NOSIG RMK A3013
TAF
RJTT 172036Z 1721/1824 04012KT 9999 FEW030 BECMG 1806/1809 07014KT BECMG 1812/1815 03006KT
AAXX 17184 74486 NIL
AAXX 17184 47662 12970 20203 10203 20151 30150 40193 56005 60001 80002
ZZYY 31262 17093 13001 522980 042100 6112/ 11119 02801 10021 48214 444 20120 17093 1159/ 518// 60371
ZZYY 41955 17093 2200/ 739065 071940 6111/ 22219 00238 444 20110 17093 1828/ 50101 80119 80007 9/015
ZZYY 53904 17093 2336/ 135184 142953 6112/ 22219 00285 444 20120 17093 2331/ 50101 80092 80016 9/015
AMDAR 1605 ASC AFZA51 2624S 02759E 160414 F156 MS048 278/034 TB0 S031 333 F/// VG010
EOF

=head1 SEE ALSO

L<metaf2xml::parser|metaf2xml::parser>(3pm),
L<metaf2xml::src2raw|metaf2xml::src2raw>(3pm),
L<metafsrc2raw|metafsrc2raw>(1), L<metaf|metaf>(1),
L<http://metaf2xml.sourceforge.net/>

=head1 COPYRIGHT and LICENSE

copyright (c) 2006-2016 metaf2xml @ L<http://metaf2xml.sourceforge.net/>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

=cut

use Getopt::Std;
use Pod::Usage 'pod2usage';
# use File::Basename 'dirname';

our $VERSION = '2.1';

# path will be set by install
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(File::Spec->rel2abs(__FILE__)), 'lib');
use metaf2xml::parser 2.001 qw(start_cb start_xml parse_report process_bufr finish);

########################################################################
# process input and/or pass to parse_report()
########################################################################

sub go {
    my $opts_h = shift;
    state $default_msg_type = 'METAR';
    my ($msg_type, %WMOheader);

    if ($_ eq 'METAR' || $_ eq 'SPECI' || $_ eq 'TAF') {
        $default_msg_type = $_;
        return 1;
    }

    $msg_type = $default_msg_type;
    if ($opts_h > 0) {
        s/^(..) ?//
            or return 1;
        $WMOheader{TT} = $1;
        $msg_type = $_
            for ({ SA => 'METAR', SP => 'SPECI',
                   FC => 'TAF',   FT => 'TAF'    }->{$1} // ());

        if ($opts_h >= 2 && s/^([^ ]+) //) {
            $WMOheader{AAII} = $1;
            if ($opts_h >= 3 && s/^([^ ]+) //) {
                $WMOheader{CCCC} = $1;
                if ($opts_h >= 4 && s/^(\d\d)(\d\d)(\d\d) //) {
                    @WMOheader{qw(day hour minute)} = ($1, $2, $3);
                    if ($opts_h == 5) {
                        $WMOheader{indicator} = $1
                            if s/^(COR|(?:RR|CC|AA)[A-Z]|P[A-Z]{2}) //;
                    }
                }
            }
        }
    }

    return parse_report $_, $msg_type;
}

########################################################################
# usage
########################################################################
sub usage {
    my $msg = shift;

    if ($msg eq '') {
        pod2usage -exitval => 'NOEXIT', -output => \*STDERR, -noperldoc => 1;
        print {*STDERR} <<"EOF";
Options may be merged together.  -- stops processing of options.
Space is not required between options and their arguments.
EOF
    } else {
        print {*STDERR} $msg;
    }

    print {*STDERR} <<"EOF";

For more details run
        perldoc -F $0
EOF
    exit 1;
}

sub HELP_MESSAGE { usage ''; return; } # for Getopt::Std

my $OUT;

# make complete timestamp from day (optional!), hour, minute
sub date2ts {
    my ($day, $hour, $minute) = @_;

    # CHANGE_HERE: to be implemented
    return ($day // '') . $hour . $minute;
}

# convert temperature to C
sub temp2C {
    my ($val, $unit) = @_;

    return   !defined $val ? ''
           : $unit eq 'C'  ? $val
           :                 sprintf '%.1f', ($val - 32) / 1.8;
}

########################################################################
# example callback function to print certain values from METAR in a
# different XML format
# Data is cached (in a hash) and printed only at end of report
########################################################################
sub printXML2 {
    my ($path, $type, $node, @attrs) = @_;

    # CHANGE_HERE: add/delete paths as needed
    state $paths = {
        metar        => '/data/reports/metar/s',
        station      => '/data/reports/metar/obsStationId/s',
        day          => '/data/reports/metar/obsTime/timeAt/day/v',
        hour         => '/data/reports/metar/obsTime/timeAt/hour/v',
        minute       => '/data/reports/metar/obsTime/timeAt/minute/v',
        cloudBase_v_ => '/data/reports/metar/cloud/cloudBase/v',
        airtemp_v    => '/data/reports/metar/temperature/air/temp/v',
        airtemp_u    => '/data/reports/metar/temperature/air/temp/u',
        dewtemp_v    => '/data/reports/metar/temperature/dewpoint/temp/v',
        dewtemp_u    => '/data/reports/metar/temperature/dewpoint/temp/u',
    };

    state %report;
    my (%val, $full_path);

    # no report yet: return
    return 1
        if $#$path < 2;

    # start of report: init for report
    %report = ()
        if $#$path == 2 && $type ne 'end';

    $full_path = join '/', @$path, $node;

    # collect data to print
    for (keys %$paths) {
        my ($p, $is_eq);

        $p     = $paths->{$_};
        $is_eq = $full_path eq $p;

        if ($type eq 'end') {
            if ($is_eq) {
                if (/_$/) {
                    push @{$report{$_}}, $val{$_};
                } else {
                    $report{$_} = $val{$_};
                }
            }
            next;
        }

        $val{$_} = ''
            if $is_eq;

        # check all attributes
        for (my $jj = 0; $jj <= $#attrs; $jj += 2) {
            my ($name, $value) = @attrs[$jj .. $jj + 1];

            next
                unless "$full_path/$name" =~ m{^$p(?:/(.*))?$};

            if (!defined $1) {
                if (/_$/) {
                    push @{$report{$_}}, $value;
                } else {
                    $report{$_} = $value;
                }
            } else {
                $val{$_} .= " $1:$value";
            }
        }

        # add matching subnode which is empty and has no attributes
        $val{$_} .= " $1"
            if $type eq 'empty' && $#_ == -1 && $full_path =~ m{^$p/(.*)$};

        if ($type eq 'empty' && $is_eq) {
            if (/_$/) {
                push @{$report{$_}}, $val{$_};
            } else {
                $report{$_} = $val{$_};
            }
        }
    }

    # if this were the only callback in this script, the following would
    # simply be done after parse_report()

    # if end of report: print selected data
    if ($#$path == 2 && $type eq 'end') {
        # don't print unless mandatory data is complete
        return 1
            unless exists $report{station} && exists $report{hour};

        # CHANGE_HERE: print added paths/omit printing of deleted paths

        # start of metar, timestamp, station
        print {$OUT}
                '<metar>',
                '<date>', date2ts(@report{qw(day hour minute)}), '</date>',
                '<station>', $report{station}, '</station>'
            or return 0;

        # print clouds (or empty string)
        for (0 .. 2) {
            print {$OUT} "<cloudBase$_>"
                or return 0;

            print {$OUT} $report{cloudBase_v_}[$_]
                    or return 0
                if exists $report{cloudBase_v_}[$_];

            print {$OUT} "</cloudBase$_>"
                or return 0;
        }

        # print temperatures
        print {$OUT}
                '<air>', temp2C(@report{qw(airtemp_v airtemp_u)}), '</air>',
                '<dew>', temp2C(@report{qw(dewtemp_v dewtemp_u)}), '</dew>'
            or return 0;

        # escape special XML characters and print message
        $report{metar} =~ s/&/&amp;/g; # must be the first substitution
        $report{metar} =~ s/</&lt;/g;
        print {$OUT} '<msg>', $report{metar}, '</msg>'
            or return 0;

        # end of metar
        print {$OUT} "</metar>\n"
            or return 0;

        return 1;
    }

    # if top node is closed: close output stream
    close $OUT
            or return 0
        if ($#$path == 0 && $type eq 'end');

    return 1;
}

# used by printVal
sub filterVal {
    my $ii = shift;

    return   $ii == 0 || $ii == 2 # ERROR, remark/notRecognised
           ? 1
             # warning/warningType
           : shift !~ /msgModified|windMissing|visibilityMissing|tempMissing|QNHMissing/;
}

########################################################################
# example callback function to print certain values from reports which
# match some filter criterium
# Data is cached (in $data_str) and printed only at end of report and
#   if criterium matches
########################################################################
sub printVal {
    my ($path, $type, $node, %attrs) = @_;

    # CHANGE_HERE: add/delete paths as needed
    state $nodes2print = [
        '/data/reports/metar/s',
        '/data/reports/metar/ERROR',
        '/data/reports/metar/warning',
        '/data/reports/metar/remark/notRecognised/s',
    ];
    state $nodes2filter = [
        '/data/reports/metar/ERROR',
        '/data/reports/metar/warning/warningType',
        '/data/reports/metar/remark/notRecognised',
    ];

    state ($data_str, $found);
    my (@print_val, @filter_val, $full_path);

    # no report yet: return
    return 1
        if $#$path < 2;

    # start of report: init for report
    if ($#$path == 2 && $type ne 'end') {
        $found    = $#$nodes2filter == -1; # found if no filter
        $data_str = '';
    }

    $full_path = join '/', @$path, $node;

    # collect data to print
    for my $ii (0 .. $#$nodes2print) {
        my ($p, $is_eq);

        $p     = $nodes2print->[$ii];
        $is_eq = $full_path eq $p;

        if ($type eq 'end') {
            $data_str .= "$ii $p:" . $print_val[$ii] . "\n"
                if $is_eq;
            next;
        }

        if ($is_eq) {
            $print_val[$ii]  = '';
            $filter_val[$ii] = ();
        }

        # check all attributes
        for my $key (keys %attrs) {
            next
                unless "$full_path/$key" =~ m{^$p(?:/(.*))?$};

            if (!defined $1) {
                $data_str .= "$ii $p:$attrs{$key}\n";
            } else {
                $print_val[$ii] .= " $1:$attrs{$key}";
            }
        }

        # add matching subnode which is empty and has no attributes
        $print_val[$ii] .= " $1"
            if $type eq 'empty' && $#_ == -1 && $full_path =~ m{^$p/(.*)$};

        $data_str .= "$ii $p:" . $print_val[$ii] . "\n"
            if $type eq 'empty' && $is_eq;
    }

    # check filters to decide whether to print the report
    for my $ii (0 .. $#$nodes2filter) {
        my ($p, $is_eq);

        $p     = $nodes2filter->[$ii];
        $is_eq = $full_path eq $p;

        if ($type eq 'end') {
            $found ||= filterVal $ii, $filter_val[$ii]
                if $is_eq;
            next;
        }

        # check all attributes
        for my $key (keys %attrs) {
            next
                unless "$full_path/$key" =~ m{^$p(?:/(.*))?$};

            if (!defined $1) {
                $found ||= filterVal $ii, $attrs{$key};
            } else {
                push @{$filter_val[$ii]}, $1, $attrs{$key};
            }
        }

        # add matching subnode which is empty and has no attributes
        push @{$filter_val[$ii]}, $1, undef
            if $type eq 'empty' && $#_ == -1 && $full_path =~ m{^$p/(.*)$};

        $found ||= filterVal $ii, $filter_val[$ii]
            if $type eq 'empty' && $is_eq;
    }

    # if this were the only callback in this script, the following would
    # simply be done after parse_report()

    # if end of report: print selected data unless report is filtered out
    print {$OUT} $data_str
            or return 0
        if ($#$path == 2 && $type eq 'end' && $found);

    # if top node is closed: close output stream
    close $OUT
            or return 0
        if ($#$path == 0 && $type eq 'end');

    return 1;
}

########################################################################
# example callback function to print node paths with (their) values
# features:
# - Print full path and attributes, but skip nodes with subnodes but
#   without attributes, or only 's' (except for nodes 'ERROR', 'warning'
#   and at the start of the report).
# - Print data in abridged form if a node has only 'v', or 'v' and 'u'.
# - Print line '-/path/...-' to delimit adjacent nodes with the same name.
# - After each report an empty line is printed.
# - Data is not cached, but printed immediately
########################################################################
sub simpleDump {
    my ($path, $type, $node, @attrs) = @_;
    state $prev_path = '';

    if ($type eq 'end') {
        if ($#$path == 2) {
            $prev_path = '';
            return print {$OUT} "\n";
        }
        $prev_path = join '/', @$path, $node;
        return 1;
    }

    print {$OUT} "-$prev_path-\n"
            or return 0
        if join('/', @$path, $node) eq $prev_path;

    # also delimit adjacent empty nodes with the same name
    $prev_path = join '/', @$path, $node
        if $type eq 'empty';

    return 1
        if    $type eq 'start'
           && $#$path != 2
           && ($#attrs < 1 || ($#attrs == 1 && $attrs[0] eq 's'));

    print {$OUT} join '/', @$path, $node
        or return 0;

    # print short form for 'v' only, or 'v' and 'u', only
    return print {$OUT} ' = ' . $attrs[1] . "\n"
        if $#attrs == 1 && $attrs[0] eq 'v';
    return print {$OUT} ' = ' . $attrs[1] . ' ' . $attrs[3] . "\n"
        if $#attrs == 3 && $attrs[0] eq 'v' && $attrs[2] eq 'u';

    # print name and value of attributes (except 's' in most cases)
    while (defined (my $name = shift @attrs)) {
        my $value = shift @attrs;

        print {$OUT} " $name=$value"
                or return 0
            if (   $name ne 's'
                || { map { $_ => 1 } qw(metar taf synop buoy amdar
                                        warning ERROR notRecognised)
                   }->{$node});
    }
    print {$OUT} "\n"
        or return 0;

    # if top node is closed: close output stream
    close $OUT
            or return 0
        if ($#$path == 0 && $type eq 'end');

    return 1;
}

########################################################################
# pass all kinds of input to go()
########################################################################
sub main {
    my %opts;

    # get and check options
    $Getopt::Std::STANDARD_HELP_VERSION = 1;
    usage ''
        unless getopts('vf:o:H:T:DS:', \%opts);
    if (exists $opts{v}) {
        print "metaf2xml.pl version $VERSION\n" or exit 1;
        return 1;
    }
    $opts{H} = 0
        unless exists $opts{H} && $opts{H} =~ /^[0-5]$/;

    # overwrite initial state for message type
    if (exists $opts{T}) {
        if ($opts{T} eq 'SPECI' || $opts{T} eq 'TAF') {
            $_ = $opts{T};
            go;
        } elsif ($opts{T} ne 'BUFR') { # TODO: -TBUFR is deprecated
            usage "ERROR: invalid message type: '$opts{T}'\n";
        }
    }

    #open($OUT, ">$opts{o}") && start_cb \&printVal
    #open($OUT, ">$opts{o}") && start_cb \&printXML2
    #open($OUT, ">$opts{o}") && start_cb \&simpleDump
    start_xml \%opts
            or usage "ERROR: start_cb() failed\n"
        if exists $opts{o};

    if ($#ARGV >= 0) {
        RET: for (@ARGV) {
            for (split /\n/, $_) {
                go $opts{H} or last RET;
            }
        }
    } elsif (exists $opts{f} && ($opts{T} // '') eq 'BUFR') {
        # TODO: -TBUFR is deprecated
        my ($rc, $bufr, $data, $desc);

        sub do_filter {
            my $self = shift;
            my ($cat, $sub);

            $cat = $self->get_data_category;
            $sub = $self->get_int_data_subcategory // 255;

            return    $cat == 2 || $cat == 3 || $cat > 4
                   || { map { $_ => 1 } qw(0_14 0_20 0_30 0_40 1_20 1_30 1_31 4_1) }->{"${cat}_$sub"};
        }

        $rc = eval {
            require Geo::BUFR;
            Geo::BUFR->VERSION >= 1.31;
        };
        usage "ERROR: cannot load Geo::BUFR 1.31+: $@\n"
            if !$rc || $@;

        Geo::BUFR->set_tablepath($ENV{BUFR_TABLES});
        $bufr = Geo::BUFR->new();
        $bufr->set_strict_checking(0);
        $bufr->set_show_all_operators(0);
        $bufr->set_filter_cb(\&do_filter)
            if $bufr->can('set_filter_cb');
        $bufr->reuse_current_ahl(1)
            if $bufr->can('reuse_current_ahl');

        $bufr->fopen($opts{f})
            or usage "ERROR: cannot open '$opts{f}'\n";
        while (1) {
            $rc = eval {
                ($data, $desc) = $bufr->next_observation();
            };
            last
                if $bufr->eof;
            if ($@) {
                print {*STDERR} $@;
                next;
            }
            if (!$rc) {
                print {*STDERR} 'ERROR: rc: "' . ($rc // '(undef)') . '"';
                next;
            }
            next
                if $bufr->can('is_filtered') && $bufr->is_filtered();

            process_bufr $data, $desc
                or last;
        }
        $bufr->fclose();
    } elsif (exists $opts{f}) {
        my ($rc, $fh);

        # use two-argument "open" for special files, only
        if ($opts{f} eq '-' || $opts{f} =~ /^&\d+$/) {
            $rc = open $fh, "<$opts{f}";
        } else {
            $rc = open $fh, '<', $opts{f};
        }
        usage "ERROR: cannot open '$opts{f}': $!\n"
            unless $rc;
        while (<$fh>) {
            chomp;
            go $opts{H} or last;
        }
        if (!close $fh) {
            print {*STDERR} "ERROR: close input file '$opts{f}' failed: $!\n";
            exit 1;
        }
    } else {
        while (<>) {
            chomp;
            go $opts{H} or last;
        }
    }

    return exists $opts{o} ? finish : 1;
}

# don't run if loaded as a library
return 1
    if caller;

exit !main;
