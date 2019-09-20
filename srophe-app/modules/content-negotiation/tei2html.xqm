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
            case element(tei:ref) return
                if($node/parent::tei:ab[@type='crossreference']) then 
                    if($node/@target) then
                        <a href="{replace($node/@target,$global:base-uri,$global:nav-base)}">{$node//text()}</a>
                    else if($node[@type='lookup']) then   
                        <a href="{concat($global:nav-base,'/search.html?q=',$node//text())}">{$node//text()}</a>
                    else if($node[@type='authorLookup']) then   
                        <a href="{concat($global:nav-base,'/search.html?author=',$node//text())}">{$node//text()}</a>
                    else <a href="{concat($global:nav-base,'/search.html?q=',$node//text())}">{$node//text()}</a>
                else tei2html:tei2html($node/node())                    
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
            case element(tei:persName) return 
                <span class="tei-persName">{
                    if($node/child::*) then 
                        for $part in $node/child::*
                        order by $part/@sort ascending, string-join($part/descendant-or-self::text(),' ') descending
                        return tei2html:tei2html($part/node())
                    else tei2html:tei2html($node/node())
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
                    <span class="tei-title {$titleType}">{
                        (if($node/@xml:lang) then attribute lang { $node/@xml:lang } else (),
                        tei2html:tei2html($node/node()))                 
                    }</span>
            case element(tei:foreign) return 
                <span dir="{if($node/@xml:lang = ('syr','ar','^syr')) then 'rtl' else 'ltr'}">{
                    tei2html:tei2html($node/node())
                }</span>
            default return tei2html:tei2html($node/node())
};

(:
 : Used for short views of records, browse, search or related items display. 
:)
declare function tei2html:summary-view($nodes as node()*,$id as xs:string?) as item()* {
  if($nodes/descendant-or-self::tei:ab[@type='crossreference']) then
    tei2html:summary-view-crossref($nodes,$id)
  else tei2html:summary-view-generic($nodes,$id)   
};

(: Generic short view template :)
declare function tei2html:summary-view-generic($nodes as node()*, $id as xs:string?) as item()* {    
    let $recID :=  tokenize($id,'/')[last()]
    return 
       <div class="results-list {if($nodes[@type = ('subsection','subSubsection')]) then 'indent' else ()}">
          <span class="sort-title">  
               <a href="{$global:nav-base}/{$recID}">{$nodes/tei:head}</a>
               <span class="type">{$nodes/tei:ab[@type='infobox']}</span>
           </span>
           {if($nodes/descendant::tei:byline) then
            <span class="results-list-desc sort-title">
                <span>Contributor: </span>
                <i>{$nodes/descendant::tei:byline/tei:persName}</i>
            </span>
           else ()}
           <span class="results-list-desc uri">
               <span class="srp-label">URI: </span>
               <a href="{$global:nav-base}/{$recID}">{$id}</a>
           </span>
       </div>   
};

(: Generic short view template :)
declare function tei2html:summary-view-crossref($nodes as node()*, $id as xs:string?) as item()* {
    let $recID :=  tokenize($id,'/')[last()]
    return 
        <div class="results-list">
           <span class="sort-title">
            {$nodes/tei:head}&#160;{tei2html:tei2html($nodes//tei:ab)} </span>
        </div>  
};

(:~ 
 : Reworked  KWIC to be more 'Google like' 
 : Passes content through  tei2html:kwic-format() to output only text and matches 
 : Note: could be made more robust to match proximity operator, it it is greater the 10 it may be an issue.
 : To do, pass search params to record, highlight hits in record 
   let $search-params := 
        string-join(
            for $param in request:get-parameter-names()
            return 
                if($param = ('fq','start')) then ()
                else if(request:get-parameter($param, '') = ' ') then ()
                else concat('&amp;',$param, '=',request:get-parameter($param, '')),'')
:)
declare function tei2html:output-kwic($nodes as node()*, $id as xs:string*){
    let $results := <results xmlns="http://www.w3.org/1999/xhtml">{
                      if(request:get-parameter('keywordProximity', '') castable as xs:integer) then
                        let $wordList := 
                                string-join(for $word in tokenize(request:get-parameter('q', ''),'\s')
                                    return $word,concat('\W+(\w+\W+){1,',request:get-parameter('keywordProximity', ''),'}?'))                      
                        let $pattern := concat('(',$wordList,')\W+(\w+\W+){1,',request:get-parameter('keywordProximity', ''),'}?(',$wordList,')')
                        let $highlight := function($string as xs:string) { <match xmlns="http://www.w3.org/1999/xhtml">{$string}</match> }
                        return tei2html:highlight-matches($nodes, $wordList, $highlight)
                      else tei2html:kwic-format($nodes)
                    }</results>   
    let $count := count($results//*:match)
    for $node at $p in subsequence($results//*:match,1,8)
    let $prev := $node/preceding-sibling::text()[1]
    let $next := $node/following-sibling::text()[1]
    let $prevString := 
                if(string-length($prev) gt 60) then 
                    concat(' ...',substring($prev,string-length($prev) - 100, 100))
                else $prev
    let $nextString := 
                if(string-length($next) lt 100 ) then () 
                else concat(substring($next,1,100),'... ')
    let $link := concat($global:nav-base,'/',tokenize($id,'/')[last()],'#',$node/@n)
    return <span>{$prevString}&#160;<span class="match" style="background-color:yellow;"><a href="{$link}">{$node/text()}</a></span>&#160;{$nextString}</span>
};

(:~
 : Strips results to just text and matches. 
 : Note, could pass though tei2html:tei2html() to hide hidden content (choice/orig)
:)
declare function tei2html:kwic-format($nodes as node()*){
    for $node in $nodes
    return 
        typeswitch($node)
            case text() return $node
            case comment() return ()
            case element(exist:match) return  
                <match xmlns="http://www.w3.org/1999/xhtml">
                    {(if($node/*[@n]) then attribute n {concat('n-id.',$node/@n)} else (), $node/node())}</match>
            default return tei2html:kwic-format($node/node())                
};

(:~ 
 : Highlight matches for proximity search. 
 : @see https://gist.github.com/joewiz/5937897
:)
declare function tei2html:highlight-matches($nodes as node()*, $pattern as xs:string, $highlight as function(xs:string) as item()* ) { 
    for $node in $nodes
    return
        typeswitch ( $node )
            case element() return
                tei2html:highlight-matches($node/node(), $pattern, $highlight)
            case text() return
                for $segment in analyze-string($node, $pattern, 'i')/node()
                return
                    if ($segment instance of element(fn:match)) then 
                        $highlight($segment/string())
                    else 
                        $segment/string()
            case document-node() return
                document { tei2html:highlight-matches($node/node(), $pattern, $highlight) }
            default return
                $node
};