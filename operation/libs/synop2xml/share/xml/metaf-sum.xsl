<?xml version="1.0" encoding="UTF-8"?>
<!--
########################################################################
# metaf-sum.xsl 2.1
#   templates to transform XML to HTML or text for mode=summary
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
-->

<!DOCTYPE xsl:stylesheet [
<!ENTITY xslns 'http://www.w3.org/1999/XSL/Transform'>
<!ENTITY tab1  '<text xmlns="&xslns;">&#9;</text>'>
<!ENTITY tab2  '<text xmlns="&xslns;">&#9;&#9;</text>'>
<!ENTITY tab3  '<text xmlns="&xslns;">&#9;&#9;&#9;</text>'>
<!ENTITY tab4  '<text xmlns="&xslns;">&#9;&#9;&#9;&#9;</text>'>
<!ENTITY nl    '<text xmlns="&xslns;">&#10;</text>'>
]>

<xsl:stylesheet
    xmlns:xsl = "&xslns;"
    xmlns:m = "http://metaf2xml.sourceforge.net/2.1"
    xmlns:t = "http://metaf2xml.sourceforge.net/2.1"
    xmlns:d = "urn:data-section"
    exclude-result-prefixes = "m"
    version = "1.0">

 <!-- allow attribute "method" to be set by caller -->
 <xsl:output
    encoding = "UTF-8"
    indent = "yes"
 />

 <!-- this must be passed with "- -stringparam name value" from xsltproc -->
 <xsl:param name="lang"/>
 <xsl:param name="no_msg"/>
 <xsl:param name="no_links"/>

 <xsl:variable name="add_info">
  <xsl:if test="$no_links != 1 and $method = 'html'">1</xsl:if>
 </xsl:variable>

 <xsl:variable name="lang_used">
  <xsl:variable name="lang_opt" select="/data/options/@lang|/xsl:stylesheet/d:data/d:options/@lang"/>
  <xsl:variable name="all_lang" select="' en es ru '"/>
  <xsl:choose>
   <xsl:when test="not(contains($lang, ' ')) and contains($all_lang, concat(' ', $lang, ' '))">
    <xsl:value-of select="$lang"/>
   </xsl:when>
   <xsl:when test="$lang = '' and not(contains($lang_opt, ' ')) and contains($all_lang, concat(' ', $lang_opt, ' '))">
    <xsl:value-of select="$lang_opt"/>
   </xsl:when>
   <xsl:otherwise>de</xsl:otherwise>
  </xsl:choose>
 </xsl:variable>

 <xsl:variable name="lang_xml" select="'metaf-lang.xml'"/>
 <xsl:variable name="lang_used_xml" select="concat('metaf-lang-', $lang_used, '.xml')"/>
 <xsl:variable name="transsumroot" select="document($lang_xml)/transsum"/>
 <xsl:variable name="transsum" select="$transsumroot/t:weatherSum"/>
 <xsl:variable name="transroot" select="document($lang_used_xml)/trans"/>
 <xsl:variable name="trans" select="$transroot/t:lang"/>

 <xsl:variable name="NM2KM" select="1.852"/>
 <xsl:variable name="FT2M" select="0.3048"/>
 <xsl:variable name="SM2M" select="1609.3412196"/> <!-- statute mile! -->
 <xsl:variable name="METER_PER_SEC2KT" select="3.6 div $NM2KM"/>
 <xsl:variable name="INHG2HPA" select="33.86388640341"/>

 <xsl:template match="comment()">
  <xsl:if test="$method = 'html'">
   <xsl:comment><xsl:value-of select="."/></xsl:comment>
   &nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="data|d:data">
  <xsl:choose>
   <xsl:when test="boolean(m:reports)">
    <div class="output">
    <xsl:apply-templates select="m:reports"/>
    </div>
   </xsl:when>
   <xsl:otherwise>
    <p><b>
    <xsl:value-of select="concat('ERROR: versions differ: XML: ', namespace-uri(*[last()]), ', metaf-sum.xsl: http://metaf2xml.sourceforge.net/2.1')"/>
    </b></p>&nl;
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:reports">
  <xsl:choose>
   <xsl:when test="not(boolean($transroot))">
    <p><b>
    <xsl:value-of select="concat('ERROR in ', $lang_used_xml, ': invalid document structure')"/>
    </b></p>&nl;
   </xsl:when>
   <xsl:when test="not(boolean($trans))">
    <p><b>
    <xsl:value-of select="concat('ERROR: versions differ: ', $lang_used_xml, ': ', namespace-uri($transroot/*[1]), ', metaf-sum.xsl: http://metaf2xml.sourceforge.net/2.1')"/>
    </b></p>&nl;
   </xsl:when>
   <xsl:when test="not(boolean($transsumroot))">
    <p><b>
    <xsl:value-of select="concat('ERROR in ', $lang_xml, ': invalid document structure')"/>
    </b></p>&nl;
   </xsl:when>
   <xsl:when test="not(boolean($transsum))">
    <p><b>
    <xsl:value-of select="concat('ERROR: versions differ: ', $lang_xml, ': ', namespace-uri($transsumroot/*[1]), ', metaf-sum.xsl: http://metaf2xml.sourceforge.net/2.1')"/>
    </b></p>&nl;
   </xsl:when>
   <xsl:otherwise>
    <xsl:if test="boolean(m:metar|m:taf|m:synop|m:buoy|m:amdar)">
     <p><b><xsl:value-of select="$trans/t:cgi[@o='disclaimer']"/></b></p>
     &nl;&nl;
     <xsl:if test="boolean(//*[@q = 'M2Xderived'])">
      <p><xsl:value-of select="$trans/t:cgi[@o='derived']"/></p>
      &nl;&nl;
     </xsl:if>
    </xsl:if>
    <xsl:if test="boolean(m:metar|m:taf)">
     <table border="1" cellpadding="3" frame="box">
     <xsl:apply-templates select="m:metar|m:taf"/>
     </table>
     &nl;
    </xsl:if>
    <xsl:if test="boolean(m:synop)">
     <xsl:if test="boolean(m:metar|m:taf)"><p /></xsl:if>
     <table border="1" cellpadding="3" frame="box">
     <xsl:apply-templates select="m:synop"/>
     </table>
     &nl;
    </xsl:if>
    <xsl:if test="boolean(m:buoy)">
     <xsl:if test="boolean(m:metar|m:taf|m:synop)"><p /></xsl:if>
     <table border="1" cellpadding="3" frame="box">
     <xsl:apply-templates select="m:buoy"/>
     </table>
     &nl;
    </xsl:if>
    <xsl:if test="boolean(m:amdar)">
     <xsl:if test="boolean(m:metar|m:taf|m:synop|m:buoy)"><p /></xsl:if>
     <table border="1" cellpadding="3" frame="box">
     <xsl:apply-templates select="m:amdar"/>
     </table>
     &nl;
    </xsl:if>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:if test="$method = 'html'">
   <xsl:comment> metaf-sum: 2.1 </xsl:comment>
   &nl;
  </xsl:if>
 </xsl:template>

 <xsl:template name="fmt_coord">
  <xsl:param name="pre"/>
  <xsl:param name="which"/> <!-- 0 or 1 -->
  <xsl:param name="len_sec"/> <!-- 0 or 2 -->
  <xsl:variable name="off_deg" select="1 + $which * (5 + $len_sec)"/>
  <xsl:variable name="len_deg" select="2 + $which"/>
  <xsl:variable name="compass" select="substring(info/@loc, $off_deg + $len_deg + 2 + $len_sec, 1)"/>
  <xsl:variable name="compassIdx">
   <xsl:choose>
    <xsl:when test="$compass = 'N'">1</xsl:when>
    <xsl:when test="$compass = 'E'">5</xsl:when>
    <xsl:when test="$compass = 'S'">9</xsl:when>
    <xsl:otherwise>13</xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <xsl:value-of select="concat($pre, format-number(substring(info/@loc, $off_deg, $len_deg), '#'), '° ', format-number(substring(info/@loc, $off_deg + $len_deg, 2), '#'))"/>
  <xsl:text>' </xsl:text>
  <xsl:if test="$len_sec = 2">
   <xsl:value-of select="concat(format-number(substring(info/@loc, $off_deg + $len_deg + 2, 2), '#'), '&quot; ')"/>
  </xsl:if>
  <xsl:value-of select="$trans/t:compassDirAbbr/t:arr[0 + $compassIdx]"/>
  <xsl:if test="$which = 1">
   <xsl:value-of select="concat(' ', format-number(substring(info/@loc, $off_deg + $len_deg + 3 + $len_sec, 4), '#'), ' m')"/>
  </xsl:if>
 </xsl:template>

 <xsl:template match="@ctry">
  <xsl:variable name="ctry" select="substring-before(., '-')"/>
  <xsl:choose>
   <xsl:when test="boolean($trans/t:country[@o=current()])">
    <xsl:value-of select="$trans/t:country[@o=current()]"/>
   </xsl:when>
   <xsl:when test="contains(., '-') and boolean($trans/t:country[@o=$ctry])">
    <xsl:value-of select="$trans/t:country[@o=$ctry]"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="."/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template name="stationInfo">
  <xsl:param name="station"/>
  <xsl:if test="($station != '' and string(m:obsStationName/@v) != $station) or boolean($station/@ctry)">
   <xsl:text> (</xsl:text>
   <xsl:if test="$station != '' and string(m:obsStationName/@v) != $station">
    <xsl:value-of select="$station"/>
    <xsl:if test="boolean($station/@ctry)">, </xsl:if>
   </xsl:if>
   <xsl:apply-templates select="$station/@ctry"/>
   <xsl:text>)</xsl:text>
  </xsl:if>
 </xsl:template>

 <xsl:template match="t:summaryHeader/t:c">
  <xsl:if test="not($no_msg != '') or position() != last()">
   <xsl:if test="position() != 1">&tab1;</xsl:if>
   <th>
    <xsl:for-each select="@*">
     <xsl:if test="name() != 'post'">
      <xsl:copy/>
     </xsl:if>
    </xsl:for-each>
    <xsl:value-of select="."/>
   </th>
   <xsl:if test="boolean(@post)"><xsl:value-of select="@post"/></xsl:if>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:metar|m:taf">
  <xsl:if test="position() mod 15 = 1">
   <tr>
   <xsl:apply-templates select="$trans/t:summaryHeader[@o='metar']/t:c"/>
   </tr>&nl;
  </xsl:if>
  <xsl:variable name="rows" select="count(m:trend[m:trendType/@v != 'NOSIG']) + 1"/>
  <tr>
   <xsl:if test="$add_info = 1">
    <xsl:attribute name="title">
     <xsl:apply-templates select="m:obsStationId">
      <xsl:with-param name="type" select="'ICAO'"/>
     </xsl:apply-templates>
    </xsl:attribute>
   </xsl:if>
   <td nowrap="1">
    <xsl:if test="$rows > 1">
     <xsl:attribute name="valign">top</xsl:attribute>
     <xsl:attribute name="rowspan">
      <xsl:value-of select="$rows"/>
     </xsl:attribute>
    </xsl:if>
    <xsl:choose>
     <xsl:when test="boolean(m:isSpeci)"><b>SPECI</b></xsl:when>
     <xsl:when test="name() = 'taf'">TAF</xsl:when>
     <xsl:otherwise>METAR</xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="m:reportModifier|m:fcstCancelled"/>
   </td>&tab1;
   <td nowrap="1">
    <xsl:if test="$rows > 1">
     <xsl:attribute name="valign">top</xsl:attribute>
     <xsl:attribute name="rowspan">
      <xsl:value-of select="$rows"/>
     </xsl:attribute>
    </xsl:if>
    <xsl:apply-templates select="m:obsStationId/m:id"/>
   </td>&tab1;
   <td nowrap="1"><xsl:apply-templates select="m:obsTime|m:issueTime"/></td>
   &tab1;
   <td nowrap="1">
   <xsl:apply-templates select="m:sfcWind/m:wind"/>
   <xsl:apply-templates select="m:sfcWind/m:wind/m:gustSpeed|m:remark/m:peakWind/m:wind/m:speed|m:remark/m:sfcWind/m:wind/m:gustSpeed"/>
   </td>&tab1;
   <xsl:choose>
    <xsl:when test="boolean(m:CAVOK)">
     <td colspan="3">CAVOK</td>&tab3;
    </xsl:when>
    <xsl:otherwise>
     <td nowrap="1" align="right">
     <xsl:apply-templates select="m:visPrev[boolean(m:distance)]|m:visMin[boolean(m:distance)]|m:visMax[boolean(m:distance)]"/>
     </td>&tab1;
     <td nowrap="1"><xsl:apply-templates select="m:weather"/></td>&tab1;
     <td nowrap="1">
     <xsl:apply-templates select="m:cloud[not(boolean(m:notAvailable|m:invalidFormat))]|m:visVert[boolean(m:distance)]"/>
     </td>&tab1;
    </xsl:otherwise>
   </xsl:choose>
   <td nowrap="1" align="right">
   <xsl:apply-templates select="m:temperature/m:air[boolean(m:temp)]"/>
   <xsl:if test="boolean(m:remark/m:temperature/m:air/m:temp)">
    <xsl:if test="boolean(m:temperature/m:air/m:temp)">
     <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:text>(</xsl:text>
    <xsl:apply-templates select="m:remark/m:temperature/m:air[boolean(m:temp)]"/>
    <xsl:text>)</xsl:text>
   </xsl:if>
   <xsl:apply-templates select="m:tempAt[boolean(m:temp)]|m:tempMaxAt[boolean(m:temp)]|m:tempMinAt[boolean(m:temp)]|m:remark/m:tempMax[boolean(m:temp)]|m:remark/m:tempMin[boolean(m:temp)]|m:remark/m:tempExtreme/m:tempExtremeMax[boolean(m:temp)]|m:remark/m:tempExtreme/m:tempExtremeMin[boolean(m:temp)]"/>
   </td>&tab1;
   <td nowrap="1" align="right">
   <xsl:if test="boolean(m:temperature/m:relHumid1)">
    <xsl:value-of select="concat(format-number(m:temperature/m:relHumid1/@v, '0'), ' %')"/>
    <xsl:if test="m:temperature/m:relHumid1/@q = 'M2Xderived'">*</xsl:if>
   </xsl:if>
   <xsl:if test="boolean(m:remark/m:temperature/m:relHumid1)">
    <xsl:if test="boolean(m:temperature/m:relHumid1)">
     <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:value-of select="concat('(', format-number(m:remark/m:temperature/m:relHumid1/@v, '0'), ' %')"/>
    <xsl:if test="m:remark/m:temperature/m:relHumid1/@q = 'M2Xderived'">*</xsl:if>
    <xsl:text>)</xsl:text>
   </xsl:if>
   </td>&tab1;
   <td nowrap="1" align="right">
   <xsl:choose>
    <xsl:when test="name() = 'metar'">
     <xsl:apply-templates select="m:QNH/m:pressure[@u = 'hPa' or not(boolean(../../m:QNH/m:pressure[@u = 'hPa']))]|m:QFE/m:pressure|m:remark/m:QNH/m:pressure|m:remark/m:SLP/m:pressure|m:remark/m:QFE/m:pressure[@u = 'hPa' or not(boolean(../m:pressure[@u = 'hPa']))]"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:apply-templates select="m:minQNH/m:pressure"/>
    </xsl:otherwise>
   </xsl:choose>
   <xsl:apply-templates select="m:remark/m:pressureChange/m:pressureChangeVal"/>
   </td>&tab1;
   <td nowrap="1">
    <xsl:if test="$rows > 1">
     <xsl:attribute name="rowspan">
      <xsl:value-of select="$rows"/>
     </xsl:attribute>
    </xsl:if>
    <xsl:variable name="warnings">
     <xsl:apply-templates select="m:warning[@warningType = 'notProcessed']|m:remark/m:notRecognised|descendant::m:invalidFormat"/>
    </xsl:variable>
    <xsl:value-of select="substring($warnings, 1, 40)"/>
    <xsl:if test="string-length($warnings) &gt; 40"> ...</xsl:if>
    <xsl:apply-templates select="m:ERROR">
     <xsl:with-param name="need_sep" select="$warnings != ''"/>
    </xsl:apply-templates>
   </td>
   <xsl:call-template name="msg">
    <xsl:with-param name="type" select="'metaf'"/>
    <xsl:with-param name="rows" select="$rows"/>
   </xsl:call-template>
  </tr>&nl;
  <xsl:apply-templates select="m:trend[m:trendType/@v != 'NOSIG']"/>
 </xsl:template>

 <xsl:template name="stationInfoFromDoc">
  <xsl:param name="doc"/>
  <xsl:param name="type"/>
  <xsl:choose>
   <xsl:when test="$type = 'ICAO'">
    <xsl:call-template name="stationInfo">
     <xsl:with-param name="station" select="$doc/station[@icao=current()/m:id/@v]"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:when test="$type = 'AAXX'">
    <xsl:call-template name="stationInfo">
     <xsl:with-param name="station" select="$doc/station[@wmo=current()/m:id/@v]"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:when test="$type = 'BBXX'">
    <xsl:call-template name="stationInfo">
     <xsl:with-param name="station" select="$doc/station[@ship=current()/m:id/@v]"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:when test="$type = 'OOXX'">
    <xsl:call-template name="stationInfo">
     <xsl:with-param name="station" select="$doc/station[@mobil=current()/m:id/@v]"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:when test="$type = 'ZZYY'">
    <xsl:call-template name="stationInfo">
     <xsl:with-param name="station" select="$doc/station[@buoy=current()/m:id/@v]"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:when test="$type = 'AMDAR'">
    <xsl:call-template name="stationInfo">
     <xsl:with-param name="station" select="$doc/station[@ac=current()/m:id/@v]"/>
    </xsl:call-template>
   </xsl:when>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:obsStationId|m:callSign|m:buoyId|m:aircraftId">
  <xsl:param name="type"/>
  <xsl:apply-templates select="m:id|m:natId"/>
  <xsl:if test="boolean(m:obsStationName/@v)">
   <xsl:if test="boolean(m:id|m:natId)">
    <xsl:text> </xsl:text>
   </xsl:if>
   <xsl:value-of select="concat('&quot;', m:obsStationName/@v, '&quot;')"/>
  </xsl:if>
  <xsl:choose>
   <xsl:when test="not(boolean(m:id))"/>
   <xsl:when test="boolean(/data/stations)">
    <xsl:call-template name="stationInfoFromDoc">
     <xsl:with-param name="type" select="$type"/>
     <xsl:with-param name="doc" select="/data/stations"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:when test="boolean(info) and info = ''"/>
   <xsl:when test="boolean(info)">
    <xsl:value-of select="concat(' (', info)"/>
    <xsl:if test="boolean(info/@ctry)">, </xsl:if>
    <xsl:apply-templates select="info/@ctry"/>
    <xsl:if test="boolean(info/@loc)">
     <xsl:call-template name="fmt_coord">
      <xsl:with-param name="pre" select="', '"/>
      <xsl:with-param name="which" select="0"/>
      <xsl:with-param name="len_sec" select="(string-length(info/@loc) - 15) div 2"/>
     </xsl:call-template>
     <xsl:call-template name="fmt_coord">
      <xsl:with-param name="pre" select="' '"/>
      <xsl:with-param name="which" select="1"/>
      <xsl:with-param name="len_sec" select="(string-length(info/@loc) - 15) div 2"/>
     </xsl:call-template>
    </xsl:if>
    <xsl:text>)</xsl:text>
   </xsl:when>
   <xsl:otherwise>
    <xsl:call-template name="stationInfoFromDoc">
     <xsl:with-param name="type" select="$type"/>
     <xsl:with-param name="doc" select="document('stations.xml')/data/stations"/>
    </xsl:call-template>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:if test="boolean(m:region)">
   <xsl:value-of select="concat(' (', $trans/t:wmoRegion[@o=current()/m:region/@v], ')')"/>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:obsTime|m:issueTime">
  <xsl:apply-templates select="m:timeAt"/>
  <xsl:if test="boolean(../m:exactObsTime/m:timeAt)">
   <xsl:text> (</xsl:text>
   <xsl:variable name="offset" select="../m:exactObsTime/m:timeAt/m:hour/@v - m:timeAt/m:hour/@v"/>
   <xsl:choose>
    <xsl:when test="$offset &lt; -12 or ($offset >= 0 and $offset * 60 + ../m:exactObsTime/m:timeAt/m:minute/@v &lt; 12 * 60)">
     <xsl:value-of select="concat('+', format-number(($offset + 24) mod 24, '00:'), format-number(../m:exactObsTime/m:timeAt/m:minute/@v, '00'))"/>
    </xsl:when>
    <xsl:when test="../m:exactObsTime/m:timeAt/m:minute/@v = 0">
     <xsl:value-of select="concat(format-number(($offset - 24) mod 24, '00:'), '00')"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:choose>
      <xsl:when test="$offset = -1 or $offset = 23">-00:</xsl:when>
      <xsl:otherwise>
       <xsl:value-of select="format-number(($offset - 23) mod 24, '00:')"/>
      </xsl:otherwise>
     </xsl:choose>
     <xsl:value-of select="format-number(60 - ../m:exactObsTime/m:timeAt/m:minute/@v, '00')"/>
    </xsl:otherwise>
   </xsl:choose>
   <xsl:text>)</xsl:text>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:visPrev|m:visibility">
  <xsl:call-template name="visibility">
   <xsl:with-param name="rnd_m" select="50"/>
   <xsl:with-param name="unitThreshold" select="1000"/>
  </xsl:call-template>
 </xsl:template>

 <xsl:template match="m:visVert">
  <xsl:if test="position() != 1"><xsl:text> </xsl:text></xsl:if>
  <xsl:text>VV</xsl:text>
  <xsl:choose>
   <xsl:when test="m:distance/@u = 'FT'">
    <xsl:value-of select="format-number(m:distance/@v div 100, '000')"/>
   </xsl:when>
   <xsl:when test="m:distance/@q = 'isLess' and m:distance/@v = 30">000</xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="format-number(m:distance/@v div 30, '000')"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template name="visibility">
  <xsl:param name="rnd_m"/>
  <xsl:param name="unitThreshold"/>
  <xsl:choose>
   <xsl:when test="m:distance/@q = 'isLess'">&lt;</xsl:when>
   <xsl:when test="m:distance/@q = 'isGreater'">&gt;</xsl:when>
   <xsl:when test="m:distance/@q = 'isEqualGreater'">&gt;=</xsl:when>
   <xsl:otherwise></xsl:otherwise>
  </xsl:choose>
  <xsl:variable name="amountMeter">
   <xsl:choose>
    <xsl:when test="m:distance/@u = 'M'">
     <xsl:value-of select="m:distance/@v"/>
    </xsl:when>
    <xsl:when test="m:distance/@u = 'KM'">
     <xsl:value-of select="m:distance/@v * 1000"/>
    </xsl:when>
    <xsl:when test="m:distance/@u = 'SM'">
     <xsl:value-of select="m:distance/@v * $SM2M"/>
    </xsl:when>
    <xsl:when test="m:distance/@u = 'FT'">
     <xsl:value-of select="m:distance/@v * $FT2M"/>
    </xsl:when>
     <xsl:when test="m:distance/@u = 'NM'">
      <xsl:value-of select="m:distance/@v * $NM2KM * 1000"/>
     </xsl:when>
   </xsl:choose>
  </xsl:variable>
  <xsl:choose>
   <xsl:when test="$amountMeter >= $unitThreshold">
    <xsl:value-of select="concat(format-number($amountMeter div 1000, '0.#'), $trans/t:units[@o='KM'])"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="concat(format-number($amountMeter div $rnd_m, '#0') * $rnd_m, $trans/t:units[@o='M'])"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:if test="boolean(m:compassDir)">
   <xsl:if test="m:compassDir/@q = 'isGrid'">GRID</xsl:if>
   <xsl:value-of select="concat(' ', m:compassDir/@v)"/>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:wind">
  <xsl:choose>
   <xsl:when test="boolean(m:invalidFormat|m:notAvailable)"/>
   <xsl:when test="boolean(m:isCalm)">
    <xsl:value-of select="$trans/t:t[@o='calmWind']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:variable name="dir">
     <xsl:if test="boolean(m:dirVariable)">VRB</xsl:if>
     <xsl:if test="boolean(m:dir)">
      <xsl:if test="m:dir/@q = 'isGrid'">GRID</xsl:if>
      <xsl:value-of select="$trans/t:compassDirAbbr/t:arr[1+format-number(current()/m:dir/@v div 45 * 2, '0')]"/>
      <!--select="concat(m:dir/@v, '°')"/-->
      <xsl:if test="boolean(m:windVarLeft)">
       <xsl:value-of select="concat(' (', $trans/t:compassDirAbbr/t:arr[1+format-number(current()/m:windVarLeft/@v div 45 * 2, '0')], '-', $trans/t:compassDirAbbr/t:arr[1+format-number(current()/m:windVarRight/@v div 45 * 2, '0')], ')')"/>
      </xsl:if>
     </xsl:if>
    </xsl:variable>
    <xsl:choose>
     <xsl:when test="m:dir/@v = '0' and m:speed/@v = '0'">
      <xsl:value-of select="$trans/t:t[@o='calmWind']"/>
     </xsl:when>
     <xsl:when test="boolean(m:speedNotAvailable)">
      <xsl:value-of select="$dir"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="$dir"/>
      <xsl:if test="$dir != ''"><xsl:text> </xsl:text></xsl:if>
      <xsl:call-template name="speed2kt">
       <xsl:with-param name="speed" select="m:speed"/>
      </xsl:call-template>
     </xsl:otherwise>
    </xsl:choose>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:wind/m:gustSpeed|m:wind/m:speed">
  <xsl:if test="position() = 1"> (</xsl:if>
  <xsl:if test="position() != 1">, </xsl:if>
  <xsl:if test="name() = 'speed' and boolean(../m:dir)">
   <xsl:value-of select="concat($trans/t:compassDirAbbr/t:arr[1+format-number(current()/../m:dir/@v div 45 * 2, '0')], ' ')"/>
  </xsl:if>
  <xsl:choose>
   <xsl:when test="name() = 'gustSpeed'">
    <xsl:text>G</xsl:text>
    <xsl:call-template name="speed2kt">
     <xsl:with-param name="speed" select="."/>
    </xsl:call-template>
   </xsl:when>
   <xsl:when test="name(../..) = 'highestGust'">
    <xsl:text>G</xsl:text>
    <xsl:call-template name="speed2kt">
     <xsl:with-param name="speed" select="."/>
    </xsl:call-template>
    <xsl:apply-templates select="../../m:measurePeriod|../../m:timeBeforeObs"/>
   </xsl:when>
   <xsl:when test="name(../..) = 'highestMeanSpeed'">
    <xsl:text>^</xsl:text>
    <xsl:call-template name="speed2kt">
     <xsl:with-param name="speed" select="."/>
    </xsl:call-template>
    <xsl:apply-templates select="../../m:measurePeriod|../../m:timePeriod|../../m:timeBeforeObs"/>
    <xsl:apply-templates select="../../m:timeAt">
     <xsl:with-param name="need_type" select="1"/>
    </xsl:apply-templates>
   </xsl:when>
   <xsl:when test="name(../..) = 'peakWind'">
    <xsl:text>G</xsl:text>
    <xsl:call-template name="speed2kt">
     <xsl:with-param name="speed" select="."/>
    </xsl:call-template>
    <xsl:apply-templates select="../../m:timeAt">
     <xsl:with-param name="need_type" select="1"/>
    </xsl:apply-templates>
   </xsl:when>
  </xsl:choose>
  <xsl:if test="position() = last()">)</xsl:if>
 </xsl:template>

 <xsl:template match="m:timeBeforeObs">
  <xsl:if test="position() = 1">/</xsl:if>
  <xsl:if test="position() != 1">,</xsl:if>
  <xsl:if test="boolean(m:notAvailable)">?</xsl:if>
  <xsl:if test="@occurred = 'Begin'">*</xsl:if>
  <xsl:if test="@occurred = 'End'">+</xsl:if>
  <xsl:if test="@occurred = 'At'">@</xsl:if>
  <xsl:if test="m:hours/@q = 'isGreater'">&gt;</xsl:if>
  <xsl:if test="m:hours/@q = 'isLess'">&lt;</xsl:if>
  <xsl:value-of select="m:minutes/@v|m:hoursFrom/@v|m:hours/@v"/>
  <xsl:if test="boolean(m:hoursTill)">
   <xsl:value-of select="concat('-', m:hoursTill/@v)"/>
  </xsl:if>
  <xsl:choose>
   <xsl:when test="boolean(m:minutes)">
    <xsl:value-of select="$trans/t:units[@o='MIN-sum']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:units[@o='H-sum']"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:timePeriod">
  <xsl:value-of select="concat('/', @v)"/>
 </xsl:template>

 <xsl:template match="m:measurePeriod">
  <xsl:value-of select="concat('/', @v, 'm')"/>
 </xsl:template>

 <xsl:template name="speed2kt">
  <xsl:param name="speed"/>
  <xsl:if test="$speed/@q = 'isGreater'">&gt;</xsl:if>
  <xsl:variable name="speedkt">
   <xsl:choose>
    <xsl:when test="$speed/@u = 'KT'">
     <xsl:value-of select="$speed/@v"/>
    </xsl:when>
    <xsl:when test="$speed/@u = 'KMH'">
     <xsl:value-of select="$speed/@v div $NM2KM"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="$speed/@v * $METER_PER_SEC2KT"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <xsl:value-of select="format-number($speedkt, '0.#')"/>
 </xsl:template>

 <xsl:template match="m:weather">
  <xsl:if test="position() != 1"><xsl:text> </xsl:text></xsl:if>
  <xsl:apply-templates select="m:phenomDescr"/>
  <xsl:if test="boolean(m:inVicinity)">VC</xsl:if>
  <xsl:if test="boolean(m:notAvailable|m:invalidFormat)">?</xsl:if>
  <xsl:if test="boolean(m:NSW)">NSW</xsl:if>
  <xsl:if test="boolean(m:tornado)">TORNADO</xsl:if>
  <xsl:apply-templates select="m:descriptor"/>
  <xsl:apply-templates select="m:phenomSpec"/>
 </xsl:template>

 <xsl:template match="m:phenomDescr">
  <xsl:if test="@v = 'isHeavy'">+</xsl:if>
  <xsl:if test="@v = 'isLight'">-</xsl:if>
 </xsl:template>

 <xsl:template match="m:natId">
  <xsl:if test="position() != 1">/</xsl:if>
  <xsl:value-of select="concat(m:natStationId/@v, '-', m:countryId/@v)"/>
 </xsl:template>

 <xsl:template match="m:descriptor|m:phenomSpec|m:id">
  <xsl:value-of select="@v"/>
 </xsl:template>

 <xsl:template match="m:cloud">
  <xsl:if test="position() != 1"><xsl:text> </xsl:text></xsl:if>
  <xsl:choose>
   <xsl:when test="boolean(m:noClouds)">
    <xsl:value-of select="m:noClouds/@v"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:variable name="cloud">
     <xsl:value-of select="m:cloudCover/@v"/>
     <xsl:choose>
      <xsl:when test="boolean(m:cloudBaseNotAvailable)">///</xsl:when>
      <xsl:when test="boolean(m:cloudBase)">
       <xsl:call-template name="cloudBaseVal"/>
      </xsl:when>
     </xsl:choose>
     <xsl:apply-templates select="m:cloudType"/>
     <xsl:if test="boolean(m:cloudTypeNotAvailable)">///</xsl:if>
    </xsl:variable>
    <xsl:choose>
     <xsl:when test="boolean(m:isCeiling)">
      <b><xsl:value-of select="$cloud"/></b>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="$cloud"/>
     </xsl:otherwise>
    </xsl:choose>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template name="cloudBaseVal">
  <xsl:if test="m:cloudBase/@q = 'isLess' and not(m:cloudBase/@u = 'M' and m:cloudBase/@v = 30)">
   <xsl:text>&lt;</xsl:text>
  </xsl:if>
  <xsl:if test="m:cloudBase/@q = 'isGreater'">
   <xsl:text>&gt;</xsl:text>
  </xsl:if>
  <xsl:if test="m:cloudBase/@q = 'isEqualGreater'">
   <xsl:text>&gt;=</xsl:text>
  </xsl:if>
  <xsl:choose>
   <xsl:when test="m:cloudBase/@u = 'FT'">
    <xsl:value-of select="format-number(m:cloudBase/@v div 100, '000')"/>
   </xsl:when>
   <xsl:when test="m:cloudBase/@q = 'isLess' and m:cloudBase/@v = 30">000</xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="format-number(m:cloudBase/@v div 30, '000')"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:air">
  <xsl:call-template name="printTemp">
   <xsl:with-param name="temp" select="."/>
  </xsl:call-template>
 </xsl:template>

 <xsl:template match="m:ERROR">
  <xsl:param name="need_sep"/>
  <xsl:if test="$need_sep"><xsl:text> </xsl:text></xsl:if>
  <xsl:choose>
   <xsl:when test="substring-after(@s, '@> ') != ''">
    <xsl:value-of select="substring-after(@s, '@> ')"/>
   </xsl:when>
   <xsl:otherwise>...</xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:notRecognised|m:obsStationType|m:warning">
  <xsl:if test="position() > 1"><xsl:text> </xsl:text></xsl:if>
  <xsl:value-of select="@s"/>
 </xsl:template>

 <xsl:template match="m:invalidFormat">
  <xsl:if test="position() > 1"><xsl:text> </xsl:text></xsl:if>
  <xsl:variable name="s">
   <xsl:choose>
    <xsl:when test="boolean(../@s)"><xsl:value-of select="../@s"/></xsl:when>
    <xsl:when test="boolean(../../@s)"><xsl:value-of select="../../@s"/></xsl:when>
   </xsl:choose>
  </xsl:variable>
  <xsl:value-of select="@v"/>
  <xsl:if test="@v != $s"><xsl:value-of select="concat('(', $s, ')')"/></xsl:if>
 </xsl:template>

 <xsl:template name="printTemp">
  <xsl:param name="temp"/>
  <xsl:choose>
   <xsl:when test="$temp/m:temp/@u = 'C'">
    <xsl:value-of select="$temp/m:temp/@v"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="format-number(($temp/m:temp/@v - 32) div 1.8, '0.#')"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:pressure">
  <xsl:if test="position() != 1"><xsl:text> </xsl:text></xsl:if>
  <xsl:choose>
   <xsl:when test="name(..) = 'stationPressure'">SP</xsl:when>
   <xsl:when test="name(..) = 'minQNH'">vQNH</xsl:when>
   <xsl:otherwise><xsl:value-of select="name(..)"/></xsl:otherwise>
  </xsl:choose>
  <xsl:choose>
   <xsl:when test="@u = 'hPa'">
    <xsl:value-of select="@v"/>
   </xsl:when>
   <xsl:when test="@u = 'mmHg'">
    <xsl:value-of select="format-number(@v div ($FT2M div 12 * 1000) * $INHG2HPA, '0')"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="format-number(@v * $INHG2HPA, '0')"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:visMin|m:visMax">
  <xsl:if test="position() != 1">, </xsl:if>
  <xsl:if test="name() = 'visMin'">v</xsl:if>
  <xsl:if test="name() = 'visMax'">^</xsl:if>
  <xsl:call-template name="visibility">
   <xsl:with-param name="rnd_m" select="10"/>
   <xsl:with-param name="unitThreshold" select="1000"/>
  </xsl:call-template>
 </xsl:template>

 <xsl:template match="m:trend">
  <tr>
   <xsl:if test="$add_info = 1">
    <xsl:attribute name="title">
     <xsl:apply-templates select="../m:obsStationId">
      <xsl:with-param name="type" select="'ICAO'"/>
     </xsl:apply-templates>
    </xsl:attribute>
   </xsl:if>
   &tab2;
   <td nowrap="1">
   <xsl:if test="boolean(m:probability)">
    <xsl:value-of select="concat('PROB', m:probability/@v)"/>
    <xsl:if test="m:trendType/@v != 'FM' or boolean(m:timeAt|m:timeFrom|m:timeTill)"><xsl:text> </xsl:text></xsl:if>
   </xsl:if>
   <xsl:if test="m:trendType/@v != 'FM'">
    <xsl:value-of select="m:trendType/@v"/>
    <xsl:if test="boolean(m:timeAt|m:timeFrom|m:timeTill)"><xsl:text> </xsl:text></xsl:if>
   </xsl:if>
   <xsl:apply-templates select="m:timeAt|m:timeFrom|m:timeTill">
    <xsl:with-param name="need_type" select="1"/>
   </xsl:apply-templates>
   </td>&tab1;
   <td nowrap="1">
   <xsl:apply-templates select="m:sfcWind/m:wind"/>
   <xsl:apply-templates select="m:sfcWind/m:wind/m:gustSpeed"/>
   </td>&tab1;
   <xsl:choose>
    <xsl:when test="boolean(m:CAVOK)">
     <td colspan="3">CAVOK</td>&tab3;
    </xsl:when>
    <xsl:otherwise>
     <td nowrap="1" align="right">
     <xsl:apply-templates select="m:visPrev[boolean(m:distance)]|m:visMin[boolean(m:distance)]|m:visMax[boolean(m:distance)]"/>
     </td>&tab1;
     <td nowrap="1"><xsl:apply-templates select="m:weather"/></td>&tab1;
     <td nowrap="1">
     <xsl:apply-templates select="m:cloud[not(boolean(m:notAvailable|m:invalidFormat))]|m:visVert[boolean(m:distance)]"/>
     </td>&tab1;
    </xsl:otherwise>
   </xsl:choose>
   <xsl:choose>
    <xsl:when test="name(..) = 'metar' or not(boolean(m:minQNH/m:pressure))">
     <td colspan="3"/>
    </xsl:when>
    <xsl:otherwise>
     <td colspan="2"/>&tab2;
     <td nowrap="1" align="right">
     <xsl:apply-templates select="m:minQNH/m:pressure"/>
     </td>
    </xsl:otherwise>
   </xsl:choose>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:timeAt|m:timeFrom|m:timeTill">
  <xsl:param name="need_type"/>
  <xsl:if test="position() = 2"><xsl:text> </xsl:text></xsl:if>
  <xsl:if test="$need_type">
   <xsl:choose>
    <xsl:when test="name() = 'timeAt'">@</xsl:when>
    <xsl:when test="name() = 'timeFrom'">FM </xsl:when>
    <xsl:otherwise>TL </xsl:otherwise>
   </xsl:choose>
  </xsl:if>
  <xsl:if test="boolean(m:day)">
   <xsl:value-of select="concat(m:day/@v + 0, '.')"/>
   <xsl:if test="boolean(m:month)">
    <xsl:value-of select="concat(m:month/@v + 0, '.')"/>
    <xsl:if test="boolean(m:yearUnitsDigit)">
     <xsl:text>xxx</xsl:text>
    </xsl:if>
    <xsl:value-of select="m:yearUnitsDigit/@v|m:year/@v"/>
   </xsl:if>
   <xsl:text>, </xsl:text>
  </xsl:if>
  <xsl:value-of select="concat(m:hour/@v, ':')"/>
  <xsl:choose>
   <xsl:when test="boolean(m:minute)">
    <xsl:value-of select="m:minute/@v"/>
   </xsl:when>
   <xsl:otherwise>00</xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template name="replace">
  <xsl:param name="in"/>
  <xsl:param name="out"/>
  <xsl:param name="s"/>
  <xsl:choose>
   <xsl:when test="contains($s, $in)">
    <xsl:value-of select="concat(substring-before($s, $in), $out)"/>
    <xsl:variable name="after" select="substring-after($s, $in)"/>
    <xsl:call-template name="replace">
     <xsl:with-param name="s" select="$after"/>
     <xsl:with-param name="in" select="$in"/>
     <xsl:with-param name="out" select="$out"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$s"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template name="msg">
  <xsl:param name="type"/>
  <xsl:param name="rows"/>
  <xsl:if test="not($no_msg != '')">
   &tab1;
   <td nowrap="1" class="msg">
    <xsl:if test="$rows > 1">
     <xsl:attribute name="rowspan">
      <xsl:value-of select="$rows"/>
     </xsl:attribute>
    </xsl:if>
    <xsl:choose>
     <xsl:when test="$add_info = 1">
      <a>
       <xsl:attribute name="href">
        <xsl:value-of select="concat('metaf.pl?msg_', $type, '=')"/>
        <xsl:call-template name="replace">
         <xsl:with-param name="in" select="'&amp;'"/>
         <xsl:with-param name="out" select="'%26'"/>
         <xsl:with-param name="s">
          <xsl:call-template name="replace">
           <xsl:with-param name="in" select="'+'"/>
           <xsl:with-param name="out" select="'%2B'"/>
           <xsl:with-param name="s">
            <xsl:call-template name="replace">
             <xsl:with-param name="in" select="'#'"/>
             <xsl:with-param name="out" select="'%23'"/>
             <xsl:with-param name="s">
              <xsl:call-template name="replace">
               <xsl:with-param name="in" select="';'"/>
               <xsl:with-param name="out" select="'%3B'"/>
               <xsl:with-param name="s">
                <xsl:call-template name="replace">
                 <xsl:with-param name="in" select="'%'"/>
                 <xsl:with-param name="out" select="'%25'"/>
                 <xsl:with-param name="s" select="@s"/>
                </xsl:call-template>
               </xsl:with-param>
              </xsl:call-template>
             </xsl:with-param>
            </xsl:call-template>
           </xsl:with-param>
          </xsl:call-template>
         </xsl:with-param>
        </xsl:call-template>
        <xsl:value-of select="concat(
        '&amp;lang=', /data/options/@lang,
            /xsl:stylesheet/d:data/d:options/@lang,
        '&amp;format=', /data/options/@format,
            /xsl:stylesheet/d:data/d:options/@format,
        '&amp;src_metaf=', /data/options/@src_metaf,
            /xsl:stylesheet/d:data/d:options/@src_metaf,
        '&amp;src_synop=', /data/options/@src_synop,
            /xsl:stylesheet/d:data/d:options/@src_synop,
        '&amp;src_buoy=', /data/options/@src_buoy,
            /xsl:stylesheet/d:data/d:options/@src_buoy,
        '&amp;src_amdar=', /data/options/@src_amdar,
            /xsl:stylesheet/d:data/d:options/@src_amdar,
        '&amp;hours=', /data/options/@hours,
            /xsl:stylesheet/d:data/d:options/@hours)"/>
        <xsl:if test="name() = 'taf'">
         <xsl:value-of select="'&amp;type_metaf=taf'"/>
        </xsl:if>
       </xsl:attribute>
       <xsl:value-of select="@s"/>
      </a>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="@s"/>
     </xsl:otherwise>
    </xsl:choose>
   </td>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:cloudType">
  <xsl:param name="post"/>
  <xsl:value-of select="concat(@v, $post)"/>
 </xsl:template>

 <xsl:template match="m:cloudTypeLow">
  <xsl:param name="post"/>
  <xsl:value-of select="concat($transsum/t:cloud/t:arr[current()/@v + 21], $post)"/>
 </xsl:template>

 <xsl:template match="m:cloudTypeMiddle">
  <xsl:param name="post"/>
  <xsl:value-of select="concat($transsum/t:cloud/t:arr[current()/@v + 11], $post)"/>
 </xsl:template>

 <xsl:template match="m:cloudTypeHigh">
  <xsl:param name="post"/>
  <xsl:value-of select="concat($transsum/t:cloud/t:arr[current()/@v + 1], $post)"/>
 </xsl:template>

 <xsl:template name="calmSea">
  <xsl:param name="root"/>
  <xsl:variable name="noWaves" select="count($root/m:waves/m:noWaves|$root/m:windWaves/m:noWaves|$root/m:swell/m:swellData/m:noWaves)"/>
  <xsl:variable name="notAvailable" select="count($root/m:waves/m:notAvailable|$root/m:windWaves/m:notAvailable|$root/m:swell/m:swellData/m:notAvailable)"/>
  <xsl:if test="$noWaves > 0 and $notAvailable + $noWaves = count($root/m:waves|$root/m:windWaves|$root/m:swell/m:swellData)">1</xsl:if>
 </xsl:template>

 <xsl:template match="m:synop_section2|m:buoy_section2" mode="waves">
  <xsl:variable name="noWaves" select="count(m:waves/m:noWaves|m:windWaves/m:noWaves|m:swell/m:swellData/m:noWaves)"/>
  <xsl:choose>
   <xsl:when test="$noWaves > 0 and count(m:waves/m:notAvailable|m:windWaves/m:notAvailable|m:swell/m:swellData/m:notAvailable) + $noWaves = count(m:waves|m:windWaves|m:swell/m:swellData)">-</xsl:when>
   <xsl:otherwise>
    <xsl:apply-templates select="m:waves[not(boolean(m:notAvailable|m:noWaves))]|m:windWaves[not(boolean(m:notAvailable|m:noWaves))]|m:swell/m:swellData[not(boolean(m:notAvailable|m:invalidFormat|m:noWaves))]"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:synop">
  <xsl:if test="position() mod 15 = 1">
   <tr>
   <xsl:apply-templates select="$trans/t:summaryHeader[@o='synop']/t:c"/>
   </tr>&nl;
  </xsl:if>
  <tr>
   <xsl:if test="$add_info = 1">
    <xsl:attribute name="title">
     <xsl:apply-templates select="m:obsStationId|m:callSign">
      <xsl:with-param name="type" select="m:obsStationType/m:stationType/@v"/>
     </xsl:apply-templates>
    </xsl:attribute>
   </xsl:if>
   <td nowrap="1">
   <xsl:text>SYNOP</xsl:text>
   <xsl:apply-templates select="m:reportModifier"/>
   </td>&tab1;
   <td nowrap="1"><xsl:apply-templates select="m:obsStationType"/></td>&tab1;
   <td nowrap="1">
   <xsl:apply-templates select="m:obsStationId/m:id|m:obsStationId/m:natId|m:callSign/m:id"/>
   </td>&tab1;
   <td nowrap="1"><xsl:apply-templates select="m:obsTime"/></td>&tab1;
   <td nowrap="1" align="right">
   <xsl:apply-templates select="m:visPrev[boolean(m:distance)]|m:visibilityAtLoc[m:locationAt/@v = 'MAR']/m:visibility[boolean(m:distance)]"/>
   </td>&tab1;
   <td nowrap="1">
   <xsl:if test="boolean(m:totalCloudCover/m:skyObscured)">?/8</xsl:if>
   <xsl:if test="boolean(m:totalCloudCover/m:oktas)">
    <xsl:value-of select="concat(m:totalCloudCover/m:oktas/@v, '/8')"/>
   </xsl:if>
   <xsl:if test="boolean(m:baseLowestCloud/m:from|m:baseLowestCloud/m:distance)">
    <xsl:if test="boolean(m:totalCloudCover/m:skyObscured|m:totalCloudCover/m:oktas)">
     <xsl:text>, </xsl:text>
    </xsl:if>
    <xsl:if test="m:baseLowestCloud/m:from/@q = 'isEqualGreater'">
     <xsl:text>&gt;=</xsl:text>
    </xsl:if>
    <xsl:value-of select="m:baseLowestCloud/m:from/@v|m:baseLowestCloud/m:distance/@v"/>
    <xsl:if test="boolean(m:baseLowestCloud/m:to)">
     <xsl:value-of select="concat('..&lt;', m:baseLowestCloud/m:to/@v)"/>
    </xsl:if>
    <xsl:value-of select="$trans/t:units[@o=current()/m:baseLowestCloud/m:from/@u|current()/m:baseLowestCloud/m:distance/@u]"/>
   </xsl:if>
   </td>&tab1;
   <td nowrap="1">
   <xsl:apply-templates select="m:sfcWind/m:wind"/>
   <xsl:apply-templates select="m:synop_section3/m:highestGust/m:wind/m:speed|m:synop_section3/m:highestMeanSpeed/m:wind/m:speed|m:synop_section5/m:highestGust/m:wind/m:speed|m:synop_section5/m:highestMeanSpeed/m:wind/m:speed|m:synop_section5/m:peakWind/m:wind/m:speed|m:synop_section9/m:highestGust/m:wind/m:speed"/>
   </td>&tab1;
   <td nowrap="1" align="right">
   <xsl:apply-templates select="m:temperature/m:air[boolean(m:temp)]"/>
   <xsl:apply-templates select="m:synop_section3/m:tempMax[boolean(m:temp)]|m:synop_section3/m:tempMin[boolean(m:temp)]|m:synop_section3/m:tempExtreme/m:tempExtremeMax[boolean(m:temp)]|m:synop_section3/m:tempExtreme/m:tempExtremeMin[boolean(m:temp)]|m:synop_section3/m:tempMaxDaytime[boolean(m:temp)]|m:synop_section3/m:tempMinNighttime[boolean(m:temp)]|m:synop_section3/m:tempMinGround[boolean(m:temp)]|m:synop_section5/m:tempMax[boolean(m:temp)]|m:synop_section5/m:tempMin[boolean(m:temp)]|m:synop_section5/m:tempMinGround[boolean(m:temp)]"/>
   </td>&tab1;
   <td nowrap="1" align="right">
   <xsl:if test="boolean(m:temperature/m:relHumid1)">
    <xsl:value-of select="concat(format-number(m:temperature/m:relHumid1/@v, '0'), ' %')"/>
    <xsl:if test="m:temperature/m:relHumid1/@q = 'M2Xderived'">*</xsl:if>
   </xsl:if>
   </td>&tab1;
   <td nowrap="1" align="right">
   <xsl:if test="boolean(m:stationPressure/m:pressure)">
    <xsl:apply-templates select="m:stationPressure/m:pressure"/>
    <xsl:apply-templates select="m:pressureChange/m:pressureChangeVal|m:synop_section3/m:pressureChange/m:pressureChangeVal"/>
   </xsl:if>
   <xsl:if test="boolean(m:gpSurface/m:geopotential)">
    <xsl:if test="boolean(m:stationPressure/m:pressure)"><xsl:text> </xsl:text></xsl:if>
    <xsl:value-of select="concat(m:gpSurface/m:surface/@v, ': ', m:gpSurface/m:geopotential/@v)"/>
   </xsl:if>
   <xsl:if test="boolean(m:SLP/m:pressure) and boolean(m:stationPressure/m:pressure|m:gpSurface/m:geopotential)"><xsl:text> </xsl:text></xsl:if>
   <xsl:apply-templates select="m:SLP/m:pressure"/>
   <xsl:if test="not(boolean(m:stationPressure/m:pressure))">
    <xsl:apply-templates select="m:pressureChange/m:pressureChangeVal"/>
    <xsl:apply-templates select="m:synop_section3/m:pressureChange/m:pressureChangeVal">
     <xsl:with-param name="pre" select="'SP '"/>
    </xsl:apply-templates>
   </xsl:if>
   </td>&tab1;
   <td nowrap="1">
   <xsl:apply-templates select="m:precipitation/m:precipAmount|m:precipitation/m:precipTraces|m:synop_section3/m:precipitation/m:precipAmount|m:synop_section3/m:precipitation/m:precipTraces|m:synop_section5/m:precipitation/m:precipAmount|m:synop_section5/m:precipitation/m:precipTraces"/>
   </td>&tab1;
   <td nowrap="1">
   <xsl:choose>
    <xsl:when test="boolean(m:weatherSynop/m:weatherPresent|m:weatherSynop/m:weatherPresentSimple)">
     <xsl:apply-templates select="m:weatherSynop/m:weatherPresent|m:weatherSynop/m:weatherPresentSimple"/>
    </xsl:when>
    <xsl:when test="m:wxInd/m:wxIndVal/@v = 2 or m:wxInd/m:wxIndVal/@v = 5 or boolean(m:weatherSynop/m:NSW)">
     <xsl:text>-</xsl:text>
     <xsl:apply-templates select="m:weatherSynop/m:timeBeforeObs"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:text>?</xsl:text>
     <xsl:apply-templates select="m:weatherSynop/m:timeBeforeObs"/>
    </xsl:otherwise>
   </xsl:choose>
   <xsl:apply-templates select="m:weatherSynop/m:weatherPast1|m:weatherSynop/m:weatherPast1Simple"/>
   <xsl:if test="(boolean(m:weatherSynop/m:weatherPast1) and m:weatherSynop/m:weatherPast1/@v != m:weatherSynop/m:weatherPast2/@v) or (boolean(m:weatherSynop/m:weatherPast1Simple) and m:weatherSynop/m:weatherPast1Simple/@v != m:weatherSynop/m:weatherPast2Simple/@v)">
    <xsl:apply-templates select="m:weatherSynop/m:weatherPast2|m:weatherSynop/m:weatherPast2Simple"/>
   </xsl:if>
   <xsl:apply-templates select="m:synop_section3/m:weatherSynopAdd/m:weatherPresent|m:synop_section3/m:weatherSynopAmplPast/m:weatherPresent|m:synop_section3/m:weatherSynopAmpl/m:weatherPresent|m:synop_section3/m:weatherSynopPast/m:weatherPresent"/>
   </td>&tab1;
   <xsl:choose>
    <xsl:when test="boolean(m:cloudTypes/m:skyObscured)">
     <td colspan="3">?/8</td>&tab3;
    </xsl:when>
    <xsl:when test="boolean(m:cloudTypes/m:cloudTypeLow|m:cloudTypes/m:cloudTypeMiddle|m:cloudTypes/m:cloudTypeHigh)">
     <td nowrap="1">
     <xsl:if test="boolean(m:cloudTypes/m:oktasLow)">
      <xsl:value-of select="concat(m:cloudTypes/m:oktasLow/@v, '/8 ')"/>
     </xsl:if>
     <xsl:apply-templates select="m:cloudTypes/m:cloudTypeLow"/>
     </td>&tab1;
     <td nowrap="1">
     <xsl:if test="boolean(m:cloudTypes/m:oktasMiddle)">
      <xsl:value-of select="concat(m:cloudTypes/m:oktasMiddle/@v, '/8 ')"/>
     </xsl:if>
     <xsl:apply-templates select="m:cloudTypes/m:cloudTypeMiddle"/>
     </td>&tab1;
     <td nowrap="1">
     <xsl:apply-templates select="m:cloudTypes/m:cloudTypeHigh"/>
     </td>&tab1;
    </xsl:when>
    <xsl:otherwise>
     <td colspan="3"/>&tab3;
    </xsl:otherwise>
   </xsl:choose>
   <td nowrap="1">
   <!-- don't show if just oktas or oktas=0 -->
   <xsl:apply-templates select="m:synop_section3/m:cloudInfo[(not(boolean(m:cloudBaseNotAvailable|m:invalidFormat)) or boolean(m:cloudType|m:cloudTypeLow|m:cloudTypeMiddle|m:cloudTypeHigh)) and not(m:cloudOktas/m:oktas/@v = 0)]"/>
   </td>&tab1;
   <td nowrap="1">
   <xsl:apply-templates select="m:synop_section2[boolean(m:waves|m:windWaves|m:swell)]" mode="waves"/>
   </td>&tab1;
   <td nowrap="1">
   <xsl:variable name="warnings">
    <xsl:apply-templates select="m:warning[@warningType='notProcessed']|descendant::m:invalidFormat"/>
   </xsl:variable>
   <xsl:value-of select="substring($warnings, 1, 40)"/>
   <xsl:if test="string-length($warnings) &gt; 40"> ...</xsl:if>
   <xsl:apply-templates select="m:ERROR">
    <xsl:with-param name="need_sep" select="$warnings != ''"/>
   </xsl:apply-templates>
   </td>
   <xsl:call-template name="msg">
    <xsl:with-param name="type" select="'synop'"/>
   </xsl:call-template>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:buoy">
  <xsl:if test="position() mod 15 = 1">
   <tr>
   <xsl:apply-templates select="$trans/t:summaryHeader[@o='buoy']/t:c"/>
   </tr>&nl;
  </xsl:if>
  <tr>
   <xsl:if test="$add_info = 1">
    <xsl:attribute name="title">
     <xsl:apply-templates select="m:buoyId">
      <xsl:with-param name="type" select="m:obsStationType/m:stationType/@v"/>
     </xsl:apply-templates>
    </xsl:attribute>
   </xsl:if>
   <td nowrap="1">
   <xsl:text>BUOY</xsl:text>
   <xsl:apply-templates select="m:reportModifier"/>
   </td>&tab1;
   <td nowrap="1"><xsl:value-of select="m:buoyId/m:id/@v"/></td>&tab1;
   <td nowrap="1"><xsl:apply-templates select="m:obsTime"/></td>&tab1;
   <td nowrap="1">
   <xsl:apply-templates select="m:buoy_section1/m:sfcWind/m:wind"/>
   </td>&tab1;
   <td nowrap="1" align="right">
   <xsl:apply-templates select="m:buoy_section1/m:temperature/m:air[boolean(m:temp)]"/>
   </td>&tab1;
   <td nowrap="1" align="right">
   <xsl:if test="boolean(m:buoy_section1/m:temperature/m:relHumid1)">
    <xsl:value-of select="concat(format-number(m:buoy_section1/m:temperature/m:relHumid1/@v, '0'), ' %')"/>
    <xsl:if test="m:buoy_section1/m:temperature/m:relHumid1/@q = 'M2Xderived'">*</xsl:if>
   </xsl:if>
   </td>&tab1;
   <td nowrap="1" align="right">
   <xsl:if test="boolean(m:buoy_section1/m:stationPressure/m:pressure)">
    <xsl:apply-templates select="m:buoy_section1/m:stationPressure/m:pressure"/>
    <xsl:apply-templates select="m:buoy_section1/m:pressureChange/m:pressureChangeVal|m:buoy_section3/m:pressureChange/m:pressureChangeVal"/>
   </xsl:if>
   <xsl:if test="boolean(m:buoy_section1/m:SLP/m:pressure) and boolean(m:buoy_section1/m:stationPressure/m:pressure)"><xsl:text> </xsl:text></xsl:if>
   <xsl:apply-templates select="m:buoy_section1/m:SLP/m:pressure"/>
   <xsl:if test="not(boolean(m:buoy_section1/m:stationPressure/m:pressure))">
    <xsl:apply-templates select="m:buoy_section1/m:pressureChange/m:pressureChangeVal"/>
   </xsl:if>
   </td>&tab1;
   <td nowrap="1">
   <xsl:apply-templates select="m:buoy_section2[boolean(m:waves|m:windWaves|m:swell)]" mode="waves"/>
   </td>&tab1;
   <td nowrap="1">
   <xsl:variable name="warnings">
    <xsl:apply-templates select="m:warning[@warningType='notProcessed']|descendant::m:invalidFormat"/>
   </xsl:variable>
   <xsl:value-of select="substring($warnings, 1, 40)"/>
   <xsl:if test="string-length($warnings) &gt; 40"> ...</xsl:if>
   <xsl:apply-templates select="m:ERROR">
    <xsl:with-param name="need_sep" select="$warnings != ''"/>
   </xsl:apply-templates>
   </td>
   <xsl:call-template name="msg">
    <xsl:with-param name="type" select="'buoy'"/>
   </xsl:call-template>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:pressureChangeVal">
  <xsl:param name="pre"/>
  <xsl:variable name="sign">
   <xsl:if test="@v > 0">+</xsl:if>
  </xsl:variable>
  <xsl:if test="position() = 1"> (</xsl:if>
  <xsl:if test="position() != 1">, </xsl:if>
  <xsl:value-of select="concat($pre, $sign, @v)"/>
  <xsl:apply-templates select="../m:timeBeforeObs"/>
  <xsl:if test="position() = last()">)</xsl:if>
 </xsl:template>

 <xsl:template match="m:reportModifier">
  <xsl:value-of select="concat(' ', m:modifierType/@v)"/>
  <xsl:if test="boolean(m:segment/@v)"><xsl:value-of select="m:segment/@v"/></xsl:if>
  <xsl:if test="boolean(m:over24hLate)">Z</xsl:if>
  <xsl:if test="boolean(m:sequenceLost)">Y</xsl:if>
  <xsl:if test="boolean(m:bulletinSeq/@v)"><xsl:value-of select="m:bulletinSeq/@v"/></xsl:if>
 </xsl:template>

 <xsl:template match="m:fcstCancelled">
  <xsl:value-of select="concat(' ', @s)"/>
 </xsl:template>

 <xsl:template match="m:weatherPresent|m:weatherPresentSimple">
  <xsl:variable name="weather">
   <xsl:choose>
    <xsl:when test="name() = 'weatherPresentSimple'">
     <xsl:value-of select="$transsum/t:weatherPresentSimpleSum/t:arr[current()/@v + 1]"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="$transsum/t:weatherPresentSum/t:arr[current()/@v + 1]"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <xsl:if test="name(..) = 'weatherSynop' or $weather != '-'">
   <xsl:if test="name(..) != 'weatherSynop'">, </xsl:if>
   <xsl:value-of select="$weather"/>
   <xsl:if test="name(..) != 'weatherSynop'">
    <xsl:apply-templates select="../m:timeBeforeObs"/>
   </xsl:if>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:weatherPast1|m:weatherPast1Simple|m:weatherPast2|m:weatherPast2Simple">
  <xsl:variable name="weather">
   <xsl:choose>
    <xsl:when test="name() = 'weatherPast1' or name() = 'weatherPast2'">
     <xsl:value-of select="$transsum/t:weatherPastSum/t:arr[current()/@v + 1]"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="$transsum/t:weatherPastSimpleSum/t:arr[current()/@v + 1]"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <xsl:if test="$weather != '-'">
   <xsl:value-of select="concat(', ', $weather)"/>
   <xsl:apply-templates select="../m:timeBeforeObs"/>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:cloudInfo">
  <xsl:if test="position() &gt; 1">, </xsl:if>
  <xsl:if test="boolean(m:cloudOktas/m:oktas)">
   <xsl:value-of select="concat(m:cloudOktas/m:oktas/@v, '/8 ')"/>
  </xsl:if>
  <xsl:apply-templates select="m:cloudType|m:cloudTypes/m:cloudTypeLow|m:cloudTypes/m:cloudTypeMiddle|m:cloudTypes/m:cloudTypeHigh">
   <xsl:with-param name="post" select="' '"/>
  </xsl:apply-templates>
  <xsl:if test="boolean(m:visVert|m:visVertFrom)">VV</xsl:if>
  <xsl:if test="boolean(m:cloudBase|m:visVert)">
   <xsl:variable name="val" select="m:cloudBase|m:visVert/m:distance"/>
   <xsl:if test="$val/@q = 'isLess'">
    <xsl:text>&lt;</xsl:text>
   </xsl:if>
   <xsl:if test="$val/@q = 'isGreater'">
    <xsl:text>&gt;</xsl:text>
   </xsl:if>
   <xsl:if test="$val/@q = 'isEqualGreater'">
    <xsl:text>&gt;=</xsl:text>
   </xsl:if>
   <xsl:value-of select="concat($val/@v, $trans/t:units[@o=$val/@u])"/>
  </xsl:if>
  <xsl:if test="boolean(m:cloudBaseFrom|m:visVertFrom)">
   <xsl:variable name="valFrom" select="m:cloudBaseFrom|m:visVertFrom/m:distance"/>
   <xsl:variable name="valTo" select="m:cloudBaseTo|m:visVertTo/m:distance"/>
   <xsl:value-of select="concat($valFrom/@v, '..')"/>
   <xsl:if test="$valTo/@q = 'isLess'">
    <xsl:text>&lt;</xsl:text>
   </xsl:if>
   <xsl:value-of select="concat($valTo/@v, $trans/t:units[@o=$valTo/@u])"/>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:waves|m:windWaves|m:swellData">
  <xsl:if test="position() != 1">, </xsl:if>
  <xsl:if test="boolean(m:seaConfused)">~</xsl:if>
  <xsl:if test="boolean(m:wavePeriod)">
   <xsl:if test="boolean(m:seaConfused)">/</xsl:if>
   <xsl:value-of select="concat(m:wavePeriod/@v, $trans/t:units[@o='SEC-sum'])"/>
  </xsl:if>
  <xsl:if test="boolean(m:dir)">
   <xsl:if test="boolean(m:seaConfused|m:wavePeriod)">/</xsl:if>
   <xsl:value-of select="concat(m:dir/@v, '°')"/>
  </xsl:if>
  <xsl:if test="boolean(m:height)">
   <xsl:if test="boolean(m:seaConfused|m:wavePeriod|m:dir)">/</xsl:if>
   <xsl:value-of select="concat(m:height/@v, $trans/t:units[@o=current()/m:height/@u])"/>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:tempMax|m:tempMin|m:tempExtremeMax|m:tempExtremeMin|m:tempMaxDaytime|m:tempMinNighttime|m:tempMinGround|m:tempAt|m:tempMaxAt|m:tempMinAt">
  <xsl:if test="position() = 1"> (</xsl:if>
  <xsl:if test="position() != 1">, </xsl:if>
  <xsl:choose>
   <xsl:when test="name() = 'tempAt'"></xsl:when>
   <xsl:when test="name() = 'tempMax' or name() = 'tempExtremeMax' or name() = 'tempMaxDaytime' or name() = 'tempMaxAt'">^</xsl:when>
   <xsl:when test="name() = 'tempMinGround'">_</xsl:when>
   <xsl:otherwise>v</xsl:otherwise>
  </xsl:choose>
  <xsl:call-template name="printTemp">
   <xsl:with-param name="temp" select="."/>
  </xsl:call-template>
  <xsl:apply-templates select="m:timePeriod|m:timeBeforeObs|m:timeAt">
   <xsl:with-param name="need_type" select="1"/>
  </xsl:apply-templates>
  <xsl:if test="not(boolean(m:timePeriod|m:timeBeforeObs|m:timeAt))">/</xsl:if>
  <xsl:if test="name() = 'tempMaxDaytime'">D</xsl:if>
  <xsl:if test="name() = 'tempMinNighttime'">N</xsl:if>
  <xsl:if test="position() = last()">)</xsl:if>
 </xsl:template>

 <xsl:template match="m:precipAmount|m:precipTraces">
  <xsl:if test="position() &gt; 1">, </xsl:if>
  <xsl:if test="name() = 'precipTraces'">
   <xsl:value-of select="$trans/t:t[@o='precipTraces']"/>
  </xsl:if>
  <xsl:if test="name() = 'precipAmount'">
   <xsl:value-of select="concat(@v, $trans/t:units[@o=current()/@u])"/>
  </xsl:if>
  <xsl:apply-templates select="../m:timePeriod|../m:timeBeforeObs"/>
 </xsl:template>

 <xsl:template match="m:amdar">
  <xsl:if test="position() mod 15 = 1">
   <tr>
   <xsl:apply-templates select="$trans/t:summaryHeader[@o='amdar']/t:c"/>
   </tr>&nl;
  </xsl:if>
  <xsl:variable name="rows" select="count(m:amdarObs)"/>
  <tr>
   <xsl:if test="$add_info = 1">
    <xsl:attribute name="title">
     <xsl:apply-templates select="m:aircraftId">
      <xsl:with-param name="type" select="m:obsStationType/m:stationType/@v"/>
     </xsl:apply-templates>
    </xsl:attribute>
   </xsl:if>
   <td nowrap="1">
    <xsl:if test="$rows > 1">
     <xsl:attribute name="valign">top</xsl:attribute>
     <xsl:attribute name="rowspan">
      <xsl:value-of select="$rows"/>
     </xsl:attribute>
    </xsl:if>
    <xsl:text>AMDAR</xsl:text>
   </td>&tab1;
   <td nowrap="1">
    <xsl:if test="$rows > 1">
     <xsl:attribute name="valign">top</xsl:attribute>
     <xsl:attribute name="rowspan">
      <xsl:value-of select="$rows"/>
     </xsl:attribute>
    </xsl:if>
    <xsl:if test="boolean(m:amdarInfo/m:amdarSystem)">
     <xsl:value-of select="substring($trans/t:amdarSystem[@o=current()/m:amdarInfo/m:amdarSystem/@v], 1, 5)"/>
    </xsl:if>
   </td>&tab1;
   <td nowrap="1">
    <xsl:if test="$rows > 1">
     <xsl:attribute name="valign">top</xsl:attribute>
     <xsl:attribute name="rowspan">
      <xsl:value-of select="$rows"/>
     </xsl:attribute>
    </xsl:if>
    <xsl:value-of select="m:aircraftId/m:id/@v"/>
   </td>&tab1;
   <td nowrap="1">
    <xsl:if test="$rows > 1">
     <xsl:attribute name="valign">top</xsl:attribute>
     <xsl:attribute name="rowspan">
      <xsl:value-of select="$rows"/>
     </xsl:attribute>
    </xsl:if>
    <xsl:apply-templates select="m:obsTime"/>
   </td>&tab1;
   <xsl:choose>
    <xsl:when test="$rows > 0">
     <td nowrap="1">
     <xsl:choose>
      <xsl:when test="boolean(m:amdarObs[1]/m:aircraftLocation)">
       <xsl:apply-templates select="m:amdarObs[1]/m:aircraftLocation"/>
       <xsl:if test="boolean(m:amdarObs[1]/m:flightLvl/m:level|m:amdarObs[1]/m:pressureAlt/m:altitude|m:amdar_section3/m:flightLvl/m:level)">
        <xsl:text> </xsl:text>
       </xsl:if>
      </xsl:when>
      <xsl:otherwise>
       <xsl:apply-templates select="m:aircraftLocation"/>
       <xsl:if test="boolean(m:amdarObs[1]/m:flightLvl/m:level|m:amdarObs[1]/m:pressureAlt/m:altitude|m:amdar_section3/m:flightLvl/m:level)">
        <xsl:text> </xsl:text>
       </xsl:if>
      </xsl:otherwise>
     </xsl:choose>
     <xsl:choose>
      <xsl:when test="boolean(m:amdarObs[1]/m:flightLvl/m:level|m:amdarObs[1]/m:pressureAlt/m:altitude)">
       <xsl:apply-templates select="m:amdarObs[1]/m:flightLvl/m:level|m:amdarObs[1]/m:pressureAlt/m:altitude"/>
      </xsl:when>
      <xsl:otherwise>
       <xsl:apply-templates select="m:amdar_section3/m:flightLvl/m:level"/>
      </xsl:otherwise>
     </xsl:choose>
     </td>&tab1;
     <td nowrap="1">
     <xsl:apply-templates select="m:amdarObs[1]/m:windAtPA/m:wind"/>
     </td>&tab1;
     <td nowrap="1" align="right">
     <xsl:apply-templates select="m:amdarObs[1]/m:temperature/m:air[boolean(m:temp)]"/>
     </td>&tab1;
    </xsl:when>
    <xsl:otherwise>
     <td colspan="3"/>&tab3;
    </xsl:otherwise>
   </xsl:choose>
   <td nowrap="1">
   <xsl:if test="$rows > 1">
    <xsl:attribute name="rowspan">
     <xsl:value-of select="$rows"/>
    </xsl:attribute>
   </xsl:if>
   <xsl:variable name="warnings">
    <xsl:apply-templates select="m:warning[@warningType='notProcessed']|descendant::m:invalidFormat"/>
   </xsl:variable>
   <xsl:value-of select="substring($warnings, 1, 40)"/>
   <xsl:if test="string-length($warnings) &gt; 40"> ...</xsl:if>
   <xsl:apply-templates select="m:ERROR">
    <xsl:with-param name="need_sep" select="$warnings != ''"/>
   </xsl:apply-templates>
   </td>
   <xsl:call-template name="msg">
    <xsl:with-param name="type" select="'amdar'"/>
    <xsl:with-param name="rows" select="$rows"/>
   </xsl:call-template>
  </tr>&nl;
  <xsl:apply-templates select="m:amdarObs[position() &gt; 1]"/>
 </xsl:template>

 <xsl:template match="m:amdarObs">
  <tr>
  &tab4;
  <td nowrap="1">
  <xsl:if test="boolean(m:aircraftLocation)">
   <xsl:apply-templates select="m:aircraftLocation"/>
   <xsl:if test="boolean(m:flightLvl/m:level|m:pressureAlt/m:altitude)">
    <xsl:text> </xsl:text>
   </xsl:if>
  </xsl:if>
  <xsl:apply-templates select="m:flightLvl/m:level|m:pressureAlt/m:altitude"/>
  </td>&tab1;
  <td nowrap="1">
  <xsl:apply-templates select="m:windAtPA/m:wind"/>
  </td>&tab1;
  <td nowrap="1" align="right">
  <xsl:apply-templates select="m:temperature/m:air[boolean(m:temp)]"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:aircraftLocation">
  <xsl:apply-templates select="m:lat|m:lon"/>
 </xsl:template>

 <xsl:template match="m:lat|m:lon">
  <xsl:variable name="fmt_deg">
   <xsl:if test="name() = 'lat'">00</xsl:if>
   <xsl:if test="name() = 'lon'">000</xsl:if>
  </xsl:variable>
  <xsl:variable name="degmin">
   <xsl:choose>
    <xsl:when test="starts-with(@v, '-')">
     <xsl:value-of select="format-number(substring(@v, 2) * 60, '0')"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="format-number(@v * 60, '0')"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <xsl:variable name="min" select="format-number($degmin mod 60, '00')"/>
  <xsl:value-of select="concat(format-number(($degmin - $min) div 60, $fmt_deg), $min)"/>
  <xsl:choose>
   <xsl:when test="starts-with(@v, '-')">
    <xsl:if test="name() = 'lat'">S </xsl:if>
    <xsl:if test="name() = 'lon'">W</xsl:if>
   </xsl:when>
   <xsl:otherwise>
    <xsl:if test="name() = 'lat'">N </xsl:if>
    <xsl:if test="name() = 'lon'">E</xsl:if>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:level">
  <xsl:value-of select="concat('FL', format-number(@v, '000'))"/>
 </xsl:template>

 <xsl:template match="m:altitude">
  <xsl:value-of select="concat('FL', format-number(@v div 100, '000'))"/>
 </xsl:template>

</xsl:stylesheet>
