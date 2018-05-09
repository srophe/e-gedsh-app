xquery version "3.0";

module namespace cntneg="http://syriaca.org/cntneg";
(:~
 : Module for content negotiation based on work done by Steve Baskauf
 : https://github.com/baskaufs/guid-o-matic
 : Supported serializations: 
    - TEI to HTML
    - TEI to RDF/XML
    - TEI to RDF/ttl
    - TEI to geoJSON
    - TEI to KML
    - TEI to Atom 
    - SPARQL XML to JSON-LD
 : Add additional serializations to lib folder and call them here.
 :
 : @author Winona Salesky <wsalesky@gmail.com>
 : @authored 2018-04-12
:)

import module namespace global="http://syriaca.org/global" at "global.xqm";
(:
 : Syriaca.org content serialization modules.
 : Additional modules can be added. 
:)
(:import module namespace tei2ttl="http://syriaca.org/tei2ttl" at "tei2ttl.xqm";:)
import module namespace tei2rdf="http://syriaca.org/tei2rdf" at "tei2rdf.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "tei2html.xqm";
import module namespace tei2txt="http://syriaca.org/tei2txt" at "tei2txt.xqm";
import module namespace geojson="http://syriaca.org/geojson" at "geojson.xqm";
import module namespace jsonld="http://syriaca.org/jsonld" at "jsonld.xqm";
import module namespace geokml="http://syriaca.org/geokml" at "geokml.xqm";
import module namespace feed="http://syriaca.org/atom" at "atom.xqm";

(:eXist modules :)
import module namespace req="http://exquery.org/ns/request";
(: These are needed for rending as HTML via existdb templating module, can be removed if not using 
import module namespace config="http://syriaca.org/config" at "config.xqm";
import module namespace templates="http://exist-db.org/xquery/templates" ;
:)

(: Namespaces :)
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace http="http://expath.org/ns/http-client";


(:
 : Main content negotiation
 : @param $data - data to be serialized
 : @param $content-type - content-type header to determine serialization 
 : @param $path - url can be used to determine content-type if content-type header is not available
 :
 : @NOTE - This function has two ways to serialize HTML records, these can easily be swapped out for other HTML serializations, including an XSLT version: 
        1. tei2html.xqm (an incomplete serialization, used primarily for search and browse results)
        2. eXistdb's templating module for full html page display
:)
declare function cntneg:content-negotiation($data as item()*, $content-type as xs:string?, $path as xs:string?){
    let $page := if(contains($path,'/')) then tokenize($path,'/')[last()] else $path
    let $type := if(substring-after($page,".") != '') then 
                    substring-after($page,".")
                 else if($content-type) then 
                    cntneg:determine-extension($content-type)
                 else 'html'
    let $flag := cntneg:determine-type-flag($type)
    return 
        if($flag = ('tei','xml')) then 
            (<rest:response> 
                <http:response status="200"> 
                    <http:header name="Content-Type" value="application/xml; charset=utf-8"/> 
                </http:response> 
                <output:serialization-parameters>
                    <output:method value='xml'/>
                    <output:media-type value='text/xml'/>
                </output:serialization-parameters>
             </rest:response>,$data)
        else if($flag = 'atom') then <message>Not an available data format.</message>
        else if($flag = 'rdf') then (<rest:response> 
                <http:response status="200"> 
                    <http:header name="Content-Type" value="application/xml; charset=utf-8"/>  
                    <http:header name="media-type" value="application/xml"/>
                </http:response> 
                <output:serialization-parameters>
                    <output:method value='xml'/>
                    <output:media-type value='application/xml'/>
                </output:serialization-parameters>
             </rest:response>, tei2rdf:rdf-output($data))
        else if($flag = ('turtle','ttl')) then <message>Not an available data format.</message>
            (:(<rest:response> 
                <http:response status="200"> 
                    <http:header name="Content-Type" value="text/plain; charset=utf-8"/>
                    <http:header name="method" value="text"/>
                    <http:header name="media-type" value="text/plain"/>
                </http:response>
                <output:serialization-parameters>
                    <output:method value='text'/>
                    <output:media-type value='text/plain'/>
                </output:serialization-parameters>
            </rest:response>, tei2ttl:ttl-output($data)):)
        else if($flag = 'geojson') then 
            (<rest:response> 
                <http:response status="200"> 
                    <http:header name="Content-Type" value="application/json; charset=utf-8"/>
                    <http:header name="Access-Control-Allow-Origin" value="application/json; charset=utf-8"/> 
                </http:response> 
             </rest:response>, geojson:geojson($data))
        else if($flag = 'kml') then 
            (<rest:response> 
                <http:response status="200"> 
                    <http:header name="Content-Type" value="application/xml; charset=utf-8"/>  
                </http:response> 
                <output:serialization-parameters>
                    <output:method value='xml'/>
                    <output:media-type value='application/vnd.google-earth.kmz'/>
                    </output:serialization-parameters>                        
             </rest:response>, geokml:kml($data))
        else if($flag = 'json') then 
            (<rest:response> 
                <http:response status="200"> 
                    <http:header name="Content-Type" value="application/json; charset=utf-8"/>
                    <http:header name="Access-Control-Allow-Origin" value="application/json; charset=utf-8"/> 
                </http:response> 
             </rest:response>, jsonld:jsonld($data))
        else if($flag = 'txt') then 
            (<rest:response> 
                <http:response status="200"> 
                    <http:header name="Content-Type" value="text/plain; charset=utf-8"/>
                    <http:header name="Access-Control-Allow-Origin" value="text/plain; charset=utf-8"/> 
                </http:response> 
             </rest:response>, tei2txt:tei2txt($data))
        (: Output as html using existdb templating module or tei2html.xqm :)
        else
            (:
            let $work-uris := 
                distinct-values(for $collection in $global:get-config//repo:collection
                    let $short-path := replace($collection/@record-URI-pattern,$global:base-uri,'')
                    return replace($short-path,'/',''))
            let $folder := tokenize(substring-before($path,concat('/',$page)),'/')[last()]                    
            return  
                if($folder = $work-uris) then         
                    let $id :=  if(contains($page,'.')) then
                                    concat($global:get-config//repo:collection[contains(@record-URI-pattern, $folder)][1]/@record-URI-pattern,substring-before($page,"."))
                                else concat($global:get-config//repo:collection[contains(@record-URI-pattern, $folder)][1]/@record-URI-pattern,$page)
                    let $collection := $global:get-config//repo:collection[contains(@record-URI-pattern,concat('/',$folder))]/@app-root
                    let $html-path := concat($global:app-root,'/',$global:get-config//repo:collection[contains(@record-URI-pattern, $folder)][1]/@app-root,'/record.html') 
                    return  
                        (<rest:response> 
                            <http:response status="200"> 
                                <http:header name="Content-Type" value="text/html; charset=utf-8"/>  
                            </http:response> 
                            <output:serialization-parameters>
                                <output:method value='html5'/>
                                <output:media-type value='text/html'/>
                            </output:serialization-parameters>                        
                        </rest:response>, cntneg:render-html($html-path,$id)) 
                else if($page != '') then (<rest:response> 
                        <http:response status="200"> 
                            <http:header name="Content-Type" value="text/html; charset=utf-8"/>  
                        </http:response> 
                        <output:serialization-parameters>
                            <output:method value='html5'/>
                            <output:media-type value='text/html'/>
                        </output:serialization-parameters>                        
                     </rest:response>,cntneg:render-html($page,''))                   
                else:) (<rest:response> 
                            <http:response status="200"> 
                                <http:header name="Content-Type" value="text/html; charset=utf-8"/>  
                            </http:response> 
                            <output:serialization-parameters>
                                <output:method value='html5'/>
                                <output:media-type value='text/html'/>
                            </output:serialization-parameters>                        
                          </rest:response>, tei2html:tei2html($data))
};


(:~
 : Process HTML templating from within a RestXQ function.
 : @see https://github.com/eXist-db/demo-apps/blob/master/examples/templating/restxq-demo.xql 
:)(:
declare function cntneg:render-html($content as xs:string, $id as xs:string?){
    let $content := doc($content)
    return 
        if($content) then 
             let $config := map {
                 $templates:CONFIG_APP_ROOT := $config:app-root,
                 $templates:CONFIG_STOP_ON_ERROR := true(),
                 $templates:CONFIG_PARAM_RESOLVER := function($param as xs:string) as xs:string* {
                     switch ($param)
                        case "id" return
                            $id
                        default return (:req:parameter($param):)$param
                 }
             }
             let $lookup := function($functionName as xs:string, $arity as xs:int) {
                 try {
                     function-lookup(xs:QName($functionName), $arity)
                 } catch * {
                     ()
                 }
             }
             return
                 templates:apply($content, $lookup, (), $config)
        else <p>Content {$content} id: {$id}</p>      
};
:) 

(: Utility functions to set media type-dependent values :)

(: Functions used to set media type-specific values :)
declare function cntneg:determine-extension($header){
    if (contains(string-join($header),"application/rdf+xml") or $header = 'rdf') then "rdf"
    else if (contains(string-join($header),"text/turtle") or $header = ('ttl','turtle')) then "ttl"
    else if (contains(string-join($header),"application/ld+json") or contains(string-join($header),"application/json") or $header = ('json','ld+json')) then "json"
    else if (contains(string-join($header),"application/tei+xml") or contains(string-join($header),"text/xml") or $header = ('tei','xml')) then "tei"
    else if (contains(string-join($header),"application/atom+xml") or $header = 'atom') then "atom"
    else if (contains(string-join($header),"application/vnd.google-earth.kmz") or $header = 'kml') then "kml"
    else if (contains(string-join($header),"application/geo+json") or $header = 'geojson') then "geojson"
    else if (contains(string-join($header),"text/plain") or $header = 'txt') then "txt"
    else "html"
};

declare function cntneg:determine-media-type($extension){
  switch($extension)
    case "rdf" return "application/rdf+xml"
    case "tei" return "application/tei+xml"
    case "tei" return "text/xml"
    case "atom" return "application/atom+xml"
    case "ttl" return "text/turtle"
    case "json" return "application/ld+json"
    case "kml" return "application/vnd.google-earth.kmz"
    case "geojson" return "application/geo+json"
    case "txt" return "text/plain"
    default return "text/html"
};

(: NOTE: not sure this is needed:)
declare function cntneg:determine-type-flag($extension){
  switch($extension)
    case "rdf" return "rdf"
    case "atom" return "atom"
    case "tei" return "xml"
    case "xml" return "xml"
    case "ttl" return "turtle"
    case "json" return "json"
    case "kml" return "kml"
    case "geojson" return "geojson"
    case "html" return "html"
    case "htm" return "html"
    case "txt" return "txt"
    case "text" return "txt"
    default return "html"
};
