xquery version "3.0";        
 
module namespace search="http://syriaca.org/search";
import module namespace page="http://syriaca.org/page" at "../lib/paging.xqm";
import module namespace common="http://syriaca.org/common" at "common.xqm";
import module namespace maps="http://syriaca.org/maps" at "lib/maps.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "../content-negotiation/tei2html.xqm";
import module namespace global="http://syriaca.org/global" at "../lib/global.xqm";
import module namespace kwic="http://exist-db.org/xquery/kwic";
import module namespace templates="http://exist-db.org/xquery/templates" ;

declare namespace tei="http://www.tei-c.org/ns/1.0";

(:~ 
 : Shared global parameters for building search paging function
:)
declare variable $search:q {request:get-parameter('q', '') cast as xs:string};
declare variable $search:persName {request:get-parameter('persName', '') cast as xs:string};
declare variable $search:placeName {request:get-parameter('placeName', '') cast as xs:string};
declare variable $search:title {request:get-parameter('title', '') cast as xs:string};
declare variable $search:bibl {request:get-parameter('bibl', '') cast as xs:string};
declare variable $search:idno {request:get-parameter('uri', '') cast as xs:string};
declare variable $search:start {request:get-parameter('start', 1) cast as xs:integer};
declare variable $search:sort-element {request:get-parameter('sort-element', '') cast as xs:string};
declare variable $search:perpage {request:get-parameter('perpage', 20) cast as xs:integer};
declare variable $search:collection {request:get-parameter('collection', '') cast as xs:string};

(:~
 : Builds search string and evaluates string.
 : Search stored in map for use by other functions
 : @param $collection passed from search page templates to build correct sub-collection search string
:)
declare %templates:wrap function search:get-results($node as node(), $model as map(*), $collection as xs:string?, $view as xs:string?){
    let $coll := if($search:collection != '') then $search:collection else $collection
    let $eval-string :=  search:query-string($collection)
    return                         
    map {"hits" := 
                if(exists(request:get-parameter-names()) or ($view = 'all')) then 
                    if($search:sort-element != '' and $search:sort-element != 'relevance' or $view = 'all') then 
                        for $hit in util:eval($eval-string)
                        order by global:build-sort-string(page:add-sort-options($hit,$search:sort-element),'') ascending
                        return $hit                                                     
                    else 
                        for $hit in util:eval($eval-string)
                        order by ft:score($hit) descending
                        return $hit
                else ()                        
         }
};

(:~   
 : Builds general search string from main syriaca.org page and search api.
:)
declare function search:query-string($collection as xs:string?) as xs:string?{
if($collection !='') then 
    concat("collection('",$global:data-root,"/",$collection,"')//tei:body",
    common:keyword(),
    search:author(),
    search:persName(),
    search:placeName(), 
    search:bibl(),
    search:idno()
    )
else 
concat("collection('",$global:data-root,"')//tei:div[@type=('entry','crossreference','section','subsection')][tei:ab[@type='idnos']]",
    common:keyword(),
    search:author(),
    search:persName(),
    search:placeName(), 
    search:bibl(),
    search:idno()
    )
};


declare function search:author(){
    if(request:get-parameter('author', '') != '') then 
        concat("[ft:query(descendant::tei:byline,'",request:get-parameter('author', ''),"',common:options())]")
    else () 
};

declare function search:persName(){
    if($search:persName != '') then 
        concat("[ft:query(descendant::tei:persName,'",$search:persName,"',common:options()) or ft:query(descendant::tei:head,'",$search:persName,"',common:options())]")
    else () 
};

declare function search:placeName(){
    if($search:placeName != '') then 
        concat("[ft:query(descendant::tei:placeName,'",$search:placeName,"',common:options()) or ft:query(descendant::tei:head,'",$search:placeName,"',common:options())]")
    else () 
};

declare function search:bibl(){
    if($search:bibl != '') then  
        concat("[ft:query(descendant::tei:div[@type='bibl'],'",$search:bibl,"',common:options())]")
    else ()
};

(: NOTE add additional idno locations, ptr/@target @ref, others? :)
declare function search:idno(){
    if($search:idno != '') then 
    concat("
        [descendant::tei:idno[@type='URI'][. =  '",$search:idno,"'] or  
            .//@ref[matches(.,'",$search:idno,"(\s.*)?$')]
            or 
            .//@target[matches(.,'",$search:idno,"(\s.*)?$')]
        ]")
    (:     concat("[descendant::tei:idno =  '",$search:idno,"']") :) 
    else () 
};

declare function search:search-string(){
<span xmlns="http://www.w3.org/1999/xhtml">
{(
    let $parameters :=  request:get-parameter-names()
    for  $parameter in $parameters
    return 
        if(request:get-parameter($parameter, '') != '') then
            if($parameter = 'start' or $parameter = 'sort-element') then ()
            else if($parameter = 'author') then 
                (<span class="param">Contributor: </span>,<span class="match">{request:get-parameter($parameter, '')}&#160;</span>)
            else if($parameter = 'q') then 
                (<span class="param">Keyword: </span>,<span class="match">{$search:q}&#160;</span>)
            else if($parameter = 'persName') then 
                (<span class="param">Person: </span>,<span class="match">{$search:persName}&#160;</span>)
            else if($parameter = 'placeName') then 
                (<span class="param">Place: </span>,<span class="match">{$search:placeName}&#160;</span>)                            
            else (<span class="param">{replace(concat(upper-case(substring($parameter,1,1)),substring($parameter,2)),'-',' ')}: </span>,<span class="match">{request:get-parameter($parameter, '')}</span>)    
        else ())
        }
</span>
};

(:~
 : Display search string in browser friendly format for search results page
 : @param $collection passed from search page templates
:)
declare function search:search-string($collection as xs:string?){
     search:search-string()
};


(:~ 
 : Count total hits
:)
declare  %templates:wrap function search:hit-count($node as node()*, $model as map(*)) {
    count($model("hits"))
};

(:~
 : Build paging for search results pages
 : If 0 results show search form
:)
declare  %templates:wrap function search:pageination($node as node()*, $model as map(*), $collection as xs:string?, $view as xs:string?, $sort-options as xs:string*){
   if($view = 'all') then 
        page:pages($model("hits"), $search:start, $search:perpage, '', $sort-options)
        (:page:pageination($model("hits"), $search:start, $search:perpage, true()):)
   else if(exists(request:get-parameter-names())) then 
        page:pages($model("hits"), $search:start, $search:perpage, search:search-string($collection), $sort-options)
        (:page:pageination($model("hits"), $search:start, $search:perpage, true(), $collection, search:search-string($collection)):)
   else ()
};

(:~
 : Build Map view of search results with coordinates
 : @param $node search resuls with coords
:)
declare function search:build-geojson($node as node()*, $model as map(*)){
let $data := $model("hits")
let $geo-hits := $data//tei:geo
return
    if(count($geo-hits) gt 0) then
         (
         maps:build-map($data[descendant::tei:geo], count($data)),
         <div>
            <div class="modal fade" id="map-selection" tabindex="-1" role="dialog" aria-labelledby="map-selectionLabel" aria-hidden="true">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <button type="button" class="close" data-dismiss="modal">
                                <span aria-hidden="true"> x </span>
                                <span class="sr-only">Close</span>
                            </button>
                        </div>
                        <div class="modal-body">
                            <div id="popup" style="border:none; margin:0;padding:0;margin-top:-2em;"/>
                        </div>
                        <div class="modal-footer">
                            <a class="btn" href="/documentation/faq.html" aria-hidden="true">See all FAQs</a>
                            <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
                        </div>
                    </div>
                </div>
            </div>
         </div>,
         <script type="text/javascript">
         <![CDATA[
            $('#mapFAQ').click(function(){
                $('#popup').load( '../documentation/faq.html #map-selection',function(result){
                    $('#map-selection').modal({show:true});
                });
             });]]>
         </script>)
    else ()         
};

(:~
 : Calls advanced search forms from sub-collection search modules
 : @param $collection
:)
declare %templates:wrap  function search:show-form($node as node()*, $model as map(*), $collection as xs:string?) {   
    if(exists(request:get-parameter-names())) then ''
    else  <div>{search:search-form()}</div>
};

(:~ 
 : Builds results output
    if(starts-with(request:get-parameter('author', ''),$global:base-uri)) then 
        global:display-recs-short-view($hit,'',request:get-parameter('author', ''))
    else global:display-recs-short-view($hit,'') 
:)
declare 
    %templates:default("start", 1)
function search:show-hits($node as node()*, $model as map(*), $collection as xs:string?) {
<div class="indent" id="search-results">
    <div>{search:build-geojson($node,$model)}</div>
    {
        for $hit at $p in subsequence($model("hits"), $search:start, $search:perpage)
        let $kwic := kwic:expand($hit)
        let $uri := if($hit/@type='crossreference') then
                        string($hit/descendant::tei:ref/@target)
                    else $hit/descendant::tei:idno[@type='URI'][1]/text()
        return 
            <div class="row" xmlns="http://www.w3.org/1999/xhtml" style="border-bottom:1px dotted #eee; padding-top:.5em">
                <div class="col-md-12">
                      <div class="col-md-1" style="margin-right:-1em; padding-top:1em;">
                        <span class="label label-default">{$search:start + $p - 1}</span>
                      </div>
                      <div class="col-md-9" xml:lang="en">
                       {tei2html:summary-view($hit, $uri, $kwic)}
                      </div>
                </div>
            </div>
       } 
</div>
};


declare function search:filter($node, $mode){
  if ($mode eq 'before') then 
      concat($node, ' ')
  else 
      concat(' ', $node)
};

(:~          
 : Checks to see if there are any parameters in the URL, if yes, runs search, if no displays search form. 
 : NOTE: could add view param to show all for faceted browsing? 
:)
declare %templates:wrap function search:build-page($node as node()*, $model as map(*), $collection as xs:string?, $view as xs:string?) {
    if(exists(request:get-parameter-names()) or ($view = 'all')) then search:show-hits($node, $model, $collection)
    else ()
};

(:~
 : Builds advanced search form
 :)
declare function search:search-form() {   
<form method="get" action="search.html" style="margin-top:2em;" class="form-horizontal indent" role="form" xmlns:xi="http://www.w3.org/2001/XInclude">
    <div class="well well-small">
              <button type="button" class="btn btn-info pull-right" data-toggle="collapse" data-target="#searchTips">
                Search Help <span class="glyphicon glyphicon-question-sign" aria-hidden="true"></span>
            </button>&#160;<p/>
            <xi:include href="{$global:app-root}/searchTips.html"/>
        <div class="well well-small" style="background-color:white;">
            <div class="row">
                <div class="col-md-7">
                <!-- Keyword -->
                 <div class="form-group">
                    <label for="q" class="col-sm-2 col-md-3  control-label">Keyword: </label>
                    <div class="col-sm-10 col-md-9 ">
                        <input type="text" id="q" name="q" class="form-control"/>
                    </div>
                  </div>
                  <div class="form-group">
                    <label for="author" class="col-sm-2 col-md-3  control-label">Contributor: </label>
                    <div class="col-sm-10 col-md-9 ">
                        <input type="text" id="author" name="author" class="form-control"/>
                    </div>
                  </div> 
                    <!-- Place Name-->
                  <div class="form-group">
                    <label for="placeName" class="col-sm-2 col-md-3  control-label">Place Name: </label>
                    <div class="col-sm-10 col-md-9 ">
                        <input type="text" id="placeName" name="placeName" class="form-control"/>
                    </div>
                  </div>
                <div class="form-group">
                    <label for="persName" class="col-sm-2 col-md-3  control-label">Person Name: </label>
                    <div class="col-sm-10 col-md-9 ">
                        <input type="text" id="persName" name="persName" class="form-control"/>
                    </div>
                  </div> 
                <div class="form-group">
                    <label for="bibl" class="col-sm-2 col-md-3  control-label">Sources: </label>
                    <div class="col-sm-10 col-md-9 ">
                        <input type="text" id="bibl" name="bibl" class="form-control"/>
                    </div>
               </div> 
                <div class="form-group">
                    <label for="uri" class="col-sm-2 col-md-3  control-label">URI <span class="glyphicon glyphicon-question-sign text-info moreInfo" 
                    aria-hidden="true" data-toggle="tooltip" 
                    title="Searches the entire XML data and returns the entries that reference the specified URI(s)."></span>: </label>
                    <div class="col-sm-10 col-md-9 ">
                        <input type="text" id="uri" name="uri" class="form-control"/>
                        <p class="hint">*Enter e-GEDSH or Syriaca URI, ex. http://gedsh.bethmardutho.org/Aba, or http://syriaca.org/person/13</p>
                    </div>

               </div> 
               </div>
            </div>    
        </div>
        <div class="pull-right">
            <button type="submit" class="btn btn-info">Search</button>&#160;
            <button type="reset" class="btn">Clear</button>
        </div>
        <br class="clearfix"/><br/>
    </div>    
</form>
};
