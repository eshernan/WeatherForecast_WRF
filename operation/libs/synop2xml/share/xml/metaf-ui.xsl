<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet
    xmlns:xsl = "http://www.w3.org/1999/XSL/Transform"
    xmlns:m = "http://metaf2xml.sourceforge.net/2.1"
    xmlns:t = "http://metaf2xml.sourceforge.net/2.1"
    exclude-result-prefixes = "m"
    version = "1.0">

 <xsl:template match="data">
  <html lang="{$lang_used}">
  <xsl:choose>
   <xsl:when test="not(boolean(m:reports)) or not(boolean($trans))">
  <head>
  <title>ERROR</title>
  </head>
  <body>
   <p><b>
    <xsl:choose>
     <xsl:when test="not(boolean(*))">ERROR in XML: invalid document structure</xsl:when>
     <xsl:when test="not(boolean(m:reports))">
      <xsl:value-of select="concat('ERROR: versions differ: XML: ', namespace-uri(*[last()]), ', metaf-ui.xsl: http://metaf2xml.sourceforge.net/2.1')"/>
     </xsl:when>
     <xsl:when test="not(boolean(document($lang_used_xml)/trans))">
      <xsl:value-of select="concat('ERROR in ', $lang_used_xml, ': invalid document structure')"/>
     </xsl:when>
     <xsl:otherwise>
      <xsl:value-of select="concat('ERROR: versions differ: ', $lang_used_xml, ': ', namespace-uri(document($lang_used_xml)/trans/*[1]), ', metaf.xsl: http://metaf2xml.sourceforge.net/2.1')"/>
     </xsl:otherwise>
    </xsl:choose>
   </b></p>
   <xsl:text>&#10;</xsl:text>
  </body>
   </xsl:when>
   <xsl:otherwise>
  <head>
  <title><xsl:value-of select="$trans/t:cgi[@o='title']"/></title>
  <meta name="keywords"
      content="metaf2xml,parse,decode,METAR,SPECI,SAO,TAF,SYNOP,BUOY,AMDAR,BUFR,XML,aviation,weather,report,forecast"/>
  <meta name="robots" content="noindex,nofollow"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <link rel="shortcut icon" type="image/x-icon" href="../images/metaf2xml.ico"/>
  <link rel="stylesheet"    type="text/css"     href="../metaf2xml.css"/>
  </head>
  <body lang="{$lang_used}">
  <h1><xsl:value-of select="$trans/t:cgi[@o='title']"/></h1>
  <p>
  <xsl:value-of select="$trans/t:cgi[@o='infosrc']"/>
  <xsl:text>: </xsl:text>
  <kbd>http://aviationweather.gov/dataserver</kbd>
  </p>
  <p>
  <xsl:value-of select="$trans/t:cgi[@o='infofetch']"/>
  </p>
  <form method="GET" action="metaf.pl">

<table border="0" cellspacing="0">

<tr><td colspan="5"><hr /></td></tr>

<tr>
<td colspan="5">
<strong><xsl:value-of select="$trans/t:cgi[@o='options']"/></strong>
</td>
</tr>

<tr>
<td nowrap="1"><xsl:value-of select="$trans/t:cgi[@o='language']"/></td>
<td>
 <input type="radio" name="lang" value="de">
  <xsl:if test="$lang_used = 'de'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:text>Deutsch</xsl:text>
</td>
<td>
 <input type="radio" name="lang" value="en">
  <xsl:if test="$lang_used = 'en'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:text>English</xsl:text>
</td>
<td>
 <input type="radio" name="lang" value="es">
  <xsl:if test="$lang_used = 'es'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:text>Español</xsl:text>
</td>
<td>
 <input type="radio" name="lang" value="ru">
  <xsl:if test="$lang_used = 'ru'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:text>Русский</xsl:text>
</td>
</tr>

<tr>
<td nowrap="1"><xsl:value-of select="$trans/t:cgi[@o='format']"/></td>
<td>
 <input type="radio" name="format" value="html">
  <xsl:if test="not(options/@format = 'text' or options/@format = 'xml')">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='format1']"/>
</td>
<td>
 <input type="radio" name="format" value="text">
  <xsl:if test="options/@format = 'text'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='format2']"/>
</td>
<td colspan="2">
 <input type="radio" name="format" value="xml">
  <xsl:if test="options/@format = 'xml'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='format3']"/>
</td>
</tr>

<tr>
<td nowrap="1"><xsl:value-of select="$trans/t:cgi[@o='mode']"/></td>
<td nowrap="1">
 <input type="radio" name="mode" value="latest">
  <xsl:if test="not(options/@mode = 'summary')">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='mode1']"/>
</td>

<td colspan="3" nowrap="1">
 <input type="radio" name="mode" value="summary">
  <xsl:if test="options/@mode = 'summary'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='mode2']"/>
 <input type="text" name="hours" size="3" maxlength="3" class="mono" value="{options/@hours}"/>
 <xsl:value-of select="$trans/t:cgi[@o='hours']"/>
</td>
</tr>
</table>

<table border="0" cellspacing="0" width="100%">

<tr><td colspan="2"><hr /></td></tr>

<tr>
<td valign="top" rowspan="3">
<strong>METAR, TAF </strong>
<xsl:value-of select="$trans/t:cgi[@o='example']"/>
</td>
<td class="mono">METAR YUDO 090600Z 00000KT CAVOK 22/15 Q1021 NOSIG</td>
</tr>

<tr>
<td class="mono">TAF YUDO 090600Z 0907/0916 VRB03KT 8000 SKC PROB40 TEMPO 0907/0908 0200 +TSRA FM090800 CAVOK</td>
</tr>

<tr>
<td class="mono">TAF YUDO 090600Z 090716 VRB03KT 8000 SKC PROB40 TEMPO 0708 0200 +TSRA FM0800 CAVOK</td>
</tr>

<tr>
<td nowrap="1">
 <input type="radio" name="type_metaf" value="metar">
  <xsl:if test="not(options/@type_metaf = 'taf' or options/@type_metaf = 'icao')">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='type1']"/>
 <br/>
 <input type="radio" name="type_metaf" value="taf">
  <xsl:if test="options/@type_metaf = 'taf'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='type2']"/>
 <br/>
 <input type="radio" name="type_metaf" value="icao">
  <xsl:if test="options/@type_metaf = 'icao'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='type4']"/>
</td>

<td valign="bottom">
 <input type="text" name="msg_metaf" size="80" maxlength="2000" class="mono" value="{options/@msg_metaf}"/>
</td>
</tr>

<tr>
<td nowrap="1" align="right">
<xsl:value-of select="$trans/t:cgi[@o='source']"/>
</td>

<td>
 <input type="radio" name="src_metaf" value="noaa">
  <xsl:if test="not(options/@src_metaf = 'adds' or options/@src_metaf = 'nws' or options/@src_metaf = 'addsds' or options/@src_metaf = 'ogimet' or options/@src_metaf = 'local')">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
  <xsl:if test="options/@src_metaf = 'local'">
   <xsl:attribute name="disabled">1</xsl:attribute>
   <xsl:attribute name="readonly">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='source1']"/>

 <input type="radio" name="src_metaf" value="nws">
  <xsl:if test="options/@src_metaf = 'nws'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
  <xsl:if test="options/@src_metaf = 'local'">
   <xsl:attribute name="disabled">1</xsl:attribute>
   <xsl:attribute name="readonly">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='source4']"/>

 <input type="radio" name="src_metaf" value="adds">
  <xsl:if test="options/@src_metaf = 'adds'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
  <xsl:if test="options/@src_metaf = 'local'">
   <xsl:attribute name="disabled">1</xsl:attribute>
   <xsl:attribute name="readonly">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='source2']"/>

 <input type="radio" name="src_metaf" value="addsds">
  <xsl:if test="options/@src_metaf = 'addsds'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
  <xsl:if test="options/@src_metaf = 'local'">
   <xsl:attribute name="disabled">1</xsl:attribute>
   <xsl:attribute name="readonly">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='source3']"/>

 <input type="radio" name="src_metaf" value="ogimet">
  <xsl:if test="options/@src_metaf = 'ogimet'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
  <xsl:if test="options/@src_metaf = 'local'">
   <xsl:attribute name="disabled">1</xsl:attribute>
   <xsl:attribute name="readonly">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='source6']"/>
</td>
</tr>

<tr><td colspan="2"><hr /></td></tr>

<tr>
<td valign="top" rowspan="3">
<strong>SYNOP </strong>
<xsl:value-of select="$trans/t:cgi[@o='example']"/>
</td>
<td class="mono">AAXX 09004 08495 11459 30714 10147 20136 30151 40159 58005 60001 70511 83500 92350</td>
</tr>

<tr>
<td class="mono">BBXX UIDS 18061 99613 70284 41698 61806 10000 40107 57020 70121 86//8 22271 00064</td>
</tr>

<tr>
<td class="mono">OOXX AAERC 10104 99815 31639 60713 00451 46/// /1511 11185 39739 49798 5//// 90940</td>
</tr>

<tr>
<td nowrap="1">
 <input type="radio" name="type_synop" value="synop">
  <xsl:if test="not(options/@type_synop = 'wmo')">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='type3']"/>
 <br/>
 <input type="radio" name="type_synop" value="wmo">
  <xsl:if test="options/@type_synop = 'wmo'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='type7']"/>
 <br/>
 <input type="radio" name="type_synop" value="ship">
  <xsl:if test="options/@type_synop = 'ship'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='type8']"/>
 <br/>
 <input type="radio" name="type_synop" value="mobil">
  <xsl:if test="options/@type_synop = 'mobil'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='type9']"/>

</td>

<td valign="bottom">
 <input type="text" name="msg_synop" size="80" maxlength="2000" class="mono" value="{options/@msg_synop}"/>
</td>
</tr>

<tr>
<td nowrap="1" align="right">
<xsl:value-of select="$trans/t:cgi[@o='source']"/>
</td>

<td>
 <input type="radio" name="src_synop" value="nws">
  <xsl:if test="not(options/@src_synop = 'cod' or options/@src_synop = 'ogimet' or options/@src_synop = 'local')">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
  <xsl:if test="options/@src_synop = 'local'">
   <xsl:attribute name="disabled">1</xsl:attribute>
   <xsl:attribute name="readonly">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='source4']"/>

 <input type="radio" name="src_synop" value="cod">
  <xsl:if test="options/@src_synop = 'cod'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
  <xsl:if test="options/@src_synop = 'local'">
   <xsl:attribute name="disabled">1</xsl:attribute>
   <xsl:attribute name="readonly">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='source5']"/>

 <input type="radio" name="src_synop" value="ogimet">
  <xsl:if test="options/@src_synop = 'ogimet'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
  <xsl:if test="options/@src_synop = 'local'">
   <xsl:attribute name="disabled">1</xsl:attribute>
   <xsl:attribute name="readonly">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='source6']"/>
</td>
</tr>

<tr><td colspan="2"><hr /></td></tr>

<tr>
<td valign="top" rowspan="1">
<strong>BUOY </strong>
<xsl:value-of select="$trans/t:cgi[@o='example']"/>
</td>
<td class="mono">ZZYY 47503 02031 2206/ 769820 097173 6112/ 444 20120 02031 2201/ 500// 9/000</td>
</tr>

<tr>
<td nowrap="1">
 <input type="radio" name="type_buoy" value="buoy">
  <xsl:if test="not(options/@type_buoy = 'wmo')">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='type3']"/>
 <br/>
 <input type="radio" name="type_buoy" value="wmo">
  <xsl:if test="options/@type_buoy = 'wmo'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='type5']"/>
</td>

<td valign="bottom">
 <input type="text" name="msg_buoy" size="80" maxlength="2000" class="mono" value="{options/@msg_buoy}"/>
</td>
</tr>

<tr>
<td nowrap="1" align="right">
<xsl:value-of select="$trans/t:cgi[@o='source']"/>
</td>

<td>
 <input type="radio" name="src_buoy" value="nws">
  <xsl:if test="not(options/@src_buoy = 'ogimet' or options/@src_buoy = 'local')">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
  <xsl:if test="options/@src_buoy = 'local'">
   <xsl:attribute name="disabled">1</xsl:attribute>
   <xsl:attribute name="readonly">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='source4']"/>

 <input type="radio" name="src_buoy" value="ogimet">
  <xsl:if test="options/@src_buoy = 'ogimet'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
  <xsl:if test="options/@src_buoy = 'local'">
   <xsl:attribute name="disabled">1</xsl:attribute>
   <xsl:attribute name="readonly">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='source6']"/>
</td>
</tr>

<tr><td colspan="2"><hr /></td></tr>

<tr>
<td valign="top" rowspan="1">
<strong>AMDAR </strong>
<xsl:value-of select="$trans/t:cgi[@o='example']"/>
</td>
<td class="mono">AMDAR 1605 ASC AFZA51 2624S 02759E 160414 F156 MS048 278/034 TB0 S031 333 F/// VG010</td>
</tr>

<tr>
<td nowrap="1">
 <input type="radio" name="type_amdar" value="amdar">
  <xsl:if test="not(options/@type_amdar = 'ac')">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='type3']"/>
 <br/>
 <input type="radio" name="type_amdar" value="ac">
  <xsl:if test="options/@type_amdar = 'ac'">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='type11']"/>
</td>

<td valign="bottom">
 <input type="text" name="msg_amdar" size="80" maxlength="2000" class="mono" value="{options/@msg_amdar}"/>
</td>
</tr>

<tr>
<td nowrap="1" align="right">
<xsl:value-of select="$trans/t:cgi[@o='source']"/>
</td>

<td>
 <input type="radio" name="src_amdar" value="nws">
  <xsl:if test="not(options/@src_amdar = 'local')">
   <xsl:attribute name="checked">1</xsl:attribute>
  </xsl:if>
  <xsl:if test="options/@src_amdar = 'local'">
   <xsl:attribute name="disabled">1</xsl:attribute>
   <xsl:attribute name="readonly">1</xsl:attribute>
  </xsl:if>
 </input>
 <xsl:value-of select="$trans/t:cgi[@o='source4']"/>
</td>
</tr>

<tr><td colspan="2"><hr /></td></tr>

<tr>
<td colspan="2">
 <input type="submit" class="button" value="{$trans/t:cgi[@o='decode']}"/>
</td>
</tr>

</table>

  </form>
  <div class="output">
  <xsl:apply-templates select="m:reports"/>
  </div>
  <p>copyright (c) 2006-2016 metaf2xml @ <a href="http://metaf2xml.sourceforge.net/">
  SourceForge.net
  </a></p>
  </body>
   </xsl:otherwise>
  </xsl:choose>
  </html>
 </xsl:template>

</xsl:stylesheet>
