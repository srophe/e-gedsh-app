xquery version "3.0";
(: Main module for interacting with eXist-db templates :)
module namespace app="http://syriaca.org/templates";
(: eXist modules :)
import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://syriaca.org/config" at "config.xqm";
import module namespace functx="http://www.functx.com";
(: Srophe modules :)
import module namespace teiDocs="http://syriaca.org/teiDocs" at "teiDocs/teiDocs.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "lib/tei2html.xqm";
import module namespace global="http://syriaca.org/global" at "lib/global.xqm";
import module namespace rel="http://syriaca.org/related" at "lib/get-related.xqm";
import module namespace maps="http://syriaca.org/maps" at "lib/maps.xqm";
import module namespace timeline="http://syriaca.org/timeline" at "lib/timeline.xqm";
(: Namespaces :)
declare namespace http="http://expath.org/ns/http-client";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";

(:~    
 : Simple get record function, get tei record based on tei:idno
 : Builds URL from the following URL patterns defined in the controller.xql or uses the id paramter
 : Retuns 404 page if record is not found, or has been @depreciated
 : Retuns 404 page and redirects if the record has been @depreciated see https://github.com/srophe/srophe-app-data/wiki/Deprecated-Records
 : @param request:get-parameter('id', '') syriaca.org uri   
:)                 
declare function app:get-rec($node as node(), $model as map(*), $collection as xs:string?) { 
if(request:get-parameter('id', '') != '') then 
    let $id := global:resolve-id()   
    return 
        let $rec := 
                    if(request:get-parameter('id', '') = 'front') then 
                        collection($global:data-root)//tei:front
                    else if(request:get-parameter('id', '') = 'back') then 
                        collection($global:data-root)//tei:back
                    else collection($global:data-root)//tei:div[tei:ab/tei:idno[normalize-space(.) = $id]]
        return 
            if(empty($rec)) then request:get-parameter('id', '')
            (:response:redirect-to(xs:anyURI(concat($global:nav-base, '/404.html'))):)
            else 
                if($rec/descendant::tei:revisionDesc[@status='deprecated']) then 
                    let $redirect := 
                            if($rec/descendant::tei:idno[@type='redirect']) then 
                                replace(replace($rec/descendant::tei:idno[@type='redirect'][1]/text(),'/tei',''),$global:base-uri,$global:nav-base)
                            else concat($global:nav-base,'/',$collection,'/','browse.html')
                    return response:redirect-to(xs:anyURI(concat($global:nav-base, '/301.html?redirect=',$redirect)))
                else map {"data" := $rec }
else map {"data" := <div>'Page data'</div>}
};

(:~    
 : Default record display. Runs full TEI record through global:tei2html($data/child::*) for HTML display 
 : For more complicated displays page can be configured using eXistdb templates. See a persons or place html page.
 : Or the page can be organized using templates and Srophe functions to extend TEI visualiation to include 
 : dynamic maps, timelines and xquery enhanced relationships.
 : @param $view swap in functions for other page views/layouts
:)
declare function app:display-rec($node as node(), $model as map(*), $collection as xs:string?){
 global:tei2html($model("data"))    
};

(:~  
 : Default title display, used if no sub-module title function.
 : Used by templating module, not needed if full record is being displayed 
:)
declare function app:h1($node as node(), $model as map(*)){
 global:tei2html(<srophe-title xmlns="http://www.tei-c.org/ns/1.0">{($model("data")/descendant::tei:titleStmt[1]/tei:title[1], $model("data")/descendant::tei:idno[1])}</srophe-title>)
}; 

(:~  
 : Display any TEI nodes passed to the function via the paths parameter
 : Used by templating module, defaults to tei:body if no nodes are passed. 
 : @param $paths comma separated list of xpaths for display. Passed from html page  
:)
declare function app:display-nodes($node as node(), $model as map(*), $paths as xs:string*){
    let $data := $model("data")
    return 
        if($paths != '') then 
            global:tei2html(
                    for $p in tokenize($paths,',')
                    return util:eval(concat('$data',$p)))
        else global:tei2html($model("data")/descendant::tei:body)
}; 

(:
 : Return tei:body/descendant/tei:bibls for use in sources
:)
declare %templates:wrap function app:display-sources($node as node(), $model as map(*)){
    let $sources := $model("data")/descendant::tei:body/descendant::tei:bibl
    return global:tei2html(<sources xmlns="http://www.tei-c.org/ns/1.0">{$sources}</sources>)
};

(:
 : Return tei:body/descendant/tei:bibls for use in sources
:)
declare %templates:wrap function app:display-citation($node as node(), $model as map(*)){
    global:tei2html(<citation xmlns="http://www.tei-c.org/ns/1.0">{
    $model("data")/ancestor::tei:TEI/descendant::tei:teiHeader | 
    $model("data")/tei:head[1] | $model("data")/tei:ab | 
    $model("data")/tei:byline[1]}</citation>) 

};

(:~
 : Passes any tei:geo coordinates in record to map function. 
 : Suppress map if no coords are found. 
:)                   
declare function app:display-map($node as node(), $model as map(*)){
    if($model("data")//tei:geo) then 
        maps:build-map($model("data"),0)
    else ()
};

(:~
 : Process relationships uses lib/timeline.xqm module
:)                   
declare function app:display-timeline($node as node(), $model as map(*)){
    if($model("data")/descendant::tei:body/descendant::*[@when or @notBefore or @notAfter]) then
        <div>                
            <div>{timeline:timeline($model("data")/descendant::tei:body/descendant::*[@when or @notBefore or @notAfter], 'Timeline')}</div>
            <div class="indent">
                <h4>Dates</h4>
                <ul class="list-unstyled">
                    {
                        for $date in $model("data")/descendant::tei:body/descendant::*[@when or @notBefore or @notAfter] 
                        return <li>{global:tei2html($date)}</li>
                    }
                </ul> 
            </div>     
        </div>
     else ()
};
 
(:~
 : Process relationships uses lib/rel.xqm module
:)                   
declare function app:display-related($node as node(), $model as map(*)){
    if($model("data")//tei:body/child::*/tei:listRelation) then 
        rel:build-relationships($model("data")//tei:body/child::*/tei:listRelation, replace($model("data")//tei:idno[@type='URI'][starts-with(.,$global:base-uri)][1],'/tei',''))
    else ()
};

(:~
 : bibl module relationships
:)                   
declare function app:subject-headings($node as node(), $model as map(*)){
    rel:subject-headings($model("data")//tei:idno[@type='URI'][ends-with(.,'/tei')])
};

(:~
 : bibl 
:)                   
declare function app:cited($node as node(), $model as map(*)){
    rel:cited($model("data")//tei:idno[@type='URI'][ends-with(.,'/tei')], request:get-parameter('start', 1),request:get-parameter('perpage', 5))
};

(:~      
 : Get relations to display in body of HTML page
 : Used by NHSL for displaying child works
 : @param $data TEI record
 : @param $relType name/ref of relation to be displayed in HTML page
:)
declare %templates:wrap function app:display-related-inline($data, $relType){
let $rec := $data
let $relType := $relType
let $recid := replace($rec/descendant::tei:idno[@type='URI'][starts-with(.,$global:base-uri)][1]/text(),'/tei','')
let $works := 
            for $w in collection($global:data-root)//tei:body[child::*/tei:listRelation/tei:relation[@passive[functx:contains-word(.,$recid)]][@ref=$relType or @name=$relType]]
            let $part := xs:integer($w/child::*/tei:listRelation/tei:relation[@passive[functx:contains-word(.,$recid)]]/tei:desc/tei:label[@type='order'][1]/@n)
            order by $part
            return $w
let $count := count($works)
let $title := if(contains($rec/descendant::tei:title[1]/text(),' — ')) then 
                    substring-before($rec/descendant::tei:title[1]/text(),' — ') 
               else $rec/descendant::tei:title[1]/text()
return 
    if($count gt 0) then 
        <div xmlns="http://www.w3.org/1999/xhtml">
            {if($relType = 'dct:isPartOf') then 
                <h3>{$title} contains {$count} works.</h3>
             else if ($relType = 'syriaca:part-of-tradition') then 
                (<h3>This tradition comprises at least {$count} branches.</h3>,
                <p>{$data/descendant::tei:note[@type='literary-tradition']}</p>)
             else <h3>{$title} {$relType} {$count} works.</h3>
             }
            {(
                if($count gt 5) then
                        <div>
                         {
                             for $r in subsequence($works, 1, 3)
                             let $rec :=  $r/ancestor::tei:TEI
                             let $workid := replace($rec/descendant::tei:idno[@type='URI'][starts-with(.,$global:base-uri)][1],'/tei','')
                             let $part := $rec/descendant::*/tei:listRelation/tei:relation[@passive[matches(.,$recid)]]/tei:desc/tei:label[@type='order']
                             return 
                             <div class="indent row">
                                <div class="col-md-1"><span class="badge">{string-join($part/@n,' ')}</span></div>
                                <div class="col-md-11">{global:display-recs-short-view($rec,'',$recid)}</div>
                             </div>
                         }
                           <div>
                            <a href="#" class="btn btn-info getData" style="width:100%; margin-bottom:1em;" data-toggle="modal" data-target="#moreInfo" 
                            data-ref="{$global:nav-base}/nhsl/search.html?rel={$recid}&amp;={$relType}&amp;perpage={$count}" 
                            data-label="{$title} contains {$count} works" id="works">
                              See all {count($works)} works
                             </a>
                           </div>
                         </div>    
                else 
                    for $r in $works
                    let $workid := replace($r/ancestor::tei:TEI/descendant::tei:idno[@type='URI'][starts-with(.,$global:base-uri)][1],'/tei','')
                    let $rec :=  $r/ancestor::tei:TEI
                    let $workid := replace($rec/descendant::tei:idno[@type='URI'][starts-with(.,$global:base-uri)][1],'/tei','')
                             let $part := $rec/descendant::*/tei:listRelation/tei:relation[@passive[matches(.,$recid)]]/tei:desc/tei:label[@type='order']
                             return 
                             <div class="indent row">
                                <div class="col-md-1"><span class="badge">{$part/text()}</span></div>
                                <div class="col-md-11">{global:display-recs-short-view($rec,'',$recid)}</div>
                             </div>
            )}
        </div>
    else ()     
};

(:~      
 : Return teiHeader info to be used in citation used for Syriaca.org bibl module
:)
declare %templates:wrap function app:about($node as node(), $model as map(*)){
    let $rec := $model("data")
    let $header := 
        <srophe-about xmlns="http://www.tei-c.org/ns/1.0">
            {$rec//tei:teiHeader}
        </srophe-about>
    return global:tei2html($header)
};

(:~  
 : Record status to be displayed in HTML sidebar 
 : Data from tei:teiHeader/tei:revisionDesc/@status
:)
declare %templates:wrap  function app:rec-status($node as node(), $model as map(*), $collection as xs:string?){
let $status := string($model("data")/descendant::tei:revisionDesc/@status)
return
    if($status = 'published' or $status = '') then ()
    else
    <span class="rec-status {$status} btn btn-info">Status: {$status}</span>
};

(:~
 : Dynamically build html title based on TEI record and/or sub-module. 
 : @param request:get-parameter('id', '') if id is present find TEI title, otherwise use title of sub-module
:)
declare %templates:wrap function app:app-title($node as node(), $model as map(*), $collection as xs:string?){
if(request:get-parameter('id', '')) then normalize-space(string-join($model("data")/tei:head[1]/text()))
else $global:app-title
};  

(:~ 
 : Add header links for alternative formats. 
:)
declare function app:metadata($node as node(), $model as map(*)) {
    if(request:get-parameter('id', '')) then 
    (
    (: some rdf examples
    <link type="application/rdf+xml" href="id.rdf" rel="alternate"/>
    <link type="text/turtle" href="id.ttl" rel="alternate"/>
    <link type="text/plain" href="id.nt" rel="alternate"/>
    <link type="application/json+ld" href="id.jsonld" rel="alternate"/>
    :)
    <meta name="DC.title" property="dc.title " content="{normalize-space($model("data")/descendant::tei:head[1])}"/>,
    if($model("data")/descendant::tei:note[@type='abstract']) then 
        <meta name="DC.description" property="dc.description " content="{normalize-space($model("data")/descendant::tei:note[@type='abstract'][1])}"/>
    else (),
    <link xmlns="http://www.w3.org/1999/xhtml" type="text/html" href="{request:get-parameter('id', '')}.html" rel="alternate"/>,
    <link xmlns="http://www.w3.org/1999/xhtml" type="text/xml" href="{request:get-parameter('id', '')}/tei" rel="alternate"/>,
    <link xmlns="http://www.w3.org/1999/xhtml" type="application/atom+xml" href="{request:get-parameter('id', '')}/atom" rel="alternate"/>
    )
    else ()
};

(:~
 : Generic contact form can be added to any page by calling:
 : <div data-template="app:contact-form"/>
 : with a link to open it that looks like this: 
 : <button class="btn btn-default" data-toggle="modal" data-target="#feedback">CLink text</button>&#160;
:)
declare %templates:wrap function app:contact-form($node as node(), $model as map(*), $collection)
{
<div class="modal fade" id="feedback" tabindex="-1" role="dialog" aria-labelledby="feedbackLabel" aria-hidden="true" xmlns="http://www.w3.org/1999/xhtml">
    <div class="modal-dialog">
        <div class="modal-content">
        <div class="modal-header">
            <button type="button" class="close" data-dismiss="modal"><span aria-hidden="true">x</span><span class="sr-only">Close</span></button>
            <h2 class="modal-title" id="feedbackLabel">Corrections/Additions?</h2>
        </div>
        <form action="{$global:nav-base}/modules/email.xql" method="post" id="email" role="form">
            <div class="modal-body" id="modal-body">
                <!-- More information about submitting data from howtoadd.html -->
                <p><strong>Notify the editors of a mistake:</strong>
                <a class="btn btn-link togglelink" data-toggle="collapse" data-target="#viewdetails" data-text-swap="hide information">more information...</a>
                </p>
                <div class="container">
                    <div class="collapse" id="viewdetails">
                    <p>Using the following form, please inform us which page URI the mistake is on, where on the page the mistake occurs,
                    the content of the correction, and a citation for the correct information (except in the case of obvious corrections, such as misspelled words). 
                    Please also include your email address, so that we can follow up with you regarding 
                    anything which is unclear. We will publish your name, but not your contact information as the author of the  correction.</p>
                    <h4>Add data to an existing entry</h4>
                    <p>The Syriac Gazetteer is an ever expanding resource  created by and for users. The editors actively welcome additions to the gazetteer. If there is information which you would like to add to an existing place entry in The Syriac Gazetteer, please use the link below to inform us about the information, your (primary or scholarly) source(s) 
                    for the information, and your contact information so that we can credit you for the modification. For categories of information which  The Syriac Gazetteer structure can support, please see the section headings on the entry for Edessa and  specify in your submission which category or 
                    categories this new information falls into.  At present this information should be entered into  the email form here, although there is an additional  delay in this process as the data needs to be encoded in the appropriate structured data format  and assigned a URI. A structured form for submitting  new entries is under development.</p>
                    </div>
                </div>
                <input type="text" name="name" placeholder="Name" class="form-control" style="max-width:300px"/>
                <br/>
                <input type="text" name="email" placeholder="email" class="form-control" style="max-width:300px"/>
                <br/>
                <input type="text" name="subject" placeholder="subject" class="form-control" style="max-width:300px"/>
                <br/>
                <textarea name="comments" id="comments" rows="3" class="form-control" placeholder="Comments" style="max-width:500px"/>
                <input type="hidden" name="id" value="{request:get-parameter('id', '')}"/>
                <input type="hidden" name="collection" value="{$collection}"/>
                <!-- start reCaptcha API-->
                {if($global:recaptcha != '') then                                
                    <div class="g-recaptcha" data-sitekey="{$global:recaptcha}"></div>                
                else ()}
            </div>
            <div class="modal-footer">
                <button class="btn btn-default" data-dismiss="modal">Close</button><input id="email-submit" type="submit" value="Send e-mail" class="btn"/>
            </div>
        </form>
        </div>
    </div>
</div>
};

(:~
 : Grabs latest news for Syriaca.org home page
 : http://syriaca.org/feed/
 :) 
declare %templates:wrap function app:get-feed($node as node(), $model as map(*)){
    if(doc('http://syriaca.org/blog/feed/')/child::*) then 
       let $news := doc('http://syriaca.org/blog/feed/')/child::*
       for $latest at $n in subsequence($news//item, 1, 3)
       return 
       <li>
            <a href="{$latest/link/text()}">{$latest/title/text()}</a>
       </li>
    else ()   
};

(:~ 
 : Used by teiDocs
:)
declare %templates:wrap function app:set-data($node as node(), $model as map(*), $doc as xs:string){
    teiDocs:generate-docs($global:data-root || '/places/tei/78.xml')
};

(:~
 : Generic output documentation from xml
 : @param $doc as string
:)
declare %templates:wrap function app:build-documentation($node as node(), $model as map(*), $doc as xs:string?){
    let $doc := doc($global:app-root || '/documentation/' || $doc)//tei:encodingDesc
    return tei2html:tei2html($doc)
};

(:~   
 : get editors as distinct values
:)
declare function app:get-editors(){
distinct-values(
    (for $editors in collection($global:data-root || '/places/tei')//tei:respStmt/tei:name/@ref
     return substring-after($editors,'#'),
     for $editors-change in collection($global:data-root || '/places/tei')//tei:change/@who
     return substring-after($editors-change,'#'))
    )
};

(:~
 : Build editor list. Sort alphabeticaly
:)
declare %templates:wrap function app:build-editor-list($node as node(), $model as map(*)){
    let $editors := doc($global:app-root || '/documentation/editors.xml')//tei:listPerson
    for $editor in app:get-editors()
    let $name := 
        for $editor-name in $editors//tei:person[@xml:id = $editor]
        return concat($editor-name/tei:persName/tei:forename,' ',$editor-name/tei:persName/tei:addName,' ',$editor-name/tei:persName/tei:surname)
    let $sort-name :=
        for $editor-name in $editors//tei:person[@xml:id = $editor] return $editor-name/tei:persName/tei:surname
    order by $sort-name
    return
        if($editor != '') then 
            if(normalize-space($name) != '') then 
            <li>{normalize-space($name)}</li>
            else ''
        else ''  
};

(:~
 : Dashboard function outputs collection statistics. 
 : $data collection data
 : $collection-title title of sub-module/collection
 : $data-dir 
:)
declare %templates:wrap function app:dashboard($node as node(), $model as map(*), $collection-title, $data-dir){
    let $data := 
        if($collection-title != '') then 
            collection($global:data-root || '/' || $data-dir || '/tei')//tei:title[. = $collection-title]
        else collection($global:data-root || '/' || $data-dir || '/tei')//tei:title[@level='a'][parent::tei:titleStmt] 
            
    let $data-type := if($data-dir) then $data-dir else 'data'
    let $rec-num := count($data)
    let $contributors := for $contrib in distinct-values(for $contributors in $data/ancestor::tei:TEI/descendant::tei:respStmt/tei:name return $contributors) return <li>{$contrib}</li>
    let $contrib-num := count($contributors)
    let $data-points := count($data/ancestor::tei:TEI/descendant::tei:body/descendant::text())
    return
    <div class="panel-group" id="accordion" role="tablist" aria-multiselectable="true">
        <div class="panel panel-default">
            <div class="panel-heading" role="tab" id="dashboardOne">
                <h4 class="panel-title">
                    <a role="button" data-toggle="collapse" data-parent="#accordion" href="#collapseOne" aria-expanded="true" aria-controls="collapseOne">
                        <i class="glyphicon glyphicon-dashboard"></i> {concat(' ',$collection-title,' ')} Dashboard
                    </a>
                </h4>
            </div>
            <div id="collapseOne" class="panel-collapse collapse in" role="tabpanel" aria-labelledby="dashboardOne">
                <div class="panel-body dashboard">
                    <div class="row" style="padding:2em;">
                        <div class="col-md-4">
                            <div class="panel panel-primary">
                                <div class="panel-heading">
                                    <div class="row">
                                        <div class="col-xs-3"><i class="glyphicon glyphicon-file"></i></div>
                                        <div class="col-xs-9 text-right">
                                            <div class="huge">{$rec-num}</div><div>{$data-dir}</div>
                                        </div>
                                    </div>
                                </div>
                                <div class="collapse panel-body" id="recCount">
                                    <p>This number represents the count of {$data-dir} currently described in <i>{$collection-title}</i> as of {current-date()}.</p>
                                    <span><a href="browse.html"> See records <i class="glyphicon glyphicon-circle-arrow-right"></i></a></span>
                                </div>
                                <a role="button" 
                                    data-toggle="collapse" 
                                    href="#recCount" 
                                    aria-expanded="false" 
                                    aria-controls="recCount">
                                    <div class="panel-footer">
                                        <span class="pull-left">View Details</span>
                                        <span class="pull-right"><i class="glyphicon glyphicon-circle-arrow-right"></i></span>
                                        <div class="clearfix"></div>
                                    </div>
                                </a>
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="panel panel-success">
                                <div class="panel-heading">
                                    <div class="row">
                                        <div class="col-xs-3"><i class="glyphicon glyphicon-user"></i></div>
                                        <div class="col-xs-9 text-right"><div class="huge">{$contrib-num}</div><div>Contributors</div></div>
                                    </div>
                                </div>
                                <div class="panel-body collapse" id="contribCount">
                                    {(
                                    <p>This number represents the count of contributors who have authored or revised an entry in <i>{$collection-title}</i> as of {current-date()}.</p>,
                                    <ul style="padding-left: 1em;">{$contributors}</ul>)} 
                                    
                                </div>
                                <a role="button" 
                                    data-toggle="collapse" 
                                    href="#contribCount" 
                                    aria-expanded="false" 
                                    aria-controls="contribCount">
                                    <div class="panel-footer">
                                        <span class="pull-left">View Details</span>
                                        <span class="pull-right"><i class="glyphicon glyphicon-circle-arrow-right"></i></span>
                                        <div class="clearfix"></div>
                                    </div>
                                </a>
                            </div>
                        </div>
                        <div class="col-md-4">
                            <div class="panel panel-info">
                                <div class="panel-heading">
                                    <div class="row">
                                        <div class="col-xs-3"><i class="glyphicon glyphicon-stats"></i></div>
                                        <div class="col-xs-9 text-right"><div class="huge"> {$data-points}</div><div>Data points</div></div>
                                    </div>
                                </div>
                                <div id="dataPoints" class="panel-body collapse">
                                    <p>This number is an approximation of the entire data, based on a count of XML text nodes in the body of each TEI XML document in the <i>{$collection-title}</i> as of {current-date()}.</p>  
                                </div>
                                <a role="button" 
                                data-toggle="collapse" 
                                href="#dataPoints" 
                                aria-expanded="false" 
                                aria-controls="dataPoints">
                                    <div class="panel-footer">
                                        <span class="pull-left">View Details</span>
                                        <span class="pull-right"><i class="glyphicon glyphicon-circle-arrow-right"></i></span>
                                        <div class="clearfix"></div>
                                    </div>
                                </a>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
};

(:~
 : Pulls github wiki data into Syriaca.org documentation pages. 
 : @param $wiki-uri pulls content from specified wiki or wiki page. 
:)
declare function app:get-wiki($wiki-uri as xs:string?){
    http:send-request(
            <http:request href="{xs:anyURI($wiki-uri)}" method="get">
                <http:header name="Connection" value="close"/>
            </http:request>)[2]//html:div[@class = 'repository-content']            
};

(:~
 : Pulls github wiki data H1.  
:)
declare function app:wiki-page-title($node, $model){
    let $wiki-uri := 
        if(request:get-parameter('wiki-uri', '')) then 
            request:get-parameter('wiki-uri', '')
        else 'https://github.com/srophe/srophe-eXist-app/wiki' 
    let $uri := 
        if(request:get-parameter('wiki-page', '')) then 
            concat($wiki-uri, request:get-parameter('wiki-page', ''))
        else $wiki-uri
    let $wiki-data := app:get-wiki($uri)
    let $content := $wiki-data//html:div[@id='wiki-body']
    return $wiki-data/descendant::html:h1[1]
};

(:~
 : Pulls github wiki content.  
:)
declare function app:wiki-page-content($node, $model){
    let $wiki-uri := 
        if(request:get-parameter('wiki-uri', '')) then 
            request:get-parameter('wiki-uri', '')
        else 'https://github.com/srophe/srophe-eXist-app/wiki' 
    let $uri := 
        if(request:get-parameter('wiki-page', '')) then 
            concat($wiki-uri, request:get-parameter('wiki-page', ''))
        else $wiki-uri
    let $wiki-data := app:get-wiki($uri)
    return $wiki-data//html:div[@id='wiki-body'] 
};

(:~
 : Pull github wiki data into Syriaca.org documentation pages. 
 : Grabs wiki menus to add to Syraica.org pages
 : @param $wiki pulls content from specified wiki or wiki page. 
:)
declare function app:wiki-menu($node, $model, $wiki){
    let $wiki-data := app:get-wiki($wiki)
    let $menu := app:wiki-links($wiki-data//html:div[@id='wiki-rightbar']/descendant::*:ul[@class='wiki-pages'], $wiki)
    return $menu
};

(:~
 : Typeswitch to processes wiki menu links for use with Syriaca.org documentation pages. 
 : @param $wiki pulls content from specified wiki or wiki page. 
:)
declare function app:wiki-links($nodes as node()*, $wiki) {
    for $node in $nodes
    return 
        typeswitch($node)
            case element(html:a) return
                let $wiki-path := substring-after($wiki,'https://github.com')
                let $href := concat($global:nav-base, replace($node/@href, $wiki-path, "/documentation/wiki.html?wiki-page="),'&amp;wiki-uri=', $wiki)
                return
                    <a href="{$href}">
                        {$node/@* except $node/@href, $node/node()}
                    </a>
            case element() return
                element { node-name($node) } {
                    $node/@*, app:wiki-links($node/node(), $wiki)
                }
            default return
                $node               
};

(:~
 : display keyboard menu 
:)
declare function app:keyboard-select-menu($node, $model, $input-id){
    global:keyboard-select-menu($input-id)
};

(:~ 
 : Enables shared content with template expansion.  
 : Used for shared menus in navbar where relative links can be problematic 
 : @param $node
 : @param $model
 : @param $path path to html content file, relative to app root. 
:)
declare function app:shared-content($node as node(), $model as map(*), $path as xs:string){
    let $links := doc($global:app-root || $path)
    return templates:process(global:fix-links($links/node()), $model)
};

(:~                   
 : Traverse main nav and "fix" links based on values in config.xml
 : Replaces $app-root with vaule defined in config.xml. 
 : This allows for more flexible deployment for dev and production environments.   
:)
declare
    %templates:wrap
function app:fix-links($node as node(), $model as map(*)) {
    templates:process(global:fix-links($node/node()), $model)
};

(:~ 
 : Adds google analytics from config.xml
 : @param $node
 : @param $model
 : @param $path path to html content file, relative to app root. 
:)
declare  
    %templates:wrap 
function app:google-analytics($node as node(), $model as map(*)) {
   $global:get-config//google_analytics/text() 
};

(: e-gedsh functions :) 
declare %templates:wrap function app:entries-count($node as node(), $model as map(*)){
count(collection($global:data-root)//tei:div[@type='entry'])
};

declare %templates:wrap function app:contributors-count($node as node(), $model as map(*)){
count(collection($global:data-root)//tei:div[@type='section'][tei:ab[@type='idnos']/child::tei:idno[. = 'http://gedsh.bethmardutho.org/List-Contributors']]/tei:p)
};
declare %templates:wrap function app:next-entry($node as node(), $model as map(*), $collection as xs:string?){
if($model("data")/descendant::tei:idno[@type=('back','front')] or $model("data")/descendant-or-self::*/@type='figure') then 
    let $c := $model("data")/descendant::tei:idno[1]
    let $nID := substring-after($model("data")/following-sibling::tei:div[1]/descendant::tei:idno[1], $global:base-uri) 
    let $pID := substring-after($model("data")/preceding-sibling::tei:div[1]/descendant::tei:idno[1], $global:base-uri)
    let $prev := 
               if($pID != '') then
                    (<a href="{$global:nav-base}/entry{$pID}"><span class="glyphicon glyphicon-backward" aria-hidden="true"></span></a>,' | ')
               else ()
    let $next := 
                if($nID != '') then 
                    (' | ', <a href="{$global:nav-base}/entry{$nID}"><span class="glyphicon glyphicon-forward" aria-hidden="true"></span></a>)                                        
                else ()  
    return 
    <p>{($prev, ' ', if($model("data")/descendant-or-self::*/@type='figure') then $c else $model("data")/tei:head[1], ' ', $next)}</p>
else
   let $nID := substring-after($model("data")/following-sibling::tei:div[@type="entry"][1]/descendant::tei:idno[@type='URI'][1],$global:base-uri)
   let $pID := substring-after($model("data")/preceding-sibling::tei:div[@type="entry"][1]/descendant::tei:idno[@type='URI'][1],$global:base-uri)
   let $prev := 
                if($pID != '') then
                        (<a href="{$global:nav-base}/entry{$pID}"><span class="glyphicon glyphicon-backward" aria-hidden="true"></span></a>,' | ')
                else ()
   let $next := 
                if($nID != '') then 
                   (' | ', <a href="{$global:nav-base}/entry{$nID}"><span class="glyphicon glyphicon-forward" aria-hidden="true"></span></a>)                                        
                else ()
   return             
   <p>{($prev, ' ', $model("data")/tei:head[1], ' ', $next)}</p>
};
(: Data formats and sharing:)
declare %templates:wrap function app:other-data-formats($node as node(), $model as map(*), $formats as xs:string?){
    if($formats) then
        <div class="container" style="width:100%;clear:both;margin-bottom:1em; text-align:right;">
            {
                for $f in tokenize($formats,',')
                return 
                    if($f = 'tei') then
                        (<a href="{concat(replace(request:get-parameter('id', ''),$global:base-uri,concat($global:nav-base,'/entry')),'/tei')}" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the TEI XML data for this record." >
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> TEI/XML
                        </a>, '&#160;')
                    else if($f = 'print') then                        
                        (<a href="javascript:window.print();" type="button" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to send this page to the printer." >
                             <span class="glyphicon glyphicon-print" aria-hidden="true"></span>
                        </a>, '&#160;')  
                   else if($f = 'rdf') then
                        (<a href="{concat(replace(request:get-parameter('id', ''),$global:base-uri,concat($global:nav-base,'/entry')),'/rdf')}" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the RDF-XML data for this record." >
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> RDF/XML
                        </a>, '&#160;')
                  else if($f = 'ttl') then
                        (<a href="{concat(replace(request:get-parameter('id', ''),$global:base-uri,concat($global:nav-base,'/entry')),'/ttl')}" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the RDF-Turtle data for this record." >
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> RDF/TTL
                        </a>, '&#160;')                        
                   else () 
                
            }
            <br/>
        </div>
    else ()
};

(:
 : Display related Syriaca.org names
:)
declare %templates:wrap function app:srophe-related($node as node(), $model as map(*)){
    (:if($model("data")//@ref[contains(.,'http://syriaca.org/')] and $model("data")//tei:idno[@type="subject"][contains(.,'http://syriaca.org/')]) then:) 
    if($model("data")//@ref[contains(.,'http://syriaca.org/')]) then
        <div class="panel panel-default" style="margin-top:1em;" xmlns="http://www.w3.org/1999/xhtml">
            <div class="panel-heading"><h3 class="panel-title">Linked Data <span class="glyphicon glyphicon-question-sign text-info moreInfo" aria-hidden="true" data-toggle="tooltip" title="This sidebar provides links via Syriaca.org to additional resources beyond those mentioned by the author of this entry."></span></h3></div>
            <div class="panel-body">
                {(
                    let $subject-uri := string($model("data")/descendant::tei:idno[@type="subject"][contains(.,'http://syriaca.org/')][1])
                    let $article-title := $model('data')/tei:head[1]
                    let $query := 
                        fn:encode-for-uri(concat("prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
                                prefix lawd: <http://lawd.info/ontology/>
                                prefix skos: <http://www.w3.org/2004/02/skos/core#>
                                prefix dcterms: <http://purl.org/dc/terms/>  
                                SELECT ?uri ?label ?subjects ?citations 
                                {
                                    ?uri rdfs:label ?label
                                    FILTER (?uri IN ( <",$subject-uri,">))
                                    FILTER ( langMatches(lang(?label), 'en')) .
                                    {SELECT ?uri ( count(?s) as ?subjects ) { ?s dcterms:relation ?uri } GROUP BY ?uri }  
                                    {SELECT ?uri ( count(?o) as ?citations ) { 
                                            ?uri lawd:hasCitation ?o 
                                            	OPTIONAL{
                                                  ?uri skos:closeMatch ?o.}
                                            } GROUP BY ?uri }   
                                }"))
                    let $subject-sparql-results := 
                                    try{http:send-request(<http:request href="http://wwwb.library.vanderbilt.edu/exist/apps/srophe/api/sparql?query={$query}" method="get"/>)[2]
                                       } catch * {<error>Caught error {$err:code}: {$err:description} {$subject-uri}</error>}       
                    return 
                        if($subject-uri != '') then 
                            <div class="related-resources">
                                <h4>Resources related to {if($subject-uri) then <a href="{$subject-uri}">{$article-title}</a> else $article-title}</h4>
                                    {(
                                     if($subject-sparql-results//*:binding[@name='citations']/*:literal[xs:integer(.) gt 0]) then
                                       <div class="indent">{$subject-sparql-results//*:binding[@name='citations'][1]/*:literal} related citations</div>
                                     else (),
                                     if($subject-sparql-results//*:binding[@name='subjects']/*:literal[xs:integer(.) gt 0]) then 
                                        <div class="indent">{$subject-sparql-results//*:binding[@name='subjects'][1]/*:literal} related subjects</div>
                                     else()
                                    )}
                            </div>
                        else (),
                 if($model("data")//@ref[contains(.,'http://syriaca.org/')]) then
                    let $other-resources := distinct-values($model("data")//@ref[contains(.,'http://syriaca.org/')])
                    let $count := count($other-resources)
                    return 
                        <div class="other-resources" xmlns="http://www.w3.org/1999/xhtml">
                            <h4>Resources related to {$count} other topics in this article. </h4>
                            <div class="collapse" id="showOtherResources">
                                <form class="form-inline hidden" action="http://wwwb.library.vanderbilt.edu/exist/apps/srophe/api/sparql" method="post">
                                    <input type="hidden" name="format" id="format" value="json"/>
                                    <textarea id="query" class="span9" rows="15" cols="150" name="query" type="hidden">
                                      <![CDATA[
                                        prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
                                        prefix lawd: <http://lawd.info/ontology/>
                                        prefix skos: <http://www.w3.org/2004/02/skos/core#>
                                        prefix dcterms: <http://purl.org/dc/terms/>
                                        
                                        SELECT ?uri ?label ?subjects ?citations
                                        {
                                            ?uri rdfs:label ?label
                                            FILTER (?uri IN ( ]]>{string-join(for $r in subsequence($other-resources,1,10) return concat('<',$r,'>'),',')}<![CDATA[))
                                            FILTER ( langMatches(lang(?label), 'en')) .
                                            {SELECT ?uri ( count(?s) as ?subjects ) { ?s dcterms:relation ?uri } GROUP BY ?uri }  
                                            {SELECT ?uri ( count(?o) as ?citations ) { 
                                              ?uri lawd:hasCitation ?o 
                                            	OPTIONAL{
                                                  ?uri skos:closeMatch ?o.}
                                            } GROUP BY ?uri }   
                                        }
                                      ]]>  
                                    </textarea>
                                </form>
                                <div id="listOtherResources"></div>
                                {if($count gt 10) then
                                    <div>
                                        <div class="collapse" id="showMoreResources">
                                            <form class="form-inline hidden" action="http://wwwb.library.vanderbilt.edu/exist/apps/srophe/api/sparql" method="post">
                                                <input type="hidden" name="format" id="format" value="json"/>
                                                <textarea id="query" class="span9" rows="15" cols="150" name="query" type="hidden">
                                                  <![CDATA[
                                                    prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
                                                    prefix lawd: <http://lawd.info/ontology/>
                                                    prefix skos: <http://www.w3.org/2004/02/skos/core#>
                                                    prefix dcterms: <http://purl.org/dc/terms/>
                                                    
                                                    SELECT ?uri ?label ?subjects ?citations
                                                    {
                                                        ?uri rdfs:label ?label
                                                        FILTER (?uri IN ( ]]>{string-join(for $r in subsequence($other-resources,12,$count) return concat('<',$r,'>'),',')}<![CDATA[))
                                                        FILTER ( langMatches(lang(?label), 'en')) .
                                                        {SELECT ?uri ( count(?s) as ?subjects ) { ?s dcterms:relation ?uri } GROUP BY ?uri }  
                                                        {SELECT ?uri ( count(?o) as ?citations ) { 
                                                          ?uri lawd:hasCitation ?o 
                                                        	OPTIONAL{
                                                              ?uri skos:closeMatch ?o.}
                                                        } GROUP BY ?uri }   
                                                    }
                                                  ]]>  
                                                </textarea>
                                            </form>
                                        </div>
                                        <a href="#" class="togglelink" data-toggle="collapse" data-target="#showMoreResources" data-text-swap="Less" id="getMoreLinkedData">See more ...</a>
                                    </div>
                                else ()
                                }
                            </div>
                            <a href="#" class="btn btn-default togglelink" style="width:100%;" data-toggle="collapse" data-target="#showOtherResources" data-text-swap="Hide Other Resources" id="getLinkedData">Show Other Resources</a>
                            <script>
                            <![CDATA[
                                $(document).ready(function() {
                                    $('#showOtherResources').children('form').each(function () {
                                        var url = $(this).attr('action');
                                            $.post(url, $(this).serialize(), function(data) {
                                                console.log(data);
                                                var showOtherResources = $("#listOtherResources"); 
                                                var dataArray = data.results.bindings;
                                                if (!jQuery.isArray(dataArray)) dataArray = [dataArray];
                                                $.each(dataArray, function (currentIndex, currentElem) {
                                                    showOtherResources.append(
                                                        '<div>Resources related to <a href="'+ currentElem.uri.value +'">'+ currentElem.label.value + '</a> <div class="indent">' + currentElem.citations.value + ' related citations</div><div class="indent">' + currentElem.subjects.value + ' related subjects</div></div>'
                                                    );
                                                });
                                            }).fail( function(jqXHR, textStatus, errorThrown) {
                                                console.log(textStatus);
                                            }); 
                                        });
                                        $('#getMoreLinkedData').one("click", function(e){
                                           $('#showMoreResources').children('form').each(function () {
                                                var url = $(this).attr('action');
                                                    $.post(url, $(this).serialize(), function(data) {
                                                        var showOtherResources = $("#showMoreResources");
                                                        var dataArray = data.results.bindings;
                                                        if (!jQuery.isArray(dataArray)) dataArray = [dataArray];                                                        
                                                        $.each(dataArray, function (currentIndex, currentElem) {
                                                            showOtherResources.append(
                                                               '<div>Resources related to <a href="'+ currentElem.uri.value +'">'+ currentElem.label.value + '</a> <div class="indent">' + currentElem.citations.value + ' related citations</div><div class="indent">' + currentElem.subjects.value + ' related subjects</div></div>'
                                                          );
                                                        });
                                                    }).fail( function(jqXHR, textStatus, errorThrown) {
                                                        console.log(textStatus);
                                                    }); 
                                                }); 
                                        });
                                });
                            ]]>
                            </script>
                        </div>
                 else () 
                )}
            </div>
        </div>       
    else()
};