xquery version "3.0";
(:~
 : Builds tei conversions. 
 : Used by oai, can be plugged into other outputs as well.
 :)
 
module namespace tei2html="http://syriaca.org/tei2html";
import module namespace bibl2html="http://syriaca.org/bibl2html" at "bibl2html.xqm";
import module namespace global="http://syriaca.org/global" at "../lib/global.xqm";

declare namespace html="http://purl.org/dc/elements/1.1/";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xlink = "http://www.w3.org/1999/xlink";
declare namespace util="http://exist-db.org/xquery/util";

(:~
 : Simple TEI to HTML transformation
 : @param $node   
:)
declare function tei2html:tei2html($nodes as node()*) as item()* {
    for $node in $nodes
    return 
        typeswitch($node)
            case text() return $node
            case comment() return ()
            case element(tei:biblScope) return element span {
                let $unit := if($node/@unit = 'vol') then concat($node/@unit,'.') 
                             else if($node[@unit != '']) then string($node/@unit) 
                             else if($node[@type != '']) then string($node/@type)
                             else () 
                return 
                    if(matches($node/text(),'^\d')) then concat($unit,' ',$node/text())
                    else if(not($node/text()) and ($node/@to or $node/@from)) then  concat($unit,' ',$node/@from,' - ',$node/@to)
                    else $node/text()
            }
            case element(tei:category) return element ul {tei2html:tei2html($node/node())}
            case element(tei:catDesc) return element li {tei2html:tei2html($node/node())}
            case element(tei:imprint) return element span {
                    if($node/tei:pubPlace/text()) then $node/tei:pubPlace[1]/text() else (),
                    if($node/tei:pubPlace/text() and $node/tei:publisher/text()) then ': ' else (),
                    if($node/tei:publisher/text()) then $node/tei:publisher[1]/text() else (),
                    if(not($node/tei:pubPlace) and not($node/tei:publisher) and $node/tei:title[@level='m']) then <abbr title="no publisher">n.p.</abbr> else (),
                    if($node/tei:date/preceding-sibling::*) then ', ' else (),
                    if($node/tei:date) then $node/tei:date else <abbr title="no date of publication">n.d.</abbr>,
                    if($node/following-sibling::tei:biblScope[@unit='series']) then ', ' else ()
            }
            case element(tei:label) return element span {tei2html:tei2html($node/node())}
            case element(tei:placeName) return 
                <span class="tei-placeName">{
                    let $name := tei2html:tei2html($node/node())
                    return
                        if($node/@ref) then
                            element a { attribute href { $node/@ref }, $name }
                        else $name                                 
                        }</span>
            case element(tei:persName) return 
                <span class="tei-persName">{
                    let $name := if($node/child::*) then 
                                    for $part in $node/child::*
                                    order by $part/@sort ascending, string-join($part/descendant-or-self::text(),' ') descending
                                    return tei2html:tei2html($part/node())
                                 else tei2html:tei2html($node/node())
                    return
                        if($node/@ref) then
                            element a { attribute href { $node/@ref }, $name }
                        else $name                                 
                        }</span>
            case element(tei:title) return 
                let $titleType := 
                        if($node/@level='a') then 
                            'title-analytic'
                        else if($node/@level='m') then 
                            'title-monographic'
                        else if($node/@level='j') then 
                            'title-journal'
                        else if($node/@level='s') then 
                            'title-series'
                        else if($node/@level='u') then 
                            'title-unpublished'
                        else if($node/parent::tei:persName) then 
                            'title-person'                             
                        else ()
                return  
                    <span class="tei-title {$titleType}"> {
                        (if($node/@xml:lang) then attribute lang { $node/@xml:lang } else (),
                        if($node/child::*) then 
                            ($node/text(),
                            for $part in $node/child::*
                            return tei2html:tei2html($part/node()))
                        else tei2html:tei2html($node/node()))                 
                    }</span>
            default return tei2html:tei2html($node/node())
};

(:~ 
 : Display idno with copy icon and paging (if relevant)
:)
declare function tei2html:idno-title-display($id){
    let $id-string := substring-after(tokenize($id,'/')[last()],'-')
    let $id-num := if($id-string castable as xs:integer) then $id-string cast as xs:integer else 0
    let $next := $id-num + 1
    let $prev := $id-num - 1
    let $next-url := concat(substring-before($id,'-'),'-',string($next))
    let $prev-url := concat(substring-before($id,'-'),'-',string($prev))
    return 
        <div style="margin:0 1em 1em; color: #999999;" xmlns="http://www.w3.org/1999/xhtml">
            <small>
                <span class="uri">
                    <a href="{replace($prev-url, $global:base-uri, $global:nav-base)}"><span class="glyphicon glyphicon-backward" aria-hidden="true"/></a>
                    &#160;<button type="button" class="btn btn-default btn-xs" id="idnoBtn" data-clipboard-action="copy" data-clipboard-target="#syriaca-id">
                        <span class="srp-label">URI</span>
                    </button>&#160;
                    <span id="syriaca-id">{$id}</span>
                    <script>
                        <![CDATA[
                            var clipboard = new Clipboard('#idnoBtn');
                            clipboard.on('success', function(e) {
                            console.log(e);
                            });
                            
                            clipboard.on('error', function(e) {
                            console.log(e);
                            });]]>
                    </script>
                    <a href="{replace($next-url,$global:base-uri, $global:nav-base)}"><span class="glyphicon glyphicon-forward" aria-hidden="true"/></a>
                </span>
            </small>
        </div>
};

(:
 : Used for short views of records, browse, search or related items display. 
:)
declare function tei2html:summary-view($nodes as node()*, $lang as xs:string?, $id as xs:string?) as item()* {
  let $id := if($id) then $id else replace($nodes/descendant-or-self::tei:idno[starts-with(.,$global:base-uri)][1],'/tei','')
  return 
      if(contains($id,'/person/')) then tei2html:summary-view-persons($nodes,$id)
      else if(contains($id,'/place/')) then tei2html:summary-view-places($nodes,$id)
      else if(contains($id,'/keyword/')) then tei2html:summary-view-keyword($nodes, $id)
      else if(contains($id,'/bibl/')) then tei2html:summary-view-bibl($nodes, $id)
      else tei2html:summary-view-generic($nodes,$id)   
};

(: Special short view template for Persons :)
declare function tei2html:summary-view-persons($nodes as node()*, $id as xs:string?) as item()* {
    let $title := if($nodes/descendant-or-self::*[@syriaca-tags='#syriaca-headword'][@xml:lang='en']) then 
                    $nodes/descendant-or-self::*[@syriaca-tags='#syriaca-headword'][@xml:lang='en'][1]
                  else $nodes/descendant-or-self::tei:title[1]/text()
    let $syr-title := 
                if($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')][matches(@xml:lang,'^syr')][1]) then
                     <span xml:lang="syr" lang="syr" dir="rtl">{string-join($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')][matches(@xml:lang,'^syr')][1]//text(),' ')}</span>
                else if($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')]) then 
                    '[Syriac Not Available]'
                else () 
    let $ana := for $a in distinct-values($nodes/descendant::tei:seriesStmt/tei:biblScope/tei:title)
                return tei2html:translate-series($a)
    let $birth := if($ana != '') then $nodes/descendant::tei:birth/text() else ()            
    let $death := if($ana != '') then $nodes/descendant::tei:death/text() else ()
    let $floruit := string-join($nodes/descendant-or-self::tei:floruit/text(),' ')
    let $dates := 
        (
        if($birth != '') then $birth else (),
        if($birth != '' and $death != '') then  ' - ' else(),
        if($death != '') then if($birth = '' or empty($birth)) then ('d. ',$death) else  $death else (),
        if($floruit != '') then if($birth != '' or $death != '') then (', ',$floruit) else $floruit else ()
        )                    
    return 
        <div class="short-rec-view">
            <a href="{replace($id,$global:base-uri,$global:nav-base)}" dir="ltr">{(tei2html:tei2html($title),if($syr-title != '') then (' - ', $syr-title) else())}</a>
            <button type="button" class="btn btn-sm btn-default copy-sm clipboard"  
                data-toggle="tooltip" title="Copies record title &amp; URI to clipboard." 
                data-clipboard-action="copy" data-clipboard-text="{normalize-space($title[1])} - {normalize-space($id[1])}">
                    <span class="glyphicon glyphicon-copy" aria-hidden="true"/>
            </button>
            {if($ana != '') then <span class="results-list-desc type" dir="ltr" lang="en">{('(', $ana, if($dates != '') then (', ', $dates) else (),')')}</span>  else()}
            {if(
            $nodes/descendant::tei:person/tei:persName[not(contains(@syriaca-tags,'#syriaca-headword'))][not(matches(@xml:lang,('^syr|^ar|^en-xsrp1')))]) then 
                <span class="results-list-desc names" dir="ltr" lang="en">
                    Names: {
                        for $n in $nodes/descendant::tei:person/tei:persName[not(contains(@syriaca-tags,'#syriaca-headword'))][not(matches(@xml:lang,('^syr|^ar|^en-xsrp1')))] 
                        where $n/position() lt 8
                        return <span class="pers-label badge">{tei2html:tei2html($n)}</span>
                    } 
                </span>
            else ()}
            {if($nodes/descendant-or-self::*[starts-with(@xml:id,'abstract')]) then 
                for $abstract in $nodes/descendant::*[starts-with(@xml:id,'abstract')]
                let $string := string-join($abstract/descendant-or-self::*/text(),' ')
                let $blurb := 
                    if(count(tokenize($string, '\W+')[. != '']) gt 25) then  
                        concat(string-join(for $w in tokenize($string, '\W+')[position() lt 25]
                        return $w,' '),'...')
                     else $string 
                return 
                    <span class="results-list-desc desc" dir="ltr" lang="en">{
                        if($abstract/descendant-or-self::tei:quote) then concat('"',normalize-space($blurb),'"')
                        else $blurb
                    }</span>
            else()}
            {
            if($id != '') then 
            <span class="results-list-desc uri"><span class="srp-label">URI: </span><a href="{replace($id,$global:base-uri,$global:nav-base)}">{$id}</a></span>
            else()
            }
        </div>   
};

(: Special short view template for Places :)
declare function tei2html:summary-view-places($nodes as node()*, $id as xs:string?) as item()* {
    let $title := if($nodes/descendant-or-self::*[@syriaca-tags='#syriaca-headword'][@xml:lang='en']) then 
                    $nodes/descendant-or-self::*[@syriaca-tags='#syriaca-headword'][@xml:lang='en'][1]
                  else $nodes/descendant-or-self::tei:title[1]/text()
    let $syr-title := 
                if($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')][matches(@xml:lang,'^syr')][1]) then
                     <span xml:lang="syr" lang="syr" dir="rtl">{string-join($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')][matches(@xml:lang,'^syr')][1]//text(),' ')}</span>
                else if($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')]) then 
                    '[Syriac Not Available]'
                else () 
    let $series := for $a in distinct-values($nodes/descendant::tei:seriesStmt/tei:biblScope/tei:title)
                   return tei2html:translate-series($a)                
    return 
        <div class="short-rec-view">
                        <a href="{replace($id,$global:base-uri,$global:nav-base)}" dir="ltr">{(tei2html:tei2html($title),if($nodes/descendant::tei:place/@type) then concat(' (',string($nodes/descendant::tei:place/@type),') ') else (),if($syr-title != '') then (' - ', $syr-title) else())}</a>
            <button type="button" class="btn btn-sm btn-default copy-sm clipboard"  
                data-toggle="tooltip" title="Copies record title &amp; URI to clipboard." 
                data-clipboard-action="copy" data-clipboard-text="{normalize-space($title[1])} - {normalize-space($id[1])}">
                    <span class="glyphicon glyphicon-copy" aria-hidden="true"/>
            </button>
            {if($nodes/descendant-or-self::tei:place/tei:placeName[not(contains(@syriaca-tags,'#syriaca-headword'))][not(matches(@xml:lang,('^syr|^ar|^en-xsrp1')))]) then 
                <span class="results-list-desc names" dir="ltr" lang="en">
                    Names: {
                        for $n in $nodes/descendant::tei:place/tei:placeName[not(contains(@syriaca-tags,'#syriaca-headword'))][not(matches(@xml:lang,('^syr|^ar|^en-xsrp1')))] 
                        where $n/position() lt 8
                        return <span class="pers-label badge">{tei2html:tei2html($n)}</span>
                    } 
                </span>
             else ()}
            {if($nodes/descendant-or-self::*[starts-with(@xml:id,'abstract')]) then 
                for $abstract in $nodes/descendant::*[starts-with(@xml:id,'abstract')]
                let $string := string-join($abstract/descendant-or-self::*/text(),' ')
                let $blurb := 
                    if(count(tokenize($string, '\W+')[. != '']) gt 25) then  
                        concat(string-join(for $w in tokenize($string, '\W+')[position() lt 25]
                        return $w,' '),'...')
                     else $string 
                return 
                    <span class="results-list-desc desc" dir="ltr" lang="en">{
                        if($abstract/descendant-or-self::tei:quote) then concat('"',normalize-space($blurb),'"')
                        else $blurb
                    }</span>
            else()}
            {
            if($id != '') then 
            <span class="results-list-desc uri"><span class="srp-label">URI: </span><a href="{replace($id,$global:base-uri,$global:nav-base)}">{$id}</a></span>
            else()
            }
        </div>   
};

(: Special short view template for Keywords/Taxonomy :)
declare function tei2html:summary-view-keyword($nodes as node()*, $id as xs:string?) as item()* {
    let $title := if($nodes/descendant-or-self::tei:term[@syriaca-tags='#syriaca-headword'][@xml:lang='en']) then 
                    $nodes/descendant-or-self::tei:term[@syriaca-tags='#syriaca-headword'][@xml:lang='en'][1]/text()
                  else $nodes/descendant-or-self::tei:term[1]/text()                  
    return 
        <div class="short-rec-view">
            <a href="{replace($id,$global:base-uri,$global:nav-base)}" dir="ltr">{$title}</a>
            <button type="button" class="btn btn-sm btn-default copy-sm clipboard"  
                data-toggle="tooltip" title="Copies record title &amp; URI to clipboard." 
                data-clipboard-action="copy" data-clipboard-text="{normalize-space($title)} - {normalize-space($id)}">
                    <span class="glyphicon glyphicon-copy" aria-hidden="true"/>
            </button>
            {if($nodes/descendant::*[starts-with(@xml:id,'abstract')]) then 
                for $abstract in $nodes/descendant::*[starts-with(@xml:id,'abstract')]
                let $string := string-join($abstract/descendant-or-self::*/text(),' ')
                let $blurb := 
                    if(count(tokenize($string, '\W+')[. != '']) gt 25) then  
                            concat(string-join(for $w in tokenize($string, '\W+')[position() lt 25]
                            return $w,' '),'...')  
                     else $string 
                return 
                    if($abstract/descendant-or-self::tei:quote) then 
                        concat('"',$blurb,'"')
                    else $blurb
            else()}
            {
            if($id != '') then 
            <span class="results-list-desc uri"><span class="srp-label">URI: </span><a href="{replace($id,$global:base-uri,$global:nav-base)}">{$id}</a></span>
            else()
            }
        </div>   
};

(: Generic short view template :)
declare function tei2html:summary-view-generic($nodes as node()*, $id as xs:string?) as item()* {
    let $title := if($nodes/descendant-or-self::tei:title[@syriaca-tags='#syriaca-headword'][@xml:lang='en']) then 
                    $nodes/descendant-or-self::tei:title[@syriaca-tags='#syriaca-headword'][@xml:lang='en'][1]/text()
                  else $nodes/descendant-or-self::tei:title[1]/text()
    let $series := for $a in distinct-values($nodes/descendant::tei:seriesStmt/tei:biblScope/tei:title)
                   return tei2html:translate-series($a)
    return 
        <div class="short-rec-view">
            <a href="{replace($id,$global:base-uri,$global:nav-base)}" dir="ltr">{$title}</a>
            <button type="button" class="btn btn-sm btn-default copy-sm clipboard"  
                data-toggle="tooltip" title="Copies record title &amp; URI to clipboard." 
                data-clipboard-action="copy" data-clipboard-text="{normalize-space($title[1])} - {normalize-space($id[1])}">
                    <span class="glyphicon glyphicon-copy" aria-hidden="true"/>
            </button>
            {if($series != '') then <span class="results-list-desc type" dir="ltr" lang="en">{(' (',$series,') ')}</span> else ()}
            {if($nodes/descendant-or-self::*[starts-with(@xml:id,'abstract')]) then 
                for $abstract in $nodes/descendant::*[starts-with(@xml:id,'abstract')]
                let $string := string-join($abstract/descendant-or-self::*/text(),' ')
                let $blurb := 
                    if(count(tokenize($string, '\W+')[. != '']) gt 25) then  
                        concat(string-join(for $w in tokenize($string, '\W+')[position() lt 25]
                        return $w,' '),'...')
                     else $string 
                return 
                    <span class="results-list-desc desc" dir="ltr" lang="en">{
                        if($abstract/descendant-or-self::tei:quote) then concat('"',normalize-space($blurb),'"')
                        else $blurb
                    }</span>
            else()}
            {
            if($id != '') then 
            <span class="results-list-desc uri"><span class="srp-label">URI: </span><a href="{replace($id,$global:base-uri,$global:nav-base)}">{$id}</a></span>
            else()
            }
        </div>   
};

declare function tei2html:summary-view-bibl($nodes as node()*, $id as xs:string?) as item()* {
    let $title := if($nodes/descendant-or-self::tei:title[@syriaca-tags='#syriaca-headword'][@xml:lang='en']) then 
                    $nodes/descendant-or-self::tei:title[@syriaca-tags='#syriaca-headword'][@xml:lang='en'][1]/text()
                  else $nodes/descendant-or-self::tei:title[1]/text()
    let $series := for $a in distinct-values($nodes/descendant::tei:seriesStmt/tei:biblScope/tei:title)
                   return tei2html:translate-series($a)
    return 
        <div class="short-rec-view">
            <a href="{replace($id,$global:base-uri,$global:nav-base)}" dir="ltr">{$title}</a>
            <button type="button" class="btn btn-sm btn-default copy-sm clipboard"  
                data-toggle="tooltip" title="Copies record title &amp; URI to clipboard." 
                data-clipboard-action="copy" data-clipboard-text="{normalize-space($title[1])} - {normalize-space($id[1])}">
                    <span class="glyphicon glyphicon-copy" aria-hidden="true"/>
            </button>
            <span class="results-list-desc desc" dir="ltr" lang="en">{
                bibl2html:citation($nodes/descendant::tei:biblStruct)
                (:global:tei2html(<citation xmlns="http://www.tei-c.org/ns/1.0">{$nodes/descendant::tei:biblStruct}</citation>):)
            }</span>
            {
            if($id != '') then 
            <span class="results-list-desc uri"><span class="srp-label">URI: </span><a href="{replace($id,$global:base-uri,$global:nav-base)}">{$id}</a></span>
            else()
            }
        </div>
};

declare function tei2html:summary-view-spear($nodes as node()*, $id as xs:string?) as item()* {
    let $title := if($nodes/descendant-or-self::*[@syriaca-tags='#syriaca-headword'][@xml:lang='en']) then 
                    $nodes/descendant-or-self::*[@syriaca-tags='#syriaca-headword'][@xml:lang='en'][1]
                  else $nodes/descendant-or-self::tei:title[1]/text()
    let $syr-title := 
                if($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')][matches(@xml:lang,'^syr')][1]) then
                     <span xml:lang="syr" lang="syr" dir="rtl">{string-join($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')][matches(@xml:lang,'^syr')][1]//text(),' ')}</span>
                else if($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')]) then 
                    '[Syriac Not Available]'
                else () 
    let $ana := for $a in distinct-values($nodes/descendant::tei:seriesStmt/tei:biblScope/tei:title)
                    return tei2html:translate-series($a)
    let $birth := if($ana != '') then $nodes/descendant::tei:birth/text() else ()            
    let $death := if($ana != '') then $nodes/descendant::tei:death/text() else ()
    let $floruit := string-join($nodes/descendant-or-self::tei:floruit/text(),' ')
    let $dates := 
            (
            if($birth != '') then $birth else (),
            if($birth != '' and $death != '') then  ' - ' else(),
            if($death != '') then if($birth = '' or empty($birth)) then ('d. ',$death) else  $death else (),
            if($floruit != '') then if($birth != '' or $death != '') then (', ',$floruit) else $floruit else ()
            )                    
    return                    
    <div class="short-rec-view">
        <a href="aggregate.html?id={$id}" dir="ltr">{(tei2html:tei2html($title),if($nodes/descendant::tei:place/@type) then concat(' (',string($nodes/descendant::tei:place/@type),') ') else (),if($syr-title != '') then (' - ', $syr-title) else())}</a>
        {if($ana != '') then <span class="results-list-desc type" dir="ltr" lang="en">{('(', $ana, if($dates != '') then (', ', $dates) else (),')')}</span>  else()}
            {if(
            $nodes/descendant::tei:person/tei:persName[not(contains(@syriaca-tags,'#syriaca-headword'))][not(matches(@xml:lang,('^syr|^ar|^en-xsrp1')))]) then 
                <span class="results-list-desc names" dir="ltr" lang="en">
                    Names: {
                        for $n in $nodes/descendant::tei:person/tei:persName[not(contains(@syriaca-tags,'#syriaca-headword'))][not(matches(@xml:lang,('^syr|^ar|^en-xsrp1')))] 
                        where $n/position() lt 8
                        return <span class="pers-label badge">{tei2html:tei2html($n)}</span>
                    } 
                </span>
            else ()}
            {if($nodes/descendant-or-self::*[starts-with(@xml:id,'abstract')]) then 
                for $abstract in $nodes/descendant::*[starts-with(@xml:id,'abstract')]
                let $string := string-join($abstract/descendant-or-self::*/text(),' ')
                let $blurb := 
                    if(count(tokenize($string, '\W+')[. != '']) gt 25) then  
                        concat(string-join(for $w in tokenize($string, '\W+')[position() lt 25]
                        return $w,' '),'...')
                     else $string 
                return 
                    <span class="results-list-desc desc" dir="ltr" lang="en">{
                        if($abstract/descendant-or-self::tei:quote) then concat('"',normalize-space($blurb),'"')
                        else $blurb
                    }</span>
            else()}
        <span class="results-list-desc uri"><span class="srp-label">For additional information, see: </span><a href="{replace($id,$global:base-uri,$global:nav-base)}">{$id}</a></span>
    </div>        
};

declare function tei2html:title-display($nodes as node()*){
    <span id="title">
        {(
            if($nodes/descendant-or-self::tei:entryFree) then
                concat('Term: ', tei2html:tei2html($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')][starts-with(@xml:lang,'en')][not(empty(node()))][1]))
            else if($nodes/descendant::*[contains(@syriaca-tags,'#anonymous-description')]) then
                string-join($nodes/descendant::*[contains(@syriaca-tags,'#anonymous-description')][1],' ')
            else if($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')]) then
                (string(tei2html:tei2html($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')][starts-with(@xml:lang,'en')][not(empty(node()))][1])),
                ' - ',
                if($nodes/descendant::*[contains(@syriaca-tags,'#anonymous-description')]) then 
                    string(tei2html:tei2html($nodes/descendant::*[contains(@syriaca-tags,'#anonymous-description')][1]))
                else if($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')][starts-with(@xml:lang,'syr')]) then 
                    <span lang="syr" dir="rtl">{string(tei2html:tei2html($nodes/descendant::*[contains(@syriaca-tags,'#syriaca-headword')][starts-with(@xml:lang,'syr')][1]))}</span>
                else '[ Syriac Not Available ]'
                )
            else tei2html:tei2html($nodes/descendant-or-self::tei:title[1])
           (:NOTE: need to add dates for persons. see xslt :)
        )}
   </span>
};

declare function tei2html:translate-series($series as xs:string?){
    if($series = 'The Syriac Biographical Dictionary') then ()
    else if($series = 'A Guide to Syriac Authors') then 
        <a href="{$global:nav-base}/authors/index.html"><img src="{$global:nav-base}/resources/img/icons-authors-sm.png" alt="A Guide to Syriac Authors"/>author</a>
    else if($series = 'Qadishe: A Guide to the Syriac Saints') then 
        <a href="{$global:nav-base}/q/index.html"><img src="{$global:nav-base}/resources/img/icons-q-sm.png" alt="Qadishe: A Guide to the Syriac Saints"/>saint</a>        
    else $series
};

(:~ 
 : Reworked KWIC to be more 'Google like' used examples from: http://ctb.kantl.be/download/kwic.xql for preceding and following content. 
 : Pass content through tei2html:tei2html() to handle simple things like suppression of tei:orig, etc. Could be made more robust to hide URI's as well. 
 :
 : @see : https://rvdb.wordpress.com/2011/07/20/from-kwic-display-to-kwicer-processing-with-exist/
          http://ctb.kantl.be/download/kwic.xql
:)
declare function tei2html:output-kwic($nodes as node()*){
    for $node in subsequence($nodes//exist:match,1,8)
    return
        <span>{tei2html:kwic-truncate-previous($node/ancestor-or-self::tei:div[@type='entry'], $node, (), 40)} 
                &#160;<span class="match">{$node/text()}</span>
                {tei2html:kwic-truncate-following($node/ancestor-or-self::tei:div[@type='entry'], $node, (), 40)} </span>
};

(:~
	Generate the left-hand context of the match. Returns a normalized string, 
	whose total string length is less than or equal to $width characters.
	Note: this function calls itself recursively until $node is empty or
	the returned sequence has the desired total string length.
:)
declare function tei2html:kwic-truncate-previous($root as node()?, $node as node()?, $truncated as item()*, $width as xs:int) {
  let $nextProbe := $node/preceding::text()[1]
  let $next := if ($root[not(. intersect $nextProbe/ancestor::*)]) then () else tei2html:tei2html($nextProbe)  
  let $probe :=  concat($nextProbe, ' ', $truncated)
  return
    if (string-length($probe) gt $width) then
      let $norm := concat(normalize-space($probe), ' ')
      return 
        if (string-length($norm) le $width and $next) then
          tei2html:kwic-truncate-previous($root, $next, $norm, $width)
        else if ($next) then
          concat('...', substring($norm, string-length($norm) - $width + 1))
        else $norm
    else if ($next) then 
      tei2html:kwic-truncate-previous($root, $next, $probe, $width)
    else for $str in normalize-space($probe)[.] return concat($str, ' ')
};

declare function tei2html:kwic-truncate-following($root as node()?, $node as node()?, $truncated as item()*, $width as xs:int) {
  let $nextProbe := $node/following::text()[1]
  let $next := if ($root[not(. intersect $nextProbe/ancestor::*)]) then () else tei2html:tei2html($nextProbe)  
  let $probe :=  concat($nextProbe, ' ', $truncated)
  return
    if (string-length($probe) gt $width) then
      let $norm := concat(normalize-space($probe), ' ')
      return 
        if (string-length($norm) le $width and $next) then
          tei2html:kwic-truncate-following($root, $next, $norm, $width)
        else if ($next) then
          concat('...', substring($norm, string-length($norm) - $width + 1))
        else $norm
    else if ($next) then 
      tei2html:kwic-truncate-following($root, $next, $probe, $width)
    else for $str in normalize-space($probe)[.] return concat($str, ' ')
};