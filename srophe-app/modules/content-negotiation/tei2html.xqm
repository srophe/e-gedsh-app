xquery version "3.0";
(:~
 : Builds tei conversions. 
 : Used by oai, can be plugged into other outputs as well.
 :)
 
module namespace tei2html="http://srophe.org/srophe/tei2html";
import module namespace bibl2html="http://srophe.org/srophe/bibl2html" at "bibl2html.xqm";
import module namespace config="http://srophe.org/srophe/config" at "../config.xqm";

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
            case element(tei:foreign) return element span 
                {(
                if($node/@xml:lang) then attribute lang { $node/@xml:lang } else (),
                if($node/@xml:lang = ('syr','ar','he')) then attribute dir { 'rtl' } else (),
                tei2html:tei2html($node/node())
                )}
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
            case element(tei:orig) return 
                <span class="tei-orig">{
                if($node/tei:date) then 
                    <span class="tei-date">{(' (',tei2html:tei2html($node/tei:date),')')}</span>
                else tei2html:tei2html($node/node())
                }</span>
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
                                    string-join(for $part in $node/child::*
                                    order by $part/@sort ascending, string-join($part/descendant-or-self::text(),' ') descending
                                    return tei2html:tei2html($part/node()),' ')
                                 else tei2html:tei2html($node/node())
                    return
                        if($node/@ref) then
                            element a { attribute href { $node/@ref }, $name }
                        else $name                                 
                        }</span>
            case element(tei:quote) return
                ('"',tei2html:tei2html($node/node()),'"')
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
                        tei2html:tei2html($node/node()))                 
                    }</span>
            default return <span class="tei-{local-name($node)}">{tei2html:tei2html($node/node())}</span>
};

(:
 : Used for short views of records, browse, search or related items display. 
:)
declare function tei2html:summary-view($nodes as node()*,$id as xs:string?) as item()* {
  if($nodes/descendant-or-self::tei:ab[@type='crossreference']) then
    tei2html:summary-view-crossref($nodes,$id)
  else tei2html:summary-view-generic($nodes,$id,())   
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
               <a href="{$config:nav-base}/entry/{$recID}">{$nodes/tei:head}</a>
               <span class="type">{$nodes/tei:ab[@type='infobox']}</span>
           </span>
           {(if($nodes/descendant::tei:byline) then
            <span class="results-list-desc sort-title">
                <span>Contributor: </span>
                <i>{$nodes/descendant::tei:byline/tei:persName}</i>
            </span>
           else (),
           if($kwic != '') then
            <span class="results-list-desc type">{tei2html:output-kwic($kwic, $id)}</span>
           else ()
           )}
           <span class="results-list-desc uri">
               <span class="srp-label">URI: </span>
               <a href="{$config:nav-base}/entry/{$recID}">{$id}</a>
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
 : Borrowed regex to solve util:expand slowness
 : See: https://exist-open.markmail.org/message/bwcxoq3dg5e3zeis?q=util:expand+is+slow
 
:)
declare function tei2html:queryToRegex($q as xs:string, $input as xs:string) as xs:string {
    if (ends-with($q,'"') and starts-with($q,'"')) then
        "(^|[^a-zA-Z])" ||
        replace(substring(substring($q,2),1,string-length($q)-2)," +"," +") ||
        "([^a-zA-Z]|$)"
    else
        if (not(contains($q," "))) then
            "([^a-zA-Z]|^)" || replace(replace($q,"[*]","[^ ]*"),"[?]","[^ ]") || "([^a-zA-Z]|$)"
        else
            let $terms := replace(replace($q," OR "," ")," AND "," ")
            return
            (if (matches($input,"([^a-zA-Z]|^)"||$q||"([^a-zA-Z]|$)","i")) then
                "([^a-zA-Z]|^)"||$q||"([^a-zA-Z]|$)|"
             else "") ||
                string-join(for $term in tokenize($terms)
                let $wildcards := replace(replace($term,"[*]","[^ ]*"),"[?]","[^]")
                return "([^a-zA-Z]|^)" || $wildcards || "([^a-zA-Z]|$)","|")
};

declare function tei2html:highlight($toHighlight as node(), $searchterm as xs:string) as node()* {
        try {
            let $regex := tei2html:queryToRegex($searchterm,$toHighlight/text())
            let $ana := fn:analyze-string( $toHighlight/text(),$regex, "i")
            for $s in $ana/*
            return
            if (fn:local-name($s)='non-match') then
                fn:string-join($s//text())
            else <strong>{
                fn:string-join($s//text())
            }</strong>
        } catch * {
            (util:log("warn", $err:code || ": " || $err:description),
            <span>{$toHighlight//text()}</span>)
        }
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
                                (:string-join(for $word in tokenize(request:get-parameter('q', ''),'\s+')
                                            return $word,concat('\W+(\w+\W+){1,',request:get-parameter('keywordProximity', ''),'}?'))
                                            :)
                                string-join(for $word in tokenize(request:get-parameter('q', ''),'\s+')
                                            return $word,concat('.*(\w+\W+){1,',request:get-parameter('keywordProximity', ''),'}?'))                                            
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
    (:let $link := concat($config:nav-base,'/',tokenize($id,'/')[last()],'#',$node/@n):)
    return <span>{$prevString}&#160;<span class="match" style="background-color:yellow;">{$node/text()}</span>&#160;{$nextString}</span>
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
                <match xmlns="http://www.w3.org/1999/xhtml">{(if($node/*[@n]) then attribute n {concat('n-id.',$node/@n)} else (), $node/node())}</match>
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