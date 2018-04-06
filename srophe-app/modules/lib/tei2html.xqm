xquery version "3.0";
(:~
 : Builds tei conversions. 
 : Used by oai, can be plugged into other outputs as well.
 :)
 
module namespace tei2html="http://syriaca.org/tei2html";
import module namespace global="http://syriaca.org/global" at "global.xqm";

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
                        <a href="{replace($node/@target,$global:base-uri,concat($global:nav-base,'/entry'))}">{$node//text()}</a>
                    else if($node[@type='lookup']) then   
                        <a href="{concat($global:nav-base,'/search.html?q=',$node//text())}">{$node//text()}</a>
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
declare function tei2html:summary-view($nodes as node()*,$id as xs:string?, $kwic as node()*) as item()* {
  if($nodes/descendant-or-self::tei:ab[@type='crossreference']) then
    tei2html:summary-view-crossref($nodes,$id)
  else tei2html:summary-view-generic($nodes,$id,$kwic)   
};

(: Generic short view template :)
declare function tei2html:summary-view-generic($nodes as node()*, $id as xs:string?, $kwic as node()*) as item()* {    
    let $recID :=  tokenize($id,'/')[last()]
    return 
       <div class="results-list {if($nodes[@type = ('subsection','subSubsection')]) then 'indent' else ()}">
          <span class="sort-title">  
               <a href="{$global:nav-base}/entry/{$recID}">{$nodes/tei:head}</a>
               <span class="type">{$nodes/tei:ab[@type='infobox']}</span>
           </span>
           {(if($nodes/descendant::tei:byline) then
            <span class="results-list-desc sort-title">
                <span>Author: </span>
                <i>{$nodes/descendant::tei:byline/tei:persName}</i>
            </span>
           else (),
           if($kwic != '') then
            <span class="results-list-desc type">{tei2html:output-kwic($kwic, $id)}</span>
           else ()
           )}
           <span class="results-list-desc uri">
               <span class="srp-label">URI: </span>
               <a href="{$global:nav-base}/entry/{$recID}">{$id}</a>
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
 : Reworked KWIC to be more 'Google like' used examples from: http://ctb.kantl.be/download/kwic.xql for preceding and following content. 
 : Pass content through tei2html:tei2html() to handle simple things like suppression of tei:orig, etc. Could be made more robust to hide URI's as well. 
 :
 : @see : https://rvdb.wordpress.com/2011/07/20/from-kwic-display-to-kwicer-processing-with-exist/
          http://ctb.kantl.be/download/kwic.xql
:)
declare function tei2html:output-kwic($nodes as node()*, $id as xs:string?){
    for $node in subsequence($nodes//exist:match,1,8)
    return
        <span>{tei2html:kwic-truncate-previous($node/ancestor-or-self::tei:div[@type='entry'], $node, (), 40)} 
                &#160;<span class="match" style="background-color:yellow;">{$node/text()}</span>
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
  let $next := if ($root[not(. intersect $nextProbe/ancestor::*)]) then () else $nextProbe  
  let $probe :=  concat($nextProbe, ' ', $truncated)
  return
    if (string-length($probe) gt $width) then
      let $norm := concat(normalize-space($probe), ' ')
      return 
        if (string-length($norm) le $width and $next) then
          tei2html:kwic-truncate-previous($root, $next, $norm, $width)
        else if ($next) then
          concat('...', substring($norm, string-length($norm) - $width + 1))
        else 
          tei2html:tei2html($norm)
    else if ($next) then 
      tei2html:kwic-truncate-previous($root, $next, $probe, $width)
    else for $str in normalize-space($probe)[.] return concat($str, ' ')
};

declare function tei2html:kwic-truncate-following($root as node()?, $node as node()?, $truncated as item()*, $width as xs:int) {
  let $nextProbe := $node/following::text()[1]
  let $next := if ($root[not(. intersect $nextProbe/ancestor::*)]) then () else $nextProbe  
  let $probe :=  concat($nextProbe, ' ', $truncated)
  return
    if (string-length($probe) gt $width) then
      let $norm := concat(normalize-space($probe), ' ')
      return 
        if (string-length($norm) le $width and $next) then
          tei2html:kwic-truncate-following($root, $next, $norm, $width)
        else if ($next) then
          concat('...', substring($norm, string-length($norm) - $width + 1))
        else 
          tei2html:tei2html($norm)
    else if ($next) then 
      tei2html:kwic-truncate-following($root, $next, $probe, $width)
    else for $str in normalize-space($probe)[.] return concat($str, ' ')
};