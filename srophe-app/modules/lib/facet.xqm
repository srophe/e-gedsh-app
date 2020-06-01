xquery version "3.0";
(:~ 
 : Partial facet implementation for eXist-db based on the EXPath specifications (http://expath.org/spec/facet)
 : 
 : Uses the following eXist-db specific functions:
 :      util:eval 
 :      request:get-parameter
 :      request:get-parameter-names()
 : 
 : @author Winona Salesky
 : @version 1.0 
 :
 : @see http://expath.org/spec/facet   
 : 
 : TODO: 
 :  Handle arrays in attribute values, see tei:relation/@mutual for an example
 :  Support for hierarchical facets
 :)

module namespace facet = "http://expath.org/ns/facet";
import module namespace global="http://srophe.org/srophe/global" at "global.xqm";
import module namespace functx="http://www.functx.com";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

(: External facet parameters :)
declare variable $facet:fq {request:get-parameter('fq', '') cast as xs:string};

(:~
 : Given a result sequence, and a sequence of facet definitions, count the facet-values for each facet defined by the facet definition(s).
 : Accepts one or more facet:facet-definition elements
 : Signiture: 
    facet:count($results as item()*,
        $facet-definitions as element(facet:facet-definition)*) as element(facet:facets)
 : @param $results results node to be faceted on.
 : @param $facet-definitions one or more facet:facet-definition element
:) 
declare function facet:count($results as item()*, $facet-definitions as element(facet:facet-definition)*) as element(facet:facets){
<facets xmlns="http://expath.org/ns/facet">
    {   
    for $facet in $facet-definitions
    return 
    <facet name="{$facet/@name}" show="{$facet/descendant::facet:max-values/@show}" max="{$facet/descendant::facet:max-values/text()}">
        {
        let $max := if($facet/descendant::facet:max-values/text()) then $facet/descendant::facet:max-values/text() else ()
        for $facets at $i in subsequence(facet:facet($results, $facet),1)
        return $facets
        }
    </facet>
    }
</facets>  
};

(:~
 : Given a result sequence, and a facet definition, count the facet-values for each facet defined by the facet definition. 
 : Facet defined by facets:facet-definition/facet:group-by/facet:sub-path 
 : @param $results results to be faceted on. 
 : @param $facet-definitions one or more facet:facet-definition element
:) 
declare function facet:facet($results as item()*, $facet-definitions as element(facet:facet-definition)?) as item()*{
    if($facet-definitions/facet:range) then
        facet:group-by-range($results, $facet-definitions)
    else if($facet-definitions/facet:facet-definition) then
        facet:group-by-subfacet($results, $facet-definitions)    
    else if ($facet-definitions/facet:group-by/@function) then
        util:eval(concat($facet-definitions/facet:group-by/@function,'($results,$facet-definitions)'))
    else facet:group-by($results, $facet-definitions)
};

(:~
 : Given a result sequence, and a facet definition, count the facet-values for each facet defined by the facet definition. 
 : Facet defined by facets:facet-definition/facet:group-by/facet:sub-path 
 : @param $results results to be faceted on. 
 : @param $facet-definitions one or more facet:facet-definition element
:) 
(: TODO: Need to be able to switch out descending with ascending based on facet-def/order-by/@direction:)
declare function facet:group-by($results as item()*, $facet-definitions as element(facet:facet-definition)?) as element(facet:key)*{
    let $path := concat('$results/',$facet-definitions/facet:group-by/facet:sub-path/text())
    let $sort := $facet-definitions/facet:order-by
    for $f in util:eval($path)
    group by $facet-grp := $f
    order by 
        if($sort/text() = 'value') then $facet-grp
        else count($f)
        descending
    return <key xmlns="http://expath.org/ns/facet" count="{count($f)}" value="{$facet-grp}" label="{$facet-grp}"/>
};

(:~
 : Syriaca.org specific group-by function for correctly labeling attributes with arrays.
:)
declare function facet:group-by-array($results as item()*, $facet-definitions as element(facet:facet-definition)?){
    let $path := concat('$results/',$facet-definitions/facet:group-by/facet:sub-path/text()) 
    let $sort := $facet-definitions/facet:order-by
    let $d := tokenize(string-join(util:eval($path),' '),' ')
    for $f in $d
    group by $facet-grp := tokenize($f,' ')
    order by 
        if($sort/text() = 'value') then $facet-grp
        else count($f)
        descending
    return <key xmlns="http://expath.org/ns/facet" count="{count($f)}" value="{$facet-grp}" label="{$facet-grp}"/>
};

(:~
 : Given a result sequence, and a facet definition, count the facet-values for each range facet defined by the facet definition. 
 : Range values defined by: range and range/bucket elements
 : Facet defined by facets:facet-definition/facet:group-by/facet:sub-path 
 : @param $results results to be faceted on. 
 : @param $facet-definitions one or more facet:facet-definition element
:) 
declare function facet:group-by-range($results as item()*, $facet-definitions as element(facet:facet-definition)*) as element(facet:key)*{
    let $ranges := $facet-definitions/facet:range
    let $sort := $facet-definitions/facet:order-by
    for $range in $ranges/facet:bucket
    let $path := concat('$results/',$facet-definitions/descendant::facet:sub-path/text(),'[. gt "', facet:type($range/@gt, $ranges/@type),'" and . lt "',facet:type($range/@lt, $ranges/@type),'"]')
    let $f := util:eval($path)
    order by 
            if($sort/text() = 'value') then $f[1]
            else count($f)
        descending
    return 
         <key xmlns="http://expath.org/ns/facet" count="{count($f)}" value="{string($range/@name)}" label="{string($range/@name)}"/>
};

declare function facet:group-by-subfacet($results as item()*, $facet-definitions as element(facet:facet-definition)*) as element(facet:key)*{
    let $facets := $facet-definitions/facet:facet-definition
    for $facet in $facets
    return 
        if ($facet/facet:group-by/@function) then
            util:eval(concat($facet/facet:group-by/@function,'($results,$facet)'))
        else facet:group-by($results, $facet-definitions)
};

(:~ 
    e-gedsh front/back matter sort
:)
declare function facet:group-front-back($results as item()*, $facet-definitions as element()*) as element(facet:key)*{
    let $path := concat('$results/',$facet-definitions/descendant::facet:sub-path/text())
    let $name := $facet-definitions/@name
    let $parent := $facet-definitions/parent::*[1]/@name 
    let $facet-name := concat($parent,';',$name,';')
    for $f in util:eval($path)
    group by $facet-grp := $f
    return 
        <key xmlns="http://expath.org/ns/facet" count="{count($f)}" value="{$facet-name[1]}" label="{$name[1]}">
             {
                if(contains($facet:fq, concat(':',$facet-name[1]))) then 
                    for $sf in $f
                    let $value := if($sf/parent::*[1]/preceding-sibling::tei:idno[@type='URI']) then 
                                    $sf/parent::*[1]/preceding-sibling::tei:idno[@type='URI'][1]
                                  else string($sf/parent::*[1]/following-sibling::tei:idno[@type='URI'][1])
                    let $label := $sf/ancestor-or-self::tei:ab[1]/parent::tei:div[1]/tei:head[1] 
                    return <key xmlns="http://expath.org/ns/facet" count="{count($sf)}" value="{$value[1]}" label="{$label}"/>
                else ()
            }
        </key>   
};


(:~ 
    e-gedsh alpha sort
:)
declare function facet:group-by-abc($results as item()*, $facet-definitions as element()*) as element(facet:key)*{
    let $path := concat('$results/',$facet-definitions/descendant::facet:sub-path/text())
    let $name := $facet-definitions/@name
    let $parent := $facet-definitions/parent::*[1]/@name 
    for $f in util:eval($path)
    let $sort-string := translate(translate(translate(translate(upper-case(substring(global:build-sort-string(replace($f[1],'ʿ',''),''),1,1)),'Ṭ','T'),'Ṣ','S'),'Ç ','C'),'Ḥ','H')
    group by $facet-grp := $sort-string
    order by $facet-grp ascending
    return 
    <key xmlns="http://expath.org/ns/facet" count="{count($f)}" value="{concat($parent[1],';',$facet-grp,';')}" label="{$facet-grp}">
        {
            if(contains($facet:fq, concat(':',concat($parent[1],';',$facet-grp,';')))) then 
                for $sf in $f
                let $value := if($sf/following-sibling::tei:ab[1]/tei:idno[@type='URI']) then 
                                $sf/following-sibling::tei:ab[1]/tei:idno[@type='URI'][1]
                              else string($sf/following-sibling::tei:ab[1]/tei:ref[1]/@target)
                let $see :=   if($sf/following-sibling::tei:ab/tei:ref) then 
                                concat(' see ',string($sf/following-sibling::tei:ab[1]/tei:ref[1]))
                              else () 
                return <key xmlns="http://expath.org/ns/facet" count="{count($sf)}" value="{$value[1]}" label="{($sf[1],$see)}"/>
            else ()
        }
    </key>
};

(:~
 : Adds type casting when type is specified facet:facet:group-by/@type
 : @param $value of xpath
 : @param $type value of type attribute
:)
declare function facet:type($value as item()*, $type as xs:string?) as item()*{
    if($type != '') then  
        if($type = 'xs:string') then xs:string($value)
        else if($type = 'xs:string') then xs:string($value)
        else if($type = 'xs:decimal') then xs:decimal($value)
        else if($type = 'xs:integer') then xs:integer($value)
        else if($type = 'xs:long') then xs:long($value)
        else if($type = 'xs:int') then xs:int($value)
        else if($type = 'xs:short') then xs:short($value)
        else if($type = 'xs:byte') then xs:byte($value)
        else if($type = 'xs:float') then xs:float($value)
        else if($type = 'xs:double') then xs:double($value)
        else if($type = 'xs:dateTime') then xs:dateTime($value)
        else if($type = 'xs:date') then xs:date($value)
        else if($type = 'xs:gYearMonth') then xs:gYearMonth($value)        
        else if($type = 'xs:gYear') then xs:gYear($value)
        else if($type = 'xs:gMonthDay') then xs:gMonthDay($value)
        else if($type = 'xs:gMonth') then xs:gMonth($value)        
        else if($type = 'xs:gDay') then xs:gDay($value)
        else if($type = 'xs:duration') then xs:duration($value)        
        else if($type = 'xs:anyURI') then xs:anyURI($value)
        else if($type = 'xs:Name') then xs:Name($value)
        else $value
    else $value
};

(:~
 : XPath filter to be passed to main query
 : creates XPath based on facet:facet-definition//facet:sub-path.
 : @param $facet-def facet:facet-definition element
 : NOTE: need to do type checking here
 : NOTE: add range handling here. 
:)
declare function facet:facet-filter($facet-definitions as node()*)  as item()*{
    if($facet:fq != '') then
        string-join(
        for $facet in tokenize($facet:fq,';fq-')
        let $facet-name := substring-before($facet,':')
        let $facet-value := normalize-space(substring-after($facet,':'))
        return 
            for $facet in $facet-definitions/facet:facet-definition[@name = $facet-name]
            let $path := 
                         if(matches($facet/descendant::facet:sub-path/text(), '^/@')) then concat('descendant::*/',substring($facet/descendant::facet:sub-path/text(),2))
                         else $facet/descendant::facet:sub-path/text()
            return 
            if($facet-value != '') then 
                if($facet/facet:range) then
                    concat('[',$path,'[string(.) gt "', facet:type($facet/facet:range/facet:bucket[@name = $facet-value]/@gt, $facet/facet:range/facet:bucket[@name = $facet-value]/@type),'" and string(.) lt "',facet:type($facet/facet:range/facet:bucket[@name = $facet-value]/@lt, $facet/facet:range/facet:bucket[@name = $facet-value]/@type),'"]]')
                else if($facet/facet:group-by[@function="facet:group-by-array"]) then 
                    concat('[',$path,'[matches(., "',$facet-value,'(\W|$)")]',']')
                else concat('[',$path,'[string(.) = "',$facet-value,'"]',']')
            else(),'')    
    else () 
};

(:~ 
 : Builds new facet params for html links.
 : Uses request:get-parameter-names() to get all current params 
 :)
declare function facet:url-params(){
    string-join(
    for $param in request:get-parameter-names()
    return 
        if($param = 'fq') then ()
        else if($param = 'start') then '&amp;start=1'
        else if(request:get-parameter($param, '') = ' ') then ()
        else concat('&amp;',$param, '=',request:get-parameter($param, '')),'')
};

(: HTML display functions :)

(:~
 : Create 'Remove' button 
 : Constructs new URL for user action 'remove facet'
:)
declare function facet:selected-facets-display(){
    for $facet in tokenize($facet:fq,';fq-')
    let $value := substring-after($facet,':')
    let $new-fq := string-join(
                    for $facet-param in tokenize($facet:fq,';fq-') 
                    return 
                        if($facet-param = $facet) then ()
                        else concat(';fq-',$facet-param),'')
    let $href := if($new-fq != '') then concat('?fq=',replace(replace($new-fq,';fq- ',''),';fq-;fq-',';fq-'),facet:url-params()) else ()
    return 
        if($facet != '') then 
            <span class="label label-facet" title="Remove {$value}">
                {$value} <a href="{$href}" class="facet icon"> x</a>
            </span>
        else()
};


(:~
 : Create 'Add' button 
 : Constructs new URL for user action 'Add facet'
:)
declare function facet:html-list-facets-as-buttons($facets as node()*){
(
for $facet in tokenize($facet:fq,';fq-')
let $facet-name := substring-before($facet,':')
let $new-fq := string-join(
                for $facet-param in tokenize($facet:fq,';fq-') 
                return 
                    if($facet-param = $facet) then ()
                    else concat(';fq-',$facet-param),'')
let $href := if($new-fq != '') then concat('?fq=',replace(replace($new-fq,';fq- ',''),';fq-;fq-',';fq-'),facet:url-params()) else ()
return
    if($facet != '') then
        for $f in $facets/facet:facet[@name = $facet-name]
        let $fn := string($f/@name)
        let $label := string($f/facet:key[@value = substring-after($facet,concat($facet-name,':'))][1]/@label)
        let $value := if(starts-with($label,'http://syriaca.org/')) then 
                         facet:get-label($label)   
                      else $label
        return 
                <span class="label label-facet" title="Remove {$value}">
                    {concat($fn,': ', $value)} <a href="{$href}" class="facet icon"> x</a>
                </span>
    else(),
for $f in $facets/facet:facet
let $count := count($f/facet:key)
return 
    if($count gt 0) then 
        if(string($f/@name) = 'Browse') then
            <div class="facet-grp">
            <h4>{string($f/@name)}</h4>
                <div class="facet-list show">{
                    for $key at $l in subsequence($f/facet:key,1)
                    let $facet-query := replace(replace(concat(';fq-',string($f/@name),':',string($key/@value)),';fq-;fq-;',';fq-'),';fq- ','')
                    let $new-fq := concat('fq=',$facet-query)
                    return 
                        (if(contains($facet:fq, concat(':',string($key/@value)))) then 
                            <a href="?start=1" class="facet-label btn btn-default active">
                                {facet:get-label(string($key/@label))} <span class="count"> ({string($key/@count)})</span>
                            </a>
                        else 
                            <a href="?{$new-fq}" class="facet-label btn btn-default">
                                {facet:get-label(string($key/@label))} <span class="count"> ({string($key/@count)})</span>
                            </a>,
                           if($key/facet:key) then
                                (
                                <div class="facet-list show">
                                    {
                                    for $sub-key in subsequence($key/facet:key, 1)
                                    return
                                        <a href="{concat($global:nav-base,'/entry',substring-after($sub-key/@value,$global:base-uri))}?{$new-fq}" class="facet-label btn btn-default sub-menu">
                                            {
                                                if(contains($sub-key/@label,' see ')) then
                                                    (substring-before($sub-key/@label,' see '), <span class="browse cross-ref"> see </span>, substring-after($sub-key/@label,' see '))
                                                else string($sub-key/@label)
                                            }
                                        </a>
                                    } 
                                 </div>)     
                           else()
                        )
                    }
                </div>
                <div class="facet-list collapse" id="{concat('show',replace(string($f/@name),' ',''))}">{
                    for $key at $l in subsequence($f/facet:key,$f/@show + 1,$f/@max)
                    let $facet-query := replace(replace(concat(';fq-',string($f/@name),':',string($key/@value)),';fq-;fq-;',';fq-'),';fq- ','')
                    let $new-fq := 
                        if($facet:fq) then concat('fq=',$facet:fq,$facet-query)
                        else concat('fq=',$facet-query)
                    return <a href="?{$new-fq}{facet:url-params()}" class="facet-label btn btn-default">{facet:get-label(string($key/@label))} <span class="count"> ({string($key/@count)})</span></a>
                    }
                </div>
                {if($count gt ($f/@show - 1)) then 
                    <a class="facet-label togglelink btn btn-info" data-toggle="collapse" data-target="#{concat('show',replace(string($f/@name),' ',''))}" data-text-swap="Less"> More &#160;<i class="glyphicon glyphicon-circle-arrow-right"></i></a>
                else()}
        </div>
        else 
         <div class="facet-grp">
             <h4>{string($f/@name)}</h4>
                 <div class="facet-list show">{
                     for $key at $l in subsequence($f/facet:key,1,$f/@show)
                     let $facet-query := (:replace(replace(concat(';fq-',string($f/@name),':',string($key/@value)),';fq-;fq-;',';fq-'),';fq- ',''):)''
                     let $new-fq := 
                         if($facet:fq) then concat('fq=',$facet:fq,$facet-query)
                         else concat('fq=',$facet-query)
                     return 
                         (<a href="?{$new-fq}{facet:url-params()}" class="facet-label btn btn-default 
                         {if(contains($facet:fq, concat(';fq-',string($f/@name),':',string($key/@label)))) then 'active' else()}">{facet:get-label(string($key/@label))} <span class="count"> ({string($key/@count)})</span></a>,
                            if($key/facet:key) then
                                 (
                                 <div class="facet-list show">
                                     {
                                     for $sub-key in subsequence($key/facet:key, 1,5)
                                     return
                                         <a href="entry.html?id={string($sub-key/@value)}" class="facet-label btn btn-default sub-menu">
                                             {string($sub-key/@label)}
                                         </a>
                                     } 
                                  </div>,
                                  <div class="facet-list collapse" id="{concat('show',replace(string($key/@label),' ',''))}">
                                     {
                                     for $sub-key in subsequence($key/facet:key,6,100)
                                     return
                                         <a href="entry.html?id={string($sub-key/@value)}" class="facet-label btn btn-default sub-menu">
                                             {string($sub-key/@label)}
                                         </a>
                                     }
                                  </div>,
                                  if(count($key/facet:key) gt 5) then 
                                      <a class="facet-label togglelink btn btn-info" data-toggle="collapse" data-target="#{concat('show',replace(string($key/@label),' ',''))}" data-text-swap="Less"> More &#160;<i class="glyphicon glyphicon-circle-arrow-right"></i></a>
                                   else())
                                     
                            else()
                         )
                         
                     }
                 </div>
                 <div class="facet-list collapse" id="{concat('show',replace(string($f/@name),' ',''))}">{
                     for $key at $l in subsequence($f/facet:key,$f/@show + 1,$f/@max)
                     let $facet-query := replace(replace(concat(';fq-',string($f/@name),':',string($key/@value)),';fq-;fq-;',';fq-'),';fq- ','')
                     let $new-fq := 
                         if($facet:fq) then concat('fq=',$facet:fq,$facet-query)
                         else concat('fq=',$facet-query)
                     return <a href="?{$new-fq}{facet:url-params()}" class="facet-label btn btn-default">{facet:get-label(string($key/@label))} <span class="count"> ({string($key/@count)})</span></a>
                     }
                 </div>
                 {if($count gt ($f/@show - 1)) then 
                     <a class="facet-label togglelink btn btn-info" data-toggle="collapse" data-target="#{concat('show',replace(string($f/@name),' ',''))}" data-text-swap="Less"> More &#160;<i class="glyphicon glyphicon-circle-arrow-right"></i></a>
                 else()}
         </div>
    else()
)    
};

(:~
 : Syriaca.org specific function to label URI's with human readable labels. 
 : @param $uri Syriaca.org uri to be used for lookup. 
 : NOTE: this function will probably slow down the facets.
:)

declare function facet:get-label($uri as item()*){
if(starts-with($uri,'http://syriaca.org/')) then 
  replace(string-join(collection('/db/apps/srophe-data/data')/range:field-eq("uri", concat($uri,"/tei"))[1]/descendant::tei:fileDesc/tei:titleStmt[1]/tei:title[1]/text()[1],' '),' — ','')
else $uri
};
