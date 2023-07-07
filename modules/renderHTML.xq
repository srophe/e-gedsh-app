xquery version "3.1";

(:~
 : Pre-render HTML versions of all content pages
 : Combination of @wsalesky's storeAsHTML and code by @line-o
 : https://gist.github.com/line-o/d2682a42a3028d5b4125759a10603c5f#file-pre-render-xq-L25
 : Uses templating module to pre-render HTML pages and store them in the app. Run on first deploy of application
 : Tie webhooks to this module to update/add pages.
 : 
 : WS:Note to use this, I will need a main page that calls headers,nav,content and footers, then applies all the templates in the app.xqm
 : A work in progress 
:)

declare namespace pr="http://line-o.de/ns/pre-render";

import module namespace config="http://srophe.org/srophe/config" at "config.xqm";
import module namespace templates="http://exist-db.org/xquery/html-templating";
import module namespace lib="http://exist-db.org/xquery/html-templating/lib";

import module namespace app="http://srophe.org/srophe/templates" at "app.xql";
import module namespace browse="http://srophe.org/srophe/browse" at "browse.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace srophe="https://srophe.app";

(:
 : We have to provide a lookup function to templates:apply to help it
 : find functions in the imported application modules. The templates
 : module cannot see the application modules, but the inline function
 : below does see them.
 :)
declare variable $pr:lookup := function($functionName as xs:string, $arity as xs:int) {
    function-lookup(xs:QName($functionName), $arity)
};

(: templating configuration :)
declare variable $pr:config := map {
    $templates:CONFIG_APP_ROOT : $config:app-root,
    $templates:CONFIG_STOP_ON_ERROR : true(),
    $templates:CONFIG_FILTER_ATTRIBUTES : false()
};

(: base template for all pages :)
declare variable $pr:page-template := doc("../entry.html");

(: Helper function to recursively create a collection hierarchy. :)
declare function pr:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xmldb:create-collection($collection, $components[1]),
            pr:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function pr:mkcol($collection, $path) {
    pr:mkcol-recursive($collection, tokenize($path, "/"))
};

(: our render function is only dependent on the model :)
declare function pr:render ($model as map(*)) {
    templates:apply(
        $pr:page-template, $pr:lookup,
        $model, 
        $pr:config
    )
};

declare function pr:render-record($record as node()) {
     let $record-model := map {'data' : $record}
    let $rendered := 
        <html xmlns="http://www.w3.org/1999/xhtml">
            {pr:render($record-model)}
        </html>
    let $path := document-uri($record)
    let $file := tokenize($path,'/')[last()]
    let $fileName := replace($file,'.xml','.html')
    let $htmlPath := concat($config:app-root,'/html/')
    let $buildPath := 
                    if(xmldb:collection-available($htmlPath)) then ()
                    else (pr:mkcol("/db/apps", replace($htmlPath,'/db/apps','')))
    return 
        try {xmldb:store($htmlPath, xmldb:encode-uri($fileName), $rendered)} 
        catch *{
                    <response status="fail">
                        <message>Failed to add resource {$fileName}: {concat($err:code, ": ", $err:description)}</message>
                    </response>
                } 
};

declare function pr:render-toc($records as node()*) {
    let $rendered := 
        <div xmlns="http://www.w3.org/1999/xhtml">
            {templates:apply(
                doc("../toc.html"), $pr:lookup,
                (), 
                $pr:config
            )}
        </div>
    let $fileName := 'toc.html'
    let $htmlPath := concat($config:app-root,'/html/')
    let $buildPath := 
                    if(xmldb:collection-available($htmlPath)) then ()
                    else (pr:mkcol("/db/apps", replace($htmlPath,'/db/apps','')))
    return 
        try {xmldb:store($htmlPath, xmldb:encode-uri($fileName), $rendered)} 
        catch *{
                    <response status="fail">
                        <message>Failed to add resource {$fileName}: {concat($err:code, ": ", $err:description)}</message>
                    </response>
                }           
};


(: load article data :)
<div>{
    if(request:get-parameter('toc', '')  = 'true') then
        pr:render-toc(())
    else 
        let $start := if(request:get-parameter('start', '') != '') then request:get-parameter('start', '') else 1
        let $limit := if(request:get-parameter('limit', '') != '') then request:get-parameter('limit', '') else 50
        let $startParam := if(request:get-parameter('start', '') != '') then concat('&amp;start=',request:get-parameter('start', '')) else '&amp;start=0'
        let $limitParam := if(request:get-parameter('limit', '') != '') then concat('&amp;limit=',request:get-parameter('limit', '')) else '&amp;limit=200'
        let $action := if(request:get-parameter('action', '') != '') then request:get-parameter('action', '') else 'check'
        let $items := if(request:get-parameter('id', '') != '') then collection($config:data-root)//tei:TEI[.//tei:idno[. = request:get-parameter('id', '')][@type='URI']] else collection($config:data-root || '/tei/articles')
        let $total := count($items)
        let $next := if(xs:integer($start) lt xs:integer($total)) then (xs:integer($start) + xs:integer($limit)) else ()
        let $group := 
            for $record in subsequence($items,$start,$limit)
            return 
                pr:render-record($record)
        return 
            if($next) then
                ($group,
                <div xmlns="http://www.w3.org/1999/xhtml">
                    <p>Processed {if(request:get-parameter('start', '') != '') then request:get-parameter('start', '') else '0'} - {substring-before($next,'&amp;')} of {string($total)}</p>
                    <p><a href="?start={$next}&amp;limit={$limit}" class="btn btn-info zotero">Next</a></p>
                </div>)
            else 
                ($group,
                <div><h3>Updated!</h3>
                    <p><label>Number of updated records: </label> {string($total)}</p>
                 </div>)             
}</div>
