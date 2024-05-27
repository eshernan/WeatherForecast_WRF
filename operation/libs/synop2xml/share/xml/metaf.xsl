<?xml version="1.0" encoding="UTF-8"?>
<!--
########################################################################
# metaf.xsl 2.1
#   templates to transform XML to HTML or text
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
<!ENTITY xslns      'http://www.w3.org/1999/XSL/Transform'>
<!ENTITY tab1       '<text xmlns="&xslns;">&#9;</text>'>
<!ENTITY tab2       '<text xmlns="&xslns;">&#9;&#9;</text>'>
<!ENTITY tab3       '<text xmlns="&xslns;">&#9;&#9;&#9;</text>'>
<!ENTITY tab4       '<text xmlns="&xslns;">&#9;&#9;&#9;&#9;</text>'>
<!ENTITY tab5       '<text xmlns="&xslns;">&#9;&#9;&#9;&#9;&#9;</text>'>
<!ENTITY nl         '<text xmlns="&xslns;">&#10;</text>'>
<!ENTITY src_string '<call-template xmlns="&xslns;" name="src_string"/>'>
<!ENTITY hdr_string '<call-template xmlns="&xslns;" name="hdr_string"/>'>
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

 <!-- set parameter with option "- -stringparam name value" of xsltproc -->
 <xsl:param name="lang"/>

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

 <xsl:variable name="lang_used_xml" select="concat('metaf-lang-', $lang_used, '.xml')"/>
 <xsl:variable name="transroot" select="document($lang_used_xml)/trans"/>
 <xsl:variable name="trans" select="$transroot/t:lang"/>

 <xsl:variable name="NM2KM" select="1.852"/>
 <xsl:variable name="FT2M" select="0.3048"/>
 <xsl:variable name="SM2M" select="1609.34"/><!-- U.S. and int. statute mile -->
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
    <xsl:value-of select="concat('ERROR: versions differ: XML: ', namespace-uri(*[last()]), ', metaf.xsl: http://metaf2xml.sourceforge.net/2.1')"/>
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
    <xsl:value-of select="concat('ERROR: versions differ: ', $lang_used_xml, ': ', namespace-uri($transroot/*[1]), ', metaf.xsl: http://metaf2xml.sourceforge.net/2.1')"/>
    </b></p>&nl;
   </xsl:when>
   <xsl:otherwise>
    <xsl:if test="boolean(*)">
     <p><b><xsl:value-of select="$trans/t:cgi[@o='disclaimer']"/></b></p>
     &nl;&nl;
     <xsl:if test="boolean(//*[@q = 'M2Xderived'])">
      <p><xsl:value-of select="$trans/t:cgi[@o='derived']"/></p>
      &nl;&nl;
     </xsl:if>
    </xsl:if>
    <xsl:apply-templates select="*"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:if test="$method = 'html'">
   <xsl:comment> metaf.xsl: 2.1 </xsl:comment>
   &nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:synop">
  <table border="1" cellpadding="2" frame="box">
  <xsl:call-template name="table_head"/>
  <tr>
  <xsl:if test="$method = 'html'">
   <th nowrap="1" align="left">
   <xsl:text>SYNOP</xsl:text>
   <xsl:apply-templates select="m:reportModifier" mode="concat_s"/>
   </th>
  </xsl:if>
  <th nowrap="1" colspan="3">
  <xsl:value-of select="$trans/t:hdr[@o='synop']"/>
  <xsl:choose>
   <xsl:when test="boolean(m:obsTime/m:timeAt) and m:obsTime/m:timeAt/m:hour/@v mod 6 = 0">
    <xsl:value-of select="$trans/t:t[@o='synopMainHour']"/>
   </xsl:when>
   <xsl:when test="boolean(m:obsTime/m:timeAt) and m:obsTime/m:timeAt/m:hour/@v mod 6 = 3">
    <xsl:value-of select="$trans/t:t[@o='synopIntermHour']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:t[@o='synopNonstandardHour']"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:apply-templates select="m:reportModifier" mode="header"/>
  <xsl:if test="$method != 'html'">
   &nl;
   <xsl:value-of select="$trans/t:hdr[@o='synop_ul']"/>
  </xsl:if>
  </th>
  </tr>&nl;
  <xsl:if test="boolean(m:obsStationType)">
   <xsl:call-template name="section">
    <xsl:with-param name="section_nr" select="0"/>
   </xsl:call-template>
  </xsl:if>
  <xsl:apply-templates select="m:obsStationType|m:callSign|m:obsTime|m:windIndicator|m:stationPosition|m:obsStationId">
   <xsl:with-param name="type" select="m:obsStationType/m:stationType/@v"/>
  </xsl:apply-templates>
  <xsl:if test="boolean(m:precipInd)">
   <xsl:call-template name="section">
    <xsl:with-param name="section_nr" select="1"/>
   </xsl:call-template>
  </xsl:if>
  <xsl:apply-templates select="m:precipInd|m:wxInd|m:baseLowestCloud|m:visPrev|m:visibilityAtLoc|m:totalCloudCover|m:sfcWind|m:temperature|m:stationPressure|m:SLP|m:gpSurface|m:pressureChange|m:precipitation|m:weatherSynop|m:cloudTypes|m:exactObsTime|m:synop_section2|m:synop_section3|m:synop_section4|m:synop_section5|m:synop_section9"/>
  <xsl:apply-templates select="m:ERROR"/>
  <xsl:apply-templates select="m:reportModifier[m:modifierType/@v = 'NIL']"/>
  </table>
  &nl;
  <xsl:if test="position() != last()"><p /></xsl:if>
 </xsl:template>

 <xsl:template match="m:buoy">
  <table border="1" cellpadding="2" frame="box">
  <xsl:call-template name="table_head"/>
  <tr>
  <xsl:if test="$method = 'html'">
   <th nowrap="1" align="left">
   <xsl:text>BUOY</xsl:text>
   <xsl:apply-templates select="m:reportModifier" mode="concat_s"/>
   </th>
  </xsl:if>
  <th nowrap="1" colspan="3">
  <xsl:value-of select="$trans/t:hdr[@o='buoy']"/>
  <xsl:apply-templates select="m:reportModifier" mode="header"/>
  <xsl:if test="$method != 'html'">
   &nl;
   <xsl:value-of select="$trans/t:hdr[@o='buoy_ul']"/>
  </xsl:if>
  </th>
  </tr>&nl;
  <xsl:if test="boolean(m:obsStationType)">
   <xsl:call-template name="section">
    <xsl:with-param name="section_nr" select="0"/>
   </xsl:call-template>
  </xsl:if>
  <xsl:apply-templates select="m:obsStationType|m:buoyId|m:obsTime|m:windIndicator|m:stationPosition|m:qualityPositionTime|m:visPrev">
   <xsl:with-param name="type" select="m:obsStationType/m:stationType/@v"/>
  </xsl:apply-templates>
  <xsl:apply-templates select="m:buoy_section1|m:buoy_section2|m:buoy_section3|m:buoy_section4"/>
  <xsl:apply-templates select="m:ERROR"/>
  </table>
  &nl;
  <xsl:if test="position() != last()"><p /></xsl:if>
 </xsl:template>

 <xsl:template match="m:amdar">
  <table border="1" cellpadding="2" frame="box">
  <xsl:call-template name="table_head"/>
  <tr>
  <xsl:if test="$method = 'html'">
   <th nowrap="1" align="left">
   <xsl:text>AMDAR</xsl:text>
   </th>
  </xsl:if>
  <th nowrap="1" colspan="3">
  <xsl:value-of select="$trans/t:hdr[@o='amdar']"/>
  <xsl:apply-templates select="m:reportModifier" mode="header"/>
  <xsl:if test="$method != 'html'">
   &nl;
   <xsl:value-of select="$trans/t:hdr[@o='amdar_ul']"/>
  </xsl:if>
  </th>
  </tr>&nl;
  <xsl:if test="boolean(m:phaseOfFlight)">
   <xsl:call-template name="section">
    <xsl:with-param name="section_nr" select="2"/>
   </xsl:call-template>
  </xsl:if>
  <xsl:apply-templates select="m:phaseOfFlight|m:aircraftId|m:aircraftLocation|m:obsTime|m:amdarObs[1]|m:amdarInfo|m:amdar_section3">
   <xsl:with-param name="type" select="m:obsStationType/m:stationType/@v"/>
  </xsl:apply-templates>
  <xsl:apply-templates select="m:ERROR"/>
  </table>
  &nl;
  <xsl:if test="position() != last()"><p /></xsl:if>
 </xsl:template>

 <xsl:template match="m:taf">
  <table border="1" cellpadding="2" frame="box">
  <xsl:call-template name="table_head"/>
  <tr>
  <xsl:if test="$method = 'html'">
   <th nowrap="1" align="left">
   <xsl:text>TAF</xsl:text>
   <xsl:apply-templates select="m:reportModifier|m:fcstCancelled" mode="concat_s"/>
   </th>
  </xsl:if>
  <th nowrap="1" colspan="3">
  <xsl:choose>
   <xsl:when test="not(boolean(m:fcstPeriod/m:timeFrom))">
    <xsl:value-of select="$trans/t:hdr[@o='taf']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:variable name="hours">
     <xsl:choose>
      <xsl:when test="boolean(m:fcstPeriod/m:timeFrom/m:day) and boolean(m:fcstPeriod/m:timeTill/m:day) and m:fcstPeriod/m:timeFrom/m:day/@v &lt;= m:fcstPeriod/m:timeTill/m:day/@v">
       <xsl:value-of select="m:fcstPeriod/m:timeTill/m:hour/@v - m:fcstPeriod/m:timeFrom/m:hour/@v + 24 * (m:fcstPeriod/m:timeTill/m:day/@v - m:fcstPeriod/m:timeFrom/m:day/@v)"/>
      </xsl:when>
      <!-- TODO: how to detect if dayFrom+1 > dayTill across end of month? -->
      <xsl:when test="boolean(m:fcstPeriod/m:timeFrom/m:day) and boolean(m:fcstPeriod/m:timeTill/m:day) and m:fcstPeriod/m:timeFrom/m:hour/@v &lt; m:fcstPeriod/m:timeTill/m:hour/@v">
       <xsl:value-of select="m:fcstPeriod/m:timeTill/m:hour/@v - m:fcstPeriod/m:timeFrom/m:hour/@v + 24"/>
      </xsl:when>
      <xsl:when test="m:fcstPeriod/m:timeFrom/m:hour/@v &lt; m:fcstPeriod/m:timeTill/m:hour/@v">
       <xsl:value-of select="m:fcstPeriod/m:timeTill/m:hour/@v - m:fcstPeriod/m:timeFrom/m:hour/@v"/>
      </xsl:when>
      <xsl:when test="boolean(m:fcstPeriod/m:timeFrom/m:day) and boolean(m:fcstPeriod/m:timeTill/m:day) and m:fcstPeriod/m:timeFrom/m:day/@v != m:fcstPeriod/m:timeTill/m:day/@v">
       <xsl:value-of select="m:fcstPeriod/m:timeTill/m:hour/@v - m:fcstPeriod/m:timeFrom/m:hour/@v + 24"/>
      </xsl:when>
      <xsl:otherwise>
       <xsl:value-of select="m:fcstPeriod/m:timeTill/m:hour/@v - m:fcstPeriod/m:timeFrom/m:hour/@v + 24"/>
      </xsl:otherwise>
     </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="concat(substring-before($trans/t:hdr[@o='taf_hour'], '|'), $hours, substring-after($trans/t:hdr[@o='taf_hour'], '|'))"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:apply-templates select="m:reportModifier|m:fcstCancelled" mode="header"/>
  <xsl:if test="$method != 'html'">
   &nl;
   <xsl:value-of select="$trans/t:hdr[@o='taf_ul']"/>
  </xsl:if>
  </th>
  </tr>&nl;
  <xsl:apply-templates select="m:obsStationId|m:issueTime|m:fcstPeriod|m:fcstCancelled|m:fcstNotAvbl|m:sfcWind|m:CAVOK|m:visPrev|m:weather[1]|m:cloud[1]|m:visVert|m:tempMaxAt|m:tempMinAt|m:turbulence|m:icing|m:windShearLvl|m:windShearConds|m:minQNH|m:obscuration|m:VA_fcst|m:trend[1]|m:correctedAt|m:amendedAt|m:limMetwatch|m:autoMetwatch|m:amendment|m:issuedBy|m:temp_fcst|m:QNH_fcst|m:fcstCancelledFrom|m:tempAt|m:QFE|m:QNH|m:tafRemark[1]">
   <xsl:with-param name="type" select="'ICAO'"/>
  </xsl:apply-templates>
  <xsl:apply-templates select="m:ERROR"/>
  <xsl:apply-templates select="m:reportModifier[m:modifierType/@v = 'NIL']"/>
  </table>
  &nl;
  <xsl:if test="position() != last()"><p /></xsl:if>
 </xsl:template>

 <xsl:template match="m:metar">
  <table border="1" cellpadding="2" frame="box">
  <xsl:call-template name="table_head"/>
  <tr>
  <xsl:choose>
   <xsl:when test="boolean(m:isSpeci)">
    <xsl:if test="$method = 'html'">
     <th nowrap="1" align="left">
     <xsl:text>SPECI</xsl:text>
     <xsl:apply-templates select="m:reportModifier" mode="concat_s"/>
     </th>
    </xsl:if>
    <th nowrap="1" colspan="3">
    <xsl:value-of select="$trans/t:hdr[@o='speci']"/>
    <xsl:apply-templates select="m:reportModifier" mode="header"/>
    <xsl:if test="$method != 'html'">
     &nl;
     <xsl:value-of select="$trans/t:hdr[@o='speci_ul']"/>
    </xsl:if>
    </th>
   </xsl:when>
   <xsl:otherwise>
    <xsl:if test="$method = 'html'">
     <th nowrap="1" align="left">
     <xsl:text>METAR</xsl:text>
     <xsl:apply-templates select="m:reportModifier" mode="concat_s"/>
     </th>
    </xsl:if>
    <th nowrap="1" colspan="3">
    <xsl:value-of select="$trans/t:hdr[@o='metar']"/>
    <xsl:apply-templates select="m:reportModifier" mode="header"/>
    <xsl:if test="$method != 'html'">
     &nl;
     <xsl:value-of select="$trans/t:hdr[@o='metar_ul']"/>
    </xsl:if>
    </th>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
  <xsl:apply-templates select="m:obsStationId|m:obsTime|m:sfcWind|m:CAVOK|m:skyObstructed|m:visPrev|m:visMin|m:visMax|m:visRwy|m:RVRNO|m:weather[1]|m:cloud[1]|m:visVert|m:temperature|m:QNH|m:QFE|m:windShear|m:waterTemp|m:seaCondition|m:waveHeight|m:rwyState|m:stationPressure|m:recentWeather[1]|m:colourCode|m:cloudMaxCover|m:RH|m:trend[1]|m:remark[1]">
   <xsl:with-param name="type" select="'ICAO'"/>
  </xsl:apply-templates>
  <xsl:apply-templates select="m:ERROR"/>
  <xsl:apply-templates select="m:reportModifier[m:modifierType/@v = 'NIL']"/>
  </table>
  &nl;
  <xsl:if test="position() != last()"><p /></xsl:if>
 </xsl:template>

 <xsl:template name="table_head">
  <tr>
  <td colspan="4" class="msg">
  <xsl:if test="$method != 'html'">msg: </xsl:if>
  <xsl:value-of select="@s"/>
  </td>
  </tr>&nl;
  <xsl:apply-templates select="m:warning"/>
 </xsl:template>

 <xsl:template name="src_string">
  <xsl:param name="rows"/>
  <xsl:param name="s"/>
  <xsl:if test="$method = 'html'">
   <td>
   <xsl:if test="$rows > 1">
    <xsl:attribute name="valign">top</xsl:attribute>
    <xsl:attribute name="rowspan">
     <xsl:value-of select="$rows"/>
    </xsl:attribute>
   </xsl:if>
   <b>
   <xsl:choose>
    <xsl:when test="$s != ''"><xsl:value-of select="$s"/></xsl:when>
    <xsl:otherwise><xsl:value-of select="@s"/></xsl:otherwise>
   </xsl:choose>
   </b>
   </td>
  </xsl:if>
 </xsl:template>

 <xsl:template name="hdr_string">
  <xsl:param name="hdr_name"/>
  <xsl:param name="rows"/>
  <xsl:param name="derived"/>
  <td nowrap="1">
   <xsl:if test="$rows > 1">
    <xsl:attribute name="valign">top</xsl:attribute>
    <xsl:attribute name="rowspan">
     <xsl:value-of select="$rows"/>
    </xsl:attribute>
   </xsl:if>
   <xsl:variable name="hdr">
    <xsl:choose>
     <xsl:when test="$hdr_name != ''">
      <xsl:value-of select="$trans/t:hdr[@o=$hdr_name]"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="$trans/t:hdr[@o=name(current())]"/>
     </xsl:otherwise>
    </xsl:choose>
   </xsl:variable>
   <xsl:choose>
    <xsl:when test="$derived = 1">
     <xsl:value-of select="concat(substring-before($hdr, ':'), '*:', substring-after($hdr, ':'))"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="$hdr"/>
    </xsl:otherwise>
   </xsl:choose>
  </td>
 </xsl:template>

 <xsl:template name="unitConverter">
  <xsl:param name="val"/>
  <xsl:param name="unit"/>
  <xsl:param name="factor"/>
  <xsl:param name="format"/>
  <xsl:param name="range"/>
  <xsl:if test="$val/@q = 'isEqualGreater'">&gt;=</xsl:if>
  <xsl:if test="$val/@q = 'isLess'">&lt;</xsl:if>
  <xsl:if test="$val/@q = 'isGreater'">&gt;</xsl:if>
  <xsl:choose>
   <xsl:when test="$unit = '' or $val/@u = $unit">
    <xsl:value-of select="$val/@v"/>
    <xsl:if test="boolean($val/@rp|$val/@rn|$val/@rpi|$val/@rne)">
     <xsl:variable name="gt">
      <xsl:if test="boolean($val/@rne)">&gt;</xsl:if>
     </xsl:variable>
     <xsl:variable name="lt">
      <xsl:if test="boolean($val/@rp)">&lt;</xsl:if>
     </xsl:variable>
     <xsl:text> </xsl:text>
     <xsl:if test="$range = ''">(</xsl:if>
     <xsl:variable name="rp" select="$val/@rp|$val/@rpi"/>
     <xsl:variable name="rn" select="$val/@rn|$val/@rne"/>
     <xsl:choose>
      <xsl:when test="boolean($val/@rn|$val/@rne) and boolean($val/@rp|$val/@rpi)">
       <xsl:value-of select="concat($gt, $val/@v - $rn, ' .. ', $lt, $val/@v + $rp)"/>
      </xsl:when>
      <xsl:when test="boolean($val/@rn|$val/@rne)">
       <xsl:value-of select="concat($gt, $val/@v - $rn, ' ..')"/>
      </xsl:when>
      <xsl:otherwise>
       <xsl:value-of select="concat('.. ', $lt, $val/@v + $rp)"/>
      </xsl:otherwise>
     </xsl:choose>
     <xsl:if test="$range = ''">)</xsl:if>
    </xsl:if>
    <xsl:value-of select="$trans/t:units[@o=$val/@u]"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:variable name="conv_rate">
     <xsl:choose>
      <xsl:when test="$val/@u = 'IN' and $unit = 'MM'">
       <xsl:value-of select="$FT2M div 12 * 1000"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'MM' and $unit = 'IN'">
       <xsl:value-of select="12 div $FT2M div 1000"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'IN' and $unit = 'CM'">
       <xsl:value-of select="$FT2M div 12 * 100"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'CM' and $unit = 'IN'">
       <xsl:value-of select="12 div $FT2M div 100"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'FT' and $unit = 'M'">
       <xsl:value-of select="$FT2M"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'M' and $unit = 'FT'">
       <xsl:value-of select="1 div $FT2M"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'FT' and $unit = 'KM'">
       <xsl:value-of select="$FT2M div 1000"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'KM' and $unit = 'FT'">
       <xsl:value-of select="1000 div $FT2M"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'NM' and $unit = 'M'">
       <xsl:value-of select="$NM2KM * 1000"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'M' and $unit = 'NM'">
       <xsl:value-of select="1 div 1000 div $NM2KM"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'NM' and $unit = 'KM'">
       <xsl:value-of select="$NM2KM"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'KM' and $unit = 'NM'">
       <xsl:value-of select="1 div $NM2KM"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'FT' and $unit = 'SM'">
       <xsl:value-of select="$FT2M div $SM2M"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'SM' and $unit = 'FT'">
       <xsl:value-of select="$SM2M div $FT2M"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'SM' and $unit = 'M'">
       <xsl:value-of select="$SM2M"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'M' and $unit = 'SM'">
       <xsl:value-of select="1 div $SM2M"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'SM' and $unit = 'KM'">
       <xsl:value-of select="$SM2M div 1000"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'KM' and $unit = 'SM'">
       <xsl:value-of select="1000 div $SM2M"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'KT' and $unit = 'KMH'">
       <xsl:value-of select="$NM2KM"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'KMH' and $unit = 'KT'">
       <xsl:value-of select="1 div $NM2KM"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'KMH' and $unit = 'MPH'">
       <xsl:value-of select="1000 div $SM2M"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'MPH' and $unit = 'KMH'">
       <xsl:value-of select="$SM2M div 1000"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'KMH' and $unit = 'MPS'">
       <xsl:value-of select="1 div 3.6"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'MPS' and $unit = 'KMH'">
       <xsl:value-of select="3.6"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'MPS' and $unit = 'KT'">
       <xsl:value-of select="3.6 div $NM2KM"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'KT' and $unit = 'MPS'">
       <xsl:value-of select="$NM2KM div 3.6"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'MPS' and $unit = 'MPH'">
       <xsl:value-of select="3600 div $SM2M"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'MPH' and $unit = 'MPS'">
       <xsl:value-of select="$SM2M div 3600"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'KT' and $unit = 'MPH'">
       <xsl:value-of select="$NM2KM * 1000 div $SM2M"/>
      </xsl:when>
      <xsl:when test="$val/@u = 'MPH' and $unit = 'KT'">
       <xsl:value-of select="$SM2M div $NM2KM div 1000"/>
      </xsl:when>
     </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="format-number($val/@v div $factor * $conv_rate, $format)"/>
    <xsl:if test="$factor = 10 and not($val/@v = '0')">0</xsl:if>
    <xsl:value-of select="$trans/t:units[@o=$unit]"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:reportModifier|m:fcstCancelled|m:fcstNotAvbl" mode="header">
  <xsl:choose>
   <xsl:when test="position() = 1">&tab2;(</xsl:when>
   <xsl:otherwise>, </xsl:otherwise>
  </xsl:choose>
  <xsl:choose>
   <xsl:when test="name() = 'reportModifier'">
    <xsl:value-of select="$trans/t:reportModifierType[@o=current()/m:modifierType/@v]"/>
    <xsl:if test="m:modifierType/@v = 'P'">
     <xsl:value-of select="concat($trans/t:t[@o='segment'],' ', m:segment/@v)"/>
      <xsl:if test="boolean(m:isLastSegment)">
       <xsl:value-of select="concat(' (', $trans/t:t[@o='last'],')')"/>
      </xsl:if>
    </xsl:if>
    <xsl:if test="boolean(m:over24hLate)">
     <xsl:value-of select="$trans/t:t[@o='over24hLate']"/>
    </xsl:if>
    <xsl:if test="boolean(m:sequenceLost)">
     <xsl:value-of select="$trans/t:t[@o='sequenceLost']"/>
    </xsl:if>
    <xsl:if test="boolean(m:bulletinSeq)">
     <xsl:value-of select="concat($trans/t:t[@o='bulletinSeq'], m:bulletinSeq/@v)"/>
    </xsl:if>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:t[@o=name(current())]"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:if test="position() = last()">)</xsl:if>
 </xsl:template>

 <xsl:template match="m:precipInd">
  <tr>
  &src_string;
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'precipIndicator'"/>
  </xsl:call-template>
  <td nowrap="1" colspan="2">
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable)">
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:precipIndicator[@o=current()/m:precipIndVal/@v]"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:wxInd">
  <tr>
  &src_string;
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'wxIndicator'"/>
  </xsl:call-template>
  <td nowrap="1" colspan="2">
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable)">
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:wxIndicator[@o=current()/m:wxIndVal/@v]"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:from|m:to|m:distance|m:cloudBase|m:cloudBaseFrom|m:cloudBaseTo|m:cloudTops|m:cloudTopsFrom|m:cloudTopsTo" mode="synop_alt">
  <xsl:choose>
   <xsl:when test="@u = 'M'">
    <xsl:call-template name="unitConverter">
     <xsl:with-param name="val" select="."/>
     <xsl:with-param name="unit" select="'FT'"/>
     <xsl:with-param name="factor" select="10"/>
     <xsl:with-param name="format" select="'0'"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:otherwise>
    <xsl:call-template name="unitConverter">
     <xsl:with-param name="val" select="."/>
     <xsl:with-param name="unit" select="'M'"/>
     <xsl:with-param name="factor" select="10"/>
     <xsl:with-param name="format" select="'0'"/>
    </xsl:call-template>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:baseLowestCloud">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(*)"/>
  </xsl:call-template>
  <xsl:variable name="hdr" select="$trans/t:hdr[@o='baseLowestCloud']"/>
  <td nowrap="1">
  <xsl:value-of select="substring-before($hdr, '|')"/>
  <xsl:if test="boolean(m:to)">
   <xsl:value-of select="$trans/t:t[@o='range-from']"/>
  </xsl:if>
  <xsl:value-of select="substring-after($hdr, '|')"/>
  </td>
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable)">
    <td nowrap="1" colspan="2">
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <td nowrap="1">
    <xsl:call-template name="unitConverter">
     <xsl:with-param name="val" select="m:from|m:distance"/>
    </xsl:call-template>
    </td>
    &tab4;
    <td nowrap="1">
    <xsl:apply-templates select="m:from|m:distance" mode="synop_alt"/>
    </td>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
  <xsl:if test="boolean(m:to)">
   <tr>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'to'"/>
   </xsl:call-template>
   <td nowrap="1">
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:to"/>
   </xsl:call-template>
   </td>
   &tab4;
   <td nowrap="1">
   <xsl:apply-templates select="m:to" mode="synop_alt"/>
   </td>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template name="latlonquad">
  <xsl:choose>
   <xsl:when test="starts-with(@v, '-')">
    <xsl:if test="name() = 'lat'"> S </xsl:if>
    <xsl:if test="name() = 'lon'"> W</xsl:if>
   </xsl:when>
   <xsl:otherwise>
    <xsl:if test="name() = 'lat'"> N </xsl:if>
    <xsl:if test="name() = 'lon'"> E</xsl:if>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:lat|m:lon">
  <xsl:choose>
   <xsl:when test="starts-with(@v, '-')">
    <xsl:value-of select="substring(@v, 2)"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="@v"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:text>°</xsl:text>
  <xsl:call-template name="latlonquad"/>
 </xsl:template>

 <xsl:template match="m:lat|m:lon" mode="min">
  <xsl:variable name="fmt_deg">
   <xsl:if test="name() = 'lat'">00</xsl:if>
   <xsl:if test="name() = 'lon'">000</xsl:if>
  </xsl:variable>
  <xsl:variable name="scale">
   <xsl:choose>
    <xsl:when test="@q &lt;= 60">1</xsl:when>
    <xsl:when test="@q = 100">10</xsl:when>
    <xsl:otherwise >100</xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <xsl:variable name="fmt_min">
   <xsl:choose>
    <xsl:when test="@q &lt;= 60">00</xsl:when>
    <xsl:when test="@q = 100">00.0</xsl:when>
    <xsl:otherwise >00.00</xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <xsl:variable name="degmin">
   <xsl:choose>
    <xsl:when test="starts-with(@v, '-')">
     <xsl:value-of select="format-number(substring(@v, 2) * 60 * $scale, '0')"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="format-number(@v * 60 * $scale, '0')"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <xsl:variable name="min" select="format-number(($degmin mod (60 * $scale)) div $scale, $fmt_min)"/>
  <xsl:value-of select="concat(format-number((($degmin div $scale) - $min) div 60, $fmt_deg), '° ', $min, '&quot;')"/>
  <xsl:call-template name="latlonquad"/>
 </xsl:template>

 <xsl:template match="m:lat|m:lon" mode="min_sec">
  <xsl:variable name="scale" select="'1000'"/>
  <xsl:variable name="fmt_deg">
   <xsl:if test="name() = 'lat'">00</xsl:if>
   <xsl:if test="name() = 'lon'">000</xsl:if>
  </xsl:variable>
  <xsl:variable name="degminsec">
   <xsl:choose>
    <xsl:when test="starts-with(@v, '-')">
     <xsl:value-of select="format-number(substring(@v, 2) * 3600 * $scale, '0')"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="format-number(@v * 3600 * $scale, '0')"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <xsl:variable name="sec" select="format-number(($degminsec mod (60 * $scale)) div $scale, '00.000')"/>
  <xsl:variable name="min" select="format-number(((($degminsec div $scale) - $sec) mod 3600) div 60, '00')"/>
  <xsl:value-of select="concat(format-number((($degminsec div $scale) - $sec - $min * 60) div 3600, $fmt_deg), '° ', $min, '&quot; ', $sec)"/>
  <xsl:text>' </xsl:text>
  <xsl:call-template name="latlonquad"/>
 </xsl:template>

 <xsl:template match="m:elevation">
  <xsl:value-of select="concat(' ', @v, $trans/t:units[@o=current()/@u])"/>
  <xsl:if test="boolean(@q)">
   <xsl:value-of select="concat(' ', $trans/t:t[@o=current()/@q])"/>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:stationPosition|m:aircraftLocation">
  <tr>
  &src_string;
  &hdr_string;
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable) or m:lat/@q &lt;= 10">
    <td nowrap="1" colspan="2">
    <xsl:apply-templates select="m:notAvailable|m:lat|m:lon"/>
    <xsl:apply-templates select="m:elevation"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <td nowrap="1">
    <xsl:choose>
     <xsl:when test="m:lat/@q = 60">
      <xsl:apply-templates select="m:lat|m:lon" mode="min"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:apply-templates select="m:lat|m:lon"/>
     </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="m:elevation"/>
    </td>
    &tab3;
    <td nowrap="1">
    <xsl:choose>
     <xsl:when test="m:lat/@q = 100000">
      <xsl:apply-templates select="m:lat|m:lon" mode="min_sec"/>
     </xsl:when>
     <xsl:when test="m:lat/@q != 60">
      <xsl:apply-templates select="m:lat|m:lon" mode="min"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:apply-templates select="m:lat|m:lon"/>
     </xsl:otherwise>
    </xsl:choose>
    </td>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:totalCloudCover|m:totalOpacity">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable|m:invalidFormat|m:oktas|m:tenths|m:skyObscured"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:gpSurface">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:choose>
   <xsl:when test="boolean(m:geopotential)">
    <xsl:value-of select="concat(substring-before($trans/t:hdr[@o='gpSurface'], '|'), m:surface/@v, substring-after($trans/t:hdr[@o='gpSurface'], '|'))"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:hdr[@o='gpSurfaceNA']"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  <td nowrap="1" colspan="2">
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable|m:invalidFormat)">
    <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="concat(m:geopotential/@v, $trans/t:units[@o='gpm'])"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:weatherSynop|m:weatherSynopAdd|m:weatherSynopAmplPast|m:weatherSynopAmpl|m:weatherSynopPast">
  <xsl:variable name="rows">
   <xsl:choose>
    <xsl:when test="name() = 'weatherSynop'">
     <xsl:choose>
      <xsl:when test="boolean(m:NSW)">1</xsl:when>
      <xsl:when test="boolean(m:weatherPast1|m:weatherPast1Simple) and boolean(m:weatherPast2NotAvailable)">3</xsl:when>
      <xsl:when test="boolean(m:weatherPast2|m:weatherPast2Simple) and boolean(m:weatherPast1NotAvailable)">3</xsl:when>
      <xsl:when test="boolean(m:weatherPast1) and boolean(m:weatherPast2) and m:weatherPast1/@v != m:weatherPast2/@v">3</xsl:when>
      <xsl:when test="boolean(m:weatherPast1Simple) and boolean(m:weatherPast2Simple) and m:weatherPast1Simple/@v != m:weatherPast2Simple/@v">3</xsl:when>
      <xsl:otherwise>2</xsl:otherwise>
     </xsl:choose>
    </xsl:when>
    <xsl:when test="boolean(m:weatherSynopFG/m:visibilityFrom)">3</xsl:when>
    <xsl:when test="boolean(m:weatherSynopFG)">2</xsl:when>
   </xsl:choose>
  </xsl:variable>
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <td nowrap="1">
  <xsl:choose>
   <xsl:when test="name() = 'weatherSynop'">
    <xsl:value-of select="$trans/t:hdr[@o='weather']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="substring-before($trans/t:hdr[@o=name(current())], '|')"/>
    <xsl:apply-templates select="m:timeBeforeObs">
     <xsl:with-param name="pre" select="' '"/>
    </xsl:apply-templates>
    <xsl:value-of select="substring-after($trans/t:hdr[@o=name(current())], '|')"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  <xsl:choose>
   <xsl:when test="boolean(m:NSW)">
    <td nowrap="1" colspan="2">
    <xsl:apply-templates select="m:timeBeforeObs">
     <xsl:with-param name="pre" select="concat($trans/t:weather[@o='NSW'], ' ')"/>
    </xsl:apply-templates>
    </td>
   </xsl:when>
   <xsl:when test="boolean(m:weatherPresentNotAvailable)">
    <td nowrap="1" colspan="2">
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
    </td>
   </xsl:when>
   <xsl:when test="boolean(m:weatherPresent)">
    <td nowrap="1" colspan="2">
    <xsl:value-of select="$trans/t:weatherSynop[@o=current()/m:weatherPresent/@v]"/>
    <xsl:apply-templates select="m:phenomVariation|m:location|m:phenomDescr">
     <xsl:with-param name="pre" select="', '"/>
    </xsl:apply-templates>
    </td>
   </xsl:when>
   <xsl:when test="boolean(m:weatherPresentSimple)">
    <td nowrap="1" colspan="2">
    <xsl:value-of select="$trans/t:weatherSynopSimple[@o=current()/m:weatherPresentSimple/@v]"/>
    </td>
   </xsl:when>
   <xsl:when test="boolean(m:weatherPresent1)">
    <td nowrap="1" colspan="2">
    <xsl:value-of select="$trans/t:weatherSynop1[@o=current()/m:weatherPresent1/@v]"/>
    </td>
   </xsl:when>
   <xsl:when test="boolean(m:weatherSynopFG)">
    <td nowrap="1" colspan="2">
    <xsl:value-of select="$trans/t:weather_all[@o='+FG']"/>
    </td>
   </xsl:when>
   <xsl:when test="boolean(m:weatherSynopPrecip)">
    <td nowrap="1" colspan="2">
    <xsl:for-each select="m:weatherSynopPrecip">
     <xsl:call-template name="printWeather"/>
    </xsl:for-each>
    <xsl:value-of select="$trans/t:hdr[@o='weatherSynopPrecip']"/>
    <xsl:if test="boolean(m:weatherSynopPrecip/m:rateOfFall)">
     <xsl:call-template name="unitConverter">
      <xsl:with-param name="val" select="m:weatherSynopPrecip/m:rateOfFall"/>
     </xsl:call-template>
    </xsl:if>
    <xsl:if test="boolean(m:weatherSynopPrecip/m:rateOfFallFrom)">
     <xsl:value-of select="concat(m:weatherSynopPrecip/m:rateOfFallFrom/@v, ' - ', m:weatherSynopPrecip/m:rateOfFallTo/@v)"/>
     <xsl:value-of select="$trans/t:units[@o=current()/m:weatherSynopPrecip/m:rateOfFallFrom/@u]"/>
    </xsl:if>
    </td>
   </xsl:when>
  </xsl:choose>
  </tr>&nl;
  <xsl:if test="name() = 'weatherSynop' and not(boolean(m:NSW))">
   <tr>
   <td nowrap="1">
    <xsl:if test="$rows > 2">
     <xsl:attribute name="valign">top</xsl:attribute>
     <xsl:attribute name="rowspan">
      <xsl:value-of select="$rows - 1"/>
     </xsl:attribute>
    </xsl:if>
    <xsl:apply-templates select="m:timeBeforeObs">
     <xsl:with-param name="pre" select="' '"/>
     <xsl:with-param name="header" select="$trans/t:hdr[@o='weatherPast']"/>
    </xsl:apply-templates>
   </td>
   <td nowrap="1" colspan="2">
   <xsl:choose>
    <xsl:when test="boolean(m:weatherPast1NotAvailable)">
     <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
    </xsl:when>
    <xsl:when test="boolean(m:weatherPast1Simple)">
     <xsl:value-of select="$trans/t:weatherSynopPastSimple[@o=current()/m:weatherPast1Simple/@v]"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="$trans/t:weatherSynopPast[@o=current()/m:weatherPast1/@v]"/>
    </xsl:otherwise>
   </xsl:choose>
   </td>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:weatherSynopFG/m:visibility|m:weatherSynopFG/m:visibilityFrom)">
   <tr>
   <td nowrap="1">
   <xsl:value-of select="substring-before($trans/t:hdr[@o='visLoc'], '|')"/>
   <xsl:if test="boolean(m:weatherSynopFG/m:visibilityFrom)">
    <xsl:value-of select="$trans/t:t[@o='range-from']"/>
   </xsl:if>
   <xsl:value-of select="substring-after($trans/t:hdr[@o='visLoc'], '|')"/>
   </td>
   <xsl:call-template name="visibility">
    <xsl:with-param name="visVal" select="m:weatherSynopFG/m:visibility|m:weatherSynopFG/m:visibilityFrom"/>
   </xsl:call-template>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:weatherSynopFG/m:visibilityTo)">
   <tr>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'to'"/>
   </xsl:call-template>
   <xsl:call-template name="visibility">
    <xsl:with-param name="visVal" select="m:weatherSynopFG/m:visibilityTo"/>
   </xsl:call-template>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="name() = 'weatherSynop' and $rows = 3">
   <tr>
   &tab3;
   <td nowrap="1" colspan="2">
   <xsl:choose>
    <xsl:when test="boolean(m:weatherPast2NotAvailable)">
     <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
    </xsl:when>
    <xsl:when test="boolean(m:weatherPast2Simple)">
     <xsl:value-of select="$trans/t:weatherSynopPastSimple[@o=current()/m:weatherPast2Simple/@v]"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="$trans/t:weatherSynopPast[@o=current()/m:weatherPast2/@v]"/>
    </xsl:otherwise>
   </xsl:choose>
   </td>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:timePeriod|m:radiationPeriod|m:sunshinePeriod">
  <xsl:param name="header"/>
  <xsl:param name="pre"/>
  <xsl:if test="$header != ''">
   <xsl:value-of select="substring-before($header, '|')"/>
  </xsl:if>
  <xsl:value-of select="$pre"/>
  <xsl:choose>
   <xsl:when test="@v = 'p' or @v = 'n' or @v = '24h06' or @v = '12h18p' or @v = '24h04' or @v = '24h14' or @v = '24h21' or @v = '24h07p' or @v = '3or6h'">
    <xsl:value-of select="$trans/t:period[@o=current()/@v]"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="concat($trans/t:t[@o='since'], @v, $trans/t:units[@o=current()/@u])"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:if test="$header != ''">
   <xsl:value-of select="substring-after($header, '|')"/>
  </xsl:if>
 </xsl:template>

 <xsl:template name="section">
  <xsl:param name="s"/>
  <xsl:param name="section_nr"/>
  <xsl:if test="$method = 'html'">
   <tr>
   <xsl:choose>
    <xsl:when test="$s != ''">
     <td nowrap="1"><b><xsl:value-of select="$s"/></b></td>
    </xsl:when>
    <xsl:otherwise>
     <td></td>
    </xsl:otherwise>
   </xsl:choose>
   <td nowrap="1" colspan="3"><b>
   <xsl:value-of select="concat($trans/t:t[@o='section'], ' ', $section_nr, ':')"/>
   </b></td>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:windIndicator">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable)">
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:units[@o=current()/m:windUnit/@v]"/>
    <xsl:if test="boolean(m:isEstimated)">
     <xsl:value-of select="concat(', ', $trans/t:t[@o='estimated'])"/>
    </xsl:if>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
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
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
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
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template name="stationInfo">
  <xsl:param name="station"/>
  <xsl:if test="($station != '' and not(m:obsStationName/@v = $station)) or boolean($station/@ctry)">
   <xsl:text> (</xsl:text>
   <xsl:if test="$station != '' and not(m:obsStationName/@v = $station)">
    <xsl:value-of select="$station"/>
    <xsl:if test="boolean($station/@ctry)">, </xsl:if>
   </xsl:if>
   <xsl:apply-templates select="$station/@ctry"/>
   <xsl:text>)</xsl:text>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:fcstPeriod|m:obsTime|m:issueTime|m:exactObsTime|m:nextFcst|m:amdAt|m:correctedAt|m:amendedAt|m:endOfContWinds|m:lastKnownPosTime|m:fcstCancelledFrom">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:invalidFormat|m:timeAt|m:timeBy|m:timeFrom|m:timeTill"/>
  <xsl:if test="name() = 'obsTime' and boolean(../m:exactObsTime/m:timeAt)">
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
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:fcstAutoObs|m:limMetwatch|m:autoMetwatch|m:windShift|m:windShearConds">
  <tr>
  &src_string;
  <td nowrap="1" colspan="3">
  <xsl:value-of select="$trans/t:hdr[@o=name(current())]"/>
  <xsl:apply-templates select="m:timeAt|m:timeFrom|m:timeTill">
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  <xsl:if test="boolean(m:FROPA)">
   <xsl:value-of select="concat(' ', $trans/t:t[@o='FROPA'])"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:skyObstructed">
  <tr>
  &src_string;
  <td nowrap="1" colspan="3">
  <xsl:choose>
   <xsl:when test="@q = 'isPartial'">
    <xsl:value-of select="$trans/t:phenomenon[@o='SKY_PRLY_OBSC']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:phenomenon[@o='SKY_OBSC']"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:visPrev|m:visMin|m:visMax">
  <xsl:variable name="rows" select="count(m:NDV) + 1"/>
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:call-template name="visibility">
   <xsl:with-param name="notavail" select="$trans/t:t[@o='notAvailable']"/>
   <xsl:with-param name="visVal" select="."/>
  </xsl:call-template>
  </tr>&nl;
  <xsl:if test="boolean(m:NDV)">
   <tr><td nowrap="1" colspan="2">
   &tab3;
   <xsl:value-of select="$trans/t:t[@o='NDV']"/>
   </td></tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:visVert">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:value-of select="concat(substring-before($trans/t:hdr[@o='visVert'], '|'), substring-after($trans/t:hdr[@o='visVert'], '|'))"/>
  </td>
  <xsl:call-template name="visibility">
   <xsl:with-param name="notavail" select="$trans/t:t[@o='visVertNA']"/>
   <xsl:with-param name="visVal" select="."/>
  </xsl:call-template>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:visRwy[m:notAvailable]">
  <tr>
  &src_string;
  <td nowrap="1" colspan="3">
  <xsl:value-of select="$trans/t:t[@o='visRwyNotAvailable']"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:visRwy">
  <xsl:variable name="hdr" select="$trans/t:hdr[@o='visRwy']"/>
  <xsl:variable name="rows" select="count(m:RVRVariations|m:visTrend) + 1"/>
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <td nowrap="1">
   <xsl:if test="$rows > 1">
    <xsl:attribute name="valign">top</xsl:attribute>
    <xsl:attribute name="rowspan">
     <xsl:value-of select="$rows"/>
    </xsl:attribute>
   </xsl:if>
   <xsl:value-of select="concat(substring-before($hdr, '|'), m:rwyDesig/@v, substring-after($hdr, '|'))"/>
  </td>
  <xsl:call-template name="visibility">
   <xsl:with-param name="notavail" select="$trans/t:t[@o='rwyVisNotAvailable']"/>
   <xsl:with-param name="fromto">
    <xsl:if test="boolean(m:RVRVariations)">
     <xsl:value-of select="$trans/t:t[@o='variable-from']"/>
    </xsl:if>
   </xsl:with-param>
   <xsl:with-param name="visVal" select="m:RVR"/>
  </xsl:call-template>
  </tr>&nl;
  <xsl:if test="boolean(m:RVRVariations)">
   &tab3;
   <tr>
   <xsl:call-template name="visibility">
    <xsl:with-param name="notavail" select="$trans/t:t[@o='rwyVisNotAvailable']"/>
    <xsl:with-param name="fromto" select="$trans/t:t[@o='variable-to']"/>
    <xsl:with-param name="visVal" select="m:RVRVariations"/>
   </xsl:call-template>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:visTrend)">
   <tr>
   <td nowrap="1" colspan="2">
    <xsl:value-of select="concat($trans/t:hdr[@o='visTrend'], $trans/t:visTrend[@o=current()/m:visTrend/@v])"/>
   </td></tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:RVRVariations|m:visTrend)">&nl;</xsl:if>
 </xsl:template>

 <xsl:template name="visibility">
  <xsl:param name="notavail"/>
  <xsl:param name="fromto"/>
  <xsl:param name="visVal"/>
  <xsl:choose>
   <xsl:when test="boolean($visVal/m:invalidFormat)">
    <td nowrap="1" colspan="2">
    <xsl:apply-templates select="$visVal/m:invalidFormat"/>
    </td>
   </xsl:when>
   <xsl:when test="boolean($visVal/m:notAvailable)">
    <td nowrap="1" colspan="2">
    <xsl:value-of select="$notavail"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <xsl:variable name="compassDir">
     <xsl:apply-templates select="$visVal/m:compassDir">
      <xsl:with-param name="pre" select="concat(' ', substring-before($trans/t:t[@o='compassDirTo'], '|'))"/>
      <xsl:with-param name="post" select="substring-after($trans/t:t[@o='compassDirTo'], '|')"/>
     </xsl:apply-templates>
    </xsl:variable>
    <td nowrap="1">
    <xsl:value-of select="$fromto"/>
    <xsl:if test="$visVal/m:distance/@q = 'isVariable'">
     <xsl:value-of select="substring-before($trans/t:t[@o='distIsVariable'], '|')"/>
    </xsl:if>
    <xsl:call-template name="unitConverter">
     <xsl:with-param name="val" select="$visVal/m:distance"/>
    </xsl:call-template>
    <xsl:if test="$visVal/m:distance/@q = 'isVariable'">
     <xsl:value-of select="substring-after($trans/t:t[@o='distIsVariable'], '|')"/>
    </xsl:if>
    <xsl:value-of select="$compassDir"/>
    </td>
    &tab5;
    <td nowrap="1">
    <xsl:choose>
     <xsl:when test="($visVal/m:distance/@u = 'M' and $visVal/m:distance/@v &lt; 2000) or ($visVal/m:distance/@u = 'KM' and $visVal/m:distance/@v &lt; 2)">
      <xsl:call-template name="unitConverter">
       <xsl:with-param name="val" select="$visVal/m:distance"/>
       <xsl:with-param name="unit" select="'FT'"/>
       <xsl:with-param name="factor">
        <xsl:choose>
         <xsl:when test="name() = 'visVert'">
          <xsl:value-of select="0.3 div $FT2M"/>
         </xsl:when>
         <xsl:otherwise>
          <xsl:value-of select="10"/>
         </xsl:otherwise>
        </xsl:choose>
       </xsl:with-param>
       <xsl:with-param name="format" select="'0'"/>
      </xsl:call-template>
     </xsl:when>
     <xsl:when test="$visVal/m:distance/@u = 'KM' or $visVal/m:distance/@u = 'M'">
      <xsl:call-template name="unitConverter">
       <xsl:with-param name="val" select="$visVal/m:distance"/>
       <xsl:with-param name="unit" select="'SM'"/>
       <xsl:with-param name="factor" select="1"/>
       <xsl:with-param name="format" select="'0.#'"/>
      </xsl:call-template>
     </xsl:when>
     <xsl:when test="($visVal/m:distance/@u = 'FT' and $visVal/m:distance/@v &lt; 6000) or (($visVal/m:distance/@u = 'SM' or $visVal/m:distance/@u = 'NM') and $visVal/m:distance/@v &lt; 2)">
      <xsl:call-template name="unitConverter">
       <xsl:with-param name="val" select="$visVal/m:distance"/>
       <xsl:with-param name="unit" select="'M'"/>
       <xsl:with-param name="factor">
        <xsl:choose>
         <xsl:when test="name() = 'visVert'">
          <xsl:value-of select="$FT2M div 0.3"/>
         </xsl:when>
         <xsl:otherwise>
          <xsl:value-of select="10"/>
         </xsl:otherwise>
        </xsl:choose>
       </xsl:with-param>
       <xsl:with-param name="format" select="'0'"/>
      </xsl:call-template>
     </xsl:when>
     <xsl:otherwise>
      <xsl:call-template name="unitConverter">
       <xsl:with-param name="val" select="$visVal/m:distance"/>
       <xsl:with-param name="unit" select="'KM'"/>
       <xsl:with-param name="factor" select="1"/>
       <xsl:with-param name="format" select="'0.#'"/>
      </xsl:call-template>
     </xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="$compassDir"/>
    </td>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:compassDir|m:cloudCompassDir|m:cloudTypeLowCompassDir|m:cloudTypeMiddleCompassDir|m:cloudTypeHighCompassDir">
  <xsl:param name="pre"/>
  <xsl:param name="post"/>
  <xsl:value-of select="$pre"/>
  <xsl:if test="@q = 'isGrid'">
   <xsl:value-of select="$trans/t:t[@o='isGrid']"/>
  </xsl:if>
  <xsl:value-of select="concat($trans/t:compassDir[@o=current()/@v], $post)"/>
 </xsl:template>

 <xsl:template match="m:timeAt|m:timeBy|m:timeFrom|m:timeSince|m:timeTill">
  <xsl:param name="pre"/>
  <xsl:param name="name"/>
  <xsl:variable name="minute">
   <xsl:choose>
    <xsl:when test="boolean(m:minute)">
     <xsl:value-of select="m:minute/@v"/>
    </xsl:when>
    <xsl:otherwise>0</xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <xsl:if test="position() = 1"><xsl:value-of select="$pre"/></xsl:if>
  <xsl:if test="position() = 2"><xsl:value-of select="' '"/></xsl:if>
  <xsl:choose>
   <xsl:when test="boolean(m:day)">
    <xsl:choose>
     <xsl:when test="$name != ''">
      <xsl:value-of select="$trans/t:t[@o=$name]"/>
     </xsl:when>
     <xsl:when test="name() = 'timeAt'">
      <xsl:value-of select="$trans/t:t[@o='onDate']"/>
     </xsl:when>
     <xsl:when test="name() = 'timeBy'">
      <xsl:value-of select="$trans/t:t[@o='byDate']"/>
     </xsl:when>
     <xsl:when test="name() = 'timeSince'">
      <xsl:value-of select="$trans/t:t[@o='sinceDate']"/>
     </xsl:when>
     <xsl:when test="name() = 'timeTill'">
      <xsl:value-of select="$trans/t:t[@o='tillDate']"/>
     </xsl:when>
     <xsl:when test="position() = 1 and last() = 2">
      <xsl:value-of select="$trans/t:t[@o='fromTillDate']"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="$trans/t:t[@o='fromDate']"/>
     </xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="concat(m:day/@v + 0, '.')"/>
    <xsl:if test="boolean(m:month)">
     <xsl:value-of select="concat(m:month/@v + 0, '.')"/>
     <xsl:if test="boolean(m:yearUnitsDigit)">
      <xsl:text>xxx</xsl:text>
     </xsl:if>
     <xsl:value-of select="m:yearUnitsDigit/@v|m:year/@v"/>
    </xsl:if>
    <xsl:text>, </xsl:text>
   </xsl:when>
   <xsl:otherwise>
    <xsl:choose>
     <xsl:when test="name() = 'timeFrom' and position() = 1 and last() = 2">
      <xsl:value-of select="$trans/t:t[@o='timeFromTill']"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="$trans/t:t[@o=name(current())]"/>
     </xsl:otherwise>
    </xsl:choose>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:choose>
   <xsl:when test="boolean(m:hour)">
    <xsl:value-of select="concat(format-number(m:hour/@v, '00:'), format-number($minute, '00'))"/>
    <xsl:choose>
     <xsl:when test="m:hour/@q = 'localtime'">
      <xsl:value-of select="$trans/t:units[@o='localtime']"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="$trans/t:units[@o='UTC']"/>
     </xsl:otherwise>
    </xsl:choose>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="concat($minute + 0, $trans/t:t[@o='afterHour'])"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:if test="position() = 2 and not(boolean(m:day)) and boolean(../m:timeFrom/m:hour) and boolean(m:hour) and ../m:timeFrom/m:hour/@v >= m:hour/@v">
   <xsl:variable name="minuteFrom">
    <xsl:choose>
     <xsl:when test="boolean(../m:timeFrom/m:minute)">
      <xsl:value-of select="../m:timeFrom/m:minute/@v"/>
     </xsl:when>
     <xsl:otherwise>0</xsl:otherwise>
    </xsl:choose>
   </xsl:variable>
   <xsl:if test="$minuteFrom >= $minute">
    <xsl:value-of select="$trans/t:t[@o='nextDay']"/>
   </xsl:if>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:peakWind">
  <xsl:apply-templates select="m:wind">
   <xsl:with-param name="hdr">
    <xsl:value-of select="substring-before($trans/t:hdr[@o='peakWind'], '|')"/>
    <xsl:apply-templates select="m:timeAt">
     <xsl:with-param name="pre" select="' '"/>
    </xsl:apply-templates>
    <xsl:value-of select="substring-after($trans/t:hdr[@o='peakWind'], '|')"/>
   </xsl:with-param>
   <xsl:with-param name="s" select="@s"/>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="m:rwyWind|m:thrWind">
  <xsl:variable name="hdr" select="$trans/t:hdr[@o=name(current())]"/>
  <xsl:apply-templates select="m:wind">
   <xsl:with-param name="hdr" select="concat(substring-before($hdr, '|'), m:rwyDesig/@v, substring-after($hdr, '|'))"/>
   <xsl:with-param name="s"   select="@s"/>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="m:sfcWind|m:windAtPA">
  <xsl:apply-templates select="m:wind">
   <xsl:with-param name="hdr" select="$trans/t:hdr[@o=name(current())]"/>
   <xsl:with-param name="s"   select="@s"/>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="m:windAtLoc">
  <xsl:variable name="loc">
   <xsl:choose>
    <xsl:when test="$trans/t:t[@o=current()/m:windLocation/@v] != ''">
     <xsl:value-of select="$trans/t:t[@o=current()/m:windLocation/@v]"/>
    </xsl:when>
    <xsl:when test="../../m:obsStationId/m:id/@v = 'NZSP' and m:windLocation/@v = 'CLN AIR'">
     <xsl:value-of select="'Clean Air Sector'"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="m:windLocation/@v"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <xsl:apply-templates select="m:wind">
   <xsl:with-param name="hdr" select="concat(substring-before($trans/t:hdr[@o='windAtLoc'], '|'), $loc, substring-after($trans/t:hdr[@o='windAtLoc'], '|'))"/>
   <xsl:with-param name="s"   select="@s"/>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="m:dir|m:cloudTypeLowDir|m:cloudTypeMiddleDir|m:cloudTypeHighDir">
  <xsl:param name="hdr"/>
  <xsl:value-of select="substring-before($trans/t:t[@o=$hdr], '|')"/>
  <xsl:if test="@q = 'isGrid'">
   <xsl:value-of select="$trans/t:t[@o='isGrid']"/>
  </xsl:if>
  <xsl:value-of select="$trans/t:compassDir[1+format-number(current()/@v div 45 * 2, '0')]"/>
  <xsl:value-of select="substring-after($trans/t:t[@o=$hdr], '|')"/>
  <xsl:value-of select="concat(' (', @v, '°')"/>
  <xsl:choose>
   <xsl:when test="boolean(@rp) and boolean(@rn)">
    <xsl:value-of select="concat(' (+', @rp, '°/-', @rn, '°)')"/>
   </xsl:when>
   <xsl:when test="boolean(@rp)">
    <xsl:value-of select="concat(' (+', @rp, '°)')"/>
   </xsl:when>
   <xsl:when test="boolean(@rn)">
    <xsl:value-of select="concat(' (-', @rn, '°)')"/>
   </xsl:when>
  </xsl:choose>
  <xsl:text>)</xsl:text>
 </xsl:template>

 <xsl:template match="m:wind">
  <xsl:param name="hdr"/>
  <xsl:param name="s"/>
  <xsl:variable name="rows" select="count(m:gustSpeed|m:windVarLeft) + 1"/>
  <tr>
  <xsl:if test="$s != ''">
   <xsl:call-template name="src_string">
    <xsl:with-param name="rows" select="$rows"/>
    <xsl:with-param name="s" select="$s"/>
   </xsl:call-template>
  </xsl:if>
  <td nowrap="1">
   <xsl:if test="$rows > 1">
    <xsl:attribute name="valign">top</xsl:attribute>
    <xsl:attribute name="rowspan">
     <xsl:value-of select="$rows"/>
    </xsl:attribute>
   </xsl:if>
   <xsl:value-of select="$hdr"/>
  </td>
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable|m:invalidFormat)">
    <td nowrap="1" colspan="2">
    <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
    </td>
   </xsl:when>
   <xsl:when test="boolean(m:isCalm)">
    <td nowrap="1" colspan="2">
    <xsl:if test="boolean(m:isEstimated)">
     <xsl:value-of select="substring-before($trans/t:t[@o='isEstimated'], '|')"/>
    </xsl:if>
    <xsl:value-of select="$trans/t:t[@o='calmWind']"/>
    <xsl:if test="boolean(m:isEstimated)">
     <xsl:value-of select="substring-after($trans/t:t[@o='isEstimated'], '|')"/>
    </xsl:if>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <xsl:variable name="dir">
     <xsl:apply-templates select="m:dir|m:dirNotAvailable|m:dirVariable|m:dirVarAllUnk">
      <xsl:with-param name="hdr" select="'wind-from'"/>
     </xsl:apply-templates>
    </xsl:variable>
    <xsl:choose>
     <xsl:when test="boolean(m:speedNotAvailable)">
      <td nowrap="1" colspan="2">
      <xsl:value-of select="$dir"/>
      <xsl:if test="$dir != ''">
       <xsl:if test="not(boolean(m:dirNotAvailable))">,</xsl:if>
       <xsl:text> </xsl:text>
      </xsl:if>
      <xsl:value-of select="$trans/t:t[@o='speedNotAvailable']"/>
      </td>
     </xsl:when>
     <xsl:otherwise>
      <xsl:call-template name="printSpeed">
       <xsl:with-param name="dir" select="$dir"/>
       <xsl:with-param name="speed" select="m:speed"/>
       <xsl:with-param name="delim" select="'&#9;&#9;'"/>
      </xsl:call-template>
     </xsl:otherwise>
    </xsl:choose>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
  <xsl:if test="boolean(m:gustSpeed)">
   <tr>
   <xsl:call-template name="printSpeed">
    <xsl:with-param name="dir" select="$trans/t:t[@o='wind-gusts']"/>
    <xsl:with-param name="speed" select="m:gustSpeed"/>
    <xsl:with-param name="delim" select="'&#9;&#9;&#9;'"/>
   </xsl:call-template>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:windVarLeft)">
   <tr>
   <td nowrap="1" colspan="2">
   <xsl:value-of select="concat($trans/t:t[@o='variable'], ' ')"/>
   <xsl:value-of select="$trans/t:t[@o='variable-from']"/>
   <xsl:value-of select="concat($trans/t:compassDir[1+format-number(current()/m:windVarLeft/@v div 45 * 2, '0')], ' ')"/>
   <xsl:value-of select="$trans/t:t[@o='variable-to']"/>
   <xsl:value-of select="concat($trans/t:compassDir[1+format-number(current()/m:windVarRight/@v div 45 * 2, '0')], ' ')"/>
   <xsl:value-of select="concat('(', m:windVarLeft/@v, '°--', m:windVarRight/@v, '°)')"/>
   </td></tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template name="printSpeed">
  <xsl:param name="dir"/>
  <xsl:param name="speed"/>
  <xsl:param name="delim"/>
  <xsl:param name="greater"/>
  <td nowrap="1">
  <xsl:if test="boolean(m:isEstimated|m:wind/m:isEstimated)">
   <xsl:value-of select="substring-before($trans/t:t[@o='isEstimated'], '|')"/>
  </xsl:if>
  <xsl:if test="$dir != ''">
   <xsl:value-of select="concat($dir, ' ', $trans/t:t[@o='wind-at'], ' ')"/>
  </xsl:if>
  <xsl:call-template name="unitConverter">
   <xsl:with-param name="val" select="$speed"/>
   <xsl:with-param name="unit" select="'KMH'"/>
   <xsl:with-param name="factor" select="1"/>
   <xsl:with-param name="format" select="'0.#'"/>
  </xsl:call-template>
  <xsl:if test="boolean(m:isEstimated|m:wind/m:isEstimated)">
   <xsl:value-of select="substring-after($trans/t:t[@o='isEstimated'], '|')"/>
  </xsl:if>
  </td>
  <xsl:value-of select="$delim"/>
  <td nowrap="1">
  <xsl:call-template name="unitConverter">
   <xsl:with-param name="val" select="$speed"/>
   <xsl:with-param name="unit" select="'KT'"/>
   <xsl:with-param name="factor" select="1"/>
   <xsl:with-param name="format" select="'0.#'"/>
  </xsl:call-template>
  <xsl:text> = </xsl:text>
  <xsl:call-template name="unitConverter">
   <xsl:with-param name="val" select="$speed"/>
   <xsl:with-param name="unit" select="'MPH'"/>
   <xsl:with-param name="factor" select="1"/>
   <xsl:with-param name="format" select="'0.#'"/>
  </xsl:call-template>
  <xsl:text> = </xsl:text>
  <xsl:call-template name="unitConverter">
   <xsl:with-param name="val" select="$speed"/>
   <xsl:with-param name="unit" select="'MPS'"/>
   <xsl:with-param name="factor" select="1"/>
   <xsl:with-param name="format" select="'0.#'"/>
  </xsl:call-template>
  </td>
 </xsl:template>

 <!-- combine all weather nodes into one set and process them in one go -->
 <xsl:template match="m:weather">
  <xsl:apply-templates select="../m:weather" mode="go">
   <xsl:with-param name="s">
    <xsl:apply-templates select="../m:weather" mode="concat_s"/>
   </xsl:with-param>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="m:recentWeather">
  <xsl:apply-templates select="../m:recentWeather" mode="go">
   <xsl:with-param name="s">
    <xsl:apply-templates select="../m:recentWeather" mode="concat_s"/>
   </xsl:with-param>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="*" mode="concat_s">
  <xsl:value-of select="concat(' ', @s)"/>
 </xsl:template>

 <xsl:template match="m:weather|m:recentWeather" mode="go">
  <xsl:param name="s"/>
  <xsl:variable name="rows">
   <xsl:if test="last() != 1"><xsl:value-of select="last()"/></xsl:if>
  </xsl:variable>
  <tr>
  <xsl:if test="position() = 1">
   <xsl:if test="$s != ''">
    <xsl:call-template name="src_string">
     <xsl:with-param name="rows" select="$rows"/>
     <xsl:with-param name="s" select="substring($s, 2)"/>
    </xsl:call-template>
   </xsl:if>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="rows" select="$rows"/>
   </xsl:call-template>
  </xsl:if>
  <td nowrap="1" colspan="2">
  <xsl:if test="position() != 1 and $method = 'text'">, </xsl:if>
  <xsl:call-template name="printWeather"/>
  </td>
  </tr>
  <xsl:if test="position() = last()">
   &nl;
  </xsl:if>
 </xsl:template>

 <xsl:template name="printWeather">
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable|m:invalidFormat)">
    <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
   </xsl:when>
   <xsl:when test="boolean(m:NSW)">
    <xsl:value-of select="$trans/t:weather[@o='NSW']"/>
   </xsl:when>
   <xsl:when test="boolean(m:tornado/@v)">
    <xsl:value-of select="$trans/t:tornadoType[@o=current()/m:tornado/@v]"/>
   </xsl:when>
   <xsl:when test="boolean(m:tornado)">
    <xsl:value-of select="$trans/t:weather[@o='tornado']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:variable name="desc">
     <xsl:if test="m:phenomDescr/@v = 'isHeavy'">+</xsl:if>
     <xsl:if test="m:phenomDescr/@v = 'isLight'">-</xsl:if>
    </xsl:variable>
    <xsl:variable name="w_all">
     <xsl:apply-templates select="m:descriptor|m:phenomSpec"/>
    </xsl:variable>
    <xsl:variable name="w_all_desc" select="concat($desc, $w_all)"/>
    <xsl:variable name="phenomDescr">
     <xsl:apply-templates select="m:phenomDescr">
      <xsl:with-param name="post" select="' '"/>
     </xsl:apply-templates>
    </xsl:variable>
    <xsl:variable name="w_primary">
     <xsl:apply-templates select="m:descriptor|m:phenomSpec[1]"/>
    </xsl:variable>
    <xsl:choose>
     <xsl:when test="$desc != '' and $trans/t:weather_all[@o=$w_all_desc] != ''">
      <xsl:value-of select="$trans/t:weather_all[@o=$w_all_desc]"/>
     </xsl:when>
     <xsl:when test="$trans/t:weather_all[@o=$w_all] != ''">
      <xsl:variable name="w_all_trans_all" select="$trans/t:weather_all[@o=$w_all]"/>
      <xsl:value-of select="concat(substring-before($w_all_trans_all, '|'), $phenomDescr, substring-after($w_all_trans_all, '|'))"/>
     </xsl:when>
     <xsl:when test="$trans/t:weather[@o=$w_all] != ''">
      <xsl:variable name="w_all_trans" select="$trans/t:weather[@o=$w_all]"/>
      <xsl:value-of select="concat(substring-before($w_all_trans, '|'), $phenomDescr, substring-after($w_all_trans, '|'))"/>
     </xsl:when>
     <xsl:when test="$trans/t:weather[@o=$w_primary] != ''">
      <xsl:variable name="w_primary_trans" select="$trans/t:weather[@o=$w_primary]"/>
      <xsl:value-of select="concat(substring-before($w_primary_trans, '|'), $phenomDescr, substring-after($w_primary_trans, '|'))"/>
      <xsl:apply-templates select="m:phenomSpec[position()>1]" mode="combined"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="@s"/>
     </xsl:otherwise>
    </xsl:choose>
    <xsl:if test="boolean(m:inVicinity)">
     <xsl:value-of select="concat(' ', $trans/t:locationSpec[@o='inVicinity'])"/>
    </xsl:if>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:phenomSpec" mode="combined">
  <xsl:choose>
   <xsl:when test="position() > 1 or ../m:descriptor/@v = 'TS'">
    <xsl:value-of select="$trans/t:t[@o='combined_phenom2']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:t[@o='combined_phenom1']"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:variable name="w_combined" select="$trans/t:weather_combined[@o=current()/@v]"/>
  <xsl:variable name="w_orig" select="$trans/t:weather[@o=current()/@v]"/>
  <xsl:choose>
   <xsl:when test="$w_combined != ''">
    <xsl:value-of select="concat(substring-before($w_combined,  '|'), substring-after($w_combined, '|'))"/>
   </xsl:when>
   <xsl:when test="$w_orig != ''">
    <xsl:value-of select="concat(substring-before($w_orig,  '|'), substring-after($w_orig, '|'))"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="@v"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:natId">
  <xsl:if test="position() != 1">/</xsl:if>
  <xsl:value-of select="concat(m:natStationId/@v, '-', m:countryId/@v)"/>
 </xsl:template>

 <xsl:template match="m:descriptor|m:phenomSpec|m:text|m:id">
  <xsl:value-of select="@v"/>
 </xsl:template>

 <xsl:template match="m:cloudBase|m:cloudBaseFrom|m:cloudBaseTo|m:distance|m:layerBase|m:layerTop|m:layerThickness" mode="metaf_alt">
  <xsl:choose>
   <xsl:when test="@u = 'M'">
    <xsl:call-template name="unitConverter">
     <xsl:with-param name="val" select="."/>
     <xsl:with-param name="unit" select="'FT'"/>
     <xsl:with-param name="factor" select="0.3 div $FT2M"/>
     <xsl:with-param name="format" select="'0'"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:otherwise>
    <xsl:call-template name="unitConverter">
     <xsl:with-param name="val" select="."/>
     <xsl:with-param name="unit" select="'M'"/>
     <xsl:with-param name="factor" select="$FT2M div 0.3"/>
     <xsl:with-param name="format" select="'0'"/>
    </xsl:call-template>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <!-- combine all cloud nodes into one set and process them in one go -->
 <xsl:template match="m:cloud">
  <xsl:apply-templates select="../m:cloud" mode="go"/>
 </xsl:template>

 <xsl:template match="m:cloud" mode="go">
  <xsl:choose>
   <xsl:when test="position() = 1">
    <xsl:variable name="ceiling" select="../m:cloud[boolean(m:isCeiling)]"/>
    <xsl:variable name="s">
     <xsl:apply-templates select="../m:cloud" mode="concat_s"/>
    </xsl:variable>
    <xsl:variable name="rows" select="last()"/>
    <tr>
    <xsl:call-template name="src_string">
     <xsl:with-param name="rows">
      <xsl:choose>
       <xsl:when test="boolean($ceiling)">
        <xsl:value-of select="$rows + 1"/>
       </xsl:when>
       <xsl:otherwise>
        <xsl:value-of select="$rows"/>
       </xsl:otherwise>
      </xsl:choose>
     </xsl:with-param>
     <xsl:with-param name="s" select="substring($s, 2)"/>
    </xsl:call-template>
    <xsl:choose>
     <xsl:when test="boolean($ceiling)">
      <xsl:call-template name="hdr_string">
       <xsl:with-param name="hdr_name" select="'ceiling'"/>
       <xsl:with-param name="derived" select="$ceiling/m:isCeiling/@q = 'M2Xderived'"/>
      </xsl:call-template>
      <td nowrap="1">
      <xsl:if test="m:cloudBase/@q = 'isEstimated'">
       <xsl:value-of select="substring-before($trans/t:t[@o='isEstimated'], '|')"/>
      </xsl:if>
      <xsl:value-of select="concat($trans/t:t[@o='cloud-at'], ' ')"/>
      <xsl:call-template name="unitConverter">
       <xsl:with-param name="val" select="$ceiling/m:cloudBase"/>
      </xsl:call-template>
      <xsl:if test="m:cloudBase/@q = 'isEstimated'">
       <xsl:value-of select="substring-after($trans/t:t[@o='isEstimated'], '|')"/>
      </xsl:if>
      </td>
      &tab4;
      <td nowrap="1">
      <xsl:apply-templates select="$ceiling/m:cloudBase" mode="metaf_alt"/>
      </td>
     </xsl:when>
     <xsl:otherwise>
      <xsl:call-template name="hdr_string">
       <xsl:with-param name="rows" select="$rows"/>
      </xsl:call-template>
      <xsl:call-template name="printCloud"/>
     </xsl:otherwise>
    </xsl:choose>
    </tr>&nl;
    <xsl:if test="boolean($ceiling)">
     <tr>
     <xsl:call-template name="hdr_string">
      <xsl:with-param name="rows" select="$rows"/>
     </xsl:call-template>
     <xsl:call-template name="printCloud"/>
     </tr>&nl;
    </xsl:if>
   </xsl:when>
   <xsl:otherwise>
    <tr>
    &tab3;
    <xsl:call-template name="printCloud"/>
    </tr>&nl;
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:cloudCover|m:cloudCover2|m:noClouds">
  <xsl:if test="@q = 'isThin'">
   <xsl:value-of select="substring-before($trans/t:t[@o='thinLayer'], '|')"/>
  </xsl:if>
  <xsl:value-of select="$trans/t:cloudCover[@o=current()/@v]"/>
  <xsl:if test="@q = 'isThin'">
   <xsl:value-of select="substring-after($trans/t:t[@o='thinLayer'], '|')"/>
  </xsl:if>
 </xsl:template>

 <xsl:template name="printCloud">
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable|m:invalidFormat|m:noClouds)">
    <td nowrap="1" colspan="2">
    <xsl:apply-templates select="m:notAvailable|m:invalidFormat|m:noClouds"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <td nowrap="1">
     <xsl:if test="not(boolean(m:cloudBase))">
      <xsl:attribute name="colspan">2</xsl:attribute>
     </xsl:if>
     <xsl:apply-templates select="m:cloudCover"/>
     <xsl:if test="boolean(m:cloudCoverNotAvailable)">
      <xsl:value-of select="$trans/t:phenomenon[@o='CLDS']"/>
     </xsl:if>
     <xsl:if test="boolean(m:cloudBase)">
      <xsl:if test="m:cloudBase/@q = 'isEstimated'">
       <xsl:value-of select="substring-before($trans/t:t[@o='isEstimated'], '|')"/>
      </xsl:if>
      <xsl:value-of select="concat(' ', $trans/t:t[@o='cloud-at'], ' ')"/>
      <xsl:call-template name="unitConverter">
       <xsl:with-param name="val" select="m:cloudBase"/>
      </xsl:call-template>
     </xsl:if>
      <xsl:if test="m:cloudBase/@q = 'isEstimated'">
       <xsl:value-of select="substring-after($trans/t:t[@o='isEstimated'], '|')"/>
      </xsl:if>
     <xsl:if test="boolean(m:cloudBaseNotAvailable)">
      <xsl:value-of select="concat(', ', $trans/t:t[@o='cloudBaseNotAvailable'])"/>
     </xsl:if>
     <xsl:if test="boolean(m:cloudType)">
      <br />
      <xsl:value-of select="concat(' (', $trans/t:cloudType[@o=current()/m:cloudType/@v])"/>
      <xsl:apply-templates select="m:locationAnd">
       <xsl:with-param name="locOrDir" select="'compassDirLocation'"/>
      </xsl:apply-templates>
      <xsl:text>)</xsl:text>
     </xsl:if>
     <xsl:if test="boolean(m:cloudTypeNotAvailable)">
      <xsl:value-of select="concat(' ', $trans/t:t[@o='cloudTypeNotAvailable'])"/>
     </xsl:if>
    </td>
    <xsl:if test="boolean(m:cloudBase)">
     &tab3;
     <td nowrap="1">
     <xsl:apply-templates select="m:cloudBase" mode="metaf_alt"/>
     </td>
    </xsl:if>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:temperature">
  <xsl:variable name="rows" select="count(m:invalidFormat|m:air|m:dewpoint|m:relHumid1)"/>
  <xsl:if test="boolean(m:invalidFormat)">
   <tr>
   &src_string;
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'temperature-temp'"/>
   </xsl:call-template>
   <td nowrap="1" colspan="2">
   <xsl:apply-templates select="m:invalidFormat"/>
   </td>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:air)">
   <tr>
   <xsl:call-template name="printTemp">
    <xsl:with-param name="hdr" select="$trans/t:hdr[@o='temperature-temp']"/>
    <xsl:with-param name="rows" select="$rows"/>
    <xsl:with-param name="s" select="@s"/>
    <xsl:with-param name="temp" select="m:air"/>
   </xsl:call-template>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:dewpoint)">
   <tr>
   <xsl:choose>
    <xsl:when test="boolean(m:air)">
     <xsl:call-template name="printTemp">
      <xsl:with-param name="hdr" select="$trans/t:hdr[@o='temperature-dew']"/>
      <xsl:with-param name="temp" select="m:dewpoint"/>
     </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
     <xsl:call-template name="printTemp">
      <xsl:with-param name="hdr" select="$trans/t:hdr[@o='temperature-dew']"/>
      <xsl:with-param name="rows" select="$rows"/>
      <xsl:with-param name="s" select="@s"/>
      <xsl:with-param name="temp" select="m:dewpoint"/>
     </xsl:call-template>
    </xsl:otherwise>
   </xsl:choose>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:relHumid1)">
   <tr>
    <xsl:if test="not(boolean(m:air)) and not(boolean(m:dewpoint))">
     &src_string;
    </xsl:if>
    <xsl:call-template name="hdr_string">
     <xsl:with-param name="hdr_name" select="'relHumid'"/>
     <xsl:with-param name="derived" select="m:relHumid1/@q = 'M2Xderived'"/>
    </xsl:call-template>
    <td nowrap="1" colspan="2">
    <xsl:value-of select="format-number(m:relHumid1/@v, '0')"/>
    <xsl:text> %</xsl:text>
    </td>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:tempAt|m:SST|m:OAT|m:tempMaxFQ|m:tempCity">
  <tr>
  <xsl:call-template name="printTemp">
   <xsl:with-param name="hdr" select="$trans/t:hdr[@o=name(current())]"/>
   <xsl:with-param name="s" select="@s"/>
   <xsl:with-param name="temp" select="."/>
  </xsl:call-template>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:tempMaxAt|m:tempMinAt|m:tempMax|m:tempMin|m:tempExtremeMax|m:tempExtremeMin|m:tempMaxDaytime|m:tempMinNighttime|m:tempCityMax|m:tempCityMin|m:waterTemp|m:tempMinGround|m:tempGround|m:soilTemp|m:soilTempMin">
  <tr>
  <xsl:variable name="hdr" select="$trans/t:hdr[@o=name(current())]"/>
  <xsl:call-template name="printTemp">
   <xsl:with-param name="hdr">
    <xsl:value-of select="substring-before($hdr, '|')"/>
    <xsl:if test="boolean(m:depth)">
     <xsl:value-of select="concat(' ', substring-before($trans/t:t[@o='atDepth'], '|'), m:depth/@v, $trans/t:units[@o=current()/m:depth/@u], substring-after($trans/t:t[@o='atDepth'], '|'))"/>
    </xsl:if>
    <xsl:if test="boolean(m:sensorHeight)">
     <xsl:value-of select="concat(' ', substring-before($trans/t:t[@o='atHeight'], '|'), m:sensorHeight/@v, $trans/t:units[@o=current()/m:sensorHeight/@u], substring-after($trans/t:t[@o='atHeight'], '|'))"/>
    </xsl:if>
    <xsl:apply-templates select="m:timePeriod|m:timeBeforeObs">
     <xsl:with-param name="pre" select="' '"/>
    </xsl:apply-templates>
    <xsl:value-of select="substring-after($hdr, '|')"/>
   </xsl:with-param>
   <xsl:with-param name="s" select="@s"/>
   <xsl:with-param name="temp" select="."/>
  </xsl:call-template>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:tempExtreme">
  <xsl:variable name="hdrMax" select="$trans/t:hdr[@o='tempMax']"/>
  <xsl:variable name="hdrMin" select="$trans/t:hdr[@o='tempMin']"/>
  <tr>
  <xsl:call-template name="printTemp">
   <xsl:with-param name="hdr">
    <xsl:apply-templates select="m:tempExtremeMax/m:timeBeforeObs">
     <xsl:with-param name="pre" select="' '"/>
     <xsl:with-param name="header" select="$hdrMax"/>
    </xsl:apply-templates>
    <xsl:if test="boolean(m:tempExtremeMax/m:notAvailable)">
     <xsl:value-of select="concat(substring-before($hdrMax, '|'), substring-after($hdrMax, '|'))"/>
    </xsl:if>
   </xsl:with-param>
   <xsl:with-param name="rows" select="2"/>
   <xsl:with-param name="s" select="@s"/>
   <xsl:with-param name="temp" select="m:tempExtremeMax"/>
  </xsl:call-template>
  </tr>&nl;
  <tr>
  <xsl:call-template name="printTemp">
   <xsl:with-param name="hdr">
    <xsl:apply-templates select="m:tempExtremeMin/m:timeBeforeObs">
     <xsl:with-param name="pre" select="' '"/>
     <xsl:with-param name="header" select="$hdrMin"/>
    </xsl:apply-templates>
    <xsl:if test="boolean(m:tempExtremeMin/m:notAvailable)">
     <xsl:value-of select="concat(substring-before($hdrMin, '|'), substring-after($hdrMin, '|'))"/>
    </xsl:if>
   </xsl:with-param>
   <xsl:with-param name="temp" select="m:tempExtremeMin"/>
  </xsl:call-template>
  </tr>&nl;
 </xsl:template>

 <xsl:template name="printTemp">
  <xsl:param name="hdr"/>
  <xsl:param name="notavail"/>
  <xsl:param name="rows"/>
  <xsl:param name="s"/>
  <xsl:param name="temp"/>
  <xsl:param name="offsetValidFrom"/>
  <xsl:if test="$s != ''">
   <xsl:call-template name="src_string">
    <xsl:with-param name="rows" select="$rows"/>
    <xsl:with-param name="s" select="$s"/>
   </xsl:call-template>
  </xsl:if>
  <xsl:if test="$hdr != ''">
   <td nowrap="1">
   <xsl:value-of select="$hdr"/>
   </td>
  </xsl:if>
  <xsl:choose>
   <xsl:when test="boolean($temp/m:notAvailable)">
    <td nowrap="1" colspan="2">
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <td nowrap="1">
    <xsl:choose>
     <xsl:when test="$temp/m:temp/@u = 'C'">
      <xsl:value-of select="$temp/m:temp/@v"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="format-number(($temp/m:temp/@v - 32) div 1.8, '0.0')"/>
     </xsl:otherwise>
    </xsl:choose>
    <xsl:text> °C</xsl:text>
    <xsl:apply-templates select="$temp/m:timeAt">
     <xsl:with-param name="pre" select="' '"/>
    </xsl:apply-templates>
    <xsl:if test="$offsetValidFrom != ''">
     <xsl:apply-templates select="ancestor::m:taf/m:fcstPeriod/m:timeFrom">
      <xsl:with-param name="name" select="'timeAt'"/>
      <xsl:with-param name="pre" select="' '"/>
     </xsl:apply-templates>
     <xsl:value-of select="concat(' + ', $offsetValidFrom, $trans/t:units[@o='H'])"/>
    </xsl:if>
    </td>
    <xsl:choose>
     <xsl:when test="boolean($temp/m:timeAt)">
      &tab3;
     </xsl:when>
     <xsl:otherwise>
      &tab5;
     </xsl:otherwise>
    </xsl:choose>
    <td nowrap="1">
    <xsl:choose>
     <xsl:when test="$temp/m:temp/@u = 'C'">
      <!--select="format-number($temp/m:temp/@v * 1.8 + 32, '0.#')"/-->
      <xsl:value-of select="format-number(floor(10 * ($temp/m:temp/@v * 1.8 + 32 + 0.05)) div 10, '0.0')"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="$temp/m:temp/@v"/>
     </xsl:otherwise>
    </xsl:choose>
    <xsl:text> °F</xsl:text>
    </td>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:QNH|m:stationPressure|m:SLP|m:regQNH|m:QFE|m:QFF|m:QNH_fcst|m:minQNH">
  <xsl:variable name="rows" select="count(m:pressure)"/>
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable|m:invalidFormat)">
    <td nowrap="1" colspan="2">
    <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <xsl:apply-templates select="m:pressure[1]">
     <xsl:with-param name="offsetValidFrom">
      <xsl:if test="name() = 'QNH_fcst'">0</xsl:if>
     </xsl:with-param>
    </xsl:apply-templates>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
  <xsl:for-each select="m:pressure[position() > 1]">
   <tr>
   &tab3;
   <xsl:apply-templates select=".">
    <xsl:with-param name="offsetValidFrom">
     <xsl:if test="name(..) = 'QNH_fcst'">
      <xsl:value-of select="position() * 3"/>
     </xsl:if>
    </xsl:with-param>
   </xsl:apply-templates>
   </tr>&nl;
  </xsl:for-each>
 </xsl:template>

 <xsl:template match="m:pressure">
  <xsl:param name="offsetValidFrom"/>
  <td nowrap="1">
  <xsl:if test="@q = 'isEstimated'">
   <xsl:value-of select="substring-before($trans/t:t[@o='isEstimated'], '|')"/>
  </xsl:if>
  <xsl:value-of select="concat(@v, $trans/t:units[@o=current()/@u])"/>
  <xsl:if test="@q = 'isEstimated'">
   <xsl:value-of select="substring-after($trans/t:t[@o='isEstimated'], '|')"/>
  </xsl:if>
  <xsl:if test="$offsetValidFrom != ''">
   <xsl:apply-templates select="ancestor::m:taf/m:fcstPeriod/m:timeFrom">
    <xsl:with-param name="name" select="'timeAt'"/>
    <xsl:with-param name="pre" select="' '"/>
   </xsl:apply-templates>
   <xsl:value-of select="concat(' + ', $offsetValidFrom, $trans/t:units[@o='H'])"/>
  </xsl:if>
  </td>
  &tab4;
  <td nowrap="1">
  <xsl:choose>
   <xsl:when test="@u = 'hPa'">
    <xsl:value-of select="concat(format-number(@v div $INHG2HPA, '0.00'), $trans/t:units[@o='inHg'], ' = ', format-number(@v div $INHG2HPA * ($FT2M div 12 * 1000), '0'), $trans/t:units[@o='mmHg'])"/>
   </xsl:when>
   <xsl:when test="@u = 'inHg'">
    <xsl:value-of select="concat(format-number(@v * $INHG2HPA, '0'), $trans/t:units[@o='hPa'], ' = ', format-number(@v * ($FT2M div 12 * 1000), '0'), $trans/t:units[@o='mmHg'])"/>
   </xsl:when>
   <xsl:when test="@u = 'mmHg'">
    <xsl:value-of select="concat(format-number(@v div ($FT2M div 12 * 1000) * $INHG2HPA, '0'), $trans/t:units[@o='hPa'], ' = ', format-number(@v div ($FT2M div 12 * 1000), '0.00'), $trans/t:units[@o='inHg'])"/>
   </xsl:when>
  </xsl:choose>
  </td>
 </xsl:template>

 <xsl:template match="m:cloudMaxCover">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:cloudCover|m:noClouds"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:cloudAbove">
  <tr>
  &src_string;
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'cloudLayer'"/>
  </xsl:call-template>
  <xsl:call-template name="printCloud"/>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:cloudCoverVar">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="2"/>
  </xsl:call-template>
  &hdr_string;
  <xsl:choose>
   <xsl:when test="boolean(m:cloudBase)">
    <xsl:call-template name="printCloud"/>
   </xsl:when>
   <xsl:otherwise>
   <td nowrap="1" colspan="2">
   <xsl:apply-templates select="m:cloudCover"/>
   </td>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
  <tr>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'cloudCoverVar2'"/>
  </xsl:call-template>
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:cloudCover2"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:reportConcerns">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:variable name="chg" select="$trans/t:concernsChange[@o=current()/m:change/@v]"/>
  <xsl:value-of select="concat(substring-before($chg, '|'), $trans/t:concernsSubject[@o=current()/m:subject/@v], substring-after($chg, '|'))"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:cloudOpacityLvl">
 <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1">
  <xsl:apply-templates select="m:oktas"/>
  <xsl:if test="boolean(m:weather)">
   <xsl:text> </xsl:text>
   <xsl:for-each select="m:weather">
    <xsl:call-template name="printWeather"/>
   </xsl:for-each>
  </xsl:if>
  <xsl:if test="boolean(m:cloudType)">
   <xsl:value-of select="concat(' ', $trans/t:cloudType[@o=current()/m:cloudType/@v])"/>
  </xsl:if>
  <xsl:value-of select="concat(' ', $trans/t:t[@o='cloud-at'], ' ')"/>
  <xsl:call-template name="unitConverter">
   <xsl:with-param name="val" select="m:cloudBase"/>
  </xsl:call-template>
  <xsl:apply-templates select="m:locationAnd">
   <xsl:with-param name="locOrDir" select="'compassDirLocation'"/>
  </xsl:apply-templates>
  </td>
  &tab2;
  <td nowrap="1">
  <xsl:apply-templates select="m:cloudBase" mode="metaf_alt"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:RH">
  <tr>
  &src_string;
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'relHumid'"/>
  </xsl:call-template>
  <td nowrap="1" colspan="2">
  <xsl:value-of select="m:relHumid/@v"/>
  <xsl:text> %</xsl:text>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:AI">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
   <xsl:value-of select="m:AIVal/@v"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:rwyState">
  <tr>
  &src_string;
  <xsl:choose>
   <xsl:when test="boolean(m:SNOCLO)">
    <td nowrap="1" colspan="3">
    <xsl:value-of select="$trans/t:t[@o='SNOCLO']"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <td nowrap="1">
    <xsl:choose>
     <xsl:when test="boolean(m:rwyDesigAll)">
      <xsl:value-of select="substring-before($trans/t:hdr[@o='stateOfRwy'], '|')"/>
      <xsl:value-of select="$trans/t:t[@o='rwyDesigAll']"/>
      <xsl:value-of select="substring-after($trans/t:hdr[@o='stateOfRwy'], '|')"/>
     </xsl:when>
     <xsl:when test="boolean(m:rwyReportRepeated)">
      <xsl:value-of select="$trans/t:hdr[@o='rwyReportRepeated']"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="substring-before($trans/t:hdr[@o='stateOfRwy'], '|')"/>
      <xsl:apply-templates select="m:rwyDesig"/>
      <xsl:value-of select="substring-after($trans/t:hdr[@o='stateOfRwy'], '|')"/>
     </xsl:otherwise>
    </xsl:choose>
    </td>
    <td colspan="2">
    <xsl:choose>
     <xsl:when test="boolean(m:depositType/m:notAvailable) and boolean(m:depositExtent/m:notAvailable) and boolean(m:depositDepth/m:notAvailable) and boolean(m:friction/m:notAvailable)">
      <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
     </xsl:when>

     <xsl:otherwise>

      <xsl:if test="boolean(m:cleared)">
       <xsl:value-of select="$trans/t:t[@o='cleared']"/>
      </xsl:if>

      <xsl:if test="boolean(m:invalidFormat)">
       <xsl:apply-templates select="m:invalidFormat"/>
      </xsl:if>

      <xsl:variable name="delim1">
       <xsl:if test="boolean(m:cleared)">, </xsl:if>
      </xsl:variable>
      <xsl:if test="boolean(m:depositType/m:depositTypeVal)">
       <xsl:value-of select="$delim1"/>
       <xsl:value-of select="$trans/t:depositType[@o=current()/m:depositType/m:depositTypeVal/@v]"/>
      </xsl:if>

      <xsl:variable name="delim2">
       <xsl:if test="$delim1 != '' or boolean(m:depositType/m:depositTypeVal)">, </xsl:if>
      </xsl:variable>
      <xsl:apply-templates select="m:depositExtent/m:invalidFormat">
       <xsl:with-param name="s" select="$delim2"/>
      </xsl:apply-templates>
      <xsl:if test="boolean(m:depositExtent/m:depositExtentVal)">
       <xsl:value-of select="$delim2"/>
       <xsl:value-of select="substring-before($trans/t:depositExtent[@o=current()/m:depositExtent/m:depositExtentVal/@v], '|')"/>
       <xsl:value-of select="$trans/t:t[@o='depositExtent']"/>
       <xsl:value-of select="substring-after($trans/t:depositExtent[@o=current()/m:depositExtent/m:depositExtentVal/@v], '|')"/>
      </xsl:if>

      <xsl:variable name="delim3">
       <xsl:if test="$delim2 != '' or boolean(m:depositExtent/m:invalidFormat|m:depositExtent/m:depositExtentVal)">, </xsl:if>
      </xsl:variable>
      <xsl:apply-templates select="m:depositDepth/m:invalidFormat">
       <xsl:with-param name="s" select="$delim3"/>
      </xsl:apply-templates>
      <xsl:if test="boolean(m:depositDepth/m:depositDepthVal)">
       <xsl:value-of select="$delim3"/>
       <xsl:value-of select="substring-before($trans/t:t[@o='depositDepth'], '|')"/>
       <xsl:call-template name="unitConverter">
        <xsl:with-param name="val" select="m:depositDepth/m:depositDepthVal"/>
       </xsl:call-template>
       <xsl:value-of select="substring-after($trans/t:t[@o='depositDepth'], '|')"/>
      </xsl:if>
      <xsl:if test="boolean(m:depositDepth/m:rwyNotInUse)">
       <xsl:value-of select="$delim3"/>
       <xsl:value-of select="$trans/t:t[@o='rwyNotInUse']"/>
      </xsl:if>
      <xsl:variable name="delim4">
       <xsl:if test="$delim3 != '' or boolean(m:depositDepth/m:invalidFormat|m:depositDepth/m:depositDepthVal|m:depositDepth/m:rwyNotInUse)">, </xsl:if>
      </xsl:variable>
      <xsl:apply-templates select="m:friction/m:invalidFormat">
       <xsl:with-param name="s" select="$delim4"/>
      </xsl:apply-templates>
      <xsl:if test="boolean(m:friction/m:coefficient)">
       <xsl:value-of select="concat($delim4, $trans/t:t[@o='friction'], m:friction/m:coefficient/@v)"/>
      </xsl:if>
      <xsl:if test="boolean(m:friction/m:brakingAction)">
       <xsl:value-of select="concat($delim4, $trans/t:t[@o=current()/m:friction/m:brakingAction/@v])"/>
      </xsl:if>
      <xsl:if test="boolean(m:friction/m:unreliable)">
       <xsl:value-of select="concat($delim4, $trans/t:t[@o='frictionUnreliable'])"/>
      </xsl:if>
     </xsl:otherwise>
    </xsl:choose>
    </td>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:windShear">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:value-of select="substring-before($trans/t:hdr[@o='windShearRwy'], '|')"/>
  <xsl:choose>
   <xsl:when test="boolean(m:rwyDesigAll)">
    <xsl:value-of select="$trans/t:t[@o='rwyDesigAll']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:apply-templates select="m:rwyDesig"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:value-of select="substring-after($trans/t:hdr[@o='windShearRwy'], '|')"/>
  </td>
  <td nowrap="1" colspan="2">
  <xsl:value-of select="$trans/t:t[@o='windShear']"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:colourCode">
  <xsl:variable name="rows">
   <xsl:choose>
    <xsl:when test="boolean(m:BLACK) and boolean(m:currentColour) and boolean(m:predictedColour)">3</xsl:when>
    <xsl:when test="boolean(m:BLACK) and boolean(m:currentColour)">2</xsl:when>
    <xsl:when test="boolean(m:currentColour) and boolean(m:predictedColour)">2</xsl:when>
   </xsl:choose>
  </xsl:variable>
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <td nowrap="1" colspan="2">
  <xsl:choose>
   <xsl:when test="boolean(m:BLACK)">
    <xsl:value-of select="$trans/t:colour[@o='BLACK']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:colour[@o=current()/m:currentColour/@v]"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
  <xsl:if test="boolean(m:currentColour) and boolean(m:BLACK)">
   <tr>
   &tab3;
   <td nowrap="1" colspan="2">
   <xsl:value-of select="$trans/t:colour[@o=current()/m:currentColour/@v]"/>
   </td>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:predictedColour)">
   <tr>
   &tab3;
   <td nowrap="1" colspan="2">
   <xsl:value-of select="$trans/t:t[@o='predictedColour']"/>
   <br />
   <xsl:if test="$method != 'html'">&nl;&tab3;</xsl:if>
   <xsl:choose>
    <xsl:when test="m:currentColour/@v != m:predictedColour/@v">
     <xsl:value-of select="$trans/t:colour[@o=current()/m:predictedColour/@v]"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="$trans/t:colour[@o='noChange']"/>
    </xsl:otherwise>
   </xsl:choose>
   </td>
  </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:windShearLvl">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="2"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="rows" select="2"/>
  </xsl:call-template>
  <td nowrap="1">
  <xsl:value-of select="concat($trans/t:t[@o='layerTop'], ' ', m:level/@v * 100, $trans/t:units[@o='FT'])"/>
  </td>
  &tab3;
  <td nowrap="1">
  <xsl:value-of select="concat(format-number(m:level/@v * 10 * $FT2M, '0') * 10, $trans/t:units[@o='M'])"/>
  </td>
  </tr>&nl;
  <tr>
  &tab3;
  <xsl:call-template name="printSpeed">
   <xsl:with-param name="dir">
    <xsl:apply-templates select="m:wind/m:dir">
     <xsl:with-param name="hdr" select="'wind-from'"/>
    </xsl:apply-templates>
   </xsl:with-param>
   <xsl:with-param name="speed" select="m:wind/m:speed"/>
   <xsl:with-param name="delim" select="'&#9;&#9;'"/>
  </xsl:call-template>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:turbulence|m:icing">
  <xsl:variable name="rows" select="count(m:layerBase|m:timeFrom) + 2"/>
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <td nowrap="1" colspan="2">
  <xsl:value-of select="$trans/t:turbulenceDescr[@o=current()/m:turbulenceDescr/@v]"/>
  <xsl:choose>
   <xsl:when test="m:icingDescr/@v = 'TR'">
    <xsl:value-of select="$trans/t:t[@o='precipTraces']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:icingDescr[@o=current()/m:icingDescr/@v]"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
  <xsl:if test="boolean(m:timeFrom)">
   <tr>
   &tab3;
   <td nowrap="1" colspan="2">
   <xsl:apply-templates select="m:timeFrom|m:timeTill"/>
   </td>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:layerBase)">
   <tr>
   &tab3;
   <td nowrap="1">
   <xsl:value-of select="$trans/t:hdr[@o='layerBase']"/>
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:layerBase"/>
   </xsl:call-template>
   </td>
   &tab3;
   <td nowrap="1">
   <xsl:apply-templates select="m:layerBase" mode="metaf_alt"/>
   </td>
   </tr>&nl;
  </xsl:if>
  <tr>
  &tab3;
  <xsl:choose>
   <xsl:when test="boolean(m:layerTop)">
    <td nowrap="1">
    <xsl:value-of select="$trans/t:t[@o='layerTop']"/>
    <xsl:text>:&#9;</xsl:text>
    <xsl:call-template name="unitConverter">
     <xsl:with-param name="val" select="m:layerTop"/>
    </xsl:call-template>
    </td>
    &tab3;
    <td nowrap="1">
    <xsl:apply-templates select="m:layerTop" mode="metaf_alt"/>
    </td>
   </xsl:when>
   <xsl:when test="boolean(m:layerThickness)">
    <td nowrap="1">
    <xsl:value-of select="$trans/t:hdr[@o='layerThickness']"/>
    <xsl:call-template name="unitConverter">
     <xsl:with-param name="val" select="m:layerThickness"/>
    </xsl:call-template>
    </td>
    &tab3;
    <td nowrap="1">
    <xsl:apply-templates select="m:layerThickness" mode="metaf_alt"/>
   </td>
   </xsl:when>
   <xsl:otherwise>
    <td nowrap="1" colspan="2">
    <xsl:value-of select="$trans/t:t[@o='toTopOfCloud']"/>
    </td>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:amendment">
  <tr>
  &src_string;
  <td nowrap="1" colspan="3">
  <xsl:value-of select="concat($trans/t:t[@o='amendment'], ' ')"/>
  <xsl:choose>
   <xsl:when test="boolean(m:isNotScheduled)">
    <xsl:value-of select="$trans/t:t[@o='isNotScheduled']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:t[@o='isLtdToCldVisWind']"/>
    <xsl:apply-templates select="m:timeFrom|m:timeTill">
     <xsl:with-param name="pre" select="' '"/>
    </xsl:apply-templates>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:issuedBy">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:value-of select="m:id/@v"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <!-- combine all trend nodes into one set and process them in one go -->
 <xsl:template match="m:trend">
  <xsl:apply-templates select="../m:trend" mode="go"/>
 </xsl:template>

 <xsl:template match="m:trend" mode="go">
  <xsl:if test="position() = 1">
   &nl;
   <tr>
   <td></td>
   <td nowrap="1" colspan="3"><b>
   <xsl:if test="name(..) = 'metar'">
    <xsl:value-of select="$trans/t:hdr[@o='trend']"/>
   </xsl:if>
   <xsl:if test="name(..) != 'metar'">
    <xsl:value-of select="$trans/t:hdr[@o='trendTAF']"/>
   </xsl:if>
   <xsl:if test="$method != 'html'">
    &nl;
    <xsl:choose>
     <xsl:when test="name(..) = 'metar'">
      <xsl:value-of select="$trans/t:hdr[@o='trend_ul']"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="$trans/t:hdr[@o='trendTAF_ul']"/>
     </xsl:otherwise>
    </xsl:choose>
   </xsl:if>
   </b></td>
   </tr>&nl;
  </xsl:if>
  <tr>
  &src_string;
  <xsl:if test="position() != 1">
   &nl;
  </xsl:if>
  <td nowrap="1" colspan="3">
  <xsl:choose>
   <xsl:when test="m:trendType/@v = 'NOSIG'">
    <xsl:value-of select="$trans/t:t[@o='NOSIG']"/>
   </xsl:when>
   <xsl:otherwise>
    <b>
    <xsl:if test="boolean(m:probability)">
     <xsl:value-of select="concat(substring-before($trans/t:t[@o='prob'], '|'), m:probability/@v, substring-after($trans/t:t[@o='prob'], '|'))"/>
    </xsl:if>
    <xsl:apply-templates select="m:timeAt|m:timeFrom|m:timeTill">
     <xsl:with-param name="pre">
      <xsl:if test="boolean(m:probability)"><xsl:text> </xsl:text></xsl:if>
     </xsl:with-param>
    </xsl:apply-templates>
    <xsl:if test="m:trendType/@v != 'FM'">
     <xsl:if test="boolean(m:probability|m:timeAt|m:timeFrom|m:timeTill)">
      <xsl:text> </xsl:text>
     </xsl:if>
     <xsl:value-of select="$trans/t:t[@o=current()/m:trendType/@v]"/>
    </xsl:if>
    <xsl:text>:</xsl:text>
    </b>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
  <xsl:apply-templates select="m:sfcWind|m:CAVOK|m:visPrev|m:weather[1]|m:cloud[1]|m:visVert|m:colourCode|m:turbulence|m:icing|m:windShearLvl|m:windShearConds|m:minQNH|m:obscuration|m:VA_fcst"/>
  <xsl:if test="position() = last() and boolean(following-sibling::*) and not(boolean(following-sibling::m:remark)) and not(boolean(following-sibling::m:tafRemark))">
   &nl;
   <tr><td/><td colspan="3"><hr/></td></tr>
  </xsl:if>
 </xsl:template>

 <!-- combine all tafRemark nodes into one set and process them in one go -->
 <xsl:template match="m:tafRemark">
  <xsl:apply-templates select="../m:tafRemark" mode="go"/>
 </xsl:template>

 <xsl:template match="m:tafRemark" mode="go">
  <xsl:if test="position() = 1">
   &nl;
   <tr>
   <xsl:if test="$method = 'html'">
    <td><b>RMK</b></td>
   </xsl:if>
   <td nowrap="1" colspan="3"><b>
    <xsl:value-of select="$trans/t:hdr[@o='remark']"/>
    <xsl:if test="$method != 'html'">
     &nl;
     <xsl:value-of select="$trans/t:hdr[@o='remark_ul']"/>
    </xsl:if>
   </b></td>
   </tr>&nl;
  </xsl:if>
  <xsl:apply-templates select="*"/>
 </xsl:template>

 <!-- combine all remark nodes into one set and process them in one go -->
 <xsl:template match="m:remark">
  &nl;
  <tr>
  <xsl:if test="$method = 'html'">
   <td><b>RMK</b></td>
  </xsl:if>
  <td nowrap="1" colspan="3"><b>
   <xsl:value-of select="$trans/t:hdr[@o='remark']"/>
   <xsl:if test="$method != 'html'">
    &nl;
    <xsl:value-of select="$trans/t:hdr[@o='remark_ul']"/>
   </xsl:if>
  </b></td>
  </tr>&nl;
  <xsl:apply-templates select="../m:remark" mode="go"/>
 </xsl:template>

 <xsl:template match="m:remark" mode="go">
  <xsl:variable name="rmk" select="name(child::*[last()])"/>
  <xsl:choose>
   <xsl:when test="$rmk = 'cloud'">
    <xsl:apply-templates select="m:cloud">
     <xsl:with-param name="s_list" select="m:cloud/@s"/>
    </xsl:apply-templates>
   </xsl:when>
   <xsl:when test="$rmk = 'visRwy'">
    <xsl:apply-templates select="m:visRwy"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:apply-templates select="child::*[last()]"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:ERROR">
  <tr>
  <td class="msg" colspan="4">
  <xsl:value-of select="concat($trans/t:hdr[@o='ERROR'], $trans/t:error[@o=current()/@errorType], ': ', @s)"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:warning">
  <tr>
  <td class="msg" colspan="4">
  <xsl:value-of select="$trans/t:hdr[@o='warning']"/>
  <xsl:choose>
   <xsl:when test="@s != ''">
    <xsl:value-of select="substring-before($trans/t:warning[@o=current()/@warningType], '|')"/>
    <xsl:if test="$method != 'html' and @warningType = 'msgModified'">
     <xsl:text>     </xsl:text>
    </xsl:if>
    <xsl:value-of select="concat(@s, substring-after($trans/t:warning[@o=current()/@warningType], '|'))"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:warning[@o=current()/@warningType]"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:invalidFormat">
  <xsl:param name="s"/>
  <xsl:value-of select="concat($s, '(', $trans/t:t[@o='invalidFormat'])"/>
  <xsl:text>: '</xsl:text>
  <xsl:value-of select="@v"/>
  <xsl:text>')</xsl:text>
 </xsl:template>

 <xsl:template match="m:reportModifier|m:CAVOK|m:RVRNO|m:needMaint|m:fcstAutoMETAR|m:fcstCancelled">
  <xsl:variable name="name" select="name()"/>
  <tr>
  <xsl:if test="$method = 'html'">
   <td nowrap="1"><b>
   <xsl:choose>
    <xsl:when test="boolean(@s)">
     <xsl:value-of select="@s"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="$name"/>
    </xsl:otherwise>
   </xsl:choose>
   </b></td>
  </xsl:if>
  <td colspan="3">
  <xsl:choose>
   <xsl:when test="name() = 'reportModifier'">
    <xsl:value-of select="$trans/t:reportModifierType[@o=current()/m:modifierType/@v]"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:t[@o=$name]"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:keyword">
  <tr>
  &src_string;
  <td colspan="3">
  <xsl:choose>
   <xsl:when test="$trans/t:t[@o=current()/@v] != ''">
    <xsl:value-of select="$trans/t:t[@o=current()/@v]"/>
    <xsl:if test="@v = 'EPO' or @v = 'EPC' or @v = 'EPM'">
     <!-- Sheep Mountain Airport -->
     <xsl:if test="../../m:obsStationId/m:id/@v = 'PASP'"> (Tahetna pass)</xsl:if>
     <!-- Cantwell -->
     <xsl:if test="../../m:obsStationId/m:id/@v = 'PATW'"></xsl:if>
     <!-- Merrill Pass West -->
     <xsl:if test="../../m:obsStationId/m:id/@v = 'PAER'"></xsl:if>
     <!-- Farewell Lake Seaplane Base -->
     <xsl:if test="../../m:obsStationId/m:id/@v = 'PAFK'"></xsl:if>
     <!-- Healy River Airport -->
     <xsl:if test="../../m:obsStationId/m:id/@v = 'PAHV'"></xsl:if>
     <!-- Port Alsworth -->
     <xsl:if test="../../m:obsStationId/m:id/@v = 'PALJ'"></xsl:if>
     <!-- Big River Lake -->
     <xsl:if test="../../m:obsStationId/m:id/@v = 'PALV'"></xsl:if>
    </xsl:if>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="@s"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:obsStationType">
  <tr>
  &src_string;
  <td nowrap="1" colspan="3">
  <xsl:value-of select="$trans/t:stationType[@o=current()/m:stationType/@v]"/>
  </td></tr>&nl;
 </xsl:template>

 <xsl:template match="m:visListAtLoc">
  <xsl:apply-templates select="m:visLocData"/>
 </xsl:template>

 <xsl:template match="m:visLocData">
  <tr>
  <xsl:if test="position() = 1">
   <xsl:call-template name="src_string">
    <xsl:with-param name="rows" select="last()"/>
    <xsl:with-param name="s" select="../@s"/>
   </xsl:call-template>
  </xsl:if>
  <td nowrap="1">
  <xsl:value-of select="substring-before($trans/t:hdr[@o='visLoc'], '|')"/>
  <xsl:apply-templates select="m:locationAnd">
   <xsl:with-param name="locOrDir" select="'compassDirTo'"/>
  </xsl:apply-templates>
  <xsl:value-of select="substring-after($trans/t:hdr[@o='visLoc'], '|')"/>
  </td>
  <xsl:call-template name="visibility">
   <xsl:with-param name="notavail" select="$trans/t:t[@o='notAvailable']"/>
   <xsl:with-param name="visVal" select="m:visibility"/>
  </xsl:call-template>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:MOV|m:MOVD">
  <xsl:value-of select="$trans/t:t[@o=name(current())]"/>
  <xsl:apply-templates select="m:locationAnd">
   <xsl:with-param name="locOrDir" select="'compassDirTo'"/>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="m:locationAnd">
  <xsl:param name="locOrDir"/>
  <xsl:apply-templates select="m:locationThru">
   <xsl:with-param name="locOrDir" select="$locOrDir"/>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="m:locationThru">
  <xsl:param name="locOrDir"/>
  <xsl:if test="position() != 1">,</xsl:if>
  <xsl:apply-templates select="m:location">
   <xsl:with-param name="locOrDirBefore" select="substring-before($trans/t:t[@o=$locOrDir], '|')"/>
   <xsl:with-param name="locOrDirAfter" select="substring-after($trans/t:t[@o=$locOrDir], '|')"/>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="m:location">
  <xsl:param name="locOrDirBefore"/>
  <xsl:param name="locOrDirAfter"/>
  <xsl:if test="position() != 1">
   <xsl:choose>
    <xsl:when test="boolean(m:compassDir|m:quadrant) or boolean(preceding-sibling::m:location/m:compassDir|preceding-sibling::m:location/m:quadrant)">
     <xsl:value-of select="$trans/t:t[@o='loc-through']"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:text>,</xsl:text>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:if>
  <xsl:if test="boolean(m:distance)">
   <xsl:value-of select="concat(' ', m:distance/@v, $trans/t:units[@o=current()/m:distance/@u])"/>
  </xsl:if>
  <xsl:if test="position() = 1 and boolean(m:inDistance|m:inVicinity)">
   <xsl:value-of select="concat(' ', $trans/t:locationSpec[@o=name(current()/m:inDistance|current()/m:inVicinity)])"/>
  </xsl:if>
  <xsl:apply-templates select="m:locationSpec">
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  <xsl:if test="position() = 1 and boolean(m:compassDir|m:quadrant)">
   <xsl:value-of select="concat(' ', $locOrDirBefore)"/>
  </xsl:if>
  <xsl:if test="position() != 1 and boolean(m:compassDir|m:quadrant)">
   <xsl:value-of select="concat(' ', substring-before($trans/t:t[@o='compassDirThrough'], '|'))"/>
  </xsl:if>
  <xsl:if test="boolean(m:quadrant)">
   <xsl:for-each select="m:quadrant">
    <xsl:if test="position() != 1">
     <xsl:value-of select="$trans/t:t[@o='loc-and']"/>
    </xsl:if>
    <xsl:value-of select="$trans/t:quadrant[@o=current()/@v]"/>
   </xsl:for-each>
   <xsl:value-of select="concat(' ', $trans/t:t[@o='quadrant'])"/>
  </xsl:if>
  <xsl:if test="boolean(m:compassDir)">
   <xsl:variable name="quad">
    <xsl:if test="boolean(m:isQuadrant)">
     <xsl:value-of select="$trans/t:t[@o='compassDirDescrQuad']"/>
    </xsl:if>
   </xsl:variable>
   <xsl:apply-templates select="m:compassDir">
    <xsl:with-param name="pre" select="substring-before($quad, '|')"/>
    <xsl:with-param name="post" select="substring-after($quad, '|')"/>
   </xsl:apply-templates>
   <xsl:if test="not(boolean(m:isQuadrant))">
    <xsl:if test="position() = 1">
     <xsl:value-of select="$locOrDirAfter"/>
    </xsl:if>
    <xsl:if test="position() != 1">
     <xsl:value-of select="substring-after($trans/t:t[@o='compassDirThrough'], '|')"/>
    </xsl:if>
   </xsl:if>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:visibilityAtLoc">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:if test="boolean(m:locationAt)">
   <xsl:variable name="hdr" select="$trans/t:hdr[@o=current()/m:locationAt/@v]"/>
   <xsl:value-of select="substring-before($hdr, '|')"/>
   <xsl:apply-templates select="m:compassDir">
    <xsl:with-param name="pre" select="concat(' ', substring-before($trans/t:t[@o='compassDirTo'], '|'))"/>
    <xsl:with-param name="post" select="substring-after($trans/t:t[@o='compassDirTo'], '|')"/>
   </xsl:apply-templates>
   <xsl:value-of select="substring-after($hdr, '|')"/>
  </xsl:if>
  <xsl:if test="boolean(m:rwyDesig)">
   <xsl:variable name="hdr" select="$trans/t:hdr[@o='visLoc']"/>
   <xsl:value-of select="substring-before($hdr, '|')"/>
   <xsl:apply-templates select="m:rwyDesig">
    <xsl:with-param name="pre" select="' '"/>
   </xsl:apply-templates>
   <xsl:value-of select="substring-after($hdr, '|')"/>
  </xsl:if>
  </td>
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable)">
    <td nowrap="1" colspan="2">
    <xsl:apply-templates select="m:notAvailable"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <xsl:call-template name="visibility">
     <xsl:with-param name="visVal" select="m:visibility"/>
    </xsl:call-template>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:rwyDesig">
  <xsl:param name="pre"/>
  <xsl:value-of select="$pre"/>
  <xsl:if test="boolean(../m:isApproach)">
   <xsl:value-of select="concat($trans/t:t[@o='approach'], ' ')"/>
  </xsl:if>
  <xsl:value-of select="concat(substring-before($trans/t:t[@o='rwyDesig'], '|'), @v, substring-after($trans/t:t[@o='rwyDesig'], '|'))"/>
 </xsl:template>

 <xsl:template match="m:visVar2">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="2"/>
   <xsl:with-param name="s" select="../m:visVar1/@s"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'rmkVisVar'"/>
  </xsl:call-template>
  <xsl:call-template name="visibility">
   <xsl:with-param name="notavail" select="$trans/t:t[@o='notAvailable']"/>
   <xsl:with-param name="visVal" select="../m:visVar1"/>
  </xsl:call-template>
  </tr>&nl;
  <tr>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'to'"/>
  </xsl:call-template>
  <xsl:call-template name="visibility">
   <xsl:with-param name="notavail" select="$trans/t:t[@o='notAvailable']"/>
   <xsl:with-param name="visVal" select="."/>
  </xsl:call-template>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:precipitation|m:precipCity">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:value-of select="substring-before($trans/t:hdr[@o=name(current())], '|')"/>
  <xsl:if test="boolean(m:precipAmount|m:precipTraces)">
   <xsl:apply-templates select="m:timePeriod|m:timeBeforeObs|m:timeSince">
    <xsl:with-param name="pre" select="' '"/>
   </xsl:apply-templates>
  </xsl:if>
  <xsl:value-of select="substring-after($trans/t:hdr[@o=name(current())], '|')"/>
  </td>
  <xsl:call-template name="precipAmountVal"/>
  </tr>&nl;
 </xsl:template>

 <xsl:template name="precipAmountVal">
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable|m:invalidFormat|m:coverNotCont|m:noMeasurement|m:precipTraces)">
    <td nowrap="1" colspan="2">
    <xsl:apply-templates select="m:notAvailable|m:invalidFormat|m:coverNotCont|m:noMeasurement|m:precipTraces"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <td nowrap="1">
    <xsl:call-template name="unitConverter">
     <xsl:with-param name="val" select="m:precipAmount"/>
    </xsl:call-template>
    </td>
    &tab5;
    <td nowrap="1">
    <xsl:choose>
     <xsl:when test="m:precipAmount/@u = 'IN' and m:precipAmount/@v &lt; 1">
      <xsl:call-template name="unitConverter">
       <xsl:with-param name="val" select="m:precipAmount"/>
       <xsl:with-param name="unit" select="'MM'"/>
       <xsl:with-param name="factor" select="1"/>
       <xsl:with-param name="format" select="'0.#'"/>
      </xsl:call-template>
     </xsl:when>
     <xsl:when test="m:precipAmount/@u = 'IN'">
      <xsl:call-template name="unitConverter">
       <xsl:with-param name="val" select="m:precipAmount"/>
       <xsl:with-param name="unit" select="'CM'"/>
       <xsl:with-param name="factor" select="1"/>
       <xsl:with-param name="format" select="'0.#'"/>
      </xsl:call-template>
     </xsl:when>
     <xsl:otherwise>
      <xsl:call-template name="unitConverter">
       <xsl:with-param name="val" select="m:precipAmount"/>
       <xsl:with-param name="unit" select="'IN'"/>
       <xsl:with-param name="factor" select="1"/>
       <xsl:with-param name="format" select="'0.##'"/>
      </xsl:call-template>
     </xsl:otherwise>
    </xsl:choose>
    </td>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:snowIncr">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:value-of select="substring-before($trans/t:t[@o='snowIncrPastHour'],'|')"/>
  <xsl:value-of select="m:pastHour/@v"/>
  <xsl:value-of select="substring-after($trans/t:t[@o='snowIncrPastHour'], '|')"/>
  <xsl:text>, </xsl:text>
  <xsl:value-of select="substring-before($trans/t:t[@o='snowIncrOnGround'],'|')"/>
  <xsl:value-of select="m:onGround/@v"/>
  <xsl:value-of select="substring-after($trans/t:t[@o='snowIncrOnGround'], '|')"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:cloudTypeLow">
  <xsl:value-of select="$trans/t:cloudTypeLow[@o=current()/@v]"/>
 </xsl:template>

 <xsl:template match="m:cloudTypeMiddle">
  <xsl:value-of select="$trans/t:cloudTypeMiddle[@o=current()/@v]"/>
 </xsl:template>

 <xsl:template match="m:cloudTypeHigh">
  <xsl:value-of select="$trans/t:cloudTypeHigh[@o=current()/@v]"/>
 </xsl:template>

 <xsl:template match="m:cloudTypes">
  <xsl:variable name="rows">
   <xsl:choose>
    <xsl:when test="boolean(m:oktas) and not(m:cloudTypeLow/@v = 0 and m:cloudTypeMiddle/@v = 0 and m:oktas/@v = 0)">4</xsl:when>
    <xsl:when test="boolean(m:cloudTypeLow|m:cloudTypeLowNA)">3</xsl:when>
   </xsl:choose>
  </xsl:variable>
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable|m:invalidFormat)">
    <td colspan="2">
    <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
    </td>
   </xsl:when>
   <xsl:when test="boolean(m:skyObscured)">
    <td colspan="2">
    <xsl:value-of select="concat($trans/t:t[@o='notAvailable'], ', ')"/>
    <xsl:apply-templates select="m:skyObscured"/>
    </td>
   </xsl:when>
   <xsl:when test="$rows = 4">
    &nl;&tab1;
    <td colspan="2">
    <xsl:value-of select="$trans/t:t[@o='cloudLayerCover']"/>
    <xsl:apply-templates select="m:oktas"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    &nl;
    <xsl:call-template name="cloudTypeLow"/>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
  <xsl:if test="$rows >= 3">
   <xsl:if test="$rows = 4">
    <tr>
    <xsl:call-template name="cloudTypeLow"/>
     </tr>&nl;
   </xsl:if>
   <tr>
   &tab1;
   <td colspan="2">
   <xsl:value-of select="$trans/t:t[@o='middle']"/>
   <xsl:choose>
    <xsl:when test="boolean(m:cloudTypeMiddleNA)">
     <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:if test="boolean(m:oktasMiddle)">
      <xsl:apply-templates select="m:oktasMiddle"/>
      <xsl:text> </xsl:text>
     </xsl:if>
     <xsl:value-of select="$trans/t:cloudTypeMiddle[@o=current()/m:cloudTypeMiddle/@v]"/>
    </xsl:otherwise>
   </xsl:choose>
   </td>
   </tr>&nl;
   <tr>
   &tab1;
   <td colspan="2">
   <xsl:value-of select="$trans/t:t[@o='high']"/>
   <xsl:choose>
    <xsl:when test="boolean(m:cloudTypeHighNA)">
     <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="$trans/t:cloudTypeHigh[@o=current()/m:cloudTypeHigh/@v]"/>
    </xsl:otherwise>
   </xsl:choose>
   </td>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template name="cloudTypeLow">
  &tab1;
  <td colspan="2">
  <xsl:value-of select="$trans/t:t[@o='low']"/>
  <xsl:choose>
   <xsl:when test="boolean(m:cloudTypeLowNA)">
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:if test="boolean(m:oktasLow)">
     <xsl:apply-templates select="m:oktasLow"/>
     <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:apply-templates select="m:cloudTypeLow"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
 </xsl:template>

 <xsl:template match="m:synop_section2|m:synop_section3|m:synop_section4|m:synop_section5|m:synop_section9|m:buoy_section1|m:buoy_section2|m:buoy_section3|m:buoy_section4|m:amdar_section3">
  <xsl:call-template name="section">
   <xsl:with-param name="s" select="@s"/>
   <xsl:with-param name="section_nr" select="substring(name(), string-length(name()))"/>
  </xsl:call-template>
  <xsl:apply-templates select="*"/>
 </xsl:template>

 <xsl:template match="m:weatherHist">
  <xsl:variable name="rows" select="count(m:weatherBeginEnd)"/>
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'weather'"/>
   <xsl:with-param name="rows"  select="$rows"/>
  </xsl:call-template>
  <xsl:apply-templates select="m:weatherBeginEnd">
   <xsl:with-param name="is_first" select="1"/>
  </xsl:apply-templates>
  </tr>&nl;
  <xsl:apply-templates select="m:weatherBeginEnd">
   <xsl:with-param name="is_first" select="0"/>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template name="printWeatherHist">
  <td nowrap="1" colspan="2">
  <dl><dt>
  <xsl:call-template name="printWeather"/>
  <xsl:if test="boolean(../m:locationAnd)">
   <xsl:apply-templates select="../m:locationAnd">
    <xsl:with-param name="locOrDir" select="'compassDirLocation'"/>
   </xsl:apply-templates>
   <xsl:if test="boolean(../m:MOV|../m:MOVD|../m:isStationary)">,</xsl:if>
  </xsl:if>
  <xsl:if test="boolean(../m:MOV|../m:MOVD|../m:isStationary)"><xsl:text> </xsl:text></xsl:if>
  <xsl:apply-templates select="../m:MOV|../m:MOVD|../m:isStationary"/>
  <xsl:text>:</xsl:text></dt>
  <xsl:apply-templates select="m:weatherBegan|m:weatherEnded"/>
  </dl></td>
 </xsl:template>

 <xsl:template match="m:weatherBeginEnd">
  <xsl:param name="is_first"/>
  <xsl:if test="$is_first = 1 and position() = 1">
   <xsl:call-template name="printWeatherHist"/>
  </xsl:if>
  <xsl:if test="$is_first = 0 and position() != 1">
   <tr>
   &tab3;
   <xsl:call-template name="printWeatherHist"/>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:weatherBegan|m:weatherEnded">
  <xsl:if test="$method != 'html'">&nl;&tab4;</xsl:if>
  <dd>
  <xsl:value-of select="$trans/t:t[@o=name(current())]"/>
  <xsl:apply-templates select="m:timeAt">
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  </dd>
 </xsl:template>

 <xsl:template match="m:cloudType">
  <xsl:if test="position() != 1">
   <xsl:value-of select="$trans/t:t[@o='loc-and']"/>
  </xsl:if>
  <xsl:value-of select="$trans/t:cloudType[@o=current()/@v]"/>
 </xsl:template>

 <xsl:template match="m:lightningType">
  <xsl:if test="position() = 1">
   <xsl:value-of select="concat($trans/t:phenomenon[@o='LTG'], ' ')"/>
  </xsl:if>
  <xsl:if test="position() != 1">
   <xsl:value-of select="$trans/t:t[@o='loc-and']"/>
  </xsl:if>
  <xsl:value-of select="$trans/t:lightningType[@o=current()/@v]"/>
 </xsl:template>

 <xsl:template match="m:phenomenon">
  <tr>
  &src_string;
  <td colspan="3">
  <xsl:apply-templates select="m:phenomDescrPre">
   <xsl:with-param name="post" select="' '"/>
  </xsl:apply-templates>
  <xsl:choose>
   <xsl:when test="boolean(m:weather)">
   <xsl:for-each select="m:weather">
    <xsl:call-template name="printWeather"/>
   </xsl:for-each>
   </xsl:when>
   <xsl:when test="boolean(m:cloudType|m:cloudCover|m:lightningType)">
    <xsl:apply-templates select="m:cloudType|m:cloudCover|m:lightningType"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:phenomenon[@o=current()/m:otherPhenom/@v]"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:if test="boolean(m:obscgMtns)">
   <xsl:value-of select="$trans/t:t[@o='obscgMtns']"/>
  </xsl:if>
  <xsl:apply-templates select="m:phenomDescrPost">
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  <xsl:if test="boolean(m:locationAnd)">
   <xsl:if test="boolean(m:phenomDescrPost)">,</xsl:if>
   <xsl:apply-templates select="m:locationAnd">
    <xsl:with-param name="locOrDir" select="'compassDirLocation'"/>
   </xsl:apply-templates>
   <xsl:if test="boolean(m:MOV|m:MOVD|m:isStationary)">,</xsl:if>
  </xsl:if>
  <xsl:if test="boolean(m:MOV|m:MOVD|m:isStationary)"><xsl:text> </xsl:text></xsl:if>
  <xsl:apply-templates select="m:MOV|m:MOVD|m:isStationary"/>
  <xsl:if test="boolean(m:cloudTypeAsoctd|m:cloudTypeEmbd)">
   <xsl:text>, </xsl:text>
   <xsl:apply-templates select="m:cloudTypeAsoctd|m:cloudTypeEmbd"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:phenomDescr|m:phenomDescr2|m:phenomVariation|m:phenomDescrPre|m:phenomDescrPost|m:locationSpec">
  <xsl:param name="pre"/>
  <xsl:param name="post"/>
  <xsl:if test="position() = 1"><xsl:value-of select="$pre"/></xsl:if>
  <xsl:if test="position() != 1">, </xsl:if>
  <xsl:choose>
   <xsl:when test="name() = 'locationSpec'">
    <xsl:value-of select="$trans/t:locationSpec[@o=current()/@v]"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:t[@o=current()/@v]"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:if test="position() = last()"><xsl:value-of select="$post"/></xsl:if>
 </xsl:template>

 <xsl:template match="m:conditionMountain">
  <xsl:apply-templates select="m:condMountainLoc"/>
  <xsl:apply-templates select="m:maxConcentration"/>
 </xsl:template>

 <xsl:template match="m:condMountainLoc">
  <tr>
  <xsl:if test="position() = 1">
   <xsl:call-template name="src_string">
    <xsl:with-param name="rows" select="count(../m:maxConcentration) + 1"/>
    <xsl:with-param name="s" select="../@s"/>
   </xsl:call-template>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'conditionMountain'"/>
    <xsl:with-param name="rows" select="last()"/>
   </xsl:call-template>
  </xsl:if>
  <xsl:if test="position() != 1">
   &tab3;
  </xsl:if>
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:locationAnd">
   <xsl:with-param name="locOrDir" select="'compassDirLocation'"/>
  </xsl:apply-templates>
  <xsl:if test="boolean(m:locationAnd)">: </xsl:if>
  <xsl:value-of select="$trans/t:cloudMountain[@o=current()/m:cloudMountain/@v]"/>
  <xsl:if test="boolean(m:cloudEvol)">
   <xsl:value-of select="concat('. ', $trans/t:phenomenon[@o='CLDS'], ': ', $trans/t:cloudEvol[@o=current()/m:cloudEvol/@v])"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:conditionValley">
  <xsl:apply-templates select="m:condValleyLoc"/>
  <xsl:apply-templates select="m:maxConcentration"/>
 </xsl:template>

 <xsl:template match="m:condValleyLoc">
  <tr>
  <xsl:if test="position() = 1">
   <xsl:call-template name="src_string">
    <xsl:with-param name="rows" select="count(../m:maxConcentration) + 1"/>
    <xsl:with-param name="s" select="../@s"/>
   </xsl:call-template>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'conditionValley'"/>
    <xsl:with-param name="rows"     select="last()"/>
   </xsl:call-template>
  </xsl:if>
  <xsl:if test="position() != 1">
   &tab3;
  </xsl:if>
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:locationAnd">
   <xsl:with-param name="locOrDir" select="'compassDirLocation'"/>
  </xsl:apply-templates>
  <xsl:if test="boolean(m:locationAnd)">: </xsl:if>
  <xsl:value-of select="$trans/t:cloudValley[@o=current()/m:cloudValley/@v]"/>
  <xsl:if test="boolean(m:cloudBelowEvol)">
   <xsl:value-of select="concat('. ', $trans/t:phenomenon[@o='CLDS'], ': ', $trans/t:cloudBelowEvol[@o=current()/m:cloudBelowEvol/@v])"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:ceilingAtLoc">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:value-of select="$trans/t:t[@o='ceiling']"/>
  <xsl:apply-templates select="m:rwyDesig">
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  <xsl:apply-templates select="m:locationAnd">
   <xsl:with-param name="locOrDir" select="'compassDirLocation'"/>
  </xsl:apply-templates>
  <xsl:text>:</xsl:text>
  </td>
  &tab1;
  <xsl:choose>
   <xsl:when test="boolean(m:cloudsLower)">
    <td nowrap="1" colspan="2">
    <xsl:value-of select="concat($trans/t:phenomenon[@o='CLDS'], ' ', $trans/t:t[@o='isLower'])"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <td nowrap="1">
    <xsl:value-of select="concat($trans/t:t[@o='cloud-at'], ' ')"/>
    <xsl:call-template name="unitConverter">
     <xsl:with-param name="val" select="m:cloudBase"/>
    </xsl:call-template>
    </td>
    &tab4;
    <td nowrap="1">
    <xsl:apply-templates select="m:cloudBase" mode="metaf_alt"/>
    </td>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:opacityPhenom">
  <xsl:apply-templates select="m:opacityCloud|m:opacityWeather"/>
 </xsl:template>

 <xsl:template match="m:cloudTypeAsoctd|m:cloudTypeEmbd">
  <xsl:value-of select="concat(substring-before($trans/t:t[@o=name(current())], '|'), $trans/t:cloudType[@o=current()/@v], substring-after($trans/t:t[@o=name(current())], '|'))"/>
 </xsl:template>

 <xsl:template match="m:opacityCloud|m:opacityWeather">
  <xsl:variable name="rows" select="last() + count(../m:cloudTypeAsoctd|../m:cloudTypeEmbd)"/>
  <tr>
  <xsl:choose>
   <xsl:when test="position() = 1">
    <xsl:call-template name="src_string">
     <xsl:with-param name="rows" select="$rows"/>
     <xsl:with-param name="s"    select="../@s"/>
    </xsl:call-template>
    <xsl:call-template name="hdr_string">
     <xsl:with-param name="hdr_name" select="'cloudOpacityLvl'"/>
     <xsl:with-param name="rows"     select="$rows"/>
    </xsl:call-template>
   </xsl:when>
   <xsl:otherwise>
    &tab3;
   </xsl:otherwise>
  </xsl:choose>
  <td nowrap="1" colspan="2">
   <xsl:apply-templates select="m:oktas|m:tenths"/>
   <xsl:if test="boolean(m:weather)">
    <xsl:text> </xsl:text>
    <xsl:for-each select="m:weather">
     <xsl:call-template name="printWeather"/>
    </xsl:for-each>
   </xsl:if>
   <xsl:if test="boolean(m:cloudType)">
    <xsl:text> </xsl:text>
    <xsl:apply-templates select="m:cloudType"/>
   </xsl:if>
  </td>
  </tr>&nl;
  <xsl:if test="position() = last() and boolean(../m:cloudTypeAsoctd|../m:cloudTypeEmbd)">
   <tr>
   &tab3;
   <td nowrap="1" colspan="2">
   <xsl:apply-templates select="../m:cloudTypeAsoctd|../m:cloudTypeEmbd"/>
   </td>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:cloudTypeLvl">
  <tr>
  &src_string;
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'cloud'"/>
  </xsl:call-template>
  <xsl:choose>
   <xsl:when test="boolean(m:cloudBase)">
    <td nowrap="1">
    <xsl:apply-templates select="m:cloudType"/>
    <xsl:value-of select="concat(' ', $trans/t:t[@o='cloud-at'], ' ')"/>
    <xsl:call-template name="unitConverter">
     <xsl:with-param name="val" select="m:cloudBase"/>
    </xsl:call-template>
    </td>
    &tab3;
    <td nowrap="1">
    <xsl:apply-templates select="m:cloudBase" mode="metaf_alt"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <td nowrap="1" colspan="2">
    <xsl:apply-templates select="m:cloudType"/>
    </td>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:cloudTrace">
  <tr>
  &src_string;
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'tracesOf'"/>
  </xsl:call-template>
  <td nowrap="1" colspan="2">
  <xsl:if test="boolean(m:isLower)">
   <xsl:value-of select="concat($trans/t:t[@o='isLower'], ' ')"/>
  </xsl:if>
  <xsl:if test="boolean(m:cloudTypeNotAvailable)">
   <xsl:value-of select="$trans/t:t[@o='cloudTypeNotAvailable']"/>
  </xsl:if>
  <xsl:for-each select="m:cloudType">
   <xsl:if test="position() != 1">, </xsl:if>
   <xsl:value-of select="$trans/t:cloudType[@o=current()/@v]"/>
  </xsl:for-each>
  <xsl:apply-templates select="m:locationAnd">
   <xsl:with-param name="locOrDir" select="'compassDirLocation'"/>
  </xsl:apply-templates>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:seaCondition|m:swellCondition|m:alightingAreaCondition">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:if test="boolean(m:seaCondVal)">
   <xsl:value-of select="$trans/t:seaCondition[@o=current()/m:seaCondVal/@v]"/>
  </xsl:if>
  <xsl:if test="boolean(m:swellCondVal)">
   <xsl:value-of select="$trans/t:swellCondition[@o=current()/m:swellCondVal/@v]"/>
  </xsl:if>
  <xsl:if test="boolean(m:locationAnd)">
   <xsl:text>,</xsl:text>
   <xsl:apply-templates select="m:locationAnd">
    <xsl:with-param name="locOrDir" select="'compassDirFrom'"/>
   </xsl:apply-templates>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:obscuration">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:value-of select="substring-before($trans/t:hdr[@o='obscuration'], '|')"/>
  <xsl:for-each select="m:weather">
   <xsl:call-template name="printWeather"/>
  </xsl:for-each>
  <xsl:if test="boolean(m:cloudPhenom)">
   <xsl:value-of select="$trans/t:cloudPhenom[@o=current()/m:cloudPhenom/@v]"/>
  </xsl:if>
  <xsl:value-of select="substring-after($trans/t:hdr[@o='obscuration'], '|')"/>
  </td>
  <xsl:for-each select="m:cloud">
   <xsl:call-template name="printCloud"/>
  </xsl:for-each>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:VA_fcst">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="2"/>
  </xsl:call-template>
  <td nowrap="1" rowspan="2" valign="top">
  <xsl:value-of select="concat(substring-before($trans/t:weather[@o='VA'], '|'), substring-after($trans/t:weather[@o='VA'], '|'), ':')"/>
  &tab2;
  </td>
  <td nowrap="1">
  <xsl:value-of select="$trans/t:hdr[@o='layerBase']"/>
  <xsl:call-template name="unitConverter">
   <xsl:with-param name="val" select="m:layerBase"/>
  </xsl:call-template>
  </td>
  &tab3;
  <td nowrap="1">
  <xsl:apply-templates select="m:layerBase" mode="metaf_alt"/>
  </td>
  </tr>&nl;
  <tr>
  &tab3;
  <td nowrap="1">
  <xsl:value-of select="$trans/t:t[@o='layerTop']"/>
  <xsl:text>:&#9;</xsl:text>
  <xsl:call-template name="unitConverter">
   <xsl:with-param name="val" select="m:layerTop"/>
  </xsl:call-template>
  </td>
  &tab3;
  <td nowrap="1">
  <xsl:apply-templates select="m:layerTop" mode="metaf_alt"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:variableCeiling">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="2"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="rows" select="2"/>
  </xsl:call-template>
  <td nowrap="1">
  <xsl:value-of select="$trans/t:t[@o='variable-from']"/>
  <xsl:call-template name="unitConverter">
   <xsl:with-param name="val" select="m:cloudBaseFrom"/>
  </xsl:call-template>
  </td>
  &tab4;
  <td nowrap="1">
  <xsl:apply-templates select="m:cloudBaseFrom" mode="metaf_alt"/>
  </td>
  </tr>&nl;
  <tr>
  &tab3;
  <td nowrap="1">
  <xsl:value-of select="$trans/t:t[@o='variable-to']"/>
  <xsl:call-template name="unitConverter">
   <xsl:with-param name="val" select="m:cloudBaseTo"/>
  </xsl:call-template>
  </td>
  &tab4;
  <td nowrap="1">
  <xsl:apply-templates select="m:cloudBaseTo" mode="metaf_alt"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:pressureChange">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:apply-templates select="m:timeBeforeObs">
   <xsl:with-param name="pre" select="' '"/>
   <xsl:with-param name="header">
    <xsl:choose>
     <xsl:when test="boolean(../m:stationPressure/m:pressure) or name(..) = 'synop_section3' or name(..) = 'buoy_section1'">
      <xsl:value-of select="$trans/t:hdr[@o='pressureChangeStn']"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="$trans/t:hdr[@o='pressureChange']"/>
     </xsl:otherwise>
    </xsl:choose>
   </xsl:with-param>
  </xsl:apply-templates>
  </td>
  <td nowrap="1" colspan="2">
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable|m:invalidFormat)">
    <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:variable name="sign">
     <xsl:if test="m:pressureChangeVal/@v > 0">+</xsl:if>
    </xsl:variable>
    <xsl:value-of select="concat($sign, m:pressureChangeVal/@v, $trans/t:units[@o='hPa'])"/>
    <xsl:if test="boolean(m:pressureTendency)">
     <xsl:value-of select="concat(', ', $trans/t:pressureTend[@o=current()/m:pressureTendency/@v])"/>
    </xsl:if>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:ceilVisVariable">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="2"/>
  </xsl:call-template>
  &hdr_string;
  <xsl:call-template name="visibility">
   <xsl:with-param name="notavail" select="$trans/t:t[@o='notAvailable']"/>
   <xsl:with-param name="visVal" select="m:visibilityFrom"/>
  </xsl:call-template>
  </tr>&nl;
  <tr>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'to'"/>
  </xsl:call-template>
  <xsl:call-template name="visibility">
   <xsl:with-param name="notavail" select="$trans/t:t[@o='notAvailable']"/>
   <xsl:with-param name="visVal" select="m:visibilityTo"/>
  </xsl:call-template>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:rwySfcCondition">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:for-each select="*">
   <xsl:if test="name() = 'notAvailable'">
    <xsl:value-of select="$trans/t:t[@o='decelerometerReadingNA']"/>
   </xsl:if>
   <xsl:if test="name() = 'decelerometer'">
    <xsl:value-of select="concat($trans/t:t[@o='decelerometerReading'], ' ',@v)"/>
   </xsl:if>
   <xsl:if test="name() = 'rwySfc'">
    <xsl:value-of select="$trans/t:rwySfc[@o=current()/@v]"/>
   </xsl:if>
   <xsl:if test="position() != last()">, </xsl:if>
  </xsl:for-each>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:rainfall">
  <xsl:apply-templates select="m:precipitation"/>
 </xsl:template>

 <xsl:template match="m:rainfall/m:precipitation">
  <tr>
  <xsl:if test="position() = 1">
   <xsl:call-template name="src_string">
    <xsl:with-param name="rows" select="last()"/>
    <xsl:with-param name="s"    select="../@s"/>
   </xsl:call-template>
  </xsl:if>
  <td nowrap="1">
  <xsl:value-of select="substring-before($trans/t:hdr[@o='rainfall'], '|')"/>
  <xsl:apply-templates select="m:timePeriod|m:timeBeforeObs|m:timeSince">
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  <xsl:value-of select="substring-after($trans/t:hdr[@o='rainfall'], '|')"/>
  </td>
  <xsl:call-template name="precipAmountVal"/>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:NEFO_PLAYA">
  <tr>
  &src_string;
  &hdr_string;
  <xsl:choose>
   <xsl:when test="boolean(m:noClouds)">
    <td nowrap="1" colspan="2">
    <xsl:apply-templates select="m:noClouds"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <td nowrap="1">
    <xsl:call-template name="unitConverter">
     <xsl:with-param name="val" select="m:cloudBase"/>
    </xsl:call-template>
    </td>
    &tab3;
    <td nowrap="1">
    <xsl:apply-templates select="m:cloudBase" mode="metaf_alt"/>
    </td>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:densityAlt|m:pressureAlt">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1">
  <xsl:value-of select="concat(m:altitude/@v, $trans/t:units[@o='FT'])"/>
  </td>
  &tab5;
  <td nowrap="1">
  <xsl:value-of select="concat(format-number(m:altitude/@v div 10 * $FT2M, '0.0') * 10, $trans/t:units[@o='M'])"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:VISNO|m:CHINO">
  <tr>
  &src_string;
  <td nowrap="1" colspan="3">
  <xsl:variable name="s" select="$trans/t:t[@o=name(current())]"/>
  <xsl:value-of select="substring-before($s, '|')"/>
  <xsl:apply-templates select="m:rwyDesig"/>
  <xsl:value-of select="substring-after($s, '|')"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:obsTimeOffset">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:value-of select="concat(m:minutes/@v, ' ', $trans/t:t[@o='minutes'])"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:waterEquivOfSnow">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:value-of select="substring-before($trans/t:hdr[@o='waterEquivOfSnow'], '|')"/>
  <xsl:choose>
   <xsl:when test="boolean(m:timePeriod)">
    <xsl:apply-templates select="m:timePeriod">
     <xsl:with-param name="pre" select="' '"/>
    </xsl:apply-templates>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:t[@o='onGround']"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:value-of select="substring-after($trans/t:hdr[@o='waterEquivOfSnow'], '|')"/>
  </td>
  <xsl:call-template name="precipAmountVal"/>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:snowCover">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:value-of select="$trans/t:snowCoverType[@o=current()/m:snowCoverType/@v]"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:climate">
  <tr>
  <xsl:call-template name="printTemp">
   <xsl:with-param name="hdr" select="$trans/t:hdr[@o='temp1']"/>
   <xsl:with-param name="rows" select="count(*)"/>
   <xsl:with-param name="s" select="@s"/>
   <xsl:with-param name="temp" select="m:temp1"/>
  </xsl:call-template>
  </tr>&nl;
  <tr>
  <xsl:call-template name="printTemp">
   <xsl:with-param name="hdr" select="$trans/t:hdr[@o='temp2']"/>
   <xsl:with-param name="temp" select="m:temp2"/>
  </xsl:call-template>
  </tr>&nl;
  <xsl:if test="boolean(m:precipAmount1Inch|m:precipAmount1MM|m:precipTraces)">
   <tr>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'precipAmount1'"/>
   </xsl:call-template>
   <xsl:choose>
    <xsl:when test="boolean(m:precipAmount1Inch)">
     <td nowrap="1">
     <xsl:value-of select="concat(format-number(m:precipAmount1Inch/@v * ($FT2M div 12 * 1000), '0'), $trans/t:units[@o='MM'])"/>
     </td>
     &tab5;
     <td nowrap="1">
     <xsl:value-of select="concat(m:precipAmount1Inch/@v, $trans/t:units[@o='IN'])"/>
     </td>
    </xsl:when>
    <xsl:when test="boolean(m:precipAmount1MM)">
     <td nowrap="1">
     <xsl:value-of select="concat(m:precipAmount1MM/@v, $trans/t:units[@o='MM'])"/>
     </td>
     &tab5;
     <td nowrap="1">
     <xsl:value-of select="concat(format-number(m:precipAmount1MM/@v div ($FT2M div 12 * 1000), '0.00'), $trans/t:units[@o='IN'])"/>
     </td>
    </xsl:when>
    <xsl:otherwise>
     <td nowrap="1" colspan="2">
     <xsl:value-of select="$trans/t:t[@o='precipTraces']"/>
     </td>
    </xsl:otherwise>
   </xsl:choose>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:precipAmount2Inch|m:precipAmount2MM)">
   <tr>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'precipAmount2'"/>
   </xsl:call-template>
   <xsl:choose>
    <xsl:when test="boolean(m:precipAmount2Inch)">
     <td nowrap="1">
     <xsl:value-of select="concat(format-number(m:precipAmount2Inch/@v * ($FT2M div 12 * 1000), '0'), $trans/t:units[@o='MM'])"/>
     </td>
     &tab5;
     <td nowrap="1">
     <xsl:value-of select="concat(m:precipAmount2Inch/@v, $trans/t:units[@o='IN'])"/>
     </td>
    </xsl:when>
    <xsl:otherwise>
     <td nowrap="1">
     <xsl:value-of select="concat(m:precipAmount2MM/@v, $trans/t:units[@o='MM'])"/>
     </td>
     &tab5;
     <td nowrap="1">
     <xsl:value-of select="concat(format-number(m:precipAmount2MM/@v div ($FT2M div 12 * 1000), '0.00'), $trans/t:units[@o='IN'])"/>
     </td>
    </xsl:otherwise>
   </xsl:choose>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:balloon">
  <tr>
  &src_string;
  <td nowrap="1" colspan="3">
  <xsl:if test="boolean(m:disappearedAt)">
   <xsl:value-of select="substring-before($trans/t:t[@o='balloonDisapp'], '|')"/>
   <xsl:value-of select="concat(m:disappearedAt/m:distance/@v, $trans/t:units[@o=current()/m:disappearedAt/m:distance/@u])"/>
   <xsl:value-of select="substring-after($trans/t:t[@o='balloonDisapp'], '|')"/>
  </xsl:if>
  <xsl:if test="boolean(m:visibleTo)">
   <xsl:value-of select="substring-before($trans/t:t[@o='balloonVisib'], '|')"/>
   <xsl:value-of select="concat(m:visibleTo/m:distance/@v, $trans/t:units[@o=current()/m:visibleTo/m:distance/@u])"/>
   <xsl:value-of select="substring-after($trans/t:t[@o='balloonVisib'], '|')"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:firstObs|m:nextObs|m:lastObs">
  <xsl:variable name="name" select="name()"/>
  <tr>
  &src_string;
  <td nowrap="1" colspan="3">
  <xsl:value-of select="substring-before($trans/t:t[@o=$name], '|')"/>
  <xsl:apply-templates select="m:isManned|m:isStaffed"/>
  <xsl:value-of select="substring-after($trans/t:t[@o=$name], '|')"/>
  <xsl:apply-templates select="m:timeAt">
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:isStaffed|m:isManned|m:isStationary|m:coverNotCont|m:noMeasurement|m:precipTraces|m:thicknessTraces|m:oktasNotAvailable|m:seaConfused|m:dirNotAvailable|m:dirVariable|m:dirVarAllUnk">
  <xsl:value-of select="$trans/t:t[@o=name(current())]"/>
 </xsl:template>

 <xsl:template match="m:notAvailable">
  <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
 </xsl:template>

 <xsl:template match="m:skyObscured">
  <xsl:value-of select="$trans/t:phenomenon[@o='SKY_OBSC']"/>
 </xsl:template>

 <xsl:template match="m:estimated">
  <tr>
  &src_string;
  <td nowrap="1" colspan="3">
  <xsl:for-each select="m:estimatedItem">
   <xsl:if test="position() != 1">, </xsl:if>
   <xsl:value-of select="$trans/t:estimatedItem[@o=current()/@v]"/>
  </xsl:for-each>
  <xsl:value-of select="concat(' ', $trans/t:t[@o='estimated'])"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:RSNK|m:LAG_PK">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(m:wind/m:gustSpeed|m:dewpoint) + 3"/>
  </xsl:call-template>
  <td nowrap="1" colspan="3">
  <b><xsl:value-of select="$trans/t:hdr[@o=name(current())]"/></b>
  </td>
  </tr>&nl;
  <tr>
  <xsl:call-template name="printTemp">
   <xsl:with-param name="hdr" select="$trans/t:hdr[@o='temperature-temp']"/>
   <xsl:with-param name="temp" select="m:air"/>
  </xsl:call-template>
  </tr>&nl;
  <xsl:if test="boolean(m:dewpoint)">
   <tr>
   <xsl:call-template name="printTemp">
    <xsl:with-param name="hdr" select="$trans/t:hdr[@o='temperature-dew']"/>
    <xsl:with-param name="temp" select="m:dewpoint"/>
   </xsl:call-template>
   </tr>&nl;
  </xsl:if>
  <xsl:apply-templates select="m:wind">
   <xsl:with-param name="hdr" select="$trans/t:hdr[@o='sfcWind']"/>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="m:RADAT">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="3 - count(m:isMissing)"/>
  </xsl:call-template>
  <td nowrap="1" colspan="3">
  <b><xsl:value-of select="$trans/t:hdr[@o='RADAT']"/></b>
  </td>
  </tr>&nl;
  <xsl:choose>
   <xsl:when test="boolean(m:isMissing)">
    <tr>
    <td nowrap="1" colspan="3">
    <xsl:value-of select="$trans/t:t[@o='isMissing']"/>
    </td>
    </tr>&nl;
   </xsl:when>
   <xsl:otherwise>
    <tr>
    <xsl:call-template name="hdr_string">
     <xsl:with-param name="hdr_name" select="'relHumid'"/>
    </xsl:call-template>
    <td nowrap="1" colspan="2">
    <xsl:value-of select="m:relHumid/@v"/>
    <xsl:text> %</xsl:text>
    </td>
    </tr>&nl;
    <tr>
    <xsl:call-template name="hdr_string">
     <xsl:with-param name="hdr_name" select="'freezingLvl'"/>
    </xsl:call-template>
    <td nowrap="1">
    <xsl:value-of select="concat($trans/t:t[@o='cloud-at'], ' ', m:distance/@v, $trans/t:units[@o='FT'])"/>
    </td>
    &tab4;
    <td nowrap="1">
    <xsl:apply-templates select="m:distance" mode="metaf_alt"/>
    </td>
    </tr>&nl;
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:radiationSun">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(m:rad0PosNet|m:rad1NegNet|m:rad2GlobalSolar|m:rad3DiffusedSolar|m:rad4DownwardLongWave|m:rad5UpwardLongWave|m:rad6ShortWave) + 1"/>
  </xsl:call-template>
  <td nowrap="1">
  <xsl:apply-templates select="m:sunshinePeriod">
   <xsl:with-param name="pre" select="' '"/>
   <xsl:with-param name="header" select="$trans/t:hdr[@o='sunshine']"/>
  </xsl:apply-templates>
  </td>
  <td nowrap="1" colspan="2">
  <xsl:choose>
   <xsl:when test="boolean(m:sunshine)">
    <xsl:variable name="sunshineMinutes">
     <xsl:if test="m:sunshine/@u = 'MIN'">
      <xsl:value-of select="m:sunshine/@v" />
     </xsl:if>
     <xsl:if test="m:sunshine/@u = 'H'">
      <xsl:value-of select="format-number(m:sunshine/@v * 60, '0')" />
     </xsl:if>
    </xsl:variable>
    <xsl:choose>
     <xsl:when test="$sunshineMinutes > 59">
      <xsl:variable name="min" select="$sunshineMinutes mod 60"/>
      <xsl:value-of select="concat(($sunshineMinutes - $min) div 60, $trans/t:units[@o='H'])"/>
      <xsl:if test="$min > 0">
       <xsl:value-of select="concat(' ', $min, $trans/t:units[@o='MIN'])"/>
      </xsl:if>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="concat($sunshineMinutes, $trans/t:units[@o='MIN'])"/>
     </xsl:otherwise>
    </xsl:choose>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
  <xsl:apply-templates select="m:rad0PosNet|m:rad1NegNet|m:rad2GlobalSolar|m:rad3DiffusedSolar|m:rad4DownwardLongWave|m:rad5UpwardLongWave|m:rad6ShortWave"/>
 </xsl:template>

 <xsl:template match="m:rad0PosNet|m:rad1NegNet|m:rad2GlobalSolar|m:rad3DiffusedSolar|m:rad4DownwardLongWave|m:rad5UpwardLongWave|m:rad6ShortWave|m:radShortWave|m:radDirectSolar">
  <tr>
  <xsl:if test="@s != ''">
   &src_string;
  </xsl:if>
  <td nowrap="1">
  <xsl:variable name="hdr" select="$trans/t:hdr[@o=name(current())]"/>
  <xsl:value-of select="substring-before($hdr, '|')"/>
  <xsl:apply-templates select="../m:radiationPeriod|m:radiationPeriod">
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  <xsl:value-of select="substring-after($hdr, '|')"/>
  </td>
  <td nowrap="1" colspan="2">
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable)">
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="concat(m:radiationValue/@v, $trans/t:units[@o=current()/m:radiationValue/@u])"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:hailStones|m:glazeDeposit|m:rimeDeposit|m:compoundDeposit|m:wetsnowDeposit">
  <tr>
  &src_string;
  &hdr_string;
  <td colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:if test="boolean(m:precipTraces)">
   <xsl:value-of select="$trans/t:t[@o='notMeasurable']"/>
  </xsl:if>
  <xsl:if test="boolean(m:diameter)">
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:diameter"/>
   </xsl:call-template>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:activeRwy">
  <tr>
  &src_string;
  &hdr_string;
  <td colspan="2">
  <xsl:apply-templates select="m:rwyDesig"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:transitionLvl">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:value-of select="concat($trans/t:t[@o='cloud-at'], ' FL ', m:level/@v)"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:QBB|m:QBJ">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:value-of select="concat(m:altitude/@v, $trans/t:units[@o='M'])"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:currentATIS">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:value-of select="m:ATIS/@v"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:notRecognised|m:obsInitials">
  <tr>
  &src_string;
  &hdr_string;
  <td colspan="2">
  <xsl:value-of select="@s"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:weatherMan">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(*) + 1"/>
  </xsl:call-template>
  <td colspan="3">
   <xsl:value-of select="$trans/t:t[@o='WEA']"/>
  </td>
  </tr>&nl;
  <xsl:if test="boolean(m:timeAt)">
   <tr>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'obsTime'"/>
   </xsl:call-template>
   <td colspan="2">
   <xsl:apply-templates select="m:timeAt"/>
   </td>
   </tr>&nl;
  </xsl:if>
  <xsl:apply-templates select="m:weather" mode="go"/>
 </xsl:template>

 <xsl:template match="m:birdStrikeHazard">
  <tr>
  &src_string;
  <td colspan="3">
  <xsl:value-of select="substring-before($trans/t:t[@o='birdStrikeHazard'], '|')"/>
  <xsl:apply-templates select="m:rwyDesig">
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  <xsl:value-of select="substring-after($trans/t:t[@o='birdStrikeHazard'], '|')"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:fcstNotAvbl">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:value-of select="$trans/t:fcstNotAvblReason[@o=current()/m:fcstNotAvblReason/@v]"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:temp_fcst">
  <xsl:variable name="rows" select="count(m:air)"/>
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:call-template name="printTemp">
   <xsl:with-param name="temp" select="m:air[1]"/>
   <xsl:with-param name="offsetValidFrom" select="0"/>
  </xsl:call-template>
  </tr>&nl;
  <xsl:for-each select="m:air[position() > 1]">
   <tr>
   &tab3;
   <xsl:call-template name="printTemp">
    <xsl:with-param name="temp" select="."/>
    <xsl:with-param name="offsetValidFrom" select="position() * 3"/>
   </xsl:call-template>
   </tr>&nl;
  </xsl:for-each>
 </xsl:template>

 <xsl:template match="m:stateOfGround">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:if test="boolean(m:stateOfGroundVal)">
   <xsl:value-of select="$trans/t:stateOfGround[@o=current()/m:stateOfGroundVal/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:stateOfGroundSnow">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:if test="boolean(m:stateOfGroundSnowVal)">
   <xsl:value-of select="$trans/t:stateOfGroundSnow[@o=current()/m:stateOfGroundSnowVal/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:snowDepth|m:snowFall">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:variable name="hdr" select="$trans/t:hdr[@o=name(current())]"/>
  <xsl:value-of select="substring-before($hdr, '|')"/>
  <xsl:apply-templates select="m:timePeriod|m:timeBeforeObs|m:timeSince">
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  <xsl:value-of select="substring-after($hdr, '|')"/>
  </td>
  <xsl:call-template name="precipAmountVal"/>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:cloudTypesDrift">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="3"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="rows" select="3"/>
  </xsl:call-template>
  &nl;&tab1;
  <td nowrap="1" colspan="2">
  <xsl:value-of select="$trans/t:t[@o='low']"/>
  <xsl:if test="boolean(m:cloudTypeLowNA)">
   <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
  </xsl:if>
  <xsl:if test="boolean(m:cloudTypeLowNone)">
   <xsl:value-of select="$trans/t:t[@o='cloudNone']"/>
  </xsl:if>
  <xsl:if test="boolean(m:cloudTypeLowInvisible)">
   <xsl:value-of select="$trans/t:t[@o='cloudInvisible']"/>
  </xsl:if>
  <xsl:apply-templates select="m:cloudTypeLowDir">
   <xsl:with-param name="hdr" select="'compassDirFrom'"/>
  </xsl:apply-templates>
  <xsl:apply-templates select="m:cloudTypeLowCompassDir">
   <xsl:with-param name="pre" select="substring-before($trans/t:t[@o='compassDirFrom'], '|')"/>
   <xsl:with-param name="post" select="substring-after($trans/t:t[@o='compassDirFrom'], '|')"/>
  </xsl:apply-templates>
  </td>
  </tr>&nl;
  <tr>
  <td nowrap="1" colspan="2">
  &tab1;
  <xsl:value-of select="$trans/t:t[@o='middle']"/>
  <xsl:if test="boolean(m:cloudTypeMiddleNA)">
   <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
  </xsl:if>
  <xsl:if test="boolean(m:cloudTypeMiddleNone)">
   <xsl:value-of select="$trans/t:t[@o='cloudNone']"/>
  </xsl:if>
  <xsl:if test="boolean(m:cloudTypeMiddleInvisible)">
   <xsl:value-of select="$trans/t:t[@o='cloudInvisible']"/>
  </xsl:if>
  <xsl:apply-templates select="m:cloudTypeMiddleDir">
   <xsl:with-param name="hdr" select="'compassDirFrom'"/>
  </xsl:apply-templates>
  <xsl:apply-templates select="m:cloudTypeMiddleCompassDir">
   <xsl:with-param name="pre" select="substring-before($trans/t:t[@o='compassDirFrom'], '|')"/>
   <xsl:with-param name="post" select="substring-after($trans/t:t[@o='compassDirFrom'], '|')"/>
  </xsl:apply-templates>
  </td>
  </tr>&nl;
  <tr>
  <td nowrap="1" colspan="2">
  &tab1;
  <xsl:value-of select="$trans/t:t[@o='high']"/>
  <xsl:if test="boolean(m:cloudTypeHighNA)">
   <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
  </xsl:if>
  <xsl:if test="boolean(m:cloudTypeHighNone)">
   <xsl:value-of select="$trans/t:t[@o='cloudNone']"/>
  </xsl:if>
  <xsl:if test="boolean(m:cloudTypeHighInvisible)">
   <xsl:value-of select="$trans/t:t[@o='cloudInvisible']"/>
  </xsl:if>
  <xsl:apply-templates select="m:cloudTypeHighDir">
   <xsl:with-param name="hdr" select="'compassDirFrom'"/>
  </xsl:apply-templates>
  <xsl:apply-templates select="m:cloudTypeHighCompassDir">
   <xsl:with-param name="pre" select="substring-before($trans/t:t[@o='compassDirFrom'], '|')"/>
   <xsl:with-param name="post" select="substring-after($trans/t:t[@o='compassDirFrom'], '|')"/>
  </xsl:apply-templates>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:cloudLocation">
  <tr>
  &src_string;
  <td nowrap="1" colspan="3">
  <xsl:if test="boolean(m:cloudTypeNotAvailable)">
   <xsl:value-of select="$trans/t:t[@o='cloudTypeNotAvailable']"/>
  </xsl:if>
  <xsl:apply-templates select="m:cloudType"/>
  <xsl:if test="boolean(m:cloudNone)">
   <xsl:value-of select="concat(', ', $trans/t:t[@o='cloudNone'])"/>
  </xsl:if>
  <xsl:if test="boolean(m:cloudInvisible)">
   <xsl:value-of select="concat(', ', $trans/t:t[@o='cloudInvisible'])"/>
  </xsl:if>
  <xsl:apply-templates select="m:cloudCompassDir">
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  <xsl:text>, </xsl:text>
  <xsl:if test="boolean(m:topsInvisible)">
   <xsl:value-of select="$trans/t:t[@o='topsInvisible']"/>
  </xsl:if>
  <xsl:if test="boolean(m:elevationAngle)">
   <xsl:value-of select="$trans/t:t[@o='elevationAngle']"/>
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:elevationAngle"/>
   </xsl:call-template>
   <xsl:text>°</xsl:text>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:group5xxxxNA">
  <tr>
  &src_string;
  <td nowrap="1" colspan="3">
  <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:evapo[boolean(m:notAvailable)]">
  <xsl:variable name="hdr" select="$trans/t:hdr[@o='evaporation']"/>
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:value-of select="concat(substring-before($hdr, '|'), substring-after($hdr, '|'))"/>
  </td>
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:evapo[boolean(m:evapoAmount)]">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="2"/>
  </xsl:call-template>
  <td nowrap="1">
  <xsl:apply-templates select="m:timePeriod|m:timeBeforeObs">
   <xsl:with-param name="pre" select="' '"/>
   <xsl:with-param name="header">
    <xsl:choose>
     <xsl:when test="m:evapoIndicator/@v &lt; 5">
      <xsl:value-of select="$trans/t:hdr[@o='evaporation']"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="$trans/t:hdr[@o='evapotranspiration']"/>
     </xsl:otherwise>
    </xsl:choose>
   </xsl:with-param>
  </xsl:apply-templates>
  </td>
  <td nowrap="1" colspan="2">
  <xsl:value-of select="concat(m:evapoAmount/@v, $trans/t:units[@o=current()/m:evapoAmount/@u])"/>
  </td>
  </tr>&nl;
  <tr>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name">
    <xsl:choose>
     <xsl:when test="m:evapoIndicator/@v &lt; 5">evapoInstrumentation</xsl:when>
     <xsl:otherwise>cropEvapotranspiration</xsl:otherwise>
    </xsl:choose>
   </xsl:with-param>
  </xsl:call-template>
  <td nowrap="1" colspan="2">
  <xsl:value-of select="$trans/t:evapoIndicator[@o=current()/m:evapoIndicator/@v]"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:tempChange">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:value-of select="substring-before($trans/t:hdr[@o='tempChange'], '|')"/>
  <xsl:call-template name="printHoursFromTill">
   <xsl:with-param name="desc" select="concat($trans/t:t[@o='since'], '|')"/>
  </xsl:call-template>
  <xsl:value-of select="substring-after($trans/t:hdr[@o='tempChange'], '|')"/>
  </td>
  <td nowrap="1">
  <xsl:value-of select="concat(m:temp/@v, ' °C')"/>
  </td>
  &tab5;
  <td nowrap="1">
  <xsl:value-of select="concat(format-number(m:temp/@v div 1.8, '0.#'), ' °F')"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:cloudInfo">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(m:cloudBaseFrom|m:visVertFrom) + 1"/>
  </xsl:call-template>
  <td>
  <xsl:choose>
   <xsl:when test="boolean(m:cloudBaseNotAvailable|m:cloudBase|m:cloudBaseFrom|m:invalidFormat)">
    <xsl:variable name="hdr" select="$trans/t:hdr[@o='cloudInfoBase']"/>
    <xsl:value-of select="substring-before($hdr, '|')"/>
    <xsl:if test="boolean(m:cloudOktas/m:oktas)">
     <xsl:apply-templates select="m:cloudOktas/m:oktas"/>
     <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:if test="boolean(m:cloudTypeNotAvailable|m:cloudTypeLowNA|m:cloudTypeMiddleNA|m:cloudTypeHighNA)">
      <xsl:value-of select="$trans/t:t[@o='cloudTypeNotAvailable']"/>
    </xsl:if>
    <xsl:apply-templates select="m:cloudType|m:cloudTypeLow|m:cloudTypeMiddle|m:cloudTypeHigh"/>
    <xsl:if test="not(boolean(m:cloudOktas/m:oktas))">
     <xsl:text> (</xsl:text>
     <xsl:apply-templates select="m:cloudOktas/*"/>
     <xsl:text>)</xsl:text>
    </xsl:if>
    <xsl:if test="boolean(m:cloudBaseFrom)">
     <xsl:value-of select="$trans/t:t[@o='range-from']"/>
    </xsl:if>
    <xsl:value-of select="substring-after($hdr, '|')"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="substring-before($trans/t:hdr[@o='visVert'], '|')"/>
    <xsl:if test="boolean(m:visVertFrom)">
     <xsl:value-of select="$trans/t:t[@o='range-from']"/>
    </xsl:if>
    <xsl:value-of select="substring-after($trans/t:hdr[@o='visVert'], '|')"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  <xsl:if test="boolean(m:cloudBaseNotAvailable)">
   <td nowrap="1" colspan="2">
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
   </td>
  </xsl:if>
  <xsl:if test="boolean(m:invalidFormat)">
   <td nowrap="1" colspan="2">
    <xsl:apply-templates select="m:invalidFormat"/>
   </td>
  </xsl:if>
  <xsl:if test="boolean(m:cloudBase)">
   <td nowrap="1">
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:cloudBase"/>
   </xsl:call-template>
   </td>
   &tab4;
   <td nowrap="1">
   <xsl:apply-templates select="m:cloudBase" mode="synop_alt"/>
   </td>
  </xsl:if>
  <xsl:if test="boolean(m:cloudBaseFrom)">
   <td nowrap="1">
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:cloudBaseFrom"/>
   </xsl:call-template>
   </td>
   &tab4;
   <td nowrap="1">
   <xsl:apply-templates select="m:cloudBaseFrom" mode="synop_alt"/>
   </td>
  </xsl:if>
  <xsl:if test="boolean(m:visVert|m:visVertFrom)">
   <xsl:call-template name="visibility">
    <xsl:with-param name="visVal" select="m:visVert|m:visVertFrom"/>
   </xsl:call-template>
  </xsl:if>
  </tr>&nl;
  <xsl:if test="boolean(m:cloudBaseTo)">
   <tr>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'to'"/>
   </xsl:call-template>
   <td nowrap="1">
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:cloudBaseTo"/>
   </xsl:call-template>
   </td>
   &tab4;
   <td nowrap="1">
   <xsl:apply-templates select="m:cloudBaseTo" mode="synop_alt"/>
   </td>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:visVertTo)">
   <tr>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'to'"/>
   </xsl:call-template>
   <xsl:call-template name="visibility">
    <xsl:with-param name="visVal" select="m:visVertTo"/>
   </xsl:call-template>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:cloudEvolution">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(m:maxConcentration) + 1"/>
  </xsl:call-template>
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:cloudType"/>
  <xsl:value-of select="concat(': ', $trans/t:cloudEvol[@o=current()/m:cloudEvol/@v])"/>
  </td>
  </tr>&nl;
  <xsl:apply-templates select="m:maxConcentration"/>
 </xsl:template>

 <xsl:template match="m:cloudTopsHeight">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(*)"/>
  </xsl:call-template>
  <td nowrap="1">
  <xsl:variable name="hdr" select="$trans/t:hdr[@o='cloudTopsHeight']"/>
  <xsl:value-of select="substring-before($hdr, '|')"/>
  <xsl:if test="boolean(m:cloudTopsFrom)">
   <xsl:value-of select="$trans/t:t[@o='range-from']"/>
  </xsl:if>
  <xsl:value-of select="substring-after($hdr, '|')"/>
  </td>
  <xsl:if test="boolean(m:notAvailable|m:invalidFormat)">
   <td nowrap="1" colspan="2">
    <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
   </td>
  </xsl:if>
  <xsl:if test="boolean(m:cloudTops)">
   <td nowrap="1">
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:cloudTops"/>
   </xsl:call-template>
   </td>
   &tab4;
   <td nowrap="1">
   <xsl:apply-templates select="m:cloudTops" mode="synop_alt"/>
   </td>
  </xsl:if>
  <xsl:if test="boolean(m:cloudTopsFrom)">
   <td nowrap="1">
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:cloudTopsFrom"/>
   </xsl:call-template>
   </td>
   &tab4;
   <td nowrap="1">
   <xsl:apply-templates select="m:cloudTopsFrom" mode="synop_alt"/>
   </td>
  </xsl:if>
  </tr>&nl;
  <xsl:if test="boolean(m:cloudTopsFrom)">
   <tr>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'to'"/>
   </xsl:call-template>
   <td nowrap="1">
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:cloudTopsTo"/>
   </xsl:call-template>
   </td>
   &tab4;
   <td nowrap="1">
   <xsl:apply-templates select="m:cloudTopsTo" mode="synop_alt"/>
   </td>
   </tr>&nl;
  </xsl:if>
  <xsl:apply-templates select="m:maxConcentration"/>
 </xsl:template>

 <xsl:template match="m:oktas|m:oktasLow|m:oktasMiddle">
  <!-- WMO-No. 306 Vol I.1, Part A, coding table 2700 -->
  <xsl:value-of select="concat(@v, '/8 (')"/>
  <xsl:choose>
   <xsl:when test="@v = 0 or @v = 1"><xsl:value-of select="@v"/></xsl:when>
   <xsl:when test="@v = 2">2..3</xsl:when>
   <xsl:when test="@v = 6">7..8</xsl:when>
   <xsl:when test="@v = 7 or @v = 8"><xsl:value-of select="@v + 2"/></xsl:when>
   <xsl:otherwise><xsl:value-of select="@v + 1"/></xsl:otherwise>
  </xsl:choose>
  <xsl:text>/10)</xsl:text>
  <xsl:if test="@v = 1">
   <xsl:value-of select="$trans/t:t[@o='lessOktas']"/>
  </xsl:if>
  <xsl:if test="@v = 7">
   <xsl:value-of select="$trans/t:t[@o='moreOktas']"/>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:tenths">
  <xsl:value-of select="concat(@v, '/10 (')"/>
  <xsl:choose>
   <xsl:when test="@v &lt;= 2"><xsl:value-of select="@v"/></xsl:when>
   <xsl:when test="@v >= 8"><xsl:value-of select="@v - 2"/></xsl:when>
   <xsl:otherwise><xsl:value-of select="@v - 1"/></xsl:otherwise>
  </xsl:choose>
  <xsl:text>/8)</xsl:text>
  <xsl:if test="@v = 1">
   <xsl:value-of select="$trans/t:t[@o='lessTenths']"/>
  </xsl:if>
  <xsl:if test="@v = 9">
   <xsl:value-of select="$trans/t:t[@o='moreTenths']"/>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:precipCharacter">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable)">
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
   </xsl:when>
   <xsl:when test="boolean(m:noPrecip)">
    <xsl:value-of select="$trans/t:t[@o='noPrecip']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:apply-templates select="m:phenomDescr|m:phenomDescr2"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:beginPrecip|m:endPrecip">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable)">
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
   </xsl:when>
   <xsl:when test="boolean(m:noPrecip)">
    <xsl:value-of select="$trans/t:t[@o='noPrecip']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:call-template name="printHoursFromTill">
     <xsl:with-param name="desc" select="$trans/t:t[@o='atAgo']"/>
    </xsl:call-template>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:weatherSynopInfo">
  <tr>
  &src_string;
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name">
    <xsl:choose>
     <xsl:when test="m:timeBeforeObs/@occurred = 'Begin'">weatherSynopBegin</xsl:when>
     <xsl:when test="m:timeBeforeObs/@occurred = 'End'">weatherSynopEnd</xsl:when>
     <xsl:when test="boolean(m:timeBeforeObs)">weatherSynopSince</xsl:when>
     <xsl:otherwise>weatherSynopCharacter</xsl:otherwise>
    </xsl:choose>
   </xsl:with-param>
  </xsl:call-template>
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:phenomVariation|m:location|m:phenomDescr|m:timeBeforeObs"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:timeBeforeObs">
  <xsl:param name="header"/>
  <xsl:param name="pre"/>
  <xsl:if test="$header != ''">
   <xsl:value-of select="substring-before($header, '|')"/>
  </xsl:if>
  <xsl:if test="position() = 1"><xsl:value-of select="$pre"/></xsl:if>
  <xsl:if test="position() != 1">, </xsl:if>
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable)">
    <xsl:variable name="name" select="concat('timeBeforeObs', @occurred, 'NA')"/>
    <xsl:value-of select="$trans/t:t[@o=$name]"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:call-template name="printHoursFromTill">
     <xsl:with-param name="desc">
      <xsl:choose>
       <xsl:when test="@occurred = 'Begin'">
        <xsl:value-of select="$trans/t:t[@o='beganAgo']"/>
       </xsl:when>
       <xsl:when test="@occurred = 'End'">
        <xsl:value-of select="$trans/t:t[@o='endedAgo']"/>
       </xsl:when>
       <xsl:when test="@occurred = 'At'">
        <xsl:value-of select="$trans/t:t[@o='atAgo']"/>
       </xsl:when>
       <xsl:when test="@occurred = 'Duration'">
        <xsl:value-of select="$trans/t:t[@o='duration']"/>
       </xsl:when>
       <xsl:otherwise>
        <xsl:value-of select="concat($trans/t:t[@o='since'], '|')"/>
       </xsl:otherwise>
      </xsl:choose>
     </xsl:with-param>
    </xsl:call-template>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:if test="$header != ''">
   <xsl:value-of select="substring-after($header, '|')"/>
  </xsl:if>
 </xsl:template>

 <xsl:template name="printHoursFromTill">
  <xsl:param name="desc"/>
  <xsl:value-of select="substring-before($desc, '|')"/>
  <xsl:if test="m:hours/@q = 'isGreater'">&gt;</xsl:if>
  <xsl:if test="m:hours/@q = 'isLess'">&lt;</xsl:if>
  <xsl:value-of select="m:minutes/@v|m:hoursFrom/@v|m:hours/@v"/>
  <xsl:if test="boolean(m:hoursTill)">
   <xsl:value-of select="concat(' .. ', m:hoursTill/@v)"/>
  </xsl:if>
  <xsl:choose>
   <xsl:when test="boolean(m:minutes)">
    <xsl:value-of select="$trans/t:units[@o='MIN']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:units[@o='H']"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:value-of select="substring-after($desc, '|')"/>
 </xsl:template>

 <xsl:template match="m:highestGust|m:highestMeanSpeed|m:meanSpeed|m:lowestMeanSpeed|m:highestWind|m:maxDerivedVerticalGust">
  <xsl:variable name="hdr2" select="$trans/t:hdr[@o=name(current())]"/>
  <xsl:apply-templates select="m:wind">
   <xsl:with-param name="hdr">
    <xsl:value-of select="substring-before($hdr2, '|')"/>
    <xsl:if test="boolean(m:measurePeriod)">
     <xsl:choose>
      <xsl:when test="boolean(m:timePeriod|m:timeBeforeObs[not(boolean(@occurred))]|m:timeBeforeObs[@occurred='At']|m:timeAt)">
       <xsl:value-of select="$trans/t:t[@o='during']"/>
      </xsl:when>
      <xsl:otherwise>
       <xsl:value-of select="concat(' ', $trans/t:t[@o='since'])"/>
      </xsl:otherwise>
     </xsl:choose>
     <xsl:value-of select="concat(m:measurePeriod/@v, $trans/t:units[@o=current()/m:measurePeriod/@u])"/>
    </xsl:if>
    <xsl:apply-templates select="m:timeAt">
     <xsl:with-param name="pre" select="' '"/>
    </xsl:apply-templates>
    <xsl:apply-templates select="m:timePeriod|m:timeBeforeObs|m:phenomDescr|m:phenomVariation|m:location">
     <xsl:with-param name="pre" select="' '"/>
    </xsl:apply-templates>
    <xsl:value-of select="substring-after($hdr2, '|')"/>
   </xsl:with-param>
   <xsl:with-param name="s" select="@s"/>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="m:squall">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(m:approaching) + 1"/>
  </xsl:call-template>
  <td nowrap="1" colspan="3">
  <xsl:value-of select="$trans/t:squallType[@o=current()/m:squallType/@v]"/>
  <xsl:apply-templates select="m:location">
   <xsl:with-param name="locOrDirBefore" select="substring-before($trans/t:t[@o='compassDirFrom'], '|')"/>
   <xsl:with-param name="locOrDirAfter" select="substring-after($trans/t:t[@o='compassDirFrom'], '|')"/>
  </xsl:apply-templates>
  </td>
  </tr>&nl;
  <xsl:apply-templates select="m:approaching"/>
 </xsl:template>

 <xsl:template match="m:approaching">
  <xsl:param name="s"/>
  <xsl:param name="hdr_string"/>
  <tr>
  <xsl:if test="$s != ''">
   <xsl:call-template name="src_string">
    <xsl:with-param name="s" select="$s"/>
   </xsl:call-template>
  </xsl:if>
  <xsl:choose>
   <xsl:when test="boolean(m:isStationary)">
    <td nowrap="1" colspan="3">
    <xsl:apply-templates select="m:isStationary"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <td>
    <xsl:apply-templates select="m:compassDir">
     <xsl:with-param name="pre" select="concat($hdr_string, substring-before($trans/t:t[@o='approachingWith'], '|'), substring-before($trans/t:t[@o='compassDirFrom'], '|'))"/>
     <xsl:with-param name="post" select="concat(substring-after($trans/t:t[@o='compassDirFrom'], '|'), substring-after($trans/t:t[@o='approachingWith'], '|'))"/>
    </xsl:apply-templates>
    </td>
    <xsl:apply-templates select="m:speed" mode="range"/>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:windPhenom">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(m:approaching) + 1"/>
  </xsl:call-template>
  <td nowrap="1" colspan="3">
  <xsl:value-of select="$trans/t:windPhenomType[@o=current()/m:windPhenomType/@v]"/>
  <xsl:apply-templates select="m:location">
   <xsl:with-param name="locOrDirBefore" select="substring-before($trans/t:t[@o='compassDirLocation'], '|')"/>
   <xsl:with-param name="locOrDirAfter" select="substring-after($trans/t:t[@o='compassDirLocation'], '|')"/>
  </xsl:apply-templates>
  </td>
  </tr>&nl;
  <xsl:apply-templates select="m:approaching"/>
 </xsl:template>

 <xsl:template match="m:precipPeriods">
  <tr>
  &src_string;
  &hdr_string;
  <td colspan="2">
  <xsl:call-template name="printHoursFromTill"/>
  <xsl:choose>
   <xsl:when test="boolean(m:periodsNA)">
    <xsl:value-of select="$trans/t:t[@o='periodNotAvailable']"/>
   </xsl:when>
   <xsl:when test="boolean(m:onePeriod)">
    <xsl:value-of select="$trans/t:t[@o='onePeriod']"/>
   </xsl:when>
   <xsl:when test="boolean(m:morePeriods)">
    <xsl:value-of select="$trans/t:t[@o='morePeriods']"/>
   </xsl:when>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:stateOfSky">
  <tr>
  &src_string;
  &hdr_string;
  <td colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:if test="boolean(m:stateOfSkyVal)">
   <xsl:value-of select="$trans/t:stateOfSky[@o=current()/m:stateOfSkyVal/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:cloudBelowStation">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="2"/>
  </xsl:call-template>
  <td nowrap="1" rowspan="2" valign="top">
  <xsl:variable name="hdr" select="$trans/t:hdr[@o='cloudBelowStation']"/>
  <xsl:value-of select="substring-before($hdr, '|')"/>
  <xsl:if test="boolean(m:cloudOktas/m:oktas)">
   <xsl:apply-templates select="m:cloudOktas/m:oktas"/>
   <xsl:text> </xsl:text>
  </xsl:if>
  <xsl:apply-templates select="m:cloudType"/>
  <xsl:if test="not(boolean(m:cloudOktas/m:oktas))">
   <xsl:text> (</xsl:text>
   <xsl:apply-templates select="m:cloudOktas/*"/>
   <xsl:text>)</xsl:text>
  </xsl:if>
  <xsl:value-of select="substring-after($hdr, '|')"/>
  </td>
  <td nowrap="1">
  <xsl:call-template name="unitConverter">
   <xsl:with-param name="val" select="m:cloudTops"/>
  </xsl:call-template>
  </td>
  &tab3;
  <td nowrap="1">
  <xsl:apply-templates select="m:cloudTops" mode="synop_alt"/>
  </td>
  </tr>&nl;
  <tr>
  <td colspan="2">
  <xsl:value-of select="$trans/t:cloudTopDescr[@o=current()/m:cloudTopDescr/@v]"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:windDir">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:value-of select="substring-before($trans/t:hdr[@o='windDir'], '|')"/>
  <xsl:apply-templates select="m:timeBeforeObs">
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  <xsl:value-of select="substring-after($trans/t:hdr[@o='windDir'], '|')"/>
  </td>
  <td colspan="2">
  <xsl:apply-templates select="m:compassDir">
   <xsl:with-param name="pre" select="substring-before($trans/t:t[@o='wind-from'], '|')"/>
   <xsl:with-param name="post" select="substring-after($trans/t:t[@o='wind-from'], '|')"/>
  </xsl:apply-templates>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:recordTemp|m:recordTempCity">
  <tr>
  &src_string;
  <td nowrap="1" colspan="3">
  <xsl:value-of select="substring-before($trans/t:t[@o=name(current())], '|')"/>
  <xsl:if test="m:recordType/@v = 'HI'">
   <xsl:value-of select="$trans/t:t[@o='highest']"/>
  </xsl:if>
  <xsl:if test="m:recordType/@v = 'LO'">
   <xsl:value-of select="$trans/t:t[@o='lowest']"/>
  </xsl:if>
  <xsl:value-of select="substring-after($trans/t:t[@o=name(current())], '|')"/>
  <xsl:choose>
   <xsl:when test="(m:recordType/@v = 'HI' and m:recordPeriod/@v = 'SE') or (m:recordType/@v = 'LO' and m:recordPeriod/@v = 'SL')">
    <xsl:value-of select="$trans/t:recordPeriod[@o='spring']"/>
   </xsl:when>
   <xsl:when test="(m:recordType/@v = 'HI' and m:recordPeriod/@v = 'SL') or (m:recordType/@v = 'LO' and m:recordPeriod/@v = 'SE')">
    <xsl:value-of select="$trans/t:recordPeriod[@o='fall']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:recordPeriod[@o=current()/m:recordPeriod/@v]"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:choose>
   <xsl:when test="not(boolean(m:recordType/@q))">
    <xsl:value-of select="$trans/t:t[@o='isEqualled']"/>
   </xsl:when>
   <xsl:when test="m:recordType/@v = 'HI'">
    <xsl:value-of select="$trans/t:t[@o='isOverrun']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:t[@o='isUnderrun']"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:tideData">
  <xsl:variable name="rows" select="count(m:tideDeviation) + 1"/>
  <xsl:variable name="sign">
   <xsl:if test="m:tideDeviation/@v > 0">+</xsl:if>
  </xsl:variable>
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable)">
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:tideType[@o=current()/m:tideType/@v]"/>
    <xsl:value-of select="$trans/t:tideLevel[@o=current()/m:tideLevel/@v]"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
  <xsl:if test="$rows = 2">
   <tr>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'tideDeviation'"/>
   </xsl:call-template>
   <td nowrap="1">
   <xsl:value-of select="$sign"/>
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:tideDeviation"/>
   </xsl:call-template>
   </td>
   &tab3;
   <td nowrap="1">
   <xsl:value-of select="$sign"/>
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:tideDeviation"/>
    <xsl:with-param name="unit" select="'M'"/>
    <xsl:with-param name="factor" select="1"/>
    <xsl:with-param name="format" select="'0'"/>
   </xsl:call-template>
   </td>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:verticalClouds">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(m:maxConcentration|m:approaching) + 1"/>
  </xsl:call-template>
  &hdr_string;
  <td colspan="2">
  <xsl:value-of select="concat($trans/t:t[@o=current()/m:phenomDescr/@v], ' ', $trans/t:cloudTypeVertical[@o=current()/m:cloudTypeVertical/@v])"/>
  <xsl:apply-templates select="m:location">
   <xsl:with-param name="locOrDirBefore" select="substring-before($trans/t:t[@o='compassDirLocation'], '|')"/>
   <xsl:with-param name="locOrDirAfter" select="substring-after($trans/t:t[@o='compassDirLocation'], '|')"/>
  </xsl:apply-templates>
  </td>
  </tr>&nl;
  <xsl:apply-templates select="m:maxConcentration"/>
  <xsl:apply-templates select="m:approaching"/>
 </xsl:template>

 <xsl:template match="m:specialClouds|m:orographicClouds">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(m:maxConcentration) + 1"/>
  </xsl:call-template>
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:choose>
   <xsl:when test="name() = 'specialClouds'">
    <xsl:value-of select="$trans/t:cloudTypeSpecial[@o=current()/m:cloudTypeSpecial/@v]"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:cloudTypeOrographic[@o=current()/m:cloudTypeOrographic/@v]"/>
   </xsl:otherwise>
  </xsl:choose>
  <xsl:apply-templates select="m:location">
   <xsl:with-param name="locOrDirBefore" select="substring-before($trans/t:t[@o='compassDirLocation'], '|')"/>
   <xsl:with-param name="locOrDirAfter" select="substring-after($trans/t:t[@o='compassDirLocation'], '|')"/>
  </xsl:apply-templates>
  </td>
  </tr>&nl;
  <xsl:apply-templates select="m:maxConcentration"/>
 </xsl:template>

 <xsl:template match="m:maxConcentration|m:maxCloudLocation|m:maxLowCloudLocation|m:maxWeatherLocation">
  <tr>
  <xsl:if test="name() != 'maxConcentration'">
   &src_string;
  </xsl:if>
  <td nowrap="1" colspan="3">
  <xsl:if test="name() = 'maxConcentration'">&tab1;</xsl:if>
  <xsl:choose>
   <xsl:when test="name() = 'maxLowCloudLocation'">
    <xsl:value-of select="concat($trans/t:maxCloudType[@o='lowCloud'], ': ')"/>
   </xsl:when>
   <xsl:when test="name() = 'maxWeatherLocation'">
    <xsl:value-of select="concat($trans/t:weatherType[@o=current()/m:weatherType/@v], ': ')"/>
   </xsl:when>
   <xsl:when test="name(..) != 'verticalClouds' and name(..) != 'orographicClouds' and name(..) != 'specialClouds'">
    <xsl:value-of select="concat($trans/t:maxCloudType[@o='cloud'], ': ')"/>
   </xsl:when>
  </xsl:choose>
  <xsl:if test="boolean(m:cloudType|m:cloudTypeLow|m:cloudTypeMiddle|m:cloudTypeHigh)">
   <xsl:apply-templates select="m:cloudType|m:cloudTypeLow|m:cloudTypeMiddle|m:cloudTypeHigh"/>
   <xsl:text>, </xsl:text>
  </xsl:if>
  <xsl:value-of select="$trans/t:t[@o='maxConcentration']"/>
  <xsl:apply-templates select="m:location">
   <xsl:with-param name="locOrDirBefore" select="substring-before($trans/t:t[@o='compassDirLocation'], '|')"/>
   <xsl:with-param name="locOrDirAfter" select="substring-after($trans/t:t[@o='compassDirLocation'], '|')"/>
  </xsl:apply-templates>
  <xsl:if test="boolean(m:elevAboveHorizon)">
   <xsl:value-of select="concat(', ', $trans/t:elevAboveHorizon[@o=current()/m:elevAboveHorizon/@v])"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:weatherMovement">
  <xsl:apply-templates select="m:approaching">
   <xsl:with-param name="s" select="@s"/>
   <xsl:with-param name="hdr_string" select="concat($trans/t:weatherType[@o=current()/m:weatherType/@v], ': ')"/>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="m:opticalPhenom">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:value-of select="concat($trans/t:opticalPhenomenon[@o=current()/m:opticalPhenomenon/@v], ', ', $trans/t:t[@o=current()/m:phenomDescr/@v], ' ', $trans/t:t[@o='intensity'])"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:equivWindSpeed">
  <xsl:apply-templates select="m:wind">
   <xsl:with-param name="hdr">
    <xsl:value-of select="substring-before($trans/t:hdr[@o='equivWindSpeed'], '|')"/>
    <xsl:call-template name="unitConverter">
     <xsl:with-param name="val" select="m:sensorHeight"/>
    </xsl:call-template>
    <xsl:value-of select="substring-after($trans/t:hdr[@o='equivWindSpeed'], '|')"/>
   </xsl:with-param>
   <xsl:with-param name="s" select="@s"/>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="m:displacement">
  <xsl:variable name="dir">
   <xsl:choose>
    <xsl:when test="boolean(m:compassDir)">
     <xsl:value-of select="substring-before($trans/t:t[@o='compassDirTo'], '|')"/>
     <xsl:apply-templates select="m:compassDir"/>
     <xsl:value-of select="substring-after($trans/t:t[@o='compassDirTo'], '|')"/>
     <xsl:text>, </xsl:text>
    </xsl:when>
    <xsl:when test="boolean(m:dir)">
     <xsl:apply-templates select="m:dir">
      <xsl:with-param name="hdr" select="'compassDirTo'"/>
     </xsl:apply-templates>
     <xsl:text>, </xsl:text>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="concat($trans/t:t[@o='dirNotAvailable'], ' ')"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:apply-templates select="m:timeBeforeObs">
   <xsl:with-param name="header" select="$trans/t:hdr[@o='displacement']"/>
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  </td>
  <xsl:if test="boolean(m:speedNotAvailable)">
   <td colspan="2">
   <xsl:value-of select="concat($dir, $trans/t:t[@o='speedNotAvailable'])"/>
   </td>
  </xsl:if>
  <xsl:if test="boolean(m:isStationary)">
   <td colspan="2">
   <xsl:apply-templates select="m:isStationary"/>
   </td>
  </xsl:if>
  <xsl:apply-templates select="m:speed" mode="range">
   <xsl:with-param name="hdr" select="$dir"/>
  </xsl:apply-templates>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:speed" mode="range">
  <xsl:param name="hdr"/>
  <td nowrap="1">
  <xsl:if test="position() = 1"><xsl:value-of select="$hdr"/></xsl:if>
  <xsl:if test="position() != 1">&tab2;</xsl:if>
  <xsl:call-template name="unitConverter">
   <xsl:with-param name="range" select="1"/>
   <xsl:with-param name="val" select="."/>
  </xsl:call-template>
  </td>
 </xsl:template>

 <xsl:template match="m:seaSurfaceTemp|m:wetbulbTemperature">
  <xsl:variable name="rows" select="count(m:waterTempMeasurement|m:wetbulbTempMeasurement) + 1"/>
  <tr>
  <xsl:call-template name="printTemp">
   <xsl:with-param name="hdr" select="$trans/t:hdr[@o=name(current())]"/>
   <xsl:with-param name="rows" select="$rows"/>
   <xsl:with-param name="s" select="@s"/>
   <xsl:with-param name="temp" select="."/>
  </xsl:call-template>
  </tr>&nl;
  <xsl:if test="$rows = 2">
   <tr>
   &tab3;
   <td nowrap="1">
   <xsl:value-of select="$trans/t:t[@o='typeOfMeasurement']"/>
   </td>
   <td colspan="2">
   <xsl:if test="boolean(m:waterTempMeasurement)">
    <xsl:value-of select="$trans/t:waterTempMeasurement[@o=current()/m:waterTempMeasurement/@v]"/>
   </xsl:if>
   <xsl:if test="boolean(m:wetbulbTempMeasurement)">
    <xsl:value-of select="$trans/t:wetbulbTempMeasurement[@o=current()/m:wetbulbTempMeasurement/@v]"/>
   </xsl:if>
   </td>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:noWaves">
  <xsl:param name="root"/>
  <xsl:choose>
   <xsl:when test="count($root/m:waves/m:notAvailable|$root/m:waves/m:noWaves|$root/m:windWaves/m:notAvailable|$root/m:windWaves/m:noWaves|$root/m:swell/m:swellData/m:notAvailable|$root/m:swell/m:swellData/m:noWaves) = count($root/m:waves|$root/m:windWaves|$root/m:swell/m:swellData)">
    <xsl:value-of select="$trans/t:t[@o='calmSea']"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:t[@o='noWaves']"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:waves|m:windWaves|m:waveHeight">
  <tr>
  &src_string;
  &hdr_string;
  <td colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:apply-templates select="m:noWaves">
   <xsl:with-param name="root" select=".."/>
  </xsl:apply-templates>
  <xsl:if test="boolean(m:dir)">
   <xsl:apply-templates select="m:dir">
    <xsl:with-param name="hdr" select="'compassDirFrom'"/>
   </xsl:apply-templates>
   <xsl:if test="boolean(m:wavePeriod|m:seaConfused|m:height)">, </xsl:if>
  </xsl:if>
  <xsl:if test="boolean(m:wavePeriod)">
   <xsl:value-of select="concat($trans/t:t[@o='period'], ': ', m:wavePeriod/@v, $trans/t:units[@o='SEC'])"/>
  </xsl:if>
  <xsl:apply-templates select="m:seaConfused"/>
  <xsl:if test="boolean(m:height)">
   <xsl:if test="boolean(m:wavePeriod|m:seaConfused)">, </xsl:if>
   <xsl:value-of select="concat($trans/t:t[@o='height'], ': ')"/>
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:height"/>
   </xsl:call-template>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:swell">
  <xsl:variable name="rows" select="count(m:swellData)"/>
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:apply-templates select="m:swellData[1]"/>
  </tr>&nl;
  <xsl:if test="$rows = 2">
   <tr>
   &tab3;
   <xsl:apply-templates select="m:swellData[2]"/>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:swellData">
  <td colspan="2">
  <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
  <xsl:apply-templates select="m:noWaves">
   <xsl:with-param name="root" select="../.."/>
  </xsl:apply-templates>
  <xsl:if test="boolean(m:dir)">
   <xsl:apply-templates select="m:dir">
    <xsl:with-param name="hdr" select="'compassDirFrom'"/>
   </xsl:apply-templates>
   <xsl:if test="boolean(m:wavePeriod|m:seaConfused|m:height)">, </xsl:if>
  </xsl:if>
  <xsl:if test="boolean(m:wavePeriod)">
   <xsl:value-of select="concat($trans/t:t[@o='period'], ': ', m:wavePeriod/@v, $trans/t:units[@o='SEC'])"/>
  </xsl:if>
  <xsl:apply-templates select="m:seaConfused"/>
  <xsl:if test="boolean(m:height)">
   <xsl:if test="boolean(m:wavePeriod|m:seaConfused)">, </xsl:if>
   <xsl:value-of select="concat($trans/t:t[@o='height'], ': ')"/>
   <xsl:call-template name="unitConverter">
    <xsl:with-param name="val" select="m:height"/>
   </xsl:call-template>
  </xsl:if>
  </td>
 </xsl:template>

 <xsl:template match="m:snowCoverCharReg">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="2"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'snowCoverCharacter'"/>
  </xsl:call-template>
  <td colspan="2">
  <xsl:value-of select="$trans/t:snowCoverCharacter[@o=current()/m:snowCoverCharacter/@v]"/>
  </td>
  </tr>&nl;
  <tr>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'snowCoverRegularity'"/>
  </xsl:call-template>
  <td colspan="2">
  <xsl:value-of select="$trans/t:snowCoverRegularity[@o=current()/m:snowCoverRegularity/@v]"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:driftSnow">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="2"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'driftSnowData'"/>
  </xsl:call-template>
  <td colspan="2">
  <xsl:value-of select="$trans/t:driftSnowData[@o=current()/m:driftSnowData/@v]"/>
  </td>
  </tr>&nl;
  <tr>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'driftSnowEvolution'"/>
  </xsl:call-template>
  <td colspan="2">
  <xsl:value-of select="$trans/t:driftSnowEvolution[@o=current()/m:driftSnowEvolution/@v]"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:hoarFrost">
  <tr>
  &src_string;
  <td colspan="3">
  <xsl:apply-templates select="m:phenomDescr"/>
  <xsl:value-of select="concat(' ', $trans/t:hoarFrost[@o=current()/m:hoarFrostVal/@v])"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:colouredPrecip">
  <tr>
  &src_string;
  <td colspan="3">
  <xsl:apply-templates select="m:phenomDescr"/>
  <xsl:value-of select="concat(' ', $trans/t:colouredPrecip[@o=current()/m:colouredPrecipVal/@v])"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:continuousWind">
  <xsl:if test="not(boolean(following-sibling::m:continuousWind))">
   <xsl:apply-templates select="../m:continuousWind" mode="go"/>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:continuousWind" mode="go">
  <xsl:apply-templates select="m:wind">
   <xsl:with-param name="hdr">
    <xsl:value-of select="substring-before($trans/t:hdr[@o='continuousWind'], '|')"/>
    <xsl:value-of select="concat((position() - 1) * 10, ' .. ', position() * 10, $trans/t:units[@o='MIN'])"/>
    <xsl:value-of select="substring-after($trans/t:hdr[@o='continuousWind'], '|')"/>
   </xsl:with-param>
   <xsl:with-param name="s" select="@s"/>
  </xsl:apply-templates>
 </xsl:template>

 <xsl:template match="m:iceAccretion">
  <xsl:variable name="rows">
   <xsl:if test="boolean(m:iceAccretionRate)">3</xsl:if>
  </xsl:variable>
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <td nowrap="1">
   <xsl:if test="$rows > 1">
    <xsl:attribute name="valign">top</xsl:attribute>
    <xsl:attribute name="rowspan">
     <xsl:value-of select="$rows"/>
    </xsl:attribute>
   </xsl:if>
   <xsl:value-of select="substring-before($trans/t:hdr[@o='iceAccretion'], '|')"/>
   <xsl:apply-templates select="m:timeBeforeObs">
    <xsl:with-param name="pre" select="' '"/>
   </xsl:apply-templates>
   <xsl:value-of select="substring-after($trans/t:hdr[@o='iceAccretion'], '|')"/>
  </td>
  <xsl:choose>
   <xsl:when test="boolean(m:thicknessTraces)">
    <td colspan="2"><xsl:apply-templates select="m:thicknessTraces"/></td>
   </xsl:when>
   <xsl:when test="boolean(m:thickness)">
    <td>
     <xsl:call-template name="unitConverter">
      <xsl:with-param name="val" select="m:thickness"/>
     </xsl:call-template>
    </td>
    &tab5;
    <td>
     <xsl:choose>
      <xsl:when test="m:thickness/@u = 'CM'">
       <xsl:call-template name="unitConverter">
        <xsl:with-param name="val" select="m:thickness"/>
        <xsl:with-param name="unit" select="'IN'"/>
        <xsl:with-param name="factor" select="1"/>
        <xsl:with-param name="format" select="'0.#'"/>
       </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
       <xsl:call-template name="unitConverter">
        <xsl:with-param name="val" select="m:thickness"/>
        <xsl:with-param name="unit" select="'CM'"/>
        <xsl:with-param name="factor" select="1"/>
        <xsl:with-param name="format" select="'0.##'"/>
       </xsl:call-template>
      </xsl:otherwise>
     </xsl:choose>
    </td>
   </xsl:when>
   <xsl:when test="boolean(m:text)">
    <td colspan="2"><xsl:value-of select="m:text/@v"/></td>
   </xsl:when>
   <xsl:otherwise>
    <td colspan="2"><xsl:apply-templates select="m:notAvailable"/></td>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
  <xsl:if test="$rows = 3">
   <tr>
   &tab3;
   <td colspan="2">
   <xsl:value-of select="$trans/t:iceAccretionSource[@o=current()/m:iceAccretionSource/@v]"/>
   </td>
   </tr>&nl;
   <tr>
   &tab3;
   <td colspan="2">
   <xsl:value-of select="$trans/t:iceAccretionRate[@o=current()/m:iceAccretionRate/@v]"/>
   </td>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:seaLandIce">
  <xsl:variable name="noSeaIce">
   <xsl:if test="boolean(m:seaIceConcentration) and m:seaIceConcentration/@v = 0 and not(boolean(m:iceDevelopmentStage)) and boolean(m:iceOfLandOrigin) and not(boolean(m:iceEdgeBearing)) and boolean(m:iceConditionTrend) and m:iceConditionTrend/@v = 0">1</xsl:if>
  </xsl:variable>
  <xsl:variable name="rows">
   <xsl:choose>
    <xsl:when test="boolean(m:notAvailable|m:text)"></xsl:when>
    <xsl:when test="$noSeaIce = 1">2</xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="count(m:seaIceConcentration|m:iceDevelopmentStage|m:iceOfLandOrigin|m:iceEdgeBearing|m:iceConditionTrend)"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:variable>
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="rows" select="$rows"/>
  </xsl:call-template>
  <td colspan="2">
  <xsl:apply-templates select="*[1]"/>
  </td>
  </tr>&nl;
  <xsl:if test="$rows > 1">
   <tr>&tab3;<td colspan="2">
   <xsl:apply-templates select="*[2]"/>
   </td></tr>&nl;
  </xsl:if>
  <xsl:if test="$rows > 2">
   <tr>&tab3;<td colspan="2">
    <xsl:apply-templates select="*[3]"/>
   </td></tr>&nl;
  </xsl:if>
  <xsl:if test="$rows > 3">
   <tr>&tab3;<td colspan="2">
    <xsl:apply-templates select="*[4]"/>
   </td></tr>&nl;
  </xsl:if>
  <xsl:if test="$rows > 4">
   <tr>&tab3;<td colspan="2">
    <xsl:apply-templates select="*[5]"/>
   </td></tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:seaIceConcentration|m:iceDevelopmentStage|m:iceOfLandOrigin|m:iceEdgeBearing|m:iceConditionTrend">
  <xsl:choose>
   <xsl:when test="name() = 'seaIceConcentration'">
    <xsl:choose>
     <xsl:when test="../m:seaIceConcentration/@v = 1 and ../m:iceEdgeBearing/@v = 0">
      <xsl:value-of select="$trans/t:seaIceConcentration[@o='1-0']"/>
     </xsl:when>
     <xsl:when test="../m:seaIceConcentration/@v = 1 and ../m:iceEdgeBearing/@v = 9">
      <xsl:value-of select="$trans/t:seaIceConcentration[@o='1-9']"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="$trans/t:seaIceConcentration[@o=current()/@v]"/>
     </xsl:otherwise>
    </xsl:choose>
   </xsl:when>
   <xsl:when test="name() = 'iceDevelopmentStage'">
    <xsl:value-of select="$trans/t:iceDevelopmentStage[@o=current()/@v]"/>
   </xsl:when>
   <xsl:when test="name() = 'iceOfLandOrigin'">
    <xsl:value-of select="$trans/t:iceOfLandOrigin[@o=current()/@v]"/>
   </xsl:when>
   <xsl:when test="name() = 'iceEdgeBearing'">
    <xsl:value-of select="$trans/t:iceEdgeBearing[@o=current()/@v]"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:iceConditionTrend[@o=current()/@v]"/>
   </xsl:otherwise>
  </xsl:choose>
 </xsl:template>

 <xsl:template match="m:maxWindForce">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:value-of select="substring-before($trans/t:hdr[@o='maxWindForce'], '|')"/>
  <xsl:apply-templates select="m:timeBeforeObs">
   <xsl:with-param name="pre" select="' '"/>
  </xsl:apply-templates>
  <xsl:value-of select="substring-after($trans/t:hdr[@o='maxWindForce'], '|')"/>
  </td>
  <td colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:if test="boolean(m:windForce)">
   <xsl:value-of select="concat(m:windForce/@v, $trans/t:units[@o='bft'])"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:frozenDeposit">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="2"/>
  </xsl:call-template>
  &hdr_string;
  <td colspan="2">
  <xsl:choose>
   <xsl:when test="boolean(m:frozenDepositType)">
    <xsl:value-of select="$trans/t:frozenDepositType[@o=current()/m:frozenDepositType/@v]"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
  <tr>
  <td nowrap="1">
  <xsl:apply-templates select="m:timeBeforeObs">
   <xsl:with-param name="pre" select="' '"/>
   <xsl:with-param name="header" select="$trans/t:hdr[@o='tempVariation']"/>
  </xsl:apply-templates>
  </td>
  <td colspan="2">
  <xsl:choose>
   <xsl:when test="boolean(m:tempVariation)">
    <xsl:value-of select="$trans/t:tempVariation[@o=current()/m:tempVariation/@v]"/>
   </xsl:when>
   <xsl:otherwise>
    <xsl:value-of select="$trans/t:t[@o='notAvailable']"/>
   </xsl:otherwise>
  </xsl:choose>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:mirage">
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:value-of select="substring-before($trans/t:hdr[@o='mirage'], '|')"/>
  <xsl:apply-templates select="m:location">
   <xsl:with-param name="locOrDirBefore" select="substring-before($trans/t:t[@o='compassDirLocation'], '|')"/>
   <xsl:with-param name="locOrDirAfter" select="substring-after($trans/t:t[@o='compassDirLocation'], '|')"/>
  </xsl:apply-templates>
  <xsl:value-of select="substring-after($trans/t:hdr[@o='mirage'], '|')"/>
  </td>
  <td colspan="2">
  <xsl:value-of select="$trans/t:mirageType[@o=current()/m:mirageType/@v]"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:visibilityVariation">
  <xsl:variable name="hdr" select="$trans/t:hdr[@o='visibilityVariation']"/>
  <xsl:variable name="loc">
   <xsl:apply-templates select="m:location">
    <xsl:with-param name="locOrDirBefore" select="substring-before($trans/t:t[@o='compassDirTo'], '|')"/>
    <xsl:with-param name="locOrDirAfter" select="substring-after($trans/t:t[@o='compassDirTo'], '|')"/>
   </xsl:apply-templates>
  </xsl:variable>
  <tr>
  &src_string;
  <td nowrap="1">
  <xsl:apply-templates select="m:timeBeforeObs">
   <xsl:with-param name="pre" select="' '"/>
   <xsl:with-param name="header" select="concat(substring-before($hdr, '|'), $loc, '|', substring-after($hdr, '|'))"/>
  </xsl:apply-templates>
  </td>
  <td colspan="2">
  <xsl:value-of select="$trans/t:visibilityVariation[@o=current()/m:visibilityVariationVal/@v]"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:cloudFrom|m:lowCloudFrom">
  <tr>
  &src_string;
  <td nowrap="1" colspan="3">
  <xsl:apply-templates select="m:notAvailable|m:invalidFormat|m:cloudType|m:cloudTypeLow"/>
  <xsl:apply-templates select="m:compassDir">
   <xsl:with-param name="pre" select="concat(substring-before($trans/t:t[@o='approaching'], '|'), substring-before($trans/t:t[@o='compassDirFrom'], '|'))"/>
   <xsl:with-param name="post" select="concat(substring-after($trans/t:t[@o='compassDirFrom'], '|'), substring-after($trans/t:t[@o='approaching'], '|'))"/>
  </xsl:apply-templates>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:qualitySection">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
  <xsl:if test="boolean(m:qualityControlInd)">
   <xsl:choose>
    <xsl:when test="boolean(m:worstQualityGroup)">
     <xsl:value-of select="$trans/t:qualityControlInd[@o = 1]"/>
     <xsl:value-of select="substring-before($trans/t:t[@o='dataQualityExcept'], '|')"/>
     <xsl:value-of select="m:worstQualityGroup/@v"/>
     <xsl:value-of select="substring-after($trans/t:t[@o='dataQualityExcept'], '|')"/>
     <xsl:value-of select="$trans/t:qualityControlInd[@o = current()/m:qualityControlInd/@v]"/>
    </xsl:when>
    <xsl:when test="m:qualityControlInd/@v &lt;= 1">
     <xsl:value-of select="$trans/t:qualityControlInd[@o = current()/m:qualityControlInd/@v]"/>
    </xsl:when>
    <xsl:otherwise>
     <xsl:value-of select="substring-before($trans/t:t[@o='dataQualityAllOrBetter'], '|')"/>
     <xsl:value-of select="$trans/t:qualityControlInd[@o = current()/m:qualityControlInd/@v]"/>
     <xsl:value-of select="substring-after($trans/t:t[@o='dataQualityAllOrBetter'], '|')"/>
    </xsl:otherwise>
   </xsl:choose>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:qualityLocClass">
  <tr>
  <td nowrap="1">
  <xsl:variable name="hdr" select="$trans/t:hdr[@o='qualityLocClass']"/>
  <xsl:value-of select="substring-before($hdr, '|')"/>
  <xsl:if test="boolean(m:distanceFrom)">
   <xsl:value-of select="$trans/t:t[@o='range-from']"/>
  </xsl:if>
  <xsl:value-of select="substring-after($hdr, '|')"/>
  </td>
  <xsl:choose>
   <xsl:when test="boolean(m:notAvailable|m:invalidFormat)">
    <td colspan="2">
    <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
    </td>
   </xsl:when>
   <xsl:otherwise>
    <xsl:apply-templates select="*[1]"/>
   </xsl:otherwise>
  </xsl:choose>
  </tr>&nl;
  <xsl:if test="count(*) = 2">
   <tr>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'to'"/>
   </xsl:call-template>
   <xsl:apply-templates select="*[2]"/>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:qualityPositionTime">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(m:qualityLocClass/*) + 2"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'qualityControlPosition'"/>
  </xsl:call-template>
  <td colspan="2">
  <xsl:apply-templates select="m:qualityControlPosition/m:notAvailable|m:qualityControlPosition/m:invalidFormat"/>
  <xsl:if test="boolean(m:qualityControlPosition/m:qualityControlInd)">
   <xsl:value-of select="$trans/t:qualityControlInd[@o = current()/m:qualityControlPosition/m:qualityControlInd/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
  <tr>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'qualityControlTime'"/>
  </xsl:call-template>
  <td colspan="2">
  <xsl:apply-templates select="m:qualityControlTime/m:notAvailable|m:qualityControlTime/m:invalidFormat"/>
  <xsl:if test="boolean(m:qualityControlTime/m:qualityControlInd)">
   <xsl:value-of select="$trans/t:qualityControlInd[@o = current()/m:qualityControlTime/m:qualityControlInd/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
  <xsl:apply-templates select="m:qualityLocClass"/>
 </xsl:template>

 <xsl:template match="m:qualityLocClass/m:distance|m:qualityLocClass/m:distanceFrom|m:qualityLocClass/m:distanceTo">
  <td nowrap="1">
  <xsl:call-template name="unitConverter">
   <xsl:with-param name="val" select="."/>
  </xsl:call-template>
  </td>
  &tab4;
  <td nowrap="1">
  <xsl:call-template name="unitConverter">
   <xsl:with-param name="val" select="."/>
   <xsl:with-param name="unit" select="'FT'"/>
   <xsl:with-param name="factor" select="10"/>
   <xsl:with-param name="format" select="'0'"/>
  </xsl:call-template>
  </td>
 </xsl:template>

 <xsl:template match="m:qualityHousekeeping|m:qualityWaterTemp|m:qualityAirTemp">
  <tr>
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:value-of select="$trans/t:qualityInd[@o = current()/@v]"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:qualityGroup1">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(*)"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name">
    <xsl:choose>
     <xsl:when test="boolean(m:invalidFormat)">qualityData</xsl:when>
     <xsl:otherwise>qualityPressure</xsl:otherwise>
    </xsl:choose>
   </xsl:with-param>
  </xsl:call-template>
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:invalidFormat"/>
  <xsl:value-of select="$trans/t:qualityInd[@o = current()/m:qualityPressure/@v]"/>
  </td>
  </tr>&nl;
  <xsl:apply-templates select="m:qualityHousekeeping"/>
  <xsl:apply-templates select="m:qualityWaterTemp"/>
  <xsl:apply-templates select="m:qualityAirTemp"/>
 </xsl:template>

 <xsl:template match="m:qualityGroup2">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(*) + count(m:qualityLocClass/m:distanceFrom)"/>
  </xsl:call-template>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'qualityTransmission'"/>
  </xsl:call-template>
  <td nowrap="1" colspan="2">
  <xsl:value-of select="$trans/t:qualityTransmission[@o = current()/m:qualityTransmission/@v]"/>
  </td>
  </tr>&nl;
  <tr>
  <xsl:call-template name="hdr_string">
   <xsl:with-param name="hdr_name" select="'qualityLocation'"/>
  </xsl:call-template>
  <td nowrap="1" colspan="2">
  <xsl:value-of select="$trans/t:qualityLocation[@o = current()/m:qualityLocation/@v]"/>
  </td>
  </tr>&nl;
  <xsl:apply-templates select="m:qualityLocClass"/>
  <xsl:if test="boolean(m:depthCorrectionInd)">
   <tr>
   <xsl:call-template name="hdr_string">
    <xsl:with-param name="hdr_name" select="'depthCorrectionInd'"/>
   </xsl:call-template>
   <td nowrap="1" colspan="2">
   <xsl:value-of select="$trans/t:depthCorrectionInd[@o = current()/m:depthCorrectionInd/@v]"/>
   </td>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:qualityTempSalProfile|m:qualityCurrentProfile">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
  <xsl:if test="boolean(m:qualityControlInd)">
   <xsl:value-of select="$trans/t:qualityControlInd[@o = current()/m:qualityControlInd/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:salinityMeasurement">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
  <xsl:if test="boolean(m:salinityMeasurementInd)">
   <xsl:value-of select="$trans/t:salinityMeasurementInd[@o = current()/m:salinityMeasurementInd/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:waterTempSalDepth|m:waterCurrent">
  <tr>
  <xsl:call-template name="src_string">
   <xsl:with-param name="rows" select="count(*)"/>
  </xsl:call-template>
  <td nowrap="1" colspan="3">
  <xsl:value-of select="concat(substring-before($trans/t:t[@o='atDepth'], '|'), m:depth/@v, $trans/t:units[@o=current()/m:depth/@u], substring-after($trans/t:t[@o='atDepth'], '|'))"/>
  </td>
  </tr>&nl;
  <xsl:if test="boolean(m:temp)">
   <tr>
   <xsl:call-template name="printTemp">
    <xsl:with-param name="hdr">
     <xsl:value-of select="concat(substring-before($trans/t:hdr[@o='waterTemp'], '|'), substring-after($trans/t:hdr[@o='waterTemp'], '|'))"/>
     </xsl:with-param>
    <xsl:with-param name="temp" select="."/>
   </xsl:call-template>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:salinity)">
   <tr>
   <td nowrap="1">
   <xsl:value-of select="$trans/t:hdr[@o='salinity']"/>
   </td>
   <td nowrap="1" colspan="2">
   <xsl:value-of select="m:salinity/@v"/>
   <xsl:text> %</xsl:text>
   </td>
   </tr>&nl;
  </xsl:if>
  <xsl:if test="boolean(m:current)">
   <xsl:variable name="dir">
    <xsl:apply-templates select="m:current/m:dir|m:current/m:dirVarAllUnk">
     <xsl:with-param name="hdr" select="'wind-from'"/>
    </xsl:apply-templates>
   </xsl:variable>
   <tr>
   <td nowrap="1">
   <xsl:value-of select="$trans/t:hdr[@o='current']"/>
   </td>
   <td nowrap="1" colspan="2">
   <xsl:apply-templates select="m:current/m:invalidFormat"/>
   <xsl:if test="boolean(m:current/m:speedNotAvailable)">
    <xsl:value-of select="concat($dir, ', ', $trans/t:t[@o='speedNotAvailable'])"/>
   </xsl:if>
   <xsl:if test="boolean(m:current/m:speed)">
    <xsl:value-of select="concat($dir, ' ', $trans/t:t[@o='wind-at'], ' ', m:current/m:speed/@v, $trans/t:units[@o=current()/m:current/m:speed/@u])"/>
   </xsl:if>
   </td>
   </tr>&nl;
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:buoyType">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
  <xsl:if test="boolean(m:buoyTypeInd)">
   <xsl:value-of select="$trans/t:buoyTypeInd[@o = current()/m:buoyTypeInd/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:drogueType">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
  <xsl:if test="boolean(m:drogueTypeInd)">
   <xsl:value-of select="$trans/t:drogueTypeInd[@o = current()/m:drogueTypeInd/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:anemometer">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:if test="boolean(m:anemometerType/m:anemometerTypeInd)">
   <xsl:value-of select="concat($trans/t:anemometerTypeInd[@o = current()/m:anemometerType/m:anemometerTypeInd/@v], ', ')"/>
  </xsl:if>
  <xsl:value-of select="concat($trans/t:t[@o='height'], ': ', m:sensorHeight/@v, $trans/t:units[@o=current()/m:sensorHeight/@u])"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:pressureCableEnd">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:value-of select="concat(m:pressure/@v, $trans/t:units[@o=current()/m:pressure/@u])"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:batteryVoltage">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:if test="boolean(m:batteryVoltageVal)">
   <xsl:value-of select="concat(m:batteryVoltageVal/@v, $trans/t:units[@o='V'])"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:submergence">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:if test="boolean(m:submergenceVal)">
   <xsl:value-of select="concat(m:submergenceVal/@v, ' %')"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:cableLengthThermistor|m:cableLengthDrogue">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:if test="boolean(m:length)">
   <xsl:value-of select="concat(m:length/@v, $trans/t:units[@o=current()/m:length/@u])"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:measurementDurTime">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
  <xsl:if test="boolean(m:measurementDurTimeInd)">
   <xsl:value-of select="$trans/t:measurementDurTimeInd[@o = current()/m:measurementDurTimeInd/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:measurementCorrection">
  <tr>
  &src_string;
  &hdr_string;
  <td colspan="2">
  <xsl:apply-templates select="m:notAvailable|m:invalidFormat"/>
  <xsl:if test="boolean(m:measurementCorrectionInd)">
   <xsl:value-of select="$trans/t:measurementCorrectionInd[@o = current()/m:measurementCorrectionInd/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:buoyDrift">
  <xsl:variable name="dir">
   <xsl:apply-templates select="m:drift/m:dir|m:drift/m:dirVarAllUnk">
    <xsl:with-param name="hdr" select="'compassDirTo'"/>
   </xsl:apply-templates>
  </xsl:variable>
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:value-of select="concat($dir, ' ', $trans/t:t[@o='wind-at'], ' ', m:drift/m:speed/@v, $trans/t:units[@o=current()/m:drift/m:speed/@u])"/>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:phaseOfFlight">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:if test="boolean(m:phaseOfFlightVal)">
   <xsl:value-of select="$trans/t:phaseOfFlight[@o=current()/m:phaseOfFlightVal/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <!-- combine all amdarObs nodes into one set and process them in one go -->
 <xsl:template match="m:amdarObs">
  <xsl:apply-templates select="../m:amdarObs" mode="go"/>
 </xsl:template>

 <xsl:template match="m:amdarObs" mode="go">
  &nl;
  <tr>
  <td></td>
  <td nowrap="1" colspan="3"><b>
  <xsl:value-of select="$trans/t:hdr[@o='amdarObs']"/>
  <xsl:if test="$method != 'html'">
   &nl;
   <xsl:value-of select="$trans/t:hdr[@o='amdarObs_ul']"/>
  </xsl:if>
  </b></td>
  </tr>&nl;
  <xsl:apply-templates select="*"/>
  <xsl:if test="position() = last() and boolean(following-sibling::*)">
   &nl;
   <tr><td/><td colspan="3"><hr/></td></tr>
  </xsl:if>
 </xsl:template>

 <xsl:template match="m:rollAngleQuality">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:if test="boolean(m:rollAngleQualityVal)">
   <xsl:value-of select="$trans/t:rollAngleQualityVal[@o=current()/m:rollAngleQualityVal/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:turbulenceAtPA">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:if test="boolean(m:turbulenceDescr)">
   <xsl:value-of select="$trans/t:turbulenceDescr[@o=current()/m:turbulenceDescr/@v]"/>
  </xsl:if>
  <xsl:if test="boolean(m:turbulenceVal)">
   <xsl:value-of select="$trans/t:turbulenceVal[@o=current()/m:turbulenceVal/@v]"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:flightLvl">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:apply-templates select="m:notAvailable"/>
  <xsl:if test="boolean(m:level)">
   <xsl:value-of select="concat('FL ', format-number(m:level/@v, '000'), ' (', format-number(m:level/@v * 100, '0'), $trans/t:units[@o='FT'], ')')"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>

 <xsl:template match="m:amdarInfo">
  <tr>
  &src_string;
  &hdr_string;
  <td nowrap="1" colspan="2">
  <xsl:if test="boolean(m:notAvailable)">
   <xsl:apply-templates select="m:notAvailable"/>
  </xsl:if>
  <xsl:if test="boolean(m:navSystem)">
   <xsl:value-of select="concat(substring-before($trans/t:t[@o='navSystem'], '|'), $trans/t:navSystem[@o=current()/m:navSystem/@v], substring-after($trans/t:t[@o='navSystem'], '|'))"/>
  </xsl:if>
  <xsl:if test="boolean(m:amdarSystem)">
   <xsl:if test="boolean(m:navSystem)">
    <br />
    <xsl:if test="$method != 'html'">&nl;&tab3;</xsl:if>
   </xsl:if>
   <xsl:value-of select="concat(substring-before($trans/t:t[@o='amdarSystem'], '|'), $trans/t:amdarSystem[@o=current()/m:amdarSystem/@v], substring-after($trans/t:t[@o='amdarSystem'], '|'))"/>
  </xsl:if>
  <xsl:if test="boolean(m:tempPrecision)">
   <xsl:if test="boolean(m:navSystem|m:amdarSystem)">
    <br />
    <xsl:if test="$method != 'html'">&nl;&tab3;</xsl:if>
   </xsl:if>
   <xsl:value-of select="concat(substring-before($trans/t:t[@o='tempPrecision'], '|'), m:tempPrecision/@v, ' °C', substring-after($trans/t:t[@o='tempPrecision'], '|'))"/>
  </xsl:if>
  </td>
  </tr>&nl;
 </xsl:template>
</xsl:stylesheet>
