<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:t="http://www.tei-c.org/ns/1.0" xmlns:s="http://syriaca.org" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:saxon="http://saxon.sf.net/" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:local="http://syriaca.org/ns" xmlns:x="http://www.w3.org/1999/xhtml" exclude-result-prefixes="xs t s saxon" version="2.0">

 <!-- ================================================================== 
       Copyright 2013 New York University
       
       This file is part of the Syriac Reference Portal Places Application.
       
       The Syriac Reference Portal Places Application is free software: 
       you can redistribute it and/or modify it under the terms of the GNU 
       General Public License as published by the Free Software Foundation, 
       either version 3 of the License, or (at your option) any later 
       version.
       
       The Syriac Reference Portal Places Application is distributed in 
       the hope that it will be useful, but WITHOUT ANY WARRANTY; without 
       even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
       PARTICULAR PURPOSE.  See the GNU General Public License for more 
       details.
       
       You should have received a copy of the GNU General Public License
       along with the Syriac Reference Portal Places Application.  If not,
       see (http://www.gnu.org/licenses/).
       
       ================================================================== --> 
 
 <!-- ================================================================== 
       tei2html.xsl
       
       This XSLT transforms tei.xml to html.
       
       parameters:

        
       code by: 
        + Winona Salesky (wsalesky@gmail.com)
          for use with eXist-db
        + Tom Elliott (http://www.paregorios.org) 
          for the Institute for the Study of the Ancient World, New York
          University, under contract to Vanderbilt University for the
          NEH-funded Syriac Reference Portal project.
        + Winona Salesky for use with eXist-db
          
       funding provided by:
        + National Endowment for the Humanities (http://www.neh.gov). Any 
          views, findings, conclusions, or recommendations expressed in 
          this code do not necessarily reflect those of the National 
          Endowment for the Humanities.
       
       ================================================================== -->
 <!-- =================================================================== -->
 <!-- import component stylesheets for HTML page portions -->
 <!-- =================================================================== -->
    <xsl:import href="helper-functions.xsl"/>
    <xsl:import href="link-icons.xsl"/>
    <xsl:import href="citation.xsl"/>
    <xsl:import href="bibliography.xsl"/>
    <xsl:import href="json-uri.xsl"/>
    <xsl:import href="langattr.xsl"/>
    <xsl:import href="collations.xsl"/>
    
 <!-- =================================================================== -->
 <!-- set output so we get (mostly) indented HTML -->
 <!-- =================================================================== -->
    <xsl:output name="html" encoding="UTF-8" method="xhtml" indent="no"/>

 <!-- =================================================================== -->
 <!--  initialize top-level variables and transform parameters -->
 <!--  sourcedir: where to look for XML files to summarize/link to -->
 <!--  description: a meta description for the HTML page we will output -->
 <!--  name-app: name of the application (for use in head/title) -->
 <!--  name-page-short: short name of the page (for use in head/title) -->
 <!--  colquery: constructed variable with query for collection fn. -->
 <!-- =================================================================== -->
    <xsl:param name="normalization">NFKC</xsl:param>
    <!--<xsl:param name="xmlbase">/db/apps/srophe/data/places/tei/xml/</xsl:param>-->
    <xsl:param name="editoruriprefix">http://syriaca.org/editors.xml#</xsl:param>
    <xsl:variable name="editorssourcedoc">/db/apps/srophe/documentation/editors.xml</xsl:variable>
    <!--<xsl:param name="uribase">http://syriaca.org/</xsl:param>-->
    <xsl:variable name="resource-id">
        <xsl:choose>
            <xsl:when test="string(/*/@id)">
                <xsl:value-of select="string(/*/@id)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="starts-with(//idno[@URI],'http://syriaca.org/')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
 <!-- =================================================================== -->
 <!-- TEMPLATES -->
 <!-- =================================================================== -->


 <!-- ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||| -->
 <!-- |||| Root template matches tei root -->
 <!-- ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||| -->
    <xsl:template match="/">
        <xsl:apply-templates/>
    </xsl:template>

    <!-- Manuscript templates -->
    <xsl:template match="t:msPart">
        <div class="row">
            <xsl:if test="t:msIdentifier">
                <h3>
                    <xsl:apply-templates select="t:altIdentifier"/>
                </h3>
                <h4>
                    <xsl:apply-templates select="t:idno"/>
                </h4>
            </xsl:if>
            <xsl:choose>
                <xsl:when test="t:physDesc">
                    <div class="col-md-4">
                        <xsl:apply-templates select="t:physDesc"/>
                    </div>
                    <div class="col-md-8">
                        <xsl:apply-templates select="*[not(self::t:physDesc)]"/>
                    </div>
                </xsl:when>
                <xsl:otherwise>
                    <div class="col-md-12">
                        <xsl:apply-templates/>
                    </div>
                </xsl:otherwise>
            </xsl:choose>
        </div>
    </xsl:template>
    <xsl:template match="t:msIdentifier">
        <h4>Current location: </h4>
        <div class="msItem">
            <xsl:value-of select="t:country"/>
            <xsl:if test="t:country/following-sibling::*"> - </xsl:if>
            <xsl:value-of select="t:settlement"/>
            <xsl:if test="t:settlement/following-sibling::*"> - </xsl:if>
            <xsl:value-of select="t:repository"/>
            <xsl:if test="t:repository/following-sibling::*"> - </xsl:if>
            <xsl:value-of select="t:collection"/>
        </div>
        <h4>Identification</h4>
        <xsl:apply-templates select="t:altIdentifier"/>
    </xsl:template>
    <xsl:template match="t:altIdentifier">
        <xsl:choose>
            <xsl:when test="t:idno[@type ='Wright-BL-Arabic']">
                <div class="msItem">
                    <div>
                        <xsl:value-of select="t:collection"/>
                    </div>
                    <div>
                        <strong>Wright number:</strong>
                        <xsl:value-of select="t:idno"/>
                        (<xsl:value-of select="following-sibling::t:altIdentifier[child::t:idno[@type='Wright-BL-Roman']]/tei:idno"/>)
                    </div>
                </div>
            </xsl:when>
            <xsl:when test="t:idno[@type ='BL-Shelfmark']">
                <div class="msItem">
                    <xsl:value-of select="."/>
                </div>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:history/t:origin">
        <xsl:if test="t:origin">
            <xsl:for-each select="t:origin">
                <xsl:if test="t:origDate">
                    <p>
                        <strong>Date of Origin: </strong>
                        <xsl:apply-templates select="t:origDate"/>
                    </p>
                </xsl:if>
                <xsl:if test="t:origPlace">
                    <p>
                        <strong>Place of Origin: </strong>
                        <xsl:apply-templates select="t:origPlace"/>
                    </p>
                </xsl:if>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    <xsl:template match="t:textLang[@mainLang]">
        <xsl:if test="not(parent::*)">
            <p>
                <strong>Language: </strong>
                <xsl:apply-templates/>
            </p>
        </xsl:if>
    </xsl:template>
    <xsl:template match="t:origPlace">
        <xsl:choose>
            <xsl:when test="string-length(.) &lt; 1">Not available</xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:msContents">
        <div>
            <div class="msItem">
                <div>
                    <xsl:apply-templates/>
                </div>
            </div>
        </div>
    </xsl:template>
    <xsl:template match="t:physDesc">
        <div class="well">
            <h3 class="srp-label">Physical Description</h3>
            <div style="margin-left:.5em;">
                <xsl:apply-templates/>
            </div>
        </div>
    </xsl:template>
    <xsl:template match="t:msAuthors"/>
    <xsl:template match="t:msItem">
        <xsl:choose>
            <xsl:when test="@defective = 'true'">
                <div name="{string(@xml:id)}" class="msItem">
                    <div>
                        <strong>Item <xsl:value-of select="@n"/>
                        </strong> (defective)
                    </div>
                    <div class="msItem">
                        <xsl:call-template name="msItem-child"/>
                    </div>
                </div>
            </xsl:when>
            <xsl:when test="@defective ='unknown'">
                <div name="{string(@xml:id)}" class="msItem">
                    <div>
                        <strong>Item <xsl:value-of select="@n"/>
                        </strong> (defective?)
                    </div>
                    <div class="msItem">
                        <xsl:call-template name="msItem-child"/>
                    </div>
                </div>
            </xsl:when>
            <xsl:otherwise>
                <div name="{string(@xml:id)}" class="msItem">
                    <div>
                        <strong>Item <xsl:value-of select="@n"/>
                        </strong>
                    </div>
                    <div class="msItem">
                        <xsl:call-template name="msItem-child"/>
                    </div>
                </div>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:additional">
        <div>
            <h4>Origin: </h4>
            <div class="msItem">
                <xsl:apply-templates select="*[not(self::t:listBibl)]"/>
            </div>
            <div>
                <strong>Bibliographic list:</strong>
                <xsl:apply-templates select="t:listBibl"/>
            </div>
        </div>
    </xsl:template>
    <xsl:template name="msItem-child">
        <xsl:apply-templates select="t:title"/>
        <!-- Have to pull in author via xquery? or just doc? -->
        <p>
            <strong>Author: </strong>
            <xsl:variable name="author" select="string(t:author/@ref)"/>
            <a href="{$author}">
                <xsl:value-of select="string-join(/t:msAuthors/t:msAuthor[@id = $author][1],' ')"/>
            </a>
        </p>
        <xsl:apply-templates select="*[not(self::t:title or self::t:author or self::t:listBibl)]"/>
        <xsl:if test="t:listBibl">
            <div>
                <strong>Bibliographic list:</strong>
                <xsl:apply-templates select="t:listBibl"/>
            </div>
        </xsl:if>
    </xsl:template>
    <xsl:template match="t:rubric">
        <p>
            <xsl:choose>
                <xsl:when test="@xml:lang='syr'">
                    <strong>Syriac Title: </strong>
                    <bdi lang="syr">
                        <xsl:apply-templates/>
                    </bdi>
                </xsl:when>
                <xsl:otherwise>
                    <strong>Rubric: </strong>
                    <xsl:apply-templates/>
                </xsl:otherwise>
            </xsl:choose>
        </p>
    </xsl:template>
    <xsl:template match="t:incipit">
        <p>
            <strong>Incipit: </strong>
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    <xsl:template match="t:msItem/t:title">
        <p>
            <strong>Title: </strong>
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    <xsl:template match="t:msItem/t:author">
        <!-- Have to pull in author via xquery? or just doc? -->
        <p>
            <strong>Author: </strong>
            <xsl:variable name="author" select="string(@ref)"/>
            <a href="{$author}">
                <xsl:value-of select="string-join(/t:msAuthors/t:msAuthor[@id = $author][1],' ')"/>
            </a>
        </p>
    </xsl:template>
    <xsl:template match="t:editor">
        <p>
            <strong>Editor: </strong>
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    <xsl:template match="t:locus"/>
    <xsl:template match="t:locus" mode="locus">
        <p>
            <xsl:choose>
                <xsl:when test="parent::t:msItem"/>
                <xsl:otherwise>
                    <xsl:attribute name="class">msItem</xsl:attribute>
                </xsl:otherwise>
            </xsl:choose>
            <strong>Locus: </strong>
            <xsl:choose>
                <xsl:when test="string-length(.) &gt; 0">
                    <xsl:apply-templates/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:if test="@from"> from <xsl:value-of select="@from"/>
                    </xsl:if>
                    <xsl:if test="@to"> to <xsl:value-of select="@to"/>
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
        </p>
    </xsl:template>
    <xsl:template match="t:msItem/t:quote">
        <p>
            <strong>Quote: </strong>
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    <xsl:template match="t:explicit">
        <p>
            <strong>Explicit: </strong>
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    <xsl:template match="t:colophon">
        <p>
            <strong>Colophon: </strong>
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    <xsl:template match="t:finalRubric">
        <p>
            <strong>Desinit: </strong>
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    <xsl:template match="t:note[ancestor::t:msItem]">
        <p>
            <strong>Note</strong>
            <br/>
            <xsl:apply-templates select="." mode="plain"/>
        </p>
    </xsl:template>
    <xsl:template match="t:filiation">
        <p>
            <strong>Filiation: </strong>
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    <xsl:template match="t:material">
        <div>
            <strong>Material: </strong>
            <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="t:extent[ancestor::t:physDesc]">
        <div>
            <h4>Extent:</h4>
            <xsl:apply-templates mode="msExtent"/>
        </div>
    </xsl:template>
    <xsl:template match="t:measure" mode="msExtent">
        <span class="msExtent">
            <xsl:value-of select="concat(upper-case(substring(@type,1,1)),substring(@type,2))"/> (<xsl:value-of select="@unit"/>) <xsl:value-of select="."/>
        </span>
    </xsl:template>
    <xsl:template match="t:foliation">
        <div>
            <strong>Foliation: </strong>
            <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="t:collation">
        <div>
            <strong>Collation: </strong>
            <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="t:additions">
        <div>
            <strong>Additions: </strong>
            <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="t:condition">
        <div>
            <strong>Condition: </strong>
            <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="t:layoutDesc">
        <div>
            <strong>Layout: </strong>
            <xsl:apply-templates/>
        </div>
    </xsl:template>

    <!--
    <xsl:template match="t:height">
        <p>Height (<xsl:value-of select="t:measure/@unit"/>) <xsl:value-of select="t:measure/@quantity"/></p>
    </xsl:template>
    <xsl:template match="t:width">
        <p>Width (<xsl:value-of select="t:measure/@unit"/>) <xsl:value-of select="t:measure/@quantity"/></p>
    </xsl:template>
    -->
    <xsl:template match="t:handNote">
        <div name="{string(@xml:id)}">
            Hand <xsl:value-of select="substring-after(string(@xml:id),'ote')"/>:
            <div class="msItem">
                <div>
                    Type: <xsl:value-of select="@scope"/>
                </div>
                <div>
                    Script: <xsl:value-of select="ancestor::t:fileDesc/following-sibling::t:profileDesc/t:langUsage/t:language[@ident=string(./@script)]/text()"/>
                </div>
                <div>
                    Medium: <xsl:value-of select="@medium"/>
                </div>
                <xsl:apply-templates mode="plain"/>
            </div>
        </div>
    </xsl:template>
    <xsl:template match="t:decoNote">
        <div class="msItem" name="{string(@xml:id)}">
            Decoration <xsl:value-of select="substring-after(string(@xml:id),'ote')"/>:
            <div class="msItem">
                <div>
                    Type: <xsl:value-of select="@type"/>
                </div>
                <div>
                    Medium: <xsl:value-of select="@medium"/>
                </div>
                <xsl:apply-templates/>
            </div>
        </div>
    </xsl:template>
    <xsl:template match="t:binding">
        <div class="msItem" name="{string(@xml:id)}">
            Binding Note <xsl:value-of select="substring-after(string(@xml:id),'ing')"/>:
            <div class="msItem">
                <xsl:apply-templates/>
            </div>
        </div>
    </xsl:template>
    <xsl:template match="t:seal">
        <div class="msItem" name="{string(@xml:id)}">
            Seal Note <xsl:value-of select="substring-after(string(@xml:id),'seal')"/>: 
            <div class="msItem">
                <xsl:apply-templates/>
            </div>
        </div>
    </xsl:template>
    <xsl:template match="t:history">
        <xsl:if test="not(empty(.))">
            <div>
                <h4>History: </h4>
                <div class="msItem">
                    <xsl:apply-templates/>
                </div>
            </div>
        </xsl:if>
    </xsl:template>
    <xsl:template match="t:summary">
        <xsl:if test="string-length(.) &gt; 0">
            <div>
                <h4>Summary: </h4>
                <div class="msItem">
                    <xsl:apply-templates/>
                </div>
            </div>
        </xsl:if>
    </xsl:template>
    <xsl:template match="t:origin">
        <div>
            <h4>Origin: </h4>
            <div class="msItem">
                <xsl:apply-templates/>
            </div>
        </div>
    </xsl:template>
    <xsl:template match="t:origDate">
        <div>
            Date:  <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="t:origPlace">
        <div>
            Place:  <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="t:provenance">
        <div>Provenance: <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="t:acquisition">
        <div>Acquisition: <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="t:availability">
        <div>Availability: <xsl:value-of select="string(@status)"/>
            <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="t:custodialHist">
        <div>
            <strong>Custodial History:</strong>
            <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="t:custEvent">
        <div>Type: <xsl:value-of select="string(@type)"/>
            <div class="msItem">
                <xsl:apply-templates/>
            </div>
        </div>
    </xsl:template>
</xsl:stylesheet>