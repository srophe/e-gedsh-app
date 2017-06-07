<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:t="http://www.tei-c.org/ns/1.0" xmlns:x="http://www.w3.org/1999/xhtml" xmlns:saxon="http://saxon.sf.net/" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:local="http://syriaca.org/ns" exclude-result-prefixes="xs t x saxon local" version="2.0">

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
    <xsl:import href="manuscripts.xsl"/>
    <xsl:import href="citation.xsl"/>
    <xsl:import href="bibliography.xsl"/>
    <xsl:import href="json-uri.xsl"/>
    <xsl:import href="langattr.xsl"/>
    <xsl:import href="collations.xsl"/>
    
 <!-- =================================================================== -->
 <!-- set output so we get (mostly) indented HTML -->
 <!-- =================================================================== -->
    <xsl:output name="html" encoding="UTF-8" method="xhtml" indent="no" omit-xml-declaration="yes"/>
    <xsl:preserve-space elements="*"/>

 <!-- =================================================================== -->
 <!--  initialize top-level variables and transform parameters -->
 <!--  sourcedir: where to look for XML files to summarize/link to -->
 <!--  description: a meta description for the HTML page we will output -->
 <!--  name-app: name of the application (for use in head/title) -->
 <!--  name-page-short: short name of the page (for use in head/title) -->
 <!--  colquery: constructed variable with query for collection fn. -->
 <!-- =================================================================== -->
    
    <!-- Parameters passed from global.xqm (set in config.xml) default values if params are empty -->
    <!-- eXist data app root for gazetteer data -->
    <xsl:param name="data-root" select="'/db/apps/srophe-data'"/>
    <!-- eXist app root for app deployment-->
    <xsl:param name="app-root" select="'/db/apps/srophe'"/>
    <!-- Root of app for building dynamic links. Default is eXist app root -->
    <xsl:param name="nav-base" select="'/db/apps/srophe'"/>
    <!-- Base URI for identifiers in app data -->
    <xsl:param name="base-uri" select="'/db/apps/srophe'"/>
    <!-- Hard coded values-->
    <xsl:param name="normalization">NFKC</xsl:param>
    <xsl:param name="editoruriprefix">http://syriaca.org/documentation/editors.xml#</xsl:param>
    <xsl:variable name="editorssourcedoc" select="concat($app-root,'/documentation/editors.xml')"/>
    <!-- Resource id -->
    <xsl:variable name="resource-id">
        <xsl:choose>
            <xsl:when test="string(/*/@id)">
                <xsl:value-of select="string(/*/@id)"/>
            </xsl:when>
            <xsl:when test="/descendant::t:idno[@type='URI'][starts-with(.,$base-uri)][not(ancestor::t:seriesStmt)]">
                <xsl:value-of select="replace(replace(/descendant::t:idno[@type='URI'][not(ancestor::t:seriesStmt)][starts-with(.,$base-uri)][1],'/tei',''),'/source','')"/>
            </xsl:when>
            <!-- Temporary fix for SPEAR -->
            <xsl:otherwise>
                <xsl:text>http://syriaca.org/0000</xsl:text>
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
    <xsl:template match="t:TEI">
        <!-- Header -->
        <xsl:call-template name="h1"/>
        <!-- MSS display -->
        <xsl:if test="descendant::t:sourceDesc/t:msDesc">
            <xsl:apply-templates select="descendant::t:sourceDesc/t:msDesc"/>
        </xsl:if>
        <!-- Body -->
        <xsl:apply-templates select="descendant::t:body/child::*"/>
        <!-- Citation Information -->
        <xsl:call-template name="citationInfo"/>
    </xsl:template>
   
    <xsl:template match="t:titlePage">
        <div>
            <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="t:imprimatur | t:byline | t:docImprint | t:figDesc">
        <p class="{name(.)}">
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    <xsl:template match="t:titlePart">
        <xsl:choose>
            <xsl:when test="@type='main'">
                <h2>
                    <xsl:apply-templates/>
                </h2>        
            </xsl:when>
            <xsl:when test="@type='sub'">
                <h3>
                    <xsl:apply-templates/>
                </h3> 
            </xsl:when>
            <xsl:otherwise>
                <h4>
                    <xsl:apply-templates/>
                </h4>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:table">
        <table>
            <xsl:variable name="col-width" select="100 div count(t:row[1]/t:cell)"/>
            <xsl:for-each select="t:row[1]/t:cell">
                <col width="{$col-width}"/>
            </xsl:for-each>
           <xsl:apply-templates/>
        </table>
    </xsl:template>
    <xsl:template match="t:row">
        <tr>
            <xsl:apply-templates/>
        </tr>
    </xsl:template>
    <xsl:template match="t:cell">
        <td>
            <xsl:apply-templates/>
        </td>
    </xsl:template>
    <xsl:template match="t:pb">
        <xsl:choose>
            <xsl:when test="parent::t:table">
                <tr>
                    <td colspan="{parent::t:table/@cols}">        
                        <div class="strike">
                        <span>
                            <xsl:value-of select="@n"/>
                        </span>
                        </div>
                    </td>
                </tr>
            </xsl:when>
            <xsl:otherwise>
                <div class="strike">
                    <span>
                        <xsl:value-of select="@n"/>
                    </span>
                </div>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:figure">
        <div class="figure">
            <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="t:graphic">
        <xsl:choose>
            <xsl:when test="@url">
                <img src="@url"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Template for page titles -->
    <xsl:template match="t:srophe-title | t:titleStmt">
        <xsl:call-template name="h1"/>
    </xsl:template>
    <xsl:template name="h1">
        <div class="row title">
            <h1 class="col-md-8">
                <!-- Format title, calls template in place-title-std.xsl -->
                <xsl:call-template name="title"/>
            </h1>
            <!-- Call link icons (located in link-icons.xsl) -->
            <xsl:call-template name="link-icons"/>   
            <!-- End Title -->
        </div>
        <!-- emit record URI and associated help links -->
        <div style="margin:0 1em 1em; color: #999999;">
            <xsl:variable name="current-id" select="tokenize($resource-id,'/')[last()]"/>
            <xsl:variable name="next-id" select="xs:integer($current-id) + 1"/>
            <xsl:variable name="prev-id" select="xs:integer($current-id) - 1"/>
            <xsl:variable name="next-uri" select="replace($resource-id,$current-id,string($next-id))"/>
            <xsl:variable name="prev-uri" select="replace($resource-id,$current-id,string($prev-id))"/>
            <small>
                <a href="../documentation/terms.html#place-uri" title="Click to read more about Place URIs" class="no-print-link">
                    <span class="helper circle noprint">
                        <p>i</p>
                    </span>
                </a>
                <p>
                    <xsl:if test="starts-with($nav-base,'/exist/apps')">
                        <a href="{replace($prev-uri,$base-uri,$nav-base)}">
                            <span class="glyphicon glyphicon-backward" aria-hidden="true"/>
                        </a>
                    </xsl:if>
                    <xsl:text> </xsl:text>
                    <span class="srp-label">URI</span>
                    <xsl:text>: </xsl:text>
                    <span id="syriaca-id">
                        <xsl:value-of select="$resource-id"/>
                    </span>
                    <xsl:text> </xsl:text>
                    <xsl:if test="starts-with($nav-base,'/exist/apps')">
                        <a href="{replace($next-uri,$base-uri,$nav-base)}">
                            <span class="glyphicon glyphicon-forward" aria-hidden="true"/>
                        </a>
                    </xsl:if>
                </p>
            </small>
        </div>
    </xsl:template>
    <xsl:template name="title">
        <xsl:choose>
            <xsl:when test="descendant::*[contains(@syriaca-tags,'#syriaca-headword')]">
                <xsl:apply-templates select="descendant::*[contains(@syriaca-tags,'#syriaca-headword')][starts-with(@xml:lang,'en')][1]" mode="plain"/>
                <xsl:text> - </xsl:text>
                <xsl:choose>
                    <xsl:when test="descendant::*[contains(@syriaca-tags,'#anonymous-description')]">
                        <xsl:value-of select="descendant::*[contains(@syriaca-tags,'#anonymous-description')][1]"/>
                    </xsl:when>
                    <xsl:when test="descendant::*[contains(@syriaca-tags,'#syriaca-headword')][starts-with(@xml:lang,'syr')]">
                        <span lang="syr" dir="rtl">
                            <xsl:apply-templates select="descendant::*[contains(@syriaca-tags,'#syriaca-headword')][starts-with(@xml:lang,'syr')][1]" mode="plain"/>
                        </span>
                    </xsl:when>
                    <xsl:otherwise>
                        [ Syriac Not Available ]
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="descendant-or-self::t:title[1]"/>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="t:birth or t:death or t:floruit">
            <span lang="en" class="type" style="padding-left:1em;">
                <xsl:text>(</xsl:text>
                <xsl:if test="t:death or t:birth">
                    <xsl:if test="not(t:death)">b. </xsl:if>
                    <xsl:choose>
                        <xsl:when test="count(t:birth/t:date) &gt; 1">
                            <xsl:for-each select="t:birth/t:date">
                                <xsl:value-of select="text()"/>
                                <xsl:if test="position() != last()"> or </xsl:if>
                            </xsl:for-each>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="t:birth/text()"/>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:if test="t:death">
                        <xsl:choose>
                            <xsl:when test="t:birth"> - </xsl:when>
                            <xsl:otherwise>d. </xsl:otherwise>
                        </xsl:choose>
                        <xsl:choose>
                            <xsl:when test="count(t:death/t:date) &gt; 1">
                                <xsl:for-each select="t:death/t:date">
                                    <xsl:value-of select="text()"/>
                                    <xsl:if test="position() != last()"> or </xsl:if>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="t:death/text()"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:if>
                </xsl:if>
                <xsl:if test="t:floruit">
                    <xsl:if test="not(t:death) and not(t:birth)">
                        <xsl:choose>
                            <xsl:when test="count(t:floruit/t:date) &gt; 1">
                                <xsl:for-each select="t:floruit/t:date">
                                    <xsl:value-of select="concat('active ',text())"/>
                                    <xsl:if test="position() != last()"> or </xsl:if>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="concat('active ', t:floruit/text())"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:if>
                </xsl:if>
                <xsl:text>) </xsl:text>
            </span>
        </xsl:if>
        <xsl:for-each select="distinct-values(t:seriesStmt/t:biblScope/t:title)">
            <xsl:text>&#160; </xsl:text>
            <xsl:choose>
                <xsl:when test=". = 'The Syriac Biographical Dictionary'"/>
                <xsl:when test=". = 'A Guide to Syriac Authors'">
                    <a href="{$nav-base}/authors/index.html">
                        <span class="syriaca-icon syriaca-authors">
                            <span class="path1"/>
                            <span class="path2"/>
                            <span class="path3"/>
                            <span class="path4"/>
                        </span>
                        <span> author</span>
                    </a>
                </xsl:when>
                <xsl:when test=". = 'Qadishe: A Guide to the Syriac Saints'">
                    <a href="{$nav-base}/q/index.html">
                        <span class="syriaca-icon syriaca-q">
                            <span class="path1"/>
                            <span class="path2"/>
                            <span class="path3"/>
                            <span class="path4"/>
                        </span>
                        <span> saint</span>
                    </a>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="."/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
    
    <!-- Named template for citation information -->
    <xsl:template name="citationInfo">
        <div class="citationinfo">
            <h3>How to Cite This Entry</h3>
            <div id="citation-note" class="well">
                <xsl:apply-templates select="//t:teiHeader/t:fileDesc/t:titleStmt" mode="cite-foot"/>
                <div class="collapse" id="showcit">
                    <div id="citation-bibliography">
                        <h4>Bibliography:</h4>
                        <xsl:apply-templates select="//t:teiHeader/t:fileDesc/t:titleStmt" mode="cite-biblist"/>
                    </div>
                    <xsl:call-template name="aboutEntry"/>
                    <div id="license">
                        <h3>Copyright and License for Reuse</h3>
                        <div>
                            <xsl:text>Except otherwise noted, this page is © </xsl:text>
                            <xsl:choose>
                                <xsl:when test="//t:teiHeader/t:fileDesc/t:publicationStmt/t:date[1]/text() castable as xs:date">
                                    <xsl:value-of select="format-date(xs:date(//t:teiHeader/t:fileDesc/t:publicationStmt/t:date[1]), '[Y]')"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="//t:teiHeader/t:fileDesc/t:publicationStmt/t:date[1]"/>
                                </xsl:otherwise>
                            </xsl:choose>.
                        </div>
                        <xsl:apply-templates select="//t:teiHeader/t:fileDesc/t:publicationStmt/t:availability/t:licence"/>
                    </div>
                </div>
                <a class="togglelink pull-right btn-link" data-toggle="collapse" data-target="#showcit" data-text-swap="Hide citation">Show full citation information...</a>
            </div>
        </div>
    </xsl:template>
    <!-- Named template for bibl about -->
    <xsl:template match="t:srophe-about">
        <div id="citation-note" class="well">
            <xsl:call-template name="aboutEntry"/>
        </div>
    </xsl:template>
    <xsl:template name="aboutEntry">
        <div id="about">
            <xsl:choose>
                <xsl:when test="contains($resource-id,'/bibl/')">
                    <h3>About this Online Entry</h3>
                    <xsl:apply-templates select="/descendant::t:teiHeader/t:fileDesc/t:titleStmt" mode="about-bibl"/>
                </xsl:when>
                <xsl:otherwise>
                    <h3>About this Entry</h3>
                    <xsl:apply-templates select="/descendant::t:teiHeader/t:fileDesc/t:titleStmt" mode="about"/>
                </xsl:otherwise>
            </xsl:choose>
        </div>
    </xsl:template>
    <!-- Named template for sources calls bibliography.xsl -->
    <xsl:template name="sources">
        <xsl:param name="node"/>
        <div class="well">
            <!-- Sources -->
            <div id="sources">
                <h3>Sources</h3>
                <p>
                    <small>Any information without attribution has been created following the Syriaca.org <a href="http://syriaca.org/documentation/">editorial guidelines</a>.</small>
                </p>
                <ul>
                    <!-- Bibliography elements are processed by bibliography.xsl -->
                    <xsl:choose>
                        <xsl:when test="t:bibl[@type='lawd:Citation']">
                            <xsl:apply-templates select="t:bibl[@type='lawd:Citation']" mode="footnote"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:apply-templates select="t:bibl" mode="footnote"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </ul>
            </div>
        </div>
    </xsl:template>
    
    <!-- Generic title formating -->
    <xsl:template match="t:title">
        <xsl:choose>
            <xsl:when test="@ref">
                <a href="{@ref}">
                    <xsl:sequence select="local:rend(.)"/>
                        [<xsl:value-of select="@ref"/>]
                    </a>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="local:rend(.)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:foreign">
        <xsl:choose>
            <xsl:when test="starts-with(@xml:lang,'syr') or starts-with(@xml:lang,'ar')">
                <span lang="{@xml:lang}" dir="rtl">
                    <xsl:value-of select="."/>
                </span>
            </xsl:when>
            <xsl:otherwise>
                <span lang="{@xml:lang}">
                    <xsl:value-of select="."/>
                </span>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:event">
        <!-- There are several desc templates, this 'plain' mode ouputs all the child elements with no p or li tags -->
        <xsl:apply-templates select="child::*" mode="plain"/>
        <!-- Adds dates if available -->
        <xsl:sequence select="local:do-dates(.)"/>
        <!-- Adds footnotes if available -->
        <xsl:if test="@source">
            <xsl:sequence select="local:do-refs(@source,ancestor::t:*[@xml:lang][1])"/>
        </xsl:if>
    </xsl:template>
    <xsl:template match="t:orig | t:sic">
        <xsl:text> (</xsl:text>
        <xsl:apply-templates/>
        <xsl:text>) </xsl:text>
    </xsl:template>
    <xsl:template match="t:event" mode="event">
        <li>
        <!-- There are several desc templates, this 'plain' mode ouputs all the child elements with no p or li tags -->
            <xsl:apply-templates select="child::*" mode="plain"/>
        <!-- Adds dates if available -->
            <xsl:sequence select="local:do-dates(.)"/>
        <!-- Adds footnotes if available -->
            <xsl:if test="@source">
                <xsl:sequence select="local:do-refs(@source,ancestor::t:*[@xml:lang][1])"/>
            </xsl:if>
        </li>
    </xsl:template>
    <!-- suppress bibl -->
    <xsl:template match="t:bibl" mode="title"/>
    <xsl:template match="t:bibl">
        <xsl:choose>
            <xsl:when test="@type=('lawd:Edition','lawd:Translation','lawd:WrittenWork')">
                <li>
                    <xsl:if test="descendant::t:lang/text()">
                        <span class="srp-label">
                            <xsl:value-of select="local:expand-lang(descendant::t:lang/text(),'lawd:Edition')"/>:
                        </span>
                    </xsl:if>
                    <span>
                        <xsl:call-template name="langattr"/>
                        <xsl:apply-templates select="self::*" mode="inline"/>
                        <xsl:if test="@type=('lawd:Edition','lawd:Translation') and t:listRelation/t:relation">
                            <xsl:variable name="parent" select="ancestor::t:body/t:bibl"/>
                            <xsl:variable name="bibl-type">
                                <xsl:choose>
                                    <xsl:when test="@type='lawd:Translation'">Translation</xsl:when>
                                    <xsl:otherwise>
                                        <xsl:text>Edition</xsl:text>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:variable>
                            <xsl:variable name="bibl-rel">
                                <xsl:variable name="bibl-id" select="tokenize(t:listRelation/t:relation/@passive,' ')[1]"/>
                                <xsl:variable name="type" select="$parent/t:bibl[@xml:id = substring-after($bibl-id,'#')]/@type"/>
                                <xsl:choose>
                                    <xsl:when test="$type = 'lawd:Edition'">
                                        Edition<xsl:if test="contains(t:listRelation/t:relation/@passive,' ')">
                                            <xsl:text>s</xsl:text>
                                        </xsl:if>
                                    </xsl:when>
                                    <xsl:when test="$type ='lawd:WrittenWork'">
                                        Syriac Manuscript Witnesse<xsl:if test="contains(t:listRelation/t:relation/@passive,' ')">
                                            <xsl:text>s</xsl:text>
                                        </xsl:if>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:value-of select="string($type)"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:variable>
                            <xsl:text> (</xsl:text>
                            <xsl:value-of select="$bibl-type"/>
                            <xsl:text> from  </xsl:text>
                            <xsl:value-of select="$bibl-rel"/>
                            <xsl:choose>
                                <xsl:when test="contains(t:listRelation/t:relation/@passive,' ')">
                                    <xsl:for-each select="tokenize(t:listRelation/t:relation/@passive,' ')">
                                        <xsl:variable name="rel" select="substring-after(.,'#')"/>
                                        <xsl:for-each-group select="$parent/t:bibl" group-by="@type">
                                            <xsl:for-each select="current-group()">
                                                <xsl:if test="@xml:id = $rel">
                                                    <xsl:text> </xsl:text>
                                                    <xsl:value-of select="position()"/>
                                                </xsl:if>
                                            </xsl:for-each>
                                        </xsl:for-each-group>
                                        <xsl:if test="position() != last()">, </xsl:if>
                                    </xsl:for-each>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:variable name="rel" select="substring-after(t:listRelation/t:relation/@passive,'#')"/>
                                    <xsl:for-each-group select="$parent/t:bibl" group-by="@type">
                                        <xsl:for-each select="current-group()">
                                            <xsl:if test="@xml:id = $rel">
                                                <xsl:text> </xsl:text>
                                                <xsl:value-of select="position()"/>
                                            </xsl:if>
                                        </xsl:for-each>
                                    </xsl:for-each-group>
                                </xsl:otherwise>
                            </xsl:choose>
                            <xsl:text>. See below.)</xsl:text>
                            <xsl:if test="t:listRelation/t:relation/t:desc">
                                <xsl:text> [</xsl:text>
                                <xsl:value-of select="t:listRelation/t:relation/t:desc"/>
                                <xsl:text>]</xsl:text>
                            </xsl:if>
                        </xsl:if>
                    </span>
                </li>
            </xsl:when>
            <xsl:when test="parent::t:note">
                <xsl:apply-templates select="self::*" mode="inline"/>
            </xsl:when>
            <xsl:when test="child::*">
                    <li>
                        <xsl:if test="@xml:id">
                            <xsl:attribute name="id">
                                <xsl:value-of select="@xml:id"/>
                            </xsl:attribute>
                        </xsl:if>
                        <xsl:variable name="bibl-content">
                            <xsl:apply-templates mode="biblist"/>
                        </xsl:variable>
                        <xsl:sequence select="$bibl-content"/>
                    </li>
                <!--<xsl:apply-templates mode="footnote"/>-->
                    
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:listPerson">
        <li>
            <xsl:apply-templates/>
        </li>
    </xsl:template>
    <xsl:template match="t:biblScope"/>
    <xsl:template match="t:biblStruct">
        <xsl:choose>
            <xsl:when test="parent::t:body">
                <div class="well preferred-citation">
                    <h4>Preferred Citation</h4>
                    <xsl:apply-templates select="self::*" mode="bibliography"/>.
                </div>
                <h3>Full Citation Information</h3>
                <div class="section indent">
                    <xsl:apply-templates mode="full"/>
                </div>
            </xsl:when>
            <xsl:otherwise>
                <span class="section indent">
                    <xsl:apply-templates mode="footnote"/>
                </span>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:listRelation">
        <xsl:apply-templates/>
    </xsl:template>
    <!-- Template to print out confession section -->
    <xsl:template match="t:state[@type='confession']">
        <!-- Get all ancesors of current confession (but only once) -->
        <xsl:variable name="confessions" select="document(concat($app-root,'/documentation/confessions.xml'))//t:body/t:list"/>
        <xsl:variable name="id" select="substring-after(@ref,'#')"/>
        <li>
            <xsl:value-of select="$id"/>: 
            <xsl:for-each select="$confessions//t:item[@xml:id = $id]/ancestor-or-self::*/t:label">
                <xsl:value-of select="."/>
            </xsl:for-each>
        </li>
    </xsl:template>

    <!-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++  
     handle  output of  locations 
     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ -->
    <xsl:template match="t:location[@type='geopolitical' or @type='relative']">
        <li>
            <xsl:choose>
                <xsl:when test="@subtype='quote'">"<xsl:apply-templates/>"</xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates/>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:sequence select="local:do-refs(@source,ancestor::t:*[@xml:lang][1])"/>
        </li>
    </xsl:template>
    <xsl:template match="t:location[@type='nested']">
        <li>Within 
            <xsl:for-each select="t:*">
                <xsl:apply-templates select="."/>
                <xsl:if test="following-sibling::t:*">
                    <xsl:text> within </xsl:text>
                </xsl:if>
            </xsl:for-each>
            <xsl:text>.</xsl:text>
            <xsl:sequence select="local:do-refs(@source,'eng')"/>
        </li>
    </xsl:template>
    <xsl:template match="t:location[@type='gps' and t:geo]">
        <li>Coordinates: 
            <ul class="unstyled offset1">
                <li>
                    <xsl:value-of select="concat('Lat. ',tokenize(t:geo,' ')[1],'°')"/>
                </li>
                <li>
                    <xsl:value-of select="concat('Long. ',tokenize(t:geo,' ')[2],'°')"/>
                    <!--            <xsl:value-of select="t:geo"/>-->
                    <xsl:sequence select="local:do-refs(@source,'eng')"/>
                </li>
            </ul>
        </li>
    </xsl:template>
    <xsl:template match="t:offset | t:measure | t:source">
        <xsl:if test="preceding-sibling::*">
            <xsl:text> </xsl:text>
        </xsl:if>
        <xsl:apply-templates select="." mode="plain"/>
    </xsl:template>
    <xsl:template match="t:choice" mode="#all">
        <xsl:apply-templates select="t:corr | t:reg"/>
    </xsl:template>
    
    <!-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ 
     Description templates 
     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ -->
    <!-- Descriptions without list elements or paragraph elements -->
    <xsl:template match="t:desc | t:label" mode="plain">
        <xsl:apply-templates/>
    </xsl:template>
    <xsl:template match="t:label">
        <label>
            <xsl:if test="@type">
                <xsl:attribute name="class">
                    <xsl:value-of select="@type"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:call-template name="langattr"/>
            <xsl:sequence select="local:rend(.)"/>
        </label>
    </xsl:template>
    <!-- Descriptions for place abstract  added template for abstracts, handles quotes and references.-->
    <xsl:template match="t:desc[starts-with(@xml:id, 'abstract-en')]" mode="abstract">
        <p>
            <xsl:apply-templates/>
        </p>
    </xsl:template>
    
    <!-- General descriptions within the body of the place element, uses lists -->
    <xsl:template match="t:desc[not(starts-with(@xml:id, 'abstract-en'))]">
        <li>
            <xsl:apply-templates/>
        </li>
    </xsl:template>
    <xsl:template match="t:state | t:birth | t:death | t:floruit | t:sex | t:langKnowledge">
        <span class="srp-label">
            <xsl:choose>
                <xsl:when test="self::t:birth">Birth:</xsl:when>
                <xsl:when test="self::t:death">Death:</xsl:when>
                <xsl:when test="self::t:floruit">Floruit:</xsl:when>
                <xsl:when test="self::t:sex">Sex:</xsl:when>
                <xsl:when test="self::t:langKnowledge">Language Knowledge:</xsl:when>
                <xsl:when test="@role">
                    <xsl:value-of select="concat(upper-case(substring(@role,1,1)),substring(@role,2))"/>:
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat(upper-case(substring(@type,1,1)),substring(@type,2))"/>:        
                </xsl:otherwise>
            </xsl:choose>
        </span>
        <xsl:text> </xsl:text>
        <xsl:choose>
            <xsl:when test="count(t:date) &gt; 1">
                <xsl:for-each select="t:date">
                    <xsl:apply-templates/>
                    <xsl:sequence select="local:do-refs(@source,ancestor::t:*[@xml:lang][1])"/>
                    <xsl:if test="position() != last()"> or </xsl:if>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="plain"/>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:sequence select="local:do-refs(@source,ancestor::t:*[@xml:lang][1])"/>
    </xsl:template>
    <xsl:template match="t:langKnown">
        <xsl:apply-templates/>
        <xsl:sequence select="local:do-refs(@source,ancestor::t:*[@xml:lang][1])"/>
    </xsl:template>
    
    <!-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ 
     handle standard output of a listBibl element 
     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ -->
    <xsl:template match="t:listBibl">
        <!--<xsl:apply-templates select="*[not(self::t:bibl)]"/>-->
        <xsl:apply-templates select="t:head"/>
        <ul class="listBibl list-unstyled">
            <xsl:apply-templates select="*[not(self::t:head)]"/>
            <!--
            <xsl:for-each select="t:bibl">
                <li>
                    <xsl:if test="@xml:id">
                        <xsl:attribute name="id">
                            <xsl:value-of select="@xml:id"/>
                        </xsl:attribute>
                    </xsl:if>
                    <xsl:variable name="bibl-content">
                        <xsl:apply-templates mode="biblist"/>
                    </xsl:variable>
                    <xsl:sequence select="$bibl-content"/>
                </li>
            </xsl:for-each>
            -->
        </ul>
    </xsl:template>
    
    <xsl:template match="t:listBibl[parent::t:note]">
        <xsl:choose>
            <xsl:when test="t:bibl/t:msIdentifier">
                <xsl:choose>
                    <xsl:when test="t:bibl/t:msIdentifier/t:altIdentifier">
                        <xsl:text> </xsl:text>
                        <a href="{t:bibl/t:msIdentifier/t:altIdentifier/t:idno[@type='URI']/text()}">
                            <xsl:value-of select="t:bibl/t:msIdentifier/t:idno"/>
                        </a>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="t:idno"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="plain"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ 
     handle standard output of a note element 
     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ -->
    <xsl:template match="t:note">
        <xsl:variable name="xmlid" select="@xml:id"/>
        <xsl:choose>
            <!-- Adds definition list for depreciated names -->
            <xsl:when test="@type='deprecation'">
                <li>
                    <span>
                        <xsl:apply-templates select="../t:link[contains(@target,$xmlid)]"/>:
                            <xsl:apply-templates/>
                            <!-- Check for ending punctuation, if none, add . -->
                            <!-- NOTE not working -->
                    </span>
                    <xsl:if test="@source">
                        <xsl:sequence select="local:do-refs(@source,@xml:lang)"/>
                    </xsl:if>
                </li>
            </xsl:when>
            <xsl:when test="@type='ancientVersion'">
                <li class="note">
                    <xsl:if test="descendant::t:lang/text()">
                        <span class="srp-label">
                            <xsl:value-of select="local:expand-lang(descendant::t:lang/text(),'ancientVersion')"/>:
                        </span>
                    </xsl:if>
                    <span>
                        <xsl:call-template name="langattr"/>
                        <xsl:apply-templates/>
                    </span>
                    <xsl:if test="@source">
                        <xsl:sequence select="local:do-refs(@source,@xml:lang)"/>
                    </xsl:if>
                </li>
            </xsl:when>
            <xsl:when test="@type='modernTranslation'">
                <li>
                    <xsl:if test="descendant::t:lang/text()">
                        <span class="srp-label">
                            <xsl:value-of select="local:expand-lang(descendant::t:lang/text(),'modernTranslation')"/>:
                        </span>
                    </xsl:if>
                    <span>
                        <xsl:call-template name="langattr"/>
                        <xsl:apply-templates/>
                    </span>
                    <xsl:if test="@source">
                        <xsl:sequence select="local:do-refs(@source,@xml:lang)"/>
                    </xsl:if>
                </li>
            </xsl:when>
            <xsl:when test="@type='editions'">
                <li>
                    <span>
                        <xsl:call-template name="langattr"/>
                        <xsl:apply-templates/>
                        <xsl:if test="t:bibl/@corresp">
                            <xsl:variable name="mss" select="../t:note[@type='MSS']"/>
                            <xsl:text> (</xsl:text>
                            <xsl:choose>
                                <xsl:when test="@ana='partialTranslation'">Partial edition</xsl:when>
                                <xsl:otherwise>Edition</xsl:otherwise>
                            </xsl:choose>
                            <xsl:text> from manuscript </xsl:text>
                            <xsl:choose>
                                <xsl:when test="contains(t:bibl/@corresp,' ')">
                                    <xsl:text>witnesses </xsl:text>
                                    <xsl:for-each select="tokenize(t:bibl/@corresp,' ')">
                                        <xsl:variable name="corresp" select="."/>
                                        <xsl:for-each select="$mss/t:bibl">
                                            <xsl:if test="@xml:id = $corresp">
                                                <xsl:value-of select="position()"/>
                                            </xsl:if>
                                        </xsl:for-each>
                                        <xsl:if test="position() != last()">, </xsl:if>
                                    </xsl:for-each>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:variable name="corresp" select="substring-after(t:bibl/@corresp,'#')"/>
                                    <xsl:text>witness </xsl:text>
                                    <xsl:for-each select="$mss/t:bibl">
                                        <xsl:if test="@xml:id = $corresp">
                                            <xsl:value-of select="position()"/>
                                        </xsl:if>
                                    </xsl:for-each>
                                </xsl:otherwise>
                            </xsl:choose>
                            <xsl:text>. See below.)</xsl:text>
                        </xsl:if>
                    </span>
                    <xsl:if test="@source">
                        <xsl:sequence select="local:do-refs(@source,@xml:lang)"/>
                    </xsl:if>
                </li>
            </xsl:when>
            <xsl:otherwise>
                <p class="note">
                    <xsl:choose>
                        <xsl:when test="t:quote">
                            <xsl:apply-templates/>
                        </xsl:when>
                        <xsl:otherwise>
                            <span>
                                <xsl:call-template name="langattr"/>
                                <xsl:apply-templates/>
                                <!-- Check for ending punctuation, if none, add . -->
                                <!-- Do not have this working -->
                            </span>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:if test="@source">
                        <xsl:sequence select="local:do-refs(@source,@xml:lang)"/>
                    </xsl:if>
                </p>   
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:note" mode="abstract">
        <p>
            <xsl:apply-templates/>
            <xsl:if test="@source">
                <xsl:sequence select="local:do-refs(@source,@xml:lang)"/>
            </xsl:if>
        </p>
    </xsl:template>
    <!-- Handles t:link elements for deperciated notes, pulls value from matching element, output element and footnotes -->
    <xsl:template match="t:link">
        <xsl:variable name="elementID" select="substring-after(substring-before(@target,' '),'#')"/>
        <xsl:for-each select="/descendant-or-self::*[@xml:id=$elementID]">
            <xsl:apply-templates select="."/>
            <xsl:text> </xsl:text>
        </xsl:for-each>
    </xsl:template>

    <!-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ 
     handle standard output of a p element 
     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ -->
    <xsl:template match="t:p">
        <p>
            <xsl:call-template name="langattr"/>
            <xsl:apply-templates xml:space="preserve"/>
        </p>
    </xsl:template>
    <xsl:template match="t:quote">
        <xsl:choose>
            <xsl:when test="@xml:lang">
                <span dir="ltr">
                    <xsl:text> “</xsl:text>
                </span>
                <span>
                    <xsl:attribute name="dir">
                        <xsl:call-template name="getdirection"/>
                    </xsl:attribute>
                    <xsl:call-template name="langattr"/>
                    <xsl:apply-templates/>
                </span>
                <span dir="ltr">
                    <xsl:text>”  </xsl:text>
                </span>
            </xsl:when>
            <xsl:when test="parent::*/@xml:lang">
                <!-- Quotes need to be outside langattr for Syriac and arabic characters to render correctly.  -->
                <span dir="ltr">
                    <xsl:text> “</xsl:text>
                </span>
                <span class="langattr">
                    <xsl:attribute name="dir">
                        <xsl:choose>
                            <xsl:when test="parent::*[@xml:lang='en']">ltr</xsl:when>
                            <xsl:when test="parent::*[@xml:lang='syr' or @xml:lang='ar' or @xml:lang='syc' or @xml:lang='syr-Syrj']">rtl</xsl:when>
                            <xsl:otherwise>ltr</xsl:otherwise>
                        </xsl:choose>
                    </xsl:attribute>
                    <xsl:attribute name="lang">
                        <xsl:value-of select="parent::*/@xml:lang"/>
                    </xsl:attribute>
                    <xsl:apply-templates/>
                </span>
                <span dir="ltr">
                    <xsl:text>”  </xsl:text>
                </span>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> “</xsl:text>
                <xsl:apply-templates/>
                <xsl:text>” </xsl:text>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:if test="@source or parent::*/@source">
            <span class="langattr">
                <xsl:attribute name="dir">
                    <xsl:choose>
                        <xsl:when test="parent::t:desc[@xml:lang='en']">ltr</xsl:when>
                        <xsl:when test="parent::t:desc[@xml:lang='syr' or @xml:lang='ar' or @xml:lang='syc' or @xml:lang='syr-Syrj']">rtl</xsl:when>
                        <xsl:otherwise>ltr</xsl:otherwise>
                    </xsl:choose>
                </xsl:attribute>
                <xsl:if test="@source">
                    <xsl:sequence select="local:do-refs(@source,ancestor::t:*[@xml:lang][1])"/>
                </xsl:if>
            </span>
        </xsl:if>
    </xsl:template>
    <xsl:template match="t:persName | t:region | t:settlement | t:placeName | t:author | t:editor">
        <xsl:choose>
            <xsl:when test="self::t:persName[parent::t:byline]">
                <xsl:text>Author: </xsl:text>
            </xsl:when>
            <xsl:when test="@role">
                <span class="srp-label">
                    <xsl:value-of select="concat(upper-case(substring(@role,1,1)),substring(@role,2))"/>: 
                </span>
            </xsl:when>
        </xsl:choose>
        <span class="{local-name(.)}">
            <xsl:call-template name="langattr"/>
            <xsl:choose>
                <xsl:when test="self::t:persName[parent::t:byline]">
                    <i>
                        <xsl:apply-templates/>
                    </i>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates/>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:sequence select="local:do-refs(@source,@xml:lang)"/>
        </span>
        <!--
        <xsl:choose>
            <xsl:when test="@ref">
                <xsl:choose>
                    <xsl:when test="string-length(@ref) < 1">
                        <span>
                            <xsl:call-template name="langattr"/>
                            <xsl:apply-templates/>
                        </span>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text> </xsl:text>
                        <a class="{local-name(.)}" href="{@ref}">
                            <xsl:call-template name="langattr"/>
                            <xsl:apply-templates/>
                        </a>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <span class="{local-name(.)}">
                    <xsl:call-template name="langattr"/>
                    <xsl:choose>
                        <xsl:when test="self::t:persName[parent::t:byline]">
                            <i>
                                <xsl:apply-templates/>
                            </i>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:apply-templates/>
                        </xsl:otherwise>
                    </xsl:choose>
                    <xsl:sequence select="local:do-refs(@source,@xml:lang)"/>
                </span>
            </xsl:otherwise>
        </xsl:choose>
        -->
    </xsl:template>
    <xsl:template match="t:persName" mode="title">
        <span class="persName">
            <xsl:call-template name="langattr"/>
            <xsl:apply-templates/>
        </span>
    </xsl:template>
    <xsl:template match="t:persName" mode="list">
        <xsl:variable name="nameID" select="concat('#',@xml:id)"/>
        <xsl:choose>
            <!-- Suppress depreciated names here -->
            <xsl:when test="/descendant-or-self::t:link[substring-before(@target,' ') = $nameID][contains(@target,'deprecation')]"/>
            <!-- Output all other names -->
            <xsl:otherwise>
                <span dir="ltr" class="label label-default pers-label">
                    <span class="persName">
                        <xsl:call-template name="langattr"/>
                        <xsl:apply-templates/>
                    </span>
                    <xsl:sequence select="local:do-refs(@source,ancestor::t:*[@xml:lang][1])"/>
                </span>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:persName" mode="plain">
        <span class="persName">
            <xsl:call-template name="langattr"/>
            <xsl:apply-templates/>
        </span>
    </xsl:template>
    <xsl:template match="t:roleName">
        <xsl:apply-templates mode="plain"/>
        <xsl:text> </xsl:text>
    </xsl:template>
    <xsl:template match="t:forename | t:addName">
        <xsl:if test="preceding-sibling::*">
            <xsl:text> </xsl:text>
        </xsl:if>
        <xsl:apply-templates mode="plain"/>
        <xsl:if test="following-sibling::*">
            <xsl:text> </xsl:text>
        </xsl:if>
    </xsl:template>
    <xsl:template match="t:placeName | t:title" mode="list">
        <xsl:variable name="nameID" select="concat('#',@xml:id)"/>
        <xsl:choose>
            <!-- Suppress depreciated names here -->
            <xsl:when test="/descendant-or-self::t:link[substring-before(@target,' ') = $nameID][contains(@target,'deprecation')]"/>
            <!-- Output all other names -->
            <xsl:otherwise>
                <li dir="ltr">
                    <!-- write out the placename itself, with appropriate language and directionality indicia -->
                    <span class="placeName">
                        <xsl:call-template name="langattr"/>
                        <xsl:apply-templates select="." mode="plain"/>
                    </span>
                    <xsl:sequence select="local:do-refs(@source,ancestor::t:*[@xml:lang][1])"/>
                </li>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:list">
        <ul>
            <xsl:apply-templates/>
        </ul>
    </xsl:template>
    <xsl:template match="t:item">
        <li>
            <xsl:apply-templates/>
        </li>
    </xsl:template>
    
    <!-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ 
     handle standard output of the licence element in the tei header
     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ -->
    <xsl:template match="t:licence">
        <xsl:if test="@target">
            <a rel="license" href="{@target}">
                <img alt="Creative Commons License" style="border-width:0" src="{$nav-base}/resources/img/cc.png" height="18px"/>
            </a>
        </xsl:if>
        <xsl:apply-templates/>
    </xsl:template>
    
    <!-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ 
     handle standard output of the ref element
     ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ -->
    <xsl:template match="t:ref" mode="#all">
        <xsl:variable name="target">
            <xsl:choose>
                <xsl:when test="starts-with(@target, $base-uri) and ($base-uri != $nav-base) and contains(@target,'/fig/')">
                    <xsl:value-of select="@target"/>
                </xsl:when>
                <xsl:when test="starts-with(@target, $base-uri) and $base-uri != $nav-base">
                    <xsl:value-of select="concat('/exist/apps/e-gedsh/entry.html?id=',@target)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="@target"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="class">
            <xsl:choose>
                <xsl:when test="starts-with(@target, $base-uri) and contains(@target,'/fig/')">
                    <xsl:text>ref</xsl:text>
                </xsl:when>
                <xsl:when test="starts-with(@target, $base-uri)">
                    <xsl:text>cross-ref</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:text>ref</xsl:text>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:if test="preceding-sibling::node()[1][matches(.,'$(\s)')]">
            <xsl:text> </xsl:text>
        </xsl:if>
        <a href="{$target}" class="{$class}">
            <xsl:apply-templates mode="plain"/>
        </a>
        <xsl:if test="following-sibling::node()[1][matches(.,'^(\s)')]">
            <xsl:text> </xsl:text>
        </xsl:if>
    </xsl:template>
    <xsl:template match="t:hi" mode="#all">
        <xsl:sequence select="local:rend(.)"/>
    </xsl:template>
    <xsl:template match="t:abbr">
        <!--
        <xsl:if test="preceding-sibling::node()[1][not(matches(.,'$(\s|\(|\.|,)|\[|'))]">
            <xsl:text> </xsl:text>
        </xsl:if>
        -->
        <xsl:if test="preceding-sibling::node()[1][matches(.,'$(\s)')]">
            <xsl:text> </xsl:text>
        </xsl:if>
        <xsl:apply-templates/>
        <xsl:if test="following-sibling::node()[1][matches(.,'^(\s)')]">
            <xsl:text> </xsl:text>
        </xsl:if>
       <!--
        <xsl:if test="following-sibling::node()[1][not(matches(.,'^(\s|\)|\.|,)|\]|;|:'))]">
            <xsl:text> </xsl:text>
        </xsl:if>
        -->
    </xsl:template>
    <!-- NOTE: would really like to get rid of mode=cleanout -->
    <xsl:template match="t:placeName[local-name(..)='desc']" mode="cleanout">
        <xsl:apply-templates select="."/>
    </xsl:template>
    
    <!-- e-gedsh templates -->
    <xsl:template match="t:div[@type='entry']">
        <div class="entry-title">
            <xsl:apply-templates select="t:head"/>
        </div>
        <xsl:apply-templates select="t:div[@type='body']"/>
        <xsl:apply-templates select="t:p"/>
        <xsl:apply-templates select="t:div[@type='bibl']"/>
        <xsl:apply-templates select="t:byline"/>
    </xsl:template>
    <xsl:template match="t:head">
        <xsl:choose>
            <xsl:when test="parent::t:div[@type='entry']">
                <h1 class="inline">
                    <xsl:apply-templates/>
                    <xsl:text> </xsl:text>
                    <small>
                        <xsl:apply-templates select="../t:ab[@type='infobox']"/>
                    </small>
                </h1>
            </xsl:when>
            <xsl:otherwise>
                <h3 class="head {name(parent::*[1])}">
                    <xsl:apply-templates/>
                </h3>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <!-- NOTE: For SPEAR, could cause issues in the future.  -->
    <xsl:template match="t:div">
        <xsl:apply-templates select="*[not(self::t:bibl)]"/>
    </xsl:template>
    <xsl:template match="t:*" mode="plain">
        <xsl:apply-templates/>
    </xsl:template>
    <xsl:template match="t:*">
        <xsl:apply-templates/>
    </xsl:template>
    <xsl:template match="text()">
        <xsl:value-of select="."/>
    </xsl:template>
    <xsl:template match="text()" mode="cleanout">
        <xsl:value-of select="."/>
    </xsl:template>
    <xsl:template match="t:*" mode="cleanout">
        <xsl:apply-templates mode="cleanout"/>
    </xsl:template>
    <xsl:template name="getdirection">
        <xsl:choose>
            <xsl:when test="@xml:lang='en'">ltr</xsl:when>
            <xsl:when test="@xml:lang='syr' or @xml:lang='ar' or @xml:lang='syc' or @xml:lang='syr-Syrj'">rtl</xsl:when>
            <xsl:when test="not(@xml:lang)">
                <xsl:text/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>