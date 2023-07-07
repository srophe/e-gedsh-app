xquery version "3.1";

module namespace sf = "http://srophe.org/srophe/facets";
import module namespace functx="http://www.functx.com";
import module namespace config="http://srophe.org/srophe/config" at "../config.xqm";

declare namespace facet="http://expath.org/ns/facet";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $sf:QUERY_OPTIONS := map {
    "leading-wildcard": "yes",
    "filter-rewrite": "yes"
};

(: ~ 
 : Build indexes for fields and facets as specified in facet-def.xml and search-config.xml files
 : Note: Investigate boost? 
:)
declare function sf:build-index(){
<index xmlns="http://exist-db.org/collection-config/1.0" xmlns:tei="http://www.tei-c.org/ns/1.0">
    <lucene diacritics="no">
        <module uri="http://srophe.org/srophe/facets" prefix="sf" at="xmldb:exist:///{$config:app-root}/modules/lib/facets.xql"/>
        <text qname="tei:div">{
        let $facets :=     
            for $f in collection($config:app-root)//facet:facet-definition
            let $path := document-uri(root($f))
            group by $facet-grp := $f/@name
            return 
                if($f[1]/facet:group-by/@function != '') then 
                    <facet dimension="{functx:words-to-camel-case($facet-grp)}" expression="sf:facet(descendant-or-self::tei:div, {concat("'",$path[1],"'")}, {concat("'",string($f[1]/facet:group-by/@function),"'")})"/>
                else 
                    <facet dimension="{functx:words-to-camel-case($facet-grp)}" expression="{replace($f[1]/facet:group-by/facet:sub-path/text(),"&#34;","'")}"/>
        let $fields := 
            for $f in collection($config:app-root)//*:search-config/*:field
            let $path := document-uri(root($f))
            group by $field-grp := $f/@name
            where $field-grp != 'keyword' and  $field-grp != 'fullText'
            return 
                if($f[1]/@function != '') then 
                    (:element a { attribute href { $node/@ref }, $name }:)
                    element field { 
                        attribute name {functx:words-to-camel-case($field-grp)},
                        attribute expression {'sf:field(descendant-or-self::tei:div', concat("'",$path[1],"'"), concat("'",string($f[1]/@function),"'")},
                        if($f[1]/@boost != '') then 
                            attribute boost { string($f[1]/@boost) }
                        else ()
                    }
                    (:<field name="{functx:words-to-camel-case($field-grp)}" 
                    expression="sf:field(descendant-or-self::tei:div, {concat("'",$path[1],"'")}, {concat("'",string($f[1]/@function),"'")})"/>,
                    if($f[1]/@boost != '') then attribute boost { string($f[1]/@boost) } else ()):)
                else 
                    element field { 
                        attribute name {functx:words-to-camel-case($field-grp)},
                        attribute expression {string($f[1]/@expression)},
                        if($f[1]/@boost != '') then 
                            attribute boost { string($f[1]/@boost) }
                        else ()
                    }
        return 
            ($facets,$fields)
        }
        <!--<ignore qname="tei:body"/>-->
        </text>
        <text qname="tei:fileDesc"/>
        <text qname="tei:front"/>
        <text qname="tei:back"/>
    </lucene> 
    <range>
        <create qname="@syriaca-computed-start" type="xs:date"/>
        <create qname="@syriaca-computed-end" type="xs:date"/>
        <create qname="@type" type="xs:string"/>
        <create qname="@ana" type="xs:string"/>
        <create qname="@syriaca-tags" type="xs:string"/>
        <create qname="@when" type="xs:string"/>
        <create qname="@target" type="xs:string"/>
        <create qname="@who" type="xs:string"/>
        <create qname="@ref" type="xs:string"/>
        <create qname="@uri" type="xs:string"/>
        <create qname="@where" type="xs:string"/>
        <create qname="@active" type="xs:string"/>
        <create qname="@passive" type="xs:string"/>
        <create qname="@mutual" type="xs:string"/>
        <create qname="@name" type="xs:string"/>
        <create qname="@xml:lang" type="xs:string"/>
        <create qname="@status" type="xs:string"/>
        <create qname="tei:ab" type="xs:string"/>
        <create qname="tei:idno" type="xs:string"/>
        <create qname="tei:title" type="xs:string"/>
        <create qname="tei:geo" type="xs:string"/>
        <create qname="tei:relation" type="xs:string"/>
        <create qname="tei:persName" type="xs:string"/>
        <create qname="tei:placeName" type="xs:string"/>
        <create qname="tei:author" type="xs:string"/>
    </range>
</index>
};

(: Update collection.xconf file for data application, can be called by post install script, or index.xql :)
declare function sf:update-index(){
  try {
        let $indexFile := doc(concat('/db/system/config',replace($config:data-root,'/data',''),'/collection.xconf'))
        return 
            (update replace $indexFile//*:index with sf:build-index(), xmldb:reindex($config:data-root))
    } catch * {('error: ',concat($err:code, ": ", $err:description))}
};

(: Main facet function, for generic facets :)

(: Build facet path based on facet definition file. Used by collection.xconf to build facets at index time. 
 : @param $path - path to facet definition file, if empty assume root.
 : @param $name - name of facet in facet definition file. 
 :
 : TODO: test custom facets/fields
:)
declare function sf:facet($element as element()*, $path as xs:string, $name as xs:string){
    let $facet-definition :=  
        if(doc-available($path)) then
            doc($path)//facet:facet-definition[@name=$name]
        else () 
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text()    
    return 
        if(not(empty($facet-definition))) then  
            if($facet-definition/facet:group-by/@function != '') then 
              try { 
                    util:eval(concat('sf:facet-',string($facet-definition/facet:group-by/@function),'($element,$facet-definition)'))
                } catch * {concat($err:code, ": ", $err:description)}
            else util:eval(concat('$element/',$xpath))
        else ()  
};

declare function sf:field($element as element()*, $path as xs:string, $name as xs:string){
    let $field-definition :=  
        if(doc-available($path)) then
            doc($path)//*:field[@name=$name]
        else () 
    let $xpath := $field-definition/*:expression/text()    
    return 
        if(not(empty($field-definition))) then  
            if($field-definition/@function != '') then 
                try { 
                    util:eval(concat('sf:field-',string($field-definition/@function),'($element,$field-definition)'))
                } catch * {concat($err:code, ": ", $err:description)}
            else util:eval(concat('$element/',$xpath)) 
        else ()  
};

(: Custom search fields :)
(: Full text search, search body and part of the TEI header :)
declare function sf:field-fullText($element as element()*, $facet-definition as item()){
    $element/descendant::tei:fileDesc
};

(: Same as fullText :)
declare function sf:field-keyword($element as element()*, $facet-definition as item()){
    $element/descendant::tei:fileDesc
};

(: Title field :)
declare function sf:field-title($element as element()*, $facet-definition as item()){
    if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct) then 
        $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:title
    else $element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/tei:title
};

(: Title field :)
declare function sf:facet-title($element as element()*, $facet-definition as item()){
    if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct) then 
        $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:title
    else $element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/tei:title
};

(: Author field :)
declare function sf:field-author($element as element()*, $facet-definition as item()){
    if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct) then 
        $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:author | $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:editor
    else $element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/descendant::tei:author
};

(: Author field :)
declare function sf:facet-authors($element as element()*, $facet-definition as item()){
    if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct) then 
        $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:author | $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:editor
    else $element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/descendant::tei:author
};

declare function sf:facet-biblAuthors($element as element()*, $facet-definition as item()){
    if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct) then 
        $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:author | $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:editor
    else $element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/descendant::tei:author
};

(:e-gedsh custom field, determin if type is an entry: [@type=('entry','crossreference','section','subsection')][tei:ab[@type='idnos']] :)
declare function sf:field-type($element as element()*, $facet-definition as item()){
   let $type := lower-case($element/@type)
   return 
        if($type = ('entry','crossreference','section','subsection')) then 'entry' 
        else ()
};

(: Display, output functions 
request:get-parameter-names()[starts-with(., 'facet-')]
request:get-parameter('start', 1) 
:)
declare function sf:display($result as item()*, $facet-definition as item()*) {
    for $facet in $facet-definition//facet:facet-definition
    let $name := string($facet/@name)
    let $count := if(request:get-parameter(concat('all-',$name), '') = 'on' ) then () else string($facet/facet:max-values/@show)
    let $f := ft:facets($result, $name, $count)
    let $sort := $facet-definition/facet:order-by
    return 
        if (map:size($f) > 0) then
            <span class="facet-grp">
                <span class="facet-title">{string($facet/@label)}</span>
                <span class="facet-list">
                {array:for-each(sf:sort($f), function($entry) {
                    map:for-each($entry, function($label, $freq) {
                        let $param-name := concat('facet-',$name)
                        let $facet-param := concat($param-name,'=',$label)
                        let $active := if(request:get-parameter($param-name, '') = $label) then 'active' else ()
                        let $url-params := 
                            if($active) then replace(replace(request:get-query-string(),$facet-param,''),'&amp;&amp;','&amp;') 
                            else concat($facet-param,'&amp;',request:get-query-string())
                        return
                            <a href="?{$url-params}" class="facet-label btn btn-default {$active}">
                            {if($active) then <span class="glyphicon glyphicon-remove facet-remove"></span> else ()}
                            {$label} <span class="count"> ({$freq})</span> </a>
                    })
                })}
                {if(map:size($f) = xs:integer($count)) then 
                    <a href="?{request:get-query-string()}&amp;all-{$name}=on" class="facet-label btn btn-info"> View All </a>
                 else ()}
                </span>
            </span>
        else ()  
};

(:~ 
 : Add sort option to facets 
 : Work in progress, need to pass sort options from facet-definitions to sort function.
:)
declare function sf:sort($facets as map(*)?) {
    array {
        if (exists($facets)) then
            for $key in map:keys($facets)
            let $value := map:get($facets, $key)
            order by $key ascending
            return
                map { $key: $value }
        else
            ()
    }
};

(:~
 : Build map for search query
 : Used by search functions
 :)
declare function sf:facet-query() {
    map:merge((
        $sf:QUERY_OPTIONS,
        map {
            "facets":
                map:merge((
                    for $param in request:get-parameter-names()[starts-with(., 'facet-')]
                    let $dimension := substring-after($param, 'facet-')
                    return
                        map {
                            $dimension: request:get-parameter($param, ())
                        }
                ))
        }
    ))
};
