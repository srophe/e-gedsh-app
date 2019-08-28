xquery version "3.0";

(:~
 : Passes content to content negotiation module, if not using restxq
 : @author Winona Salesky <wsalesky@gmail.com>
 : @authored 2018-04-12
:)

import module namespace config="http://syriaca.org/config" at "../config.xqm";

(: Content serialization modules. :)
import module namespace cntneg="http://syriaca.org/cntneg" at "content-negotiation.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "tei2html.xqm";

import module namespace global="http://syriaca.org/global" at "../lib/global.xqm";

(: Import KWIC module:)
import module namespace kwic="http://exist-db.org/xquery/kwic";

(: Namespaces :)
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace http="http://expath.org/ns/http-client";

let $path := if(request:get-parameter('id', '')  != '') then 
                request:get-parameter('id', '')
             else if(request:get-parameter('doc', '') != '') then
                request:get-parameter('doc', '')
             else ()   
let $data :=
    if(request:get-parameter('id', '') != '' or request:get-parameter('doc', '') != '') then
        let $id := request:get-parameter('id', '')
        let $parse-id :=
            if(contains($id,$global:base-uri) or starts-with($id,'http://')) then $id
            else if(contains(request:get-uri(),$global:nav-base)) then 
            replace(request:get-uri(),$global:nav-base, $global:base-uri)
            else if(contains(request:get-uri(),$global:base-uri)) then request:get-uri()
            else $id
        let $final-id := if(ends-with($parse-id,'.html')) then substring-before($parse-id,'.html')
                         else if(ends-with($parse-id,'/tei')) then substring-before($parse-id,'/tei') 
                         else $parse-id
        return global:get-rec($final-id)
    else ()
let $format := if(request:get-parameter('format', '') != '') then request:get-parameter('format', '') else 'xml'    
return  
    if(not(empty($data))) then
        cntneg:content-negotiation($data, $format, $path)    
    else ()