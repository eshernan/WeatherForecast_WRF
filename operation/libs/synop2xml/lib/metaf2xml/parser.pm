########################################################################
# metaf2xml/parser.pm 2.1
#   parse a METAR/TAF/SYNOP/BUOY/AMDAR message and write the data as XML
#   or provide access to the data via a callback function
#
# copyright (c) 2006-2016 metaf2xml
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

package metaf2xml::parser;

########################################################################
# some things strictly Perl
########################################################################
use strict;
use warnings;
use 5.010_001;

use POSIX qw(floor);

########################################################################
# export the functions provided by this module
########################################################################
BEGIN {
    require Exporter;

    our @ISA       = qw(Exporter);
    our @EXPORT_OK = qw(start_cb start_xml parse_report process_bufr finish);
}

END {}

our $VERSION = 2.001;
sub VERSION {
    my ($pkg, $vers) = @_;

    die "$pkg version $vers required--this is version $VERSION\n"
        if $#_ == 1 && $vers != $VERSION;
    return $VERSION;
}

use metaf2xml::bufr 2.001;

=head1 NAME

metaf2xml::parser - parse a METAR/TAF/SYNOP/BUOY/AMDAR message

=head1 SYNOPSIS

 use metaf2xml::parser 2.001;

 # pass the data to a callback function:
 metaf2xml::parser::start_cb(\&cb);                        # mandatory
 metaf2xml::parser::parse_report($msg,$default_msg_type);  # repeat as necessary
 metaf2xml::parser::process_bufr(\@data,\@desc);           # repeat as necessary
 metaf2xml::parser::finish();                              # optional

 # write the data as XML:
 metaf2xml::parser::start_xml(\%opts);                     # mandatory
 metaf2xml::parser::parse_report($msg,$default_msg_type);  # repeat as necessary
 metaf2xml::parser::process_bufr(\@data,\@desc);           # repeat as necessary
 metaf2xml::parser::finish();                              # mandatory

=head1 DESCRIPTION

This Perl module provides a function to analyze a string (per default as a METAR
message) and functions to write the extracted data as XML, or pass each
data item to a callback function.

=cut

########################################################################
# define lots of regular expressions
########################################################################
my $re_ICAO = '(?:[A-Z][A-Z\d]{3})';
my $re_day = '(?:0[1-9]|[12]\d|3[01])';
my $re_hour = '(?:[01]\d|2[0-3])';
my $re_min = '[0-5]\d';
my $re_bbb = '(?:(?:RR|CC|AA)[A-Z]|P[A-Z]{2})';
# https://www.wmo.int/pages/prog/amp/mmop/wmo-number-rules.html
my $re_A1bw = '(?:1[1-8]|2[1-6,8]|3[1-4,8]|4[1-8]|5[1-6,8]|6[1-6,8]|7[1-4,8])';
# WMO-No. 306 Vol I.1, Part A, code table 0877, but only actual directions
my $re_dd = '(?:0[1-9]|[12]\d|3[0-6])';
my $re_rwy_des = "$re_dd(?:[LCR]|LL|RR)?";
my $re_rwy_des2 = '(?:[05][1-9]|[1267]\d|[38][0-6])'; # add 50 for rrR
my $re_wind_speed = 'P?[1-9]?\d\d';
my $re_wind_speed_unit = '(?: ?KTS?| ?MPS| ?KMH)';
my $re_wind_dir = "(?:$re_dd|00)";
my $re_wind_dir3 = '(?:[012]\d\d|3[0-5]\d|360)';
# EXTENSION: allow wind direction not rounded to 10 degrees
my $re_wind = "(VRB|///|$re_wind_dir3)(//|$re_wind_speed)(?:G($re_wind_speed))?($re_wind_speed_unit)";
my $re_vis = '(?:VIS|VSBY?)';
my $re_vis_m = '(?:0[0-7]50|[0-4]\d00|\d000|9999)';
my $re_vis_km = '[1-9]\d?KM';
my $re_vis_m_km_remark3 = "(?:($re_vis_m)M?|([1-9]\\d{2,3})M|([1-9]\\d?)KM)";

my $re_frac16 = '[135]/16';
my $re_frac8  = '[1357]/8';
my $re_frac4  = '[13]/4';
my $re_frac2  = '1/2';
my $re_vis_frac_sm0 = "(?:$re_frac16|$re_frac8|$re_frac4|$re_frac2)";
# MANAIR 2.6.8: no space between whole miles and fraction
my $re_vis_frac_sm1 = "1(?: ?(?:$re_frac8|$re_frac4|$re_frac2))";
# EXTENSION: allow /8 for 2 miles
my $re_vis_frac_sm2 = "2(?: ?(?:$re_frac8|$re_frac4|$re_frac2))";
# EXTENSION: allow /2 for 3 miles
my $re_vis_frac_sm3 = "3(?: ?(?:$re_frac2))";
my $re_vis_whole_sm = '(?:[1-9]\d0|1[0-5]|[2-9][05]|\d)'; # longest match first
my $re_vis_sm =   '(?:M1/4'
                .   "|$re_vis_frac_sm0"
                .   "|$re_vis_frac_sm1"
                .   "|$re_vis_frac_sm2"
                .   "|$re_vis_frac_sm3"
                .   "|$re_vis_whole_sm)"; # last, to find fractions first

my $re_gs_size = "(?:M1/4|[1-9]\\d*(?: $re_frac4| $re_frac2)?|$re_frac4|$re_frac2)";
# don't confuse with rwyState without trailing //: EGMC 110920Z ... R06/8503
my $re_rwy_vis = '[PM]?\d{4}';
my $re_rwy_vis_strictM = '[PM]?(?:0[0-3](?:[05]0|[27]5)|0[4-7][05]0|\d\d00)';
my $re_rwy_vis_strictFT = '[PM]?(?:0\d00|[12][02468]00|[3-5][05]00|6000)';
my $re_rwy_wind = "(?:WIND )?(?:R(?:WY)?($re_rwy_des)[ /]?|($re_rwy_des)/)((?:///|VRB|${re_wind_dir}0)(?://|$re_wind_speed(?:G$re_wind_speed)?)$re_wind_speed_unit)(?: ($re_wind_dir3)V($re_wind_dir3))?";
my $re_rwy_wind2 = "((?:///|VRB|${re_wind_dir}0)(?://|$re_wind_speed(?:G$re_wind_speed)?)$re_wind_speed_unit)/RWY($re_rwy_des)";

# format change around 03/2009: trailing 0 for wind direction
my $re_rs_rwy_wind = "(RS|$re_rwy_des)($re_wind_dir)0?($re_wind_speed(?:G$re_wind_speed)?$re_wind_speed_unit)";

my $re_compass_dir = '(?:[NS]?[EW]|[NS])';
my $re_compass_dir16 = "(?:[NE]NE|[ES]SE|[SW]SW|[NW]NW|$re_compass_dir)";

# represents exact location
my $re_loc_exact = '(?:(?:OVR|AT) AP)';

# approximate location
my $re_loc_approx = '(?:OMTNS|OVR (?:LK|RIVER|VLYS|RDG)|ALG (?:RIVER|SHRLN)|IN VLY|NR AP|VC AP)';

# inexact/all direction(s)
my $re_loc_inexact = '(?:ARND|ALQDS|V/D)';

# inexact distance
my $re_loc_dsnt_vc = '(?:DSNT|VC)';

# compass direction or quadrant, with optional exact distance
my $re_loc_compass = "(?:(?:(?:$re_loc_dsnt_vc|[1-9]\\d*(?:KM|NM)? ?))?(?:TO )?(?:GRID )?$re_compass_dir16(?: QUAD)?)";

my $re_loc_thru = "(?:(?:$re_loc_dsnt_vc )?(?:TO )?(?:(?:(?:$re_loc_compass(?: $re_loc_approx)?|(?:$re_loc_approx |OBSCG MTNS )?$re_loc_compass|OHD)(?:(?: ?- ?| THRU )(?:$re_loc_compass|OHD))*)|$re_loc_approx|$re_loc_inexact)|$re_loc_exact)";
my $re_loc_and = "(?:$re_loc_thru(?:(?:[+/, ]| AND )$re_loc_thru)*)";
my $re_loc = "(?:[ /-]$re_loc_and)";
my $re_wx_mov_d3 = "(?: (MOVD?) ($re_compass_dir16(?:-$re_compass_dir16)*|OHD|UNKN)| (STNRY))";
my $re_num_quadrant1 = '(?:1(?:ST|ER)?|2(?:ND)?|3(?:RD)?|4(?:TH)?)';
my $re_num_quadrant  = "(?: $re_num_quadrant1(?:[- ]$re_num_quadrant1)*[ /]?QUAD)";

my $re_loc_quadr3 = "(?:(?: TO)?($re_loc)|(?:(?: (DSNT))?($re_num_quadrant)))";

my $re_weather_desc  = '(?:MI|BC|PR|DR|BL|SH|TS|FZ)';
# EXTENSION: allow IC (removed in FM {15,16,51}-XV 2013)
my $re_weather_prec  = '(?:(?:DZ|RA|SN|SG|PL|GR|GS)+|IC|UP)';
my $re_weather_obsc  = '(?:BR|FG|FU|VA|DU|SA|HZ)';
my $re_weather_other = '(?:PO|SQ|FC|SS|DS)';
# EXTENSION: allow SHRADZ (ENHK)
my $re_weather_ts_sh = '(?:RA|SN|PL|GR|GS|DZ)+|UP';
my $re_weather_bl_dr = '(?:SN|SA|DU)';
# WMO-No. 306 Vol I.1, Part A, Section C:
#   Intensity shall be indicated only with precipitation, precipitation
#   associated with showers and/or thunderstorms, duststorm or sandstorm.
#   Not more than one descriptor shall be included in a w´w´ group ...
# EXTENSION: allow JP (adjacent precipitation in old METAR)
# EXTENSION: allow FZRA(SN|PL)+
# EXTENSION: allow +/- with *FG, DS, SS, BR, TS
my $re_weather_w_i =   "(?:$re_weather_prec|FC|JP"
                     . "|(?:TS|SH)(?:$re_weather_ts_sh)"
                     . '|FZ(?:(?:RA|DZ)+|UP)'
                     . '|FZRA(?:SN|PL)+'
                     . '|(?:FZ|MI|BC|PR)?FG'
                     . '|DS|SS|BR|TS)';
# FMH-1 12.6.8a
#   Intensity shall be coded with precipitation types, except ice crystals
#   (IC), hail (GR or GS), and unknown precipitation (UP)
# -> if no intensity is given for IC, GR, GS, *UP: don't add isModerate
# EXTENSION: allow BLPY (BY in SAO), FZBR
my $re_weather_wo_i =   "(?:$re_weather_obsc|$re_weather_other|TS|IC|GR|GS"
                      . '|(?:FZ|SH|TS)?UP'
                      . '|(?:FZ|MI|BC|PR)FG'
                      . '|FZBR'
                      . "|(?:BL|DR)$re_weather_bl_dr|BLPY)";
my $re_weather_vc = "(?:FG|PO|FC|DS|SS|TS(?:$re_weather_ts_sh)?|SH|BL$re_weather_bl_dr|VA)";
# annex 3, form:
# FZDZ FZRA DZ   RA   SHRA SN SHSN SG SHGR SHGS BLSN SS DS
# TSRA TSSN TSPL TSGR TSGS FC VA   PL UP
# annex 3, text:
# FZDZ FZRA DZ   RA   SHRA SN SHSN SG SHGR SHGS BLSN SS DS
#                          FC VA   PL    TS
# EXTENSION: allow FZFG
# EXTENSION to AMOFSG/10-SoD Appendix G: allow multiple phenomenona per group
my $re_weather_re =   "(?:(?:FZ|SH)?$re_weather_prec"
                    . "|TS(?:$re_weather_ts_sh)"
                    . '|FZFG|BLSN|DS|SS|TS|FC|VA|UP)';
# EXTENSION: allow [+-]VC...
# EXTENSION: Canada uses +BLSN, +BLSA, +BLDU (MANOBS chapter 20)
my $re_weather = "(?:[+-]?$re_weather_w_i|[+]BL$re_weather_bl_dr|$re_weather_wo_i|[+-]?VC$re_weather_vc)";

my $re_cloud_cov  = '(?:FEW|SCT|BKN|OVC)';
my $re_cloud_base = '(?:///|\d{3})';
my $re_cloud_type = '(?:AC(?:C|SL)?|AS|CB(?:MAM)?|CC(?:SL)?|CI|CS|CU(?:FRA)?|CF|NS|SAC|SC(?:SL)?|ST(?:FRA)?|SF|TCU)';

# EXTENSION: allow // for last 2 digits
# EXTENSION: allow tenths of hPa as .\d (FLLS, HUEN, OPRN)
# EXTENSION: allow QNH\d{4}INS, A\d{4}INS
my $re_qnh = '(?:(?:Q ?[01]\d|A ?[23]\d[./]?)(?:\d\d|//)|(?:QNH|A)[23]\d{3}INS|[AQ]////|Q[01]\d{3}\.\d)';

# prefixes for unrecognised groups, with some exceptions
my $re_unrec         = '(?:(?!RMK|TEMPO|BECMG|INTER|FM|PROB)(?:([^ ]+) )??)';
my $re_unrec_cloud   = "(?:(?!RMK|TEMPO|BECMG|INTER|FM|PROB|$re_weather |(?:M?\\d\\d|//)/(?:M?\\d\\d|//) |[AQ][\\d/]{4})(?:([^ ]+) )??)";
my $re_unrec_weather = "(?:(?!RMK|TEMPO|BECMG|INTER|FM|PROB|SKC|NSC|CLR|NCD|VV|$re_cloud_cov|[AQ][\\d/]{4})(?:([^ ]+) )??)";

my $re_colour1 = 'BLU[/+]?|WHT|GRN|YLO[12]?|AMB|RED';
my $re_colour  = "(?:(?:BL(?:AC)?K ?)?(?:$re_colour1)(?: ?(?:$re_colour1|FCST CANCEL))?|BL(?:AC)?K)";

my $re_be_weather_be = "(?:[BE]$re_hour?$re_min)";
my $re_be_weather    =
      "(?:(?:[+-]?$re_weather_w_i|$re_weather_wo_i)(?: ?$re_be_weather_be|[BE]MM)+)";

my $re_rsc_cond    = '(?:DRY|WET|SANDED)';
my $re_rsc_deposit = '(?:LSR|SLR|PSR|IR|WR)+(?://|\d\d)?';
my $re_rsc         =
    "(?:$re_rsc_deposit(?:P(?:[ /]$re_rsc_cond)?)?|(?:(?:P[ /])?$re_rsc_cond))";

my $re_snw_cvr_title = '(?:SNO?W? ?(?:CVR|COV(?:ER)?)?[/ ])';
my $re_snw_cvr_state =
       '(?:(?:ONE |MU?CH |TR(?:ACE)? ?)LOOSE|(?:MED(?:IUM)?|HARD) PACK(?:ED)?)';
my $re_snw_cvr =
             "(?:$re_snw_cvr_title?($re_snw_cvr_state)|${re_snw_cvr_title}NIL)";

my $re_temp = '(?:-?\d+\.\d)';
my $re_precip = '(?:\d{1,2}(?:\.\d)?(?: ?[MC]M)?)';

my $re_opacity_phenom =
    '(?:RA|SHGR|PL|IC|(?:BL)?SN|BLDU|FG?|DS|HZ|BLSA|SS|FU|VA|DZ|IC|AS|ACC?|CC|CF|CI|CS|CU(?:FRA)?|TCU|NS|ST|SF|SC|CB)';
my $re_trace_cloud = '(?:AC|AS|CF|CI|CS|CU(?:FRA)?|SC|SF|ST|TCU)';

my $re_phen_desc_when = '(?:OCNL|FRE?Q|INTMT|CON(?:TU)?S|CNTS|PAST HR)';
my $re_phen_desc_how  = '(?:LOW?|LWR|ALOFT|(?:VRY |V|PR )?(?:THN|THIN|THK|THICK)|ISOL|CVCTV|DSIPTD|FREEZING|PTCHY|VERT|PTL)';
my $re_phen_desc_strength  = '(?:(?:VRY |V|PR )?(?:LGT|FBL)|MDT|MOD)';
my $re_phen_desc =
              "(?:$re_phen_desc_when|$re_phen_desc_how|$re_phen_desc_strength)";

my $re_ltg_types = '(?:CA|CC|CG|CW|IC)';

my $re_wind_shear_lvl = "WS(\\d{3})/(${re_wind_dir}0${re_wind_speed}KT)";

my $re_phenomenon_other =
               "(?:LTG$re_ltg_types*"
             . '|VIRGA|AURBO|AURORA|F(?:O?G)? BA?NK|FULYR|HZY|BINOVC|ICG|SH|DEW'
             . "|(?:$re_vis|CIG|SC) (?:HYR|HIER|LWR|RDCD|RED(?:UCED)?)"
             . '|ROTOR CLD|CLDS?(?: EMBD(?: 1ST LYR)?)?|(?:GRASS )?FIRES?'
             . '|(?:SKY|MTN?S?(?: TOPS)?|RDGS)(?: P[TR]L?Y?)? OBSC(?:URED|D)?'
             . '|MTN?S? OP(?:EN)?'
             . '|HALO(?: VI?SBL| VSBL?)?|(?:CB|TCU) ?TOPS?'
             . '|VOLCANIC ASH CLOUD|ASH FALL)';
my $re_phenomenon4 = "(?:($re_phenomenon_other|PCPN|(?:BC )?VLY FG|HIR CLDS)|($re_cloud_type(?:[/-]$re_cloud_type)*)|($re_weather|SMOKE|HAZE|TSTMS)|($re_cloud_cov))";

my $re_estmd      = '(?:EST(?:M?D)?|ESMTD|ESTIMATED)';
my $re_data_estmd =
  '(?:WI?NDS?(?: DATA)?|(?:CIG )?BLN|ALTM?|CIG|CEILING|SLP|ALSTG|QNH|CLD HGTS)';

my $re_synop_tt     = '(?:[0-6]\d|7[0-5])';
my $re_synop_zz     = '(?:[7-9]\d)';
my $re_synop_period = '(?:[0-6]\d)';
my $re_synop_w1w1   =
        '(?:0[46-9]|1[01379]|2[0-8]|3[09]|4[1-9]|5[0-79]|6[0-7]|[78]\d|9[0-3])';

my $re_record_temp_data = '(?:(?:HI|LO)(?:[EX])(?:AT|FM|SE|SL|DA))';

########################################################################
# global variable
########################################################################
# path to current data node. no elements: start_*() was not called yet
my @node_path;

########################################################################
# helper functions
########################################################################

# FMH-1 2.6.3:
#   If the fractional part of a positive number to be dropped is equal to or
#   greater than one-half, the preceding digit shall be increased by one. If
#   the fractional part of a negative number to be dropped is greater than
#   one-half, the preceding digit shall be decreased by one. In all other
#   cases, the preceding digit shall remain unchanged.
#   For example, 1.5 becomes 2, -1.5 becomes -1 ...
# WMO-No. 306 Vol I.1, Part A, Section A, 15.11.1:
#   Observed values involving 0.5°C shall be rounded up to the next higher
#   Celsius degree
sub _rnd {
    my ($val, $prec) = @_;
    return $prec * floor(($val / $prec) + 0.5);
}

sub _makeErrorMsgPos {
    my $errorType = shift;

    if (/\G$/) {
        s/\G/<@/;
    } else {
        if (pos == 0) {
            s/\G/@> /;
        } else {
            s/\G/<@> /;
        }
        s/@> +[^ ]+\K .+/ .../;
        s/ $//;
    }
    return { errorType => $errorType, s => $_ };
}

{
    my @cy; # [ ' A ' | 'cUS' | 'cJP', ' AB ', ' ABCD ' ]

    sub _cySet {
        my $icao = shift;

        if (!$icao) {
            @cy = ();
            return;
        }

        @cy = map { " $_ " } unpack 'aX a2X2 a4', $icao;

        # group some codes to one country
        # note: this prevents using F,K,M,N,P,R,T as country!
        $cy[0] =   $cy[1] eq ' RJ ' || $cy[1] eq ' RO '                ? 'cJP'
                 : _cyInString(' FHAW FJDG K MHSC MUGM NSTU P TI TJ ') ? 'cUS'
                 :                                                       $cy[0]
                 ;
        return;
    }

    sub _cyIsC  { return $cy[0] eq shift; }
    sub _cyIsCC { return $cy[1] eq shift; }

    sub _cyInString {
        my $str = shift;

        return    index($str, $cy[0]) > -1
               || index($str, $cy[1]) > -1
               || index($str, $cy[2]) > -1;
    }
}

# WMO-No. 306 Vol I.1, Part A, Section A, 15.6.3:
# Visibility shall be reported using the following reporting steps:
# (a) Up to 800 metres rounded down to the nearest 50 metres;
# (b) Between 800 and 5000 metres rounded down to the nearest 100 metres;
# (c) Between 5000 metres up to 9999 metres rounded down to the nearest 1000
#     metres;
# (d) With 9999 indicating 10 km and above.
#
# WMO-No. 306 Vol I.1, Part A, Section B:
# VVVV
#   Horizontal visibility at surface, in metres,
#   in increments of 50 metres up to 500 metres,             WRONG! CORRECT: 800
#   in increments of 100 metres between 500 and 5000 metres, and      WRONG! 800
#   in increments of 1000 metres between 5000 metres up to 9999 metres,
#   with 9999 indicating visibility of 10 km and above.
#   If the value is between two increments, it shall be rounded off downward to
#   the lower of the two increments.
sub _getVisibilityM {
    my ($visM, $less_greater) = @_;

    return { v => 10, u => 'KM', q => 'isEqualGreater' } if $visM == 9999;
    return { v => $visM + 0,
             u => 'M',
             q => $less_greater eq 'P' ? 'isEqualGreater' : 'isLess'
           }
        if $less_greater;

    return { v => $visM + 0, u => 'M',
             # add range only for reportable values
               $visM =~ /0[0-7][05]0/ ? (rp =>   50)
             : $visM =~ /[0-4]\d00/   ? (rp =>  100)
             : $visM =~ /\d000/       ? (rp => 1000)
             :                          ()
    };
}

# WMO-No. 306 Vol I.1, Part A, Section B:
# VRVRVRVR
#   Runway visual range shall be reported
#   in steps of 25 metres when the runway visual range is less than 400 metres;
#   in steps of 50 metres when it is between 400 metres and 800 metres; and
#   in steps of 100 metres when the runway visual range is more than 800 metres.
#   Any observed value which does not fit the reporting scale in use shall be
#   rounded down to the nearest lower step in the scale.
sub _setVisibilityMRVRrange {
    my $dist = shift;

    # add range only for reportable values
    if ($dist->{v} =~ /0[0-3](?:[05]0|[27]5)/) {
        $dist->{rp} = 25;
    } elsif ($dist->{v} =~ /0[4-7][05]0/) {
        $dist->{rp} = 50;
    } elsif ($dist->{v} =~ /\d\d00/) {
        $dist->{rp} = 100;
    }
    return;
}

# FMH-1 12.6.7c
# TODO: rounded down or rounded?
sub _setVisibilityFTRVRrange {
    my $dist = shift;

    # add range only for reportable values
    if ($dist->{v} =~ /0\d00/) {
        $dist->{rp} = 100;
    } elsif ($dist->{v} =~ /[12][02468]00/) {
        $dist->{rp} = 200;
    } elsif ($dist->{v} =~ /[3-5][05]00|6000/) {
        $dist->{rp} = 500;
    }
    return;
}

# $val matches $re_vis_sm or $re_gs_size or P?[1-9]\d*
sub _parseFraction {
    my ($val, $unit) = @_;
    my $q;

    $q = 'isLess'         if $val =~ s/^M//;
    $q = 'isEqualGreater' if $val =~ s/^P//;
    if ($val =~ m{^(\d)/(\d\d?)$}) { # fraction, only
        $val = $1 / $2;
    } elsif ($val =~ m{^(\d) ?(\d)/(\d\d?)$}) { # 1..9 with fraction
        $val = $1 + $2 / $3;
    } # else must be integer
    return { v => $val, u => $unit, $q ? (q => $q) : () };
}

# FMH-1 6.5.2, table 6-1
# If the actual visibility falls halfway between two reportable values, the
# lower value shall be reported.
sub _setVisibilitySMrangeUS {
    my ($dist, $is_auto) = @_;

    # add range only for reportable values
    if ($is_auto) {
        if ($dist->{v} == 0) {
            # not reportable
        } elsif ($dist->{v} == 1/4) {
            $dist->{rpi} = 1/8;
        } elsif ($dist->{v} < 2) {
            @{$dist}{qw(rne rpi)} = (1/8, 1/8)
                if $dist->{v} * 4 == int($dist->{v} * 4);
        } elsif ($dist->{v} == 2) {
            @{$dist}{qw(rne rpi)} = (1/8, 1/4);
        } elsif ($dist->{v} == 2.5) {
            @{$dist}{qw(rne rpi)} = (1/4, 1/4);
        } elsif ($dist->{v} == 3) {
            @{$dist}{qw(rne rpi)} = (1/4, 1/2);
        } elsif ($dist->{v} <= 10) {
            @{$dist}{qw(rne rpi)} = (1/2, 1/2)
                if $dist->{v} == int($dist->{v});
        }
    } else {
        if ($dist->{v} == 0) {
            $dist->{rpi} = 1/32;
        } elsif ($dist->{v} < 3/8) {
            @{$dist}{qw(rne rpi)} = (1/32, 1/32)
                if $dist->{v} * 16 == int($dist->{v} * 16);
        } elsif ($dist->{v} == 3/8) {
            @{$dist}{qw(rne rpi)} = (1/32, 1/16);
        } elsif ($dist->{v} < 2) {
            @{$dist}{qw(rne rpi)} = (1/16, 1/16)
                if $dist->{v} * 8 == int($dist->{v} * 8);
        } elsif ($dist->{v} == 2) {
            @{$dist}{qw(rne rpi)} = (1/16, 1/8);
        } elsif ($dist->{v} < 3) {
            @{$dist}{qw(rne rpi)} = (1/8, 1/8)
                if $dist->{v} * 4 == int($dist->{v} * 4);
        } elsif ($dist->{v} == 3) {
            @{$dist}{qw(rne rpi)} = (1/8, 1/2);
        } elsif ($dist->{v} < 15) {
            @{$dist}{qw(rne rpi)} = (1/2, 1/2)
                if $dist->{v} == int($dist->{v});
        } elsif ($dist->{v} == 15) {
            @{$dist}{qw(rne rpi)} = (1/2, 2.5);
        } else {
            @{$dist}{qw(rne rpi)} = (2.5, 2.5)
                if $dist->{v} / 5 == int($dist->{v} / 5);
        }
    }
    return;
}

# MANOBS 10.2.9
#   If the observed prevailing visibility is exactly half-way between two
#   reportable values, use the lower value.
sub _setVisibilitySMrangeCA {
    my $dist = shift;

    # add range only for reportable values
    if ($dist->{v} == 0) {
        $dist->{rpi} = 1/16;
    } elsif ($dist->{v} < 3/4) {
        @{$dist}{qw(rne rpi)} = (1/16, 1/16)
            if $dist->{v} * 8 == int($dist->{v} * 8);
    } elsif ($dist->{v} == 3/4) {
        @{$dist}{qw(rne rpi)} = (1/16, 1/8);
    } elsif ($dist->{v} < 2.5) {
        @{$dist}{qw(rne rpi)} = (1/8, 1/8)
            if $dist->{v} * 4 == int($dist->{v} * 4);
    } elsif ($dist->{v} == 2.5) {
        @{$dist}{qw(rne rpi)} = (1/8, 1/4);
    } elsif ($dist->{v} == 3) {
        @{$dist}{qw(rne rpi)} = (1/4, 1/2);
    } elsif ($dist->{v} < 15) {
        @{$dist}{qw(rne rpi)} = (1/2, 1/2)
            if $dist->{v} == int($dist->{v});
    } elsif ($dist->{v} == 15) {
        @{$dist}{qw(rne rpi)} = (1/2, 2.5);
    } else {
        @{$dist}{qw(rne rpi)} = (2.5, 2.5)
            if $dist->{v} / 5 == int($dist->{v} / 5);
    }
    return;
}

sub _getVisibilitySM {
    my ($dist, $is_auto) = @_;
    my $r;

    $r = _parseFraction $dist, 'SM';
    if (!exists $r->{q}) {
        if (_cyIsC 'cUS') {
            _setVisibilitySMrangeUS $r, $is_auto;
        } elsif (_cyIsC ' C ') {
            _setVisibilitySMrangeCA $r;
        }
        # TODO: what about EQ(YR,YS) MM MY TKPK TNCM TX(KF)?
    }
    return { distance => $r };
}

sub _parseWeather {
    my ($weather, $mode) = @_;           # $mode: RE = recent, NI = no intensity
    my ($w, $int, $in_vicinity, $desc, $phen, $weather_str);

    if (defined $mode && $mode eq 'RE') {
        $weather_str = 'RE' . $weather;
    } else {
        $weather_str = $weather;
    }
    return { NSW => undef, s => $weather_str } if $weather eq 'NSW';
    return { notAvailable => undef, s => $weather_str }
        if $weather eq '//';

    return { tornado => undef, s => $weather_str } if $weather eq '+FC';

    # for $re_phenomenon4, only
    $weather = 'FU' if $weather eq 'SMOKE';
    $weather = 'HZ' if $weather eq 'HAZE';
    $weather = 'TS' if $weather eq 'TSTMS';

    ($int, $in_vicinity, $desc, $phen) =
                       $weather =~ m{([+-])?(VC)?($re_weather_desc)?([A-Z/]+)}o;
    $w->{s} = $weather_str;
    if (defined $int) {
        $w->{phenomDescr} = ($int eq '-' ? 'isLight' : 'isHeavy');
    } else {
        # weather in vicinity _can_ have intensity, but it is an EXTENSION
        $w->{phenomDescr} = 'isModerate'
            unless    $in_vicinity
                   || $mode
                   || $weather =~ /^$re_weather_wo_i$/o;
    }
    $w->{inVicinity}    = undef if defined $in_vicinity;
    $w->{descriptor}    = $desc if defined $desc;
    @{$w->{phenomSpec}} = $phen =~ /../g;
    return $w;
}

sub _parseOpacityPhenom {
    my ($r, $clds) = @_;

    for ($clds =~ /[A-Z]+\d/g) {
        my ($phenom, $oktas) = /([A-Z]+)(.)/;
        $phenom = 'FG' if $phenom eq 'F';
        if ($phenom =~ /$re_weather/o) {
            push @{$r->{opacityPhenomArr}}, { opacityWeather => {
                oktas   => $oktas,
                weather => _parseWeather($phenom, 'NI')
            }};
        } else {
            push @{$r->{opacityPhenomArr}}, { opacityCloud => {
                oktas     => $oktas,
                cloudType => $phenom
            }};
        }
    }
    return;
}

sub _parseOpacityPhenomSao {
    my ($r, $clds) = @_;

    for ($clds =~ /[A-Z]+\d+/g) {
        my ($phenom, $tenths) = /([A-Z]+)(.*)/;
        $phenom = {
            BD => 'BLDU',
            BN => 'BLSA',
            BS => 'BLSN',
            BY => 'BLPY',
            B  => 'DU',
            F  => 'FG',
            GF => 'MIFG',
            H  => 'HZ',
            IF => 'FZFG',
            K  => 'FU',
        }->{$phenom}
            if { map { $_ => 1 } qw(BD BN BS BY B F GF H IF K) }->{$phenom};
        if ($phenom =~ /$re_weather/o) {
            push @{$r->{opacityPhenomArr}}, { opacityWeather => {
                tenths  => $tenths,
                weather => _parseWeather($phenom, 'NI')
            }};
        } else {
            push @{$r->{opacityPhenomArr}}, { opacityCloud => {
                tenths    => $tenths,
                cloudType => $phenom
            }};
        }
    }
    return;
}

sub _parseRwyVis {
    my $metar = shift;
    my $strict = shift; # 0: in METAR main, 1: in METAR remarks
    my $v;

    if (m{\G(R///////) }ogc) {
        push @{$metar->{visRwy}}, { s => $1, notAvailable => undef };
        return 1;
    }

    # EXTENSION (standard until 2013-11-04): RVRVariations
       m{\G(R($re_rwy_des)/(?:////|($re_rwy_vis_strictM)(?:V($re_rwy_vis_strictM))?())/?([UDN])?) }ogc
    || m{\G(R($re_rwy_des)/(?:////|($re_rwy_vis_strictFT)(?:V($re_rwy_vis_strictFT))?(FT))/?([UDN])?) }ogc
    || (!$strict && m{\G(R($re_rwy_des)/(?:////|($re_rwy_vis)(?:V($re_rwy_vis))?(FT)?)/?([UDN])?) }ogc)
        or return;

    $v->{s}        = $1;
    $v->{rwyDesig} = $2;
    $v->{visTrend} = $6 if defined $6;
    if (!defined $3) {
        $v->{RVR}{notAvailable} = undef;
    } else {
        $v->{RVR}{distance} = { v => $3, u => ($5 ? $5 : 'M') };
        if (defined $4) {
            $v->{RVRVariations}{distance} =
                                       { v => $4, u => $v->{RVR}{distance}{u} };
            if ($v->{RVRVariations}{distance}{v} =~ s/^M//) {
                $v->{RVRVariations}{distance}{q} = 'isLess';
            } elsif ($v->{RVRVariations}{distance}{v} =~ s/^P//) {
                $v->{RVRVariations}{distance}{q} = 'isEqualGreater';
            } elsif ($v->{RVRVariations}{distance}{u} eq 'M') {
                _setVisibilityMRVRrange $v->{RVRVariations}{distance};
            } else {
                _setVisibilityFTRVRrange $v->{RVRVariations}{distance};
            }
            $v->{RVRVariations}{distance}{v} += 0;
        }
        # corrections postponed because pattern matching changes $4
        if ($v->{RVR}{distance}{v} =~ s/^M//) {
            $v->{RVR}{distance}{q} = 'isLess';
        } elsif ($v->{RVR}{distance}{v} =~ s/^P//) {
            $v->{RVR}{distance}{q} = 'isEqualGreater';
        } elsif ($v->{RVR}{distance}{u} eq 'M') {
            _setVisibilityMRVRrange $v->{RVR}{distance};
        } else {
            _setVisibilityFTRVRrange $v->{RVR}{distance};
        }
        $v->{RVR}{distance}{v} += 0;
    }
    push @{$metar->{visRwy}}, $v;
    return 1;
}

sub _parseRwyState {
    my $metar = shift;
    my $r;

    # SNOCLO|((RRRR|RDRDR/)((CLRD|ERCReReR)BRBR))
    # EXTENSION: allow missing /
    # EXTENSION: allow (and ignore) runway designator for SNOCLO
    # EXTENSION: allow (and mark invalid) states U, D, N
    m{\G(((?:R(?:88|$re_rwy_des)?/)?SNOCLO)|(88|99|$re_rwy_des2|R(?:88|99|$re_rwy_des)/?)(?:(?:(?:(CLRD)|([\d/])([\d/])(\d\d|//))(\d\d|//))|([UDN]))) }ogc
        or return;

    $r->{s} = $1;
    if (defined $2) {
        $r->{SNOCLO} = undef;
    } else {
        if (defined $4) {
            $r->{cleared} = undef;
        } elsif (defined $9) {
            $r->{invalidFormat} = $9;
        } else {
            # WMO-No. 306 Vol I.1, Part A, code table 0919:
            $r->{depositType} = $5 eq '/' ? { notAvailable => undef }
                                          : { depositTypeVal => $5 };

            # WMO-No. 306 Vol I.1, Part A, code table 0519:
            $r->{depositExtent} =
                  $6 eq '/'                     ? { notAvailable => undef }
                : { map { $_ => 1 } qw(0 1 2 5 9) }->{$6}
                                                ? { depositExtentVal => $6 }
                :                                 { invalidFormat => $6 }
                ;

            # WMO-No. 306 Vol I.1, Part A, code table 1079:
            $r->{depositDepth} =
                  $7 eq '//' ? { notAvailable => undef }
                : $7 == 0    ? { depositDepthVal => {
                                     v => 1, u => 'MM', q => 'isLess'
                               }}
                : $7 <= 90   ? { depositDepthVal => {
                                     v => $7 + 0, u => 'MM'
                               }}
                : $7 >= 92 && $7 <= 97 ?
                               { depositDepthVal => {
                                     v => ($7 - 90) * 5, u => 'CM'
                               }}
                : $7 == 98   ? { depositDepthVal => {
                                   v => 40, u => 'CM', q => 'isEqualGreater'
                               }}
                : $7 == 99   ? { rwyNotInUse => undef }
                :              { invalidFormat => $7 }
                ;
        }

        # WMO-No. 306 Vol I.1, Part A, code table 0366:
        $r->{friction} =   $8 eq '//'           ? { notAvailable => undef }
                         : $8 >=  0 && $8 <= 90 ? { coefficient => "0.$8" }
                         : $8 >= 91 && $8 <= 95 ?
                             { brakingAction => qw(BA_POOR BA_POOR_MED BA_MEDIUM
                                                   BA_MED_GOOD BA_GOOD)[$8 - 91]
                             }
                         : $8 == 99             ? { unreliable => undef }
                         :                        { invalidFormat => $8 }
            if defined $8;

        if ($3 eq '88' || $3 eq 'R88' || $3 eq 'R88/') {
            $r->{rwyDesigAll} = undef;
        } elsif ($3 eq '99' || $3 eq 'R99' || $3 eq 'R99/') {
            $r->{rwyReportRepeated} = undef;
        } else {
            my $rwy_des = $3;

            $r->{rwyDesig} =   $rwy_des =~ m{^R($re_rwy_des)/?$}
                               ? $1
                             : $rwy_des > 50
                               ? sprintf '%02dR', $rwy_des - 50
                             : $rwy_des;
        }
    }
    push @{$metar->{rwyState}}, $r;
    return 1;
}

sub _parseWind {
    my ($wind, $dir_is_rounded, $is_grid) = @_;
    my ($w, $dir, $speed, $gustSpeed, $unitSpeed);

    return { notAvailable => undef } if $wind eq '/////';

    ($dir, $speed, $gustSpeed, $unitSpeed) = $wind =~ m{^$re_wind$}o;
    if ($dir eq '///' && $speed eq '//') {
        $w->{notAvailable} = undef;
    } elsif ($dir eq '000' && $speed eq '00' && !defined $gustSpeed) {
        $w->{isCalm} = undef;
    } else {
        my $isGreater;

        if ($dir eq '///') {
            $w->{dirNotAvailable} = undef;
        } elsif ($dir eq 'VRB') {
            $w->{dirVariable} = undef;
        } else {
            $w->{dir}{v} = $dir + 0; # true, not magnetic
            $w->{dir}{q} = 'isGrid' if $is_grid;
            @{$w->{dir}}{qw(rp rn)} = (4, 5)
                if $dir_is_rounded && $dir =~ /0$/;
        }
        $unitSpeed =~ s/KTS/KT/;
        $unitSpeed =~ s/ //;
        if ($speed eq '//') {
            $w->{speedNotAvailable} = undef;
        } else {
            $isGreater = $speed =~ s/^P//;
            $w->{speed} = { v => $speed + 0, u => $unitSpeed };
            $w->{speed}{q} = 'isGreater' if $isGreater;
        }
        if (defined $gustSpeed) {
            $isGreater = $gustSpeed =~ s/^P//;
            $w->{gustSpeed} = { v => $gustSpeed + 0, u => $unitSpeed };
            $w->{gustSpeed}{q} = 'isGreater' if $isGreater;
        }
    }
    return $w;
}

sub _parseWindAtLoc {
    my ($s, $location, $wind, $windVarLeft, $windVarRight) = @_;
    my $r;

    $r = _parseWind $wind;
    @$r{qw(windVarLeft windVarRight)} = ($windVarLeft + 0, $windVarRight + 0)
        if defined $windVarLeft;
    return { windAtLoc => {
        s            => $s,
        windLocation => $location,
        wind         => $r
    }};
}

sub _parseLocations {
    my ($loc_str, $in_distance) = @_;
    my (@loc_thru, $obscgMtns, $in_vicinity, $is_grid);

    $obscgMtns = $loc_str =~ s/OBSCG MTNS //;

    for ($loc_str =~ m{(?:[+/, ]| AND )?($re_loc_thru|UNKN)}og) {
        my @loc;

        pos = 0;
        while (m{\G(?: ?[/-] ?| THRU )?(?:($re_loc_dsnt_vc )?(?:TO )?(?:(?:($re_loc_compass)(?: ($re_loc_approx))?|(?:($re_loc_approx) )?($re_loc_compass)|(OHD))|($re_loc_approx|$re_loc_inexact)))|($re_loc_exact|UNKN)}ogc)
        {
            my ($l, $loc_spec, $compass);

            $in_distance = 1 if defined $1 && $1 eq 'DSNT ';
            $in_vicinity = 1 if defined $1 && $1 eq 'VC ';
            $compass = $2 || $5;
            $loc_spec = $3 || $4 || $6 || $7 || $8;
            $l->{locationSpec} = $loc_spec
                if $loc_spec;

            if ($compass) {
                $compass =~ m{(?:($re_loc_dsnt_vc )|([1-9]\d*)(KM|NM)? ?)?(?:TO )?(GRID )?($re_compass_dir16)( QUAD)?}o;
                $in_distance = 1 if defined $1 && $1 eq 'DSNT ';
                $in_vicinity = 1 if defined $1 && $1 eq 'VC ';
                $l->{distance} = { v => $2, u => ($3 // 'SM') }
                    if defined $2;
                $is_grid = 1 if defined $4;
                push @{$l->{sortedArr}}, { compassDir => {
                    v => $5,
                    $is_grid ? (q => 'isGrid') : ()
                }};
                push @{$l->{sortedArr}}, { isQuadrant => undef } if defined $6;
            }

            if (exists $l->{locationSpec}) {
                if ($l->{locationSpec} =~ $re_loc_exact) {
                    $in_distance = 0;
                    $in_vicinity = 0;
                }
                $l->{locationSpec} =~ s/ARND/isAround/;
                $l->{locationSpec} =~ tr /\/ /_/;
                $l->{locationSpec} =~ s/ /_/;
            }
            $l->{inDistance} = undef if $in_distance;
            $l->{inVicinity} = undef if $in_vicinity;

            push @loc, $l;
        }
        push @loc_thru, { location => \@loc };
    }
    return { locationThru => \@loc_thru,
             $obscgMtns ? (obscgMtns => undef) : ()
    };
}

sub _parseCloud {
    my ($cloud, $q_base) = @_;
    my $c;

    $c->{s} = $cloud;
    if ($cloud =~ m{^/+$}) {
        $c->{notAvailable} = undef;
    } elsif ($cloud =~ m{^(?:($re_cloud_cov)|///)($re_cloud_base)(?: ?($re_cloud_type|///)(\($re_loc_and\))?)?}o)
    {
        if ($1) {
            $c->{cloudCover}{v} = $1;
        } else {
            $c->{cloudCoverNotAvailable} = undef;
        }
        if ($2 eq '///') {
            # can mean: not measured (autom. station) or base below station
            $c->{cloudBaseNotAvailable} = undef;
        } else {
            $c->{cloudBase} = _codeTable1690($2, $q_base);
        }
        if ($3) {
            if ($3 eq '///') {
                $c->{cloudTypeNotAvailable} = undef;
            } else {
                $c->{cloudType} = $3;
            }
            $c->{locationAnd} = _parseLocations $4
                if defined $4;
        }
    } else {
        if ($cloud =~ m{^///}) {
            $c->{cloudCoverNotAvailable} = undef;
        } else {
            $c->{cloudCover}{v} = substr $cloud, 0, 3;
        }
        $c->{cloudType} = substr $cloud, 3
            if length $cloud > 3;
    }
    return $c;
}

sub _parseQNH {
    my $qnh = shift;
    my ($q, $descr, $dig12, $dig34, $ins);

    $q->{s} = $qnh;
    ($descr, $dig12, $dig34, $ins) =
                   $qnh =~ m{([AQ])(?:NH)? ?(..)[./]?(//|\d\d(?:\.\d)?)(INS)?};
    if ("$dig12$dig34" eq '////') {
        $q->{notAvailable} = undef;
    } else {
        if ($descr eq 'Q' && !defined $ins) {
            $dig34 = '00' if $dig34 eq '//';
            $q->{pressure}{v} = ($dig12 + 0) . $dig34;
            $q->{pressure}{u} = 'hPa';
        } else {
            $q->{pressure}{v} = $dig12;
            $q->{pressure}{v} .= ".$dig34" unless $dig34 eq '//';
            $q->{pressure}{u} = 'inHg';
        }
    }
    return $q;
}

sub _parseColourCode {
    my $colour = shift;
    my $c;

    $colour =~ m{^(BL(?:AC)?K ?)?([A-Z]{3}[12+]?)?/? ?([^/]+)?/?$}
        or return { s => $colour, currentColour => 'ERROR' }; # "cannot" happen

    $c->{s}               = $colour;
    $c->{BLACK}           = undef if defined $1;
    $c->{currentColour}   =
            $2 eq 'BLU+' ? 'BLUplus' : ($2 eq 'FCST CANCEL' ? 'FCSTCANCEL' : $2)
        if defined $2;
    $c->{predictedColour} =
            $3 eq 'BLU+' ? 'BLUplus' : ($3 eq 'FCST CANCEL' ? 'FCSTCANCEL' : $3)
        if defined $3;
    return $c;
}

# assumption: all heights have the same unit
sub _determineCeiling {
    my $cloud = shift;
    my ($ceil_ft, $ceil_m, $idx, $ii);

    $ceil_ft = 20000; # max. ceiling (FT AGL)
    $ceil_m  =  6000; # max. ceiling (M AGL)
    $idx     = -1;
    $ii      = -1;
    for (@$cloud) {
        $ii++;
        if (   exists $_->{cloudBase} && exists $_->{cloudCover}
            && ($_->{cloudCover}{v} eq 'BKN' || $_->{cloudCover}{v} eq 'OVC'))
        {
            if ($_->{cloudBase}{u} eq 'FT' && $_->{cloudBase}{v} < $ceil_ft) {
                $ceil_ft = $_->{cloudBase}{v};
                $idx     = $ii;
            } elsif ($_->{cloudBase}{u} eq 'M' && $_->{cloudBase}{v} < $ceil_m){
                $ceil_m = $_->{cloudBase}{v};
                $idx    = $ii;
            }
        }
    }
    $cloud->[$idx]{isCeiling}{q} = 'M2Xderived' if $idx > -1;
    return;
}

sub _parseQuadrants {
    my ($q, $in_distance) = @_;

    return { locationThru => { location => {
        $in_distance ? (inDistance => undef) : (),
        quadrant => [ $q =~ /([1-4])/g ]
    }}};
}

# [01]\d\d[\d/]?
sub _parseTemp {
    my ($sign, $whole, $frac);

    ($sign, $whole, $frac) = unpack 'aa2a', shift;
    return { v =>   ('', '-')[$sign]                # prepend '-' even for 0[.0]
                  . ($whole + 0)                    # remove leading 0
                                                    # append fraction if valid
                  . ($frac eq '/' || $frac eq '' ? '' : ".$frac"),
             u => 'C'
    };
}

# M? ?\d ?\d
sub _parseTempMetaf {
    my $temp = shift;

    $temp =~ tr / //d;
    return { v => substr($temp, 0, 1) eq 'M' ? '-' . (0 + substr $temp, 1)
                                             :       (0 + $temp),
             u => 'C'
           };
}

sub _parsePhenomDescr {
    my ($r, $tag, $phen_descr) = @_;

    for ($phen_descr =~ /$re_phen_desc|BBLO/og) {
        s/CONTUS/CONS/;
        s/CNTS/CONS/;
        s/V(LGT|THN|THIN|FBL|THK|THICK)/VRY $1/;
        s/THIN/THN/;
        s/FREQ/FRQ/;
        s/THICK/THK/;
        s/^LOW?/LOW/;
        s/^MOD/MDT/;

        push @{$r->{$tag}}, {
            FRQ      => 'isFrequent',
            OCNL     => 'isOccasional',
            INTMT    => 'isIntermittent',
            CONS     => 'isContinuous',
            THK      => 'isThick',
           'PR THK'  => 'isPrettyThick',
           'VRY THK' => 'isVeryThick',
            THN      => 'isThin',
           'PR THN'  => 'isPrettyThin',
           'VRY THN' => 'isVeryThin',
            LGT      => 'isLight',
           'PR LGT'  => 'isPrettyLight',
           'VRY LGT' => 'isVeryLight',
            FBL      => 'isFeeble',
           'PR FBL'  => 'isPrettyFeeble',
           'VRY FBL' => 'isVeryFeeble',
            MDT      => 'isModerate',
            LOW      => 'isLow',
            LWR      => 'isLower',
            ISOL     => 'isIsolated',
            CVCTV    => 'isConvective',
            DSIPTD   => 'isDissipated',
           'PAST HR' => 'inPastHour',
            BBLO     => 'baseBelowStation',
            ALOFT    => 'isAloft',
            FREEZING => 'isFreezing',
            PTCHY    => 'isPatchy',
            VERT     => 'isVertical',
            PTL      => 'isPartial',
        }->{$_};
    }
    return;
}

sub _parsePhenom {
    my ($r, $phenom) = @_;

    if ($phenom =~ /LTG$re_ltg_types/o) {
        $$r->{lightningType} = ();
        for ($phenom =~ /$re_ltg_types/og) {
            push @{$$r->{lightningType}}, $_;
        }
    } else {
        ($$r->{otherPhenom} = $phenom) =~ tr/ /_/;
        $$r->{otherPhenom} =~ s/_HIER/_HYR/;
        $$r->{otherPhenom} =~ s/_RED(?:UCED)?/_RDCD/;
        $$r->{otherPhenom} =~ s/AURORA/AURBO/;
        $$r->{otherPhenom} =~ s/$re_vis/VIS/o;
        $$r->{otherPhenom} =~ s/_VI?SBL?//;
        $$r->{otherPhenom} =~ s/OBSC(?:URE)?D/OBSC/;
        $$r->{otherPhenom} =~ s/_P[TR]L?Y?_/_PRLY_/;
        $$r->{otherPhenom} =~ s/MT\KN?S?(?=_[OP])/NS/;
        $$r->{otherPhenom} =~ s/MT\KN?S?(?=_T)/N/;
        $$r->{otherPhenom} =~ s/_OP\K$/EN/;
        $$r->{otherPhenom} =~ s/F(?:O?G)?_BA?NK/FG_BNK/;
        $$r->{otherPhenom} =~ s/[^_]\K(?=TOP)/_/;
        $$r->{otherPhenom} =~ s/_TOP\K$/S/;
    }
    return;
}

# hBhBhB height of lowest level of turbulence
# hihihi height of lowest level of icing
# hshshs height of base of cloud layer or mass (AGL), or vertical visibility
sub _codeTable1690 {
    my ($level, $q_base) = @_;
    my $r;

    if (_cyIsC 'cUS') {
        # FMH-1 9.5.4, 9.5.5
        $r = { v => $level * 100, u => 'FT' };
        if (!defined $q_base) {
            if ($level == 0) {
                $r->{rpi} = 50;
            } elsif ($level < 50) {
                @$r{qw(rne rpi)} = (50, 50);
            } elsif ($level == 50) {
                @$r{qw(rne rpi)} = (50, 250);
            } elsif ($level < 100 && $level % 5 == 0) {
                @$r{qw(rne rpi)} = (250, 250);
            } elsif ($level == 100) {
                @$r{qw(rne rpi)} = (250, 500);
            } elsif ($level > 100 && $level % 10 == 0) {
                @$r{qw(rne rpi)} = (500, 500);
            }
        }
    } elsif ($level eq '999') {
        $r = { v => 30000, u => 'M', q => 'isEqualGreater' };
    } else {
        $r = { v => $level * 30, u => 'M', defined $q_base ? () : (rp => 30) };
    };
    $r->{q} = $q_base
        if defined $q_base;

    return $r;
}

# groups 5BhBhBhBtL, 6IchihihitL
# WMO-No. 306 Vol I.1, Part A, Section A, 53.1.9.2 (FM-53 ARFOR):
# if group is repeated and only level differs: level is layer top
# AFMAN 15-124 table 1.5: Ic=0: trace icing
sub _turbulenceIcing {
    my $metar = shift;
    my ($type, $r);

    /\G(([56])(\d)(\d{3})(\d)(?: \2\3(\d{3})\5)?) /gc
        or return;

    $type = qw(turbulence icing)[$2 - 5];

    $r = {
        s               => $1,
        $type . 'Descr' => ($3 == 0 && $2 == 6 && _cyIsC('cUS') ? 'TR' : $3),
        layerBase       => _codeTable1690 $4
    };
    if (defined $6) {
        $r->{layerTop} = _codeTable1690 $6;
    } else {
        # WMO-No. 306 Vol I.1, Part A, coding table 4013
        if ($5 eq '0') {
            $r->{layerTopOfCloud} = undef;
        } else {
            $r->{layerThickness} = { v => $5 * 300, u => 'M' };
        }
    }
    push @{$metar->{trendSupplArr}}, { $type => $r };
    return 1;
}

sub _obscuration {
    my ($r, $phen);

    /\G((FU|(?:FZ)?(?:BC)?FG|BR|(?:BL)?SN|DU|PWR PLA?NT(?: PLUME)?) ($re_cloud_cov$re_cloud_base)) /ogc
        or return;

    $r->{s}     = $1;
    $r->{cloud} = _parseCloud $3;
    $phen       = $2;
    if ($phen =~ m{^$re_weather$}o) {
        $r->{weather} = _parseWeather $phen, 'NI';
    } else {
        ($r->{cloudPhenom} = $phen) =~ s/ /_/g;
    }
    return { obscuration => $r };
}

# "supplementary" section of TAFs and additional TAF info
sub _parseTAFsuppl {
    my ($metar, $base_metar) = @_;

    # "supplementary" section of TAFs

    return 1
        if _turbulenceIcing $metar;

    if (m{\G($re_wind_shear_lvl) }ogc) {
        push @{$metar->{trendSupplArr}}, { windShearLvl => {
            s     => $1,
            level => $2 + 0,
            wind  => _parseWind $3
        }};
        return 1;
    }
    if (m{\G(WSCONDS) }gc) {
        push @{$metar->{trendSupplArr}}, { windShearConds => { s => $1 }};
        return 1;
    }

    # EXTENSION: allow QNH\d{4}INS (AFMAN 15-124 1.3.4.10)
    if (m{\G(QNH[23]\d{3}INS) }gc) {
        push @{$metar->{trendSupplArr}}, { minQNH => _parseQNH $1 };
        return 1;
    }
    if (_cyIsCC(' ES ') && m{\G((Q(?:FE|NH)) (\d{3,4})) }gc) {
        push @{$base_metar->{TAFinfoArr}}, {
                          $2 => { s => $1, pressure => { v => $3, u => 'hPa' }}
        };
        return 1;
    }

    # EXTENSION: surface-based partial obscuration (AFMAN 15-124 1.3.4.5.4)
    if (_cyInString(' cUS NZ RK ') && (my $r = _obscuration)) {
        push @{$metar->{trendSupplArr}}, $r;
        return 1;
    }

    # EXTENSION: volcanic ash forecast (AFMAN 15-124 1.3.4.6.)
    if (_cyInString(' cUS NZ RK ') && /\G(VA(\d{3})(\d{3})) /gc) {
        push @{$metar->{trendSupplArr}}, { VA_fcst => {
            s         => $1,
            layerBase => { v => $2 * 100, u => 'FT' },
            layerTop  => { v => $3 * 100, u => 'FT' }
        }};
        return 1;
    }

    # additional TAF info

    # EXTENSION: forecast temperature
    while (m{\G(T(M?\d\d)/($re_day)?($re_hour|24)Z?) }ogc) {
        push @{$base_metar->{TAFinfoArr}}, { tempAt => {
            s      => $1,
            temp   => _parseTempMetaf($2),
            timeAt => { defined $3 ? (day => $3) : (), hour => $4 }
        }};
        return 1;
    }

    if (/\G((COR|AMD) ($re_day)?($re_hour)($re_min)Z?) /ogc) {
        push @{$base_metar->{TAFinfoArr}},
            { $2 eq 'COR' ? 'correctedAt' : 'amendedAt' => {
                s      => $1,
                timeAt => {
                    defined $3 ? (day => $3) : (),
                    hour   => $4,
                    minute => $5
                }
        }};
        return 1;
    }

    if (/\G(LIMITED METWATCH ($re_day)($re_hour) TIL ($re_day)($re_hour)) /ogc){
        push @{$base_metar->{TAFinfoArr}}, { limMetwatch => {
            s        => $1,
            timeFrom => { day => $2, hour => $3 },
            timeTill => { day => $4, hour => $5 },
        }};
        return 1;
    }

    if (/\G(AUTOMATED SENSOR(?:ED)? METWATCH(?: ($re_day)($re_hour) TIL ($re_day)($re_hour))?) /ogc)
    {
        push @{$base_metar->{TAFinfoArr}}, { autoMetwatch => {
            s => $1,
            defined $2 ? (timeFrom => { day => $2, hour => $3 },
                          timeTill => { day => $4, hour => $5 })
                       : ()
        }};
        return 1;
    }

    if (/\G(AMD (?:LTD TO CLD VIS AND WIND(?: (?:TIL ($re_hour|24)Z|(${re_hour})Z-($re_hour|24)Z))?|(NOT SKED))) /ogc)
    {
        push @{$base_metar->{TAFinfoArr}}, { amendment => {
            s => $1,
            defined $5 ? (isNotScheduled => undef)
                       : (isLtdToCldVisWind => undef,
                          defined $2 ? (timeTill => { hour => $2 }) : (),
                          defined $3 ? (timeFrom => { hour => $3 }) : (),
                          defined $4 ? (timeTill => { hour => $4 }) : ())
        }};
        return 1;
    }

    if (/\G((?:ISSUED )?BY ($re_ICAO)) /ogc) {
        push @{$base_metar->{TAFinfoArr}}, { issuedBy => { s => $1, id => $2 }};
        return 1;
    }

    return;
}

sub _turbulenceTxt {
    my $r;

    m{\G((?:F(?:RO)?M ?(?:($re_day)($re_hour)($re_min)|($re_hour)($re_min)?) )?(SEV|MOD(?:/SEV)?) TURB (?:BLW|BELOW) ([1-9]\d+) ?FT(?: TILL ?(?:($re_day)($re_hour|24)($re_min)|($re_hour|24)($re_min)?))?) }gc
        or return;

    $r->{s} = $1;
    if (defined $2) {
        $r->{timeFrom} = { day => $2, hour => $3, minute => $4 };
    } elsif (defined $5) {
        $r->{timeFrom}{hour} = $5;
        $r->{timeFrom}{minute} = $6 if defined $6;
    }
    $r->{turbulenceDescr} = $7;
    $r->{layerTop} = { v => $8, u => 'FT' };
    if (defined $9) {
        $r->{timeTill} = { day => $9, hour => $10, minute => $11 };
    } elsif (defined $12) {
        $r->{timeTill}{hour} = $12;
        $r->{timeTill}{minute} = $13 if defined $13;
    }
    $r->{turbulenceDescr} =~ s{/}{_};
    return $r;
}

sub _setHumidity {
    my $r = shift;
    my ($t, $d);

    return unless    exists $r->{air}      && exists $r->{air}{temp}
                  && exists $r->{dewpoint} && exists $r->{dewpoint}{temp};

    $t = $r->{air}{temp}{v};
    $d = $r->{dewpoint}{temp}{v};
    if ($r->{air}{temp}{u} eq 'F') {
        $t = ($t - 32) / 1.8;
        $d = ($d - 32) / 1.8;
    }

    # FGFS metar
    $r->{relHumid1}{v}
      = _rnd(100 * 10 ** (7.5 * ($d / ($d + 237.7) - $t / ($t + 237.7))), 0.01);
    $r->{relHumid1}{q} = 'M2Xderived';

    # http://www.bragg.army.mil/www-wx/wxcalc.htm
    # http://www.srh.noaa.gov/bmx/tables/rh.html
    $r->{relHumid2}{v}
        = _rnd(100 * ((112 - (0.1 * $t) + $d) / (112 + (0.9 * $t))) ** 8, 0.01);
    $r->{relHumid2}{q} = 'M2Xderived';

    # http://www.mattsscripts.co.uk/mweather.htm
    # http://ingrid.ldeo.columbia.edu/dochelp/QA/Basic/dewpoint.html
    $r->{relHumid3}{v}
       = _rnd(
           100 * (6.11 * exp(5417.118093 * (1 / 273.15 - (1 / ($d + 273.15)))))
               / (6.11 * exp(5417.118093 * (1 / 273.15 - (1 / ($t + 273.15))))),
           0.01);
    $r->{relHumid3}{q} = 'M2Xderived';

    # http://de.wikipedia.org/wiki/Taupunkt
    $r->{relHumid4}{v}
               = _rnd(100 * (6.11213 * exp(17.5043 * $d / (241.2 + $d)))
                          / (6.11213 * exp(17.5043 * $t / (241.2 + $t))), 0.01);
    $r->{relHumid4}{q} = 'M2Xderived';
    return;
}

# WMO-No. 306 Vol I.1, Part A, Section D.a:
sub _IIiii2region {
    my $IIiii = shift;

    my %IIiii_region = (
         I        => [ [ 60001, 69998 ] ],
         II       => [ [ 20001, 20099 ], [ 20200, 21998 ], [ 23001, 25998 ],
                       [ 28001, 32998 ], [ 35001, 36998 ], [ 38001, 39998 ],
                       [ 40350, 48599 ], [ 48800, 49998 ], [ 50001, 59998 ] ],
         III      => [ [ 80001, 88998 ] ],
         IV       => [ [ 70001, 79998 ] ],
         V        => [ [ 48600, 48799 ], [ 90001, 98998 ] ],
         VI       => [ [     1, 19998 ], [ 20100, 20199 ], [ 22001, 22998 ],
                       [ 26001, 27998 ], [ 33001, 34998 ], [ 37001, 37998 ],
                       [ 40001, 40349 ] ],
        Antarctic => [ [ 89001, 89998 ] ],
    );
    for my $region (keys %IIiii_region) {
        for (@{$IIiii_region{$region}}) {
            return $region if $IIiii >= $_->[0] && $IIiii <= $_->[1];
        }
    }
    return '';
}

# determine the country that operates a station to select correct decoding rules
sub _IIiii2country {
    my $IIiii = shift;

    # ranges from WMO-No. 9 Vol A, country codes from ISO-3166
    my %IIiii_country2 = (
        AR => [ [ 87001, 87998 ] ],                  # Argentina
        AT => [ [ 11001, 11399 ] ],                  # Austria
        BD => [ [ 41850, 41998 ] ],                  # Bangladesh
        BE => [ [  6400,  6499 ] ],                  # Belgium
        CA => [ [ 71001, 71998 ] ],                  # Canada
        CH => [ [  6600,  6989 ] ],                  # Switzerland
        CN => [ [ 50001, 59998 ] ],                  # China
        CZ => [ [ 11400, 11799 ] ],                  # Czech Republic
        DE => [ [ 10001, 10998 ] ],                  # Germany
        ES => [ [ 60001, 60099 ] ],       # Spain: Canary Islands, Sidi Ifni(MA)
        FR => [ [  7001,  7998 ] ],                  # France
        IN => [ [ 42001, 42998 ],                    # India
                [ 43001, 43399 ] ],
        LK => [ [ 43400, 43499 ] ],                  # Sri Lanka
        MG => [ [ 67009, 67199 ] ],                  # Madagascar
        MZ => [ [ 67200, 67399 ] ],                  # Mozambique
        NL => [ [  6200,  6399 ] ],                  # Netherlands
        NO => [ [  1001,  1499 ] ],                  # Norway
        RO => [ [ 15001, 15499 ] ],                  # Romania
        RU => [ [ 20001, 39999 ] ],                  # ex-USSR minus 14 states
        SA => [ [ 40350, 40549 ],                    # Saudi Arabia
                [ 41001, 41149 ] ],
        SE => [ [  2001,  2699 ] ],                  # Sweden
        US => [ [ 70001, 70998 ],                    # USA (US-AK)
                [ 72001, 72998 ],
                [ 74001, 74998 ],
                [ 91066, 91066 ],                    # (UM-71)
                [ 91101, 91199 ], [ 91280, 91299 ],  # (US-HI)
                [ 91210, 91219 ],                    # (GU)
                [ 91220, 91239 ],                    # (MP)
                [ 91250, 91259 ], [ 91365, 91379 ],  # (MH)
                [ 91764, 91768 ],                    # (AS)
                [ 91901, 91901 ],                    # (UM-86)
                [ 91902, 91903 ],                    # (KI-L)
              ],
    );
    my %IIiii_country = (
        AM => [ 37609, 37618, 37626, 37627, 37682, 37686, 37689, 37690, 37693,
                37694, 37698, 37699, 37704, 37706, 37708, 37711, 37717, 37719,
                37770, 37772, 37781, 37782, 37783, 37785, 37786, 37787, 37788,
                37789, 37789, 37791, 37792, 37801, 37802, 37808, 37815, 37871,
                37872, 37873, 37874, 37875, 37878, 37880, 37882, 37897, 37950,
                37953, 37958, 37959, ],                             # Armenia
        AR => [ 88963, 88968, 89034, 89053, 89055, 89066, ],
        AZ => [ 37575, 37579, 37590, 37636, 37639, 37642, 37661, 37668, 37670,
                37673, 37674, 37675, 37676, 37677, 37729, 37734, 37735, 37736,
                37740, 37744, 37746, 37747, 37749, 37750, 37753, 37756, 37759,
                37769, 37813, 37816, 37825, 37831, 37832, 37835, 37843, 37844,
                37849, 37851, 37852, 37853, 37860, 37861, 37864, 37866, 37869,
                37877, 37883, 37893, 37895, 37896, 37898, 37899, 37901, 37905,
                37907, 37912, 37913, 37914, 37923, 37925, 37936, 37941, 37946,
                37947, 37952, 37957, 37968, 37972, 37978, 37981, 37984, 37985,
                37989, ],                                           # Azerbaijan
        BY => [ 26554, 26643, 26645, 26653, 26657, 26659, 26666, 26668, 26759,
                26763, 26774, 26825, 26832, 26850, 26853, 26855, 26863, 26864,
                26878, 26887, 26941, 26951, 26961, 26966, 33008, 33019, 33027,
                33036, 33038, 33041, 33124, ],                      # Belarus
        EE => [ 26029, 26038, 26045, 26046, 26058, 26115, 26120, 26124, 26128,
                26134, 26135, 26141, 26144, 26145, 26214, 26215, 26218, 26226,
                26227, 26231, 26233, 26242, 26247, 26249, ],        # Estonia
        ES => [ 60320, 60338 ],                          # Spain: Ceuta, Melilla
        GE => [ 37279, 37308, 37379, 37395, 37409, 37432, 37481, 37484, 37492,
                37514, 37531, 37545, 37553, 37621, ],               # Georgia
        KG => [ 36911, 36944, 36974, 36982, 38345, 38353, 38613, 38616,
              ],                                                    # Kyrgyzstan
        KZ => [ 28676, 28766, 28867, 28879, 28951, 28952, 28966, 28978, 28984,
                29802, 29807, 35067, 35078, 35085, 35108, 35173, 35188, 35217,
                35229, 35302, 35357, 35358, 35376, 35394, 35406, 35416, 35426,
                35497, 35532, 35576, 35671, 35699, 35700, 35746, 35796, 35849,
                35925, 35953, 35969, 36003, 36152, 36177, 36208, 36397, 36428,
                36535, 36639, 36686, 36821, 36859, 36864, 36870, 36872, 38001,
                38062, 38064, 38069, 38196, 38198, 38222, 38232, 38328, 38334,
                38341, 38343, 38439, ],                             # Kazakhstan
        LT => [ 26502, 26509, 26515, 26518, 26524, 26529, 26531, 26547, 26600,
                26603, 26620, 26621, 26629, 26633, 26634, 26713, 26728, 26730,
                26732, 26737, ],                                    # Lithuania
        LV => [ 26229, 26238, 26313, 26314, 26318, 26324, 26326, 26335, 26339,
                26346, 26348, 26403, 26406, 26416, 26422, 26424, 26425, 26429,
                26435, 26436, 26446, 26447, 26503, 26544, ],        # Latvia
        MD => [ 33664, 33678, 33679, 33744, 33745, 33748, 33749, 33754, 33810,
                33815, 33821, 33824, 33829, 33881, 33883, 33885, 33886, 33892,
              ],                                                    # Moldova
        TJ => [ 38598, 38599, 38609, 38705, 38713, 38715, 38718, 38719, 38725,
                38734, 38744, 38836, 38838, 38844, 38846, 38847, 38851, 38856,
                38869, 38875, 38878, 38932, 38933, 38937, 38943, 38944, 38947,
                38951, 38954, 38957, ],                             # Tajikistan
        TM => [ 38261, 38267, 38367, 38383, 38388, 38392, 38507, 38511, 38527,
                38529, 38545, 38634, 38637, 38641, 38647, 38656, 38665, 38684,
                38687, 38750, 38755, 38756, 38759, 38763, 38767, 38773, 38774,
                38791, 38799, 38804, 38806, 38880, 38885, 38886, 38895, 38899,
                38911, 38915, 38974, 38987, 38989, 38998, ],      # Turkmenistan
        TV => [ 91643, ],                                           # Tuvalu
        UA => [ 33049, 33058, 33088, 33135, 33173, 33177, 33187, 33213, 33228,
                33231, 33246, 33261, 33268, 33275, 33287, 33297, 33301, 33312,
                33317, 33325, 33345, 33347, 33356, 33362, 33376, 33377, 33393,
                33398, 33409, 33415, 33429, 33446, 33464, 33466, 33484, 33487,
                33495, 33506, 33526, 33536, 33548, 33557, 33562, 33577, 33586,
                33587, 33605, 33609, 33614, 33621, 33631, 33651, 33657, 33658,
                33663, 33699, 33705, 33711, 33717, 33723, 33761, 33777, 33791,
                33805, 33833, 33834, 33837, 33846, 33862, 33869, 33877, 33889,
                33896, 33902, 33907, 33910, 33915, 33924, 33929, 33939, 33945,
                33946, 33959, 33962, 33966, 33976, 33983, 33990, 33998, 34300,
                34302, 34312, 34319, 34401, 34407, 34409, 34415, 34421, 34434,
                34504, 34509, 34510, 34519, 34523, 34524, 34537, 34601, 34607,
                34609, 34615, 34622, 34704, 34708, 34712, 89063, ], # Ukraine
        US => [ 61902,                       # USA (SH-AC)
                61967,                       # (IO)
                78367,                       # (CU-14)
                91245,                       # (UM-79)
                91275,                       # (UM-67)
                91334, 91348, 91356, 91413,  # (FM)
                91442,                       # (MH)
                89009, 89049, 89061,
                89083, 89175, 89528, 89598, 89627, 89628, 89637, 89664, 89674,
                89108, 89208, 89257, 89261, 89262, 89264, 89266, 89269, 89272,
                89314, 89324, 89327, 89332, 89345, 89371, 89376, 89377, 89643,
                89667, 89734, 89744, 89768, 89769, 89799, 89828, 89832, 89834,
                89847, 89864, 89865, 89866, 89867, 89868, 89869, 89872, 89873,
                89879,
              ],
        UZ => [ 38023, 38141, 38146, 38149, 38178, 38262, 38264, 38339, 38396,
                38403, 38413, 38427, 38457, 38462, 38475, 38551, 38553, 38565,
                38567, 38579, 38583, 38589, 38606, 38611, 38618, 38683, 38685,
                38696, 38812, 38815, 38816, 38818, 38829, 38921, 38927,
              ],                                                    # Uzbekistan
    );
    # check single entries before ranges
    for my $country (keys %IIiii_country) {
        for (@{$IIiii_country{$country}}) {
            return $country if $IIiii == $_;
        }
    }
    for my $country (keys %IIiii_country2) {
        for (@{$IIiii_country2{$country}}) {
            return $country if $IIiii >= $_->[0] && $IIiii <= $_->[1];
        }
    }
    return '';
}

# WMO-No. 306 Vol I.1, Part A, code table 0161:
sub _A1bw2region {
    my $A1bw = shift;

    return qw(I II III IV V VI Antarctic)[substr($A1bw, 0, 1) - 1];
}

# determine the country that operates a station to select correct decoding rules
sub _A1bw2country {
    my $A1bw = shift;

    # ISO-3166 coded
    my %A1bw_country = (
        CA => [ qw(44137 44138 44139 44140 44141 44142 44150 44235 44251 44255
                   44258 45132 45135 45136 45137 45138 45139 45140 45141 45142
                   45143 45144 45145 45147 45148 45149 45150 45151 45152 45154
                   45159 45160 46004 46036 46131 46132 46134 46145 46146 46147
                   46181 46183 46184 46185 46204 46205 46206 46207 46208 46531
                   46532 46534 46537 46538 46559 46560 46561 46562 46563 46564
                   46565 46632 46633 46634 46635 46636 46637 46638 46639 46640
                   46641 46642 46643 46651 46652 46657 46660 46661 46692 46695
                   46698 46700 46701 46702 46705 46707 46710 47559 47560)
              ],
        US => [ qw(21413 21414 21415 21416 21417 21418 21419 32012 32301 32302
                   32411 32412 32745 32746 41001 41002 41003 41004 41005 41006
                   41007 41008 41009 41010 41011 41012 41013 41015 41016 41017
                   41018 41021 41022 41023 41025 41035 41036 41040 41041 41043
                   41044 41046 41047 41048 41049 41420 41421 41424 41X01 42001
                   42002 42003 42004 42005 42006 42007 42008 42009 42010 42011
                   42012 42015 42016 42017 42018 42019 42020 42025 42035 42036
                   42037 42038 42039 42040 42041 42042 42053 42054 42055 42056
                   42057 42058 42059 42060 42080 42407 42408 42409 42534 43412
                   43413 44001 44003 44004 44005 44006 44007 44008 44009 44010
                   44011 44012 44013 44014 44015 44017 44018 44019 44020 44022
                   44023 44025 44026 44027 44028 44039 44040 44052 44053 44056
                   44060 44065 44066 44070 44098 44401 44402 44585 44X11 45001
                   45002 45003 45004 45005 45006 45007 45008 45009 45010 45011
                   45012 45020 45021 45022 45023 46001 46002 46003 46005 46006
                   46007 46008 46009 46010 46011 46012 46013 46014 46015 46016
                   46017 46018 46019 46020 46021 46022 46023 46024 46025 46026
                   46027 46028 46029 46030 46031 46032 46033 46034 46035 46037
                   46038 46039 46040 46041 46042 46043 46045 46047 46048 46050
                   46051 46053 46054 46059 46060 46061 46062 46063 46066 46069
                   46070 46071 46072 46073 46075 46076 46077 46078 46079 46080
                   46081 46082 46083 46084 46085 46086 46087 46088 46089 46094
                   46105 46106 46107 46270 46401 46402 46403 46404 46405 46406
                   46407 46408 46409 46410 46411 46412 46413 46419 46490 46499
                   46551 46553 46779 46780 46781 46782 46785 46X84 48011 51000
                   51001 51002 51003 51004 51005 51026 51027 51028 51100 51101
                   51406 51407 51425 51426 51542 51X04 52009 52401 52402 52403
                   52404 52405 52406 54401 62027 91204 91222 91251 91328 91338
                   91343 91352 91355 91356 91365 91374 91377 91411 91442 ABAN6
                   ACQS1 ACXS1 AGMW3 ALRF1 ALSN6 AMAA2 ANMN6 ANRN6 APQF1 APXF1
                   AUGA2 BDVF1 BGXN3 BHRI3 BIGM4 BLIA2 BLTA2 BNKF1 BOBF1 BRIM2
                   BSBM4 BSLM2 BURL1 BUSL1 BUZM3 BWSF1 CANF1 CARO3 CBLO1 CBRW3
                   CDEA2 CDRF1 CHDS1 CHLV2 CHNO3 CLKN7 CLSM4 CNBF1 CPXC1 CSBF1
                   CSPA2 CVQV2 CWQO3 CYGM4 DBLN6 DEQD1 DESW1 DISW3 DKKF1 DMBC1
                   DPIA1 DRFA2 DRSD1 DRYF1 DSLN7 DUCN7 EB01 EB10 EB31 EB32 EB33
                   EB35 EB36 EB43 EB52 EB53 EB61 EB62 EB70 EB90 EB91 EB92 ELQC1
                   ELXC1 ERKC1 EROA2 FARP2 FBIS1 FBPS1 FFIA2 FILA2 FPSN7 FPTM4
                   FWYF1 GBCL1 GBIF1 GBLW3 GBQN3 GBTF1 GDIL1 GDIV2 GDQM6 GDWV2
                   GDXM6 GELO1 GLLN6 GRMM4 GSLM4 GTBM4 GTLM4 GTQF1 GTRM4 GTXF1
                   HCEF1 HHLO1 HMRA2 HPLM2 HUQN6 IOSN3 JCQN4 JCRN4 JCTN4 JKYF1
                   JOQP4 JOXP4 KCHA2 KNOH1 KNSW3 KTNF1 LBRF1 LBSF1 LCNA2 LDLC3
                   LMDF1 LMFS1 LMRF1 LMSS1 LNEL1 LONF1 LPOI1 LRKF1 LSCM4 LSNF1
                   LTQM2 MAQT2 MAXT2 MDRM1 MEEM4 MISM1 MLRF1 MPCL1 MRKA2 MUKF1
                   NABM4 NAQR1 NAXR1 NIQS1 NIWS1 NLEC1 NOQN7 NOXN7 NPDW3 NWPO3
                   OLCN6 OTNM4 OWQO1 OWXO1 PBFW1 PBLW1 PBPA2 PCLM4 PILA2 PILM4
                   PKYF1 PLSF1 PNGW3 POTA2 PRIM4 PRTA2 PSCM4 PTAC1 PTAT2 PTGC1
                   PWAW3 RKQF1 RKXF1 ROAM4 RPRN6 SANF1 SAQG1 SAUF1 SAXG1 SBIO1
                   SBLM4 SCLD1 SCQC1 SDIA2 SEQA2 SFXC1 SGNW3 SGOF1 SISA2 SISW1
                   SJLF1 SJOM4 SLVM5 SMBS1 SMKF1 SOQO3 SPGF1 SPTM4 SRST2 STDM4
                   SUPN6 SVLS1 SXHW3 SYWW3 TAWM4 TCVF1 TDPC1 TESTQ THIN6 TIBC1
                   TIQC1 TIXC1 TPEF1 TPLM2 TRRF1 TTIW1 VENF1 VMSV2 WAQM3 WATS1
                   WAXM3 WEQM1 WEXM1 WFPM4 WHRI2 WIWF1 WKQA1 WKXA1 WPLF1 WPOW1
                   WRBF1 YGNN6 YRSV2)
              ],
    );
    for my $country (keys %A1bw_country) {
        for (@{$A1bw_country{$country}}) {
            return $country if $A1bw eq $_;
        }
    }
    return '';
}

# determine the country that operates a station to select correct decoding rules
sub _A1A22country {
    my $A1A2 = substr shift, 0, 2;

    # WMO-No. 306 Vol I Part I.1, Section B recommends to use
    #   WMO-No. 386 Vol I Att. II-5 Table C1 but actually ISO-3166 is used
    #   e.g. ARP03,CAP16,CKP23,KIP39,MNP45,PAP50,ISP34,MRP43,PAP50,RUP59
    #   except AA: e.g. AABRI,AADIS,AAEMI,AAERI,AALAU,AAPEG,AAVIT: use AQ
    return $A1A2 eq 'AA' ? 'AQ' : $A1A2;
}

# a3 standard isobaric surface for which the geopotential is reported
sub _codeTable0264 {
    my $idx = shift;

    return {
        1 => '1000',
        2 =>  '925',
        5 =>  '500',
        7 =>  '700',
        8 =>  '850'
    }->{$idx};
}

# C  genus of cloud
# C  genus of cloud predominating in the layer
# C' genus of cloud whose base is below the level of the station
sub _codeTable0500 {
    my $idx = shift;

    return $idx eq '/' ? (cloudTypeNotAvailable => undef)
                       : (cloudType => qw(CI CC CS AC AS NS SC ST CU CB)[$idx]);
}

# WMO-No. 306 Vol I.1, Part A, code table 0700:
# D  true direction from which surface wind is blowing
# D  true direction towards which ice has drifted in the past 12 hours
# DH true direction from which CH clouds are moving
# DK true direction from which swell is moving
# DL true direction from which CL clouds are moving
# DM true direction from which CM clouds are moving
# Da true direction in which orographic clouds or clouds with vertical development are seen
# Da true direction in which the phenomenon indicated is observed or in which conditions specified in the same group are reported
# De true direction towards which an echo pattern is moving
# Dp true direction from which the phenomenon indicated is coming
# Ds true direction of resultant displacement of the ship during the three hours preceding the time of observation
# D1 true direction of the point position from the station
sub _codeTable0700 {
    my ($type, $idx, $parameter) = @_;
    my $dir_tag;

    $dir_tag = $type eq '' ? 'compassDir' : "${type}CompassDir";
    return   $idx eq '/'                ? ("${type}NA" => undef)

           :    $idx == 0
             && defined $parameter
             && (   $parameter eq 'Da'
                 || $parameter eq 'Dp') ? (locationSpec => 'atStation')
           :    $idx == 0
             && defined $parameter      ? ()
           : $idx == 0                  ? ("${type}None" => undef)

           :    $idx == 9
             && defined $parameter
             && $parameter eq 'Da'      ? (locationSpec => 'allDirections')
           :    $idx == 9
             && defined $parameter      ? ()
           : $idx == 9                  ? ("${type}Invisible" => undef)
           :                     ($dir_tag => qw(NE E SE S SW W NW N)[$idx - 1])
           ;
}

# dc duration and character of precipitation given by RRR
sub _codeTable0833 {
    my $idx = shift;

    return   $idx == 0 || $idx == 4 ? (hours => { v => 1, q => 'isLess' })
           : $idx == 1 || $idx == 5 ? (hoursFrom => 1, hoursTill => 3)
           : $idx == 2 || $idx == 6 ? (hoursFrom => 3, hoursTill => 6)
           :                          (hours => { v => 6, q => 'isGreater' })
           ;
}

# eC elevation angle of the top of the cloud indicated by C
# e' elevation angle of the top of the phenomenon above horizon
sub _codeTable1004 {
    my $idx = shift;

    return   $idx == 0 ? (topsInvisible => undef)
           : $idx == 1 ? (elevationAngle => { v => 45, q => 'isEqualGreater' })
           : $idx == 9 ? (elevationAngle => { v => 5,  q => 'isLess' })
           :             (elevationAngle => qw(30 20 15 12 9 7 6)[$idx - 2])
           ;
}

# h height above surface of the base of the lowest cloud seen
#   A height exactly equal to one of the values at the ends of the ranges shall
#   be coded in the higher range
sub _codeTable1600 {
    my ($idx, $country) = @_;
    my (@v, $unit);

    return { s => $idx, notAvailable => undef } if $idx eq '/';
    if ($country eq 'US') {
        # FMH-2 table 4-3:
        #   idx:    0   1   2   3    4    5    6    7    8      9
        #   from:   0 200 400 700 1000 2000 3300 5000 7000 >=8500
        #   to:   100 300 600 900 1900 3200 4900 6500 8000
        # FMH-2 4.2.1.3:
        #   heights between the end of a range and beginning of the next are
        #   rounded up if midway or greater
        @v = (0, 150, 350, 650, 950, 1950, 3250, 4950, 6750, 8250)[$idx,$idx+1];
        $unit = 'FT';
    } else {
        @v = (0, 50, 100, 200, 300, 600, 1000, 1500, 2000, 2500)[$idx,$idx + 1];
        $unit = 'M';
    }
    return { s    => $idx,
             from => { v => $v[0], u => $unit, q => 'isEqualGreater' }
           }
        if $idx == 9;
    return { s    => $idx,
             from => { v => $v[0], u => $unit },
             to   => { v => $v[1], q => 'isLess', u => $unit }
           };
}

# hshs height of base of cloud layer or mass whose genus is indicated by C
# htht height of the tops of the lowest clouds or height of the lowest cloud layer or fog
# "If the observed value is between two of the heights as given in the table,
# the code figure for the lower height shall be reported, except for code
# figures 90–99; in this decile, a value exactly equal to one of the heights at
# the ends of the ranges shall be coded in the higher range ..."
sub _codeTable1677 {
    my $idx = shift;

    return
        if $idx >= 51 && $idx <= 55;

    if ($idx >= 91 && $idx <= 98) {
        my @arr;

        @arr = (50, 100, 200, 300, 600, 1000, 1500, 2000, 2500)
                   [ $idx - 91, $idx - 90 ];
        return [ { v => $arr[0], u => 'M' },
                 { v => $arr[1], u => 'M', q => 'isLess' } ];
    }

    return {   $idx == 0  ? ( v => 30, q => 'isLess' )
             : $idx <  50 ? ( v => 30 * $idx,          rp => 30   )
             : $idx == 50 ? ( v => 1500,               rp => 300  )
             : $idx <  80 ? ( v => 300 * ($idx - 50),  rp => 300  )
             : $idx == 80 ? ( v => 9000,               rp => 1500 )
             : $idx <  88 ? ( v => 1500 * ($idx - 74), rp => 1500 )
             : $idx == 88 ? ( v => 21000,                         ) # exactly
             : $idx == 89 ? ( v => 21000, q => 'isGreater'        )
             : $idx == 90 ? ( v => 50,    q => 'isLess'           )
             :              ( v => 2500,  q => 'isEqualGreater'   ), # 99
             u => 'M'
           };
}

# FMH-2 table 6-8: hshs
# "If the observed value is midway between two of the heights as given in the
# table, the code figure for the lower height shall be reported, except for code
# figures 50-60. In this range a value midway between the heights would be
# rounded up."
#  ...
#  mid 49-50 -> 49
#  mid 50-56 -> 56
#  ...
#  mid 56-59 -> 59
#  mid 59-60 -> 60
#  mid 60-61 -> 60
#  mid 61-62 -> 61
#  ...
sub _codeTable1677US {
    my $idx = shift;

    return
        if $idx == 33 || ($idx >= 51 && $idx <= 55) || $idx >= 90;

    return {   $idx == 0  ? ( v => 100, q => 'isLess' )
             : $idx == 1  ? ( v => 100,                            rpi => 50   )
             : $idx <  33 ? ( v => 100 * $idx,         rne => 50,  rpi => 50   )
             : $idx <  50 ? ( v => 100 * ($idx - 1),   rne => 50,  rpi => 50   )
             : $idx == 50 ? ( v => 4900,               rne => 50,  rp  => 550  )
             : $idx == 56 ? ( v => 6000,               rn  => 550, rp  => 500  )
             : $idx <  60 ? ( v => 1000 * ($idx - 50), rn  => 500, rp  => 500  )
             : $idx == 60 ? ( v => 10000,              rn  => 500, rpi => 500  )
             : $idx <  80 ? ( v => 1000 * ($idx - 50), rne => 500, rpi => 500  )
             : $idx == 80 ? ( v => 30000,              rne => 500, rpi => 2500 )
             : $idx == 81 ? ( v => 35000,              rne => 2500,rpi => 2000 )
             : $idx == 82 ? ( v => 39000,              rne => 2000,rpi => 2500 )
             : $idx <  88 ? ( v => 5000 * ($idx - 74) - 1000,
                                                       rne => 2500,rpi => 2500 )
             : $idx == 88 ? ( v => 69000,              rne => 2500             )
             :              ( v => 69000, q => 'isGreater' ),
             u => 'FT'
           };
}

# N  total cloud cover
# Nh amount of all the CL cloud present or, if no CL cloud is present, the amount of all the CM cloud present
# Ns amount of individual cloud layer or mass whose genus is indicated by C
# N' amount of cloud whose base is below the level of the station
sub _codeTable2700 {
    my $idx = shift;

    return   $idx eq '/' ? { oktasNotAvailable => undef }
           : $idx eq '9' ? { skyObscured => undef }
           :               { oktas => $idx  }
           ;
}

# QA location quality class (range of radius of 66% confidence)
# WMO-No. 306 Vol I.2, Part B, CODE/FLAG Tables, code table 0 33 027
sub _codeTable3302 {
    my $idx = shift;

    return   $idx eq '/' ? { notAvailable => undef }
           : $idx > 4    ? { invalidFormat => $idx }
           : (
              { distance     => { v => 1500, u => 'M', q => 'isEqualGreater' }},
              { distanceFrom => { v => 500,  u => 'M', q => 'isEqualGreater' },
                distanceTo   => { v => 1500, u => 'M', q => 'isLess'         }},
              { distanceFrom => { v => 250,  u => 'M', q => 'isEqualGreater' },
                distanceTo   => { v => 500,  u => 'M', q => 'isLess'         }},
              { distance     => { v => 250,  u => 'M', q => 'isLess'         }},
              { distance     => { v => 100,  u => 'M', q => 'isLess'         }}
             )[$idx]
           ;
}

# Rt time at which precipitation given by RRR began or ended
sub _codeTable3552 {
    my $idx = shift;

    return   $idx == 1 ? (hours => { v => 1, q => 'isLess' })
           : $idx <= 6 ? (hoursFrom => $idx - 1, hoursTill => $idx)
           : $idx == 7 ? (hoursFrom => 6, hoursTill => 12)
           : $idx == 8 ? (hours => { v => 12, q => 'isGreater' })
           :             (notAvailable => undef)
           ;
}

# RR amount of precipitation or water equivalent of solid precipitation, or diameter of solid deposit
sub _codeTable3570 {
    my ($idx, $tag) = @_;

    return   $idx <= 55 ? ($tag => { v => $idx + 0, u => 'MM' })
           : $idx <= 90 ? ($tag => { v => ($idx - 50) * 10, u => 'MM' })
           : $idx <= 96 ? ($tag => { v => ($idx - 90) / 10, u => 'MM' })
           : $idx == 97 ? (precipTraces => undef)
           : $idx == 98 ? ($tag => { v => 400, u => 'MM', q => 'isGreater' })
           :              (notAvailable => undef)
           ;
}

# RRR amount of precipitation which has fallen during the period preceding the time of observation, as indicated by tR
sub _codeTable3590 {
    my $idx = shift;

    return   $idx eq '///' ? (notAvailable => undef)
           : $idx <= 988   ? (precipAmount => { v => $idx + 0, u => 'MM' })
           : $idx == 989   ? (precipAmount => { v => 989,      u => 'MM',
                                                q => 'isEqualGreater' })
           : $idx == 990   ? (precipTraces => undef)
           :                 (precipAmount => { v => ($idx - 990) / 10,
                                                u => 'MM' })
           ;
}

# ss depth of newly fallen snow
sub _codeTable3870 {
    my ($r, $idx) = @_;

    if ($idx == 99) {
        $$r->{noMeasurement} = undef;
    } else {
        $$r->{precipAmount} =
              $idx <= 55 ? { v => $idx * 10, u => 'MM' }
            : $idx <= 90 ? { v => ($idx - 50) * 100, u => 'MM' }
            : $idx <= 96 ? { v => $idx + 0, u => 'MM' }
            : $idx == 97 ? { v => 1, q => 'isLess', u => 'MM' }
            :              { v => 4000, q => 'isGreater', u => 'MM' }
            ;
    }
    return;
}

# sss total depth of snow
sub _codeTable3889 {
    my $sss = shift;

    return   $sss eq '///' ? (notAvailable => undef)
           : $sss eq '000' ? (invalidFormat => $sss)
           : $sss eq '997' ? (precipAmount =>
                                         { v => 0.5, u => 'CM', q => 'isLess' })
           : $sss eq '998' ? (coverNotCont => undef)
           : $sss eq '999' ? (noMeasurement => undef)
           :                 (precipAmount => { v => $sss + 0, u => 'CM' });
}

# tR duration of period of reference for amount of precipitation, ending at the time of the report
sub _codeTable4019 {
    my $idx = shift;

    return $idx == 0 ? { notAvailable => undef }
                     : { hours => (6, 12, 18, 24, 1, 2, 3, 9, 15)[$idx - 1] };
}

# tt time before observation or duration of phenomena (00-69)
# zz variation, location or intensity of phenomena (76-99)
# for both: 70-75
sub _codeTable4077 {
    my ($idx, $occurred) = @_; # 'Since' is default for occurred

    $occurred = $occurred ? [ occurred => $occurred ] : [];
    return   $idx <= 60 ? { timeBeforeObs => {
                                            hours => sprintf('%.1f', $idx / 10),
                                            @$occurred }}
           : $idx <= 66 ? { timeBeforeObs => { hoursFrom => $idx - 55,
                                               hoursTill => $idx - 54,
                                               @$occurred }}
           : $idx == 67 ? { timeBeforeObs => { hoursFrom => 12,
                                               hoursTill => 18,
                                               @$occurred }}
           : $idx == 68 ? { timeBeforeObs => {
                                         hours => { v => 18, q => 'isGreater' },
                                         @$occurred }}
           : $idx == 69 ? { timeBeforeObs => { notAvailable => undef,
                                               @$occurred }}
           : $idx <= 75 ? { phenomVariation =>
                              qw(beganDuringObs      endedDuringObs
                                 beganEndedDuringObs changedDuringObs
                                 beganAfterObs       endedAfterObs)[$idx - 70] }
           : $idx <= 82 ? { location => { locationSpec =>
                          (qw(atStation                atStationNotInDistance
                              allDirections            allDirectionsNotAtStation
                              approachingStation       recedingFromStation
                              passingStationInDistance)[$idx - 76])} }
           : $idx == 83 ? { location => { inDistance => undef }}
           : $idx == 84 ? { location => { inVicinity => undef }}
           :              { phenomDescr =>
                                   qw(aloftNotNearGround
                                      nearGroundNotAloft isOccasional
                                      isIntermittent     isFrequent
                                      isSteady           isIncreasing
                                      isDecreasing       isVariable
                                      isContinuous       isVeryLight
                                      isLight            isModerate
                                      isHeavy            isVeryHeavy)[$idx - 85]
                          }
           ;
}

# VV   horizontal visibility at surface
# VsVs visibility towards the sea
# WMO-No. 306 Vol I.1, Part A, Section A, Code Forms, b:
#   VV: code table 4377. If the distance of visibility is between two of the
#   distances given in Code table 4377, the code figure for the smaller
#   distance shall be reported.
# WMO-No. 306 Vol I.1, Part A, Section A, 12.2.1.3.2:
#   In reporting visibility at sea, the decile 90-99 shall be used for VV.
# WMO-No. 488:
#   3.2.2.3 Observations at sea stations
#   3.2.2.3.4 Visibility
#   The requirements ... are ... low, ... decade 90-99 of code table 4377 ...
sub _codeTable4377 {
    my ($r, $idx, $station_type) = @_;
    my (%dist, $vis_type);

    if ($idx eq '//') {
        $r->{visPrev} = { s => $idx, notAvailable => undef };
        return;
    }
    if ($idx >= 51 && $idx <= 55) {
        $r->{visPrev} = { s => $idx, invalidFormat => $idx };
        return;
    }

    $vis_type = 'visPrev';
    if ($idx <= 89) {
        %dist =   $idx == 0  ? (v => 100, u => 'M', q => 'isLess')
                : $idx <= 49 ? (v => $idx * 100, rp => 100, u => 'M')
                : $idx == 50 ? (v => 5, rp => 1, u => 'KM')
                : $idx <= 79 ? (v => $idx - 50, rp => 1, u => 'KM')
                : $idx == 80 ? (v => 30, rp => 5, u => 'KM')
                : $idx <= 87 ? (v => 5 * ($idx - 74), rp => 5, u => 'KM')
                : $idx == 88 ? (v => 70, u => 'KM')
                :              (v => 70, u => 'KM', q => 'isGreater')
                ;
    } elsif ($idx == 90 || $idx == 99) {
        $vis_type = 'visibilityAtLoc';
        %dist     = @{(
            [ v => 50, u => 'M',  q => 'isLess' ],
            [ v => 50, u => 'KM', q => 'isEqualGreater' ],
        )[$idx == 90 ? 0 : 1]};
    } else {
        $vis_type = 'visibilityAtLoc';
        @dist{qw(v rp u)} = @{(
            [  50, 150,  'M' ], # 91
            [ 200, 300,  'M' ], # 92
            [ 500, 500,  'M' ], # 93
            [   1,   1, 'KM' ], # 94
            [   2,   2, 'KM' ], # 95
            [   4,   6, 'KM' ], # 96
            [  10,  10, 'KM' ], # 97
            [  20,  30, 'KM' ], # 98
        )[$idx - 91]};
    }

    if ($vis_type eq 'visPrev' || $station_type =~ /^[AO]/) {
        $r->{visPrev} = { s => $idx, distance => \%dist };
    } else {
        $r->{visibilityAtLoc} = {
            s          => $idx,
            visibility => { distance => \%dist },
            locationAt => 'MAR'
        };
    }
    return;
}

# FMH-2 table 4-4
sub _codeTable4377US {
    my ($r, $idx, $station_type) = @_;
    my (%dist, $vis_type);

    if ($idx eq '//') {
        $r->{visPrev} = { s => $idx, notAvailable => undef };
        return;
    }

    $vis_type = 'visPrev';
    $dist{u}  = 'SM';
    if ($idx == 0) {
        @dist{qw(v q)} = (1/16, 'isLess');
    } elsif ($idx =~ /^(?:0[1-68]|[12][02468]|3[026]|4[048])$/) {
        $dist{v} = $idx / 16;
    } elsif ($idx =~ /^(?:5[68]|6[0134689]|7[134]|8[02457])$/) {
        $dist{v} = {
            56 =>  4, 58 =>  5,
            60 =>  6, 61 =>  7, 63 =>  8, 64 => 9, 66 => 10, 68 => 11, 69 => 12,
            71 => 13, 73 => 14, 74 => 15,
            80 => 20, 82 => 25, 84 => 30, 85 => 35, 87 => 40,
        }->{$idx};
    } elsif ($idx == 89) {
        @dist{qw(v q)} = (45, 'isEqualGreater');
    # FMH-1 6.5.2:
    # If the actual visibility falls halfway between two reportable
    # values, the lower value shall be reported.
    # FMH-2 table 4-5
    } elsif ($idx >= 90 && $idx <= 91) {
        $vis_type = 'visibilityAtLoc';
        %dist     = @{(
            [ v => 1/16, u => 'NM', q => 'isLess' ],
            [ v => 1/16, u => 'NM', rpi => 1/32 ],
        )[$idx - 90]};
    } elsif ($idx >= 92 && $idx <= 98) {
        $vis_type = 'visibilityAtLoc';
        @dist{qw(v rne rpi)} = @{(
            [ 1/8, 1/32, 1/16 ], # 92: 1/8
            [ 1/4, 1/16, 1/8  ], # 93: 1/4
            [ 1/2, 1/8,  1/4  ], # 94: 1/2
            [ 1,   1/4,  3/4  ], # 95: 1, 1.5
            [ 2,   1/4,  2    ], # 96: 2, 2.5, 3
            [ 5,   1,    7/2  ], # 97: 5, 6, 7, 8
            [ 9,   1/2,  1    ], # 98: 9, 10
        )[$idx - 92]};
        $dist{u} = 'NM';
    } else {
        $r->{visPrev} = { s => $idx, invalidFormat => $idx };
        return;
    }
    # ranges like for manual stations from FMH-1 table 6-1
    _setVisibilitySMrangeUS \%dist
        if $dist{u} eq 'SM' && !exists $dist{q};
    if ($vis_type eq 'visPrev' || $station_type =~ /^[AO]/) {
        $r->{visPrev} = { s => $idx, distance => \%dist };
    } else {
        $r->{visibilityAtLoc} = {
            s          => $idx,
            visibility => { distance => \%dist },
            locationAt => 'MAR'
        };
    }
    return;
}

# MANOBS 12.3.1.4
# MANOBS 12.3.1.4.1
#   If the visibility ... falls between two code figures, use the lower code
#   figure.
sub _codeTable4377CA {
    my ($r, $idx) = @_;
    my %dist;

    if ($idx eq '//') {
        $r->{visPrev} = { s => $idx, notAvailable => undef };
        return;
    }

    if ($idx =~ /^(?:0[02468]|1[026]|2[048]|3[26]|4[08])$/) {
        $dist{v} = $idx / 16;
    } elsif ($idx =~ /^(?:5[689]|6[124679]|7[024]|8[0-8])$/) {
        $dist{v} = {
            56 =>  4, 58 =>  5, 59 =>  6,
            61 =>  7, 62 =>  8, 64 =>  9, 66 => 10, 67 => 11, 69 => 12,
            70 => 13, 72 => 14, 74 => 15,
            80 => 19, 81 => 22, 82 => 25, 83 => 28, 84 => 32, 85 => 35,
                      86 => 38, 87 => 41, 88 => 44,
        }->{$idx};
    } elsif ($idx == 89) {
        %dist = (v => 44, q => 'isGreater');
    } else {
        $r->{visPrev} = { s => $idx, invalidFormat => $idx };
        return;
    }

    if (!exists $dist{q}) {
        if ($dist{v} < 3/4) {
            $dist{rp} = 1/8;
        } elsif ($dist{v} < 2.5) {
            $dist{rp} = 1/4;
        } elsif ($dist{v} < 3) {
            $dist{rp} = 1/2;
        } elsif ($dist{v} < 15) {
            $dist{rp} = 1;
        } elsif ($dist{v} == 15 || $dist{v} == 28) {
            $dist{rp} = 4;
        } elsif ($dist{v} != 44) {
            $dist{rp} = 3;
        }
    }

    $dist{u} = 'SM';
    $r->{visPrev} = { s => $idx, distance => \%dist };
    return;
}

# w1w1 Present weather phenomenon not specified in Code table 4677, or
#      specification of present weather phenomenon in addition to group 7wwW1W2
sub _codeTable4687 {
    my $idx = shift;
    my $r;

    return { weatherPresent1 => $idx + 0 }
        unless (   ($idx >= 47 && $idx <= 57)
                || ($idx >= 60 && $idx <= 67)
                || ($idx >= 70 && $idx <= 77));

    $r = ({ weatherSynopFG => { # 47
             visibilityFrom => { distance => { v => 60, u => 'M' }},
             visibilityTo   => { distance => { v => 90, u => 'M' }}}},
         { weatherSynopFG => { # 48
             visibilityFrom => { distance => { v => 30, u => 'M' }},
             visibilityTo   => { distance => { v => 60, u => 'M' }}}},
         { weatherSynopFG => { # 49
             visibility     => { distance => { v => 30, u => 'M',
                                               q => 'isLess' }}}},
         { weatherSynopPrecip => { # 50
             rateOfFall     => { v => '0.10', u => 'MMH', q => 'isLess' }}},
         { weatherSynopPrecip => { # 51
             rateOfFallFrom => { v => '0.10', u => 'MMH' },
             rateOfFallTo   => { v => 0.19, u => 'MMH' }}},
         { weatherSynopPrecip => { # 52
             rateOfFallFrom => { v => '0.20', u => 'MMH' },
             rateOfFallTo   => { v => 0.39, u => 'MMH' }}},
         { weatherSynopPrecip => { # 53
             rateOfFallFrom => { v => '0.40', u => 'MMH' },
             rateOfFallTo   => { v => 0.79, u => 'MMH' }}},
         { weatherSynopPrecip => { # 54
             rateOfFallFrom => { v => '0.80', u => 'MMH' },
             rateOfFallTo   => { v => 1.59, u => 'MMH' }}},
         { weatherSynopPrecip => { # 55
             rateOfFallFrom => { v => '1.60', u => 'MMH' },
             rateOfFallTo   => { v => 3.19, u => 'MMH' }}},
         { weatherSynopPrecip => { # 56
             rateOfFallFrom => { v => '3.20', u => 'MMH' },
             rateOfFallTo   => { v => 6.39, u => 'MMH' }}},
         { weatherSynopPrecip => { # 57
             rateOfFall     => { v => 6.4,
                                 u => 'MMH',
                                 q => 'isEqualGreater' }}},
         {}, # 58
         {}, # 59
         { weatherSynopPrecip => { # 60
             rateOfFall     => { v => '1.0', u => 'MMH', q => 'isLess' }}},
         { weatherSynopPrecip => { # 61
             rateOfFallFrom => { v => '1.0', u => 'MMH' },
             rateOfFallTo   => { v => 1.9, u => 'MMH' }}},
         { weatherSynopPrecip => { # 62
             rateOfFallFrom => { v => '2.0', u => 'MMH' },
             rateOfFallTo   => { v => 3.9, u => 'MMH' }}},
         { weatherSynopPrecip => { # 63
             rateOfFallFrom => { v => '4.0', u => 'MMH' },
             rateOfFallTo   => { v => 7.9, u => 'MMH' }}},
         { weatherSynopPrecip => { # 64
             rateOfFallFrom => { v => '8.0', u => 'MMH' },
             rateOfFallTo   => { v => 15.9, u => 'MMH' }}},
         { weatherSynopPrecip => { # 65
             rateOfFallFrom => { v => '16.0', u => 'MMH' },
             rateOfFallTo   => { v => 31.9, u => 'MMH' }}},
         { weatherSynopPrecip => { # 66
             rateOfFallFrom => { v => '32.0', u => 'MMH' },
             rateOfFallTo   => { v => 63.9, u => 'MMH' }}},
         { weatherSynopPrecip => { # 67
             rateOfFall     => { v => '64.0',
                                 u => 'MMH',
                                 q => 'isEqualGreater' }}},
         {}, # 68
         {}, # 69
         { weatherSynopPrecip => { # 70
             rateOfFall     => { v => '1.0', u => 'CMH', q => 'isLess' }}},
         { weatherSynopPrecip => { # 71
             rateOfFallFrom => { v => '1.0', u => 'CMH' },
             rateOfFallTo   => { v => 1.9, u => 'CMH' }}},
         { weatherSynopPrecip => { # 72
             rateOfFallFrom => { v => '2.0', u => 'CMH' },
             rateOfFallTo   => { v => 3.9, u => 'CMH' }}},
         { weatherSynopPrecip => { # 73
             rateOfFallFrom => { v => '4.0', u => 'CMH' },
             rateOfFallTo   => { v => 7.9, u => 'CMH' }}},
         { weatherSynopPrecip => { # 74
             rateOfFallFrom => { v => '8.0', u => 'CMH' },
             rateOfFallTo   => { v => 15.9, u => 'CMH' }}},
         { weatherSynopPrecip => { # 75
             rateOfFallFrom => { v => '16.0', u => 'CMH' },
             rateOfFallTo   => { v => 31.9, u => 'CMH' }}},
         { weatherSynopPrecip => { # 76
             rateOfFallFrom => { v => '32.0', u => 'CMH' },
             rateOfFallTo   => { v => 63.9, u => 'CMH' }}},
         { weatherSynopPrecip => { # 77
             rateOfFall     => { v => '64.0',
                                 u => 'CMH',
                                 q => 'isEqualGreater' }}},
       )[$idx - 47];

    $r->{weatherSynopPrecip}{phenomSpec} = 'DZ' if $idx >= 50 && $idx <= 57;
    $r->{weatherSynopPrecip}{phenomSpec} = 'RA' if $idx >= 60 && $idx <= 67;
    $r->{weatherSynopPrecip}{phenomSpec} = 'SN' if $idx >= 70;

    return $r;
}

# WMO-No. 306 Vol I.1, Part A, Section B:
# HwHw     height of wind waves, in units of 0.5 m
# HwaHwa   height of waves, obtained by instrumental methods, in units of 0.5 m
# Hw1Hw1   height of swell waves, in units of 0.5 m
# Hw2Hw2   height of swell waves, in units of 0.5 m
sub _waveHeight {
    my $v = shift;

    return { v => $v * 0.5, $v > 0 ? (rn => 0.25) : (), rp => 0.25, u => 'M' };
}

sub _radiationType {
    my $idx = shift;

    return qw(rad0PosNet rad1NegNet rad2GlobalSolar    rad3DiffusedSolar
              rad4DownwardLongWave  rad5UpwardLongWave rad6ShortWave)[$idx];
}

sub _getTempCity {
    my ($prefix, $sign, $temp, $tempAirF) = @_;

    return {
        s => "$prefix$sign$temp",
        temp =>
            { v =>
                 $sign == 1                                  ? '-' . ($temp + 0)
               : defined $tempAirF && $temp + 50 < $tempAirF ? $temp + 100
               :                                               $temp + 0,
              u => 'F'
    }};
}

sub _getRecordTempData {
    my $rec_dat = shift;
    my ($rec_type, $rec_qual, $rec_period);

    ($rec_type, $rec_qual, $rec_period) = unpack 'a2aa2', $rec_dat;
    return {
        s            => $rec_dat,
        recordPeriod => $rec_period,
        recordType   => {
            v => $rec_type,
            $rec_qual eq 'X' ? (q => $rec_type eq 'LO' ? 'isLess' : 'isGreater')
                             : ()
        }
    };
}

sub _check_915dd {
    my ($r, $winds_est) = @_;

    if (/\G915($re_dd) /ogc) {
        $r->{s} .= " 915$1";
        if ($winds_est) {
            $r->{wind}{isEstimated} = undef;
        } else {
            $r->{wind}{dir} = { rp => 4, rn => 5 };
        }
        $r->{wind}{dir}{v} = ($1 % 36) * 10;
    }
    return;
}

sub _check_958EhDa {
    my $r = shift;

    while (m{\G958([137/])(\d) }gc) {
        $r->{s} .= " 958$1$2";

        push @{$r->{maxConcentration}}, {
            $1 eq '/' ? (elevNotAvailable => undef) : (elevAboveHorizon => $1),
            location => +{ _codeTable0700 '', $2, 'Da' }
        };
    }
    return;
}

sub _parse_vpDp {
    my ($vp, $Dp) = @_;
    my @speed_KMH = (10,26,45,63,82,101,119,138,156);

    return $Dp == 0
        ? { isStationary => undef }
        : { _codeTable0700('', $Dp, 'Dp'),
          # WMO-No. 306 Vol I.1, Part A, code table 4448:
            $vp == 0 ? (speed => [ { v => 5, u => 'KT',  q => 'isLess' },
                                   { v => 9, u => 'KMH', q => 'isLess' }])
          : $vp == 9 ? (speed => [ { v =>  85, u => 'KT',  q => 'isGreater' },
                                   { v => 156, u => 'KMH', q => 'isGreater' }])
          :            (speed => [
                          { v => $vp * 10 - 5, u => 'KT', rp => 10 },
                          { v => $speed_KMH[$vp - 1],
                            u => 'KMH',
                            rp => $speed_KMH[$vp] - $speed_KMH[$vp - 1]}]
                       ) };
}

sub _check_959vpDp {
    my $r = shift;

    if (/\G959(\d)([0-8]) /ogc) {
        $r->{s} .= " 959$1$2";
        $r->{approaching} = _parse_vpDp $1, $2;
    }
    return;
}

# get temperature with tenths from rounded temperature and tenths digit
#   TT>=0, t=0..4  : TT     + t/10
#   TT>0,  t=5..9  : TT - 1 + t/10
#   TT<0,  t=0..4  : TT     - t/10
#   TT<0,  t=5..9  : TT + 1 - t/10
#   TT=0,  t=-4..-1: TT     + t/10
sub _mkTempTenths {
    my ($temp_rounded, $tenths) = @_;

    return 'invalid'
        if    $tenths < -4
           || ($tenths < 0 && $temp_rounded != 0)
           || ($tenths > 4 && $temp_rounded == 0);
    $tenths = $tenths - 10
        if $tenths >= 5;
    $tenths = -$tenths
        if $temp_rounded < 0;
    return sprintf '%.1f', $temp_rounded + $tenths / 10;
}

sub _formatQcL {
    my ($qc, $is_lat, $whole, $frac) = @_;

    return
        ($qc == 5 || ($is_lat && $qc == 3) || (!$is_lat && $qc == 7) ? '-' : '')
        . ($whole + 0)
        . '.' . $frac;
}

# get position from QcLaLaLaLaLa LoLoLoLoLoLo
sub _latLon1000 {
    my ($frac_lat, $frac_lon);

    m{\G(([1357])(\d\d)(\d)(?:(\d\d)|(\d)/|//) (\d\d\d)(\d)(?:(\d\d)|(\d)/|//)) }gc
        or return;

    $frac_lat = $4 . ($5 // '') . ($6  // '');
    $frac_lon = $8 . ($9 // '') . ($10 // '');

    if ("$3.$frac_lat" > 90 || "$7.$frac_lon" > 180) {
        pos() -= 14;
        return;
    }

    return {
        s   => $1,
        lat => { v => _formatQcL($2, 1, $3, $frac_lat),
                 q => defined $5 ? 1000 : defined $6 ? 100 : 10,
        },
        lon => { v => _formatQcL($2, 0, $7, $frac_lon),
                 q => defined $9 ? 1000 : defined $10 ? 100 : 10,
        },
    };
}

# get position from LaLaLaLaA LoLoLoLoLoB
sub _latLonDegMin {
    m{\G((\d\d)([0-5]\d)([NS]) ([01]\d\d)([0-5]\d)([EW])) }gc
        or return;

    if ("$2$3" > 9000 || "$5$6" > 18000) {
        pos() -= 13;
        return;
    }

    return {
        s   => $1,
        lat => { v => ($4 eq 'S' ? '-' : '') . sprintf('%.2f', $2 + $3 / 60),
                 q => 60,
        },
        lon => { v => ($7 eq 'W' ? '-' : '') . sprintf('%.2f', $5 + $6 / 60),
                 q => 60,
        },
    };
}

sub _msgModified {
    my $report = shift;
    my $warning;

    $warning = \(grep { $_->{warningType} eq 'msgModified' }
                      ($report->{warning} ? @{$report->{warning}} : ()));
    if ($$warning) {
        $$warning->{s} = substr $_, 0, -1;
    } else {
        unshift @{$report->{warning}}, { warningType => 'msgModified',
                                         s           => substr $_, 0, -1 }
    }
    return;
}

# since 00:00Z, 06:00Z, 12:00Z, 18:00Z
sub _timeSinceSynopticMain {
    my ($obs_hour, $obs_minute) = @_;
    my ($hour_min, $since_hour);

    if (defined $obs_hour) {
        $hour_min = $obs_hour * 60 + $obs_minute;
    } else {
        $hour_min = 0;
    }

    if ($hour_min % 360 == 0) {
        $since_hour = sprintf '%02d', $obs_hour - 6;
        $since_hour = 18 if $since_hour == -6;
    } else {
        $since_hour = sprintf '%02d', ($hour_min - ($hour_min % 360)) / 60;
    }
    return { hour => $since_hour };
}

sub _visVarCA {
    my $r;

    /\G(VSBY VRBL (\d+(?:\.\d?)?)V(\d+(?:\.\d?)?)(\+?)) /gc
        or return;

    $r = { visVar1 => { s => $1, distance => { v => $2, u => 'SM' }},
           visVar2 => {          distance => { v => $3, u => 'SM' }}
    };
    $r->{visVar2}{distance}{q} = 'isEqualGreater'
        if $4;
    $r->{visVar1}{distance}{v} =~ s/\.$//;
    $r->{visVar2}{distance}{v} =~ s/\.$//;
    return $r;
}

sub _visVarUS {
    return { visVar1 => { s => $1, distance => _parseFraction $2, 'SM' },
             visVar2 => {          distance => _parseFraction $3, 'SM' }
           }
        if m{\G($re_vis ($re_vis_sm)V($re_vis_sm)(?: ?SM)?) }ogc;
    return;
}

sub _precipCA {
    my ($obs_hour, $obs_minute) = @_;

    # MANOBS 10.2.19.9, .10, .11
    m{\G((/?)([RS])(\d\d)(?: AFT ?($re_hour)($re_min)? ?(?:Z|UTC)?)?\2) }ogc
        or return;

    return {
        ($3 eq 'S' ? 'snowFall' : 'precipitation') => {
            s            => $1,
            timeSince    =>   defined $5
                            ? { hour => $5, defined $6 ? (minute => $6) : () }
                            : _timeSinceSynopticMain($obs_hour, $obs_minute),
            precipAmount => { v => $4 + 0, u => ($3 eq 'S' ? 'CM' : 'MM') }
    }};
}

sub _parsePhenoms {
    my $r;

# nearly the same pattern twice except for the position of $re_phen_desc
# (do not match too much but don't miss anything, either)

    if (m{\G((?:PR(?:ESENT )?WX:? ?)?(DSNT )?((?:(?:AND )?(?:$re_phen_desc)[/ ]?)+)$re_phenomenon4( BBLO)?(?:$re_loc_quadr3$re_wx_mov_d3?|$re_wx_mov_d3)( BBLO)?(?: ($re_cloud_type) (?:(ASOCTD?)|(EMBDD?)))?) }ogc)
    {
        $r->{s} = $1;
        _parsePhenomDescr $r, 'phenomDescrPre', $3;
        if (defined $4) {
            _parsePhenom \$r, $4;
        } elsif (defined $5) {
            @{$r->{cloudType}} = split m{[/-]}, $5;
        } elsif (defined $6) {
            # phenomenon _can_ have intensity, but it is an EXTENSION
            $r->{weather} = _parseWeather $6, 'NI';
        } else {
            $r->{cloudCover} = $7;
        }
        _parsePhenomDescr $r, 'phenomDescrPost', $8 if defined $8;
        $r->{locationAnd} = _parseLocations $9, $2 if defined $9;
        $r->{locationAnd} = _parseQuadrants $11, ($2 || $10)
            if defined $11;
        $r->{$12}{locationAnd} = _parseLocations $13 if defined $13;
        $r->{isStationary} = undef if defined $14;
        $r->{$15}{locationAnd} = _parseLocations $16 if defined $16;
        $r->{isStationary} = undef if defined $17;
        _parsePhenomDescr $r, 'phenomDescrPost', $18 if defined $18;
        $r->{cloudTypeAsoctd} = $19 if defined $20;
        $r->{cloudTypeEmbd}   = $19 if defined $21;
        $r->{locationAnd}{locationThru}{location}{inDistance} = undef
            if defined $2 && !exists $r->{locationAnd};
        if (   exists $r->{locationAnd}
            && exists $r->{locationAnd}{obscgMtns})
        {
            delete $r->{locationAnd}{obscgMtns};
            $r->{obscgMtns} = undef;
        }
        return { phenomenon => $r };
    }

    if (m{\G((?:PR(?:ESENT )?WX:? ?)?(DSNT )?$re_phenomenon4(?: IS)?((?:[/ ](?:$re_phen_desc|BBLO))*)(?:$re_loc_quadr3$re_wx_mov_d3?|$re_wx_mov_d3)( BBLO)?(?: ($re_cloud_type) (?:(ASOCTD?)|(EMBDD?)))?) }ogc)
    {
        $r->{s} = $1;
        if (defined $3) {
            _parsePhenom \$r, $3;
        } elsif (defined $4) {
            @{$r->{cloudType}} = split m{[/-]}, $4;
        } elsif (defined $5) {
            # phenomenon _can_ have intensity, but it is an EXTENSION
            $r->{weather} = _parseWeather $5, 'NI';
        } else {
            $r->{cloudCover} = $6;
        }
        _parsePhenomDescr $r, 'phenomDescrPost', $7 if defined $7;
        $r->{locationAnd} = _parseLocations $8, $2 if defined $8;
        $r->{locationAnd} = _parseQuadrants $10, ($2 || $9)
            if defined $10;
        $r->{$11}{locationAnd} = _parseLocations $12 if defined $12;
        $r->{isStationary} = undef if defined $13;
        $r->{$14}{locationAnd} = _parseLocations $15 if defined $15;
        $r->{isStationary} = undef if defined $16;
        _parsePhenomDescr $r, 'phenomDescrPost', $17 if defined $17;
        $r->{cloudTypeAsoctd} = $18 if defined $19;
        $r->{cloudTypeEmbd}   = $18 if defined $20;
        $r->{locationAnd}{locationThru}{location}{inDistance} = undef
            if defined $2 && !exists $r->{locationAnd};
        if (   exists $r->{locationAnd}
            && exists $r->{locationAnd}{obscgMtns})
        {
            delete $r->{locationAnd}{obscgMtns};
            $r->{obscgMtns} = undef;
        }
        return { phenomenon => $r };
    }
    return;
}

sub _parseTQfcst {
    my $r;

    if (/\G(T(?: M?\d\d){1,4}) /gc) {
        $r->{temp_fcst}{s} = $1;
        for ($1 =~ /(M?\d\d)/g) {
            push @{$r->{temp_fcst}{temp_Arr}},
                                        { air => { temp => _parseTempMetaf $_ }}
        }
    }
    if (/\G(Q(?: [01]\d\d\d){1,4}) /gc) {
        $r->{QNH_fcst}{s} = $1;
        for ($1 =~ /([01]\d\d\d)/g) {
            push @{$r->{QNH_fcst}{QNH_Arr}},
                                     { pressure => { v => $_ + 0, u => 'hPa' }};
        }
    }
    return $r;
}

sub _complete_bufr {
    my $report = shift;

    if (   exists $report->{obsStationId}
        && exists $report->{obsStationId}{id}
        && !exists $report->{obsStationId}{region})
    {
        my $region;

        $region = _IIiii2region $report->{obsStationId}{id};
        $report->{obsStationId}{region} = $region
            if $region;
    }

    _setHumidity $report->{temperature}
        if    exists $report->{temperature}
           && !exists $report->{temperature}{relHumid1};
    for (@{$report->{weatherSynopAdd}}) {
        push @{$report->{section3}}, { weatherSynopAdd => {
            s => $_->{s},
            %{ _codeTable4687 $_->{weatherPresent} }
        }};
    }
    delete $report->{weatherSynopAdd};

    if (   exists $report->{stationPressure}
        && exists $report->{barometerElev})
    {
        $report->{stationPressure}{s} =   $report->{barometerElev}{s}
                                        . ' '
                                        . $report->{stationPressure}{s};
        @{$report->{stationPressure}{barometerElev}}{qw(v u)} =
                                              ($report->{barometerElev}{v}, 'M')
            if    defined $report->{barometerElev}{v}
               && exists $report->{stationPressure}{pressure};
        delete $report->{barometerElev};
    }

    if (exists $report->{isSynop}) {
        $report->{callSign}{region} = _A1bw2region $report->{callSign}{id}
            if    exists $report->{callSign}
               && !exists $report->{callSign}{region}
               && $report->{callSign}{id} =~ /^${re_A1bw}\d{3}$/o;

        for (qw(displacement seaSurfaceTemp waves windWaves swell)) {
            if (exists $report->{$_}) {
                push @{$report->{section2}}, { $_ => $report->{$_} };
                delete $report->{$_};
            }
        }

        for (@{$report->{waterTempSalDepth}}) {
            push @{$report->{section5}}, { waterTempSalDepth => $_ };
        }
        delete $report->{waterTempSalDepth};
    }

    if (exists $report->{isBuoy}) {
        $report->{buoyId}{region} = _A1bw2region $report->{buoyId}{id}
            if    exists $report->{buoyId}
               && !exists $report->{buoyId}{region}
               && $report->{buoyId}{id} =~ /^[1-7]/;

        for (qw(sfcWind temperature stationPressure SLP pressureChange)) {
            if (exists $report->{$_}) {
                push @{$report->{section1}}, { $_ => $report->{$_} };
                delete $report->{$_};
            }
        }

        for (qw(seaSurfaceTemp waves windWaves swell)) {
            if (exists $report->{$_}) {
                push @{$report->{section2}}, { $_ => $report->{$_} };
                delete $report->{$_};
            }
        }

        for (qw(salinityMeasurement waterTempSalDepth)) {
            if (exists $report->{$_}) {
                if ($_ eq 'waterTempSalDepth') {
                    for (@{$report->{waterTempSalDepth}}) {
                        push @{$report->{section3}}, { waterTempSalDepth => $_};
                    }
                } else {
                    push @{$report->{section3}}, { $_ => $report->{$_} };
                }
                delete $report->{$_};
            }
        }

        if (exists $report->{qualityGroup2}) {
            $report->{qualityGroup2}{qualityLocClass} =
                        _codeTable3302 $report->{qualityGroup2}{qualityLocClass}
                if exists $report->{qualityGroup2}{qualityLocClass};
        }

        for (qw(qualityGroup2 lastKnownPosTime buoyType drogueType
                batteryVoltage submergence cableLengthDrogue))
        {
            if (exists $report->{$_}) {
                push @{$report->{section4}}, { $_ => $report->{$_} };
                delete $report->{$_};
            }
        }
    }

    return;
}

########################################################################
# _parseBufr
########################################################################
sub _parseBufr {
    my %report;

=head2 Processing of decoded BUFR messages

The content of the BUFR message is mapped to a SYNOP, BUOY, or AMDAR data
structure, depending on the content of the message.

The message must be provided as a space delimited list of descriptor:data pairs
in the format B<FXXYYY>C<:>I<data>.
B<F> must be 0, i.e. only values are allowed.
If there are associated fields, they must be provided as a C</> (slash)
delimited list of significance:value pairs directly after the descriptor.
If a data field contains a substring which looks like a descriptor,
C</> (slash) and the length of the data field must be appended directly after
the descriptor (or the list of associated fields if it exists).
If the data is missing (undefined), a C<-> (minus) is used instead of the C<:>
(colon).

Examples:

=over

=item 000001:X

descriptor: 000001

data: X

=item 000001-

descriptor: 000001

data: (missing)

=item 000001/7:50:X

descriptor: 000001

associated significance: 7 (percentage confidence) with value 50

data: X

=item 000001/7:50/8:0/10:XE<nbsp>000002:Y

descriptor: 000001

1st associated significance: 7 (percentage confidence) with value 50

2nd associated significance: 8 (2 bits quality information) with value 0

data: XE<nbsp>000002:Y

=back

=cut

    %report = metaf2xml::bufr::_bufrstr2report();
    _complete_bufr \%report;
    return %report;
}

########################################################################
# _parseAmdar
########################################################################
sub _parseAmdar {
    my %report;

    $report{msg} = $_;
    $report{isAmdar} = undef;

    if (/^ERROR -/) {
        pos = 0;
        $report{ERROR} = _makeErrorMsgPos 'other';
        return %report;
    }

=head2 Parsing of AMDAR messages

From WMO-No. 306 Vol I.1, Part A:
AMDAR is the name of the code for an automatic meteorological report from an
aircraft.
Observations are made at specified levels, time intervals or when the highest
wind is encountered, and shall be included in individual reports.
Data transmitted from the aircraft are encoded in binary code and are
translated into the quasi-AIREP format for the convenience of human users.

=cut

    $_ .= ' '; # this makes parsing much easier

    pos = 0;

########################################################################

=head3 AMDAR Section 1

 AMDAR YYGG

=over

=item B<YYGG> (not processed)

day of the month (UTC), and actual time, rounded downwards to the nearest hour
UTC, of the first AMDAR report in the bulletin

=back

=cut

    # groups AMDAR YYGG
    if (!/\G(AMDAR) $re_day$re_hour /ogc) {
        pos() += 6;
        $report{ERROR} = _makeErrorMsgPos 'obsTime';
        return %report;
    }
    $report{obsStationType} = { s => $1, stationType => $1 };

########################################################################

=head3 AMDAR Section 2

 ipipip IA...IA LaLaLaLaA LoLoLoLoLoB YYGGgg (ShhIhIhI) SSTATATA ({SSTdTdTd|UUU}) ddd/fff (TBBA) (Ss1s2s3)

=for html <!--

=over

=item B<ipipip>

=for html --><dl><dt><strong>i<sub>p</sub>i<sub>p</sub>i<sub>p</sub></strong></dt><dd>

phase of flight indicator

=back

=cut

    # group ipipip
    if (!m{\G(LV[RW]|ASC|DES|UNS|///) }gc) {
        $report{ERROR} = _makeErrorMsgPos 'other';
        return %report;
    }
    $report{phaseOfFlight} = {
        s => $1,
        $1 eq '///' ? (notAvailable => undef)
                    : (phaseOfFlightVal =>
                     { UNS => 2, LVR => 3, LVW => 4, ASC => 5, DES => 6 }->{$1})
    };
    $report{reportModifier}{s} =
            $report{reportModifier}{modifierType} = 'LVW'
        if $1 eq 'LVW';

=for html <!--

=over

=item B<IA...IA>

=for html --><dl><dt><strong>I<sub>A</sub>...I<sub>A</sub></strong></dt><dd>

aircraft identifier

=back

=cut

    # group IA...IA
    if (!/\G([A-Z]{2}[A-Z0-9]{2,6}) /gc) {
        $report{ERROR} = _makeErrorMsgPos 'other';
        return %report;
    }
    $report{aircraftId} = { s => $1, id => $1 };

=for html <!--

=over

=item B<LaLaLaLaA LoLoLoLoLoB>

=for html --><dl><dt><strong>L<sub>a</sub>L<sub>a</sub>L<sub>a</sub>L<sub>a</sub>A L<sub>o</sub>L<sub>o</sub>L<sub>o</sub>L<sub>o</sub>L<sub>o</sub>B</strong></dt><dd>

geographical location

=back

=cut

    # group LaLaLaLaA LoLoLoLoLoB
    {
        my $r;

        $r = _latLonDegMin;
        if (!defined $r) {
            $report{ERROR} = _makeErrorMsgPos 'stationPosition';
            return %report;
        }
        $report{aircraftLocation} = $r;
    }

=over

=item B<YYGGgg>

day, hour, minute of measurement

=back

=cut

    if (!/\G($re_day)($re_hour)($re_min) /ogc) {
        $report{ERROR} = _makeErrorMsgPos 'obsTime';
        return %report;
    }
    $report{obsTime} = {
        s      => "$1$2$3",
        timeAt => { day => $1, hour => $2, minute => $3 }
    };

=for html <!--

=over

=item optional: B<ShhIhIhI>

=for html --><dl><dt>optional: <strong>S<sub>h</sub>h<sub>I</sub>h<sub>I</sub>h<sub>I</sub></strong></dt><dd>

pressure altitude, in hundreds of feet, relative to the standard datum plane of
1013.2 hPa

=back

=cut

    # group ShhIhIhI
    if (/\G(([AF])(\d{3})) /gc) {
        push @{$report{amdarObs}{sortedArr}}, { pressureAlt => {
            s        => $1,
            altitude => {
                v => ($2 eq 'A' ? '-' : '') . ($3 * 100),
                u => 'FT'
        }}};
    } elsif (m{\G(////) }gc) {
        push @{$report{warning}}, { warningType => 'notProcessed', s => $1 };
    }

=for html <!--

=over

=item B<SSTATATA>

=for html --><dl><dt><strong>SST<sub>A</sub>T<sub>A</sub>T<sub>A</sub></strong></dt><dd>

air temperature, in tenths of degrees Celsius

=back

=for html <!--

=over

=item optional: B<SSTdTdTd> | B<UUU>

=for html --><dl><dt>optional: <strong>SST<sub>d</sub>T<sub>d</sub>T<sub>d</sub></strong> | <strong>UUU</strong></dt><dd>

dewpoint temperature, in tenths of degrees Celsius, or relative humidity

=back

=cut

    # groups SSTATATA (SSTdTdTd|UUU)
    if (!/\G(([PM])S(\d\d)(\d)) /gc) {
        $report{ERROR} = _makeErrorMsgPos 'other';
        return %report;
    }

    {
        my $r;

        $r = {
            s   => $1,
            air => { temp => { v => ($2 eq 'M' ? '-' : '') . ($3 + 0) . ".$4",
                               u => 'C'
        }}};

        if (/\G(([PM])S(\d\d)(\d)|(100|0\d\d)) /gc) {
            $r->{s} .= " $1";
            if (defined $2) {
                $r->{dewpoint} = {
                     temp => { v => ($2 eq 'M' ? '-' : '') . ($3 + 0) . ".$4",
                               u => 'C'
                }};
                _setHumidity $r;
            } else {
                $r->{relHumid1} = $5 + 0;
            }
        }
        push @{$report{amdarObs}{sortedArr}}, { temperature => $r };
    }

=over

=item B<dddC</>fff>

true direction, in whole degrees, from which wind is blowing, and
wind speed, in knots

=back

=cut

    # group ddd/fff
    if (!m{\G((?:($re_wind_dir3)|\d{3})/(\d{3})) }ogc) {
        $report{ERROR} = _makeErrorMsgPos 'other';
        return %report;
    }
    push @{$report{amdarObs}{sortedArr}}, { windAtPA => {
        s    => $1,
        defined $2
            ? (wind => { dir => $2 + 0, speed => { v => $3 + 0, u =>'KT' }})
            : (wind => { invalidFormat => $1 }),
    }};

=for html <!--

=over

=item optional: B<C<TB>BA>

=for html --><dl><dt>optional: <strong><code>TB</code>B<sub>A</sub></strong></dt><dd>

turbulence

=back

=cut

    # group TBBA
    if (m{\GTB([0-3/]) }gc) {
        push @{$report{amdarObs}{sortedArr}}, { turbulenceAtPA => {
            s => "TB$1",
            $1 eq '/' ? (notAvailable => undef)
                      : (turbulenceDescr => qw(0 1 MOD SEV)[$1]),
        }};
    }

=for html <!--

=over

=item optional: B<C<S>s1s2s3>

=for html --><dl><dt>optional: <strong><code>S</code>s<sub>1</sub>s<sub>2</sub>s<sub>3</sub></strong></dt><dd>

type of navigation system, type of system used, and temperature precision

=back

=cut

    # group Ss1s2s3
    # s1, s2, s3: WMO-No. 306 Vol I.1, Part A, code table 3866, 3867, 3868
    if (m{\G(S([01/])([0-5/])([01/])) }gc) {
        $report{amdarInfo} = {
            s         => $1,
            "$2$3$4" eq '///'
                ? (notAvailable => undef)
                : (sortedArr => [
                      $2 eq '/' ? () : { navSystem     => $2 },
                      $3 eq '/' ? () : { amdarSystem   => $3 },
                      # WMO-No. 306 Vol I.1, Part A, code table 3868
                      $4 eq '/' ? () : { tempPrecision => 2 - $4 },
                  ]),
        };
    }

########################################################################

=head3 AMDAR Section 3 (optional)

 333 Fhdhdhd VGfgfgfg

=cut

    if (/\G333 /gc) {
        my @s3;

        @s3  = ();
        $report{section3} = \@s3;

=for html <!--

=over

=item B<C<F>hdhdhd>

=for html --><dl><dt><strong><code>F</code>h<sub>d</sub>h<sub>d</sub>h<sub>d</sub></strong></dt><dd>

flight level (based on ICAO standard atmosphere for reports above 700 hPa, on
airport QNH otherwise)

=back

=cut

        # group Fhdhdhd
        if (!m{\G(F(?:(\d{3})|///)) }gc) {
            $report{ERROR} = _makeErrorMsgPos 'other';
            return %report;
        }
        push @s3, { flightLvl => {
            s => $1,
            defined $2 ? (level => $2 + 0) : (notAvailable => undef)
        }};

=for html <!--

=over

=item B<C<VG>fgfgfg>

=for html --><dl><dt><strong><code>VG</code>f<sub>g</sub>f<sub>g</sub>f<sub>g</sub></strong></dt><dd>

maximum derived equivalent vertical gust, in tenths of a metre per second

=back

=cut

        # group VGfgfgfg
        if (!m{\G(VG(\d{3}|///)) }gc) {
            $report{ERROR} = _makeErrorMsgPos 'other';
            return %report;
        }
        push @s3, { maxDerivedVerticalGust => {
            s    => $1,
            wind => { $2 eq '///'
                ? (notAvailable => undef)
                : (speed => { v => sprintf('%.1f', $2 / 10), u => 'MPS' }),
        }}};
    }

    push @{$report{warning}}, { warningType => 'notProcessed',
                                s           => substr $_, pos, -1 }
        if length != pos;

    return %report;
}

########################################################################
# _parseBuoy
########################################################################
sub _parseBuoy {
    my (%report, $windUnit, $winds_est, $country, $region);

    $report{msg} = $_;
    $report{isBuoy} = undef;
    _cySet 'XXXX';

    if (/^ERROR -/) {
        pos = 0;
        $report{ERROR} = _makeErrorMsgPos 'other';
        return %report;
    }

=head2 Parsing of BUOY messages

=cut

    # EXTENSION: preprocessing
    # remove trailing =
    s/ ?=$//;

    $_ .= ' '; # this makes parsing much easier

    pos = 0;

    # warn about modification
    push @{$report{warning}}, { warningType => 'msgModified',
                                s           => substr $_, 0, -1 }
        if $report{msg} . ' ' ne $_;

########################################################################

=head3 BUOY Section 0: information about the identification, time and position data

 MiMiMjMj A1bwnbnbnb YYMMJ GGggiw QcLaLaLaLaLa LoLoLoLoLoLo (6QlQtQA/)

=for html <!--

=over

=item B<MiMiMjMj>

=for html --><dl><dt><strong>M<sub>i</sub>M<sub>i</sub>M<sub>j</sub>M<sub>j</sub></strong></dt><dd>

station type

=back

=cut

    # group MiMiMjMj
    if (!/\G(ZZYY) /gc) {
        $report{ERROR} = _makeErrorMsgPos 'obsStationType';
        return %report;
    }
    $report{obsStationType} = { s => $1, stationType => $1 };

    $region = '';
    $country = '';

=for html <!--

=over

=item B<A1bwnbnbnb>

=for html --><dl><dt><strong>A<sub>1</sub>b<sub>w</sub>n<sub>b</sub>n<sub>b</sub>n<sub>b</sub></strong></dt><dd>

station id

=back

=cut

    # group A1bwnbnbnb
    # A1bw: maritime zone, nnn: 001..499, 500 added if drifting buoy
    if (/\G(${re_A1bw}\d{3}) /ogc) {
        $country = _A1bw2country $1;
        $region  = _A1bw2region $1;
        $report{buoyId} = { s => $1, id => $1, region => $region };
    } else {
        $report{ERROR} = _makeErrorMsgPos 'buoyId';
        return %report;
    }

=for html <!--

=over

=item B<YYMMJ GGggiw>

=for html --><dl><dt><strong>YYMMJ GGggi<sub>w</sub></strong></dt><dd>

day, month, units digit of year, hour, minute of observation, indicator for wind speed (unit)

=back

=cut

    # groups YYMMJ GGggiw
    if (!m{\G($re_day)(0[1-9]|1[0-2])(\d) ($re_hour)($re_min)([0134/]) }ogc) {
        $report{ERROR} = _makeErrorMsgPos 'obsTimeWindInd';
        return %report;
    }
    $report{obsTime} = {
        s      => "$1$2$3 $4$5",
        timeAt => { day => $1, month => $2, yearUnitsDigit => $3,
                    hour => $4, minute => $5 }
    };

    # WMO-No. 306 Vol I.1, Part A, code table 1855:
    $report{windIndicator}{s} = $6;
    if ($6 ne '/') {
        $windUnit = $6 < 2 ? 'MPS' : 'KT';
        $winds_est = $6 == 0 || $6 == 3;
        $report{windIndicator}{windUnit} = $windUnit;
        $report{windIndicator}{isEstimated} = undef if $winds_est;
    } else {
        $report{windIndicator}{notAvailable} = undef;
    }

=for html <!--

=over

=item B<QcLaLaLaLaLa LoLoLoLoLoLo>

=for html --><dl><dt><strong>Q<sub>c</sub>L<sub>a</sub>L<sub>a</sub>L<sub>a</sub>L<sub>a</sub>L<sub>a</sub> L<sub>o</sub>L<sub>o</sub>L<sub>o</sub>L<sub>o</sub>L<sub>o</sub></strong></dt><dd>

position of the buoy

=back

=cut

    # group QcLaLaLaLaLa LoLoLoLoLoLo
    if (m{\G(////// //////) }gc) {
        $report{stationPosition} = { s => $1, notAvailable => undef };
    } else {
        my $r;

        $r = _latLon1000;
        if (!defined $r) {
            $report{ERROR} = _makeErrorMsgPos 'stationPosition';
            return %report;
        }
        $report{stationPosition} = $r;
    }

=for html <!--

=over

=item B<C<6>QlQtQAC</>>

=for html --><dl><dt><strong><code>6</code>Q<sub>l</sub>Q<sub>t</sub>Q<sub>A</sub><code>/</code></strong></dt><dd>

quality control indicators for position and time

=back

=cut

    # group 6QlQtQA/
    if (m{\G6([\d/])([\d/])([\d/])/ }gc) {
        $report{qualityPositionTime} = {
            s => "6$1$2$3/",
            # WMO-No. 306 Vol I.1, Part A, code table 3334:
            qualityControlPosition => {
                $1 eq '/' ? (notAvailable => undef)
              : $1 > 5    ? (invalidFormat => $1)
              :             (qualityControlInd => $1)
            },
            # WMO-No. 306 Vol I.1, Part A, code table 3334:
            qualityControlTime => {
                $2 eq '/' ? (notAvailable => undef)
              : $2 > 5    ? (invalidFormat => $2)
              :             (qualityControlInd => $2)
            },
            qualityLocClass => _codeTable3302 $3
        };
    }

########################################################################

=head3 BUOY Section 1: meteorological and other non-marine data (optional)

 111QdQx 0ddff 1snTTT {2snTdTdTd|29UUU} 3P0P0P0P0 4PPPP 5appp

=for html <!--

=over

=item B<C<111>QdQx>

=for html --><dl><dt><strong><code>111</code>Q<sub>d</sub>Q<sub>x</sub></strong></dt><dd>

quality control indicators for section 1

=back

=cut

    # group 111QdQx
    if (m{\G111(//|([01])9|([2-5])([1-69])|([\d/][\d/])) }gc) {
        my (@s1, %temp);

        @s1  = ();
        $report{section1} = \@s1;

        # WMO-No. 306 Vol I.1, Part A, Section A, 18.3.3,
        # WMO-No. 306 Vol I.1, Part A, code table 3334:
        push @s1, { qualitySection => {
            s => $1,
              defined $2 ? (qualityControlInd => $2)
            : defined $3 ? (qualityControlInd => $3,
                            $4 != 9 ? (worstQualityGroup => $4) : ())
            : defined $5 ? (invalidFormat => $5)
            :              (notAvailable => undef)
        }};

=over

=item B<C<0>ddff>

wind direction and speed

=back

=cut

        # group 0ddff
        if (m{\G0($re_dd|00|99|//)(\d\d|//) }ogc) {
            my $r;

            $r->{s} = "0$1$2";
            if ("$1$2" eq '////') {
                $r->{wind}{notAvailable} = undef;
            # WMO-No. 306 Vol I.1, Part A, code table 0877:
            } elsif ($1 eq '00') {
                $r->{wind}{isCalm} = undef;
                $r->{wind}{isEstimated} = undef if $winds_est;
            } else {
                if ($1 eq '//') {
                    $r->{wind}{dirNotAvailable} = undef;
                } elsif ($1 eq '99') {
                    $r->{wind}{dirVarAllUnk} = undef;
                } else {
                    if ($winds_est) {
                        $r->{wind}{isEstimated} = undef;
                    } else {
                        $r->{wind}{dir} = { rp => 4, rn => 5 };
                    }
                    $r->{wind}{dir}{v} = $1 * 10;
                }
                if ($2 eq '//' || !$windUnit) {
                    $r->{wind}{speedNotAvailable} = undef;
                } else {
                    $r->{wind}{speed} = { v => $2 + 0, u => $windUnit };
                    $r->{wind}{isEstimated} = undef if $winds_est;
                }
            }
            push @s1, { sfcWind => $r };
        }

=for html <!--

=over

=item B<C<1>snTTT>

=for html --><dl><dt><strong><code>1</code>s<sub>n</sub>TTT</strong></dt><dd>

temperature

=back

=cut

        # group 1snTTT
        if (m{\G(1(?:[01/]///|([01]\d\d[\d/]))) }gc) {
            %temp = (s   => $1,
                     air => defined $2 ? { temp => _parseTemp $2 }
                                       : { notAvailable => undef }
            );
        }

=for html <!--

=over

=item B<C<2>snTdTdTd> | B<C<29>UUU>

=for html --><dl><dt><strong><code>2</code>s<sub>n</sub>T<sub>d</sub>T<sub>d</sub>T<sub>d</sub></strong> | <strong><code>29</code>UUU</strong></dt><dd>

dew point or relative humidity

=back

=cut

        # group 2snTdTdTd|29UUU
        if (m{\G(2(?:[109/]///|([01]\d\d[\d/])|9(100|0\d\d))) }gc) {
            if (exists $temp{s}) {
                $temp{s} .= ' ';
            } else {
                $temp{s} = '';
            }
            $temp{s} .= $1;
            if (defined $2) {
                $temp{dewpoint}{temp} = _parseTemp $2;
                _setHumidity \%temp;
            } elsif (defined $3) {
                $temp{relHumid1} = $3 + 0;
            } else {
                $temp{dewpoint}{notAvailable} = undef;
            }
        }

        push @s1, { temperature => \%temp } if exists $temp{s};

=for html <!--

=over

=item B<C<3>P0P0P0P0>

=for html --><dl><dt><strong><code>3</code>P<sub>0</sub>P<sub>0</sub>P<sub>0</sub>P<sub>0</sub></strong></dt><dd>

station level pressure

=back

=cut

        # group 3P0P0P0P0
        # don't confuse with start of section 3
        if (!/\G333/ && m{\G(3(?:(\d{4})|[\d/]///)) }gc) {
            push @s1, { stationPressure => {
                s => $1,
                defined $2
                    ? (pressure => {
                        v => sprintf('%.1f', $2 / 10 + ($2 < 5000 ? 1000 : 0)),
                        u => 'hPa'
                      })
                    : (notAvailable => undef)
            }};
        }

=over

=item B<C<4>PPPP>

sea level pressure

=back

=cut

        # group 4PPPP
        if (m{\G(4[09/]///) }gc) {
            push @s1, { SLP => { s => $1, notAvailable => undef }};
        } elsif (m{\G(4([09]\d\d)([\d/])) }gc) {
            my $hPa;

            $hPa = $2;
            $hPa += 1000 if $2 < 500;
            $hPa .= ".$3" unless $3 eq '/';
            push @s1, {
                SLP => { s => $1, pressure => { v => $hPa, u => 'hPa' }}
            };
        } elsif (m{\G(4[\d/]{4}) }gc) {
            push @s1, { SLP => { s => $1, invalidFormat => $1 }};
        }

=over

=item B<C<5>appp>

three-hourly pressure tendency (for station level pressure if provided)

=back

=cut

        # group 5appp
        if (/\G(5([0-8])(\d{3})) /gc) {
            push @s1, { pressureChange => {
                s                 => $1,
                timeBeforeObs     => { hours => 3 },
                pressureTendency  => $2,
                pressureChangeVal => {
                    v => sprintf('%.1f', $3 / ($2 >= 5 ? -10 : 10) + 0),
                    u => 'hPa'
            }}};
        } elsif (m{\G(5////) }gc) {
            push @s1, { pressureChange => {
                s             => $1,
                timeBeforeObs => { hours => 3 },
                notAvailable  => undef
            }};
        } elsif (m{\G(5[\d/]{4}) }gc) {
            push @s1, { pressureChange => {
                s             => $1,
                timeBeforeObs => { hours => 3 },
                invalidFormat => $1
            }};
        }
    }

########################################################################

=head3 BUOY Section 2: surface marine data (optional)

 222QdQx 0snTwTwTw 1PwaPwaHwaHwa 20PwaPwaPwa 21HwaHwaHwa

=for html <!--

=over

=item B<C<222>QdQx>

=for html --><dl><dt><strong><code>222</code>Q<sub>d</sub>Q<sub>x</sub></strong></dt><dd>

quality control indicators for section 2

=back

=cut

    # group 222QdQx
    if (m{\G222(//|([01])9|([2-5])([1-49])|([\d/][\d/])) }gc) {
        my (@s2, $waves);

        @s2  = ();
        $report{section2} = \@s2;

        # WMO-No. 306 Vol I.1, Part A, Section A, 18.4.3,
        # WMO-No. 306 Vol I.1, Part A, code table 3334:
        push @s2, { qualitySection => {
            s => $1,
              defined $2 ? (qualityControlInd => $2)
            : defined $3 ? (qualityControlInd => $3,
                            $4 != 9 ? (worstQualityGroup => $4) : ())
            : defined $5 ? (invalidFormat => $5)
            :              (notAvailable => undef)
        }};

=for html <!--

=over

=item B<C<0>snTwTwTw>

=for html --><dl><dt><strong><code>0</code>s<sub>n</sub>T<sub>w</sub>T<sub>w</sub>T<sub>w</sub></strong></dt><dd>

sea-surface temperature

=back

=cut

        # group 0snTwTwTw
        if (m{\G(0(?:([01]\d{3})|[01/]///)) }gc) {
            push @s2, { seaSurfaceTemp => {
                s => $1,
                defined $2 ? (temp => _parseTemp $2) : (notAvailable => undef)
            }};
        }

=for html <!--

=over

=item B<C<1>PwaPwaHwaHwa>

=for html --><dl><dt><strong><code>1</code>P<sub>wa</sub>P<sub>wa</sub>H<sub>wa</sub>H<sub>wa</sub></strong></dt><dd>

period and height of waves (instrumental data)

=back

=cut

        # group 1PwaPwaHwaHwa
        if (m{\G(1(?://|(\d\d))(?://|(\d\d))) }gc) {
            push @s2, { waves => {
                s => $1,
                  $1 eq '1////' ? (notAvailable => undef)
                : $1 eq '10000' ? (noWaves => undef)
                :                 (defined $2 ? (wavePeriod => $2 + 0) : (),
                                   defined $3 ? (height => _waveHeight $3) : ())
            }};
            $waves = $s2[$#s2]{waves};
        }

=for html <!--

=over

=item B<C<20>PwaPwaPwa C<21>HwaHwaHwa>

=for html --><dl><dt><strong><code>20</code>P<sub>wa</sub>P<sub>wa</sub>P<sub>wa</sub> <code>21</code>H<sub>wa</sub>H<sub>wa</sub>H<sub>wa</sub></strong></dt><dd>

period and height of waves (instrumental data) with tenths

=back

=cut

        # groups 20PwaPwaPwa 21HwaHwaHwa
        if (m{\G(20(?:///|(\d\d\d)) 21(?:///|(\d\d\d))) }gc) {
            if (defined $waves) {
                $waves->{s} .= " $1";
                if (defined $2) {
                    delete $waves->{notAvailable};
                    if ($2 > 0 || exists $waves->{wavePeriod}) {
                        if (exists $waves->{noWaves}) {
                            delete $waves->{noWaves};
                            $waves->{height} = { v => 0.0, u => 'M' };
                        }
                        $waves->{wavePeriod} = sprintf '%.1f', $2 / 10;
                    }
                }
                if (defined $3) {
                    delete $waves->{notAvailable};
                    if ($3 > 0 || exists $waves->{height}) {
                        if (exists $waves->{noWaves}) {
                            delete $waves->{noWaves};
                            $waves->{wavePeriod} = 0;
                        }
                        $waves->{height}
                                  = { v => sprintf('%.1f', $3 / 10), u => 'M' };
                    }
                }
            } else {
                push @{$report{warning}},
                                     { warningType => 'notProcessed', s => $1 };
            }
        }
    }

########################################################################

=head3 BUOY Section 3: temperatures, salinity and current at selected depths (optional)

 333Qd1Qd2 (8887k2  2z0z0z0z0 3T0T0T0T0 4S0S0S0S0
                    ...
                    2znznznzn 3TnTnTnTn 4SnSnSnSn)
           (66k69k3 2z0z0z0z0 d0d0c0c0c0
                    ...
                    2znznznzn dndncncncn)

=for html <!--

=over

=item B<C<333>Qd1Qd2>

=for html --><dl><dt><strong><code>333</code>Q<sub>d1</sub>Q<sub>d2</sub></strong></dt><dd>

quality of the temperature and salinity profile, quality of the current speed
and direction profile

=back

=cut

    # group 333Qd1Qd2
    if (m{\G333(([0-5])|[\d/])(([0-5])|[\d/]) }gc) {
        my @s3;

        @s3  = ();
        $report{section3} = \@s3;

        # WMO-No. 306 Vol I.1, Part A, Section A, 18.5.3,
        # WMO-No. 306 Vol I.1, Part A, code table 3334:
        push @s3, { qualityTempSalProfile => {
            s => $1,
              defined $2 ? (qualityControlInd => $2)
            : $1 eq '/'  ? (notAvailable => undef)
            :              (invalidFormat => $1)
        }};
        push @s3, { qualityCurrentProfile => {
            s => $3,
              defined $4 ? (qualityControlInd => $4)
            : $3 eq '/'  ? (notAvailable => undef)
            :              (invalidFormat => $3)
        }};

=for html <!--

=over

=item B<C<8887>k2 C<2>z0z0z0z0 C<3>T0T0T0T0 C<4>S0S0S0S0> ...

=for html --><dl><dt><strong><code>8887</code>k<sub>2</sub> <code>2</code>z<sub>0</sub>z<sub>0</sub>z<sub>0</sub>z<sub>0</sub> <code>3</code>T<sub>0</sub>T<sub>0</sub>T<sub>0</sub>T<sub>0</sub> <code>4</code>S<sub>0</sub>S<sub>0</sub>S<sub>0</sub>S<sub>0</sub></strong> ...</dt><dd>

method of salinity measurement, selected depth, temperature, salinity

=back

=cut

        # groups 8887k2 2z0z0z0z0 3T0T0T0T0 4S0S0S0S0 ...
        if (m{\G8887(/|([0-3])|\d) }gc) {
            push @s3, { salinityMeasurement => {
                s => "8887$1",
                  defined $2 ? (salinityMeasurementInd => $2)
                : $1 eq '/'  ? (notAvailable => undef)
                :              (invalidFormat => $1)
            }};

            while (m{\G2((\d{4})(?: 3(\d\d)(\d)([\d/])| 3////)?(?: 4(\d)(\d{3})| 4////)?) }gc)
            {
                my $temp;

                if (defined $3) {
                    $temp = ($3 > 50 ? $3 : -$3 + 50) . ".$4";
                    $temp .= $5 unless $5 eq '/';
                }
                push @s3, { waterTempSalDepth => {
                    s => $1,
                    depth => { v => $2 + 0, u => 'M' },
                    defined $temp ? (temp => { v => $temp, u => 'C' }) : (),
                    defined $6 ? (salinity => "$6.$7") : ()
                }};
            }
        }

=for html <!--

=over

=item B<C<66>k6C<9>k3 C<2>z0z0z0z0 d0d0c0c0c0> ...

=for html --><dl><dt><strong><code>66</code>k<sub>6</sub><code>9</code>k<sub>3</sub> <code>2</code>z<sub>0</sub>z<sub>0</sub>z<sub>0</sub>z<sub>0</sub> c<sub>0</sub>c<sub>0</sub>d<sub>0</sub>d<sub>0</sub>d<sub>0</sub></strong> ...</dt><dd>

method of removing the velocity and motion of the buoy from current measurement,
duration and time of current measurement, selected depth, direction and speed of
the current

=back

=cut

        # groups 66k69k3 2z0z0z0z0 d0d0c0c0c0 ...
        # WMO-No. 306 Vol I.1, Part A, code tables:
        #   k6: 2267. k3: 2264
        if (m{\G66(/|([0-6])|\d)9(/|([1-9])|\d) }gc) {
            push @s3, { measurementCorrection => {
                s => "66$1",
                  defined $2 ? (measurementCorrectionInd => $2)
                : $1 eq '/'  ? (notAvailable => undef)
                :              (invalidFormat => $1)
            }};
            push @s3, { measurementDurTime => {
                s => "9$3",
                  defined $4 ? (measurementDurTimeInd => $4)
                : $3 eq '/'  ? (notAvailable => undef)
                :              (invalidFormat => $3)
            }};

            # WMO-No. 306 Vol I.1, Part A, code tables:
            #   d0d0: 0877
            while (m{\G(2(\d{4}) (?://///|($re_dd|00|99)(?:///|(\d\d\d)))) }ogc)
            {
                push @s3, { waterCurrent => {
                    s     => $1,
                    depth => { v => $2 + 0, u => 'M' },
                      !defined $3 ? ()
                    : (current => {
                         $3 eq '00' ? (invalidFormat => $3)
                       : ($3 eq '99' ? (dirVarAllUnk => undef)
                                     : (dir => { v => $3 * 10, rp=>4, rn=>5 }),
                          defined $4 ? (speed => { v => $4 + 0, u => 'CMSEC' })
                                     : (speedNotAvailable => undef))
                    })
                }};
            }
        }
    }

    # skip groups until next section
    push @{$report{warning}}, { warningType => 'notProcessed', s => $1 }
        if /\G(?:(.*?) )??(?=444 )/gc && defined $1;

########################################################################

=head3 BUOY Section 4: information on engineering and technical parameters (optional)

 444 1QPQ2QTWQ4 2QNQLQAQz {QcLaLaLaLaLa LoLoLoLoLoLo|YYMMJ GGgg/} (3ZhZhZhZh 4ZcZcZcZc) 5BtBtXtXt 6AhAhAhAN 7VBVBdBdB 8ViViViVi 9/ZdZdZd

=cut

    if (/\G444 /gc) {
        my (@s4, $QL);

        @s4  = ();
        $report{section4} = \@s4;

=for html <!--

=over

=item B<C<1>QPQ2QTWQ4>

=for html --><dl><dt><strong><code>1</code>Q<sub>P</sub>Q<sub>2</sub>Q<sub>TW</sub>Q<sub>4</sub></strong></dt><dd>

quality of: pressure measurement, houskeeping parameter, measurement of
water-surface temperature, measurement of air temperature

=back

=cut

        # group 1QPQ2QTWQ4
        # WMO-No. 306 Vol I.1, Part A, code tables:
        #   QP: 3315. QTW: 3319. Q2, Q4: 3363
        if (m{\G(1([01])([01])([01])([01])) }gc) {
            push @s4, { qualityGroup1 => {
                s => $1,
                "$2$3$4$5" eq '0000' ? (invalidFormat => $1)
                                     : (qualityPressure     => $2,
                                        qualityHousekeeping => $3,
                                        qualityWaterTemp    => $4,
                                        qualityAirTemp      => $5)
            }};
        }

=for html <!--

=over

=item B<C<2>QNQLQAQz>

=for html --><dl><dt><strong><code>2</code>Q<sub>N</sub>Q<sub>L</sub>Q<sub>A</sub>Q<sub>z</sub></strong></dt><dd>

quality of buoy satellite transmission, quality of location, location quality
class, indicator of depth correction

=back

=cut

        # group 2QNQLQAQz
        # WMO-No. 306 Vol I.1, Part A, code tables:
        #   QN: 3313. QL: 3311. QA: 3302. Qz: 3318
        if (m{\G(2([01])([0-2])([\d/])([01/])) }gc) {
            push @s4, { qualityGroup2 => {
                s                   => $1,
                qualityTransmission => $2,
                qualityLocation     => $3,
                qualityLocClass     => _codeTable3302($4),
                $5 eq '/' ? () : (depthCorrectionInd => $5)
            }};
            $QL = $3;
        }

=for html <!--

=over

=item B<QcLaLaLaLaLa LoLoLoLoLoLo>

=for html --><dl><dt><strong>Q<sub>c</sub>L<sub>a</sub>L<sub>a</sub>L<sub>a</sub>L<sub>a</sub>L<sub>a</sub> L<sub>o</sub>L<sub>o</sub>L<sub>o</sub>L<sub>o</sub>L<sub>o</sub></strong></dt><dd>

second possible solution for the position of the buoy

=back

=cut

        if (defined $QL && $QL == 2) {
            # groups QcLaLaLaLaLa LoLoLoLoLoLo
            my $r;

            $r = _latLon1000;
            if (!defined $r) {
                $report{ERROR} = _makeErrorMsgPos 'stationPosition';
                return %report;
            }
            push @s4, { stationPosition => $r };
        }

=over

=item B<YYMMJ GGggC</>>

day, month, units digit of year, hour, minute of the time of the last known
position

=back

=cut

        if (defined $QL && $QL == 1) {
            # groups YYMMJ GGgg/
            if (!m{\G($re_day)(0[1-9]|1[0-2])(\d) ($re_hour)($re_min)/ }ogc) {
                $report{ERROR} = _makeErrorMsgPos 'obsTime';
                return %report;
            }
            push @s4, { lastKnownPosTime => {
                s      => "$1$2$3 $4$5/",
                timeAt => { day => $1, month => $2, yearUnitsDigit => $3,
                            hour => $4, minute => $5 }
            }};
        }

=for html <!--

=over

=item B<C<3>ZhZhZhZh C<4>ZcZcZcZc>

=for html --><dl><dt><strong><code>3</code>Z<sub>h</sub>Z<sub>h</sub>Z<sub>h</sub>Z<sub>h</sub> <code>4</code>Z<sub>c</sub>Z<sub>c</sub>Z<sub>c</sub>Z<sub>c</sub></strong></dt><dd>

hydrostatic pressure of lower end of cable, length of cable in metres
(thermistor strings)

=back

=cut

        # groups 3ZhZhZhZh 4ZcZcZcZc
        if (m{\G3(\d{4}) 4(\d{4}) }gc) {
            push @s4, { pressureCableEnd => {
                s        => "3$1",
                pressure => { v => $1 + 0, u => 'kPa' }
            }};
            push @s4, { cableLengthThermistor => {
                s      => "4$2",
                length => { v => $2 + 0, u => 'M' }
            }};
        }

=for html <!--

=over

=item B<C<5>BtBtXtXt>

=for html --><dl><dt><strong><code>5</code>B<sub>t</sub>B<sub>t</sub>X<sub>t</sub>X<sub>t</sub></strong></dt><dd>

type of buoy, type of drogue

=back

=cut

        # group 5BtBtXtXt
        # WMO-No. 306 Vol I.1, Part A, code tables:
        #   BtBt: 0370. XtXt: 4780
        if (m{\G5(//|(0[0-689]|[12]\d|3[04-9])|[\d/]{2})(//|(0[1-5])|[\d/]{2}) }gc)
        {
            push @s4, { buoyType => {
                s => "5$1",
                  defined $2 ? (buoyTypeInd => $2 + 0)
                : $1 eq '//' ? (notAvailable => undef)
                :              (invalidFormat => $1)
            }};
            push @s4, { drogueType => {
                s => $3,
                  defined $4 ? (drogueTypeInd => $4 + 0)
                : $3 eq '//' ? (notAvailable => undef)
                :              (invalidFormat => $3)
            }};
        }

=for html <!--

=over

=item B<C<6>AhAhAhAN>

=for html --><dl><dt><strong><code>6</code>A<sub>h</sub>A<sub>h</sub>A<sub>h</sub>A<sub>N</sub></strong></dt><dd>

anemometer height, type of anemometer

=back

=cut

        # group 6AhAhAhAN
        # WMO-No. 306 Vol I.1, Part A, code tables 0114
        if (m{\G(6(\d{3})(/|([0-2])|\d)) }gc) {
            push @s4, { anemometer => {
                s              => $1,
                sensorHeight   => { v => $2 + 0, u => 'DM' },
                anemometerType => {
                      defined $4 ? (anemometerTypeInd => $4)
                    : $3 eq '/'  ? (notAvailable => undef)
                    :              (invalidFormat => $3)
                }
            }};
        }

=for html <!--

=over

=item B<C<7>VBVBdBdB>

=for html --><dl><dt><strong><code>7</code>V<sub>B</sub>V<sub>B</sub>d<sub>B</sub>d<sub>B</sub></strong></dt><dd>

drifting speed and drift direction of the buoy at the last known position

=back

=cut

        if (defined $QL && $QL == 1) {
            # group 7VBVBdBdB
            if (m{\G(7(\d\d)($re_dd|99)) }gc) {
                push @s4, { buoyDrift => {
                    s     => $1,
                    drift => {   $3 eq '99'
                               ? (dirVarAllUnk => undef)
                               : (dir => { v => $3 * 10, rp => 4, rn => 5 }),
                               speed => { v => $2 + 0, u => 'CMSEC' }
                }}};
            }
        }

=for html <!--

=over

=item B<C<8>ViViViVi> ...

=for html --><dl><dt><strong><code>8</code>V<sub>i</sub>V<sub>i</sub>V<sub>i</sub>V<sub>i</sub></strong></dt><dd>

engineering status of the buoy

=back

=cut

        # groups 8ViViViVi ...
        if (m{\G8(////|\d{4})(?: 8(////|\d{4}))? }gc) {
            push @s4, { batteryVoltage => {
                s => "8$1",
                $1 eq '////' ? (notAvailable => undef)
                             : (batteryVoltageVal => sprintf '%.1f', $1 / 10)
            }};
            if ($2) {
                push @s4, { submergence => {
                    s => "8$2",
                    $2 eq '////' ? (notAvailable => undef)
                                 : (submergenceVal => $2 + 0)
                }};
            }
        }

=for html <!--

=over

=item B<C<9/>ZdZdZd> ...

=for html --><dl><dt><strong><code>9/</code>Z<sub>d</sub>Z<sub>d</sub>Z<sub>d</sub></strong></dt><dd>

length of the cable at which the drogue is attached

=back

=cut

        # group 9/ZdZdZd
        if (m{\G9/(///|\d{3}) }gc) {
            push @s4, { cableLengthDrogue => {
                s => "9/$1",
                $1 eq '///' ? (notAvailable => undef)
                            : (length => { v => $1 + 0, u => 'M' })
            }};
        }
    }

    push @{$report{warning}}, { warningType => 'notProcessed',
                                s           => substr $_, pos, -1 }
        if length != pos;

    return %report;
}

########################################################################
# _parseSynop
########################################################################
sub _parseSynop {
    my (%report, $period, $windUnit, $winds_est, $region, $country,
        $is_auto, $obs_hour, $have_precip333, $matched);

    my $re_D____D = '[A-Z\d]{3,}';
    my $re_MMM    = '(?:\d{3})'; # 001..623, 901..936
    my $re_ULaULo = '(?:\d\d)';
    my $re_IIiii  = '(?:\d{5})';

    $report{msg} = $_;
    $report{isSynop} = undef;
    _cySet 'XXXX';

    if (/^ERROR -/) {
        pos = 0;
        $report{ERROR} = _makeErrorMsgPos 'other';
        return %report;
    }

=head2 Parsing of SYNOP messages

=cut

    $_ .= ' '; # this makes parsing much easier

    pos = 0;

    # warn about modification
    push @{$report{warning}}, { warningType => 'msgModified',
                                s           => substr $_, 0, -1 }
        if $report{msg} . ' ' ne $_;

########################################################################

=head3 SYNOP Section 0: information about the observation and the observing station

 MiMiMjMj
 FM12 (fixed land):  AAXX                     YYGGiw IIiii
 FM13 (sea):         BBXX {D....D|A1bwnbnbnb} YYGGiw 99LaLaLa QcLoLoLoLo
 FM14 (mobile land): OOXX D....D              YYGGiw 99LaLaLa QcLoLoLoLo MMMULaULo h0h0h0h0im

=for html <!--

=over

=item B<MiMiMjMj>

=for html --><dl><dt><strong>M<sub>i</sub>M<sub>i</sub>M<sub>j</sub>M<sub>j</sub></strong></dt><dd>

station type

=back

=cut

    # group MiMiMjMj
    if (!/\G((?:AA|BB|OO)XX) /gc) {
        $report{ERROR} = _makeErrorMsgPos 'obsStationType';
        return %report;
    }
    $report{obsStationType} = { s => $1, stationType => $1 };

    $region = '';
    $country = '';

=for html <!--

=over

=item BBXX: B<D....D> | B<A1bwnbnbnb>

=for html --><dl><dt>BBXX: <strong>D....D</strong> | <strong>A<sub>1</sub>b<sub>w</sub>n<sub>b</sub>n<sub>b</sub>n<sub>b</sub></strong></dt><dd>

call sign or station id

=back

=cut

    # BBXX: group (D....D|A1bwnbnbnb)
    #   D....D: ship's call sign, A1bwnbnbnb: call sign of stations at sea
    if ($report{obsStationType}{stationType} eq 'BBXX') {
        if (m{\G(${re_A1bw}\d{3}) }ogc) {
            $country = _A1bw2country $1;
            $region  = _A1bw2region $1;
            $report{callSign} = { s => $1, id => $1, region => $region };
        } elsif (m{\G($re_D____D) }ogc) {
            $region  = 'SHIP';
            $report{callSign} = { s => $1, id => $1 };
        } else {
            $report{ERROR} = _makeErrorMsgPos 'stationId';
            return %report;
        }
    }

=over

=item OOXX: B<D....D>

call sign

=back

=cut

    # OOXX: group D....D
    if ($report{obsStationType}{stationType} eq 'OOXX') {
        if (!m{\G($re_D____D) }ogc) {
            $report{ERROR} = _makeErrorMsgPos 'callSign';
            return %report;
        }
        $report{callSign} = { s => $1, id => $1 };
        $region = 'MOBIL';
        $country = _A1A22country $1
            if length $1 == 5;
    }

=for html <!--

=over

=item B<YYGGiw>

=for html --><dl><dt><strong>YYGGi<sub>w</sub></strong></dt><dd>

day and hour of observation, indicator for wind speed (unit)

=back

=cut

    # group YYGGiw
    if (!m{\G($re_day)($re_hour)([0134/]) }ogc) {
        $report{ERROR} = _makeErrorMsgPos 'obsTimeWindInd';
        return %report;
    }
    $report{obsTime} = {
        s      => "$1$2",
        timeAt => { day => $1, hour => $2 }
    };
    $obs_hour = $2;

    # WMO-No. 306 Vol I.1, Part A, code table 1855:
    $report{windIndicator}{s} = $3;
    if ($3 ne '/') {
        $windUnit = $3 < 2 ? 'MPS' : 'KT';
        $winds_est = $3 == 0 || $3 == 3;
        $report{windIndicator}{windUnit} = $windUnit;
        $report{windIndicator}{isEstimated} = undef if $winds_est;
    } else {
        $report{windIndicator}{notAvailable} = undef;
    }

    $period = $obs_hour % 6 == 0 ? 6 : $obs_hour % 3 == 0 ? 3 : 1;

    if ($report{obsStationType}{stationType} eq 'AAXX') {

=over

=item AAXX: B<IIiii>

station identification

=back

=cut

        # AAXX: group IIiii
        $matched = m{\G($re_IIiii) }ogc;
        if (!$matched || !($region = _IIiii2region $1)) {
            pos() -= 6 if $matched;
            $report{ERROR} = _makeErrorMsgPos 'stationId';
            return %report;
        }
        $report{obsStationId} = { s => $1, id => $1, region => $region };
        $country = _IIiii2country $1;
    } else {

=for html <!--

=over

=item BBXX, OOXX: B<C<99>LaLaLa QcLoLoLoLo>

=for html --><dl><dt>BBXX, OOXX: <strong><code>99</code>L<sub>a</sub>L<sub>a</sub>L<sub>a</sub> Q<sub>c</sub>L<sub>o</sub>L<sub>o</sub>L<sub>o</sub>L<sub>o</sub></strong></dt><dd>

position of the station

=back

=cut

        my $lat_lon_unit_digits;

        # BBXX, OOXX: group 99LaLaLa QcLoLoLoLo
        if (m{\G(99/// /////) }gc) {
            $report{stationPosition}{s} = $1;
            $report{stationPosition}{notAvailable} = undef;
            $lat_lon_unit_digits = '';
        } else {
            $matched = m{\G(99(\d(\d))(\d) ([1357])(\d\d(\d))(\d)) }gc;
            if ($matched && "$2$4" <= 900 && "$6$8" <= 1800) {
                $report{stationPosition} = {
                    s   => $1,
                    lat => { v => _formatQcL($5, 1, $2, $4), q => 10 },
                    lon => { v => _formatQcL($5, 0, $6, $8), q => 10 },
                };
                $lat_lon_unit_digits = "$3$7";
            } else {
                pos() -= 12 if $matched;
                $report{ERROR} = _makeErrorMsgPos 'stationPosition';
                return %report;
            }
        }

=for html <!--

=over

=item OOXX: B<MMMULaULo h0h0h0h0im>

=for html --><dl><dt>OOXX: <strong>MMMU<sub>La</sub>U<sub>Lo</sub> h<sub>0</sub>h<sub>0</sub>h<sub>0</sub>h<sub>0</sub>i<sub>m</sub></strong></dt><dd>

position of the station (Marsden square, height)

=back

=cut

        if ($report{obsStationType}{stationType} eq 'OOXX') {
            # OOXX: group MMMULaULo h0h0h0h0im
            $matched = m{\G((?:///|($re_MMM))(?://|($re_ULaULo)) (?:////[/1-8]|(\d{4})([1-8]))) }ogc;
            if (   !$matched
                || (   defined $2
                    && !(($2 >= 1 && $2 <= 623) || ($2 >= 901 && $2 <= 936))))
            {
                pos() -= 12 if $matched;
                $report{ERROR} = _makeErrorMsgPos 'stationPosition';
                return %report;
            }
            push @{$report{warning}}, { warningType => 'latlonDigitMismatch',
                                        s      => "$lat_lon_unit_digits != $3" }
                if defined $3 && $3 ne $lat_lon_unit_digits;
            $report{stationPosition}{s} .= " $1";
            $report{stationPosition}{marsdenSquare} = $2 + 0 if defined $2;
            if (defined $4) {
                $report{stationPosition}{elevation} = {
                    v => $4 + 0,
                    # WMO-No. 306 Vol I.1, Part A, code table 1845:
                    u => ($5 <= 4 ? 'M' : 'FT'),
                    q => 'confidenceIs' .
                         { 1 => 'Excellent', 2 => 'Good',
                           3 => 'Fair',      0 => 'Poor' }->{$5 % 4}
                };
            }
        }
    }

=over

=item optional: B<C<NIL>>

message contains no observation data, end of message

=back

=cut

    if (/\GNIL $/) {
        $report{reportModifier}{s} =
            $report{reportModifier}{modifierType} = 'NIL';
        return %report;
    }

########################################################################

=head3 SYNOP Section 1: land observations (data for global exchange common for all code forms)

 iRixhVV Nddff (00fff) 1snTTT {2snTdTdTd|29UUU} 3P0P0P0P0 {4PPPP|4a3hhh} 5appp 6RRRtR {7wwW1W2|7wawaWa1Wa2} 8NhCLCMCH 9GGgg

=for html <!--

=over

=item B<iRixhVV>

=for html --><dl><dt><strong>i<sub>R</sub>i<sub>x</sub>hVV</strong></dt><dd>

precipitation indicator, weather indicator, base of lowest cloud

=back

=cut

    # group iRixhVV
    # EXTENSION: iR can be '/': notAvailable
    # EXTENSION: ix can be '/': notAvailable
    $matched = m{\G([0-46-8/])([1-7/])([\d/])(\d\d|//) }gc;
    if (   !$matched
        || (($1 eq '6' || $1 eq '7' || $1 eq '8') && $country ne 'RU'))
    {
        pos() -= 6 if $matched;
        $report{ERROR} = _makeErrorMsgPos 'indicatorCloudVis';
        return %report;
    }

    # WMO-No. 306 Vol I.1, Part A, code table 1819:
    $report{precipInd}{s} = $1;
    if ($1 eq '/') {
        $report{precipInd}{notAvailable} = undef;
    } elsif ($1 <= 4) {
        # ( 1 + 3, 1, 3, omitted (amount=0), omitted (NA) )[$1];
        $report{precipInd}{precipIndVal} = $1;
    } else {
        # RU: 6 (=1), 7 (=2), 8 (=4) for stations with autom. precip. sensors
        $report{precipInd}{precipIndVal} = (1, 2, 4)[$1 - 6];
    }

    # WMO-No. 306 Vol I.1, Part A, code table 1860:
    # 1 Manned Included
    # 2 Manned Omitted (no significant phenomenon to report)
    # 3 Manned Omitted (no observation, data not available)
    # 4 Automatic Included using Code tables 4677 and 4561 (US: FMH-2 4-12/4-14)
    # 5 Automatic Omitted (no significant phenomenon to report)
    # 6 Automatic Omitted (no observation, data not available)
    # 7 Automatic Included using Code tables 4680 and 4531 (US: FMH-2 4-13/4-15)
    $report{wxInd}{s} = $2;
    if ($2 eq '/') {
        $report{wxInd}{notAvailable} = undef;
    } else {
        $report{wxInd}{wxIndVal} = $2;
        if ($report{wxInd}{wxIndVal} >= 4) {
            $report{reportModifier}{s} =
                                 $report{reportModifier}{modifierType} = 'AUTO';
            $is_auto = 'AUTO';
        }
    }

    $report{baseLowestCloud} = _codeTable1600 $3, $country;

    if ($country eq 'US') {
        _codeTable4377US \%report, $4, $report{obsStationType}{stationType};
    } elsif ($country eq 'CA') {
        _codeTable4377CA \%report, $4;
    } else {
        _codeTable4377 \%report, $4, $report{obsStationType}{stationType};
    }

=over

=item B<Nddff> (B<C<00>fff>)

total cloud cover, wind direction and speed

=back

=cut

    # group Nddff (00fff)
    if (!m{\G([\d/])($re_dd|00|99|//)(\d\d|//) }ogc) {
        $report{ERROR} = _makeErrorMsgPos 'cloudWind';
        return %report;
    }
    if ($1 eq '/') {
        $report{totalCloudCover}{notAvailable} = undef;
    } else {
        $report{totalCloudCover} = _codeTable2700 $1;
    }
    $report{totalCloudCover}{s} = $1;
    $report{sfcWind}{s} = "$2$3";
    if ("$2$3" eq '////') {
        $report{sfcWind}{wind}{notAvailable} = undef;
    # WMO-No. 306 Vol I.1, Part A, code table 0877:
    } elsif ($2 eq '00') {
        $report{sfcWind}{wind}{isCalm} = undef;
        $report{sfcWind}{wind}{isEstimated} = undef if $winds_est;
    } else {
        if ($2 eq '//') {
            $report{sfcWind}{wind}{dirNotAvailable} = undef;
        } elsif ($2 eq '99') {
            $report{sfcWind}{wind}{dirVarAllUnk} = undef;
        } else {
            if ($winds_est) {
                $report{sfcWind}{wind}{isEstimated} = undef;
            } else {
                $report{sfcWind}{wind}{dir} = { rp => 4, rn => 5 };
            }
            $report{sfcWind}{wind}{dir}{v} = $2 * 10;
        }
        if ($3 eq '//' || !$windUnit) {
            $report{sfcWind}{wind}{speedNotAvailable} = undef;
        } else {
            $report{sfcWind}{wind}{speed} = { v => $3 + 0, u => $windUnit };
            $report{sfcWind}{wind}{isEstimated} = undef if $winds_est;
            # US: FMH-2 4.2.2.2, CA: MANOBS 12.3.2.3
            # default: WMO-No. 306 Vol I.1, Part A, Section A, 12.2.2.3.1
            $report{sfcWind}{measurePeriod} = { v => 10, u => 'MIN' };
        }
    }

    if ($3 eq '99') {
        if (!m{\G(00([1-9]\d\d)) }gc) {
            $report{ERROR} = _makeErrorMsgPos 'wind';
            return %report;
        }
        $report{sfcWind}{s} .= " $1";
        $report{sfcWind}{wind}{speed}{v} = $2 + 0 if $windUnit;
    }

    # EXTENSION: allow 00///
    if (m{\G(00///) }gc) {
        $report{sfcWind}{s} .= " $1";
    }

=for html <!--

=over

=item B<C<1>snTTT>

=for html --><dl><dt><strong><code>1</code>s<sub>n</sub>TTT</strong></dt><dd>

temperature

=back

=cut

    # group 1snTTT
    if (m{\G(1(?:[01/]///|([01]\d\d[\d/]))) }gc) {
        $report{temperature} = {
            s   => $1,
            air => defined $2 ? { temp => _parseTemp $2 }
                              : { notAvailable => undef }
        };
    }

=for html <!--

=over

=item B<C<2>snTdTdTd> | B<C<29>UUU>

=for html --><dl><dt><strong><code>2</code>s<sub>n</sub>T<sub>d</sub>T<sub>d</sub>T<sub>d</sub></strong> | <strong><code>29</code>UUU</strong></dt><dd>

dew point or relative humidity

=back

=cut

    # group 2snTdTdTd|29UUU
    if (m{\G(2(?:[109/]///|([01]\d\d[\d/])|9(100|0\d\d))) }gc) {
        $report{temperature}{s} .= ' ' if exists $report{temperature};
        $report{temperature}{s} .= $1;
        if (defined $2) {
            $report{temperature}{dewpoint}{temp} = _parseTemp $2;
            _setHumidity $report{temperature};
        } elsif (defined $3) {
            $report{temperature}{relHumid1} = $3 + 0;
        } else {
            $report{temperature}{dewpoint}{notAvailable} = undef;
        }
    }

    # EXTENSION: 29UUU after 2snTdTdTd
    push @{$report{warning}}, { warningType => 'notProcessed', s => $1 }
        if m{\G(29[\d/]{3}) }gc;

=for html <!--

=over

=item B<C<3>P0P0P0P0>

=for html --><dl><dt><strong><code>3</code>P<sub>0</sub>P<sub>0</sub>P<sub>0</sub>P<sub>0</sub></strong></dt><dd>

station level pressure

=back

=cut

    # group 3P0P0P0P0
    if (m{\G(3(?:(\d{3})([\d/])|[\d/]///)) }gc) {
        $report{stationPressure} = {
            s => $1,
            defined $2
                ? (pressure => {
                   v => ($2 + ($2 < 500 ? 1000 : 0)) . ($3 eq '/' ? '' : ".$3"),
                   u => 'hPa'
                  })
                : (notAvailable => undef)
        };
    }
    if (   !exists $report{stationPressure}
        && $report{obsStationType}{stationType} eq 'AAXX')
    {
        push @{$report{warning}}, { warningType => 'pressureMissing' };
    }

=for html <!--

=over

=item B<C<4>PPPP> | B<C<4>a3hhh>

=for html --><dl><dt><strong><code>4</code>PPPP</strong> | <strong><code>4</code>a<sub>3</sub>hhh</strong></dt><dd>

sea level pressure or geopotential height of an agreed standard isobaric surface

=back

=cut

    # group 4PPPP|4a3hhh
    if (m{\G(4[09/]///) }gc) {
        $report{SLP}{s} = $1;
        $report{SLP}{notAvailable} = undef;
    } elsif (m{\G(4([09]\d\d)([\d/])) }gc) {
        $report{SLP}{s} = $1;
        $report{SLP}{pressure}{v} = $2;
        $report{SLP}{pressure}{v} += 1000 if $2 < 500;
        $report{SLP}{pressure}{v} .= ".$3" unless $3 eq '/';
        $report{SLP}{pressure}{u} = 'hPa';
    } elsif (m{\G(4([1-8])(\d{3}|///)) }gc) {
        my ($surface, $height) = ($2, $3);

        $report{gpSurface}{s} = $1;
        if ($height eq '///') {
            $report{gpSurface}{notAvailable} = undef;
        } elsif ($surface <= 2 || $surface >= 7) {
            $report{gpSurface}{surface} = _codeTable0264 $surface;
            # hhh geopotential of an agreed standard isobaric surface given by a3, in standard geopotential metres, omitting the thousands digit.
            #    1 (1000):           100 gpm ->    0 ...  999
            #    2  (925):           800 gpm ->  300 ... 1299
            #    5  (500): 5000 ... 5500 gpm -> 4500 ... 5999 !
            #    7  (700):          3000 gpm -> 2500 ... 3499
            #    8  (850):          1500 gpm -> 1000 ... 1999
            if ($surface == 2) {
                $height += 1000 if $height < 300;
            } elsif ($surface == 7) {
                $height += ($height < 500 ? 3000 : 2000);
            } elsif ($surface == 8) {
                $height += 1000;
            }
            $report{gpSurface}{geopotential} = $height + 0;
#       } elsif (   $surface == 6
#           && exists $report{obsStationId}
#           && $report{obsStationId}{id} == 84735)
#       {
#           $height += ($height < 500 ? 4000 : 3000);
#           $report{gpSurface}{geopotential} = $height;
        } else {
            $report{gpSurface}{invalidFormat} = $surface;
        }
    }

=over

=item B<C<5>appp>

three-hourly pressure tendency (for station level pressure if provided)

=back

=cut

    # group 5appp
    if (/\G(5([0-8])(\d{3})) /gc) {
        $report{pressureChange} = {
            s                 => $1,
            timeBeforeObs     => { hours => 3 },
            pressureTendency  => $2,
            pressureChangeVal => {
                v => sprintf('%.1f', $3 / ($2 >= 5 ? -10 : 10) + 0),
                u => 'hPa'
        }};
    } elsif (m{\G(5////) }gc) {
        $report{pressureChange} = {
            s             => $1,
            timeBeforeObs => { hours => 3 },
            notAvailable  => undef
        };
    } elsif (m{\G(5[\d/]{4}) }gc) {
        $report{pressureChange} = {
            s             => $1,
            timeBeforeObs => { hours => 3 },
            invalidFormat => $1
        };
    }

=for html <!--

=over

=item B<C<6>RRRtR>

=for html --><dl><dt><strong><code>6</code>RRRt<sub>R</sub></strong></dt><dd>

amount of precipitation for given period

=back

=cut

    # group 6RRRtR
    if (m{\G(6(\d{3}|///)([\d/])) }gc) {
        if (   exists $report{precipInd}{precipIndVal}
            && $report{precipInd}{precipIndVal} != 0
            && $report{precipInd}{precipIndVal} != 1)
        {
            push @{$report{warning}}, { warningType => 'precipNotOmitted1' };
        }

        $report{precipitation} = { s => $1, _codeTable3590 $2 };
        if (!exists $report{precipitation}{notAvailable}) {
            if ($3 eq '/') {
                if ($country eq 'SA') {
                    $report{precipitation}{timeBeforeObs}{hours} = 12;
                } else {
                    $report{precipitation}{timeBeforeObs}{notAvailable} = undef;
                }
            } else {
                if ($country eq 'KZ' && $3 eq '0' && $period > 1) {
                    $report{precipitation}{timeBeforeObs}{hours} = $period;
                } else {
                    $report{precipitation}{timeBeforeObs} = _codeTable4019 $3;
                }
            }
        }
    } elsif (   exists $report{precipInd}{precipIndVal}
             && (   $report{precipInd}{precipIndVal} == 0
                 || $report{precipInd}{precipIndVal} == 1))
    {
        push @{$report{warning}}, { warningType => 'precipOmitted1' };
    }

=for html <!--

=over

=item B<C<7>wwW1W2> | B<C<7>wawaWa1Wa2>

=for html --><dl><dt><strong><code>7</code>wwW<sub>1</sub>W<sub>2</sub></strong> | <strong><code>7</code>w<sub>a</sub>w<sub>a</sub>W<sub>a1</sub>W<sub>a2</sub></strong></dt><dd>

present and past weather

=back

=cut

    # group (7wwW1W2|7wawaWa1Wa2)
    if (m{\G(7(\d\d|//)([\d/])([\d/])) }gc) {
        my $simple;

        if (   exists $report{wxInd}{wxIndVal}
            && $report{wxInd}{wxIndVal} != 1
            && $report{wxInd}{wxIndVal} != 4
            && $report{wxInd}{wxIndVal} != 7)
        {
            push @{$report{warning}}, { warningType => 'weatherNotOmitted' };
        }

        $simple =      exists $report{wxInd}{wxIndVal}
                    && $report{wxInd}{wxIndVal} == 7
                  ? 'Simple' : '';
        $report{weatherSynop}{s} = $1;
        if ($2 eq '//') {
            $report{weatherSynop}{weatherPresentNotAvailable} = undef;
        } else {
            $report{weatherSynop}{"weatherPresent$simple"} = $2 + 0;
        }
        # http://www.wmo.int/pages/prog/www/WMOCodes/Updates_Sweden.pdf
        # TODO: effective from?
        if ($country eq 'SE') {
            my $period_SE;

            $period_SE = $obs_hour % 6;
            $period_SE = 6 if $period_SE == 0;
            $report{weatherSynop}{timeBeforeObs}{hours} = $period_SE;
        } else {
            $report{weatherSynop}{timeBeforeObs}{hours} = $period;
        }
        if ($3 eq '/') {
            $report{weatherSynop}{weatherPast1NotAvailable} = undef;
        } else {
            $report{weatherSynop}{"weatherPast1$simple"} = $3;
        }
        if ($4 eq '/') {
            $report{weatherSynop}{weatherPast2NotAvailable} = undef;
        } else {
            $report{weatherSynop}{"weatherPast2$simple"} = $4;
        }
    } elsif (   exists $report{wxInd}{wxIndVal}
             && (   $report{wxInd}{wxIndVal} == 1
                 || $report{wxInd}{wxIndVal} == 4
                 || $report{wxInd}{wxIndVal} == 7))
    {
        push @{$report{warning}}, { warningType => 'weatherOmitted' };
    }

=for html <!--

=over

=item B<C<8>NhCLCMCH>

=for html --><dl><dt><strong><code>8</code>N<sub>h</sub>C<sub>L</sub>C<sub>M</sub>C<sub>H</sub></strong></dt><dd>

cloud type for each level and cloud cover of lowest reported cloud type

=back

=cut

    # group 8NhCLCMCH
    # WMO-No. 306 Vol I.1, Part A, Section A, 12.2.7
    # "This group shall be omitted ... [for] N=0 ... N=9 ... N=/."
    # but: "All cloud observations at sea ... shall be reported ..."
    # EXTENSION: allow 8000[1-8], 8/[\d/]{3}
    if (m{\G(8([\d/])([\d/])([\d/])([\d/])) }gc) {
        if (   $report{obsStationType}{stationType} ne 'BBXX'
            && (   ($2 eq '0' && ("$3$4" ne '00' || $5 eq '/' || $5 eq '0'))
                || $2 eq '9'))
        {
            $report{cloudTypes}{invalidFormat} = $1;
        } elsif (($2 eq '/' || $2 == 9) && "$3$4$5" eq '///') {
            $report{cloudTypes}{ $2 eq '/' ? 'notAvailable' : 'skyObscured' }
                                                                        = undef;
        } elsif ($2 ne '9') {
            $report{cloudTypes} = {
               $3 eq '/' ? (cloudTypeLowNA    => undef):(cloudTypeLow    => $3),
               $4 eq '/' ? (cloudTypeMiddleNA => undef):(cloudTypeMiddle => $4),
               $5 eq '/' ? (cloudTypeHighNA   => undef):(cloudTypeHigh   => $5),
            };
            if ($2 ne '/') {
                if ($3 ne '/' && $3 != 0) {
                    # low has clouds (1..9)
                    $report{cloudTypes}{oktasLow} = $2;
                } elsif ($3 ne '/' && $4 ne '/' && $4 != 0) {
                    # low has no clouds (0) and middle has clouds (1..9)
                    $report{cloudTypes}{oktasMiddle} = $2;
                } else {
                    # low and middle are N/A or have no clouds
                    # if low and middle have no clouds: oktas should be 0
                    # EXTENSION: tolerate and store oktas,
                    #            but for which layer is it?
                    $report{cloudTypes}{oktas} = $2;
                }
            }
        } else {
            $report{cloudTypes}{invalidFormat} = $1;
        }
        $report{cloudTypes}{s} = $1;
    }

    # EXTENSION: tolerate multiple 8NhCLCMCH groups
    while (m{\G(8[\d/]{4}) }gc) {
        push @{$report{warning}}, { warningType => 'multCloudTypes', s => $1 };
    }

=over

=item B<C<9>GGgg>

exact observation time

=back

=cut

    # group 9GGgg
    if (/\G(9($re_hour)($re_min)) /ogc) {
        $report{exactObsTime} = {
            s      => $1,
            timeAt => { hour => $2, minute => $3 }
        };
    }

########################################################################

=head3 SYNOP Section 2: sea surface observations (maritime data for global exchange, optional)

 222Dsvs 0ssTwTwTw 1PwaPwaHwaHwa 2PwPwHwHw 3dw1dw1dw2dw2 4Pw1Pw1Hw1Hw1 5Pw2Pw2Hw2Hw2 {6IsEsEsRs|ICING plain language} 70HwaHwaHwa 8swTbTbTb ICE {ciSibiDizi|plain language}

=for html <!--

=over

=item B<C<222>Dsvs>

=for html --><dl><dt><strong><code>222</code>D<sub>s</sub>v<sub>s</sub></strong></dt><dd>

direction and speed of displacement of the ship since 3 hours

=back

=cut

    # group 222Dsvs
    if (m{\G222(?://|00|([1-9/])([\d/])) }gc) {
        my (@s2, $waves, $swell);

        @s2  = ();
        $report{section2} = \@s2;

        if (defined $1) {
            my $r;

            $r = { s             => "$1$2",
                   timeBeforeObs => { hours => 3 },
                     $1 eq '/' || $1 == 9 ? (dirVarAllUnk => undef)
                   : $1 == 0              ? (isStationary => undef)
                   :                        _codeTable0700 '', $1, 'Ds'
            };

            if (!exists $r->{isStationary}) {
                # WMO-No. 306 Vol I.1, Part A, code table 4451:
                if ($2 eq '/') {
                    $r->{speedNotAvailable} = undef;
                } elsif ($2 == 0) {
                    $r->{speed} = [ { v => 0, u => 'KT' },
                                    { v => 0, u => 'KMH' }];
                } elsif ($2 == 9) {
                    $r->{speed} = [ { v => 40, u => 'KT',  q => 'isGreater' },
                                    { v => 75, u => 'KMH', q => 'isGreater' }];
                } else {
                    my @speed_KMH = (1,11,20,29,38,48,57,66,76);
                    $r->{speed} = [ { v => $2 * 5 - 4, u => 'KT', rp => 5 },
                                    { v  => $speed_KMH[$2 - 1],
                                      u  => 'KMH',
                                      rp => $speed_KMH[$2] - $speed_KMH[$2 - 1]}
                                  ];
                }
            }

            push @s2, { displacement => $r };
        }

=for html <!--

=over

=item B<C<0>ssTwTwTw>

=for html --><dl><dt><strong><code>0</code>s<sub>s</sub>T<sub>w</sub>T<sub>w</sub>T<sub>w</sub></strong></dt><dd>

sea-surface temperature and its type of measurement

=back

=cut

        # group 0ssTwTwTw
        # ss: WMO-No. 306 Vol I.1, Part A, code table 3850
        #     WMO-No. 306 Vol I.2, Part B, CODE/FLAG Tables, code table 0 02 038
        if (m{\G(0([0-7])(\d\d[\d/])) }gc) {
            push @s2, { seaSurfaceTemp => {
                s                    => $1,
                waterTempMeasurement => (0, 1, 2, 14)[$2 >> 1],
                temp                 => _parseTemp(($2 % 2) . $3)
            }};
        } elsif (m{\G(0[0-7/]///) }gc) {
            push @s2, { seaSurfaceTemp => {
                s            => $1,
                notAvailable => undef
            }};
        }

=for html <!--

=over

=item B<C<1>PwaPwaHwaHwa>

=for html --><dl><dt><strong><code>1</code>P<sub>wa</sub>P<sub>wa</sub>H<sub>wa</sub>H<sub>wa</sub></strong></dt><dd>

period and height of waves (instrumental data)

=back

=cut

        # group 1PwaPwaHwaHwa
        if (m{\G(1(?://|(\d\d))(?://|(\d\d))) }gc) {
            push @s2, { waves => {
                s => $1,
                  $1 eq '1////' ? (notAvailable => undef)
                : $1 eq '10000' ? (noWaves => undef)
                :                 (defined $2 ? (wavePeriod => $2 + 0) : (),
                                   defined $3 ? (height => _waveHeight $3) : ())
            }};
            $waves = $s2[$#s2]{waves};
        }

=for html <!--

=over

=item B<C<2>PwPwHwHw>

=for html --><dl><dt><strong><code>2</code>P<sub>w</sub>P<sub>w</sub>H<sub>w</sub>H<sub>w</sub></strong></dt><dd>

period and height of wind waves

=back

=cut

        # group 2PwPwHwHw
        if (m{\G(2(?://|(\d\d))(?://|(\d\d))) }gc) {
            push @s2, { windWaves => {
                s => $1,
                  $1 eq '2////' ? (notAvailable => undef)
                : $1 eq '20000' ? (noWaves => undef)
                :                 (defined $2 ? (  $2 == 99
                                                 ? (seaConfused => undef)
                                                 : (wavePeriod => $2 + 0))
                                              : (),
                                   defined $3 ? (height => _waveHeight $3) : ())
            }};
        }

=for html <!--

=over

=item B<C<3>dw1dw1dw2dw2 C<4>Pw1Pw1Hw1Hw1 C<5>Pw2Pw2Hw2Hw2>

=for html --><dl><dt><strong><code>3</code>d<sub>w1</sub>d<sub>w1</sub>d<sub>w2</sub>d<sub>w2</sub> <code>4</code>P<sub>w1</sub>P<sub>w1</sub>H<sub>w1</sub>H<sub>w1</sub> <code>5</code>P<sub>w2</sub>P<sub>w2</sub>H<sub>w2</sub>H<sub>w2</sub></strong></dt><dd>

swell data

=back

=cut

        # groups 3dw1dw1dw2dw2 4Pw1Pw1Hw1Hw1 5Pw2Pw2Hw2Hw2
        # EXTENSION: any group may be missing
        # EXTENSION: allow 99 for dw1dw1/dw2dw2. Pw1Pw1/Pw2Pw2=99: seaConfused
        # EXTENSION: use 36 instead of 00 for dw1dw1/dw2dw2 with wavePeriod
        if (m{\G(3($re_dd|00|99|//)($re_dd|00|99|//)) }ogc) {
            $swell->{s} = $1;

            $swell->{s4} = $2;
            if ($2 eq '00') {
                $swell->{4}{noWaves} = undef;
            } elsif ($2 ne '99' && $2 ne '//') {
                $swell->{4}{dir} = { v => $2 * 10, rp => 4, rn => 5 };
            }

            $swell->{s5} = $3;
            if ($3 eq '00') {
                $swell->{5}{noWaves} = undef;
            } elsif ($3 ne '99' && $3 ne '//') {
                $swell->{5}{dir} = { v => $3 * 10, rp => 4, rn => 5 };
            }
        }

        for my $idx (4, 5) {
            if (m{\G($idx(\d\d|//)(\d\d|//)) }gc) {
                if (exists $swell->{s}) {
                    $swell->{s} .= " $1";
                } else {
                    $swell->{s} = $1;
                }
                if (exists $swell->{"s$idx"}) {
                    $swell->{"s$idx"} .= "$2$3";
                } else {
                    $swell->{"s$idx"} = "$2$3";
                }

                if (   (!exists $swell->{$idx} || !exists $swell->{$idx}{dir})
                    && $2 eq '00'
                    && $3 eq '00')
                {
                    $swell->{$idx}{noWaves} = undef;
                } else {
                    if ($2 eq '99') {
                        $swell->{$idx}{seaConfused} = undef;
                    } elsif ($2 ne '//') {
                        $swell->{$idx}{wavePeriod} = $2 + 0;
                    }

                    $swell->{$idx}{height} = _waveHeight $3
                        if $3 ne '//';

                    if (   exists $swell->{$idx}
                        && exists $swell->{$idx}{noWaves}
                        && exists $swell->{$idx}{wavePeriod})
                    {
                        delete $swell->{$idx}{noWaves};
                        $swell->{$idx}{dir} = { v => 360, rp => 4, rn => 5 };
                    }
                    $swell->{$idx} = { invalidFormat => $swell->{"s$idx"} }
                        if    exists $swell->{$idx}
                           && exists $swell->{$idx}{noWaves}
                           && keys (%{$swell->{$idx}}) > 1;
                }
            }
        }

        if ($swell) {
            $swell->{4}{notAvailable} = undef
                if !exists $swell->{4};
            delete $swell->{5}
                if    (exists $swell->{5} && exists $swell->{5}{noWaves})
                   || ($swell->{s4} // 'a') eq ($swell->{s5} // 'b');

            push @s2, { swell => {
                s         => $swell->{s},
                swellData => [ $swell->{4}, $swell->{5} // () ]
            }};
        }

=for html <!--

=over

=item B<C<6>IsEsEsRs> | B<C<ICING>> I<plain language>

=for html --><dl><dt><strong><code>6</code>I<sub>s</sub>E<sub>s</sub>E<sub>s</sub>R<sub>s</sub></strong> | <strong><code>ICING</code></strong> <em>plain language</em></dt><dd>

ice accretion on ships

=back

=cut

        # group 6IsEsEsRs or ICING plain language
        if (m{\G(6(?:////|([1-5])(\d\d)([0-4]))) }gc) {
            push @s2, { iceAccretion => {
                s => $1,
                defined $2
                    ? (iceAccretionSource => $2,
                       thickness          => { v => $3 + 0, u => 'CM' },
                       iceAccretionRate   => $4
                      )
                    : (notAvailable => undef)
            }};
        } elsif (   m{\GICING (.*?) ?(?=\b(?:([3-9])\2\2|[\d/]{5}|ICE) )}gc
                 || /\GICING (.*?) ?$/gc)
        {
            push @s2, { iceAccretion => {
                s => 'ICING' . ($1 ne '' ? " $1" : ''),
                text => $1
            }};
        }

=for html <!--

=over

=item B<C<70>HwaHwaHwa>

=for html --><dl><dt><strong><code>70</code>H<sub>wa</sub>H<sub>wa</sub>H<sub>wa</sub></strong></dt><dd>

height of waves in units of 0.1 metre

=back

=cut

        # group 70HwaHwaHwa
        # EXTENSION: use group even if 1PwaPwaHwaHwa was 10000 or HwaHwa was //
        if (m{\G(70(\d\d\d|///)) }gc) {
            if (defined $waves) {
                $waves->{s} .= " $1";
                if ($2 ne '///') {
                    delete $waves->{notAvailable};
                    if ($2 > 0 || exists $waves->{height}) {
                        if (exists $waves->{noWaves}) {
                            delete $waves->{noWaves};
                            $waves->{wavePeriod} = 0.0;
                        }
                        $waves->{height}
                                  = { v => sprintf('%.1f', $2 / 10), u => 'M' };
                    }
                }
            } else {
                push @{$report{warning}},
                                     { warningType => 'notProcessed', s => $1 };
            }
        }

=for html <!--

=over

=item B<C<8>swTbTbTb>

=for html --><dl><dt><strong><code>8</code>s<sub>w</sub>T<sub>b</sub>T<sub>b</sub>T<sub>b</sub></strong></dt><dd>

data from wet-bulb temperature measurement

=back

=cut

        # group 8swTbTbTb
        # sw: WMO-No. 306 Vol I.1, Part A, code table 3855
        if (/\G(8([0-25-7])(\d\d\d)) /gc) {
            push @s2, { wetbulbTemperature => {
                s                      => $1,
                wetbulbTempMeasurement => qw(measured measured icedMeasured . .
                                            computed computed icedComputed)[$2],
                temp                   => _parseTemp(($2 % 5 ? 1 : 0) . $3)
            }};
        } elsif (m{\G(8////) }gc) {
            push @s2, { wetbulbTemperature => {
                s            => $1,
                notAvailable => undef
            }};
        }

=for html <!--

=over

=item B<C<ICE>> {B<ciSibiDizi> | I<plain language>}

=for html --><dl><dt><strong><code>ICE</code></strong> {<strong>c<sub>i</sub>S<sub>i</sub>b<sub>i</sub>D<sub>i</sub>z<sub>i</sub></strong> | <em>plain language</em>}</dt><dd>

sea ice and ice of land origin

=back

=cut

        # group ICE (ciSibiDizi|plain language)
        # ci + Si reported only if ship is within 0.5 NM of ice
        # ci=1, Di=0: ship is in an open lead more than 1.0 NM wide
        # ci=1, Di=9: ship is in fast ice with ice boundary beyond visibility
        # ci=zi=0, Si=Di=/: bi icebergs in sight, but no sea ice
        if (m{\G(ICE (?://///|([\d/])([\d/])([\d/])([\d/])([\d/]))) }gc) {
            push @s2, { seaLandIce => {
                s => $1,
                defined $2
                    ? (sortedArr => [
                       $2 ne '/' ? { seaIceConcentration => $2 } : (),
                       $3 ne '/' ? { iceDevelopmentStage => $3 } : (),
                       $4 ne '/' ? { iceOfLandOrigin     => $4 } : (),
                       $5 ne '/' ? { iceEdgeBearing      => $5 } : (),
                       $6 ne '/' ? { iceConditionTrend   => $6 } : ()
                      ])
                    : (notAvailable => undef)
            }};
        } elsif (   m{\GICE (.*?) ?(?=\b([3-9])\2\2 |\b[\d/]{5} )}gc
                 || /\GICE (.*?) ?$/gc)
        {
            push @s2, { seaLandIce => {
                s => 'ICE' . ($1 ne '' ? " $1" : ''),
                text => $1
            }};
        }
    }

    # skip groups until next section
    push @{$report{warning}}, { warningType => 'notProcessed', s => $1 }
        if /\G(?:(.*?) )??(?=333 )/gc && defined $1;

########################################################################

=head3 SYNOP Section 3: climatological data (data for regional exchange, optional)

(partially implemented)

The WMO regions are:

=over

=item *

I (Africa)

=item *

II (Asia)

=item *

III (South America)

=item *

IV (North and Central Amerika)

=item *

V (South-West Pacific)

=item *

VI (Europe)

=item *

Antarctic

=back

 region I: 0TgTgRcRt 1snTxTxTx 2snTnTnTn 4E'sss 5j1j2j3j4 (j5j6j7j8j9) 6RRRtR 7R24R24R24R24 8NsChshs 9SPSPspsp 80000 0LnLcLdLg (1sLdLDLve)

 region II: 0EsnT'gT'g 1snTxTxTx 2snTnTnTn 3EsnTgTg 4E'sss 5j1j2j3j4 (j5j6j7j8j9) 6RRRtR 7R24R24R24R24 8NsChshs 9SPSPspsp

 region III: 1snTxTxTx 2snTnTnTn 3EsnTgTg 4E'sss 5j1j2j3j4 (j5j6j7j8j9) 6RRRtR 7R24R24R24R24 8NsChshs 9SPSPspsp

 region IV: 0CsDLDMDH 1snTxTxTx 2snTnTnTn 3E/// 4E'sss 5j1j2j3j4 (j5j6j7j8j9) 6RRRtR 7R24R24R24R24 8NsChshs 9SPSPspsp TORNADO/ONE-MINUTE MAXIMUM x KNOTS AT x UTC

 region V: 1snTxTxTx 2snTnTnTn 4E'sss 5j1j2j3j4 (j5j6j7j8j9) 6RRRtR 7R24R24R24R24 8NsChshs 9SPSPspsp

 region VI: 1snTxTxTx 2snTnTnTn 3EsnTgTg 4E'sss 5j1j2j3j4 (j5j6j7j8j9) 6RRRtR 7R24R24R24R24 8NsChshs 9SPSPspsp

 Antarctic: 0dmdmfmfm (00200) 1snTxTxTx 2snTnTnTn 4E'sss 5j1j2j3j4 (j5j6j7j8j9) 6RRRtR 7DmDLDMDH 8NsChshs 9SPSPspsp

=cut

    if (/\G333 /gc) {
        my @s3;

        @s3  = ();
        $report{section3} = \@s3;

=for html <!--

=over

=item region I: B<C<0>TgTgRcRt>

=for html --><dl><dt>region I: <strong><code>0</code>T<sub>g</sub>T<sub>g</sub>R<sub>c</sub>R<sub>t</sub></strong></dt><dd>

minumum ground temperature last night, character and start/end of precipitation

=back

=cut

        # region I: group 0TgTgRcRt
        if ($region eq 'I' && m{\G0(//|\d\d)([\d/])([\d/]) }gc) {
            my ($r, $begin_end);

            push @s3, { tempMinGround => {
                s => "0$1",
                $1 eq '//' ? (notAvailable => undef)
                           : (timePeriod => 'n',
                              temp       => { v => $1 > 50 ? -($1 - 50) : $1 +0,
                                              u => 'C' })
            }};

            # WMO-No. 306 Vol II, Chapter I, code table 167:
            $r->{s} = $2;
            if ($2 eq '/') {
                $r->{notAvailable} = undef;
            } elsif ($2 == 0) {
                $r->{noPrecip} = undef;
            } else {
                $r->{phenomDescr} =   $2 == 1 || $2 == 5 ? 'isLight'
                                    : $2 == 2 || $2 == 6 ? 'isModerate'
                                    : $2 == 3 || $2 == 7 ? 'isHeavy'
                                    : $2 == 4 || $2 == 8 ? 'isVeryHeavy'
                                    :                      'isVariable'
                                    ;
                if ($2 < 5) {
                    $r->{phenomDescr2} = 'isIntermittent';
                } elsif ($2 < 9) {
                    $r->{phenomDescr2} = 'isContinuous';
                }
            }
            push @s3, { precipCharacter => $r };

            # WMO-No. 306 Vol I.1, Part A, code table 4677:
            #   00..49 is not precipitation
            $begin_end =      exists $report{weatherSynop}
                           && exists $report{weatherSynop}{weatherPresent}
                           && $report{weatherSynop}{weatherPresent} >= 50
                         ? 'beginPrecip' : 'endPrecip';
            # WMO-No. 306 Vol II, Chapter I, code table 168:
            # Rt time of beginning or end of precipitation
            push @s3, { $begin_end => {
                s => $3,
                  $3 eq '/' ? (notAvailable => undef)
                : $3 == 0   ? (noPrecip => undef)
                : $3 == 1   ? (hours => { v => 1, q => 'isLess' })
                : $3 < 7    ? (hoursFrom => $3 - 1, hoursTill => $3)
                : $3 < 9    ? (hoursFrom => ($3 - 7) * 2 + 6,
                               hoursTill => ($3 - 7) * 2 + 8)
                :             (hours => { v => 10, q => 'isGreater' })
            }};
        }

=for html <!--

=over

=item region II: B<C<0>EsnT'gT'g>

=for html --><dl><dt>region II: <strong><code>0</code>Es<sub>n</sub>T'<sub>g</sub>T'<sub>g</sub></strong></dt><dd>

state of the ground without snow or measurable ice cover, ground temperature

=back

=cut

        # region II: group 0EsnT'gT'g
        # EXTENSION: allow 'E' for state of the ground
        # TODO: enable CN if the documentation matches the data:
        #       e.g. 2009-12: AAXX 14001 54527 ... 333 00151 -> -51 °C ?!?
        if ($country eq 'CN' && m{\G(0[\d/E][\d/]{3}) }gc) {
            push @{$report{warning}},
                                     { warningType => 'notProcessed', s => $1 };
        } elsif ($region eq 'II' && m{\G(0([\d/E]))(///|[01]\d\d) }gc) {
            push @s3, { stateOfGround => {
                s => $1,
                $2 eq '/' || $2 eq 'E' ? (notAvailable => undef)
                                       : (stateOfGroundVal => $2)
            }};
            push @s3, { tempGround => {
                s => $3,
                $3 eq '///' ? (notAvailable => undef) : (temp => _parseTemp $3)
            }};
        }

=for html <!--

=over

=item region IV: B<C<0>CsDLDMDH>

=for html --><dl><dt>region IV: <strong><code>0</code>C<sub>s</sub>D<sub>L</sub>D<sub>M</sub>D<sub>H</sub></strong></dt><dd>

state of sky in tropics

=back

=cut

        # region IV: group 0CsDLDMDH
        if ($region eq 'IV' && m{\G0([\d/])([\d/])([\d/])([\d/]) }gc) {
            # WMO-No. 306 Vol II, Chapter IV, code table 430
            push @s3, { stateOfSky => {
                            s => "0$1",
                            $1 eq '/' ? (notAvailable => undef)
                                      : (stateOfSkyVal => $1)
            }};
            push @s3, { cloudTypesDrift => {
                            s => "$2$3$4",
                            _codeTable0700('cloudTypeLow', $2),
                            _codeTable0700('cloudTypeMiddle', $3),
                            _codeTable0700 'cloudTypeHigh', $4
            }};
        }

=for html <!--

=over

=item Antarctic: B<C<0>dmdmfmfm> (B<C<00200>>)

=for html --><dl><dt>Antarctic: <strong><code>0</code>d<sub>m</sub>d<sub>m</sub>f<sub>m</sub>f<sub>m</sub></strong> (<strong><code>00200</code></strong>)</dt><dd>

maximum wind during the preceding six hours

=back

=cut

        # Antarctic: group 0dmdmfmfm (00200)
        if (   $region eq 'Antarctic'
            && m{\G(0($re_dd|5[1-9]|[67]\d|8[0-6]|//)(\d\d)( 00200)?) }ogc)
        {
            my $r;

            $r->{s} = $1;
            $r->{wind} = { speed => { v => $3, u => 'KT' }};
            $r->{wind}{isEstimated} = undef if $winds_est;
            $r->{wind}{speed}{v} += 200 if defined $4;

            if ($2 eq '//') {
                $r->{wind}{dirNotAvailable} = undef;
            } else {
                # WMO-No. 306 Vol I.1, Part A, code table 0877:
                $r->{wind}{dir} = { rp => 4, rn => 5 } unless $winds_est;
                $r->{wind}{dir} = $2 * 10;
                if ($r->{wind}{dir} > 500) {
                    $r->{wind}{dir} -= 500;
                    $r->{wind}{speed}{v} += 100;
                }
            }
            $r->{measurePeriod} = { v => 1, u => 'MIN' };
            $r->{timeBeforeObs}{hours} = 6;
            push @s3, { highestMeanSpeed => $r };
        }

=for html <!--

=over

=item B<C<1>snTxTxTx>

=for html --><dl><dt><strong><code>1</code>s<sub>n</sub>T<sub>x</sub>T<sub>x</sub>T<sub>x</sub></strong></dt><dd>

maximum temperature
(regions I, II except CN, MG: last 12 hours day-time;
MG: 24 hours before 14:00,
region III: day-time;
region IV: at 00:00 and 18:00 last 12 hours,
           at 06:00 last 24 hours,
           at 12:00 previous day;
region V, CN: last 24 hours,
region VI: last 12 hours, DE at 09:00 UTC: 15 hours,
Antarctic: last 12 hours)

=back

=cut

        # group 1snTxTxTx
        if ($region && m{\G(1(?:([01]\d{3})|[01/]///)) }gc) {
            my $r;

            $r->{s} = $1;
            if (defined $2) {
                $r->{temp} = _parseTemp $2;
            } else {
                $r->{notAvailable} = undef;
            }
            if ($region eq 'V' || $country eq 'CN') {
                $r->{timeBeforeObs}{hours} = 24 if exists $r->{temp};
                push @s3, { tempMax => $r };
            } elsif ($country eq 'RU') {
                $r->{timeBeforeObs}{hours} = 12 if exists $r->{temp};
                push @s3, { tempMax => $r };
            } elsif ($region eq 'IV') {
                if (exists $r->{temp}) {
                    if ($obs_hour == 0 || $obs_hour == 18) {
                        $r->{timeBeforeObs}{hours} = 12;
                    } elsif ($obs_hour == 6) {
                        $r->{timeBeforeObs}{hours} = 24;
                    } elsif ($obs_hour == 12) {
                        $r->{timePeriod} = 'p';
                    } else {
                        $r->{timeBeforeObs}{notAvailable} = undef;
                    }
                }
                push @s3, { tempMax => $r };
            } elsif ($region eq 'Antarctic') {
                $r->{timeBeforeObs}{hours} = 12 if exists $r->{temp};
                push @s3, { tempMax => $r };
            } elsif ($region eq 'VI') {
                if (exists $r->{temp}) {
                    if ($obs_hour =~ /06|18/) {
                        $r->{timeBeforeObs}{hours} = 12;
                    } elsif ($country eq 'DE' && $obs_hour == 9) {
                        $r->{timeBeforeObs}{hours} = 15;
                    } else {
                        # TODO: period for BG, EE, ...?
                        $r->{timeBeforeObs}{notAvailable} = undef;
                    }
                }
                push @s3, { tempMax => $r };
            } elsif ($country eq 'MG') {
                # WMO-No. 306 Vol II, Chapter I, Section D:
                $r->{timePeriod} = '24h14' if exists $r->{temp};
                push @s3, { tempMax => $r };
            } elsif ($region eq 'SHIP' || $region eq 'MOBIL') {
                # TODO: how useful are maxima for moving stations?
                $r->{timeBeforeObs}{notAvailable} = undef
                    if exists $r->{temp};
                push @s3, { tempMax => $r };
            } else { # I, II, III except CN, MG
                $r->{timeBeforeObs}{hours} = 12
                    if exists $r->{temp} && $region ne 'III';
                push @s3, { tempMaxDaytime => $r };
            }
        }

=for html <!--

=over

=item B<C<2>snTnTnTn>

=for html --><dl><dt><strong><code>2</code>s<sub>n</sub>T<sub>n</sub>T<sub>n</sub>T<sub>n</sub></strong></dt><dd>

minimum temperature
(regions I, II except CN, MG: night-time last 12 hours;
MG: 24 hours before 04:00,
region III: last night;
region IV: at 00:00 last 18 hours,
           at 06:00 and 18:00 last 24 hours,
           at 12:00 last 12 hours;
region V, CN: last 24 hours,
region VI: last 12 hours, DE at 09:00 UTC: 15 hours,
Antarctic: last 12 hours)

=back

=cut

        # group 2snTnTnTn
        if ($region && m{\G(2(?:([01]\d{3})|[01/]///)) }gc) {
            my $r;

            $r->{s} = $1;
            if (defined $2) {
                $r->{temp} = _parseTemp $2;
            } else {
                $r->{notAvailable} = undef;
            }
            if ($region eq 'V' || $country eq 'CN') {
                $r->{timeBeforeObs}{hours} = 24 if exists $r->{temp};
                push @s3, { tempMin => $r };
            } elsif ($country eq 'RU') {
                $r->{timeBeforeObs}{hours} = 12 if exists $r->{temp};
                push @s3, { tempMin => $r };
            } elsif ($region eq 'IV') {
                if (exists $r->{temp}) {
                    if ($obs_hour == 6 || $obs_hour == 18) {
                        $r->{timeBeforeObs}{hours} = 24;
                    } elsif ($obs_hour == 0) {
                        $r->{timeBeforeObs}{hours} = 18;
                    } elsif ($obs_hour == 12) {
                        $r->{timeBeforeObs}{hours} = 12;
                    } else {
                        $r->{timeBeforeObs}{notAvailable} = undef;
                    }
                }
                push @s3, { tempMin => $r };
            } elsif ($region eq 'Antarctic') {
                $r->{timeBeforeObs}{hours} = 12 if exists $r->{temp};
                push @s3, { tempMin => $r };
            } elsif ($region eq 'VI') {
                if (exists $r->{temp}) {
                    if ($obs_hour =~ /06|18/) {
                        $r->{timeBeforeObs}{hours} = 12;
                    } elsif ($country eq 'DE' && $obs_hour == 9) {
                        $r->{timeBeforeObs}{hours} = 15;
                    } else {
                        # TODO: period for BG, EE, ...?
                        $r->{timeBeforeObs}{notAvailable} = undef;
                    }
                }
                push @s3, { tempMin => $r };
            } elsif ($country eq 'MG') {
                # WMO-No. 306 Vol II, Chapter I, Section D:
                $r->{timePeriod} = '24h04' if exists $r->{temp};
                push @s3, { tempMin => $r };
            } elsif ($region eq 'SHIP' || $region eq 'MOBIL') {
                # TODO: how useful are maxima for moving stations?
                $r->{timeBeforeObs}{notAvailable} = undef
                    if exists $r->{temp};
                push @s3, { tempMin => $r };
            } else { # I, II, III except CN, MG
                $r->{timeBeforeObs}{hours} = 12
                    if exists $r->{temp} && $region ne 'III';
                push @s3, { tempMinNighttime => $r };
            }
        } elsif (m{\G(29(?:///|100|0\d\d)) }gc) {
            push @{$report{warning}},
                                     { warningType => 'notProcessed', s => $1 };
        }

=for html <!--

=over

=item regions II, III, VI: B<C<3>EsnTgTg>

=for html --><dl><dt>regions II, III, VI: <strong><code>3</code>Es<sub>n</sub>T<sub>g</sub>T<sub>g</sub></strong></dt><dd>

state of the ground without snow or measurable ice cover, minimum ground temperature last night (DE: 12/15 hours)

=item region IV: B<C<3>EC<///>>

state of the ground without snow or measurable ice cover

=back

=cut

        # regions II, III, VI, region I Spain: group 3EsnTgTg
        # region IV: group 3E///
        # TODO: enable CN if the documentation matches the data:
        #       e.g. 2007-07: AAXX 17001 52908 ... 333 ... 30030 -> 30 °C ?!?
        # TODO: enable RO if the documentation matches the data:
        #       e.g. 2012-09: AAXX 19181 15015 ... 333 ... 30038 -> 38 °C ?!?
        if (   $country eq 'CN' && m{\G(3[\d/]{4}) }gc
            || $country eq 'RO' && $obs_hour == 18 && m{\G(3[\d/]{4}) }gc)
        {
            push @{$report{warning}},
                                     { warningType => 'notProcessed', s => $1 };
        } elsif (   (   { II => 1, III => 1, VI => 1 }->{$region}
                     && m{\G3([\d/])(///|[01]\d\d) }gc)
                 || ($region eq 'IV' && m{\G3([\d/])(///) }gc)
                 || ($country eq 'ES' && m{\G3([\d/])(///|[01]\d\d) }gc))
        {
            push @s3, { stateOfGround => {
                s => "3$1" . ($region eq 'IV' ? $2 : ''),
                $1 eq '/' ? (notAvailable => undef) : (stateOfGroundVal => $1)
            }};

            if ($region ne 'IV') {
                push @s3, { tempMinGround => {
                    s => $2,
                    $2 eq '///' ? (notAvailable => undef)
                                : (temp => _parseTemp($2),
                                     $country eq 'DE' && $obs_hour == 9
                                   ? (timeBeforeObs => { hours => 15 })
                                   : $country eq 'DE'
                                   ? (timeBeforeObs => { hours => 12 })
                                   : (timePeriod => 'n'))
                }};
            }
        # region I: 3Ejjj is not used
        # SHIP, MOBIL, regions V, Antarctic: use of 3Ejjj not specified
        } elsif ($region && m{\G(3[\d/]{4}) }gc) {
            push @{$report{warning}},
                                     { warningType => 'notProcessed', s => $1 };
        }

=over

=item B<C<4>E'sss>

state of the ground if covered with snow or ice, snow depth

=back

=cut

        # group 4E'sss
        if (m{\G4([\d/])(///|\d{3}) }gc) {
            push @s3, { stateOfGroundSnow => {
                s => "4$1",
                $1 eq '/' ? (notAvailable => undef)
                          : (stateOfGroundSnowVal => $1)
            }};
            push @s3, { snowDepth => { s => $2, _codeTable3889 $2 }};
        }

=for html <!--

=over

=item B<C<5>j1j2j3j4> (B<j5j6j7j8j9>)

=for html --><dl><dt><strong><code>5</code>j<sub>1</sub>j<sub>2</sub>j<sub>3</sub>j<sub>4</sub></strong> (<strong>j<sub>5</sub>j<sub>6</sub>j<sub>7</sub>j<sub>8</sub>j<sub>9</sub></strong>)</dt><dd>

evaporation, temperature change, duration of sunshine,
radiation type and amount, direction of cloud drift,
direction and elevation of cloud, pressure change

=back

=cut

        {
            my ($msg5, $had_pChg, $had_sun_1d, $had_sun_1h,
                %had_rad, $had_drift);

            # WMO-No. 306 Vol I.1, Part A, code table 2061:
            # group 5j1j2j3j4 (j5j6j7j8j9)

            # use $msg5 for group(s) 5j1j2j3j4
            # determine all 5xxxx groups with 0xxxx .. 6xxxx suppl. groups:
            # 1. use only consecutive groups 0xxxx .. 6xxxx
            ($msg5) = m{\G(5[\d/]{4} (?:[0-6][\d/]{4} |///// )*)}gc;
            $msg5 = '' unless defined $msg5;
            # 2. remove trailing 6xxxx if precipitation indicator is 0 or 2
            if (   exists $report{precipInd}{precipIndVal}
                && (   $report{precipInd}{precipIndVal} == 0
                    || $report{precipInd}{precipIndVal} == 2))
            {
                pos() -= 6 if $msg5 =~ s/6[\d\/]{4} $//;
            }

            pos $msg5 = 0;

            # allow any order, but check for duplicates/impossible combinations
            while (length $msg5 > pos $msg5) {
                my $match_found;

                $match_found = 0;

                # group 5EEEiE
                if ($msg5 =~ /\G(5([0-3]\d\d)(\d)) /gc) {
                    push @s3, { evapo => {
                        s              => $1,
                        evapoAmount    => { v => sprintf('%.1f', $2 / 10),
                                            u => 'MM' },
                        evapoIndicator => $3,
                          # http://www.wmo.int/pages/prog/www/WMOCodes/Updates_NewZealand_3.pdf
                          $country eq 'TV' ? (timePeriod => '24h21')
                          # WMO-No. 306 Vol II, Chapter I, Section D:
                        : $country eq 'MZ' ? (timePeriod => '24h07p')
                        :                    (timeBeforeObs => { hours => 24 })
                    }};
                    $match_found = 1;
                } elsif ($msg5 =~ m{\G(5[0-3/][\d/]{3}(?: /////)*) }gc) {
                    push @s3, { group5xxxxNA => { s => $1 }};
                    $match_found = 1;
                }

                # group 54g0sndT
                if ($msg5 =~ /\G(54([0-5])([01])(\d)) /gc) {
                    push @s3, { tempChange => {
                        s         => $1,
                        hoursFrom => $2,
                        hoursTill => $2 + 1,
                        # WMO-No. 306 Vol I.1, Part A, code table 0822:
                        temp      => {
                                      v => ($4 < 5 ? $4 + 10 : $4) * (-$3 || 1),
                                      u => 'C'
                                     }
                    }};
                    $match_found = 1;
                } elsif ($msg5 =~ m{\G(54[0-5/]//) }gc) {
                    push @s3, { group5xxxxNA => { s => $1 }};
                    $match_found = 1;
                }

                # group 55SSS (j5j6j7j8j9)*, SSS = 000..240
                if (   !$had_sun_1d
                    && $msg5 =~ m{\G(55(?:///|(${re_hour}\d|240))) }ogc)
                {
                    my $r;

                    $r->{s} = $1;
                    $r->{sunshinePeriod} = 'p';
                    if (defined $2) {
                        $r->{sunshine} =
                                    { v => sprintf('%.1f', $2 / 10), u => 'H' };
                    } else {
                        $r->{sunshineNotAvailable} = undef;
                    }
                    for ($msg5 =~ m{\G(0(?:////|\d{4}) )?(1(?:////|\d{4}) )?(2(?:////|\d{4}) )?(3(?:////|\d{4}) )?(4(?:////|\d{4}) )?(5(?:////|[0-4]\d{3}) )?(6(?:////|\d{4}) )?}gc)
                    {
                        next unless defined $_;

                        my ($type, $val) = unpack 'aa4';
                        $r->{s} .= " $type$val";
                        if ($val ne '////') {
                            $r->{radiationPeriod} = { v => 24, u => 'H' };
                            $r->{_radiationType $type}{radiationValue} =
                                                 { v => $val + 0, u => 'Jcm2' };
                        }
                    }
                    push @s3, { radiationSun => $r };
                    $match_found = 1;
                    $had_sun_1d = 1;
                }

                # group 553SS (j5j6j7j8j9)*, SS = 00..10
                if (!$had_sun_1h && $msg5 =~ m{\G(553(?://|(0\d|10))) }gc) {
                    my $r;

                    $r->{s} = $1;
                    $r->{sunshinePeriod} = { v => 1, u => 'H' };
                    if (defined $2) {
                        $r->{sunshine} =
                                    { v => sprintf('%.1f', $2 / 10), u => 'H' };
                    } else {
                        $r->{sunshineNotAvailable} = undef;
                    }
                    for ($msg5 =~ m{\G(0(?:[\d/]///|\d{4}) )?(1(?:[\d/]///|\d{4}) )?(2(?:[\d/]///|\d{4}) )?(3(?:[\d/]///|\d{4}) )?(4(?:[\d/]///|\d{4}) )?(5(?:////|[0-4]\d{3}) )?(6(?:[\d/]///|\d{4}) )?}gc)
                    {
                        next unless defined $_;

                        my ($type, $val) = unpack 'aa4';
                        $r->{s} .= " $type$val";
                        if (substr($val, 1) ne '///') {
                            $r->{radiationPeriod} = { v => 1, u => 'H' };
                            $r->{_radiationType $type}{radiationValue} =
                                                 { v => $val + 0, u => 'kJm2' };
                        }
                    }
                    push @s3, { radiationSun => $r };
                    $match_found = 1;
                    $had_sun_1h = 1;
                }

                # groups 5540[78] 4FFFF or 5550[78] 5F24F24F24F24
                if (   $msg5 =~ m{\G(55([45])0([78])) \2(\d{4}|////) }
                    && !exists $had_rad{"$2$3"})
                {
                    pos $msg5 += 12;
                    push @s3,
                      { qw(radShortWave radDirectSolar)[$3 - 7] => {
                        s => "$1 $2$4",
                          $4 eq '////'
                        ? (notAvailable => undef)
                        : (radiationPeriod => { v => (1, 24)[$2 - 4], u => 'H'},
                           radiationValue  => { v => $4 + 0,
                                                u => qw(kJm2 Jcm2)[$2 - 4] })
                    }};
                    $match_found = 1;
                    $had_rad{"$2$3"} = undef;
                } elsif ($msg5 =~ m{\G(55[45]//) }gc) {
                    push @s3, { group5xxxxNA => { s => $1 }};
                    $match_found = 1;
                }

                # group 56DLDMDH, direction of cloud drift
                if (!$had_drift && $msg5 =~ m{\G(56([\d/])([\d/])([\d/])) }gc) {
                    push @s3, { cloudTypesDrift => {
                                    s => $1,
                                    _codeTable0700('cloudTypeLow', $2),
                                    _codeTable0700('cloudTypeMiddle', $3),
                                    _codeTable0700 'cloudTypeHigh', $4
                    }};
                    $match_found = 1;
                    $had_drift = 1;
                }

                # group 57CDaeC, direction and elevation of cloud
                if ($msg5 =~ m{\G(57([\d/])(\d)(\d)) }gc) {
                    push @s3, { cloudLocation => {
                                    s => $1,
                                    _codeTable0500($2),
                                    _codeTable0700('cloud', $3),
                                    _codeTable1004 $4
                    }};
                    $match_found = 1;
                } elsif ($msg5 =~ m{\G(57///) }gc) {
                    push @s3, { group5xxxxNA => { s => $1 }};
                    $match_found = 1;
                }

                # group 58p24p24p24
                if (!$had_pChg && $msg5 =~ m{\G(58(?:(\d{3})|///)) }gc) {
                    push @s3, { pressureChange => {
                        s             => $1,
                        timeBeforeObs => { hours => 24 },
                        defined $2
                           ? (pressureChangeVal => {
                                   v => sprintf('%.1f', $2 / 10),
                                   u => 'hPa' })
                           : (notAvailable => undef)
                    }};
                    $match_found = 1;
                    $had_pChg = 1;
                }

                # group 59p24p24p24
                if (!$had_pChg && $msg5 =~ m{\G(59(?:(\d{3})|///)) }gc) {
                    push @s3, { pressureChange => {
                        s             => $1,
                        timeBeforeObs => { hours => 24 },
                        defined $2
                          ? (pressureChangeVal => {
                                  v => sprintf('%.1f', $2 / -10 + 0),
                                  u => 'hPa' })
                          : (notAvailable => undef)
                    }};
                    $match_found = 1;
                    $had_pChg = 1;
                }

                # EXTENSION: allow /////
                if ($msg5 =~ m{///// }gc) {
                    push @s3, { group5xxxxNA => { s => '/////' }};
                    $match_found = 1;
                }

                last unless $match_found; # no match but $msg5 was not "empty"
            }

            # EXTENSION: allow un-announced 6xxxx group
            if ($msg5 =~ m{\G6(?:\d{3}|///)[\d/] $}gc) {
                pos() -= 6;
            }
            if (length $msg5 > pos $msg5) {
                pos() -= length(substr $msg5, pos $msg5);
                $report{ERROR} = _makeErrorMsgPos 'invalid333-5xxxx';
                return %report;
            }
        }

=for html <!--

=over

=item B<C<6>RRRtR>

=for html --><dl><dt><strong><code>6</code>RRRt<sub>R</sub></strong></dt><dd>

amount of precipitation for given period

=back

=cut

        # group 6RRRtR
        if (m{\G(6(\d{3}|///)([\d/])) }gc) {
            my $r;

            if (   exists $report{precipInd}{precipIndVal}
                && $report{precipInd}{precipIndVal} != 0
                && $report{precipInd}{precipIndVal} != 2)
            {
                push @{$report{warning}},
                                     { warningType => 'precipNotOmitted3' };
            }

            $r = { s => $1, _codeTable3590 $2 };
            if (!exists $r->{notAvailable}) {
                if ($3 eq '/') {
                    # WMO-No. 306 Vol II, Chapter II, Section D:
                    if ($country eq 'BD') {
                        $r->{timeBeforeObs}{hours} = 3;
                    } elsif ($country eq 'IN' || $country eq 'LK') {
                        $r->{timeSince}{hour} = '03';
                    } else {
                        $r->{timeBeforeObs}{notAvailable} = undef;
                    }
                } else {
                    $r->{timeBeforeObs} = _codeTable4019 $3;
                }
            }
            push @s3, { precipitation => $r };
            $have_precip333 = 1;
        }

=for html <!--

=over

=item regions I..VI: B<C<7>R24R24R24R24>

=for html --><dl><dt>regions I..VI: <strong><code>7</code>R<sub>24</sub>R<sub>24</sub>R<sub>24</sub>R<sub>24</sub></strong></dt><dd>

amount of precipitation in the last 24 hours

=back

=cut

        # WMO-No. 306 Vol I.1, Part A, 12.4.1:
        # regions I..VI: group 7R24R24R24R24
        # EXTENSION: allow 7////
        # EXTENSION: allow 7xxx/
        if ({ map { $_ => 1 } qw(I II III IV V VI) }->{$region}) {
            if (m{\G(7(\d{3})([\d/])) }gc) {
                my $r;

                $r->{s} = $1;
                $r->{timeBeforeObs}{hours} = 24;
                if ("$2$3" eq '9999') {
                    $r->{precipTraces} = undef;
                } elsif ("$2$3" eq '9998') {
                    $r->{precipAmount} = { v => 999.8,
                                           u => 'MM',
                                           q => 'isEqualGreater' };
                } else {
                    $r->{precipAmount}{v} = $2 + 0;
                    $r->{precipAmount}{v} .= ".$3" unless $3 eq '/';
                    $r->{precipAmount}{u} = 'MM';
                }
                push @s3, { precipitation => $r };
            } elsif (m{\G(7////) }gc) {
                push @s3, { precipitation => {
                    s            => $1,
                    notAvailable => undef
                }};
            }
        }

=for html <!--

=over

=item Antarctic: B<C<7>DmDLDMDH>

=for html --><dl><dt>Antarctic: <strong><code>7</code>D<sub>m</sub>D<sub>L</sub>D<sub>M</sub>D<sub>H</sub></strong></dt><dd>

maximum wind during the preceding six hours

=back

=cut

        # Antarctic: group 7DmDLDMDH
        if (   $region eq 'Antarctic'
            && m{\G7([1-8])([\d/])([\d/])([\d/]) }gc)
        {
            push @s3, { windDir => {
                            s             => "7$1",
                            timeBeforeObs => { hours => 6 },
                            _codeTable0700 '', $1
            }};
            push @s3, { cloudTypesDrift => {
                            s => "$2$3$4",
                            _codeTable0700('cloudTypeLow', $2),
                            _codeTable0700('cloudTypeMiddle', $3),
                            _codeTable0700 'cloudTypeHigh', $4
            }};
        }

=for html <!--

=over

=item B<C<8>NsChshs>

=for html --><dl><dt><strong><code>8</code>N<sub>s</sub>Ch<sub>s</sub>h<sub>s</sub></strong></dt><dd>

cloud cover and height for cloud layers

=back

=cut

        # group 8NsChshs (but not 80000!)
        # EXTENSION: allow Ns = 0
        while (m{\G(8([\d/])([\d/])(\d\d|//)) }gc) {
            my $r;

            if ($1 eq '80000') {
                pos() -= 6;
                last;
            }

            $r->{s} = $1;

            if ($4 eq '//') {
                push @{$r->{sortedArr}}, { cloudBaseNotAvailable => undef };
            } else {
                my ($dist, $tag);

                $dist =   $country eq 'US' ? _codeTable1677US $4
                        :                    _codeTable1677 $4;

                $tag = $2 eq '9' && $3 eq '/' ? 'visVert' : 'cloudBase';
                if (!defined $dist) {
                    push @{$r->{sortedArr}}, { invalidFormat => $4 };
                } elsif (ref $dist eq 'HASH') {
                    if ($tag eq 'visVert') {
                        push @{$r->{sortedArr}}, { visVert => {
                            s => $4,
                            distance => $dist
                        }};
                    } else {
                        push @{$r->{sortedArr}}, { cloudBase => $dist };
                    }
                } else {
                    if ($tag eq 'visVert') {
                        push @{$r->{sortedArr}},
                            { visVertFrom => { distance => $dist->[0] }},
                            { visVertTo   => { distance => $dist->[1] }};
                    } else {
                        push @{$r->{sortedArr}},
                            { cloudBaseFrom => $dist->[0] },
                            { cloudBaseTo   => $dist->[1] };
                    }
                }
            }
            push @{$r->{sortedArr}}, +{ _codeTable0500 $3 };
            push @{$r->{sortedArr}}, { cloudOktas => _codeTable2700 $2 };
            push @s3, { cloudInfo => $r };
        }

=for html <!--

=over

=item B<C<9>SPSPspsp>

=for html --><dl><dt><strong><code>9</code>S<sub>P</sub>S<sub>P</sub>s<sub>p</sub>s<sub>p</sub></strong></dt><dd>

supplementary information (partially implemented)

=back

=cut

        # WMO-No. 306 Vol I.1, Part A, code table 3778:
        # group 9SPSPspsp
        while (m{\G9[\d/]{4} }) {
            my ($r, @time_var, $no_match);

            $no_match = 0;

            # collect time and variability groups for weather phenomenon
            # reported in the following group 9SPSPspsp
            @time_var = ();
            while (   /\G(90([2467])($re_synop_tt)) /ogc
                   || /\G(90(2)($re_synop_zz)) /ogc)
            {
                push @time_var, { s => $1,
                                  t => $2,
                                  v => $3,
                                  r => _codeTable4077 $3,
                                           { 2 => 'Begin',
                                             4 => 'At',
                                             6 => 'Duration',
                                             7 => '' }->{$2}
                };
            }

            # group 90(0(tt|zz)|[15]tt)
            if (m{\G(90(?:0\d\d|[15]$re_synop_tt)) }ogc) {
                push @s3, { weatherSynopInfo => {
                             s => $1,
                             %{ _codeTable4077 substr($1, 3),
                                               ({ 0 => 'Begin',
                                                  1 => 'End',
                                                  5 => '' }->{substr $1, 2, 1})}
                }};
            # group 909Rtdc
            } elsif (/\G909([1-9])([0-79]) /gc) {
                my $begin_end;

                # WMO-No. 306 Vol I.1, Part A, code table 4677:
                #   00..49 is not precipitation
                $begin_end =      exists $report{weatherSynop}
                               && exists $report{weatherSynop}{weatherPresent}
                               && $report{weatherSynop}{weatherPresent} >= 50
                             ? 'beginPrecip' : 'endPrecip';
                push @s3, { $begin_end => { s => "909$1", _codeTable3552 $1 }};

                push @s3, { precipPeriods => {
                    s => $2,
                    _codeTable0833($2),
                      $2 <= 3 ? (onePeriod => undef)
                    : $2 <= 7 ? (morePeriods => undef)
                    :           (periodsNA => undef)
                }};
            # group (902zz) 910ff (00fff) (915dd)
            } elsif (m{\G(910(\d\d|//)) }gc) {
                $r->{s} = '';
                for (@time_var) {
                    if ($_->{v} >= 76) {
                        $r->{s} .= $_->{s} . ' ';
                        $_->{s} = '';
                        push @{$r->{time_var_Arr}}, $_->{r};
                    }
                }
                $r->{s} .= $1;
                $r->{measurePeriod} = { v => 10, u => 'MIN' };
                if ($windUnit && $2 ne '//') {
                    $r->{wind}{speed}{u} = $windUnit;
                    $r->{wind}{speed}{v} = $2 + 0;
                    $r->{wind}{isEstimated} = undef if $winds_est;
                } else {
                    $r->{wind}{speedNotAvailable} = undef;
                }
                if ($2 ne '//' && $2 == 99) {
                    if (!/\G(00([1-9]\d\d)) /gc) {
                        $report{ERROR} = _makeErrorMsgPos 'wind';
                        return %report;
                    }
                    $r->{s} .= " $1";
                    $r->{wind}{speed}{v} = $2 + 0 if $windUnit;
                }
                _check_915dd $r, $winds_est;
                push @s3, { highestGust => $r };
            # group (90[2467]tt|902zz) 91[1-4]ff (00fff) (915dd) (903tt)
            } elsif (m{\G(91([1-4])(\d\d|//)) }gc) {
                my ($type, $have_time_var);

                $r->{s} = '';
                for (@time_var) {
                    $r->{s} .= $_->{s} . ' ';
                    $_->{s} = '';
                    push @{$r->{time_var_Arr}}, $_->{r};
                    if ($_->{t} == 7) {
                        $have_time_var = 1;
                    } elsif ($_->{t} == 4) {
                        $have_time_var = 1;
                        $r->{measurePeriod} = { v => 10, u => 'MIN' };
                    }
                }
                $r->{timeBeforeObs}{hours} = $period
                    unless $have_time_var;
                $r->{s} .= $1;
                $type = { 1 => 'highestGust',
                          2 => 'highestMeanSpeed',
                          3 => 'meanSpeed',
                          4 => 'lowestMeanSpeed' }->{$2};
                if ($windUnit && $3 ne '//') {
                    $r->{wind}{speed}{u} = $windUnit;
                    $r->{wind}{speed}{v} = $3 + 0;
                    $r->{wind}{isEstimated} = undef if $winds_est;
                } else {
                    $r->{wind}{speedNotAvailable} = undef;
                }
                if ($3 ne '//' && $3 == 99) {
                    if (!/\G(00([1-9]\d\d)) /gc) {
                        $report{ERROR} = _makeErrorMsgPos 'wind';
                        $report{section3} = \@s3;
                        return %report;
                    }
                    $r->{s} .= " $1";
                    $r->{wind}{speed}{v} = $2 + 0 if exists $r->{wind}{speed};
                }
                _check_915dd $r, $winds_est;
                if (/\G903($re_synop_period) /ogc) {
                    $r->{s} .= " 903$1";
                    push @{$r->{time_var_Arr}}, _codeTable4077($1, 'End');
                }
                push @s3, { $type => $r };
            # group 918sqDp (959vpDp) nature and/or type of squall
            # group 919MwDa (959vpDp)
            #                  waterspout(s), tornadoes, whirlwinds, dust devils
            } elsif (m{\G(91([89])(\d)(\d)) }gc) {
                my $type = qw(squall windPhenom)[$2 - 8];
                $r = { s             => $1,
                       "${type}Type" => $3,
                       location      => +{ _codeTable0700 '', $4,
                                                          qw(Dp Da)[$2 - 8] }
                };
                delete $r->{location}
                    unless keys %{$r->{location}};
                _check_959vpDp $r;
                push @s3, { $type => $r };
            # group 92[01]SFx - state of the sea and maximum wind force
            } elsif (m{\G92([01])([\d/])([\d/]) }gc) {
              push @s3, { seaCondition => {
                  s  => "92.$2.",
                  $2 ne '/' ? (seaCondVal => $2) : (notAvailable => undef)
              }};
              push @s3, { maxWindForce => {
                  s => "92$1.$3",
                  $3 ne '/' ? (timeBeforeObs => { hours => $period },
                               windForce     => { v => $1 * 10 + $3 })
                            : (notAvailable => undef)
              }};
            # group 923S'S
            } elsif (m{\G923([\d/])([\d/]) }gc) {
              push @s3, { alightingAreaCondition => {
                  s => "923$1",
                  $1 ne '/' ? (seaCondVal => $1) : (notAvailable => undef)
              }};
              push @s3, { seaCondition => {
                  s => $2,
                  $2 ne '/' ? (seaCondVal => $2) : (notAvailable => undef)
              }};
            # group 924SVs - state of the sea and visibility seawards
            } elsif (m{\G924([\d/])([\d/]) }gc) {
                push @s3, { seaCondition => {
                    s => "924$1",
                    $1 ne '/' ? (seaCondVal => $1) : (notAvailable => undef)
                }};
                if ($2 ne '/') {
                    push @s3, { visibilityAtLoc => {
                        s          => $2,
                        locationAt => 'MAR',
                        visibility => { distance => (
                              $2 == 0
                            ? { v => 50, u => 'M', q => 'isLess' }
                            : $2 == 9
                            ? { v => 50, u => 'KM', q => 'isEqualGreater' }
                            : ({ v =>  50, rp => 150, u => 'M'  },
                               { v => 200, rp => 300, u => 'M'  },
                               { v => 500, rp => 500, u => 'M'  },
                               { v =>   1, rp =>   1, u => 'KM' },
                               { v =>   2, rp =>   2, u => 'KM' },
                               { v =>   4, rp =>   6, u => 'KM' },
                               { v =>  10, rp =>  10, u => 'KM' },
                               { v =>  20, rp =>  30, u => 'KM' },
                               )[$2 - 1])
                        }}};
                } else {
                    push @s3, { visibilityAtLoc => {
                        s            => '/',
                        locationAt   => 'MAR',
                        notAvailable => undef
                    }};
                }
            # group 925TwTw
            } elsif (m{\G(925(\d\d|//)) }gc) {
              push @s3, { waterTemp => {
                  s  => $1,
                  $2 ne '//' ? (temp => { v => $2 + 0, u => 'C' })
                             : (notAvailable => undef)
              }};
            # group 926S0i0 - hoar frost
            } elsif (/\G(926([01])([0-2])) /gc) {
                push @s3, { hoarFrost => {
                    s            => $1,
                    hoarFrostVal => qw(horizSurface horizVertSurface)[$2],
                    phenomDescr  => qw(isSlight isModerate isHeavy)[$3]
                }};
            # group 926S0i0 - coloured precipitation
            } elsif (/\G(926([23])([0-2])) /gc) {
                push @s3, { colouredPrecip => {
                    s                 => $1,
                    colouredPrecipVal => qw(sand volcanicAsh)[$2 - 2],
                    phenomDescr       => qw(isSlight isModerate isHeavy)[$3]
                }};
            # group 927S6Tw - frozen deposit
            } elsif (m{\G(927([0-7/])([\d/])) }gc) {
                push @s3, { frozenDeposit => {
                    s             => $1,
                    timeBeforeObs => { hours => $period },
                    ($2 ne '/')           ? (frozenDepositType => $2) : (),
                    ($3 ne '/' && $3 < 7) ? (tempVariation     => $3) : ()
                }};
            # group 928S7S'7
            } elsif (/\G(928([0-8])([0-8])) /gc) {
                push @s3, { snowCoverCharReg => {
                    s                   => $1,
                    snowCoverCharacter  => $2,
                    snowCoverRegularity => $3
                }};
            # group 929S8S'8
            } elsif (/\G(929(\d)([0-7])) /gc) {
                push @s3, { driftSnow => {
                    s                  => $1,
                    driftSnowData      => $2,
                    driftSnowEvolution => $3
                }};
            # group (907tt) 930RR
            } elsif (/\G(930(\d\d)) /gc) {
                $r = { s => '', _codeTable3570 $2, 'precipAmount' };
                for (@time_var) {
                    if ($_->{t} == 7) {
                        $r->{s} .= $_->{s} . ' ';
                        $_->{s} = '';
                        push @{$r->{time_var_Arr}}, $_->{r}
                            unless exists $r->{notAvailable};
                        last;
                    }
                }
                $r->{timeBeforeObs}{hours} = $period
                    unless    exists $r->{notAvailable}
                           || exists $r->{time_var_Arr};
                $r->{s} .= $1;
                push @s3, { precipitation => $r };
            # group (90[2467]tt|902zz) 931ss or 931s's'
            } elsif (/\G(931(\d\d)) /gc) {
                $r->{s} = '';
                if ($country eq 'AT' && $obs_hour == 6) {
                    $r->{timeBeforeObs}{hours} = 24;
                } else {
                    $r->{timeBeforeObs}{hours} = $period;
                }
                for (@time_var) {
                    # WMO-No. 306 Vol II, Chapter VI, Section D:
                    if (   $country eq 'CH'
                        && $_->{t} == 7
                        && (   ($_->{v} == 68 && $obs_hour ==  6)
                            || ($_->{v} == 66 && $obs_hour == 18)))
                    {
                        $_->{r} = { timeBeforeObs =>
                                          { hours => $_->{v} == 68 ? 24 : 12 }};
                    }
                    $r->{s} .= $_->{s} . ' ';
                    $_->{s} = '';
                    push @{$r->{time_var_Arr}}, $_->{r};
                    if ($_->{t} == 7) {
                        delete $r->{timeBeforeObs};
                    }
                }
                $r->{s} .= $1;
                # WMO-No. 306 Vol II, Chapter VI, Section D:
                if ($country eq 'FR') { # 931s's'
                    $r->{precipAmount} = { v => $2 + 0, u => 'CM' };
                    $r->{precipAmount}{q} = 'isEqualGreater' if $2 == 99;
                } elsif ($country eq 'AT') {
                    _codeTable3870 \$r, $2;
                    $r->{precipAmount}{v} = 5 if $2 == 97;
                } else {
                    _codeTable3870 \$r, $2;
                }
                push @s3, { snowFall => $r };
            # groups 93[2-7]RR
            } elsif (/\G(93([2-7])(\d\d)) /gc) {
                $r = { s => $1,
                       _codeTable3570 $3,
                                   qw(diameter precipAmount diameter
                                      diameter diameter     diameter)[$2 - 2] };
                push @s3, { qw(hailStones  waterEquivOfSnow glazeDeposit
                               rimeDeposit compoundDeposit  wetsnowDeposit
                              )[$2 - 2] => $r };
            # group (902zz) 96[024]ww
            # group (90[2467]tt) 96[04]ww
            } elsif (/\G(96([024])(\d\d)) /gc) {
                $r->{s} = '';
                if ($2 == 2) {
                    $r->{timeBeforeObs}{hours} = 1;
                } elsif ($2 == 4) {
                    $r->{timeBeforeObs}{hours} = $period;
                }
                for (@time_var) {
                    if ($2 != 2 || $_->{v} > 76) {
                        $r->{s} .= $_->{s} . ' ';
                        $_->{s} = '';
                        push @{$r->{time_var_Arr}}, $_->{r};
                        if ($_->{t} != 6 && $_->{v} < 76) {
                            delete $r->{timeBeforeObs};
                        }
                    }
                }
                $r->{s} .= $1;
                $r->{weatherPresent} = $3 + 0;
                push @s3, { { 0 => 'weatherSynopAdd',
                              2 => 'weatherSynopAmplPast',
                              4 => 'weatherSynopAmpl' }->{$2} => $r };
            # groups (90[2467]tt) (966ww|967w1w1) (903tt)
            } elsif (/\G(966(\d\d)|967($re_synop_w1w1)) /ogc) {
                my $have_period;

                if (defined $2) {
                    $r->{weatherPresent} = $2 + 0;
                } else {
                    $r = _codeTable4687 $3;
                }
                $r->{s} = '';
                for (@time_var) {
                    if ($_->{v} < 70) {
                        $r->{s} .= $_->{s} . ' ';
                        $_->{s} = '';
                        push @{$r->{time_var_Arr}}, $_->{r};
                    }
                }
                $r->{s} .= $1;
                if (/\G903($re_synop_period) /ogc) {
                    $r->{s} .= " 903$1";
                    push @{$r->{time_var_Arr}}, _codeTable4077($1, 'End');
                }
                $have_period = 0;
                for (@{$r->{time_var_Arr}}) {
                    $have_period |= 1
                        if    exists $_->{timeBeforeObs}{occurred}
                           && $_->{timeBeforeObs}{occurred} eq 'Begin';
                    $have_period |= 2
                        if    exists $_->{timeBeforeObs}{occurred}
                           && $_->{timeBeforeObs}{occurred} eq 'End';
                    $have_period |= 3
                        if    !exists $_->{timeBeforeObs}{occurred}
                           || $_->{timeBeforeObs}{occurred} eq 'At';
                }
                if ($have_period == 3) {
                    push @s3, { weatherSynopPast => $r };
                } else {
                    push @{$report{warning}},
                                { warningType => 'notProcessed', s => $r->{s} };
                }
            # group 940Cn3 (958EhDa)
            } elsif (/\G(940(\d)(\d)) /gc) {
                $r = { s => $1, _codeTable0500 $2 };
                $r->{cloudEvol} = $3;
                _check_958EhDa $r;
                push @s3, { cloudEvolution => $r };
            # groups 941CDp, 943CLDp
            } elsif (/\G(94([13])(\d)([1-8])) /gc) {
                push @s3, { qw(cloudFrom XXX lowCloudFrom)[$2 - 1] => {
                             s => $1,
                             $2 == 1 ? _codeTable0500 $3 : (cloudTypeLow => $3),
                             _codeTable0700 '', $4 }};
            } elsif (m{\G(94([13])//) }gc) {
                push @s3, { qw(cloudFrom XXX lowCloudFrom)[$2 - 1] => {
                                s            => $1,
                                notAvailable => undef }};
            } elsif (m{\G(94([13])..) }gc) {
                push @s3, { qw(cloudFrom XXX lowCloudFrom)[$2 - 1] => {
                                s             => $1,
                                invalidFormat => $1 }};
            # groups 942CDa, 944CLDa
            } elsif (/\G(94([24])(\d)(\d)) /gc) {
                push @s3,
                    { qw(maxCloudLocation XXX maxLowCloudLocation)[$2 - 2] => {
                          s        => $1,
                          $2 == 2 ? _codeTable0500 $3 : (cloudTypeLow => $3),
                          location => +{ _codeTable0700 '', $4, 'Da' }
                }};
            # group 945htht (958EhDa)
            } elsif (m{\G(945(\d\d|//)) }gc) {
                $r->{s} = $1;
                if ($2 eq '//') {
                    $r->{notAvailable} = undef;
                } else {
                    my $dist;

                    # TODO: _codeTable1677US is for hshs, only?!?
                    $dist = _codeTable1677 $2;
                    if (!defined $dist) {
                        $r->{invalidFormat} = $2;
                    } elsif (ref $dist eq 'HASH') {
                        $r->{cloudTops} = $dist;
                    } else {
                        $r->{cloudTopsFrom} = $dist->[0];
                        $r->{cloudTopsTo}   = $dist->[1];
                    }
                }
                _check_958EhDa $r;
                push @s3, { cloudTopsHeight => $r };
            # group 948C0Da (958EhDa)
            } elsif (/\G(948([1-9])(\d)) /gc) {
                $r = { s                   => $1,
                       cloudTypeOrographic => $2,
                       location            => +{ _codeTable0700 '', $3, 'Da' }
                };
                _check_958EhDa $r;
                push @s3, { orographicClouds => $r };
            # group 949CaDa (958EhDa) (959vpDp)
            } elsif (/\G(949([0-7])(\d)) /gc) {
                $r = { s                 => $1,
                       # WMO-No. 306 Vol I.1, Part A, code table 0531:
                       cloudTypeVertical => qw(Cuhum Cucon Cb CuCb)[$2 >> 1],
                       phenomDescr       => qw(isIsolated isNumerous)[$2 % 2],
                       location          => +{ _codeTable0700 '', $3, 'Da' }
                };

                _check_958EhDa $r;
                _check_959vpDp $r;
                push @s3, { verticalClouds => $r };
            # group 950Nmn3 (958EhDa)
            } elsif (m{\G(950(\d)([\d/])) }gc) {
                $r = { s               => $1,
                       condMountainLoc => {
                           cloudMountain => $2,
                           $3 ne '/' ? (cloudEvol => $3) : ()
                }};
                _check_958EhDa $r;
                push @s3, { conditionMountain => $r };
            # group 951Nvn4 (958EhDa)
            } elsif (m{\G(951(\d)([\d/])) }gc) {
                $r = { s             => $1,
                       condValleyLoc => {
                           cloudValley => $2,
                           $3 ne '/' ? (cloudBelowEvol => $3) : ()
                }};
                _check_958EhDa $r;
                push @s3, { conditionValley => $r };
            # group 96[135]w1w1
            } elsif (/\G(96([135])($re_synop_w1w1)) /ogc) {
                push @s3, { { 1 => 'weatherSynopAdd',
                              3 => 'weatherSynopAmplPast',
                              5 => 'weatherSynopAmpl' }->{$2} => {
                                s => $1,
                                $2 == 3 ? (timeBeforeObs => { hours => 1 })
                                        : (),
                                $2 == 5 ? (timeBeforeObs => { hours => $period})
                                        : (),
                                %{ _codeTable4687 $3 }
                }};
            # group 97[0-4]EhDa
            } elsif (/\G(97([0-4])([137])(\d)) /gc) {
                push @s3, { maxWeatherLocation => {
                    s                => $1,
                    weatherType      =>
                             qw(present addPresent addPresent1 past1 past2)[$2],
                    # Eh: WMO-No. 306 Vol I.1, Part A, code table 0938:
                    elevAboveHorizon => $3,
                    location         => +{ _codeTable0700 '', $4, 'Da' }
                }};
            # group 97[5-9]vpDp
            } elsif (/\G(97([5-9])(\d)([0-8])) /gc) {
                push @s3, { weatherMovement => {
                    s           => $1,
                    weatherType =>
                         qw(present addPresent addPresent1 past1 past2)[$2 - 5],
                    approaching => _parse_vpDp $3, $4
                }};
            # group 98[0-8]VV
            } elsif (/\G(98([0-8])(\d\d)) /gc) {
                $r = {};
                if ($country eq 'US') {
                    _codeTable4377US $r, $3, $report{obsStationType}{stationType};
                } elsif ($country eq 'CA') {
                    _codeTable4377CA $r, $3;
                } else {
                    _codeTable4377 $r, $3, $report{obsStationType}{stationType};
                }
                if (exists $r->{visPrev}) {
                    $r->{visPrev}{s} = $1;
                    if ($2 != 0 && exists $r->{visPrev}{distance}) {
                        my @dir = _codeTable0700 '', $2;
                        $r->{visPrev}{$dir[0]} = $dir[1];
                    }
                } else {
                    $r->{visibilityAtLoc}{s} = $1;
                    if ($2 != 0) {
                        my @dir = _codeTable0700 '', $2;
                        $r->{visibilityAtLoc}{$dir[0]} = $dir[1];
                    }
                }
                push @s3, $r;
            # group 989VbDa
            } elsif (/\G(989([0-8])(\d)) /gc) {
                push @s3, { visibilityVariation => {
                    s                      => $1,
                    timeBeforeObs          => { hours => 1 },
                    visibilityVariationVal => $2,
                        # WMO-No. 306 Vol I.1, Part A, code table 4332:
                        # Vb=7,8,9: without regard to direction
                    $2 < 7 ? (location => { _codeTable0700 '', $3, 'Da'})
                           : ()
                }};
            # group 990Z0i0
            } elsif (/\G(990(\d)([0-2])) /gc) {
                push @s3, { opticalPhenom => {
                    s                 => $1,
                    opticalPhenomenon => $2,
                    phenomDescr       => { 0 => 'isLight',
                                           1 => 'isModerate',
                                           2 => 'isHeavy' }->{$3}
                }};
            # group 991ADa - mirage
            } elsif (/\G(991([0-8])(\d)) /gc) {
                push @s3, { mirage => {
                                s          => $1,
                                mirageType => $2,
                                location   => +{ _codeTable0700 '', $3, 'Da' }
                }};
            # group 993CSDa (958EhDa)
            } elsif (/\G(993([1-5])(\d)) /gc) {
                $r = { s                => $1,
                       cloudTypeSpecial => $2,
                       location         => +{ _codeTable0700 '', $3, 'Da' }
                };
                _check_958EhDa $r;
                push @s3, { specialClouds => $r };
            # TODO: more 9xxxx stuff
            # } elsif () {
            } else {
                $no_match = 1;
            }

            for (@time_var) {
                push @{$report{warning}},
                                 { warningType => 'notProcessed', s => $_->{s} }
                    if $_->{s} ne '';
            }

            last if $no_match;
        }

        # region I: group 80000 0LnLcLdLg (1sLdLDLve)
        if ($region eq 'I' && /\G80000 /) {
           # TODO
           #while (/\G(?:0(\d{4}))(?: 1(\d{4}))? /gc) {
           #}
        }

=over

=item region IV: B<C<TORNADO/ONE-MINUTE MAXIMUM>> I<x> B<C<KNOTS AT>> I<x> B<C<UTC>>

wind speed for tornado or maximum wind

=back

=cut

        # region IV: group TORNADO/ONE-MINUTE MAXIMUM x KNOTS AT x UTC
        if ($region eq 'IV') {
            # region IV: group TORNADO
            if (m{\G(TORNADO)[ /]}gc) {
                push @s3, { weather => { s => $1, tornado => undef }};
            }

            # region IV: group ONE-MINUTE MAXIMUM x KNOTS AT x UTC
            if (/\G(ONE-MINUTE MAXIMUM ([1-9]\d+) KNOTS AT ($re_hour):($re_min) UTC) /ogc)
            {
                push @s3, { highestMeanSpeed => {
                    s             => $1,
                    timeAt        => { hour => $3, minute => $4 },
                    measurePeriod => { v => 1, u => 'MIN' },
                    wind          => { speed => { v => $2, u => 'KT' }}}};
            }
        }
    }

    if (   exists $report{precipInd}{precipIndVal}
        && (   $report{precipInd}{precipIndVal} == 0
            || $report{precipInd}{precipIndVal} == 2)
        && !$have_precip333)
    {
        push @{$report{warning}}, { warningType => 'precipOmitted3' };
    }

    # skip groups until next section
    push @{$report{warning}}, { warningType => 'notProcessed', s => $1 }
        if /\G(?:(.*?) )??(?=444 )/gc && defined $1;

########################################################################

=head3 SYNOP Section 4: clouds with base below station level (data for national use, optional)

 N'C'H'H'Ct

=for html <!--

=over

=item B<N'C'H'H'Ct>

=for html --><dl><dt><strong>N'C'H'H'C<sub>t</sub></strong></dt><dd>

data for clouds with base below station level

=back

=cut

    if (/\G444 /gc) {
        my @s4;

        @s4  = ();
        $report{section4} = \@s4;

        # group N'C'H'H'Ct
        while (m{\G(([\d/])([\d/])(\d\d)(\d)) }gc) {
            push @s4, { cloudBelowStation => {
                s             => $1,
                cloudOktas    => _codeTable2700($2),
                _codeTable0500($3),

                # WMO-No. 306 Vol I.1, Part A, Section B:
                # H'H' altitude of the upper surface of clouds reported by C',
                #      in hundreds of metres
                cloudTops     => { v => $4 * 100,
                                   u => 'M',
                                   $4 == 99 ? (q => 'isEqualGreater') : ()
                                 },

                # WMO-No. 306 Vol I.1, Part A, Section B:
                # Ct description of the top of cloud whose base is below the
                #    level of the station. (code table 0552)
                cloudTopDescr => $5
            }};
        }
    }

    # skip groups until next section
    push @{$report{warning}}, { warningType => 'notProcessed', s => $1 }
        if /\G(?:(.*?) )??(?=555 )/gc && defined $1;

########################################################################

=head3 SYNOP Section 5: data for national use (optional)

(partially implemented)

 AT:      1snTxTxTx 6RRR/
 BE:      1snTxTxTx 2snTnTnTn
 CA:      1ssss 2swswswsw 3dmdmfmfm 4fhftftfi
 NL:      2snTnTnTn 4snTgTgTg 511ff 512ff
 US land: RECORD* 0ittDtDtD 1snTT snTxTxsnTnTn RECORD* 2R24R24R24R24 44snTwTw 9YYGG
 US sea:  11fff 22fff 3GGgg 4ddfmfm 6GGgg dddfff dddfff dddfff dddfff dddfff dddfff 8ddfmfm 9GGgg
 CZ:      1dsdsfsfs 2fsmfsmfsxfsx 3UU// 5snT5T5T5 6snT10T10T10 7snT20T20T20 8snT50T50T50 9snT100T100T100
 LT:      1EsnT'gT'g (2SnTnTnTn|2snTwTwTw) 3EsnT'gT'g 4E'sss 52snT2T2 530f12f12 6RRRtR 7R24R24R24/ 88R24R24R24
 RU:      1EsnT'gT'g 2snTnTnTn 3EsnTgTg 4E'sss (5snT24T24T24) (52snT2T2) (530f12f12) 7R24R24R24/ 88R24R24R24

=cut

# TODO:
    # WMO-No. 306 Vol II, Chapter VI, Section D:
    #   AR: 1P´HP´HP´HP´H 2CVCVCVCV 3FRFRFRFR 4EVEVEVEV 5dxdxfxfx 55fxfxfx 6HeHeHeIv 64HhHhHh 65HhHhHh 66TsTsTs 67TsTsTs 68Dvhvhv 7dmdmfmfm 74HhHhHh 77fmfmfm 8HmHmHnHn 9RsRsRsRs
    #   NL: 51722 518wawa 53QhQhQh 5975Vm
    #   NO: 0Stzfxfx 1snT'xT'xT'x 2snT'nT'nT'n 3snTgTgTg 4RTWdWdWd
    # other sources:
    #   DE excl. 10320: 0snTBTBTB 1R1R1R1r 2snTmTmTm 22fff 23SS24WRtR 25wzwz26fff 3LGLGLsLs 4RwRwwzwz 5s's's'tR 7h'h'ZD' 8Ns/hshs 910ff 911ff 921ff PIC INp BOT hesnTTT 80000 1RRRRWR 2SSSS 3fkfkfk 4fxkfxkfxk 5RwRw 6VAVAVBVBVCVC 7snTxkTxkTxk 8snTnkTnkTnk 9snTgTgTgsTg
    #   UK and 10320: 7/VQN
    #   CH: 1V'f'/V'f''f'' 2snTwTwTw iiirrr
    #   MD: 8xxxx

    # WMO-No. 306 Vol II, Chapter VI, Section D:
    if ($country eq 'AR' && /\G555 /gc) {
        my @s5;

        @s5  = ();

        # TODO

        $report{section5} = \@s5;
    }

    # WMO-No. 306 Vol II, Chapter VI, Section D:
    if ($country eq 'AT' && /\G555 /gc) {
        my @s5;

        @s5  = ();
        $report{section5} = \@s5;

=for html <!--

=over

=item AT: B<C<1>snTxTxTx>

=for html --><dl><dt>AT: <strong><code>1</code>s<sub>n</sub>T<sub>x</sub>T<sub>x</sub>T<sub>x</sub></strong></dt><dd>

maximum temperature on the previous day from 06:00 to 18:00 UTC

=back

=cut

        # AT: group 1snTxTxTx
        if (m{\G(1(?:([01]\d{3})|////)) }gc) {
            push @s5, { tempMax => {
                s => $1,
                defined $2 ? (temp => _parseTemp($2), timePeriod => '12h18p')
                           : (notAvailable => undef)
            }};
        }

=over

=item AT: B<C<6>RRRC</>>

amount of precipitation on the previous day from 06:00 to 18:00 UTC

=back

=cut

        # AT: group 6RRR/
        if (m{\G(6(\d{3}|///)/) }gc) {
            my $r;

            $r = { s => $1, _codeTable3590 $2 };
            $r->{timePeriod} = '12h18p'
                unless exists $r->{notAvailable};
            push @s5, { precipitation => $r };
        }
    }

    if ($country eq 'BE' && /\G555 /gc) {
        my @s5;

        @s5  = ();
        $report{section5} = \@s5;

=for html <!--

=over

=item BE: B<C<1>snTxTxTx>

=for html --><dl><dt>BE: <strong><code>1</code>s<sub>n</sub>T<sub>x</sub>T<sub>x</sub>T<sub>x</sub></strong></dt><dd>

maximum temperature on the next day from 00:00 to 24:00 UTC

=back

=cut

        # BE: group 1snTxTxTx
        if (m{\G(1(?:([01]\d{3})|////)) }gc) {
            push @s5, { tempMax => {
                s => $1,
                defined $2 ? (temp => _parseTemp($2), timePeriod => 'p')
                           : (notAvailable => undef)
            }};
        }

=for html <!--

=over

=item BE: B<C<2>snTnTnTn>

=for html --><dl><dt>BE: <strong><code>2</code>s<sub>n</sub>T<sub>n</sub>T<sub>n</sub>T<sub>n</sub></strong></dt><dd>

minimum temperature on the next day from 00:00 to 24:00 UTC

=back

=cut

        # BE: group 2snTnTnTn
        if (m{\G(2(?:([01]\d{3})|////)) }gc) {
            push @s5, { tempMin => {
                s => $1,
                defined $2 ? (temp => _parseTemp($2), timePeriod => 'p')
                           : (notAvailable => undef)
            }};
        }
    }

    if ($country eq 'CA' && /\G555 /gc) {         # MANOBS 12.5
        my @s5;

        @s5  = ();
        $report{section5} = \@s5;

=over

=item CA: B<C<1>ssss>

amount of snowfall, in tenths of a centimeter,
for the 24-hour period ending at 06:00 UTC

=back

=cut

        # CA: group 1ssss
        if (m{\G(1(?:(\d{4})|////)) }gc) {
            push @s5, { snowFall => {
                s          => $1,
                timePeriod => '24h06',
                  !defined $2 ? (noMeasurement => undef)
                : $2 == 9999  ? (precipTraces => undef)
                :               (precipAmount =>
                                   { v => sprintf('%.1f', $2 / 10), u => 'CM' })
            }};
        }

=for html <!--

=over

=item CA: B<C<2>swswswsw>

=for html --><dl><dt>CA: <strong><code>2</code>s<sub>w</sub>s<sub>w</sub>s<sub>w</sub>s<sub>w</sub></strong></dt><dd>

amount of water equivalent, in tenths of a millimeter,
for the 24-hour snowfall ending at 06:00 UTC

=back

=cut

        # CA: group 2swswswsw
        if (m{\G(2(?:(\d{4})|////)) }gc) {
            push @s5, { waterEquivOfSnow => {
                s          => $1,
                timePeriod => '24h06',
                  !defined $2 ? (noMeasurement => undef)
                : $2 == 9999  ? (precipTraces => undef)
                :               (precipAmount =>
                                   { v => sprintf('%.1f', $2 / 10), u => 'MM' })
            }};
        }

=for html <!--

=over

=item CA: B<C<3>dmdmfmfm>

=for html --><dl><dt>CA: <strong><code>3</code>d<sub>m</sub>d<sub>m</sub>f<sub>m</sub>f<sub>m</sub></strong></dt><dd>

maximum (mean or gust) wind speed, in knots,
for the 24-hour period ending at 06:00 UTC and its direction

=back

=cut

        # CA: group 3dmdmfmfm
        if (m{\G(3(?:(\d\d|//)(\d\d)|////)) }gc) {
            my $r;

            $r->{s} = $1;
            $r->{timePeriod} = '24h06';
            if (!defined $2) {
                $r->{wind}{notAvailable} = undef;
            } else {
                if ($2 eq '//') {
                    $r->{wind}{dirNotAvailable} = undef;
                } else {
                    $r->{wind}{dir} = { rp => 4, rn => 5 } unless $winds_est;
                    $r->{wind}{dir} = $2 * 10;
                }
                $r->{wind}{speed} = { v => $3, u => 'KT' };
                $r->{wind}{isEstimated} = undef if $winds_est;
            }
            push @s5, { highestWind => $r };

=for html <!--

=over

=item CA: B<C<4>fhftftfi>

=for html --><dl><dt>CA: <strong><code>4</code>f<sub>h</sub>f<sub>t</sub>f<sub>t</sub>f<sub>i</sub></strong></dt><dd>

together with the previous group, the hundreds digit of the maximum wind speed
(in knots), the time of occurrence of the maximum wind speed, and the speed
range of the maximum two-minute mean wind speed,
for the 24-hour period ending at 06:00 UTC and its direction

=back

=cut

            # CA: group 4fhftftfi
            if (m{\G4([01/])($re_hour|//)([0-3/]) }ogc) {
                push @s5, { highestWind => {
                    s          => "4$1$2",
                    timePeriod => '24h06',
                    $2 ne '//' ? (timeAt => { hour => $2 }) : (),
                    wind       =>   $1 eq '/'
                                  ? { notAvailable => undef }
                                  : { speed => {
                                         v => 100,
                                         u => 'KT',
                                         q => $1 ? 'isEqualGreater' : 'isLess'}}
                }};
                push @s5, { highestMeanSpeed => {
                    s             => $3,
                    timePeriod    => '24h06',
                    measurePeriod => { v => 2, u => 'MIN' },
                    wind          =>   $3 eq '/'
                                     ? { notAvailable => undef }
                                     : { speed => (
                                   { v => 17, u => 'KT', q => 'isLess' },
                                   { v => 17, rp => 11, u => 'KT' },
                                   { v => 28, rp => 6,  u => 'KT' },
                                   { v => 34, u => 'KT', q => 'isEqualGreater'}
                                  )[$3] }
                }};
            }
        }
    }

    # WMO-No. 306 Vol II, Chapter VI, Section D:
    if ($country eq 'NL' && /\G555 /gc) {
        my @s5;

        @s5  = ();
        $report{section5} = \@s5;

=for html <!--

=over

=item NL: B<C<2>snTnTnTn>

=for html --><dl><dt>NL: <strong><code>2</code>s<sub>n</sub>T<sub>n</sub>T<sub>n</sub>T<sub>n</sub></strong></dt><dd>

minimum temperature last 14 hours

=back

=cut

        # NL: group 2snTnTnTn
        if (m{\G(2(?:([01]\d{3})|////)) }gc) {
            push @s5, { tempMin => {
                s => $1,
                defined $2 ? (temp          => _parseTemp($2),
                              timeBeforeObs => { hours => 14 })
                           : (notAvailable => undef)
            }};
        }

=for html <!--

=over

=item NL: B<C<4>snTgTgTg>

=for html --><dl><dt>NL: <strong><code>4</code>s<sub>n</sub>T<sub>g</sub>T<sub>g</sub>T<sub>g</sub></strong></dt><dd>

minimum ground (10 cm) temperature last 14 hours

=back

=cut

        # NL: group 4snTgTgTg
        if (m{\G(4(?:([01]\d{3})|////)) }gc) {
            push @s5, { tempMinGround => {
                s => $1,
                defined $2 ? (temp          => _parseTemp($2),
                              timeBeforeObs => { hours => 14 })
                           : (notAvailable => undef)
            }};
        }

=over

=item NL: B<C<511>ff>

maximum wind gust speed last hour

=back

=cut

        # NL: group 511ff
        if (m{\G(511(\d\d|//)) }gc) {
            push @s5, { highestGust => {
                s             => $1,
                wind          => $2 eq '//'
                                 ? { speedNotAvailable => undef }
                                 : { speed => { v => $2 + 0, u => 'MPS' }},
                timeBeforeObs => { hours => 1 }
            }};
        }

=over

=item NL: B<C<512>ff>

maximum mean wind speed last hour

=back

=cut

        # NL: group 512ff
        if (m{\G(512(\d\d|//)) }gc) {
            push @s5, { highestMeanSpeed => {
                s             => $1,
                timeBeforeObs => { hours => 1 },
                wind          => $2 eq '//'
                                 ? { speedNotAvailable => undef }
                                 : { speed => { v => $2 + 0, u => 'MPS' }},
            }};
        }
    }

    # WMO-No. 306 Vol II, Chapter VI, Section D:
    if ($country eq 'NO' && /\G555 /gc) {
        my @s5;

        @s5  = ();
        $report{section5} = \@s5;

        # TODO
    }

    if ($country eq 'US' && /\G555 /gc) {         # FMH-2 7.
        my @s5;

        @s5  = ();
        $report{section5} = \@s5;

        if ($report{obsStationType}{stationType} eq 'AAXX') {

=over

=item US land: B<RECORD>

indicator for temperature record(s)

=back

=cut

            # US land: group RECORD
            while (/\G($re_record_temp_data) /ogc) {
                push @s5, { recordTemp => _getRecordTempData $1 };
            }

=for html <!--

=over

=item US land: B<C<0>ittDtDtD>

=for html --><dl><dt>US land: <strong><code>0</code>i<sub>t</sub>t<sub>D</sub>t<sub>D</sub>t<sub>D</sub></strong></dt><dd>

tide data

=back

=cut

            # US land: group 0ittDtDtD
            if (m{\G(0(?:([134679])(\d{3})|([258])000|0///)) }gc) {
                my $r;

                $r->{s} = $1;
                if (!defined $2 && !defined $4) {
                    $r->{notAvailable} = undef;
                } else {
                    my $type = (($2 // $4) - 1) / 3;
                    $r->{tideType} = qw(low neither high)[$type];
                    if (defined $2) {
                        $r->{tideDeviation} = { v => $3 + 0, u => 'FT' };
                        if ($2 % 3 == 1) {
                            $r->{tideDeviation}{v} *= -1;
                            $r->{tideLevel} = 'below';
                        } else {
                            $r->{tideLevel} = 'above';
                        }
                    } else {
                        $r->{tideDeviation} = { v => 0, u => 'FT' };
                        $r->{tideLevel} = 'equal';
                    }
                }
                push @s5, { tideData => $r };
            }

=for html <!--

=over

=item US land: B<C<1>snTT snTxTxsnTnTn RECORD* C<2>R24R24R24R24>

=for html --><dl><dt>US land: <strong><code>1</code>s<sub>n</sub>TT s<sub>n</sub>T<sub>x</sub>T<sub>x</sub>s<sub>n</sub>T<sub>n</sub>T<sub>n</sub> RECORD* <code>2</code>R<sub>24</sub>R<sub>24</sub>R<sub>24</sub>R<sub>24</sub></strong></dt><dd>

city data: temperature, maximum and minimum temperature, indicator for
temperature record(s), precipitation last 24 hours

=back

=cut

            # US land: groups: 1snTT snTxTxsnTnTn RECORD* 2R24R24R24R24
            if (m{\G1([01])(\d\d) ([01])(\d\d)([01])(\d\d)((?: $re_record_temp_data)*) 2(\d{4}) }ogc)
            {
                my ($tempAirF, $r);

                $tempAirF = $report{temperature}{air}{temp}{v} * 1.8 + 32
                    if    exists $report{temperature}
                       && exists $report{temperature}{air}
                       && exists $report{temperature}{air}{temp};

                # ... group 1snTT
                push @s5, { tempCity => _getTempCity('1', $1, $2, $tempAirF) };

                # ... group snTxTx
                $r = _getTempCity '', $3, $4, $tempAirF;
                if ($obs_hour == 0) {
                    $r->{timeBeforeObs}{hours} = 12;
                } elsif ($obs_hour == 12) {
                    $r->{timePeriod} = 'p';
                } else {
                    $r->{timeBeforeObs}{notAvailable} = undef;
                }
                push @s5, { tempCityMax => $r };

                # ... group snTnTn
                $r = _getTempCity '', $5, $6, $tempAirF;
                if ($obs_hour == 0) {
                    $r->{timeBeforeObs}{hours} = 18;
                } elsif ($obs_hour == 12) {
                    $r->{timeBeforeObs}{hours} = 12;
                } else {
                    $r->{timeBeforeObs}{notAvailable} = undef;
                }
                push @s5, { tempCityMin => $r };

                # ... group 2R24R24R24R24
                $r = { precipCity => {
                    s             => "2$8",
                    timeBeforeObs => { hours => 24 },
                    precipAmount  => { v => sprintf('%.2f', $8 / 100), u =>'IN'}
                }};

                # ... group RECORD
                for ($7 =~ /$re_record_temp_data/og) {
                    push @s5, { recordTempCity => _getRecordTempData $_ };
                }

                push @s5, $r;
            }

=for html <!--

=over

=item US land: B<C<44>snTwTw>

=for html --><dl><dt>US land: <strong><code>44</code>s<sub>n</sub>T<sub>w</sub>T<sub>w</sub></strong></dt><dd>

water temperature

=back

=cut

            # US land: group 44snTwTw
            if (/\G(44([01]\d\d)) /gc) {
                push @s5, { waterTemp => {
                    s    => $1,
                    temp => _parseTemp $2
                }};
            }

=over

=item US land: B<C<9>YYGG>

additional day and hour of observation (repeated from Section 0)

=back

=cut

            # US land: group 9YYGG
            if (/\G(9($re_day)($re_hour)) /ogc) {
                push @s5, { obsTime => {
                    s      => $1,
                    timeAt => { day => $2, hour => $3 }
                }};
            }
        } elsif ($report{obsStationType}{stationType} eq 'BBXX') {

=over

=item US sea: B<C<11>fff C<22>fff>

equivalent wind speeds at 10 and 20 meters

=back

=cut

            # US sea: groups 11fff 22fff
            if (/\G11(\d\d)(\d) 22(\d\d)(\d) /gc) {
                push @s5, { equivWindSpeed => {
                    s            => "11$1$2",
                    wind     => { speed => { v => ($1 + 0).".$2", u => 'MPS' }},
                    sensorHeight => { v => 10, u => 'M'}
                }};
                push @s5, { equivWindSpeed => {
                    s            => "22$3$4",
                    wind     => { speed => { v => ($3 + 0).".$4", u => 'MPS' }},
                    sensorHeight => { v => 20, u => 'M'}
                }};
            }

=for html <!--

=over

=item US sea: B<C<3>GGgg C<4>ddfmfm>

=for html --><dl><dt>US sea: <strong><code>3</code>GGgg <code>4</code>ddf<sub>m</sub>f<sub>m</sub></strong></dt><dd>

maximum wind speed since the last observation and the time when it occurred

=back

=cut

            # US sea: groups 3GGgg 4ddfmfm
            if (/\G(?:3($re_hour)($re_min) )?4($re_dd)(\d\d) /ogc) {
                push @s5, { peakWind => {
                    s      => (defined $1 ? "3$1$2 " : '') . "4$3$4",
                    wind   => { dir   => $3 * 10,
                                speed => { v => $4 + 0, u => 'MPS' }},
                    defined $1 ? (timeAt => { hour => $1, minute => $2 }) : ()
                }};
            }

=over

=item US sea: B<C<6>GGgg>

end time of the latest 10-minute continuous wind measurements

=back

=cut

            # US sea: group 6GGgg
            if (/\G(6($re_hour)($re_min)) /ogc) {
                push @s5, { endOfContWinds => {
                    s      => $1,
                    timeAt => { hour => $2, minute => $3 }
                }};
            }

=over

=item US sea: 6 x B<dddfff>

6 10-minute continuous wind measurements

=back

=cut

            # US sea: 6 x group dddfff
            if (m{\G((?:$re_wind_dir3\d\d\d |////// ){6})}ogc) {
                my ($dir, $whole, $frac);
                for (split ' ', $1) {
                    ($dir, $whole, $frac) = unpack 'a3a2a';
                    push @s5, { continuousWind => {
                        s    => $_,
                        wind => $_ eq '//////'
                                    ? { notAvailable => undef }
                                    : { dir   => $dir + 0,
                                        speed => { v => ($whole + 0) . ".$frac",
                                                   u => 'MPS' }
                                      }
                    }};
                }
            }

=for html <!--

=over

=item US sea: B<C<8>ddfmfm C<9>GGgg>

=for html --><dl><dt>US sea: <strong><code>8</code>ddf<sub>m</sub>f<sub>m</sub> <code>9</code>GGgg</strong></dt><dd>

highest 1-minute wind speed and the time when it occurred

=back

=cut

            # US sea: groups 8ddfmfm 9GGgg
            if (m{\G(8($re_dd|//)(\d\d) 9($re_hour)($re_min)) }ogc) {
                push @s5, { highestMeanSpeed => {
                    s             => $1,
                    measurePeriod => { v => 1, u => 'MIN' },
                    timeAt        => { hour => $4, minute => $5 },
                    wind          => { speed => { v => $3 + 0, u => 'MPS' },
                                       $2 eq '//' ? (dirNotAvailable => undef)
                                                  : (dir => $2 * 10)
                }}};
            }
        }
    }

    # http://www.wmo.int/pages/prog/www/ISS/Meetings/CT-MTDCF_Geneva2005/Doc5-1(3).doc
    if ($country eq 'CZ' && /\G555 /gc) {
        my @s5;

        @s5  = ();
        $report{section5} = \@s5;

=for html <!--

=over

=item CZ: B<C<1>dsdsfsfs>

=for html --><dl><dt>CZ: <strong><code>1</code>d<sub>s</sub>d<sub>s</sub>f<sub>s</sub>f<sub>s</sub></strong></dt><dd>

wind direction and speed from tower measurement

=back

=cut

        # CZ: group 1dsdsfsfs
        if (/\G(1($re_dd|00|99)(\d\d)) /ogc) {
            push @s5, { windAtLoc => {
                s            => $1,
                windLocation => 'TWR',
                wind         => {   $2 == 0  ? (isCalm => undef)
                                  : ($2 == 99 ? (dirVarAllUnk => undef)
                                              : (dir => { v  => ($2 % 36) * 10,
                                                          rp => 4,
                                                          rn => 5 }),
                                     $windUnit ? (speed => { v => $3 + 0,
                                                             u => $windUnit })
                                               : (speedNotAvailable => undef)) }
            }};
        }

=for html <!--

=over

=item CZ: B<C<2>fsmfsmfsxfsx>

=for html --><dl><dt>CZ: <strong><code>2</code>f<sub>sm</sub>f<sub>sm</sub>f<sub>sx</sub>f<sub>sx</sub></strong></dt><dd>

maximum wind gust speed over 10 minute period and the period W1W2

=back

=cut

        # CZ: group 2fsmfsmfsxfsx
        if (/\G2(\d\d)(\d\d) /gc) {
            push @s5, { highestGust => {
                s      => "2$1",
                wind   => {
                          $windUnit ? (speed => { v => $1 + 0, u => $windUnit })
                                    : (speedNotAvailable => undef)
                },
                measurePeriod => { v => 10, u => 'MIN' }
            }};
            push @s5, { highestGust => {
                s      => $2,
                wind   => {
                          $windUnit ? (speed => { v => $2 + 0, u => $windUnit })
                                    : (speedNotAvailable => undef)
                },
                timeBeforeObs => { hours => $period }
            }};
        }

=over

=item CZ: B<C<3>UUC<//>>

relative humidity

=back

=cut

        # CZ: group 3UU//
        if (m{\G3(\d\d)// }gc) {
            push @s5, { RH => {
                s        => "3$1//",
                relHumid => $1 + 0
            }};
        }

=for html <!--

=over

=item CZ: B<C<5>snT5T5T5 C<6>snT10T10T10 C<7>snT20T20T20 C<8>snT50T50T50 C<9>snT100T100T100>

=for html --><dl><dt>CZ: <strong><code>5</code>s<sub>n</sub>T<sub>5</sub>T<sub>5</sub>T<sub>5</sub> <code>6</code>s<sub>n</sub>T<sub>10</sub>T<sub>10</sub>T<sub>10</sub> <code>7</code>s<sub>n</sub>T<sub>20</sub>T<sub>20</sub>T<sub>20</sub> <code>8</code>s<sub>n</sub>T<sub>50</sub>T<sub>50</sub>T<sub>50</sub> <code>9</code>s<sub>n</sub>T<sub>100</sub>T<sub>100</sub>T<sub>100</sub></strong></dt><dd>

soil temperature at the depths of 5, 10, 20, 50, and 100 cm

=back

=cut

        # CZ: groups 5snT5T5T5 6snT10T10T10 7snT20T20T20 8snT50T50T50 9snT100T100T100
        for my $i (5, 6, 7, 8, 9) {
            if (/\G$i([01]\d\d\d) /gc) {
                push @s5, { soilTemp => {
                    s     => "$i$1",
                    depth => { v => (5, 10, 20, 50, 100)[$i - 5], u => 'CM' },
                    temp  => _parseTemp $1
                }};
            }
        }
    }

    # TODO: MD: 8xxxx (ionising radiation [mSv/h])
    # http://meteoclub.ru/index.php?action=vthread&forum=7&topic=3990&page=1#2
    if ($country eq 'MD' && /\G555 /gc) {
        my @s5;

        @s5  = ();
        $report{section5} = \@s5;
    }

    # RU: http://www.meteoinfo.ru/images/misc/kn-01-synop.pdf (2012)
    #     http://www.meteo.parma.ru/doc/serv/kn01.shtml
    # LT: http://www.hkk.gf.vu.lt/nauja/apie_mus/publikacijos/Praktikos_darbai_stanku.pdf (2011)
    if ($country =~ /KZ|LT|RU/ && /\G555 /gc) {
        my @s5;

        @s5  = ();
        $report{section5} = \@s5;

=for html <!--

=over

=item LT, RU: B<C<1>EsnT'gT'g>

=for html --><dl><dt>LT, RU: <strong><code>1</code>Es<sub>n</sub>T'<sub>g</sub>T'<sub>g</sub></strong></dt><dd>

state of the ground without snow or measurable ice cover, temperature of the
ground surface

=back

=cut

        # LT, RU: group 1EsnT'gT'g
        if (m{\G(1([\d/]))([01]\d\d) }gc) {
            push @s5, { stateOfGround => {
                s => $1,
                $2 eq '/' ? (notAvailable => undef) : (stateOfGroundVal => $2)
            }};
            push @s5, { soilTemp => {
                s     => $3,
                depth => { v => 0, u => 'CM' },
                temp  => _parseTemp $3
            }};
        }

=for html <!--

=over

=item LT, RU: B<C<2>snTnTnTn>

=for html --><dl><dt>LT, RU: <strong><code>2</code>s<sub>n</sub>T<sub>n</sub>T<sub>n</sub>T<sub>n</sub></strong></dt><dd>

minimum temperature last night

=back

=cut

        # LT, RU: group 2snTnTnTn
        if (m{\G(2(?:([01]\d{3})|[01/]///)) }gc) {
            push @s5, { tempMinNighttime => {
                s => $1,
                defined $2 ? (temp => _parseTemp $2) : (notAvailable => undef)
            }};
        }

=for html <!--

=over

=item LT, RU: B<C<3>EsnTgTg>

=for html --><dl><dt>LT, RU: <strong><code>3</code>Es<sub>n</sub>T<sub>g</sub>T<sub>g</sub></strong></dt><dd>

state of the ground without snow or measurable ice cover, minimum temperature
of the ground surface last night

=back

=cut

        # LT, RU: group 3EsnTgTg
        if (m{\G3([\d/])([01]\d\d) }gc) {
            push @s5, { stateOfGround => {
                s => "3$1",
                $1 eq '/' ? (notAvailable => undef) : (stateOfGroundVal => $1)
            }};
            push @s5, { soilTempMin => {
                s          => $2,
                depth      => { v => 0, u => 'CM' },
                temp       => _parseTemp($2),
                timePeriod => 'n'
            }};
        }

=over

=item LT, RU: B<C<4>E'sss>

state of the ground if covered with snow or ice, snow depth

=back

=cut

        # LT, RU: group 4E'sss
        if (m{\G4([\d/])(///|\d{3}) }gc) {
            push @s5, { stateOfGroundSnow => {
                s => "4$1",
                $1 eq '/' ? (notAvailable => undef)
                          : (stateOfGroundSnowVal => $1)
            }};
            push @s5, { snowDepth => { s => $2, _codeTable3889 $2 }};
        }

        # TODO: RU: 5snT24T24T24 (average air temperature previous day)
        if (m{\G(5[01][\d/]{3}) }gc) {
            push @{$report{warning}},
                                     { warningType => 'notProcessed', s => $1 };
        }

=for html <!--

=over

=item LT, RU: B<C<52>snT2T2>

=for html --><dl><dt>LT, RU: <strong><code>52</code>s<sub>n</sub>T<sub>2</sub>T<sub>2</sub></strong></dt><dd>

minimum air temperature at 2 cm last 12 hours (last night)

=back

=cut

        # LT, RU: 52snT2T2
        if (m{\G(52([01]\d\d)) }gc) {
            push @s5, { tempMinGround => {
                s             => $1,
                sensorHeight  => { v => 2, u => 'CM' },
                temp          => _parseTemp($2),
                timeBeforeObs => { hours => 12 }
            }};
        }

=for html <!--

=over

=item LT, RU: B<C<530>f12f12>

=for html --><dl><dt>LT, RU: <strong><code>530</code>f<sub>12</sub>f<sub>12</sub></strong></dt><dd>

maximum wind gust speed in the last 12 hours

=back

=cut

        # LT, RU: 530f12f12
        if (m{\G(530(\d\d)) }gc) {
            push @s5, { highestGust => {
                s      => $1,
                wind   => {
                          $windUnit ? (speed => { v => $2 + 0, u => $windUnit })
                                    : (speedNotAvailable => undef)
                },
                timeBeforeObs => { hours => 12 }
            }};
        }

=for html <!--

=over

=item LT, RU: B<C<6>RRRtR>

=for html --><dl><dt>LT, RU: <strong><code>6</code>RRRt<sub>R</sub></strong></dt><dd>

amount of precipitation for given period

=back

=cut

        # LT, RU: group 6RRRtR
        if (m{\G(6(\d{3})(\d)) }gc) {
            push @s5, { precipitation => {
                s => $1,
                _codeTable3590($2),
                timeBeforeObs => _codeTable4019 $3
            }};
        }

=for html <!--

=over

=item LT, RU: B<C<7>R24R24R24C</>>

=for html --><dl><dt>LT, RU: <strong><code>7</code>R<sub>24</sub>R<sub>24</sub>R<sub>24</sub><code>/</code></strong></dt><dd>

amount of precipitation in the last 24 hours

=back

=cut

        # LT, RU: group 7R24R24R24/
        if (m{\G(7(\d{3})/) }gc) {
            push @s5, { precipitation => {
                s => $1,
                _codeTable3590($2),
                timeBeforeObs => { hours => 24 }
            }};
        }

=for html <!--

=over

=item LT, RU: B<C<88>R24R24R24>

=for html --><dl><dt>LT, RU: <strong><code>88</code>R<sub>24</sub>R<sub>24</sub>R<sub>24</sub></strong></dt><dd>

amount of precipitation in the last 24 hours if >=30 mm (to confirm the values
in 7R24R24R24/)

=back

=cut

        # LT, RU: group 88R24R24R24
        if (m{\G(88(\d{3})) }gc) {
            push @s5, { precipitation => {
                s             => $1,
                timeBeforeObs => { hours => 24 },
                precipAmount  => { v => $2 + 0, u => 'MM' }
            }};
        }

# TODO: 912ff (maximum wind speed since 12 hours (or previous day?, but reported
# at 00 and 12)
# http://meteoclub.ru/index.php?action=vthread&forum=7&topic=3990#20
    }

    # TODO: section 6 DE: 666 1snTxTxTx 2snTnTnTn 3snTnTnTn 6VMxVMxVMxVMx 7VMVMVMVM 80000 0RRRrx 1RRRrx 2RRRrx 3RRRrx 4RRRrx 5RRRrx

    # skip groups until section 9
    push @{$report{warning}}, { warningType => 'notProcessed', s => $1 }
        if /\G(?:(.*?) )??(?=999 )/gc && defined $1;

########################################################################

=head3 SYNOP Section 9: data for national use (optional)

(partially implemented)

 DE: 0dxdxfxfx

=cut

    # http://www.met.fu-berlin.de/~manfred/fm12.html
    if ($country eq 'DE' && /\G999 /gc) {
        my @s9;

        @s9  = ();
        $report{section9} = \@s9;

=for html <!--

=over

=item DE: B<C<0>dxdxfxfx>

=for html --><dl><dt>DE: <strong><code>0</code>d<sub>x</sub>d<sub>x</sub>f<sub>x</sub>f<sub>x</sub></strong></dt><dd>

maximum wind gust direction and speed in the last 3 hours

=back

=cut

        # DE: group 0dxdxfxfx
        if (m{\G(0($re_dd)(\d\d)) }ogc) {
            push @s9, { highestGust => {
                s             => $1,
                wind          => { speed => { v => $3 + 0, u => 'MPS' },
                                   dir   => { v => $2 * 10, rp => 4, rn => 5 }},
                timeBeforeObs => { hours => 3 }
            }};
        }

        # TODO: 2snTgTgTg 3E/// 4E'/// 7RRRzR
    }

    push @{$report{warning}}, { warningType => 'notProcessed',
                                s           => substr $_, pos, -1 }
        if length != pos;

    return %report;
}

########################################################################
# _parseSao
########################################################################
sub _parseSao {
    my (%report, $msg_hdr, $is_auto, $has_lt, $is_SAWR);

    $report{msg} = $_;

    if (/^ERROR -/) {
        pos = 0;
        $report{ERROR} = _makeErrorMsgPos 'other';
        return %report;
    }

=head2 Parsing of SAO messages

SAO (Surface Aviation Observation) was the official format of aviation weather
reports until 1996-06-03. However, it is still (as of 2012) used by some
automatic stations in Canada (more than 600) and in the US (PACZ, PAEH, PAIM,
PALU, PATC, PATL), being phased out).

=head3 Observational data for aviation requirements

 CA: III (SA|SP|RS) GGgg AUTOi <sky> V.VI PPI PPP/TT/TdTd/ddff(+fmfm)/AAA/RRRR (remarks) appp TTdOA
 US: CCCC (SA|SP|RS) GGgg AWOS <sky> V PPI TT/TdTd/ddff(Gfmfm)/AAA (remarks)

If the delimiter is a 'C<E<lt>>' (less than) instead of a 'C</>' (slash), the
parameter exceeds certain quality control soft limits.

=cut

    # temporarily remove and store keyword for message type
    $msg_hdr = '';
    $msg_hdr = $1
        if s/^(METAR |SPECI )//;

    # EXTENSION: preprocessing
    # remove trailing =
    s/ ?=$//;

    $_ .= ' '; # this makes parsing much easier

    # restore keyword for message type
    $_ = $msg_hdr . $_;
    pos = length $msg_hdr;

    # warn about modification
    push @{$report{warning}}, { warningType => 'msgModified',
                                s           => substr $_, 0, -1 }
        if $report{msg} . ' ' ne $_;

=over

=item CA: B<III>

reporting station (ICAO location indicator without leading C<C>)

=item US: B<CCCC>

reporting station (ICAO location indicator)

=back

=cut

    if (!/\G($re_ICAO) /ogc) {
        $report{ERROR} = _makeErrorMsgPos 'obsStation';
        return %report;
    }
    $report{obsStationId}{id} = $1;
    $report{obsStationId}{s} = $1;

    _cySet $report{obsStationId}{id};

=over

=item optional: B<C<NIL>>

message contains no observation data, end of message

=back

=cut

    if (/\GNIL $/) {
        $report{reportModifier}{s} =
            $report{reportModifier}{modifierType} = 'NIL';
        return %report;
    }

=over

=item B<C<SA>> |  B<C<RS>> |  B<C<SP>>

report type:

=over

=item C<SA>

Record Observation, scheduled

=item C<RS>

(Record Special) on significant change in weather

=item C<SP>

(Special), observation taken between Record Observations on significant change
in weather

=back

=item B<GGgg>

hour, minute of observation

=back

=cut

    if (!/\G(S[AP]|RS)(?: (COR))? ($re_hour)($re_min) /ogc) {
        $report{ERROR} = _makeErrorMsgPos 'obsTime';
        return %report;
    }
    $report{isSpeci} = undef unless $1 eq 'SA';
    push @{$report{reportModifier}}, { s => $2, modifierType => $2 }
        if defined $2;
    $report{obsTime} = {
        s      => "$3$4",
        timeAt => { hour => $3, minute => $4 }
    };

=over

=item CA: B<C<AUTO>i>

station type:

=over

=item C<AUTO1>

MARS I

=item C<AUTO2>

MARS II

=item C<AUTO3>

MAPS I

=item C<AUTO4>

MAPS II

=item C<AUTO7>

non-AES automatic station

=item C<AUTO8>

other AES automatic station

=back

=item US: B<C<AWOS>> (Automated Weather Observing Systems)

reports ceiling/sky conditions, visibility, temperature, dew point, wind
direction/speeds/gusts, altimeter setting, automated remarks containing density
altitude, variable visibility and variable wind direction, precipitation
accumulation

=item US: B<C<AMOS>> (Automatic Meteorological Observing Station)

reports temperature, dew point, wind direction and speed, pressure (altimeter
setting), peak wind speed, precipitation accumulation

=item US: B<C<AUTOB>> (Automatic Observing Station)

like C<AMOS> but with sky conditions, visibility and precipitation occurrence

=item US: B<C<RAMOS>> (Remote Automatic Meteorological Observing System)

like C<AMOS> but with 3-hour pressure change, maximum/minimum temperature, and
24-hour precipitation accumulation

=item B<C<SAWR>> (Supplemental Aviation Weather Report)

unscheduled and made by observers at stations not served by a regularly
reporting weather station

=back

=cut

    if (/\G(AUTO\d?|AWOS) /gc) {
        push @{$report{reportModifier}}, { s => $1, modifierType => 'AUTO' };
        $is_auto = $1;
    }

    # CWKV:
    if (/\G(SAWR) /gc) {
        $is_SAWR = 1;
        push @{$report{remark}},
                           { obsStationType => { s => $1, stationType => $1 } };
    }

=over

=item sky

can be C<M> or C<MM> (missing), C<CLR> or C<CLR BLO ...>, C<W...> (vertical
visibility), or optionally C<X> or C<-X> (sky (partially) obstructed) and one or
more cloud groups. If the height is prefixed by C<E> or C<M>, this is the
estimated or measured ceiling. If the height is suffixed by C<V> it is variable.
If the cloud cover is prefixed by C<->, the cover is thin.

=back

=cut

    if (/\G(MM?) /gc) {
        $report{cloud} = { s => $1, notAvailable => undef };
    } elsif (/\G(CLR BLO \d+) /gc) {
        $report{cloud} = {
            s        => $1,
            noClouds => 'NCD'
        };
    } elsif (/\G(CLR) /gc) {
        $report{cloud} = {
            s        => $1,
            noClouds => $1
        };
    } elsif (/\G($re_cloud_cov) /ogc) {
        $report{cloud} = {
            s => $1,
            cloudCover => $1,
            cloudBaseNotAvailable => undef
        };
    } else {
        my $had_ceiling = 0;

        while (   /\G([MABE]?)(\d+)(V?) (-?)($re_cloud_cov) /ogc
               || /\G(?:([APW]?)(\d+) )?(-?X) /gc)
        {
            if (defined $5) {
                my $r;
                $r = _parseCloud $5 . sprintf('%03d', $2),
                                   $1 eq 'E' ? 'isEstimated'
                                 : $3 eq 'V' ? 'isVariable'
                                 :             undef
                                 ;
                $r->{s} = "$1$2$3 $4$5";
                if ($1 && !$had_ceiling) {
                    $r->{isCeiling} = undef;
                    $had_ceiling = 1;
                }
                $r->{cloudCover}{q} = 'isThin'
                    if exists $r->{cloudCover} && $4 eq '-';
                push @{$report{cloud}}, $r;
            } else {
                $report{visVert} = {
                    s        => "$1$2",
                    distance => _codeTable1690 $2
                }
                    if defined $2;
                $report{skyObstructed} = {
                    s => $3,
                    $3 eq '-X' ? (q => 'isPartial') : ()
                };
            }
        }
    }

=for html <!--

=over

=item CA: B<V.VI>

=for html --><dl><dt>CA: <strong>V.V<sub>I</sub></strong></dt><dd>

prevailing visibility (in SM), optionally with tenths. Optionally, B<I> can be
C<V> (variable) or C<+> (greater than).

=item US: B<V>

prevailing visibility (in SM), optionally with fractions of SM

=back

=cut

    if (/\GM /gc) {
        $report{visPrev} = { s => 'M', notAvailable => undef };
    } else {
        if (/\G(\d+\.\d?)([V+]?) ?/ogc) {
            $report{visPrev} = {
                s        => "$1$2",
                distance => {
                    v => $1,
                    u => 'SM',
                    $2 eq 'V' ? (q => 'isVariable') : (),
                    $2 eq '+' ? (q => 'isGreater') : ()
                }
            };
            $report{visPrev}{distance}{v} =~ s/\.$//;
        } elsif (/\G($re_vis_sm)(V?) ?/ogc) {
            if ($2) {
                $report{visPrev}{distance} = _parseFraction $1, 'SM';
                # TODO?: if reported together with M1/4 this overwrites @q
                $report{visPrev}{distance}{q} = 'isVariable';
            } else {
                $report{visPrev} = _getVisibilitySM $1, $is_auto;
            }
            $report{visPrev}{s} = "$1$2";
        }
    }

=for html <!--

=over

=item PPI

=for html --><dl><dt><strong>PP<sub>I</sub></strong></dt><dd>

groups to describe the present weather: precipitation (C<L>, C<R>, C<S>, C<SG>,
C<IP>, C<A>, C<S>C<P>, C<IN>, C<U>), obscuration (C<F>, C<K>, C<BD>, C<BN>,
C<H>) or other (C<PO>, C<Q>, C<T>).
Certain precipitation and duststorm can have the intentsity (C<+>, C<-> or
C<-->) appended.

=back

=cut

    if (/\GM /gc) {
        $report{weather} = { s => 'M', notAvailable => undef };
    } else {
        #   R R- R+ ZR ZR- ZR+ RW RW- RW+
        #   L L- L+ ZL ZL- ZL+
        #   S S- S+            SW SW- SW+
        #   A A- A+
        #   T
        #   IP IP- IP+         IPW IPW- IPW+
        #   SG SG- SG+
        #   SP SP- SP+         SPW
        #   BN BN+
        #   BS BS+
        #   BD BD+
        #   IC IC- IC+
        #   H K D F Q V
        #   IF IN AP PO UP GF BY

        # TODO: TR should be TSRA, not TS RA
        # from www.nco.ncep.noaa.gov/pmb/.../gemlib/pt/ptwcod.f (nawips.tar)
        while (   /\G((TORNA|FUNNE|WATER|BD\+?|IF|IN|AP|PO|U?P|GF|BY|[THKDFQ])()()()) ?/gc
               || /\G((B[SN]()())(\+?)) ?/gc
               || /\G((S[GP]|IC|[LA]|(?:R|S|IP)(W?)|(Z)[RL])((?:\+|--?)?)) ?/gc)
        {
            push @{$report{weather}}, {
                s => $1,
                # from www.nco.ncep.noaa.gov/pmb/.../prmcnvlib/pt/ptwsym.f
                # numbers: WMO-No. 306 Vol I.1, Part A, code table 4677
                $2 eq 'TORNA' || $2 eq 'FUNNE' || $2 eq 'WATER' # all 19
                  ? (tornado => {
                      TORNA => 'tornado',
                      FUNNE => 'funnel_cloud',
                      WATER => 'waterspout'
                    }->{$2})
                  : (phenomSpec => {
                      K     => 'FU',     # 4
                      H     => 'HZ',     # 5
                      D     => 'DU',     # 6
                      N     => 'SA', BD => 'DU', BN => 'SA', # 7
                      PO    => 'PO',     # 8
                      F     => 'FG',     # 10
                      GF    => 'FG',     # 12
                      T     => 'TS',     # 17
                      Q     => 'SQ',     # 18
                      'BD+' => 'DS',     # 34
                      BS    => 'SN',     # 38
                      IF    => 'FG',     # 48
                      L     => 'DZ',     # 53
                      ZL    => 'DZ',     # 57
                      R     => 'RA',     # 63
                      ZR    => 'RA',     # 67
                      S     => 'SN',     # 73
                      IN    => 'IC',     # 76
                      SG    => 'SG',     # 77
                      IC    => 'IC',     # 78
                      IP    => 'PL',     # 79
                      RW    => 'RA',     # 81
                      SW    => 'SN',     # 86
                      AP    => 'GS', SPW => 'GS', SP => 'GS', IPW => 'PL', # 88
                      A     => 'GR',     # 90
                    # V     => '??',     # 201 variable visibility
                      BY    => 'PY',     # 202
                      UP    => 'UP', P => 'UP', # 203
                    }->{$2}),
                $3 || $2 eq 'AP' ? (descriptor => 'SH') : (),
                $4 || $2 eq 'IF' ? (descriptor => 'FZ') : (),
                { map { $_ => 1 } qw(N BD BN BS BY) }->{$2}
                    ? (descriptor => 'BL') : (),
                $2 eq 'GF' ? (descriptor => 'MI') : (),
                ($5 eq '+' || $2 eq 'BD+') ? (phenomDescr => 'isHeavy') : (),
                $5 eq '-' ? (phenomDescr => 'isLight') : (),
                $5 eq '--' ? (phenomDescr => 'isVeryLight') : ()
            };
        }
    }

=over

=item CA: B<PPP>

mean sea level pressure (in hPa, last 3 digits)

=back

=cut

    ($has_lt) = /\G([^ ]+)/;
    if (!defined $has_lt) {
        $report{ERROR} = _makeErrorMsgPos 'other';
        return %report;
    }
    push @{$report{warning}}, { warningType => 'qualityLimit', s => '' }
        if $has_lt =~ /</;

    if (m{\G(M|(\d\d)(\d))[</](?=(?:(?:M|-?\d+)[</]){2}(?:E?[M\d]{4}))}gc) {
        if (defined $2) {
            if ($2 > 65 || $2 < 45) { # only if within sensible range
                my $slp;

                $slp = "$2.$3";
                # threshold 55 taken from mdsplib
                $slp += $slp < 55 ? 1000 : 900;
                push @{$report{remark}}, { SLP => {
                    s        => $1,
                    pressure =>
                              { v => sprintf('%.1f', $slp), u => 'hPa' }
                }};
            } else {
                push @{$report{remark}}, { SLP => {
                    s => $1,
                    invalidFormat => "no QNH, x$2.$3 hPa"
                }};
            }
        } else {
            push @{$report{remark}}, { SLP => {
                s            => $1,
                notAvailable => undef
            }};
        }
    }

=for html <!--

=over

=item B<TT>C</>B<TdTd>

=for html --><dl><dt><strong>TT</strong><code>/</code><strong>T<sub>d</sub>T<sub>d</sub></strong></dt><dd>

air temperature and dew point temperature (CA: in E<deg>C, US: in F). Both or
either can be C<MM> (missing).

=back

=cut

    # temperature in F may have 3 digits (100 F = 37.8 °C)
    if (m{\G((?:M|(-?\d+))[</](?:M|(-?\d+)))[</](?=E?[M\d]{4})}gc) {
        my $temp_unit;

        $temp_unit = _cyIsC(' C ') ? 'C' : 'F';
        $report{temperature}{s} = $1;
        if (!defined $2) {
            $report{temperature}{air}{notAvailable} = undef;
        } else {
            $report{temperature}{air}{temp} = { v => $2 + 0, u => $temp_unit };
        }

        if (!defined $3) {
            $report{temperature}{dewpoint}{notAvailable} = undef;
        } else {
            $report{temperature}{dewpoint}{temp} =
                                               { v => $3 + 0, u => $temp_unit };
        }

        _setHumidity $report{temperature};
    }

=for html <!--

=over

=item CA: B<ddff>(B<+fmfm>), US: B<ddff>(B<Gfmfm>)

=for html --><dl><dt>CA: <strong>ddff</strong>(<strong><code>+</code>f<sub>m</sub>f<sub>m</sub></strong>), US: <strong>ddff</strong>(<strong><code>G</code>f<sub>m</sub>f<sub>m</sub></strong>)</dt><dd>

wind direction and speed (in KT), optionally gust speed, or C<MMMM> (missing).
If the direction is greater than 50, 100 must be added to the speed(s) and 50
subtracted from the direction.

=back

=cut

    if (!m{\G((E)?(MM|$re_wind_dir|5[1-9]|[67]\d|8[0-6])(MM|\d\d)(?:[+G](\d\d))?(E)?)(?=[</ ])}ogc) {
        $report{ERROR} = _makeErrorMsgPos 'other';
        return %report;
    }
    $report{sfcWind}{s} = $1;
    if ($3 eq 'MM' && $4 eq 'MM') {
        $report{sfcWind}{wind}{notAvailable} = undef;
    } elsif ($3 eq '00' && $4 eq '00' && !defined $5) {
        $report{sfcWind}{wind}{isCalm} = undef;
        $report{sfcWind}{wind}{isEstimated} = undef
            if defined $2 || defined $6;
    } else {
        my $plus_100 = 0;

        if ($3 eq 'MM') {
            $report{sfcWind}{wind}{dirNotAvailable} = undef;
        } else {
            $report{sfcWind}{wind}{dir} = { rp => 4, rn => 5 }
                unless defined $2;
            if ($3 > 50) {
                $plus_100 = 100;
                $report{sfcWind}{wind}{dir}{v} = ($3 - 50) * 10;
            } else {
                $report{sfcWind}{wind}{dir}{v} = $3 * 10;
            }
        }
        if ($4 eq 'MM') {
            $report{sfcWind}{wind}{speedNotAvailable} = undef;
        } else {
            $report{sfcWind}{wind}{speed} = { v => $4 + $plus_100, u => 'KT' };
        }
        $report{sfcWind}{wind}{gustSpeed} = { v => $5 + $plus_100, u => 'KT' }
            if defined $5;
        # US: FMH-1 5.4.3, CA: MANOBS 10.2.15
        $report{sfcWind}{measurePeriod} = { v => 2, u => 'MIN' };
        $report{sfcWind}{wind}{isEstimated} = undef
            if defined $2 || defined $6;
    }

=over

=item B<AAA>

altimeter setting (in hundredths of inHg, last 3 digits), or C<M> (missing)

=back

=cut

    if (m{\G[</] ?(M|(E)?([0189])(\d\d))(?=[ </])}gc) {
        if ($1 eq 'M') {
            $report{QNH} = { s => $1, notAvailable => undef };
        } else {
            $report{QNH} = { s => $1, pressure => {
                v => ($3 > 1 ? "2$3" : "3$3") . ".$4",
                u => 'inHg',
                defined $2 ? (q => 'isEstimated') : ()
            }};
        }
        /\G /gc;
    }

=over

=item CA: B<RRRR>

precipitation since previous main synoptic hour (tenths of mm)

=back

=cut

    if (   _cyIsC(' C ')
        && (   m{\G[</](M|\d{4}) }gc
            || m{\G[</] (M|\d{4}) (?=(?:.+ )?(?:M|[M0-8]\d{3}) (?:M|-?\d)(?:M|-?\d)[XM0-8]M $)}gc))
    {
        if (defined $1 && $1 eq 'M') {
            push @{$report{remark}},
                { precipitation => { s => $1, notAvailable => undef }};
        } elsif (defined $1) {
            push @{$report{remark}}, { precipitation => {
                s            => $1,
                timeSince    => _timeSinceSynopticMain(
                                  @{$report{obsTime}{timeAt}}{qw(hour minute)}),
                precipAmount => { v => sprintf('%.1f', $1 / 10), u => 'MM' }
            }};
        }
    }

    # end of group with slashes, skip optional trailing slash
    m{\G[</]? ?}gc;

=head3 Remarks

There may be remarks, similar to the ones in METAR.

=cut

    if (/\G(((?:(?:$re_opacity_phenom|BD|BN|BS|BY|B|F|GF|H|IF|K)(?:\d|10))+)(?: ($re_cloud_type) (?:(ASOCTD?)|(EMBDD?)))?) /ogc)
    {
        my $r;

        $r->{s} = $1;
        $r->{opacityPhenomArr} = ();
        _parseOpacityPhenomSao $r, $2;
        $r->{cloudTypeAsoctd} = $3 if defined $4;
        $r->{cloudTypeEmbd}   = $3 if defined $5;
        push @{$report{remark}}, { opacityPhenom => $r };
    }

    if (_cyIsC(' C ') && (my $r = _visVarCA)) {
        push @{$report{remark}}, $r;
    }

    if (_cyIsC('cUS') && (my $r = _visVarUS)) {
        push @{$report{remark}}, $r;
    }

    if (_cyIsC('cUS') && /\GWND ($re_dd)V($re_dd)/ogc) {
        if (exists $report{sfcWind}) {
            $report{sfcWind}{s} .= ' ';
        } else {
            # TODO?: actually not "not available" but missing
            $report{sfcWind} = {
                s    => '',
                wind => { dirNotAvailable => undef, speedNotAvailable => undef }
            };
        }
        $report{sfcWind}{s} .= "$1V$2";
        @{$report{sfcWind}{wind}}{qw(windVarLeft windVarRight)} =
                                                             ($1 * 10, $2 * 10);
    }

    if (   _cyIsC(' C ')
        && (my $r = _precipCA @{$report{obsTime}{timeAt}}{qw(hour minute)}))
    {
        push @{$report{remark}}, $r;
    }

    if ((my $r = _parsePhenoms)) {
        push @{$report{remark}}, $r;
    }

    if (/\G(PCPN (\d+.\d)MM PAST HR) /gc) {
        push @{$report{remark}}, { precipitation => {
            s             => $1,
            timeBeforeObs => { hours => 1 },
            precipAmount  => { v => sprintf('%.1f', $2), u => 'MM' }
        }};
    }

    if (/\G(PK WND (MM|$re_wind_dir)($re_wind_speed) ($re_hour)($re_min)Z) /ogc)
    {
        push @{$report{remark}}, { peakWind => {
            s      => $1,
            wind   => _parseWind(($2 eq 'MM' ? '///' : "${2}0") . "${3}KT", 1),
            timeAt => { hour => $4, minute => $5 }
        }};
    }

    if (/\G(SOG (\d+)) /gc) {
        push @{$report{remark}}, { snowDepth => {
            s            => $1,
            precipAmount => { v => $2 + 0, u => 'CM' }
        }};
    }

    if (/\G((PRES[FR]R)( PAST HR)?) /gc) {
        my $r;

        $r->{s} = $1;
        $r->{otherPhenom} = $2;
        _parsePhenomDescr $r, 'phenomDescrPost', $3 if defined $3;
        push @{$report{remark}}, { phenomenon => $r };
    }

    push @{$report{remark}}, { notRecognised => { s => $1 }}
        if /\G(VSBY) /gc;

    if (m{\G(LAST(?:( STAFFED| STFD)|( MANNED))?(?: OBS?)?(?: ($re_day)($re_hour)($re_min)(?: ?UTC| ?Z)?)?)[ /] ?}ogc)
    {
        my $r;
        $r->{s} = $1;
        $r->{isStaffed} = undef if defined $2;
        $r->{isManned} = undef if defined $3;
        @{$r->{timeAt}}{qw(day hour minute)} = ($4, $5, $6)
            if defined $4;
        push @{$report{remark}}, { lastObs => $r };
    }
    if (/\G(NEXT ($re_day)($re_hour)($re_min)(?: ?UTC| ?Z)?) /ogc){
        my $r;
        $r->{s} = $1;
        @{$r->{timeAt}}{qw(day hour minute)} = ($2, $3, $4)
            if defined $2;
        push @{$report{remark}}, { nextObs => $r };
    }

=head3 CA: Additional groups

=over

=item B<appp>

three-hourly pressure tendency for station level pressure

=back

=for html <!--

=over

=item TTdOC

=for html --><dl><dt><strong>TT<sub>d</sub>OC</strong></dt><dd>

temperature tenths value, dew point tenths value, total opacity (sky hidden, in
tenths), total cloud cover (sky covered, in tenths).

=back

=cut

    if (   _cyIsC(' C ')
        && (   /\G(?:(.*) )?(M|([M0-8])(\d{3})) (M|-?\d)(M|-?\d)([XM\d])([XM\d]) $/gc
            # do not read pressureChange as TTdOC
            || (   ($is_SAWR || !/\G(?:(.*) )?[M0-8]\d{3} $/)
                && /\G(?:(.*) )?()()()(M|-?\d)(M|-?\d)([XM\d])([XM\d]) $/gc)))
    {
        my ($air, $dew);

        push @{$report{remark}}, { notRecognised => { s => $1 }}
            if defined $1;
        push @{$report{remark}}, { pressureChange => {
            s             => $2,
            timeBeforeObs => { hours => 3 },
            defined $3 && $3 ne 'M'
              ? (pressureTendency  => $3,
                 pressureChangeVal => {
                     v => sprintf('%.1f', $4 / ($3 >= 5 ? -10 : 10) + 0),
                     u => 'hPa'
                 })
              : (notAvailable => undef)
        }}
            if $2 ne '';

        $air = '';
        $dew = '';
        if (   $5 ne 'M'
            && exists $report{temperature}
            && exists $report{temperature}{air}
            && exists $report{temperature}{air}{temp})
        {
            $air = _mkTempTenths $report{temperature}{air}{temp}{v}, $5;
        }
        if (   $6 ne 'M'
            && exists $report{temperature}
            && exists $report{temperature}{dewpoint}
            && exists $report{temperature}{dewpoint}{temp})
        {
            $dew = _mkTempTenths $report{temperature}{dewpoint}{temp}{v}, $6;
        }
        if ($air eq 'invalid' or $dew eq 'invalid') {
            push @{$report{remark}}, { temperature => {
                s             => "$5$6",
                invalidFormat => "$5$6"
            }};
        } elsif ($air ne '' || $dew ne '') {
            my $r;

            $r = {
                s => "$5$6",
                $air ne '' ? (air      => { temp => { v=>$air, u=>'C' }}) : (),
                $dew ne '' ? (dewpoint => { temp => { v=>$dew, u=>'C' }}) : (),
            };
            _setHumidity $r;
            push @{$report{remark}}, { temperature => $r };
        }

        if ($7 ne 'M') {
            push @{$report{remark}}, { totalOpacity => {
                s => $7,
                (tenths => $7 eq 'X' ? 10 : $7)
            }};
        }
        if ($8 ne 'M') {
            push @{$report{remark}}, { totalCloudCover => {
                s => $8,
                (tenths => $8 eq 'X' ? 10 : $8)
            }};
        }
    }

    push @{$report{remark}}, { notRecognised => { s => $1 }}
        if /\G(.+) /gc;
    return %report;
}

########################################################################
# _parseMetarTaf
########################################################################
sub _parseMetarTaf {
    my $default_msg_type = shift;
    my (%metar, $is_taf, $msg_hdr, $is_auto, $is_taf_Aug2007, $s_preAug2007);
    my ($obs_hour, $old_pos, $winds_est, $winds_grid, $qnhInHg, $qnhHPa);
    my $had_NOSIG;

    $metar{msg} = $_;
    $metar{isSpeci} = undef if $default_msg_type eq 'SPECI';
    $metar{isTaf}   = undef if $default_msg_type eq 'TAF';

    if (/^ERROR -/) {
        pos = 0;
        $metar{ERROR} = _makeErrorMsgPos 'other';
        return %metar;
    }

=head2 Parsing of METAR/SPECI and TAF messages

First, the message is checked for typical errors and corrected. Errors for
METARs could be:

=over

=item *

QNH with spaces

=item *

temperature or dew point with spaces

=item *

misspelled keywords, or with missing or additional spaces

=item *

missing keywords

=item *

removal of slashes before and after some components

=back

If the message is modified there will be a C<warning>.

=cut

    $is_taf = exists $metar{isTaf};

    # temporarily remove and store keyword for message type
    $msg_hdr = '';
    $msg_hdr = $1
        if s/^((?:METAR )?LWIS |METAR |SPECI |TAF )//;

    # EXTENSION: preprocessing
    # remove trailing =
    s/ ?=$//;

    $_ .= ' '; # this makes parsing much easier

    # QNH with spaces, brackets, dots
    s/ (?:A[23]|Q[01])\K (?=\d{3} )//;
    s/ (?:A[23]|Q[01])\d\K (?=\d\d )//;
    s/ (?:A[23]|Q[01])\d\d\K (?=\d )//;
    s/ \((A[23]\d)\.?(\d\d)\) / $1$2 /;

    # misspelled keywords, or with missing or additional spaces
    s/ (?:CAMOK|CC?VOK|CAVOC) / CAVOK /;
    s/ (?:NO(?: S)?IG|NOSI(?: G)?|N[L ]OSIG|NSI?G|(?:MO|N0)SIG|NOS I ?G) / NOSIG /;
    s/(?<! )(?=(?:TEMPO|BECMG) )/ /; # BLU+BLU+(TEMPO|BECMG)
    s{ (?:R MK|RMKS|RRMK)[:./]? ?}{ RMK };
    s{ RMK\K[:./] ?}{ };
    s{ RMK\K(?=[^ ])}{ };
    s{ 0VC(?=$re_cloud_base$re_cloud_type?|$re_cloud_type )}{ OVC}og;
    s{ BNK(?=$re_cloud_base$re_cloud_type?|$re_cloud_type )}{ BKN}og;
    s{ $re_cloud_cov\KO(?=\d\d )}{0}og;
    s{ $re_cloud_cov\d\KO(?=\d )}{0}og;
    s{ $re_cloud_cov\d\d\KO(?= )}{0}og;
    s{ VR\K (?=B$re_wind_speed$re_wind_speed_unit )}{}og;
    s{ WND (?:$re_dd|00)0\KMM(?=KT )}{//}og;
    s{ R\K (?=WY)}{}g;
    s{ RW\K (?=Y)}{}g;
    s{ RWY$re_dd\K (?=[LCR] )}{}og;
    s{ RWY$re_dd\K (?=(?:LL|RR) )}{}og;
    s{ RNW }{ RWY }g;
    s{ ?/(?=AURBO )}{ };
    s{ A\K0(?=[12]A? )}{O};
    s{[/ ]ALQ\K(?=S )}{D}g;
    s{[/ ]AL\KL(?=QDS )}{}g;
    s{[/ ]ALQ\KUAD(?= )}{DS}g;
    s{[/ ]A\KQ(?= )}{LQDS}g;
    s{[/ ]AR\KOU(?=ND )}{}g;
    s{ OCNL\KY(?= )}{}g;
    s{ F\KQT(?= )}{RQ}g;
    s{ LIGHTNING }{ LTG }g;
    s{ LTNG }{ LTG }g;
    s{( $re_phen_desc L)GT(?=$re_ltg_types+)}{$1TG}og;
    s{ LTG\K (?=$re_ltg_types{2,})}{}og;
    s{ LTG\K (?=(?:C[ACGW])+)}{}g; # IC could be weather
    s{ I\KN(?=OVC )}{}g;
    s{ SP\KO(?=TS )}{}g;
    s{ W\K (?=IND )}{}g;
    s{ WIND RWY\K (?=$re_rwy_des )}{}og;
    s{ (?:RWY|THR)\K($re_rwy_des ${re_wind_dir}0$re_wind_speed) (?=$re_wind_speed_unit )}{$1}og;
    s{ D\KISTA(?=NT )}{S}g;
    s{[ -]N\KORTH(?=[ -])}{}g;
    s{[ -]S\KOUTH(?=[ -])}{}g;
    s{[ -]E\KAST(?=[ -])}{}g;
    s{[ -]W\KEST(?=[ -])}{}g;
    s{ [+-]?\K(RA|SN)SH(?= )}{SH$1}g;
    s{ SH\K(?:R?S|WR|OWERS?)(?= )}{}g;
    s{ CB\KS(?= )}{}g;
    s{ TCU\KS(?= )}{}g;
    s{ LTG\K[S.](?= )}{}g;
    s{ OV\KE(?=R )}{}g;
    s{ O\KVR MT(?:N?S)?(?= )}{MTNS}g;
    s{ OMT\K(?=S )}{N}g;
    s{ A\K(?:R?PT|D)(?= )}{P}g;
    s{[ -]O\KV?HD?(?=[ -])}{HD}g;
    s{ UNK\K(?= )}{N}g;
    s{ AL\KN(?=G )}{}g;
    s{ ISOL\KD(?= )}{}g;
    s{ H\KA(?=ZY )}{}g;
    s{ DS\K(?=T )}{N}g;
    s{ D\KIS(?=T )}{SN}g;
    s{ DS\KTN(?= )}{NT}g;
    s{ PL\K(?=ME )}{U}g;
    s{ INVIS\KT(?= )}{}g;
    s{ FROIN\K/ ?}{ }g;
    s{ AS\K(?=CTD )}{O}g;
    s{ M\K(?=VD )}{O}g;
    s{ MOV\K(?:(?:IN)?G )}{ }g;
    s{^$re_ICAO $re_day$re_hour$re_min\K(?= )}{Z}o
        unless $is_taf;
    s{^$re_ICAO $re_day$re_hour$re_min\K(?= $re_day$re_hour/$re_day(?:$re_hour|24))}{Z}o
        if $is_taf;
    s{^$re_ICAO $re_day$re_hour$re_min\KKT(?= )}{Z}o;
    s{^$re_ICAO $re_day$re_hour${re_min}Z \K(${re_wind_dir}0)/(?=${re_wind_speed}$re_wind_speed_unit )}{$1}o;
    s{ [0-2]\K (?=\d0${re_wind_speed}$re_wind_speed_unit )}{}og;
    s{ 3\K (?=[0-6]0${re_wind_speed}$re_wind_speed_unit )}{}og;
    s{[+]\K (?=$re_weather_w_i )}{}og;
    s{M\K/(?=S )}{P}g;
    s{$re_cloud_base \K(M?\d\d/)/(?=M?\d\d )}{$1}o;
    s{ TMPO }{ TEMPO }g;
    s{ TEMP0 }{ TEMPO }g;
    s{ BEC }{ BECMG }g;
    s{ PR\K0(?=B[34]0 )}{O}g;
    s{(?: BECMG| TEMPO)\K(?=$re_hour(?:$re_hour|24) )}{ }og;
    s{ (?:BECMG|TEMPO|INTER) $re_day$re_hour\K(?: /|/ )(?=$re_day(?:$re_hour|24) )}{/}og
        if $is_taf;
    s{ PRECIP }{ PCPN }g;
    s{( T[XN]M?\d\d/(?:24|$re_day?$re_hour)Z)(?=T[XN]M?\d\d/(?:24|$re_day?$re_hour)Z )}{$1 }o;
    s{ ?/(?=$re_snw_cvr_title)}{ }og;
    s{ RWY0\K (?=[1-9] )}{}g;
    s{ RWY[12]\K (?=\d )}{}g;
    s{ RWY3\K (?=[0-6] )}{}g;
    s{ DRFTG SNW }{ DRSN }g;
    s{ T\KO(?=\d{3}[01]\d{3} )}{0}g;
    s{ ?/(?=BLN VISBL )}{ }g;
    s{ FG PATCHES }{ BCFG }g;
    s{[/ ]AL\KTS(?=G[/ ])}{ST}g;
    s{ TO \KTHE (?=$re_compass_dir16 )}{}g;

    # "TAF" after icao code?
    s/^$re_ICAO\K TAF(?= )//o
        if $is_taf;

    # missing keywords
    s{ (?:TEMPO|INTER) ($re_hour$re_min)/($re_hour$re_min|2400)(?= )}{ TEMPO FM$1 TL$2}og
        unless $is_taf;

    # komma got lost somwhere during transmission from originator to provider
    s{^((?:U|ZM).*? RMK.*?QFE\d{3}) (?=\d )}{$1,};
    s{^(FQ.*? RMK.*?TX/\d\d) (?=\d )}{$1,};

    # restore keyword for message type
    $_ = $msg_hdr . $_;
    pos = length $msg_hdr;

    # warn about modification
    push @{$metar{warning}}, { warningType => 'msgModified',
                               s           => substr $_, 0, -1 }
        if $metar{msg} . ' ' ne $_;

=head3 Observational data for aviation requirements

METAR, SPECI:

 (COR|AMD) CCCC YYGGggZ (NIL|AUTO|COR|RTD|BBB) dddff(f)(Gfmfm(fm)){KMH|KT|MPS} (dndndnVdxdxdx)
   {CAVOK|{VVVV (VNVNVNVNDv)|VVVVNDV} (RDRDR/VRVRVRVR(VVRVRVRVR)(i)) (w'w')
          ({NsNsNs|VVV}hshshs|CLR|SKC|NSC|NCD)}
   T'T'/T'dT'd {Q|A}PHPHPHPH
   (REw'w') (WS {RDRDR|ALL RWY}) (WTsTs/{SS'|HHsHsHs}) (RDRDR/ERCReReRBRBR)

TAF:

 (COR|AMD) CCCC YYGGggZ (NIL|COR|AMD) {Y1Y1G1G1G2G2|Y1Y1G1G1/Y2Y2G2G2} (CNL) (NIL) dddff(f)(Gfmfm(fm)){KMH|KT|MPS} (dndndnVdxdxdx)
  {CAVOK|VVVV (w'w') ({NsNsNs|VVV}hshshs|NSC) (TXTFTF/YFYFGFGFZ TNTFTF/YFYFGFGFZ)}

=over

=item optional: B<C<COR>> and/or B<C<AMD>>

keywords to indicate a corrected and/or amended message.

=back

=cut

    while (/\G(COR|AMD) /gc) {
        push @{$metar{reportModifier}}, { s => $1, modifierType => $1 };
    }

=over

=item B<CCCC>

reporting station (ICAO location indicator)

=back

=cut

    if (!/\G($re_ICAO) /ogc) {
        $metar{ERROR} = _makeErrorMsgPos 'obsStation';
        return %metar;
    }
    $metar{obsStationId}{id} = $1;
    $metar{obsStationId}{s} = $1;

    _cySet $metar{obsStationId}{id};

    # EXTENSION: allow NIL
    if (/\G(?:RMK )?NIL $/) {
        $metar{reportModifier}{s} =
            $metar{reportModifier}{modifierType} = 'NIL';
        return %metar;
    }

=over

=item B<YYGGggC<Z>>

METAR: day, hour, minute of observation;
SPECI: day, hour, minute of occurence of change;
TAF: day, hour, minute of origin of forecast

=back

=cut

    if (m{\G$re_unrec($re_day)($re_hour)($re_min)Z }ogc) {
        push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
            if defined $1;
        $metar{$is_taf ? 'issueTime' : 'obsTime'} = {
            s      => "$2$3$4Z",
            timeAt => { day => $2, hour => $3, minute => $4 }
        };
        $obs_hour = $3 unless $is_taf;
    } elsif (/\G(\d+Z) /gc) {
        $metar{$is_taf ? 'issueTime' : 'obsTime'} =
                                               { s => $1, invalidFormat => $1 };
    } elsif ($is_taf && m{\G(?:$re_day$re_hour(?:$re_hour|24)|$re_day$re_hour/$re_day(?:$re_hour|24)) }o)
    {
        $metar{issueTime} = { s => '', invalidFormat => '' };
    } elsif (/\G(NIL) $/) {
        # EXTENSION: NIL instead of issueTime
        push @{$metar{reportModifier}}, { s => $1, modifierType => $1 };
        return %metar;
    } else {
        $metar{ERROR} = _makeErrorMsgPos 'obsTime';
        return %metar;
    }

=over

=item METAR, SPECI: optional: B<C<NIL>> | B<C<AUTO>> | B<C<COR>> | B<C<RTD>> | B<BBB>

report modifier(s)
C<NIL>: message contains no observation data, end of message;
C<AUTO>: message created by an automated station;
C<COR>: corrected message;
C<RTD>: retarded message.

CA: B<BBB>: report has been retarded (C<RR>?), corrected (C<CC>?), amended
(C<AA>?), or segmented (C<P>??)

=back

=cut

    # EXTENSION: BBB (for Canada)
    while (!$is_taf && /\G(NIL|AUTO|COR|RTD|$re_bbb) /ogc) {
        my $r;

        $r->{s} = $1;
        if ($r->{s} =~ 'NIL|AUTO|COR|RTD') {
            $r->{modifierType} = $r->{s};
            $is_auto = 'AUTO'
                if $r->{modifierType} eq 'AUTO';
        } else {
            my ($type, $dat1, $dat2) = unpack 'aaa', $r->{s};
            if ($type eq 'P') {
                $r->{modifierType} = 'P';
                $r->{sortedArr} = [
                                 $dat1 eq 'Z' ? { isLastSegment => undef } : (),
                                 { segment => $dat1 . $dat2 }
                ];
            } else {
                $r->{modifierType} = $type . $dat1;
                $r->{sortedArr} = $dat2 eq 'Z' ? [{ over24hLate => undef }]
                                : $dat2 eq 'Y' ? [{ sequenceLost => undef }]
                                :                [{ bulletinSeq => $dat2 }]
                                ;
            }
        }
        push @{$metar{reportModifier}}, $r;
        return %metar if $r->{modifierType} eq 'NIL';
    }

    if ($is_taf) {

=over

=item TAF: optional: B<C<NIL>> | B<C<COR>> | B<C<AMD>>

report modifier(s).
C<NIL>: message contains no forecast data, end of message;
C<COR>: message corrected;
C<AMD>: message amended

=back

=cut

        if (/\G(NIL|COR|AMD) /gc) {
            push @{$metar{reportModifier}}, { s => $1, modifierType => $1 };
            return %metar if $1 eq 'NIL';
        }

=for html <!--

=over

=item TAF: B<Y1Y1G1G1G2G2> | B<Y1Y1G1G1C</>Y2Y2G2G2>

=for html --><dl><dt>TAF: <strong>Y<sub>1</sub>Y<sub>1</sub>G<sub>1</sub>G<sub>1</sub>G<sub>2</sub>G<sub>2</sub></strong> |  <strong>Y<sub>1</sub>Y<sub>1</sub>G<sub>1</sub>G<sub>1</sub><code>/</code>Y<sub>2</sub>Y<sub>2</sub>G<sub>2</sub>G<sub>2</sub></strong></dt><dd>

forecast period with format before or after August, 2007

=back

=cut

        if (m{\G$re_unrec($re_day)($re_hour)($re_hour|24) }ogc) {
            push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
                if defined $1;
            $metar{fcstPeriod} = {
                s        => "$2$3$4",
                timeFrom => { day => $2, hour => $3 },
                timeTill => {            hour => $4 }
            };
            $s_preAug2007 = "TAF $2$3$4";
        } elsif (m{\G$re_unrec($re_day)($re_hour)/($re_day)($re_hour|24) }ogc) {
            # EXTENSION to AMOFSG/10-SoD 4.3.2, Appendix I: allow 24
            push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
                if defined $1;
            $metar{fcstPeriod} = {
                s        => "$2$3/$4$5",
                timeFrom => { day => $2, hour => $3 },
                timeTill => { day => $4, hour => $5 }
            };
            $is_taf_Aug2007 = 1;
            $s_preAug2007 = '';
        } else {
            $metar{ERROR} = _makeErrorMsgPos 'fcstPeriod';
            return %metar;
        }

=over

=item TAF: optional: B<C<CNL>>

cancelled forecast

=cut

        if (m{\G$re_unrec(CNL) }ogc) {
            push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
                if defined $1;
            $metar{fcstCancelled}{s} = $2;
            push @{$metar{warning}}, { warningType => 'notProcessed',
                                       s           => substr $_, pos, -1 }
                if length != pos;
            return %metar;
        }

=item TAF: optional: B<C<NIL>>

message contains no forecast data, end of message

=cut

        # EXTENSION: NIL after fcstPeriod
        if (m{\G$re_unrec(NIL) }ogc) {
            push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
                if defined $1;
            push @{$metar{reportModifier}}, { s => $2, modifierType => $2 };
            push @{$metar{warning}}, { warningType => 'notProcessed',
                                       s           => substr $_, pos, -1 }
                if length != pos;
            return %metar;
        }

=item TAF: optional: B<C<FCST NOT AVBL DUE>> {B<C<NO>> | B<C<INSUFFICIENT>>} B<C<OBS>>

message contains no forecast data

=back

=cut

        # EXTENSION: NOT AVBL after fcstPeriod. Remarks may follow
        $metar{fcstNotAvbl} = { s => $1, fcstNotAvblReason => "${2}OBS" }
            if /\G(FCST NOT AVBL DUE (NO|INSUFFICIENT) OBS) /gc;
    }

=for html <!--

=over

=item B<dddff>(B<f>)(B<C<G>fmfm>(B<fm>)){B<C<KMH>> | B<C<KT>> | B<C<MPS>>}

=for html --><dl><dt><strong>dddff</strong>(<strong>f</strong>)(<strong><code>G</code>f<sub>m</sub>f<sub>m</sub></strong>(<strong>f<sub>m</sub></strong>)){<strong><code>KMH</code></strong> | <strong><code>KT</code></strong> | <strong><code>MPS</code></strong>}</dt><dd>

surface wind with optional gust (if it exceeds the wind speed by 10 knots or
more)

METAR, SPECI: mean true direction in degrees rounded off to the nearest 10
degrees from which the wind is blowing and mean speed of the wind over the
10-minute period immediately preceding the observation;
TAF: mean direction and speed of forecast wind

wind direction may be C<VRB> for variable if the speed is <3 (US: <=6) knots or
if the variation of wind direction is 180E<deg> or more or cannot be determined
(not US);
wind direction and speed may be C<00000> for calm wind

=back

=cut

    # EXTENSION: allow ///// (wind not available)
    # EXTENSION: allow /// for wind direction (not available)
    # EXTENSION: allow // for wind speed (not available)
    # EXTENSION: allow missing wind
    if (m{\G$re_unrec(/////|(?:$re_wind)) }ogc) {
        push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
            if defined $1;
        $metar{sfcWind} = { s => $2, wind => _parseWind($2, 1) };
        # US: FMH-1 5.4.3, CA: MANOBS 10.2.15
        # default: WMO-No. 306 Vol I.1, Part A, Section A, 15.5.1
        $metar{sfcWind}{measurePeriod} = {
            v => _cyInString(' cUS C ') ? 2 : 10,
            u => 'MIN'
        } if !$is_taf && exists $metar{sfcWind}{wind}{speed};
    # EXTENSION: allow invalid formats
    } elsif (   !$is_taf && $metar{obsStationId}{id} eq 'OPPS'
             && /\G(($re_compass_dir)--?($re_wind_speed)KTS?) /ogc)
    {
        $metar{sfcWind} = {
            s => $1,
            wind => {
                dir   => { 'NE' => 1, 'E' => 2, 'SE' => 3, 'S' => 4,
                           'SW' => 5, 'W' => 6, 'NW' => 7, 'N' => 8,
                         }->{$2} * 45,
                speed => { v => $3 + 0, u => 'KT' }
        }};
    } elsif (/\G(${re_wind_dir}0$re_wind_speed|\d{4,}(?:K?T|K)) /ogc) {
        $metar{sfcWind} = { s => $1, wind => { invalidFormat => $1 }};
    }

=for html <!--

=over

=item optional: B<dndndnC<V>dxdxdx>

=for html --><dl><dt>optional: <strong>d<sub>n</sub>d<sub>n</sub>d<sub>n</sub><code>V</code>d<sub>x</sub>d<sub>x</sub>d<sub>x</sub></strong></dt><dd>

variable wind direction if the speed is >=3 (US: >6) knots

=back

=cut

    # EXTENSION:
    # Annex 3 Appendix 3 4.1.4.2.b.1 requires wind speed >=3 kt and
    #   variation 60-180 for this group: not checked
    if (m{\G$re_unrec($re_wind_dir3)V($re_wind_dir3) }ogc) {
        push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
            if defined $1;
        if (exists $metar{sfcWind}) {
            $metar{sfcWind}{s} .= ' ';
        } else {
            # TODO?: actually not "not available" but missing
            $metar{sfcWind} = {
                s    => '',
                wind => { dirNotAvailable => undef, speedNotAvailable => undef }
            };
        }
        $metar{sfcWind}{s} .= "$2V$3";
        @{$metar{sfcWind}{wind}}{qw(windVarLeft windVarRight)} =
                                                               ($2 + 0, $3 + 0);
    }

    while ($is_taf && m{\G($re_wind_shear_lvl) }ogc) {
        push @{$metar{trendSupplArr}}, { windShearLvl => {
            s     => $1,
            level => $2 + 0,
            wind  => _parseWind $3
        }};
    }
    push @{$metar{trendSupplArr}}, { windShearConds => { s => $1 }}
        if $is_taf && m{\G(WSCONDS) }gc;

=over

=item B<C<CAVOK>>

If the weather conditions allow (visibility 10 km or more, no significant
weather, no clouds below 5000 ft (or minimum sector altitude, whichever is
greater) and no CB or TCU) this may be indicated by the keyword C<CAVOK>. The
next component after that should be the temperature (see below).

=back

=cut

    if (m{\G${re_unrec}CAVOK }ogc) {
        push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
            if defined $1;
        $metar{CAVOK} = undef; # cancels visibility, weather and cloud
    }

    if (!exists $metar{CAVOK}) {

=for html <!--

=over

=item B<VVVV (VNVNVNVNDv)> | B<VVVVC<NDV>>

=for html --><dl><dt><strong>VVVV</strong> (<strong>V<sub>N</sub>V<sub>N</sub>V<sub>N</sub>D<sub>v</sub></strong>) | <strong>VVVV<code>NDV</code></strong></dt><dd>

prevailing visibility (or lowest if not the same in different directions and
fluctuating rapidly). It can have a compass direction attached or C<NDV> if no
directional variations can be given. There may be an additional group for the
minimum visibility. However, if the minimum visibility is less than 1500 m and
the visibility in another direction is more than 5000 m, the minimum and
maximum visibility will be reported instead.

=back

=cut

        # EXTENSION: allow 16 compass directions
        # EXTENSION: allow 'M' (metre) after re_vis_m
        # EXTENSION: allow xxx0 for visPrev in METAR
        # EXTENSION: allow P6000/M0050
        # EXTENSION: allow missing visibility even without CAVOK
        # EXTENSION: allow missing/unavailable direction
        if (   !$is_taf
            && m{\G$re_unrec((?:([PM])?(\d{3}0|9999)M?( ?NDV)?|($re_vis_km))($re_compass_dir16)?)(?: ($re_vis_m)($re_compass_dir|/|)|( /////))? }o
            && !(defined $3 && $4 == 9999))
        {
            my ($tag1, $tag2);

            push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
                if defined $1;
            pos() += (defined $1 ? length($1) + 1 : 0) + length($2) + 1;
            # WMO-No. 782, Part A, chapter 3
            ($tag1, $tag2) =   defined $7 && defined $8
                             ? qw(visMin visMax) : qw(visPrev visMin);
            $metar{$tag1}{s} = $2;
            $metar{$tag1}{compassDir} = $7 if defined $7;
            if ($8) {
                $metar{$tag2}{s} = $8 . $9;
                pos() += length($metar{$tag2}{s}) + 1;
                $metar{$tag2}{distance} = _getVisibilityM $8;
                $metar{$tag2}{compassDir} = $9
                    if $9 ne '' and $9 ne '/';
            }
            # EXTENSION (e.g. MUCF since 2012-03-02 15:51)
            if ($10) {
                $metar{$tag1}{s} .= $10;
                pos() += length $10;
            }
            if (defined $4) {
                $metar{$tag1}{distance} = _getVisibilityM $4, $3;
                $metar{$tag1}{NDV}      = undef if defined $5;
            } else {
                $metar{$tag1}{distance} = { v => $6, rp => 1, u => 'KM' };
                $metar{$tag1}{distance}{v} =~ s/KM//;
            }
        } elsif (m{\G$re_unrec((?:($re_vis_m)M?|($re_vis_km))) }ogc) {
            push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
                if defined $1;
            $metar{visPrev}{s} = $2;
            if (defined $3) {
                $metar{visPrev}{distance} = _getVisibilityM $3;
            } else {
                $metar{visPrev}{distance} = { v => $4, rp => 1, u => 'KM' };
                $metar{visPrev}{distance}{v} =~ s/KM//;
            }
        } elsif (m{\G$re_unrec(($re_vis_sm) ?SM) }ogc) {
            push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
                if defined $1;
            $metar{visPrev} = _getVisibilitySM $3, $is_auto;
            $metar{visPrev}{s} = $2;
        } elsif ($is_taf && m{\G$re_unrec(P?[1-9]\d*)SM }ogc) {
            push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
                if defined $1;
            $metar{visPrev} = _getVisibilitySM $2, $is_auto;
            $metar{visPrev}{s} = "$2SM";
        # EXTENSION: allow //// and misformatted entry
        } elsif (m{\G${re_unrec}//// }ogc) {
            push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
                if defined $1;
            $metar{visPrev} = { s => '////', notAvailable => undef };
        } elsif (/\G(\d{3,4}M?$re_compass_dir16?(?: $re_vis_m$re_compass_dir)?|$re_vis_sm) /ogc) {
            $metar{visPrev} = { s => $1, invalidFormat => $1 };
        }
    }

=for html <!--

=over

=item METAR: optional: B<C<R>DRDRC</>VRVRVRVR>(B<C<V>VRVRVRVR>)(B<i>)

=for html --><dl><dt>METAR: optional: <strong><code>R</code>D<sub>R</sub>D<sub>R</sub><code>/</code>V<sub>R</sub>V<sub>R</sub>V<sub>R</sub>V<sub>R</sub></strong>(<strong><code>V</code>V<sub>R</sub>V<sub>R</sub>V<sub>R</sub>V<sub>R</sub></strong>)(<strong>i</strong>)</dt><dd>

runway visibility range(s) with optional trend, or C<RVRNO> if they are not
available

=back

=cut

    while (!$is_taf && _parseRwyVis \%metar, 0) {};

    # EXTENSION: allow RVRNO (not available) (KADW, RKSG, PAED)
    if (!$is_taf && /\GRVRNO /gc) {
        $metar{RVRNO} = undef;
    }

    if (!exists $metar{CAVOK}) {

=over

=item optional: B<w'w'>

up to 3 groups to describe the present weather: precipitation (C<DZ>, C<RA>,
C<SN>, C<SG>, C<PL>, C<GR>, C<GS>, C<IC>, C<UP>, C<JP>), obscuration (C<BR>,
C<FG>, C<FU>, C<VA>, C<DU>, C<SA>, C<HZ>), or other (C<PO>, C<SQ>, C<FC>,
C<SS>, C<DS>).
Mixed precipitation is indicated by concatenating, e.g. C<RASN>.
Certain precipitation, duststorm and sandstorm can have the intentsity (C<+> or
C<->) prepended.
Prepended C<VC> means in the vicinity (within 5 SM / 8 km to 10 SM / 16 km) but
not at the station.
Certain phenomena can also be combined with an appropriate descriptor (C<MI>,
C<BC>, C<PR>, C<DR>, C<BL>, C<SH>, C<TS>, C<FZ>), e.g. C<TSRA>, C<FZFG>,
C<BLSN>.

=back

=cut

        # EXTENSION: allow // (not available) and other deviations
        # NSW should not be in initial section, only in trends
        # store recent weather as invalidFormat for now, check if valid later
        while (m{\G$re_unrec_weather(?:(//) |($re_weather)(?:/? |/(?=$re_weather[ /]))|(NSW|[+-]?(?:RE|VC|$re_weather_desc|$re_weather_prec|$re_weather_obsc|$re_weather_other)+) )}ogc)
        {
            push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
                if defined $1;
            if (defined $4) {
                push @{$metar{weather}}, {
                    s             => $4,
                    invalidFormat => $4
                };
            } else {
                push @{$metar{weather}}, _parseWeather $2 // $3;
            }
        }

=for html <!--

=over

=item optional: {B<NsNsNs> | B<VVV>}B<hshshs>(B<C<TCU>> | B<C<CB>>) | B<C<CLR>> | B<C<SKC>> | B<C<NSC>> | B<C<NCD>>

=for html --><dl><dt>optional: {<strong>N<sub>s</sub>N<sub>s</sub>N<sub>s</sub></strong> | <strong>VVV</strong>}<strong>h<sub>s</sub>h<sub>s</sub>h<sub>s</sub></strong>(<strong><code>TCU</code></strong> | <strong><code>CB</code></strong>) | <strong><code>CLR</code></strong> | <strong><code>SKC</code></strong> | <strong><code>NSC</code></strong> | <strong><code>NCD</code></strong></dt><dd>

up to 3 (US: 6) groups to describe the sky condition (cloud cover and base or
vertical visibility) optionally with cloud type. The keywords C<CLR>, C<SKC>,
C<NSC>, or C<NCD> may indicate different sky conditions if no cloud cover is
given. Height values (given in hundreds of feet) are rounded to the nearest
reportable amount (<=5000 ft: 100 ft, <=10000 ft: 500 ft, otherwise 1000 ft)
(for US), or rounded down to the nearest 30 m (WMO).

=back

=cut

        # EXTENSION: allow ////// (not available) without CB, TCU
        # WMO-No. 306 Vol I.1, Part A, Section A, 15.9.1.1:
        #   CLR: no clouds below 10000 (FMH-1: 12000) ft detected by autom. st.
        #   SKC: no clouds + VV not restricted but not CAVOK
        #   NSC: no significant clouds + no CB + VV not restr. but not CAVOK,SKC
        #   NCD: no clouds + CB, TCU detected by automatic observation system
        while (m{\G$re_unrec_cloud((SKC|NSC|CLR|NCD)|VV($re_cloud_base)(?:///)?|(///|(?:$re_cloud_cov|///)(?:$re_cloud_base(?: ?(?:$re_cloud_type|///)(?:\($re_loc_and\))?)?|$re_cloud_type))|($re_cloud_cov\d{1,2}|$re_cloud_cov(?: \d{1,3}))) }ogc)
        {
            push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
                if defined $1;
            if (defined $6 || (defined $4 && exists $metar{visVert})) {
                push @{$metar{cloud}}, {
                    s             => $2,
                    invalidFormat => $2
                };
            } elsif (defined $3) {
                push @{$metar{cloud}}, {
                    s        => $2,
                    noClouds => $3
                };
            } elsif (defined $4) {
                $metar{visVert} = {
                    s => $2,
                    $4 eq '///' ? (notAvailable => undef)
                                : (distance => _codeTable1690 $4)
                };
            } else {
                push @{$metar{cloud}}, _parseCloud $5;
            }
        }
        _determineCeiling $metar{cloud} if exists $metar{cloud};
    }

=for html <!--

=over

=item METAR: B<T'T'C</>T'dT'd>

=for html --><dl><dt>METAR: <strong>T'T'<code>/</code>T'<sub>d</sub>T'<sub>d</sub></strong></dt><dd>

current air temperature and dew point. If both are given, the relative humidity
can be determined.

=back

=cut

    # EXTENSION. TODO: remove as soon as reports are fixed
    if (   $metar{obsStationId}{id} eq 'LIEE'
        && m{\G(M?\d\d/M?\d\d)([/?](?: / /)?) })
    {
        my $pos;

        $pos = pos;
        substr $_, $pos + length $1, length $2, '';
        pos = $pos;
        _msgModified \%metar;
    }

    # EXTENSION: FMH-1: dew point is optional
    # EXTENSION: allow // for temperature and dew point
    # EXTENSION: allow XX for temperature and dew point
    if (   !$is_taf
        && m{\G$re_unrec((?:(M?\d ?\d)|(?://|XX))/((M? ?\d ?\d)|(?://|XX))?) }ogc)
    {
        push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
            if defined $1;
        $metar{temperature}{s} = $2;
        if (defined $3) {
            $metar{temperature}{air}{temp} = _parseTempMetaf $3;
        } else {
            $metar{temperature}{air}{notAvailable} = undef;
        }
        if (defined $4) {
            if (defined $5) {
                $metar{temperature}{dewpoint}{temp} = _parseTempMetaf $5;
            } else {
                $metar{temperature}{dewpoint}{notAvailable} = undef;
            }
        }
        if (   exists $metar{temperature}{air}{temp}
            && exists $metar{temperature}{dewpoint}
            && exists $metar{temperature}{dewpoint}{temp})
        {
            _setHumidity $metar{temperature};
        }
    } elsif (!$is_taf && m{\G$re_unrec(M?\d{1,2}/M?\d{1,2}) }ogc) {
        push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
            if defined $1;
        $metar{temperature} = { s => $2, invalidFormat => $2 };
    }

=for html <!--

=over

=item METAR: {B<C<Q>> | B<C<A>>}B<PHPHPHPH>

=for html --><dl><dt>METAR: {<strong><code>Q</code></strong> | <strong><code>A</code></strong>}<strong>P<sub>H</sub>P<sub>H</sub>P<sub>H</sub>P<sub>H</sub></strong></dt><dd>

QNH (in hectopascal) or altimeter (in hundredths in. Hg.). Some stations report
both, some stations report QFE, only.

=back

=cut

    # EXTENSION. TODO: remove as soon as reports are fixed
    if ($metar{obsStationId}{id} eq 'LIEE' && m{\GQ[01]\d{3}[/?] }) {
        my $pos;

        $pos = pos;
        substr $_, $pos + 5, 1, '';
        pos = $pos;
        _msgModified \%metar;
    }

    # EXTENSION: allow other formats for OPxx
    if (   !$is_taf
        && _cyIsCC(' OP ')
        && m{\G(Q(?:NH)?[. ]?(1\d{3}|0?[7-9]\d\d)((?:\.\d)?))(?:[/ ](A?([23]\d\.\d\d)))? }gc)
    {
        $qnhHPa  = ($2 + 0) . $3;
        push @{$metar{QNH}}, {
            s        => $1,
            pressure => { v => $qnhHPa, u => 'hPa' }
        };
        push @{$metar{QNH}}, {
            s        => $4,
            pressure => { v => $5, u => 'inHg' }
        }
            if defined $4;
    } elsif (!$is_taf && m{\G$re_unrec($re_qnh) }ogc) {
        my $qnh;

        push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
            if defined $1;
        $qnh = _parseQNH $2;
        push @{$metar{QNH}}, $qnh;
        if (exists $qnh->{pressure}) {
            $qnhHPa  = $qnh->{pressure}{v} if $qnh->{pressure}{u} eq 'hPa';
            $qnhInHg = $qnh->{pressure}{v} if $qnh->{pressure}{u} eq 'inHg';
        }
    } elsif (!$is_taf && m{\G((?:Q(?:NH)?|A) ?(?:\d{3}(?:\d\d)?|XXXX?)) }gc) {
        push @{$metar{QNH}}, { s => $1, invalidFormat => $1 };
    }
    # EXTENSION: allow Altimeter after QNH
    if (   !$is_taf
        && _cyInString(' KHBB MG MH MN MS MT MZ OI OM RP TN VT ')
        && m{\G($re_qnh) }ogc)
    {
        my $qnh;

        $qnh = _parseQNH $1;
        push @{$metar{QNH}}, $qnh;
        if (exists $qnh->{pressure}) {
            $qnhHPa  = $qnh->{pressure}{v} if $qnh->{pressure}{u} eq 'hPa';
            $qnhInHg = $qnh->{pressure}{v} if $qnh->{pressure}{u} eq 'inHg';
        }
    }
    # EXTENSION: MGxx uses QFE
    if (   !$is_taf
        && _cyIsCC(' MG ')
        && m{\G(QFE ?(1\d{3}|[7-9]\d\d)[./](\d+)) }gc)
    {
        $metar{QFE} = { s => $1, pressure => { v => "$2.$3", u => 'hPa' }};
    }

    # EXTENSION: station pressure (OIxx, OPxx)
    if (   !$is_taf
        && _cyInString(' OI OP ')
        && m{\G((1\d{3}|0?[7-9]\d\d)(?:[./](\d))?) }gc)
    {
        $metar{stationPressure} = {
            s        => $1,
            pressure => { v => ($2 + 0) . (defined $3 ? ".$3" : ''), u => 'hPa'}
        };
    }

    # EXTENSION: allow worst cloud cover
    if (!$is_taf && _cyIsCC(' LO ') && /\G($re_cloud_cov|SKC) /ogc) {
        $metar{cloudMaxCover}{s} = $1;
        $metar{cloudMaxCover}{$1 eq 'SKC' ? 'noClouds' : 'cloudCover'} = $1;
    }

=over

=item METAR: optional: B<C<RE>w'w'>

recent weather

=back

=cut

    # recent weather: some groups omitted or wrong format?
    #   YUDO 090600Z 00000KT 9999 RERA
    if (!$is_taf && exists $metar{weather}) {
        for my $idx (-$#{$metar{weather}} .. 0) {
            my ($w, $len);

            $w = $metar{weather}[-$idx];
            $len = length($w->{s}) + 1;
            if (   exists $w->{invalidFormat}
                && $w->{s} =~ m{^RE(?://|$re_weather_re)$}
                && $w->{s} . ' ' eq substr $_, pos() - $len, $len)
            {
                # move position in message back and delete group from weather
                pos() -= $len;
                $#{$metar{weather}}--;
            } else {
                last;
            }
        }
        delete $metar{weather} if $#{$metar{weather}} == -1;
    }
    while (!$is_taf && m{\G${re_unrec}RE(//|$re_weather_re) }ogc) {
        push @{$metar{warning}}, { warningType => 'notProcessed', s => $1 }
            if defined $1;
        push @{$metar{recentWeather}}, _parseWeather($2, 'RE');
    }

=for html <!--

=over

=item METAR: optional: B<C<WS>> {B<C<R>DRDR> | B<C<ALL RWY>>}

=for html --><dl><dt>METAR: optional: <strong><code>WS</code></strong> {<strong><code>R</code>D<sub>R</sub>D<sub>R</sub></strong> | <strong><code>ALL RWY</code></strong>}</dt><dd>

wind shear for certain or all runways

=back

=cut

    if (!$is_taf && /\G(WS ALL RWY) /gc) {
        push @{$metar{windShear}}, {
            s           => $1,
            rwyDesigAll => undef
        };
    }
    while (!$is_taf && /\G(WS R(?:WY)?($re_rwy_des)) /ogc) {
        push @{$metar{windShear}}, {
            s        => $1,
            rwyDesig => $2
        };
    }

=for html <!--

=over

=item METAR: optional: B<C<W>TsTsC</>>{B<C<S>S'> | B<C<H>HsHsHs>}

=for html --><dl><dt>METAR: optional: <strong><code>W</code>T<sub>s</sub>T<sub>s</sub><code>/</code></strong>{<strong><code>S</code>S'</strong> | <strong><code>H</code>H<sub>s</sub>H<sub>s</sub>H<sub>s</sub></strong>}</dt><dd>

sea-surface temperature, state of the sea or significant wave height

=back

=cut

    # HHs(Hs(Hs)): http://www.knmi.nl/waarschuwingen_en_verwachtingen/luchtvaart/131114_AUTO_METAR_Amd76_14Nov2013_DEFINITIEF.pdf
    if (!$is_taf && m{\GW(//|M?\d\d)/(?:S([\d/])|H(\d{1,3}|///)) }gc) {
        $metar{waterTemp} = {
            s => "W$1",
            $1 eq '//' ? (notAvailable => undef) : (temp => _parseTempMetaf $1)
        };
        if (defined $2) {
            $metar{seaCondition} = {
                s => "S$2",
                $2 eq '/' ? (notAvailable => undef) : (seaCondVal => $2)
            };
        } else {
            $metar{waveHeight} = {
                s      => "H$3",
                $3 eq '///' ? (notAvailable => undef)
                            : (height => { v => $3 + 0, u => 'DM' })
            };
        }
    }

=for html <!--

=over

=item METAR: optional: B<C<R>DRDR>(B<C</>>)B<ERCReReRBRBR>

=for html --><dl><dt>METAR: optional: <strong><code>R</code>D<sub>R</sub>D<sub>R</sub></strong>(<strong><code>/</code></strong>)<strong>E<sub>R</sub>C<sub>R</sub>e<sub>R</sub>e<sub>R</sub>B<sub>R</sub>B<sub>R</sub></strong></dt><dd>

state of the runway: runway deposits, extent of runway contamination, depth of
deposit, and friction coefficient or braking action

B<ERCReReRBRBR> can also be C<SNOCLO> (airport closed due to snow), B<ERCReReR>
can also be C<CLRD> if contaminations have been cleared. The runway designator
B<DRDR> can also be C<88> (all runways), C<99> (runway repeated); otherwise, if
it is greater than 50, subtract 50 and append C<R>.

=back

=cut

    while (!$is_taf && _parseRwyState \%metar) {};

=pod

A METAR may also contain supplementary information, like colour codes.
Additionally, there can be country or station specific information: pressure,
worst cloud cover, runway winds, relative humidity.

=cut

    # EXTENSION: allow colour code
    if (!$is_taf && m{\G($re_colour) }ogc) {
        $metar{colourCode} = _parseColourCode $1;
        push @{$metar{warning}}, { warningType => 'BLUslash' }
            if index($1, '/', 3) > -1;
    }

=for html <!--

=over

=item TAF: optional: B<C<TX>TFTFC</>YFYFGFGFC<Z> C<TN>TFTFC</>YFYFGFGFC<Z>>

=for html --><dl><dt>TAF: optional: <strong><code>TX</code>T<sub>F</sub>T<sub>F</sub><code>/</code>Y<sub>F</sub>Y<sub>F</sub>G<sub>F</sub>G<sub>F</sub><code>Z</code>  <code>TN</code>T<sub>F</sub>T<sub>F</sub><code>/</code>Y<sub>F</sub>Y<sub>F</sub>G<sub>F</sub>G<sub>F</sub><code>Z</code></strong></dt><dd>

operationally significant maximum or minimum temperatures within the validity
period

=back

A TAF may also contain supplementary information: turbulence, icing, wind shear,
QNH.
Some stations provide additional information, like obscuration, or temperature
and QNH forecast.

=cut

    # TAF: look ahead for temp(Min|Max)At, move and process here
    # EXTENSION: allow mixed format (pre/post Aug 2007)
    # EXTENSION: allow day with hour=24
    # EXTENSION: allow time without Z
    while (   $is_taf
           && m{\G(?:(.+?) )??(T([XN])(M?\d\d)/($re_day)?($re_hour|24)Z?) }o)
    {
        push @{$metar{trendSupplArr}}, {
            ($3 eq 'N' ? 'tempMinAt' : 'tempMaxAt') => {
                s      => $2,
                temp   => _parseTempMetaf($4),
                timeAt => { defined $5 ? (day => $5) : (), hour => $6 }
        }};

        if (defined $1) {
            my $pos;

            $pos = pos;
            substr $_, $pos, length($1) + length($2) + 1, $2 . ' ' . $1;
            pos = $pos;
            _msgModified \%metar;
        }
        pos() += length($2) + 1;
    }

    # "supplementary" section and additional info of TAFs
    while ($is_taf && _parseTAFsuppl \%metar, \%metar) {};

=head3 Trends

METAR, SPECI:

 {NOSIG|TTTTT TTGGgg dddff(f)(Gfmfm(fm)){KMH|KT|MPS} {CAVOK|VVVV {w'w'|NSW}} ({NsNsNs|VVV}hshshs|NSC) ...}

TAF:

 {TTYYGGgg|{PROB C2C2 (TTTTT)|TTTTT} YYGG/YeYeGeGe} dddff(f)(Gfmfm(fm)){KMH|KT|MPS}
  {CAVOK|VVVV {w'w'|NSW} ({NsNsNs|VVV}hshshs|NSC)}
  ...

=cut

    # EXTENSION: METAR: if NOSIG is last group but not next, move here
    if (   !$is_taf && !/\GNOSIG / && / NOSIG $/
        && (   exists $metar{QNH} || exists $metar{QFE}
            || (exists $metar{temperature} && _cyInString ' MH MG ')))
    {
        my $pos;

        $pos = pos;
        s/\G/NOSIG /;
        s/NOSIG $//;
        pos = $pos;
        _msgModified \%metar;
    }

    # trendType NOSIG: METAR, only
    if (($had_NOSIG = !$is_taf && /\G(NOSIG) /gc)) {
        my $td;

        $td->{s} = $1;
        $td->{trendType} = $1;
        push @{$metar{trend}}, $td;

        # EXTENSION: allow rwyState after NOSIG. Not considered trend data!
        while (!$is_taf && _parseRwyState \%metar) {};
    }

    # EXTENSION: allow colour code after NOSIG
    if (!$is_taf && !exists $metar{colourCode} && m{\G($re_colour) }ogc) {
        $metar{colourCode} = _parseColourCode $1;
        push @{$metar{warning}}, { warningType => 'BLUslash' }
            if index($1, '/', 3) > -1;
    }

    # EXTENSION: allow RH after NOSIG. Not considered trend data!
    if ($metar{obsStationId}{id} eq 'OOSA' && /\G(RH(\d\d)) /gc) {
        $metar{RH}{s} = $1;
        $metar{RH}{relHumid} = $2 + 0;
    }

    # trendType:
    # - FM: significant change of conditions (TAF, only)
    # - BECMG: transition to different conditions
    # - TEMPO: temporarily different conditions (optional for TAF: with prob.)
    # - PROB: different conditions with a probability (TAF, only)
    # - INTER is obsolete
    #
    # changes at midnight: 0000 with FM/AT, 2400 with TL
    # EXTENSION: allow missing period
    # EXTENSION: FM: allow time with Z
    # EXTENSION: FM: allow time without minutes
    # EXTENSION: FM: allow 24Z? or 2400Z?
    # EXTENSION: allow mixed pre/post Aug 2007 format but warn about periods in
    #   old format
    # EXTENSION: METAR from Yxxx: allow FM
    # EXTENSION: allow blank after FM|TL|AT
    while (!$had_NOSIG && length > pos) {
        my ($td, $no_keys, $period_vis, $r);

        if (   ($is_taf || _cyIsC ' Y ')
            && /\G(FM ?(?:($re_hour)($re_min)?|(24)(?:00)?)Z?) /ogc)
        {
            $td->{s} = $1;
            $td->{trendType} = 'FM';
            if (defined $2) {
                $td->{timeFrom}{hour}   = $2;
                $td->{timeFrom}{minute} = $3 if defined $3;
            } else {
                $td->{timeFrom}{hour} = $4;
            }
            $s_preAug2007 .= ' ' . $td->{s} if $is_taf;
        } elsif (   ($is_taf || _cyIsC ' Y ')
                 && /\G(FM ?($re_day)($re_hour)($re_min)Z?) /ogc)
        {
            $td->{s} = $1;
            $td->{trendType} = 'FM';
            $td->{timeFrom} = { day => $2, hour => $3, minute => $4 };
            $is_taf_Aug2007 = 1 if $is_taf;
        } elsif (   $is_taf
                 && /\G((BECMG|TEMPO|INTER)|PROB([34]0)(?: (TEMPO|INTER))?) /gc)
        {
            $td->{s} = $1;
            if (defined $2) {
                $td->{trendType} = $2;
            } else {
                $td->{probability} = $3;
                $td->{trendType} = $4 // 'FM';
            }

            # EXTENSION: allow wrong format, e.g. MZBZ
            if (m{\GFM $re_day$re_hour/$re_day$re_hour}o) {
                my $pos;

                $pos = pos;
                s/\G...//;
                pos = $pos;
                _msgModified \%metar;
            } elsif (/\GFM$re_hour$re_min TL$re_hour$re_min /o) {
                my $pos;

                $pos = pos;
                s{\G..(....) ..}{$1/};
                pos = $pos;
                _msgModified \%metar;
            }

            if (/\G($re_hour|24)($re_hour|24) /ogc) {
                $td->{s} .= " $1$2";
                $td->{timeFrom}{hour} = $1;
                $td->{timeTill}{hour} = $2;
                $s_preAug2007 .= ' ' . $td->{s};
                $period_vis = $1 if "$1$2" =~ /^($re_vis_m)$/o;
            } elsif (m{\G($re_day)($re_hour|24)/($re_day)($re_hour|24) }ogc) {
                $td->{s} .= " $1$2/$3$4";
                $td->{timeFrom} = { day => $1, hour => $2 };
                $td->{timeTill} = { day => $3, hour => $4 };
                $is_taf_Aug2007 = 1;
            } else {
                push @{$metar{warning}},
                                    { warningType => 'periodMissing', s => $1 };
            }
        } elsif (!$is_taf && /\G(BECMG|TEMPO|INTER) /gc) {
            $td->{s} = $1;
            $td->{trendType} = $1;

            if (/\G((?:TL ?2400|(?:FM|TL|AT) ?$re_hour$re_min)Z?) /ogc) {
                my ($type, $hour, $minute);

                $td->{s} .= " $1";
                $type = substr $1, 0, 2;
                ($hour, $minute) = unpack 'a2a2', substr $1, length($1) - 4;
                $td->{{ FM => 'timeFrom',
                        TL => 'timeTill',
                        AT => 'timeAt' }->{$type}} =
                                           { hour => $hour, minute => $minute };

                if ($type ne 'TL' && /\GTL ?((?:2400|$re_hour$re_min)Z?) /ogc) {
                    $td->{s} .= " TL$1";
                    @{$td->{timeTill}}{qw(hour minute)} = unpack 'a2a2', $1;
                }
            }
        } elsif (!$is_taf && _cyIsCC(' EH ') && m{\G$re_wind }o) {
            # WMO-No. 306 Vol II, Chapter VI, Section D, 15.14:
            $td->{s} = '';
            $td->{trendType} = 'BECMG';
        } else {
            last;
        }
        $no_keys = keys %$td;

        # WMO-No. 306 Vol II, Chapter VI, Section D, 15.14:
        if (!$is_taf && _cyIsCC(' EH ') && m{\G($re_colour) }ogc) {
            $td->{colourCode} = _parseColourCode $1;
            push @{$metar{warning}}, { warningType => 'BLUslash' }
                if index($1, '/', 3) > -1;
        }

        if (m{\G($re_wind) }ogc) {
            $td->{sfcWind} = { s => $1, wind => _parseWind($1, 1) };
        # EXTENSION: allow invalid formats
        } elsif (/\G(${re_wind_dir}0$re_wind_speed|\d{6}$re_wind_speed_unit) /ogc)
        {
            $td->{sfcWind} = { s => $1, wind => { invalidFormat => $1 }};
        }

        # EXTENSION: allow variation
        if (/\G($re_wind_dir3)V($re_wind_dir3) /ogc) {
            if (exists $td->{sfcWind}) {
                $td->{sfcWind}{s} .= ' ';
            } else {
                # TODO?: actually not "not available" but missing
                $td->{sfcWind} = {
                    s    => '',
                    wind => { dirNotAvailable=>undef, speedNotAvailable=>undef }
                };
            }
            $td->{sfcWind}{s} .= "$1V$2";
            @{$td->{sfcWind}{wind}}{qw(windVarLeft windVarRight)} =
                                                               ($1 + 0, $2 + 0);
        }

        if (/\GCAVOK /gc) {
            $td->{CAVOK} = undef;
        }

        if (!exists $td->{CAVOK}) {
            # EXTENSION: allow 'M' after re_vis_m
            if (m{\G(($re_vis_m)M?|($re_vis_km)|($re_vis_sm) ?SM) }ogc) {
                if (defined $2) {
                    $td->{visPrev}{distance} = _getVisibilityM $2;
                } elsif (defined $3) {
                    $td->{visPrev}{distance} = { v => $3, rp => 1, u => 'KM' };
                    $td->{visPrev}{distance}{v} =~ s/KM//;
                } else {
                    $td->{visPrev} = _getVisibilitySM $4, $is_auto;
                }
                $td->{visPrev}{s} = $1;
            } elsif ($is_taf && /\G(P?[1-9]\d*)SM /gc) {
                $td->{visPrev} = _getVisibilitySM $1, $is_auto;
                $td->{visPrev}{s} = "$1SM";
            } elsif (/\G(\d{3,4}M?) /gc) {
                $td->{visPrev}{s} = $1;
                $td->{visPrev}{invalidFormat} = $1;
            } elsif (!exists $td->{sfcWind} && $period_vis) {
                # check for ambiguous period/wind group: BECMG 2000 could mean:
                #    - 2000 is a period in pre Aug 2007 format, or
                #    - period is missing (should not be), 2000 is visibility
                push @{$metar{warning}}, {
                    warningType => 'ambigPeriodVis',
                    s           => $period_vis
                };
            }

            # EXTENSION: allow VC..
            while (m{\G$re_unrec_weather(($re_weather)(?:/? |/(?=$re_weather[ /]))|(NSW) |(//|[+-]?(?:RE|VC|$re_weather_desc|$re_weather_prec|$re_weather_obsc|$re_weather_other)+) )}ogc)
            {
                if (defined $1) {
                    if (   keys(%$td) == $no_keys
                        && !exists $td->{timeFrom}
                        && !exists $td->{timeTill}
                        && !exists $td->{timeAt})
                    {
                        # no valid entry, no period: could be invalid period
                        pos() -= length($1) + length($2) + 1;
                        $metar{ERROR} = _makeErrorMsgPos 'other';
                        return %metar;
                    }
                    push @{$metar{warning}},
                                     { warningType => 'notProcessed', s => $1 };
                }

                if (defined $5) {
                    push @{$td->{weather}}, {
                        s             => $5,
                        invalidFormat => $5
                    };
                } else {
                    push @{$td->{weather}}, _parseWeather $3 // $4;
                }
            }

            # EXTENSION: allow SKC, CLR
            while (/\G$re_unrec((SKC|NSC|CLR)|VV($re_cloud_base)|($re_cloud_cov$re_cloud_base$re_cloud_type?|$re_cloud_cov$re_cloud_type)) /ogc)
            {
                if (defined $1) {
                    if (   keys(%$td) == $no_keys
                        && !exists $td->{timeFrom}
                        && !exists $td->{timeTill}
                        && !exists $td->{timeAt})
                    {
                        # no valid entry, no period: could be invalid period
                        pos() -= length($1) + length($2) + 2;
                        $metar{ERROR} = _makeErrorMsgPos 'other';
                        return %metar;
                    }
                    push @{$metar{warning}},
                                     { warningType => 'notProcessed', s => $1 };
                }

                if (defined $3) {
                    push @{$td->{cloud}}, {
                        s        => $2,
                        noClouds => $3
                    };
                } elsif (defined $4) {
                    if (exists $td->{visVert}) {
                        push @{$td->{cloud}}, {
                            s             => $2,
                            invalidFormat => $2
                        };
                    } else {
                        $td->{visVert} = {
                            s => $2,
                            $4 eq '///' ? (notAvailable => undef)
                                        : (distance => _codeTable1690 $4)
                        };
                    }
                } else {
                    push @{$td->{cloud}}, _parseCloud $5;
                }
            }
            _determineCeiling $td->{cloud} if exists $td->{cloud};

            # EXTENSION: allow colour code
            if (!$is_taf && m{\G($re_colour) }ogc) {
                $td->{colourCode} = _parseColourCode $1;
                push @{$metar{warning}}, { warningType => 'BLUslash' }
                    if index($1, '/', 3) > -1;
            }

            # EXTENSION: allow turbulence forecast as the only item of a trend
            if (   !$is_taf
                && _cyIsC(' Y ')
                && keys(%$td) == $no_keys
                && ($r = _turbulenceTxt))
            {
                if (exists $r->{timeFrom}) {
                    $metar{ERROR} = _makeErrorMsgPos 'other';
                    return %metar;
                }
                if (exists $r->{timeTill}) {
                    if (exists $td->{timeTill} || exists $td->{timeAt}) {
                        $metar{ERROR} = _makeErrorMsgPos 'other';
                        return %metar;
                    } else {
                        $td->{timeTill} = $r->{timeTill};
                        delete $r->{timeTill};
                    }
                }
                push @{$td->{trendSupplArr}}, { turbulence => $r };
            }
        }

        # EXTENSION: allow rwyState after trend BECMG / TEMPO but assign to main
        while (!$is_taf && _parseRwyState \%metar) {};

        # "supplementary" section and additional info of TAFs
        while ($is_taf && _parseTAFsuppl $td, \%metar) {};

        # EXTENSION: allow turbulence/icing forecast in METAR from Uxxx
        if (!$is_taf && _cyIsC ' U ') {
            while (_turbulenceIcing $td) {};
        }

        push @{$metar{trend}}, $td;

        # empty trend?
        if (keys(%$td) == $no_keys) {
            $metar{ERROR} = _makeErrorMsgPos 'noTrendData';
            last;
        }
    }

    if ($is_taf_Aug2007 && $s_preAug2007 ne '') {
        $s_preAug2007 =~ s/^ //;
        push @{$metar{warning}}, {
            warningType => 'mixedFormat4TafPeriods',
            s           => $s_preAug2007
        };
    }
    return %metar if exists $metar{ERROR};

    # EXTENSION: add 'RMK' for METAR if QNH/QFE exists and no trend/RMK follow
    if (   !$is_taf
        && (   exists $metar{QNH}
            || exists $metar{QFE}
            || (exists $metar{temperature} && _cyInString ' MH MG '))
        && length > pos
        && !m{\G.*?(?:NOSIG|BECMG|TEMPO|INTER|PROB[34]0|RMK) })
    {
        my $pos;

        $pos = pos;
        s/\G/RMK /;
        pos = $pos;
        _msgModified \%metar;
    }

    # EXTENSION: forecast QNH and temperature for AGxx, ANxx, AYxx
    if ($is_taf && _cyInString ' AG AN AY ') {
        my $r;

        $r = _parseTQfcst();
        push @{$metar{TAFinfoArr}}, { temp_fcst => $r->{temp_fcst} }
            if exists $r->{temp_fcst};
        push @{$metar{TAFinfoArr}}, { QNH_fcst => $r->{QNH_fcst} }
            if exists $r->{QNH_fcst};
    }

    # http://www.wmo.int/pages/prog/www/WMOCodes/WMO306_vII/Amendments/2013/Netherlands_2013.pdf
    if (   $is_taf
        && _cyIsCC(' EH ')
        && /\G(CNL ($re_day)($re_hour)($re_min)Z) /ogc)
    {
        push @{$metar{TAFinfoArr}}, { fcstCancelledFrom => {
            s => $1,
            timeFrom => { day => $2, hour => $3, minute => $4 }
        }};
    }

=head3 Remarks

Finally, there may be remarks.

 RMK ...

The parser recognises more than 80 types of remarks for METARs, plus about 50
keywords/keyword groups, and 5 types of remarks for TAFs. They include
(additional) information about wind and visibility (at different locations,
also max./min.), cloud (also types), pressure (also change), temperature (more
accurate, also max. and min.), runway state, duration of sunshine,
precipitation (also amounts, start, end), weather phenomena (with location,
moving direction), as well as administrative information (e.g.
correction/amendment, LAST, NEXT, broken measurement equipment). Some countries
publish documentation about the contents, but this section can contain any free
text.

=cut

    if (m{\GRMK }gc) {
        my ($notRecognised, $had_CA_RMK_prsChg);

        @{$metar{remark}} = ();

        $notRecognised = '';
        $old_pos = -1;
        while (length > pos) {
            my ($parsed, $r);

            if ($old_pos == pos) {
                # "cannot" happen, prevent endless loop
                $metar{ERROR} = _makeErrorMsgPos 'internal';
                return %metar;
            }
            $old_pos = pos;

            $parsed = 1;
            $r = {};
            if (   $notRecognised =~ /DUE(?: TO)?(?: $re_phen_desc| GROUND)?$/o
                || $notRecognised =~ /BY(?: $re_phen_desc| GROUND)?$/o)
            {
                $parsed = 0;
            } elsif (!$is_taf && _parseRwyState $r) {
                push @{$metar{remark}}, { rwyState => $r->{rwyState}[0] };
            } elsif (_parseRwyVis $r, 1) {
                push @{$metar{remark}}, { visRwy => $r->{visRwy}[0] };
            } elsif (_cyInString(' EQ LI OA ') && /\G($re_cloud_cov|SKC) /ogc) {
                push @{$metar{remark}}, { cloudMaxCover => {
                    s => $1,
                    ($1 eq 'SKC' ? 'noClouds' : 'cloudCover') => $1
                }};
            } elsif (   _cyInString(' BKPR EG EQ ET FHAW L OA PGUA ')
                     && !$is_taf
                     && m{\G($re_colour) }ogc)
            {
                push @{$metar{remark}}, { colourCode => _parseColourCode $1 };
                push @{$metar{warning}}, { warningType => 'BLUslash' }
                    if index($1, '/', 3) > -1;
            } elsif (   !$is_taf
                     && $metar{obsStationId}{id} eq 'SCSE'
                     && /\G(NEFO PLAYA (?:([1-9]\d+0)FT|(SKC))) /gc)
            {
                # 2005-09-08 19:00 .. 2012-06-25 19:00
                push @{$metar{remark}}, { NEFO_PLAYA => {
                    s => $1,
                    defined $2 ? (cloudBase => { v => $2 + 0, u => 'FT' })
                               : (noClouds => 'SKC')
                }};
            } elsif (   !$is_taf
                     && $metar{obsStationId}{id} eq 'LPMA'
                     && /\G($re_rs_rwy_wind) /ogc)
            {
                $r->{s} = $1;
                $r->{wind} = _parseWind $3 . '0' . $4, 1;
                if ($2 eq 'RS') {
                    # www.pprune.org/questions/520536-metar-decoding.html
                    # www.bostonvirtualatc.com/charts/LPMA/AD/...
                    # www.rocketroute.com/airports/europe-eu/portugal-pt/...
                    $r->{windLocation} = $2;
                    push @{$metar{remark}}, { windAtLoc => $r };
                } else {
                    $r->{rwyDesig} = $2;
                    push @{$metar{remark}}, { rwyWind => $r };
                }
            } elsif (   _cyInString(' cJP cUS MM RK UT ')
                     && m{\G(8/([\d/])([\d/])([\d/])) }gc)
            {
                push @{$metar{remark}}, { cloudTypes => {
                    s => $1,
                    $2 eq '/' ? (cloudTypeLowNA => undef)
                              : (cloudTypeLow => $2),
                    $3 eq '/' ? (cloudTypeMiddleNA => undef)
                              : (cloudTypeMiddle => $3),
                    $4 eq '/' ? (cloudTypeHighNA => undef)
                              : (cloudTypeHigh => $4),
                }};
            } elsif (m{\G(PWINO|FZRANO|TSNO|PNO|RVRNO|NO ?SPECI|VIA PHONE|RCRNR|(?:LGT |HVY )?FROIN|SD[FGP]/HD[FGP]|VRBL CONDS|ACFT MSHP|(?:LTG DATA|RVR|CLD|WX|$re_vis|ALTM|WND) MISG|FIBI)[ /] ?}ogc)
            {
                $r->{s} = $1;
                ($r->{v} = $1) =~ tr/ /_/;
                $r->{v} =~ s/NO_?SPECI/NOSPECI/;
                $r->{v} =~ s/^$re_vis/VIS/o;
                push @{$metar{remark}}, { keyword => $r };
            } elsif (m{\G/ }gc){
                push @{$metar{remark}}, { keyword => {
                    s => '/',
                    v => 'slash'
                }};
            } elsif (/\G\$ /gc){
                push @{$metar{remark}}, { needMaint => { s => '$' }};
            } elsif (_cyInString(' cUS C ') && /\G(CIG ?(?:RAG|RGD)) /gc) {
                $r->{s} = $1;
                ($r->{v} = $1) =~ tr/ /_/;
                $r->{v} =~ s/RGD/RAG/;
                $r->{v} =~ s/CIGRAG/CIG_RAG/;
                push @{$metar{remark}}, { keyword => $r };
            } elsif (_cyIsC(' C ') && /\G(CIG VRBL? ([1-9]\d*)-([1-9]\d*)) /gc){
                $r->{s} = $1;
                $r->{visibilityFrom}{distance} = { v => $2 * 100, u => 'FT' };
                $r->{visibilityTo}{distance}   = { v => $3 * 100, u => 'FT' };
                push @{$metar{remark}}, { ceilVisVariable => $r };
            } elsif (   _cyInString(' cJP cUS BGTL C EG EQ ET LI LQ MM NZ OA RK TXKF ')
                     && m{\G(SLP ?(?:(\d\d)(\d)|NO|///)) }gc)
            {
                if (!defined $2) {
                    push @{$metar{remark}}, { SLP => {
                        s            => $1,
                        notAvailable => undef
                    }};
                # TODO: really need QNH? but values are REALLY close:
                # KLWM 161454Z AUTO 31012G21KT 10SM CLR M10/M18 A2808 RMK SLP511
                #   -> 951.1 hPa
                # KQHT 021355Z 26003KT 8000 IC M15/M16 A3070 RMK SLP484
                #   -> 1048.4 hPa
                # higher QNHs possible:
                # ETNS 161520Z 11006KT 7000 FEW020 M02/M05 Q1078 WHT WHT
                #   -> SLP78?
                # UNWW 021400Z 00000MPS CAVOK M25/M29 Q1056 NOSIG RMK QFE759
                #   -> SLP56?
                } elsif (!$qnhHPa && !$qnhInHg) {
                    if ($2 > 65 || $2 < 45) { # only if within sensible range
                        my $slp;

                        $slp = "$2.$3";
                        # threshold 55 taken from mdsplib
                        $slp += $slp < 55 ? 1000 : 900;
                        push @{$metar{remark}}, { SLP => {
                            s        => $1,
                            pressure =>
                                      { v => sprintf('%.1f', $slp), u => 'hPa' }
                        }};
                    } else {
                        push @{$metar{remark}}, { SLP => {
                            s => $1,
                            invalidFormat => "no QNH, x$2.$3 hPa"
                        }};
                    }
                } else {
                    # low temperature: SLP significantly greater than QNH:
                    # KEEO 111353Z ... M22/M23 A3046 RMK ... SLP437: 1031<->1043
                    # high altitude: SLP significantly smaller than QNH:
                    # KBJN 122256Z ... 11/M08 A3013 RMK ... SLP072: 1020<->1007
                    my ($slp, @slp, $qnh);
                    my $INHG2HPA = 33.86388640341;

                    @slp = ($1, $2, $3);
                    $qnh = _rnd($qnhHPa ? $qnhHPa : $qnhInHg * $INHG2HPA, 1);
                    $slp = $qnh;                          # start with given QNH
                    $slp =~ s/..$//;                  # remove 2 trailing digits
                    $slp .= "$slp[1].$slp[2]";              # append given value
                    $slp += 100 if $slp + 50 < $qnh;     # make SLP close to QNH
                    $slp -= 100 if $slp - 50 > $qnh;
                    push @{$metar{remark}}, { SLP => {
                        s        => $slp[0],
                        pressure => { v => sprintf('%.1f', $slp), u => 'hPa' }
                    }};
                }
            } elsif (   $metar{obsStationId}{id} eq 'ROTM'
                     && /\G(SP([23]\d\.\d{3})) /gc)
            {
                push @{$metar{remark}}, { SLP => {
                    s        => $1,
                    pressure => { v => $2, u => 'inHg' }
                }};
            } elsif (_cyIsCC(' NZ ') && m{\GGRID($re_wind) }ogc) {
                push @{$metar{remark}}, { sfcWind => {
                    s             => "GRID$1",
                    measurePeriod => {
                        v => _cyIsC('cUS') ? 2 : 10,
                        u => 'MIN'
                    },
                    wind => _parseWind($1, 0, 1)
                }};
            } elsif (   _cyInString(' BG EN LC LG LH LT SP UL URSS ')
                     && m{\G($re_rwy_wind) }ogc)
            {
                $r->{rwyWind}{s} = $1;
                $r->{rwyWind}{rwyDesig} = $2 // $3;
                $r->{rwyWind}{wind} = _parseWind $4;
                @{$r->{rwyWind}{wind}}{qw(windVarLeft windVarRight)}
                                                              = ($5 + 0, $6 + 0)
                    if defined $5;
                push @{$metar{remark}}, $r;
            } elsif (_cyIsCC(' RC ') && m{\G($re_rwy_wind2) }ogc) {
                push @{$metar{remark}}, { rwyWind => {
                    s        => $1,
                    wind     => _parseWind($2),
                    rwyDesig => $3
                }};
            } elsif (   _cyInString(' cJP cUS BG EGUN ET LQTZ NZ RK ')
                     && m{\G($re_rsc) }ogc)
            {
                $r->{s} = $1;
                for ($1 =~ /SLR|LSR|PSR|P|SANDED|WET|DRY|IR|WR|\/\/|\d\d/g){
                    push @{$r->{rwySfcCondArr}},
                          $_ eq '//' ? { notAvailable => undef }
                        : /\d/       ? { decelerometer => $_ }
                        :              { rwySfc => $_ };
                }
                push @{$metar{remark}}, { rwySfcCondition => $r };
            } elsif (   _cyInString(' cUS C ')
                     && /\G(((?:$re_opacity_phenom[0-8])+)(?: ($re_cloud_type) (?:(ASOCTD?)|(EMBDD?)))?) /ogc)
            {
                $r->{s} = $1;
                $r->{opacityPhenomArr} = ();
                _parseOpacityPhenom $r, $2;
                $r->{cloudTypeAsoctd} = $3 if defined $4;
                $r->{cloudTypeEmbd}   = $3 if defined $5;
                push @{$metar{remark}}, { opacityPhenom => $r };
            } elsif (   _cyInString(' BG KTTS ')
                     && /\G([0-8])($re_opacity_phenom) /ogc)
            {
                $r->{s} = "$1$2";
                $r->{opacityPhenomArr} = ();
                _parseOpacityPhenom $r, "$2$1";
                push @{$metar{remark}}, { opacityPhenom => $r };
            } elsif (   _cyInString(' cJP MN Y ')
                     && m{\G(([0-8])(?:((?:BL)?SN|FG)|($re_cloud_type))(\d{3})(?: TO)?($re_loc)?) }ogc)
            {
                push @{$metar{remark}}, { cloudOpacityLvl => {
                    s => $1,
                    sortedArr => [
                        defined $6 ? { locationAnd => _parseLocations $6 } : (),
                        { oktas => $2 },
                        defined $3 ? { weather => _parseWeather($3, 'NI')} : (),
                        defined $4 ? { cloudType => $4 } : (),
                        { cloudBase => _codeTable1690 $5 }
                ]}};
            } elsif (   _cyInString(' cUS EG ET LI NZ RK ')
                     && /\G(($re_cloud_cov$re_cloud_base?) V ($re_cloud_cov)) /ogc)
            {
                $r->{cloudCoverVar} = _parseCloud $2;
                $r->{cloudCoverVar}{s} = $1;
                $r->{cloudCoverVar}{cloudCover2} = $3;
                push @{$metar{remark}}, $r;
            } elsif (   _cyInString(' cUS BI C EK EQ LG LI LL MG MH MR MS NT OA OI ')
                     && m{\G($re_cloud_cov$re_cloud_base(?:///|$re_cloud_type)?) }ogc)
            {
                push @{$metar{remark}}, { cloud => _parseCloud $1 };
            } elsif (_cyIsC(' U ') && /\G($re_cloud_type)($re_cloud_base) /ogc){
                push @{$metar{remark}}, { cloudTypeLvl => {
                    s         => "$1$2",
                    cloudType => $1,
                    $2 eq '///' ? () : (cloudBase => _codeTable1690 $2)
                }};
            } elsif (   _cyIsC(' C ')
                     && m{\G(TRS?( LWR)?(?: CLD|((?:[/ ]?$re_trace_cloud)+))($re_loc)?) }ogc)
            {
                $r->{s} = $1;
                $r->{isLower} = undef if defined $2;
                if (defined $3) {
                    for ($3 =~ /$re_trace_cloud/og) {
                        push @{$r->{cloudType}}, $_;
                    }
                } else {
                    $r->{cloudTypeNotAvailable} = undef;
                }
                $r->{locationAnd} = _parseLocations $4 if defined $4;
                push @{$metar{remark}}, { cloudTrace => $r };
            } elsif (_cyIsC(' C ') && m{\G(((?:$re_trace_cloud[/ ])+)TR) }ogc) {
                $r->{s} = $1;
                for ($2 =~ /$re_trace_cloud/og) {
                    push @{$r->{cloudType}}, $_;
                }
                push @{$metar{remark}}, { cloudTrace => $r };
            } elsif (_cyIsCC(' MR ') && /\G(TRACE ($re_trace_cloud)) /ogc) {
                $r->{s} = $1;
                for ($2 =~ /$re_trace_cloud/og) {
                    push @{$r->{cloudType}}, $_;
                }
                push @{$metar{remark}}, { cloudTrace => $r };
            } elsif (/\GRE($re_weather_re) /ogc) {
                push @{$metar{remark}},
                               { recentWeather => [ _parseWeather($1, 'RE') ] };
            } elsif (   _cyIsCC(' KQ ')
                     && /\G(SFC $re_vis (?:($re_vis_m)|($re_vis_km))) /ogc)
            {
                $r->{s} = $1;
                $r->{locationAt} = 'SFC';
                if (defined $2) {
                    $r->{visibility}{distance} = _getVisibilityM $2;
                } else {
                    $r->{visibility}{distance} = { v => $3, rp => 1, u => 'KM'};
                    $r->{visibility}{distance}{v} =~ s/KM//;
                }
                push @{$metar{remark}}, { visibilityAtLoc => $r };
            } elsif (   _cyInString(' cUS C ')
                     && m{\G((SFC|TWR|ROOF) $re_vis ($re_vis_sm)(?: ?SM)?) }ogc)
            {
                $r->{s} = $1;
                $r->{locationAt} = $2;
                $r->{visibility} = _getVisibilitySM $3, $is_auto;
                push @{$metar{remark}}, { visibilityAtLoc => $r };
            } elsif (_cyIsC('cUS') && ($r = _visVarUS)) {
                push @{$metar{remark}}, $r;
            } elsif (   _cyIsC(' C ')
                     && m{\G($re_vis(?: VRB)? ($re_vis_sm) ?- ?($re_vis_sm)(?: ?SM)?) }ogc)
            {
                $r->{visVar1}{distance} = _parseFraction $2, 'SM';
                $r->{visVar2}{distance} = _parseFraction $3, 'SM';
                $r->{visVar1}{s} = $1;
                push @{$metar{remark}}, $r;
            } elsif (   _cyIsC(' C ')
                     && (($r = _precipCA $obs_hour,
                      defined $obs_hour ? $metar{obsTime}{timeAt}{minute} : 0)))
            {
                push @{$metar{remark}}, $r;
            } elsif (_cyIsC(' C ') && ($r = _visVarCA)) {
                push @{$metar{remark}}, $r;
            } elsif (_cyInString(' EG ET ') && /\G(VIS (\d{4})V(\d{4})) /gc) {
                $r->{visVar1}{distance} = _getVisibilityM $2;
                delete $r->{visVar1}{distance}{rp};
                $r->{visVar2}{distance} = _getVisibilityM $3;
                delete $r->{visVar2}{distance}{rp};
                $r->{visVar1}{s} = $1;
                push @{$metar{remark}}, $r;
            } elsif (_cyIsC(' C ') && /\G(PCPN (\d+\.\d)MM PAST HR) /gc) {
                push @{$metar{remark}}, { precipitation => {
                    s             => $1,
                    timeBeforeObs => { hours => 1 },
                    precipAmount  => { v => $2 + 0, u => 'MM' }
                }};
            } elsif (   _cyInString(' BG RK ')
                     && m{\G($re_vis ?$re_vis_m_km_remark3(?: TO | )?($re_compass_dir16(?:-$re_compass_dir16)*)) }ogc)
            {
                push @{$metar{remark}}, { visListAtLoc => {
                    s          => $1,
                    visLocData => {
                        locationAnd => _parseLocations($5),
                        visibility  => { distance =>
                              defined $2 ? _getVisibilityM $2
                            : defined $3 ? _getVisibilityM(sprintf '%04d', $3)
                            :              { v => $4, rp => 1, u => 'KM' }
                }}}};
            } elsif (   _cyInString(' cJP E KQ LQ NZ ')
                     && m{\G($re_vis($re_loc) $re_vis_m_km_remark3) }ogc)
            {
                my @visLocData;

                $r->{visListAtLoc} = {
                    s          => $1,
                    visLocData => \@visLocData
                };
                while (1) {
                    push @visLocData, {
                        locationAnd => _parseLocations($2),
                        visibility  => { distance =>
                              defined $3 ? _getVisibilityM $3
                            : defined $4 ? _getVisibilityM(sprintf '%04d', $4)
                            :              { v => $5, rp => 1, u => 'KM' }
                    }};

                    # leading blank required for re_loc
                    pos()--;
                    if (!m{\G((?: AND)?($re_loc) $re_vis_m_km_remark3) }ogc) {
                        pos()++;
                        last;
                    }

                    $r->{visListAtLoc}{s} .= $1;
                }
                push @{$metar{remark}}, $r;
            } elsif (_cyIsCC(' MH ') && m{\G((\d+)KM($re_loc)) }gc) {
                push @{$metar{remark}}, { visListAtLoc => {
                    s          => $1,
                    visLocData => {
                        locationAnd => _parseLocations($3),
                        visibility  => {
                                     distance => { v => $2, rp => 1, u => 'KM' }
                }}}};
            } elsif (m{\G($re_vis($re_loc) LWR) }ogc) {
                push @{$metar{remark}}, { phenomenon => {
                    s           => $1,
                    otherPhenom => 'VIS_LWR',
                    locationAnd => _parseLocations $2
                }};
            } elsif (   _cyInString(' cJP LI OA RC RP SE TU ')
                     && /\G(A)([23]\d)(\d\d) /gc)
            {
                push @{$metar{remark}}, { QNH => {
                    s        => "$1$2$3",
                    pressure => { v => "$2.$3", u => 'inHg' }
                }};
            } elsif (   _cyInString(' KQ OA ')
                     && /\G(Q(?:NH)?([01]\d{3})(?:MB)?) /gc)
            {
                push @{$metar{remark}}, { QNH => {
                    s        => $1,
                    pressure => { v => $2, u => 'hPa' }
                }};
            } elsif (   !$is_taf
                     && $metar{obsStationId}{id} eq 'WMAU'
                     && /\G(QFF ?(\d{3,4})) /gc)
            {
                push @{$metar{remark}}, { QFF => {
                    s        => $1,
                    pressure => { v => $2, u => 'hPa' }
                }};
            } elsif (/\G(QNH([01]\d{3}\.\d)) /gc) {
                push @{$metar{remark}}, { QNH => {
                    s        => $1,
                    pressure => { v => $2, u => 'hPa' }
                }};
            } elsif (/\G(COR ($re_hour)($re_min))Z? /ogc) {
                push @{$metar{remark}}, { correctedAt => {
                    s      => $1,
                    timeAt => { hour => $2, minute => $3 }
                }};
            } elsif (_cyIsC('cUS') && m{\G(SNINCR (\d+)/(\d+)) }gc) {
                push @{$metar{remark}}, { snowIncr => {
                    s        => $1,
                    pastHour => $2,
                    onGround => $3
                }};
            } elsif (   _cyInString(' cJP cUS BG C EG ET EQ LI LQ MM RK ')
                     && /\G1([01]\d{3}) /gc)
            {
                push @{$metar{remark}}, { tempMax => {
                    s             => "1$1",
                    timeBeforeObs => { hours => 6 },
                    temp          => _parseTemp $1
                }};
            } elsif (   _cyInString(' cJP cUS BG C EG ET EQ LI LQ MM RK ')
                     && /\G2([01]\d{3}) /gc)
            {
                push @{$metar{remark}}, { tempMin => {
                    s             => "2$1",
                    timeBeforeObs => { hours => 6 },
                    temp          => _parseTemp $1
                }};
            } elsif ($had_CA_RMK_prsChg && _cyIsC(' C ') && m{\G(5(\d{4})) }gc){
                # the meaning of the 5xxxx group depends on whether there
                # was a pressure change reported (as a 4-digit group) already.
                # Probably due to buggy translation from the SAO format by KWBC.
                # (more bugs: "PAST HR": leftover from "PCPN 0.4MM PAST HR",
                #             "M": (missing) should not be copied)
                push @{$metar{remark}}, { precipitation => {
                    s             => $1,
                    timeBeforeObs => { hours => 6 },
                    precipAmount  => { v => $2 / 10, u => 'MM' }
                }};
            } elsif (   (   _cyInString(' cJP cUS BG C EG ET EQ LI LQ MM RK ')
                         && m{\G(5(?:([0-8])(\d{3})|////)) }gc)
                     || (   _cyIsC(' C ')
                         && m{\G(([0-8])(\d{3})) (?=(?:SLP|PK |T[01]\d|$))}gc
                         && ($had_CA_RMK_prsChg = 1)))
            {
                push @{$metar{remark}}, { pressureChange => {
                    s             => $1,
                    timeBeforeObs => { hours => 3 },
                    defined $2
                      ? (pressureTendency  => $2,
                         pressureChangeVal => {
                            v => sprintf('%.1f', $3 / ($2 >= 5 ? -10 : 10) + 0),
                            u => 'hPa'
                         })
                      : (notAvailable => undef)
                }};
            } elsif (_cyIsC(' C ') && m{\G(\d{3}) (?=(?:SLP|PK |T[01]\d|$))}gc){
                # CXTN 251800Z AUTO ... RMK ... 001 ...
                # AAXX 25184 71492 ... 5/001 ...
                push @{$metar{remark}}, { pressureChange => {
                    s             => $1,
                    timeBeforeObs => { hours => 3 },
                    invalidFormat => $1
                }};
                $had_CA_RMK_prsChg = 1;
            } elsif (   _cyInString(' cJP cUS BG C EG ET EQ LP LQ NZ ROTM ')
                     && m{\G((?:PK|MAX)[ /]?WND ?(GRID ?)?($re_wind_dir3$re_wind_speed)($re_wind_speed_unit)?(?:/| AT )($re_hour)?($re_min)Z?) }ogc)
            {
                push @{$metar{remark}}, { peakWind => {
                    s      => $1,
                    wind   => _parseWind($3 . ($4 // 'KT'), 0, defined $2),
                    timeAt => { defined $5 ? (hour => $5) : (), minute => $6 }
                }};
            } elsif (   $metar{obsStationId}{id} eq 'KEHA'
                     && m{\G(PK[ /]?WND ($re_wind_speed) 000) }ogc)
            {
                push @{$metar{remark}}, { peakWind => {
                    s    => $1,
                    wind => _parseWind "///$2KT"
                }};
            } elsif (   $metar{obsStationId}{id} eq 'EDLP'
                     && /\GRWY ?($re_rwy_des) ?(TRL[0 ]?(\d\d))(?: ([A-Z]{2}))? ((?:ATIS )?)([A-Z]) /ogc)
            {
                push @{$metar{remark}}, { activeRwy => {
                    s        => "RWY$1",
                    rwyDesig => $1
                }};
                push @{$metar{remark}}, { transitionLvl => {
                    s     => $2,
                    level => $3 + 0
                }};
                push @{$metar{remark}}, { obsInitials => { s => $4 }}
                    if defined $4;
                push @{$metar{remark}}, { currentATIS => {
                    s    => "$5$6",
                    ATIS => $6
                }};
            } elsif (_cyInString(' LSZR EDHL ') && /\G([A-Z]) /gc) {
                push @{$metar{remark}}, { currentATIS => {
                    s    => $1,
                    ATIS => $1
                }};
            } elsif (   _cyInString(' VT TJ ')
                     && /\G(RWY ?($re_rwy_des)(?: IN USE)?) /ogc)
            {
                push @{$metar{remark}}, { activeRwy => {
                    s        => $1,
                    rwyDesig => $2
                }};
            } elsif (_cyIsCC(' VT ') && /\G(INFO[ :]*([A-Z])) /gc) {
                push @{$metar{remark}}, { currentATIS => {
                    s    => $1,
                    ATIS => $2
                }};
            } elsif (/\G(ATIS[ :]*(?:CODE )?([A-Z])) /gc) {
                push @{$metar{remark}}, { currentATIS => {
                    s    => $1,
                    ATIS => $2
                }};
            } elsif (   _cyInString(' cJP cUS BG C EG ET EQ LI RK ')
                     && /\G(T([01]\d{3})([01]\d{3})?) /gc)
            {
                $r->{s} = $1;
                $r->{air}{temp} = _parseTemp $2;
                if (defined $3) {
                    $r->{dewpoint}{temp} = _parseTemp $3;
                    _setHumidity $r;
                }
                push @{$metar{remark}}, { temperature => $r };
            } elsif (_cyIsC('cUS') && m{\G(98(?:(\d{3})|///)) }gc) {
                $r->{s} = $1;
                $r->{sunshinePeriod} = 'p';
                if (defined $2) {
                    $r->{sunshine} = { v => $2 + 0, u => 'MIN' };
                } else {
                    $r->{sunshineNotAvailable} = undef;
                }
                push @{$metar{remark}}, { radiationSun => $r };
            } elsif (_cyInString(' UTTP UTSS ') && /\G(QFE([01]?\d{3})) /gc) {
                push @{$metar{remark}}, { QFE => {
                    s        => $1,
                    pressure => { v => $2 + 0, u => 'hPa' }
                }};
            } elsif (   $metar{obsStationId}{id} eq 'FVHA'
                     && /\G(QFE (\d{3}\.\d)) /gc)
            {
                push @{$metar{remark}}, { QFE => {
                    s        => $1,
                    pressure => { v => $2, u => 'hPa' }
                }};
            } elsif (   _cyInString(' cUS C OA OM ')
                     && m{\G(/?(DA|DENSITY ALT|PA)[ /]?([+-]?\d+)(?:FT)?/?) }gc)
            {
                push @{$metar{remark}}, { ({ DA            => 'densityAlt',
                                             'DENSITY ALT' => 'densityAlt',
                                             PA            => 'pressureAlt'
                                           }->{$2})
                                          => {
                    s        => $1,
                    altitude => { v => $3 + 0, u => 'FT' }
                }};
            } elsif (/\G(R\.?H ?\.? ?(\d\d)(?: ?PC)?) /gc) {
                push @{$metar{remark}}, { RH => { s => $1, relHumid => $2 + 0}};
            } elsif (   $metar{obsStationId}{id} eq 'KNIP'
                     && m{\G((RH|SST|AI|OAT)/(\d\d)F?) }gc)
            {
                $r->{s} = $1;
                if ($2 eq 'SST' || $2 eq 'OAT') {
                    $r->{temp} = { v => $3 + 0, u => 'F' };
                } elsif ($2 eq 'RH') {
                    $r->{relHumid} = $3 + 0;
                } else {
                    $r->{"$2Val"} = $3 + 0;
                }
                push @{$metar{remark}}, { $2 => $r };
            } elsif (_cyIsCC(' KN ') && m{\G((RH|SST)/(\d+)) }gc) {
                $r->{s} = $1;
                if ($2 eq 'SST') {
                    $r->{temp} = { v => $3 + 0, u => 'C' };
                } else {
                    $r->{relHumid} = $3 + 0;
                }
                push @{$metar{remark}}, { $2 => $r };
            } elsif (   _cyInString(' U ZM ')
                     && m{\G(QFE ?(\d{3})(?:[,.](\d))?(?:/(\d{3,4}))?) }gc)
            {
                $r->{s} = $1;
                push @{$r->{pressure}},
                    { v => ($2 + 0) . (defined $3 ? ".$3" : ''), u => 'mmHg' };
                push @{$r->{pressure}}, { v => ($4 + 0), u => 'hPa' }
                    if defined $4;
                push @{$metar{remark}}, { QFE => $r };
            } elsif (/\G(((?:VIS|CHI)NO) R(?:WY)? ?($re_rwy_des)) /ogc) {
                push @{$metar{remark}}, { $2 => {
                    s => $1,
                    rwyDesig => $3
                }};
            } elsif (_cyIsC(' C ') && m{\G($re_snw_cvr) }ogc) {
                $r->{s} = $1;
                $r->{snowCoverType} = $2 // 'NIL';
                $r->{snowCoverType} =~ s/ONE /ONE_/;
                $r->{snowCoverType} =~ s/MU?CH /MUCH_/;
                $r->{snowCoverType} =~ s/TR(?:ACE ?)? ?/TRACE_/;
                $r->{snowCoverType} =~ s/MED(?:IUM)?/MEDIUM/;
                $r->{snowCoverType} =~ s/ PACK(?:ED)?/_PACKED/;
                push @{$metar{remark}}, { snowCover => $r };
            } elsif (_cyIsC(' C ') && /\G(OBS TAKEN [+](\d+)) /gc) {
                push @{$metar{remark}}, { obsTimeOffset => {
                    s       => $1,
                    minutes => $2
                }};
            } elsif (   _cyIsC(' C ')
                     && /\G((?:BLN (?:DSA?PRD (\d+) ?FT\.?|VI?SBL(?: TO)? (\d+) ?FT))) /gc)
            {
                $r->{s} = $1;
                if (defined $2) {
                    $r->{disappearedAt} = { distance => { v => $2, u => 'FT' }};
                } else {
                    $r->{visibleTo} = { distance => { v => $3, u => 'FT' }};
                }
                push @{$metar{remark}}, { balloon => $r };
            } elsif (   _cyIsC(' C ')
                     && /\G(RVR(?: RWY ?$re_rwy_des $re_rwy_vis ?FT\.?)+) /ogc)
            {
                for ($1 =~ /((?:RVR )?RWY ?$re_rwy_des $re_rwy_vis ?FT\.?)/og) {
                    my $v;

                    $v->{s} = "$_";

                    /($re_rwy_des) ($re_rwy_vis)/o;

                    $v->{rwyDesig}      = $1;
                    $v->{RVR}{distance} = { v => $2, u => 'FT' };
                    if ($v->{RVR}{distance}{v} =~ s/^M//) {
                        $v->{RVR}{distance}{q} = 'isLess';
                    } elsif ($v->{RVR}{distance}{v} =~ s/^P//) {
                        $v->{RVR}{distance}{q} = 'isEqualGreater';
                    } else {
                        _setVisibilityFTRVRrange $v->{RVR}{distance};
                    }
                    $v->{RVR}{distance}{v} += 0;
                    push @{$metar{remark}}, { visRwy => $v };
                }
            } elsif (_cyIsCC(' FQ ') && m{\G(TX/(\d\d[,.]\d)) }gc) {
                $r->{tempMaxFQ}{s} = $1;
                $r->{tempMaxFQ}{temp} = { v => $2, u => 'C' };
                $r->{tempMaxFQ}{temp}{v} =~ s/,/./;
                push @{$metar{remark}}, $r;
            } elsif (   _cyIsC(' C ')
                     && /\G(NXT FCST BY (?:($re_hour)|($re_day)($re_hour)($re_min))Z) /ogc)
            {
                if (defined $2) {
                    push @{$metar{remark}}, { nextFcst => {
                        s      => $1,
                        timeBy => { hour => $2 }
                    }};
                } else {
                    push @{$metar{remark}}, { nextFcst => {
                        s      => $1,
                        timeBy => { day => $3, hour => $4, minute => $5 }
                    }};
                }
            } elsif (   _cyIsC(' C ')
                     && /\G(NXT FCST WILL BE ISSUED AT ($re_day)($re_hour)($re_min)Z) /ogc)
            {
                push @{$metar{remark}}, { nextFcst => {
                    s      => $1,
                    timeAt => { day => $2, hour => $3, minute => $4 }
                }};
            } elsif (   _cyIsCC(' LT ')
                     && /\G(AMD AT ($re_day)($re_hour)($re_min)Z) /ogc)
            {
                push @{$metar{remark}}, { amdAt => {
                    s      => $1,
                    timeAt => { day => $2, hour => $3, minute => $4 }
                }};
            } elsif (   _cyIsC(' C ')
                     && /\G(FCST BASED ON AUTO OBS(?: ($re_hour)-($re_hour)Z| ($re_day)($re_hour)($re_min)-($re_day)($re_hour)($re_min)Z)?\.?) /ogc)
            {
                push @{$metar{remark}}, { fcstAutoObs => {
                    s => $1,
                    defined $2
                        ? (timeFrom => { hour => $2 },
                           timeTill => { hour => $3 })
                        : (),
                    defined $4
                        ? (timeFrom => { day => $4, hour => $5, minute => $6 },
                           timeTill => { day => $7, hour => $8, minute => $9 })
                        : ()
                }};
            } elsif (_cyIsCC(' EF ') && /\G(BASED ON AUTOMETAR) /gc) {
                push @{$metar{remark}}, { fcstAutoMETAR => { s => $1 }};
            } elsif (_cyIsCC(' ED ') && /\G(ATIS ([A-Z])([A-Z-]{2})?) /gc) {
                push @{$metar{remark}}, { currentATIS => {
                    s    => $1,
                    ATIS => $2
                }};
            } elsif (   m{\G(((?:$re_data_estmd[ /])+)(?:VISUALLY )?$re_estmd) }ogc
                     || m{\G($re_estmd((?:[ /]$re_data_estmd)+)) }ogc)
            {
                $r->{s} = $1;
                for ($2 =~ /$re_data_estmd/og) {
                    s/ALT\KM?/M/;
                    s/WI?NDS?(?: DATA)?/WND/;
                    s/CEILING/CIG/;
                    s/(?:CIG )?BLN/CIG BLN/;
                    s/ /_/g;
                    push @{$r->{estimatedItem}}, $_;
                    $winds_est = 1 if $_ eq 'WND';
                }
                push @{$metar{remark}}, { estimated => $r };
            } elsif (/\G((?:(THN) )?($re_cloud_cov) ABV (\d{3})) /ogc) {
                $r = _parseCloud "$3$4", 'isGreater';
                $r->{s} = $1;
                $r->{cloudCover}{q} = 'isThin'
                    if exists $r->{cloudCover} && defined $2;
                push @{$metar{remark}}, { cloudAbove => $r };
            } elsif (_cyInString(' cUS NZ RK ') && ($r = _obscuration)) {
                push @{$metar{remark}}, $r;
            } elsif (   _cyIsC(' Y ')
                     && m{\G(RF(\d\d)\.(\d)/(\d{3})\.(\d)(?:/(\d{3})\.(\d))?) }gc)
            {
                #http://reg.bom.gov.au/general/reg/aviation_ehelp/metarspeci.pdf
                push @{$metar{remark}}, { rainfall => {
                    s             => $1,
                    precipArr => [
                    { precipitation => {
                        s            => "$2.$3",
                        precipAmount => { v => ($2 + 0) . ".$3", u => 'MM' },
                        timeBeforeObs => { minutes => 10 }
                      }},
                    { precipitation => {
                      s            => "$4.$5",
                      precipAmount => { v => ($4 + 0) . ".$5", u => 'MM' },
                      defined $6
                          ? (timeBeforeObs => { minutes => 60 })
                          : (timeSince => {
                                  hour => { v => '09', q => 'localtime' }})
                    }},
                    defined $6
                        ? { precipitation => {
                            s            => "$6.$7",
                            precipAmount => { v => ($6 +0) . ".$7", u => 'MM' },
                            timeSince    =>
                                  { hour => { v => '09', q => 'localtime' } }
                          }}
                        : ()
                    ]
                }};
            } elsif (   $metar{obsStationId}{id} eq 'KHMS'
                     && m{\G(RSNK (M?\d\d)((?:\.\d)?)/(${re_wind_dir}0$re_wind_speed(?:G$re_wind_speed)?)($re_wind_speed_unit)?) }ogc)
            {
                my $temp;

                $temp = _parseTempMetaf $2;
                $temp->{v} .= $3;
                push @{$metar{remark}}, { RSNK => {
                    s    => $1,
                    air  => { temp => $temp },
                    wind => _parseWind $4 . ($5 || 'KT')
                }};
            } elsif (   $metar{obsStationId}{id} eq 'KNTD'
                     && m{\G(LAG ?PK (M?\d\d)/(M?\d\d)/(${re_wind_dir}0$re_wind_speed(?:G$re_wind_speed)?)) }ogc)
            {
                push @{$metar{remark}}, { LAG_PK => {
                    s        => $1,
                    air      => { temp => _parseTempMetaf $2 },
                    dewpoint => { temp => _parseTempMetaf $3 },
                    wind     => _parseWind "$4KT"
                }};
            } elsif (   _cyInString(' KAEG KAUN KBVS KUKT KW22 ')
                     && /\G(P(\d{3})) /gc)
            {
                push @{$metar{remark}}, { precipitation => {
                    s             => $1,
                    timeBeforeObs => { hours => 1 },
                    $2 == 0 ? (precipTraces => undef)
                            : (precipAmount => {
                                   v => sprintf('%.2f', $2 / 100),
                                   u => 'IN' })
                }};

            } elsif (($r = _parsePhenoms)) {
                push @{$metar{remark}}, $r;
            } elsif (m{\G((?:PR(?:ESENT )?WX:? ?)?(DSNT )?((?:(?:AND )?$re_phen_desc[/ ]?)+)$re_phenomenon4( BBLO| VC)?(?: ($re_cloud_type) (?:(ASOCTD?)|(EMBDD?)))?) }ogc)
            {
                $r->{s} = $1;
                _parsePhenomDescr $r, 'phenomDescrPre', $3 if defined $3;
                if (defined $4) {
                    _parsePhenom \$r, $4;
                } elsif (defined $5) {
                    @{$r->{cloudType}} = split m{[/-]}, $5;
                } elsif (defined $6) {
                    # phenomenon _can_ have intensity, but it is an EXTENSION
                    $r->{weather} = _parseWeather $6, 'NI';
                } else {
                    $r->{cloudCover} = $7;
                }
                if (defined $8) {
                    if ($8 eq ' VC') {
                        $r->{locationAnd}{locationThru}{location}{inVicinity}
                                                                        = undef;
                    } else {
                        _parsePhenomDescr $r, 'phenomDescrPost', $8;
                    }
                }
                $r->{cloudTypeAsoctd} = $9 if defined $10;
                $r->{cloudTypeEmbd}   = $9 if defined $11;
                $r->{locationAnd}{locationThru}{location}{inDistance} = undef
                    if defined $2;
                push @{$metar{remark}}, { phenomenon => $r };

            # first check a restricted set of phenomenon and descriptions!

            } elsif (m{\G(GR ($re_gs_size)) }ogc) {
                push @{$metar{remark}}, { hailStones => {
                    s        => $1,
                    diameter => _parseFraction($2, 'IN')
                }};
            } elsif (/\G((PRES[FR]R)( PAST HR)?) /gc) {
                $r->{s} = $1;
                $r->{otherPhenom} = $2;
                _parsePhenomDescr $r, 'phenomDescrPost', $3 if defined $3;
                push @{$metar{remark}}, { phenomenon => $r };
            } elsif (/\G(CLDS LWR RWY($re_rwy_des)) /ogc) {
                push @{$metar{remark}}, { ceilingAtLoc => {
                    s           => $1,
                    cloudsLower => undef,
                    rwyDesig    => $2
                }};
            } elsif (   _cyIsCC(' SP ')
                     && /\G(([+-]?RA (?:(?:EN LA )?NOCHE|AT NIGHT) )?PP(?:(\d{3})|TRZ)) /gc)
            {
                # derived from corresponding SYNOP
                if (defined $2) {
                    push @{$metar{remark}}, { rainfall => {
                        s             => $1,
                        precipitation => {
                            s          => $3 || 'TRZ',
                            timePeriod => 'n',
                            defined $3 ? (precipAmount => {
                                              v => sprintf('%.1f', $3 / 10),
                                              u => 'MM' })
                                       : (precipTraces => undef)
                    }}};
                } else {
                    push @{$metar{remark}}, { precipitation => {
                        s             => $1,
                        timeBeforeObs => { hours => 1 },
                        defined $3 ? (precipAmount => {
                                          v => sprintf('%.1f', $3 / 10),
                                          u => 'MM' })
                                   : (precipTraces => undef)
                    }};
                }
            } elsif (   _cyIsCC(' SP ')
                     && m{\G(BIRD HAZARD(?: RWY[ /]?($re_rwy_des(?:/$re_rwy_des)?))?) }ogc)
            {
                push @{$metar{remark}}, { birdStrikeHazard => {
                    s => $1,
                    defined $2 ? (rwyDesig => $2) : ()
                }};
            } elsif (   _cyInString(' cJP cUS BG C EG ET EQ LI MM RK ')
                     && m{\G(($re_be_weather+)($re_loc)?$re_wx_mov_d3?) }ogc)
            {
                $r->{weatherHist}{s} = $1;
                $r->{weatherHist}{locationAnd} = _parseLocations $3
                    if defined $3;
                $r->{weatherHist}{$4}{locationAnd} = _parseLocations $5
                    if defined $5;
                $r->{weatherHist}{isStationary} = undef if defined $6;
                $r->{weatherHist}{weatherBeginEnd} = ();
                for ($2 =~ /$re_be_weather/og) {
                    my (@weatherBEArr, $weatherBeginEnd);
                    my ($weather, $times) = /(.*?)((?: ?$re_be_weather_be|[BE]MM)+)/og;
                    for ($times =~ /$re_be_weather_be|[BE]MM/og) {
                        my ($type, $dat1, $dat2, %s_e);

                        ($type, $dat1, $dat2) = unpack 'aa2a2';
                        if ($dat2 ne '') {
                            $s_e{timeAt}{hour} = $dat1;
                            $s_e{timeAt}{minute} = $dat2 if $dat2 ne 'MM';
                        } else {
                            $s_e{timeAt}{minute} = $dat1 if $dat1 ne 'MM';
                        }
                        push @weatherBEArr, {
                            ($type eq 'B' ? 'weatherBegan' : 'weatherEnded')
                                                                    => \%s_e
                        };
                    }
                    $weatherBeginEnd = _parseWeather $weather, 'NI';
                    delete $weatherBeginEnd->{s};
                    $weatherBeginEnd->{weatherBEArr} = \@weatherBEArr;
                    push @{$r->{weatherHist}{weatherBeginEnd}}, $weatherBeginEnd;
                }
                push @{$metar{remark}}, $r;
            } elsif (_cyIsCC(' EH ') && m/\G((TS|WX|CB) INFO NOT AVBL) /gc) {
                # http://www.knmi.nl/waarschuwingen_en_verwachtingen/luchtvaart/131114_AUTO_METAR_Amd76_14Nov2013_DEFINITIEF.pdf
                push @{$metar{remark}},{ keyword => { s => $1, v => "${2}NO" }};
            } elsif (m{\G(($re_phenomenon_other)(?: IS)?((?:[/ ](?:$re_phen_desc_when|BBLO))*)(?: ($re_cloud_type) (?:(ASOCTD?)|(EMBDD?)))?) }ogc)
            {
                $r->{s} = $1;
                _parsePhenom \$r, $2;
                _parsePhenomDescr $r, 'phenomDescrPost', $3 if defined $3;
                $r->{cloudTypeAsoctd} = $4 if defined $5;
                $r->{cloudTypeEmbd}   = $4 if defined $6;
                push @{$metar{remark}}, { phenomenon => $r };
            } elsif (m{\G((?:PR(?:ESENT )?WX:? ?)?(DSNT )?$re_phenomenon4((?: IS)?(?:[/ ](?:(?:AND )?$re_phen_desc|BBLO))*)(?: ?($re_cloud_type) (?:(ASOCTD?)|(EMBDD?)))?) }ogc)
            {
                $r->{s} = $1;
                if (defined $3) {
                    _parsePhenom \$r, $3;
                } elsif (defined $4) {
                    @{$r->{cloudType}} = split m{[/-]}, $4;
                } elsif (defined $5) {
                    # phenomenon _can_ have intensity, but it is an EXTENSION
                    $r->{weather} = _parseWeather $5, 'NI';
                } else {
                    $r->{cloudCover} = $6;
                }
                _parsePhenomDescr $r, 'phenomDescrPost', $7 if defined $7;
                $r->{cloudTypeAsoctd} = $8 if defined $9;
                $r->{cloudTypeEmbd}   = $8 if defined $10;
                $r->{locationAnd}{locationThru}{location}{inDistance} = undef
                    if defined $2;
                push @{$metar{remark}}, { phenomenon => $r };
            } elsif (/\G(AO(?:1|2A?)) /gc) {
                push @{$metar{remark}}, { obsStationType => {
                    s           => $1,
                    stationType => $1
                }};
            } elsif (m{\G(CIG (\d{3})(?:(?:(?: (APCH))?(?: RWY ?| R?)?($re_rwy_des))(?: TO)?($re_loc)?|(?: TO)?($re_loc))) }ogc)
            {
                $r->{s} = $1;
                $r->{cloudBase}  = _codeTable1690 $2;
                $r->{isApproach} = undef if defined $3;
                $r->{rwyDesig} = $4 if defined $4;
                $r->{locationAnd} =_parseLocations $5 if defined $5;
                $r->{locationAnd} =_parseLocations $6 if defined $6;
                push @{$metar{remark}}, { ceilingAtLoc => $r };
            } elsif (m{\G($re_vis ($re_vis_sm)(?: ?SM)?(?: (APCH))?(?: RWY ?| R?)?($re_rwy_des)) }ogc)
            {
                $r->{s} = $1;
                $r->{visibility} = _getVisibilitySM $2, $is_auto;
                $r->{isApproach} = undef if defined $3;
                $r->{rwyDesig} = $4;
                push @{$metar{remark}}, { visibilityAtLoc => $r };
            } elsif (/\G(NOSIG|CAVU|$re_estmd PASS (?:OPEN|CLOSED|CLSD|MARGINAL|MRGL)|PASS $re_estmd CLSD|EPC|EPO|EPM|RTS) /ogc)
            {
                $r->{s} = $1;
                $r->{v} = $1;
                if ($r->{v} =~ m{PASS OP}) {
                    $r->{v} = 'EPO';
                } elsif ($r->{v} =~ m{PASS .*?CL}) {
                    $r->{v} = 'EPC';
                } elsif ($r->{v} =~ m{PASS M}) {
                    $r->{v} = 'EPM';
                }
                push @{$metar{remark}}, { keyword => $r };
            } elsif (   _cyIsC('cUS')
                     && (   /\G((?:($re_hour)($re_min)Z? )?WEA ?:) ?/ogc
                         || /\G((?:($re_hour)($re_min)Z? )?WEA) /ogc))
            {
                $r->{s} = $1;
                $r->{timeAt} = { hour => $2, minute => $3 }
                    if defined $2;
                if (/\G(NONE) /gc) {
                    $r->{s} .= ' ' . $1;
                    push @{$r->{weather}}, { s => $1, NSW => undef }
                }
                push @{$metar{remark}}, { weatherMan => $r };
            } elsif (   _cyIsCC(' PA ')
                     && /\G(SEA (\d)) (SWELL (\d) ($re_compass_dir16)) /ogc)
            {
                push @{$metar{remark}}, { seaCondition => {
                    s          => $1,
                    seaCondVal => $2
                }};
                push @{$metar{remark}}, { swellCondition => {
                    s            => $3,
                    locationAnd  => { locationThru => { location =>
                                      { compassDir => $5 }}},
                    swellCondVal => $4
                }};
            } elsif (m{\G((?:CLIMAT ?)?($re_temp)/($re_temp)(?:/(TR|$re_precip)(?:/(NIL|$re_precip))?)?) }ogc)
            {
                $r->{s} = $1;
                $r->{temp1}{temp} = { v => $2 + 0, u => 'C' };
                $r->{temp2}{temp} = { v => $3 + 0, u => 'C' };
                if (defined $4) {
                    my ($precip1, $precip2);

                    if ($4 eq 'TR') {
                        push @{$r->{sortedArr}}, { precipTraces => undef };
                    } else {
                        $precip1 = $4;
                    }
                    if (defined $5) {
                        if ($5 eq 'NIL') {
                            push @{$r->{sortedArr}}, { precipAmount2MM => 0 };
                        } else {
                            $precip2 = $5;
                            if ($precip2 =~ s/ ?([MC]M)//) {
                                push @{$r->{sortedArr}},
                                    { precipAmount2MM =>
                                             $precip2 * ($1 eq 'CM' ? 10 : 1) };
                            } else {
                                push @{$r->{sortedArr}},
                                    { precipAmount2Inch => $precip2 + 0 };
                            }
                        }
                    }
                    if (defined $precip1) {
                        if ($precip1 =~ s/ ?([MC]M)//) {
                            unshift @{$r->{sortedArr}},
                                { precipAmount1MM =>
                                             $precip1 * ($1 eq 'CM' ? 10 : 1) };
                        } else {
                            unshift @{$r->{sortedArr}},
                                { precipAmount1Inch => $precip1 + 0 };
                        }
                    }
                }
                push @{$metar{remark}}, { climate => {
                    s => $r->{s},
                    exists $r->{sortedArr} ? (sortedArr => $r->{sortedArr}) :(),
                    temp1 => $r->{temp1},
                    temp2 => $r->{temp2}
                }};
            } elsif (m{\G((TORNADO|FUNNEL CLOUDS?|WATERSPOUT) ($re_be_weather_be+)(?: TO)?($re_loc)$re_wx_mov_d3?) }ogc) {
                $r->{s} = $1;
                $r->{weatherBeginEnd}{tornado}{v} = lc $2;
                $r->{locationAnd} = _parseLocations $4;
                $r->{$5}{locationAnd} = _parseLocations $6 if defined $6;
                $r->{isStationary} = undef if defined $7;
                $r->{weatherBeginEnd}{weatherBEArr} = ();
                for ($3 =~ /$re_be_weather_be/og) {
                    my ($type, $dat1, $dat2, %s_e);

                    ($type, $dat1, $dat2) = unpack 'aa2a2';
                    if ($dat2 ne '') {
                        $s_e{timeAt}{hour} = $dat1;
                        $s_e{timeAt}{minute} = $dat2;
                    } else {
                        $s_e{timeAt}{minute} = $dat1;
                    }
                    push @{$r->{weatherBeginEnd}{weatherBEArr}}, {
                       ($type eq 'B' ? 'weatherBegan' : 'weatherEnded') => \%s_e
                    };
                }
                $r->{weatherBeginEnd}{tornado}{v} =~ s/ (cloud)s?/_$1/;
                push @{$metar{remark}}, { weatherHist => $r };
            } elsif (m{\G((?:FIRST|FST)(?:( STAFFED| STFD)|( MANNED))?(?: OBS?)?)[ /] ?}gc)
            {
                $r->{s} = $1;
                $r->{isStaffed} = undef if defined $2;
                $r->{isManned} = undef if defined $3;
                push @{$metar{remark}}, { firstObs => $r };
            } elsif (/\G(NEXT ($re_day)($re_hour)($re_min)(?: ?UTC| ?Z)?) /ogc){
                $r->{s} = $1;
                @{$r->{timeAt}}{qw(day hour minute)} = ($2, $3, $4)
                    if defined $2;
                push @{$metar{remark}}, { nextObs => $r };
            } elsif (m{\G(LAST(?:( STAFFED| STFD)|( MANNED))?(?: OBS?)?(?: ($re_day)($re_hour)($re_min)(?: ?UTC| ?Z)?)?)[ /] ?}ogc)
            {
                $r->{s} = $1;
                $r->{isStaffed} = undef if defined $2;
                $r->{isManned} = undef if defined $3;
                @{$r->{timeAt}}{qw(day hour minute)} = ($4, $5, $6)
                    if defined $4;
                push @{$metar{remark}}, { lastObs => $r };
            } elsif (/\G((QBB|QBJ)(\d\d0)) /gc) {
                push @{$metar{remark}}, { $2 => {
                    s => $1,
                    altitude => { v => $3 + 0, u => 'M' }
                }};
            # from mdsplib, http://avstop.com/ac/aviationweather:
            } elsif (/\G(RADAT (?:(\d\d)(\d{3})|MISG)) /gc) {
                $r->{s} = $1;
                if (defined $2) {
                    $r->{relHumid} = $2 + 0;
                    $r->{distance} = { v => $3 * 100, u => 'FT' };
                } else {
                    $r->{isMissing} = undef;
                }
                push @{$metar{remark}}, { RADAT => $r };
            } elsif (_cyIsCC(' LF ') && /\G([MB])(\d) /gc) {
                push @{$metar{remark}}, { reportConcerns => {
                    s       => "$1$2",
                    change  => $1,
                    subject => $2
                }};
            } elsif (   _cyInString(' EN EK ')
                     && /\G(WI?ND ((?:AT )?\d+ ?FT) ($re_wind)(?: ($re_wind_dir3)V($re_wind_dir3))?) /ogc)
            {
                push @{$metar{remark}}, _parseWindAtLoc($1, $2, $3, $8, $9);
            } elsif (/\G((2000FT|CNTR RWY|HARBOR|ROOF|(?:BAY )?TWR) WI?ND ($re_wind)(?: ($re_wind_dir3)V($re_wind_dir3))?) /ogc)
            {
                push @{$metar{remark}}, _parseWindAtLoc($1, $2, $3, $8, $9);
            } elsif (/\G((BAY TWR|WNDY HILL|KAUKAU|SUGARLOAF|CLN AIR) ($re_wind)(?: ($re_wind_dir3)V($re_wind_dir3))?) /ogc)
            {
                push @{$metar{remark}}, _parseWindAtLoc($1, $2, $3, $8, $9);
            } elsif (   _cyIsCC(' MN ')
                     && m{\G((?:V[./]?P[/ ])($re_wind)(?: ($re_wind_dir3)V($re_wind_dir3))?) }ogc)
            {
                # TODO: VP = viento pista?
                push @{$metar{remark}}, _parseWindAtLoc($1, 'VP', $2, $7, $8);
            } elsif (   !(   exists $metar{sfcWind}
                          && exists $metar{sfcWind}{wind}
                          && !exists $metar{sfcWind}{wind}{notAvailable})
                     && m{\G(($re_wind)(?: ($re_wind_dir3)V($re_wind_dir3))?) }ogc)
            {
                $r->{sfcWind} = {
                    s    => $1,
                    wind => _parseWind $2
                };
                @{$r->{sfcWind}{wind}}{qw(windVarLeft windVarRight)}
                                                              = ($7 + 0, $8 + 0)
                    if defined $7;
                push @{$metar{remark}}, $r;
            } elsif (   _cyInString(' EQ LI OA ')
                     && /\G($re_vis ?MIN ?($re_vis_m)M?(?: TO | )?($re_compass_dir)?) /ogc)
            {
                $r->{s} = $1;
                $r->{distance} = _getVisibilityM $2;
                $r->{compassDir} = $3 if defined $3;
                push @{$metar{remark}}, { visMin => $r };
            } elsif (_cyIsCC(' UB ') && m{\G(G/([OZ])) }gc) {
                push @{$metar{remark}}, { phenomenon => {
                    s           => $1,
                    otherPhenom => $2 eq 'O' ? 'MTNS_OPEN' : 'MTNS_OBSC'
                }};
            } elsif (_cyInString ' EQ LI ') {
                my $re_cond_moun =
                      '(?:LIB|CLD SCT|VERS INC|CNS POST|CLD CIME'
                    . '|CIME INC|GEN INC|INC|INVIS)';
                my $re_chg_moun =
                       '(?:NC|CUF'
                     . '|ELEV (?:SLW|RAPID|STF)'
                     . '|ABB (?:SLW|RAPID)'
                     . '|STF(?: ABB)?'
                     . '|VAR RAPID)';
                my $re_cond_vall =
                      '(?:NIL|FOSCHIA(?: SKC SUP)?|NEBBIA(?: SCT)?'
                    . '|CLD SCT(?: NEBBIA INF)?|MAR CLD|INVIS)';
                my $re_chg_vall =
                      '(?:NC|ELEV|DIM(?: ELEV| ABB)?|AUM(?: ELEV| ABB)?|ABB'
                    . '|NEBBIA INTER)';
                my $re_moun = "$re_loc? $re_cond_moun(?: $re_chg_moun)?";
                my $re_vall = "$re_loc? $re_cond_vall(?: $re_chg_vall)?";
                if (m{\G(MON((?:$re_moun)+)) }ogc) {
                    $r->{s} = $1;
                    $r->{condMountainLoc} = ();
                    for ($2 =~ m{$re_moun}og) {
                        my $m;
                        m{($re_loc)? ($re_cond_moun)(?: ($re_chg_moun))?}o;

                        $m->{locationAnd}     =_parseLocations $1 if defined $1;
                        $m->{cloudMountain} = {
                                               'LIB'      => 0,
                                               'CLD SCT'  => 1,
                                               'VERS INC' => 2,
                                               'CNS POST' => 3,
                                               'CLD CIME' => 5,
                                               'CIME INC' => 6,
                                               'GEN INC'  => 7,
                                               'INC'      => 8,
                                               'INVIS'    => 9
                                               }->{$2};
                        $m->{cloudEvol} = {
                                           'NC'         => 0,
                                           'CUF'        => 1,
                                           'ELEV SLW'   => 2,
                                           'ELEV RAPID' => 3,
                                           'ELEV STF'   => 4,
                                           'ABB SLW'    => 5,
                                           'ABB RAPID'  => 6,
                                           'STF'        => 7,
                                           'STF ABB'    => 8,
                                           'VAR RAPID'  => 9
                                          }->{$3}
                            if defined $3;
                        push @{$r->{condMountainLoc}}, $m;
                    }
                    push @{$metar{remark}}, { conditionMountain => $r };
                } elsif (m{\G(VAL((?:$re_vall)+)) }ogc) {
                    $r->{s} = $1;
                    $r->{condValleyLoc} = ();
                    for ($2 =~ m{$re_vall}og) {
                        my $m;
                        m{($re_loc)? ($re_cond_vall)(?: ($re_chg_vall))?}o;

                        $m->{locationAnd}     =_parseLocations $1 if defined $1;
                        $m->{cloudValley} = {
                                             'NIL'                => 0,
                                             'FOSCHIA SKC SUP'    => 1,
                                             'NEBBIA SCT'         => 2,
                                             'FOSCHIA'            => 3,
                                             'NEBBIA'             => 4,
                                             'CLD SCT'            => 5,
                                             'CLD SCT NEBBIA INF' => 6,
                                             'MAR CLD'            => 8,
                                             'INVIS'              => 9
                                            }->{$2};
                        $m->{cloudBelowEvol} = {
                                                'NC'           => 0,
                                                'DIM ELEV'     => 1,
                                                'DIM'          => 2,
                                                'ELEV'         => 3,
                                                'DIM ABB'      => 4,
                                                'AUM ELEV'     => 5,
                                                'ABB'          => 6,
                                                'AUM'          => 7,
                                                'AUM ABB'      => 8,
                                                'NEBBIA INTER' => 9
                                               }->{$3}
                            if defined $3;
                        push @{$r->{condValleyLoc}}, $m;
                    }
                    push @{$metar{remark}}, { conditionValley => $r };
                } elsif (m{\G(QU(L|K) ?([\d/])(?: ?($re_compass_dir16))?) }ogc){
                    my $key = $2 eq 'K' ? 'sea' : 'swell';

                    $r->{s} = $1;
                    if ($3 eq '/') {
                        $r->{notAvailable} = undef;
                    } else {
                        $r->{"${key}CondVal"} = $3;
                    }
                    $r->{locationAnd} = _parseLocations $4 if defined $4;
                    push @{$metar{remark}}, { "${key}Condition" => $r };
                } elsif (/\G($re_vis (MAR) ([1-9]\d*) KM) /ogc) {
                    $r->{s} = $1;
                    $r->{locationAt} = $2;
                    $r->{visibility}{distance} = { v => $3, u => 'KM' };
                    push @{$metar{remark}}, { visibilityAtLoc => $r };
                } elsif (/\G((?:WIND THR ?|WT)($re_rwy_des) ($re_wind)(?: ($re_wind_dir3)V($re_wind_dir3))?) /ogc)
                {
                    $r->{thrWind} = {
                        s        => $1,
                        rwyDesig => $2,
                        wind     => _parseWind $3
                    };
                    @{$r->{thrWind}{wind}}{qw(windVarLeft windVarRight)}
                                                              = ($8 + 0, $9 + 0)
                        if defined $8;
                    push @{$metar{remark}}, $r;
                } else {
                    $parsed = 0;
                }
            } elsif(_cyIsCC(' LK ') && /\G(REG QNH ([01]\d{3})) /gc) {
                push @{$metar{remark}}, { regQNH => {
                    s        => $1,
                    pressure => { v => $2, u => 'hPa' }
                }};
            } elsif ($metar{obsStationId}{id} eq 'ZMUB' && /\G(\d\d) /gc) {
                push @{$metar{remark}}, { RH => {
                    s        => $1,
                    relHumid => $1
                }};
            } elsif (m{\G($re_vis ($re_vis_sm) ?SM(?: TO)? ($re_compass_dir16)) }ogc)
            {
                push @{$metar{remark}}, { visListAtLoc => {
                    s          => $1,
                    visLocData => {
                        locationAnd => _parseLocations($3),
                        visibility  => _getVisibilitySM $2, $is_auto
                }}};
            } elsif (m{\G($re_vis(?: TO)? ($re_compass_dir16) ($re_vis_sm) ?SM) }ogc)
            {
                push @{$metar{remark}}, { visListAtLoc => {
                    s          => $1,
                    visLocData => {
                        locationAnd => _parseLocations($2),
                        visibility  => _getVisibilitySM $3, $is_auto
                }}};
            } elsif (_cyIsC(' Y ') && ($r = _turbulenceTxt)) {
                push @{$metar{remark}}, { turbulence => $r };
            } elsif ($is_taf && _cyIsC(' Y ') && ($r = _parseTQfcst())) {
                # http://reg.bom.gov.au/aviation/knowledge-centre/ -> TAF
                # (these are not distributed internationally)
                push @{$metar{remark}}, { temp_fcst => $r->{temp_fcst} }
                    if exists $r->{temp_fcst};
                push @{$metar{remark}}, { QNH_fcst => $r->{QNH_fcst} }
                    if exists $r->{QNH_fcst};
            } elsif (   $is_taf
                     && _cyIsCC(' ES ')
                     && /\G((?:ISSUED )?BY ($re_ICAO)) /ogc)
            {
                push @{$metar{remark}}, { issuedBy => { s => $1, id => $2 }};
            } else {
                $parsed = 0;
            }

            if (!$parsed && _cyInString ' cJP cUS BG C EG ET EQ LI MM RK ') {
                $parsed = 1;
                if (m{\G(4([01]\d{3}|////)([01]\d{3}|////)) }gc) {
                    push @{$metar{remark}}, { tempExtreme => {
                        s              => $1,
                        tempExtremeMax => {
                            $2 eq '////' ? (notAvailable => undef)
                                         : (temp          => _parseTemp($2),
                                            timeBeforeObs => { hours => 24 })
                        },
                        tempExtremeMin => {
                            $3 eq '////' ? (notAvailable => undef)
                                         : (temp          => _parseTemp($3),
                                            timeBeforeObs => { hours => 24 })
                        }
                    }};
                } elsif (m{\G(4/(\d{3})) }gc) {
                    push @{$metar{remark}}, { snowDepth => {
                        s            => $1,
                        precipAmount => { v => $2 + 0, u => 'IN' }
                    }};
                } elsif (_cyIsC(' C ') && /\G(SOG ?(\d+)) /gc) {
                    push @{$metar{remark}}, { snowDepth => {
                        s            => $1,
                        precipAmount => { v => $2 + 0, u => 'CM' }
                    }};
                # TODO: MMxx: unit and period unknown
                } elsif (   !_cyInString(' KAEG KAUN KBVS KUKT KW22 MM ')
                         && m{\G((P|6|7)(?:(\d{4})|////)) }gc)
                {
                    # AFMAN 15-111, Dec. '03, 2.8.1
                    $r->{s} = $1;
                    if (defined $3) {
                        if ($3 == 0) {
                            $r->{precipTraces} = undef;
                        } else {
                            $r->{precipAmount} =
                                  { v => sprintf('%.2f', $3 / 100), u => 'IN' };
                        }
                        if ($2 eq 'P') {
                            $r->{timeBeforeObs}{hours} = 1;
                        } elsif ($2 eq '7') {
                            $r->{timeBeforeObs}{hours} = 24;
                        } else {
                            # EXTENSION: allow 20 minutes
                            if (defined $obs_hour) {
                                my $hhmm;

                                $hhmm = $obs_hour . $metar{obsTime}{timeAt}{minute};
                                if ($hhmm =~
                                    '(?:(?:23|05|11|17)[45]|(?:00|06|12|18)[01])\d')
                                {
                                    $r->{timeBeforeObs}{hours} = 6;
                                } elsif ($hhmm =~
                                    '(?:(?:02|08|14|20)[45]|(?:03|09|15|21)[01])\d')
                                {
                                    $r->{timeBeforeObs}{hours} = 3;
                                } else {
                                    $r->{timePeriod} = '3or6h';
                                }
                            } else {
                                $r->{timePeriod} = '3or6h';
                            }
                        }
                    } else {
                        $r->{notAvailable} = undef;
                    }
                    push @{$metar{remark}}, { precipitation => $r };
                # EXTENSION: allow slash after 933 (PATA)
                } elsif (m{\G(933/?(\d{3})) }gc) {
                    push @{$metar{remark}}, { waterEquivOfSnow => {
                        s            => $1,
                        precipAmount =>
                                    { v => sprintf('%.1f', $2 / 10), u => 'IN' }
                    }};
                } elsif (m{\G(931(\d{3})) }gc) {
                    push @{$metar{remark}}, { snowFall => {
                        s             => $1,
                        timeBeforeObs => { hours => 6 },
                        precipAmount  =>
                                    { v => sprintf('%.1f', $2 / 10), u => 'IN' }
                    }};
                } elsif (/\G(CIG (\d{3})V(\d{3})) /gc) {
                    push @{$metar{remark}}, { variableCeiling => {
                        s => $1,
                        cloudBaseFrom => { v => $2 * 100, u => 'FT' },
                        cloudBaseTo   => { v => $3 * 100, u => 'FT' }
                    }};
                } elsif (/\G(CIG (\d{4})V(\d{4})) /gc) {
                    push @{$metar{remark}}, { variableCeiling => {
                        s => $1,
                        cloudBaseFrom => { v => $2 + 0, u => 'FT' },
                        cloudBaseTo   => { v => $3 + 0, u => 'FT' }
                    }};
                } elsif (/\G(WSHFT ?(?:AT )?($re_hour)?($re_min)Z?( FROPA)?) /ogc) {
                    $r->{windShift}{s} = $1;
                    $r->{windShift}{timeAt}{hour} = $2 if defined $2;
                    $r->{windShift}{timeAt}{minute} = $3;
                    $r->{windShift}{FROPA} = undef if defined $4;
                    push @{$metar{remark}}, $r;
                } elsif (m{\G($re_vis ($re_vis_sm)(?: ?SM)?(?: TO)? ($re_compass_dir16(?:-$re_compass_dir16)?)) }ogc){
                    push @{$metar{remark}}, { visListAtLoc => {
                        s          => $1,
                        visLocData => {
                            locationAnd => _parseLocations($3),
                            visibility  => _getVisibilitySM $2, $is_auto
                    }}};
                } elsif (m{\G($re_vis($re_loc) ?($re_vis_sm)(?: ?SM)?) }ogc) {
                    my @visLocData;

                    $r->{visListAtLoc} = {
                        s          => $1,
                        visLocData => \@visLocData
                    };
                    while (1) {
                        push @visLocData, {
                            locationAnd => _parseLocations($2),
                            visibility  => _getVisibilitySM $3, $is_auto
                        };

                        # leading blank required for re_loc
                        pos()--;
                        if (!m{\G((?: AND)?($re_loc) ?($re_vis_sm)(?: ?SM)?) }ogc)
                        {
                            pos()++;
                            last;
                        }

                        $r->{visListAtLoc}{s} .= $1;
                    }
                    push @{$metar{remark}}, $r;
                } elsif (m{\G(I([136])(?:///|(\d)(\d\d))) }ogc) {
                    # www.nws.noaa.gov/ops2/Surface/asosimplementation.htm
                    # version 3.07
                    push @{$metar{remark}}, { iceAccretion => {
                        s             => $1,
                        timeBeforeObs => { hours => $2 },
                          !defined $3     ? (notAvailable => undef)
                        : "$3$4" eq '000' ? (thicknessTraces => undef)
                        :             (thickness => { v => "$3.$4", u => 'IN' })
                    }};
                } else {
                    $parsed = 0;
                }
            }

            if (!$parsed && /\G(BA (?:GOOD|POOR)|THN SPTS IOVC|FUOCTY|ALL WNDS GRID|CONTRAILS?|FOGGY|TWLGT) /gc)
            {
                $parsed = 1;
                $r->{s} = $1;
                ($r->{v} = $1) =~ tr/\/ /_/;
                $r->{v} =~ s/CONTRAILS?/CONTRAILS/;
                push @{$metar{remark}}, { keyword => $r };
                $winds_grid = $r->{v} eq 'ALL_WNDS_GRID';
            }

            # if DSNT or DSIPTD could not be parsed and the last remark was a
            # phenomenon and no unrecognised entry is pending:
            #   assign it to the phenomenon
            if (!$parsed && $notRecognised eq '' && /\G(DSNT|DSIPTD) /) {
                my $cnt;

                $cnt = $#{$metar{remark}};
                if ($cnt > -1 && exists ${$metar{remark}}[$cnt]{phenomenon}) {
                    $parsed = 1;
                    pos() += length($1) + 1;
                    $r = ${$metar{remark}}[$cnt]{phenomenon};
                    $r->{s} .= " $1";
                    if ($1 eq 'DSNT') {
                        if (exists $r->{locationAnd}) {
                            for (ref $r->{locationAnd}{locationThru} eq 'ARRAY'
                                 ? @{$r->{locationAnd}{locationThru}}
                                 : $r->{locationAnd}{locationThru})
                            {
                                for (ref $_->{location} eq 'ARRAY'
                                     ? @{$_->{location}} : $_->{location})
                                {
                                    $_->{inDistance} = undef;
                                }
                            }
                        } else {
                           $r->{locationAnd}{locationThru}{location}{inDistance}
                                = undef;
                        }
                    } else {
                        _parsePhenomDescr $r, 'phenomDescrPost', $1;
                    }
                }
            }

            if (!$parsed) {
                $notRecognised .= ' ' unless $notRecognised eq '';
                # TAF: do not parse anything after something not recognised
                if ($is_taf ? /\G(.*) /gc : /\G(\S+) /gc) {
                    $notRecognised .= $1;
                } else { # "cannot" happen
                    $notRecognised .= substr $_, pos;
                    pos = length;
                }
            }
            if ($parsed && $notRecognised ne '') {
                # just found something which was recognised but have something
                # not recognised from previous loop(s) => insert before last
                my $top = pop @{$metar{remark}};
                push @{$metar{remark}},
                                    { notRecognised => { s => $notRecognised }};
                push @{$metar{remark}}, $top;
                $notRecognised = '';
            }
        }
        push @{$metar{remark}}, { notRecognised => { s => $notRecognised }}
            if $notRecognised ne '';
    }

    # if winds are grid/estimated: propagate this to all winds
    if ($winds_grid || $winds_est) {
        for ((map { $_->{sfcWind} || (),
                    $_->{windAtLoc} || (),
                    $_->{rwyWind} ? @{$_->{rwyWind}} : (),
                    map { $_->{windShearLvl} || ()
                      } exists $_->{trendSupplArr} ? @{$_->{trendSupplArr}} : ()
                  } (\%metar, exists $metar{trend} ? @{$metar{trend}} : ())),
             map {    $_->{sfcWind}
                   || $_->{rwyWind}
                   || $_->{peakWind}
                   || $_->{RSNK}
                   || $_->{LAG_PK}
                   || $_->{thrWind}
                   || $_->{windAtLoc}
                   || ()
                 } exists $metar{remark} ? @{$metar{remark}} : ())
        {
            $_->{wind}{dir}{q} = 'isGrid'
                if $winds_grid && exists $_->{wind}{dir};

            if (   $winds_est
                && !exists $_->{wind}{notAvailable}
                && !exists $_->{wind}{invalidFormat})
            {
                $_->{wind}{isEstimated} = undef;
                $_->{wind}{dir} = $_->{wind}{dir}{v}
                    if exists $_->{wind}{dir} && exists $_->{wind}{dir}{v};
            }
        }
    }

    $metar{ERROR} = _makeErrorMsgPos 'other' if length > pos;

    if (!exists $metar{ERROR}) {
        push @{$metar{warning}}, { warningType => 'windMissing' }
            unless exists $metar{sfcWind} || exists $metar{fcstNotAvbl};
        push @{$metar{warning}}, { warningType => 'visibilityMissing' }
            unless    exists $metar{visPrev} || exists $metar{visMin}
                   || exists $metar{CAVOK} || exists $metar{fcstNotAvbl};
        push @{$metar{warning}}, { warningType => 'tempMissing' }
            unless $is_taf || exists $metar{temperature};
        push @{$metar{warning}}, { warningType => 'QNHMissing' }
            unless $is_taf || exists $metar{QNH} || exists $metar{QFE};
    }

    return %metar;
}

########################################################################
# callback function to write XML
########################################################################
{
    my ($opts_xml, $XML, $XML_str);

    sub _set_opts_xml {
        $opts_xml = shift;
        return;
    }

    sub _get_XML_str {
        return $XML_str;
    }

    sub _write_xml {
        my ($path, $type, $node, @attrs) = @_;
        my ($rc, $content, %options);

        if ($type eq 'end') {
            $XML_str .= ' ' x $#$path . '</' . $node . '>' . "\n";

            # end of report/input: print XML. end of input: close output stream
            if (defined $XML && ($#$path == 2 || $#$path == 0)) {
                $rc = print {$XML} $XML_str;
                $XML_str = '';
                close $XML or return 0      # always close, even if print failed
                    if $#$path == 0;
                return $rc;
            }
            return 1;
        }

        if ($#$path == 0 && $type eq 'start') {
            $XML_str = '';
            $XML = undef;

            # open output stream
            if (exists $opts_xml->{o} && $opts_xml->{o} ne '') {
                # use two-argument "open" for special files, only
                if ($opts_xml->{o} eq '-' || $opts_xml->{o} =~ /^&\d+$/) {
                    $rc = open $XML, ">$opts_xml->{o}";
                } else {
                    $rc = open $XML, '>', $opts_xml->{o};
                }
                if (!$rc) {
                    $XML = undef;
                    return 0;
                }
            }

            # append HTTP response header if requested
            $XML_str .= $opts_xml->{I}
                if exists $opts_xml->{I};

            # append XML declaration
            $XML_str .= '<?xml version="1.0" encoding="UTF-8"?>' . "\n";

            # append document type declaration if requested
            $XML_str .= '<!DOCTYPE data SYSTEM "metaf.dtd">' . "\n"
                if exists $opts_xml->{D};

            # append stylesheet declaration if requested
            $XML_str .=   '<?xml-stylesheet href="' . $opts_xml->{S}
                        . '" type="text/xsl"?>' . "\n"
                if exists $opts_xml->{S};

            # append Perl version, current time
            $XML_str .=   "<!-- Perl: $^V -->\n"
                        . '<!-- ' . gmtime() . " -->\n";
        }

        # append node of type 'start' or 'empty'
        $XML_str .= ' ' x $#$path . '<' . $node;
        while (defined (my $name = shift @attrs)) {
            my $value = shift @attrs;

            # escape XML characters invalid for attribute values
            $value =~ s/&/&amp;/g; # must be the first substitution
            $value =~ s/</&lt;/g;
            $value =~ s/>/&gt;/g;  # not required, but xmllint does it
            $value =~ s/"/&quot;/g;
            if ($name eq '') {
                $content = $value;
            } else {
                $XML_str .= ' ' . $name . '="' . $value . '"';
            }
        }
        if ($type eq 'start') {
            $XML_str .= ">\n";
        } elsif (defined $content) {
            $XML_str .= '>' . $content . '</' . $node . ">\n";
        } else {
            $XML_str .= "/>\n";
        }

        return 1
            unless $#$path == 0 && $type eq 'start';

        if (exists $opts_xml->{O}) {
            my $msgs;

            # parse options to append to XML file (no validation here!)
            (@options{'type_metaf', 'type_synop', 'type_buoy', 'type_amdar',
                      'lang', 'format',
                      'src_metaf',  'src_synop',  'src_buoy',  'src_amdar',
                      'mode', 'hours'},
             $msgs)
                = split / /, $opts_xml->{O}, 13;
            @options{'msg_metaf', 'msg_synop', 'msg_buoy', 'msg_amdar'}
                = split '  ', $msgs, 4;

            # append node 'options'
            _write_xml([ @$path, $node ], 'empty', 'options',
                       map { $_ => $options{$_} } sort keys %options)
                or return 0;
        }

        return 1
            unless defined $XML;

        $rc = print {$XML} $XML_str;
        $XML_str = '';
        return $rc;
    }
}

########################################################################
# from here: helper functions
########################################################################

########################################################################
# invoke callback function for start and end of a node, set @node_path
########################################################################
{
    my $node_callback;

    sub _set_cb {
        $node_callback = shift;
        return ref $node_callback eq 'CODE' ? 1 : 0;
    }

    # arguments: type, node[, name, value, ...]
    sub _new_node {
        my $type = shift;
        my $node = shift;
        my $rc;

        $rc = $node_callback->(\@node_path, $type, $node, @_);
        push @node_path, $node
            if $type eq 'start';
        return $rc;
    }

    sub _end_node {
        my $node = pop @node_path;

        return $node_callback->(\@node_path, 'end', $node);
    }
}

########################################################################
# walk through data structure, sort items to comply with the DTD
########################################################################
sub _walk_data {
    my ($r, $node, $xml_tag) = @_;

    $r = $r->{$node};

    $node = $xml_tag if $xml_tag;
    if (ref $r eq 'HASH') {
        my (@subnodes, @attrs);

        # nodes with special attributes and no subnodes
        return _new_node 'empty', 'ERROR',
                         errorType => $r->{errorType}, s => $r->{s}
            if $node eq 'ERROR';
        return _new_node 'empty', 'warning',
                         warningType => $r->{warningType},
                         exists $r->{s} ? (s => $r->{s}) : ()
            if $node eq 'warning';
        return _new_node 'empty', 'info',
                         xmlns => '',
                         map { $_ => $r->{$_} } keys %$r
            if $node eq '_stationInfo';

        # force special sequence to comply with the DTD
        if ($node eq 'phenomenon') {
            push @subnodes, map { exists $r->{$_} ? $_ : () }
                qw(phenomDescrPre phenomDescrPost weather cloudType cloudCover
                   lightningType otherPhenom obscgMtns locationAnd MOV MOVD
                   isStationary cloudTypeAsoctd cloudTypeEmbd);
            push @attrs, s => $r->{s};
        } else {
            push @subnodes, sort map {
                         $_ eq 'v' || $_ eq 'u' || $_ eq 'q' || $_ eq 's'
                      || $_ eq 'rp' || $_ eq 'rpi' || $_ eq 'rn' || $_ eq 'rne'
                      || $_ eq 'occurred' || $_ eq 'above'
                    ? () : $_
                } keys %$r;

            # sort attributes, so XML looks nicer
            push @attrs, occurred => $r->{occurred}
                if $node eq 'timeBeforeObs' && exists $r->{occurred};
            push @attrs, above => $r->{above}
                if $node eq 'sensorHeight' && exists $r->{above};
            for (qw(s v rp rpi rn rne u q)) {
                push @attrs, $_ => $r->{$_} if exists $r->{$_};
            }
        }

        # *Arr are arrays with different subnodes, suppress node
        if ($#subnodes > -1) {
            _new_node 'start', $node, @attrs or return 0
                unless $node =~ /Arr$/;
            for (@subnodes) {
                _walk_data($r, $_) or return 0;
            }
            _end_node or return 0 unless $node =~ /Arr$/;
        } else {
            _new_node 'empty', $node, @attrs or return 0
                unless $node =~ /Arr$/;
        }
    } elsif (ref $r eq 'ARRAY') {
        if ($#$r > -1) {
            for (@$r) {
                _walk_data({ $node => $_ }, $node) or return 0;
            }
        } else {
            _new_node 'empty', $node or return 0;
        }
    } else {
        _new_node 'empty', $node, defined $r ? (v => $r) : () or return 0;
    }
    return 1;
}

our $_mk_station_info;

########################################################################
# write as XML/invoke callback for each data item
########################################################################
sub _print_report {
    my $report = shift;

    return 0 if $#node_path == -1;

    if (exists $report->{isSynop}) {
        _new_node 'start', 'synop', 's', $report->{msg} or return 0;

        if (defined $_mk_station_info) {
            if (exists $report->{obsStationType}) {
                $report->{obsStationId}{_stationInfo} =
                        $_mk_station_info->($report->{obsStationId}{id}, 'wmo')
                    if    exists $report->{obsStationId}
                       && exists $report->{obsStationId}{id}
                       && $report->{obsStationType}{stationType} eq 'AAXX';
                $report->{callSign}{_stationInfo} =
                        $_mk_station_info->($report->{callSign}{id}, 'ship')
                    if    exists $report->{callSign}
                       && $report->{obsStationType}{stationType} eq 'BBXX';
                $report->{callSign}{_stationInfo} =
                        $_mk_station_info->($report->{callSign}{id}, 'mobil')
                    if    exists $report->{callSign}
                       && $report->{obsStationType}{stationType} eq 'OOXX';
            } else {
                $report->{obsStationId}{_stationInfo} = {}
                    if exists $report->{obsStationId};
                $report->{callSign}{_stationInfo} = {}
                    if exists $report->{callSign};
            }
        }

        for (qw(ERROR warning
                obsStationType callSign obsTime reportModifier
                windIndicator stationPosition obsStationId precipInd wxInd
                baseLowestCloud visPrev visibilityAtLoc totalCloudCover
                sfcWind temperature stationPressure SLP gpSurface
                pressureChange precipitation weatherSynop cloudTypes
                exactObsTime))
        {
            _walk_data $report, $_ or return 0
                if exists $report->{$_};
        }

        for (2 .. 5, 9) {
            if (exists $report->{"section$_"}) {
                if ($#{$report->{"section$_"}} > -1) {
                    _new_node 'start', "synop_section$_", 's', $_ x 3
                        or return 0;
                    _walk_data { Arr => $report->{"section$_"} }, 'Arr'
                        or return 0;
                    _end_node or return 0;
                } else {
                    _new_node 'empty', "synop_section$_", 's', $_ x 3
                        or return 0;
                }
            }
        }
    } elsif (exists $report->{isBuoy}) {
        _new_node 'start', 'buoy', 's', $report->{msg}
            or return 0;

        $report->{buoyId}{_stationInfo} =
                $_mk_station_info->($report->{buoyId}{id}, 'buoy')
            if defined $_mk_station_info && exists $report->{buoyId};

        for (qw(ERROR warning
                obsStationType buoyId obsTime reportModifier
                windIndicator stationPosition
                qualityPositionTime visPrev))
        {
            _walk_data $report, $_ or return 0
                if exists $report->{$_};
        }

        for (1 .. 4) {
            if (exists $report->{"section$_"}) {
                if ($#{$report->{"section$_"}} > -1) {
                    _new_node 'start', "buoy_section$_", 's', $_ x 3
                        or return 0;
                    _walk_data { Arr => $report->{"section$_"} }, 'Arr'
                        or return 0;
                    _end_node or return 0;
                } else {
                    _new_node 'empty', "buoy_section$_", 's', $_ x 3
                        or return 0;
                }
            }
        }
    } elsif (exists $report->{isAmdar}) {
        _new_node 'start', 'amdar', 's', $report->{msg}
            or return 0;

        $report->{aircraftId}{_stationInfo} =
                $_mk_station_info->($report->{aircraftId}{id}, 'ac')
            if defined $_mk_station_info && exists $report->{aircraftId};

        for (qw(ERROR warning
                reportModifier obsStationType phaseOfFlight
                aircraftId aircraftLocation obsTime
                amdarObs amdarInfo))
        {
            _walk_data $report, $_ or return 0
                if exists $report->{$_};
        }

        for (3) {
            if (exists $report->{"section$_"}) {
                if ($#{$report->{"section$_"}} > -1) {
                    _new_node 'start', "amdar_section$_", 's', $_ x 3
                        or return 0;
                    _walk_data { Arr => $report->{"section$_"} }, 'Arr'
                        or return 0;
                    _end_node or return 0;
                } else {
                    _new_node 'empty', "amdar_section$_", 's', $_ x 3
                        or return 0;
                }
            }
        }
    } else {
        my $is_taf;

        $is_taf = exists $report->{isTaf};
        _new_node 'start', $is_taf ? 'taf' : 'metar', 's', $report->{msg}
            or return 0;

        $report->{obsStationId}{_stationInfo} =
                $_mk_station_info->($report->{obsStationId}{id}, 'icao')
            if defined $_mk_station_info && exists $report->{obsStationId};

        for (qw(ERROR warning isSpeci
                obsStationId obsTime issueTime fcstPeriod reportModifier
                fcstCancelled fcstNotAvbl
                skyObstructed sfcWind windShearLvlArr
                CAVOK visPrev visMin visMax visRwy RVRNO weather cloud visVert
                temperature QNH QFE stationPressure
                cloudMaxCover recentWeather windShear
                waterTemp seaCondition waveHeight
                rwyState colourCode RH trendSupplArr))
        {
            _walk_data $report, $_ or return 0
                if exists $report->{$_};
        }

        if (exists $report->{trend}) {
            for my $td (@{$report->{trend}}) {
                _new_node 'start', 'trend', 's', $td->{s};
                for (qw(trendType timeAt timeFrom timeTill probability
                        sfcWind CAVOK visPrev weather cloud visVert
                        rwyState colourCode trendSupplArr))
                {
                    _walk_data $td, $_ or return 0
                        if exists $td->{$_};
                }
                _end_node or return 0;
            }
        }

        _walk_data $report, 'TAFinfoArr' or return 0
            if exists $report->{TAFinfoArr};
        _walk_data $report, 'remark', $is_taf ? 'tafRemark' : 'remark'
                or return 0
            if exists $report->{remark};
    }
    return _end_node;
}

=head1 SUBROUTINES/METHODS

=cut

########################################################################
# start_cb
########################################################################

=head2 start_cb(\&cb)

This function sets the function to be called for each node and its attributes
and then opens the nodes "data" and "reports".

See L<finish()|/finish()> for how to complete the processing of reports.

The following argument is expected:

=over

=item C<cb>

Reference to the callback function.

The following arguments are passed to the callback function:

=over

=item C<path>

This is a reference to an array containing the names of all parent nodes of the
current node.

=item C<type>

This will have one the values C<empty>, C<start> or C<end>.
For each C<start>, the function is also called with the matching C<end> after
all subnodes have been processed.
For C<empty> (a node without subnodes, but possibly attributes and character
data (an attribute with an empty string for the name)), the function is only
called once.

=item C<node>

This is the name of the current node.

=item [C<name>, C<value>, ...]

This is an (optionally empty) list of pairs of node attribute names and values.
If C<type> is C<end>, the list is always empty.

=back

The callback function should return one the following values:

=over

=item C<0>

An error occurred which should abort the processing.

=item C<1>

No error occurred.

=back

=back

The function will return one of the following values:

=over

=item C<0>

An error occurred. Possible error causes:

=over

=item *

the function was called in improper sequence, or

=item *

the argument C<cb> was not a reference to a function, or

=item *

the callback function C<cb> returned an error while processing the opening of
the nodes "data" or "reports".

=back

=item C<1>

No error occurred.

=back

=cut

sub start_cb {
    # check state
    return 0 if $#node_path != -1;

    # set callback function and state
    _set_cb shift or return 0;
    push @node_path, '';

    # start processing
    _new_node 'start', 'data' or return 0;
    return _new_node 'start', 'reports',
                     xmlns => 'http://metaf2xml.sourceforge.net/2.1';
}

########################################################################
# start_xml
########################################################################

=head2 start_xml(\%opts)

This function sets the options relevant for writing the data as XML and starts
to write the XML file by opening the nodes "data" and "reports".

See L<finish()|/finish()> for how to complete the processing of reports.

The following argument is expected:

=over

=item C<opts>

Reference to hash of options. The following keys of the hash are recognised:

=over

=item C<o>, contains the value for I<out_file>

enables writing the data to I<out_file> (or standard output if it is C<->)

=item C<D>

include DOCTYPE and reference to the DTD

=item C<S>, contains the value for I<xslt_file>

include reference to the stylesheet I<xslt_file>

=item C<O>, contains the value for I<options>

include I<options> (a space separated list of parameters from/for metaf.pl)

=back

Without the key C<o>, no output is generated.

=back

The function will return one of the following values:

=over

=item C<0>

An error occurred. Possible error causes:

=over

=item *

the function was called in improper sequence, or

=item *

the internal callback function to write the data as XML encountered an error
while trying to open the output file or write to it the XML for the nodes "data"
or "reports".

=back

=item C<1>

No error occurred.

=back

=cut

sub start_xml {
    _set_opts_xml shift;
    return start_cb \&_write_xml;
}

########################################################################
# parse_report
########################################################################
sub parse_report {

=head2 parse_report($msg,$default_msg_type)

This function parses a METAR, TAF, SYNOP, BUOY or AMDAR message or processes a
decoded BUFR message. It then writes the data as XML or invokes a
callback function for each data item.

The following arguments are expected:

=over

=item msg

string that contains the message. It is required to be in the format specified
by the I<WMO Manual No. 306>, B<without modifications due to distribution>
like providing the initial part of messages only once for several messages or
appending an "=" (equal sign) to terminate a message.
The Perl module C<metaf2xml::src2raw> or the program C<metafsrc2raw.pl> can be
used to create messages with the required format from files provided by various
public Internet servers.

=item default_msg_type

the default message type. It can be C<METAR>, C<SPECI>, C<TAF> or
undefined/omitted.
If the message starts with:

=over

=item C<METAR>, C<SPECI> or C<TAF>

this is used as message type.

=item C<AAXX>, C<BBXX> or C<OOXX>

the message type SYNOP is used.

=item C<ZZYY>

the message type BUOY is used.

=item C<AMDAR>

the message type AMDAR is used.

=item B<FXXYYY>C<:> or B<FXXYYY>C</> or B<FXXYYY>C<->

the message type BUFR is used for this message. See
L</Processing of decoded BUFR messages>
for a description of the format.

=back

=back

Leading and trailing spaces are removed, multiple spaces are
replaced by a single one. Characters that are invalid in HTML or XML are also
removed.

=cut

    my ($default_msg_type, $msg_head5, %report);

    local $_ = shift;
    $default_msg_type = shift;
    return 0
        if    !defined $_
           || (   defined $default_msg_type
               && !{ METAR => 1, SPECI => 1, TAF => 1 }->{$default_msg_type});

    s/^ //;
    s/[^ -~]/?/g; # replace non-ASCII characters

    $msg_head5 = substr $_, 0, 5;
    $default_msg_type = /^(?:METAR )?LWIS /      ? 'METAR'
                      : /^(METAR|SPECI|TAF) /    ? $1
                      : /^AMDAR /                ? 'AMDAR'
                      : $msg_head5 eq 'ZZYY '    ? 'BUOY'
                      :    $msg_head5 eq 'AAXX '
                        || $msg_head5 eq 'BBXX '
                        || $msg_head5 eq 'OOXX ' ? 'SYNOP'
                      : m{^0\d{5}[/:-]}          ? 'BUFR'
                      :                            $default_msg_type # no change
                      ;
    return 0
        unless defined $default_msg_type;

    # further cleanup (except for BUFR: values can be length encoded)
    if ($default_msg_type ne 'BUFR') {
        s/ \K +//g;
        s/ $//;
    }

=pod

Then the correct function to parse the message is called.

=cut

    _cySet;
    %report = $default_msg_type eq 'BUFR'  ? _parseBufr
            : $default_msg_type eq 'AMDAR' ? _parseAmdar
            : $default_msg_type eq 'BUOY'  ? _parseBuoy
            : $default_msg_type eq 'SYNOP' ? _parseSynop
            : /^(?:METAR |SPECI )?[CKP][A-Z\d]{3} (?:S[AP]|RS)(?: COR)? $re_hour$re_min /o
                                           ? _parseSao
            :                                _parseMetarTaf $default_msg_type;

=pod

After parsing, the callback function is invoked for each data item.
If L<start_xml()|/start_xml(\%opts)> was invoked initially, an internal callback
function is used which writes the data as XML.

See L<finish()|/finish()> for how to complete the processing of reports.

The function will return one of the following values:

=over

=item C<0>

An error occurred. Possible error causes:

=over

=item *

the function was called in improper sequence, or

=item *

one or both arguments are invalid, or

=item *

the callback function provided with L<start_cb()|/start_cb(\&cb)> returned an
error while processing the data, or

=item *

the internal callback function to write the data as XML encountered an error
while trying to write to the output file.

=back

=item C<1>

No error occurred.

=back

=cut

    return _print_report \%report;
}

########################################################################
# process_bufr
########################################################################
sub process_bufr {

=head2 process_bufr(\@data,\@desc)

This function processes a decoded BUFR message. It then writes the
data as XML or invokes a callback function for each data item.

The following arguments are expected:

=over

=item data

an array of values for a message subset

=item desc

an array of descriptors for the same message subset

=back

=cut

    my ($data, $desc, %report);

    ($data, $desc) = @_;

    return 0
        unless ref $data eq 'ARRAY' && ref $desc eq 'ARRAY';

    %report = metaf2xml::bufr::_bufr2report($data, $desc);
    _complete_bufr \%report;

=pod

After processing, the callback function is invoked for each data item.
If L<start_xml()|/start_xml(\%opts)> was invoked initially, an internal callback
function is used which writes the data as XML.

See L<finish()|/finish()> for how to complete the processing of reports.

The function will return one of the following values:

=over

=item C<0>

An error occurred. Possible error causes:

=over

=item *

the function was called in improper sequence, or

=item *

one or both arguments are invalid, or

=item *

the callback function provided with L<start_cb()|/start_cb(\&cb)> returned an
error while processing the data, or

=item *

the internal callback function to write the data as XML encountered an error
while trying to write to the output file.

=back

=item C<1>

No error occurred.

=back

=cut

    return _print_report \%report;
}

########################################################################
# finish
########################################################################

=head2 finish()

This function completes the processing of reports by closing the nodes "reports"
and "data".
It must be invoked if
L<start_xml()|/start_xml(\%opts)> was invoked initially, or if
L<start_xml()|/start_xml(\%opts)> or L<start_cb()|/start_cb(\&cb)> are
to be invoked later (again). Otherwise it needs to be called only if the
callback function requires it.

No arguments are expected.

The function will return one of the following values:

=over

=item C<0>

An error occurred. Possible error causes:

=over

=item *

the function was called in improper sequence, or

=item *

the callback function provided with L<start_cb()|/start_cb(\&cb)> returned an
error while processing the closure of the nodes "reports" or "data", or

=item *

the internal callback function to write the data as XML encountered an error
while trying to write to the output file or close it.

=back

=item C<1>

No error occurred.

=back

=cut

sub finish {
    my $rc;

    # check state
    return 0 if $#node_path == -1;

    if ($#node_path != 2) {
        @node_path = ('', 'data');     # there was an error, overwrite path
        $rc = 0;
    } else {
        $rc = _end_node;               # close node "reports"
    }
    $rc = 0 unless _end_node;   # close node "data"
    $#node_path = -1;           # set state

    return $rc;
}

=head1 DEPENDENCIES

The Perl module C<metaf2xml::bufr> is required.

=head1 SEE ALSO

L<metaf2xml::src2raw|metaf2xml::src2raw>(3pm),
L<metaf2xml::bufr|metaf2xml::bufr>(3pm),
L<metaf2xml|metaf2xml>(1), L<metafsrc2raw|metafsrc2raw>(1),
L<http://metaf2xml.sourceforge.net/>

=head1 COPYRIGHT and LICENSE

copyright (c) 2006-2016 metaf2xml @ L<http://metaf2xml.sourceforge.net/>

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
