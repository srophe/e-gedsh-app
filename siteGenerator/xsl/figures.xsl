<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:t="http://www.tei-c.org/ns/1.0"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:local="http://syriaca.org/ns"
    exclude-result-prefixes="xs t tei local" version="3.0">

    <!-- ==================================================================
         Deprecated Code. Figures can be run via the staticHTML.xsl stylesheet. 
         
         figures.xsl

         Generate one static HTML page per figure from the figures TEI file
         (e-GEDSH_figs.xml). Each <div type="figure"> carries an
         <ab type="idnos"><idno type="URI">.../fig/N</idno></ab> and a
         <figure> with a <graphic> (an IIIF image identifier) and a <figDesc>.

         For each figure this writes fig/<N>.html (e.g. fig/1.html, fig/3c.html),
         mirroring the layout previously served dynamically by the eXist app
         (banner, "Figure N" heading, URI nav line, image, caption).

         The stylesheet is self-contained (no imports): the figure markup only
         uses graphic/figDesc/ref/bibl/title/hi, rendered by the small templates
         below. The graphic template applies the IIIF fix: the @url is an image
         *identifier* (which alone returns info.json), so a full IIIF image
         request is built for display.

         Usage (writes fig/*.html under the directory given by $outDir):
           java -jar saxon.jar -s:e-GEDSH_figs.xml -xsl:figures.xsl \
             outDir=/path/to/output
         ================================================================== -->

    <xsl:output method="xhtml" encoding="UTF-8" indent="no" omit-xml-declaration="yes"
        doctype-system="about:legacy-compat"/>

    <!-- Root of the output tree; fig/<N>.html files are written under here. -->
    <xsl:param name="outDir" select="'.'"/>
    <!-- Public base URI used in the figure nav line. -->
    <xsl:param name="baseUri" select="'https://gedsh.bethmardutho.org'"/>

    <xsl:template match="/">
        <xsl:for-each select="descendant::t:div[@type='figure'][descendant::t:idno[@type='URI']]">
            <!-- The figure id is the last path segment of the URI, e.g.
                 https://gedsh.bethmardutho.org/fig/3c  ->  3c -->
            <xsl:variable name="uri" select="normalize-space(descendant::t:idno[@type='URI'][1])"/>
            <xsl:variable name="figId" select="tokenize($uri,'/')[last()]"/>
            <xsl:if test="$figId != ''">
                <xsl:result-document href="{concat($outDir,'/fig/',$figId,'.html')}" method="xhtml"
                    encoding="UTF-8" indent="no" omit-xml-declaration="yes"
                    doctype-system="about:legacy-compat">
                    <xsl:call-template name="figPage">
                        <xsl:with-param name="figId" select="$figId"/>
                        <xsl:with-param name="uri" select="$uri"/>
                        <xsl:with-param name="figure" select="."/>
                    </xsl:call-template>
                </xsl:result-document>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>

    <xsl:template name="figPage">
        <xsl:param name="figId"/>
        <xsl:param name="uri"/>
        <xsl:param name="figure"/>
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
                <meta charset="utf-8"/>
                <meta http-equiv="X-UA-Compatible" content="IE=edge"/>
                <meta name="viewport" content="width=device-width, initial-scale=1"/>
                <title>Fig. <xsl:value-of select="$figId"/> | e-GEDSH</title>
                <link rel="shortcut icon" href="/resources/img/favicon.ico"/>
                <link rel="stylesheet" href="/resources/css/syr-icon-fonts.css"/>
                <link rel="stylesheet" type="text/css" href="/resources/css/bootstrap.min.css"/>
                <link rel="stylesheet" type="text/css" href="/resources/css/main.css"/>
                <link rel="stylesheet" type="text/css" href="/resources/css/lightslider.css"/>
                <link rel="stylesheet" type="text/css" href="/resources/css/sm-core-css.css"/>
                <link rel="stylesheet" type="text/css" media="print" href="/resources/css/print.css"/>
                <script type="text/javascript" src="/resources/js/jquery-1.9.1.min.js"><!-- --></script>
                <script type="text/javascript" src="/resources/js/jquery.smartmenus.min.js"><!-- --></script>
            </head>
            <body id="body">
                <nav class="navbar navbar-default navbar-fixed-top" role="navigation">
                    <div class="container">
                        <div class="navbar-header">
                            <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target=".navbar-collapse">
                                <span class="sr-only">Toggle navigation</span>
                                <span class="icon-bar"><!-- --></span>
                                <span class="icon-bar"><!-- --></span>
                                <span class="icon-bar"><!-- --></span>
                            </button>
                            <a class="navbar-brand banner-container inline" href="/index.html">
                                <img property="logo" class="img-responsive" style="padding-bottom:.5em;display:inline;" alt="e-GEDSH" src="/resources/img/e-gedsh.png" width="20px"/>
                                <span style="font-size:24px;margin-left:.25em; padding-top:1.5em; display:inline;">e-GEDSH</span>
                            </a>
                        </div>
                        <div class="navbar-collapse collapse pull-right">
                            <ul class="nav navbar-nav sm sm-vertical" id="main-menu">
                                <li><a href="/browse.html">Browse Entries</a></li>
                                <li><a href="/index.html">Home</a></li>
                                <li><a href="/List-of-Figures.html">List of Figures</a></li>
                            </ul>
                            <form class="navbar-form navbar-right navbar-input-group" role="search" action="/search.html" method="get">
                                <div class="input-group">
                                    <input type="text" class="form-control" placeholder="search" name="q" id="q"/>
                                    <div class="input-group-btn">
                                        <button class="btn btn-default" type="submit">
                                            <span class="glyphicon glyphicon-search"><!-- --></span>
                                        </button>
                                        <a href="/search.html" title="advanced search" class="btn btn-default">
                                            <span class="glyphicon glyphicon-cog"><!-- --></span>
                                        </a>
                                    </div>
                                </div>
                            </form>
                        </div>
                    </div>
                </nav>
                <div>
                    <div class="banner-title full-page">
                        <span class="img-credit">
                            <h1>Gorgias Encyclopedic Dictionary of the Syriac Heritage: Electronic Edition</h1>
                        </span>
                    </div>
                    <div class="section indent top-padding">
                        <div class="row row-centered top-padding">
                            <div class="col-md-2 toc"><!-- --></div>
                            <div class="col-md-8">
                                <h1>Figure</h1>
                                <hr/>
                                <!-- URI reference line (matches the previous dynamic page). -->
                                <div class="uri" style="margin-bottom:1em;">
                                    <xsl:text>| </xsl:text>
                                    <xsl:value-of select="$uri"/>
                                    <xsl:text> |</xsl:text>
                                </div>
                                <xsl:apply-templates select="$figure/descendant::t:figure"/>
                                <br/>
                            </div>
                            <div class="col-md-2"><!-- --></div>
                        </div>
                    </div>
                </div>
                <script src="/resources/js/footer.js"><!-- --></script>
            </body>
        </html>
    </xsl:template>

    <!-- ============================ figure content ============================ -->

    <xsl:template match="t:figure" xmlns="http://www.w3.org/1999/xhtml">
        <div class="figure">
            <xsl:apply-templates/>
        </div>
    </xsl:template>

    <!-- Graphic: the @url is an IIIF Image API *identifier* (base URI), which on
         its own returns info.json rather than an image. Build a full IIIF image
         request for display, upgrading http: to https: to avoid mixed content. -->
    <xsl:template match="t:graphic" xmlns="http://www.w3.org/1999/xhtml">
        <xsl:choose>
            <xsl:when test="contains(@url,'/iiif/')">
                <xsl:variable name="iiifBase" select="replace(@url,'^http:','https:')"/>
                <div class="text-center" style="width:100% !important;">
                    <img src="{concat($iiifBase,'/full/650,/0/default.jpg')}" class="img-responsive"
                        style="display:inline-block;" alt="Figure image"/>
                </div>
                <span class="see-full-image text-center">
                    <a href="{concat($iiifBase,'/full/full/0/default.jpg')}" target="_blank">See full image</a>
                </span>
            </xsl:when>
            <xsl:when test="@url">
                <img src="{@url}" class="img-responsive" alt="Figure image"/>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <!-- Figure description / caption. -->
    <xsl:template match="t:figDesc" xmlns="http://www.w3.org/1999/xhtml">
        <p class="figDesc">
            <xsl:apply-templates/>
        </p>
    </xsl:template>

    <!-- A copyright / unavailable notice or other paragraph inside the figure. -->
    <xsl:template match="t:p" xmlns="http://www.w3.org/1999/xhtml">
        <p>
            <xsl:apply-templates/>
        </p>
    </xsl:template>

    <!-- Cross-reference link to an entry or figure. -->
    <xsl:template match="t:ref" xmlns="http://www.w3.org/1999/xhtml">
        <xsl:choose>
            <xsl:when test="@target">
                <a href="{@target}">
                    <xsl:apply-templates/>
                </a>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Bibliographic citation: rendered inline. -->
    <xsl:template match="t:bibl" xmlns="http://www.w3.org/1999/xhtml">
        <span class="bibl">
            <xsl:apply-templates/>
        </span>
    </xsl:template>

    <!-- Title, italicized when rend="italic". -->
    <xsl:template match="t:title" xmlns="http://www.w3.org/1999/xhtml">
        <xsl:choose>
            <xsl:when test="@rend = 'italic'">
                <i><xsl:apply-templates/></i>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Emphasis/highlight. -->
    <xsl:template match="t:hi" xmlns="http://www.w3.org/1999/xhtml">
        <xsl:choose>
            <xsl:when test="@rend = 'italic'">
                <i><xsl:apply-templates/></i>
            </xsl:when>
            <xsl:when test="@rend = 'bold'">
                <b><xsl:apply-templates/></b>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
