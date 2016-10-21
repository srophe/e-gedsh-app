xquery version "3.0";
(:~  
 : Builds browse pages for Syriac.org sub-collections 
 : Alphabetical English and Syriac Browse lists, browse by type, browse by date, map browse. 
 :
 : @see lib/global.xqm for global variables
 : @see lib/paging.xqm for paging functionality
 : @see lib/geojson.xqm for map generation
 : @see browse-spear.xqm for additional SPEAR browse functions 
 :)

module namespace browse="http://syriaca.org/browse";
import module namespace global="http://syriaca.org/global" at "lib/global.xqm";
import module namespace facet="http://expath.org/ns/facet" at "lib/facet.xqm";
import module namespace facet-defs="http://syriaca.org/facet-defs" at "facet-defs.xqm";
import module namespace page="http://syriaca.org/page" at "lib/paging.xqm";
import module namespace geo="http://syriaca.org/geojson" at "lib/geojson.xqm";
import module namespace templates="http://exist-db.org/xquery/templates";

declare namespace xslt="http://exist-db.org/xquery/transform";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace xlink = "http://www.w3.org/1999/xlink";
declare namespace transform="http://exist-db.org/xquery/transform";
declare namespace util="http://exist-db.org/xquery/util";

(:~ 
 : Parameters passed from the url
 : @param $browse:coll selects collection (persons/places ect) from browse.html 
 : @param $browse:type selects doc type filter eg: place@type
 : @param $browse:view selects language for browse display
 : @param $browse:date selects doc by date
 : @param $browse:sort passes browse by letter for alphabetical browse lists
 :)
declare variable $browse:coll {request:get-parameter('coll', '')};
declare variable $browse:type {request:get-parameter('type', '')};
declare variable $browse:lang {request:get-parameter('lang', '')};
declare variable $browse:view {request:get-parameter('view', '')};
declare variable $browse:sort {request:get-parameter('sort', '')};
declare variable $browse:sort-element {request:get-parameter('sort-element', 'title')};
declare variable $browse:sort-order {request:get-parameter('sort-order', '')};
declare variable $browse:date {request:get-parameter('date', '')};
declare variable $browse:start {request:get-parameter('start', 1) cast as xs:integer};
declare variable $browse:perpage {request:get-parameter('perpage', 25) cast as xs:integer};
declare variable $browse:fq {request:get-parameter('fq', '')};

declare variable $browse:computed-lang{ 
    if($browse:lang != '') then $browse:lang
    else if($browse:lang = '' and $browse:sort != '') then 'en'
    else ()
};

(:
 : Step one directory for browse 'browse path'
:)
declare function browse:collection-path($collection){
    if($collection = ('e-gedsh','gedsh')) then 
        concat("collection('",$global:data-root,"')")
    else 
        concat("collection('",$global:data-root,"')")
};

declare function browse:sub-collection-filter($collection){
let $c := if($browse:coll != '') then $browse:coll
          else if($collection = 'bibl') then ()
          else $collection
return          
    if($c != '') then
        concat("//tei:title[. = '",browse:parse-collections($collection),"']")    
    else ()
};

(:~
 : Make XPath for language filters. 
:)
declare function browse:lang-filter($collection){    
    if($browse:computed-lang != '') then 
        concat("/ancestor::tei:TEI/descendant::",browse:lang-element($collection),browse:lang-headwords(),"[@xml:lang = '", $browse:computed-lang, "']")
    else ()
};

(:~
  : Use headwords for Syriac and English language browse
:)
declare function browse:lang-headwords(){
    if($browse:computed-lang = ('en','syr')) then 
        "[@syriaca-tags='#syriaca-headword']"
    else ()    
};

(:~
  : Select correct tei element to base browse list on. 
  : Places use place/placeName
  : Persons use person/persName
  : All others use title
:)
declare function browse:lang-element($collection){
    if($collection = ('persons','sbd','saints','q','authors')) then
        "tei:person/tei:persName"
    else if($collection = ('places','geo')) then
        "tei:place/tei:placeName"
    else "tei:title"    
};

(:~
 : Browse by type, used for persons/places
:)
declare function browse:narrow-by-type($collection){
    if($browse:type != '') then 
        if($collection = ('persons','saints','authors')) then 
            if($browse:type != '') then 
                if($browse:type = 'unknown') then
                    "/ancestor::tei:TEI/tei:teiHeader[not(/descendant::tei:title[. = 'Qadishe: A Guide to the Syriac Saints']) and not(/descendant::tei:title[. = 'A Guide to Syriac Authors'])]"
                else 
                    concat("/ancestor::tei:TEI/descendant::tei:title[@level='m'][. ='", browse:parse-collections($browse:type),"']")
            else ()
        else   
            if($browse:type != '') then 
                 concat("/ancestor::tei:TEI/descendant::tei:place[contains(@type,'",$browse:type,"')]")
            else ()
    else ()
};          


(:~
 : Browse by date, persons only
:)
declare function browse:narrow-by-date(){
    if($browse:date != '') then 
        if($browse:date = 'BC dates') then 
            "/ancestor::tei:TEI/descendant::tei:body[descendant::*[(@syriaca-computed-start[starts-with(.,'-')] or @syriaca-computed-end[starts-with(.,'-')])]]"
        else
        concat("/ancestor::tei:TEI/descendant::tei:body[descendant::*[(
                @syriaca-computed-start >= 
                    '",browse:get-start-date(),"' 
                    and @syriaca-computed-end <= 
                    '",browse:get-end-date(),"'
                    ) or (
                    @syriaca-computed-start >= 
                    '",browse:get-start-date(),"' 
                    and @syriaca-computed-start <= 
                    '",browse:get-end-date(),"' and 
                    not(exists(@syriaca-computed-end)))]]") 
    else () 
};

(:~
 : Apply filters based on URL parameters
:)
declare function browse:filters($collection){
    if($collection = 'spear') then ()
    (:else if($browse:view = 'numeric') then ():)
    else if($browse:view = 'type') then browse:narrow-by-type($collection)   
    else if($browse:view = 'date') then browse:narrow-by-date()
            else if($browse:view = 'map' or $browse:view = 'all' or $browse:view = 'A-Z' or $browse:view = 'ܐ-ܬ' or $browse:view = 'ا-ي' or $browse:view = 'other') then ()
    else browse:lang-filter($collection)   
};

(:~
 : Add initial browse results function to be passed to display and refine functions
 : @param $collection collection name passed from html, should match data subdirectory name or tei series name
:)
declare function browse:get-all($node as node(), $model as map(*), $collection as xs:string?){
let $hits-main := util:eval(concat(browse:collection-path($collection),'//tei:div[@type="entry"]'))
(:let $hits := util:eval(concat("$hits-main",browse:filters($collection))):)
let $data := 
    if($browse:view = 'all') then
        for $hit in $hits-main/tei:head[1]
        let $num := xs:integer($hit/tei:ab[@type="idnos"]/tei:idno[@type="entry"])
        order by $num
        return $hit/ancestor::tei:div[@type='entry'][1]
    else 
        if($browse:view = 'facets') then
        let $path := concat('$hits-main/',facet:facet-filter(facet-defs:facet-definition($collection)))
        for $hit in util:eval($path)
        let $title := $hit/tei:head[1]
        order by global:build-sort-string(page:add-sort-options($title,$browse:sort-element),'')
        return $hit
    else  
        if($browse:computed-lang != '') then 
            for $hit in $hits-main[matches(substring(global:build-sort-string(tei:head[1],$browse:computed-lang),1,1),browse:get-sort(),'i')]
            let $title := global:build-sort-string($hit/tei:head[1],$browse:computed-lang)
            let $num := xs:integer($hit/tei:ab[@type="idnos"]/tei:idno[@type="entry"])
            order by $num
            return $hit
        else 
            for $hit in $hits-main
            let $title := global:build-sort-string($hit/tei:head[1],$browse:computed-lang)
            let $num := xs:integer($hit/tei:ab[@type="idnos"]/tei:idno[@type="entry"])
            order by $num
            return $hit
return map{"browse-data" := $data }
};

declare function browse:group-abc-entries($node as node(), $model as map(*)){
let $hits := util:eval(concat(browse:collection-path(''),'//tei:div[@type="entry"]'))
return
facet:html-list-facets-as-buttons(facet:count($hits, facet-defs:facet-definition('e-gedsh')/child::*))

};

(:~
 : Parse collection to match series name
 : @param $collection collection should match data subdirectory name or tei series name
:)
declare function browse:parse-collections($collection as xs:string?) {
    if($collection = ('persons','sbd')) then 'The Syriac Biographical Dictionary'
    else if($collection = ('saints','q')) then 'Qadishe: A Guide to the Syriac Saints'
    else if($collection = 'authors' ) then 'A Guide to Syriac Authors'
    else if($collection = 'bhse' ) then 'Bibliotheca Hagiographica Syriaca Electronica'
    else if($collection = ('places','The Syriac Gazetteer')) then 'The Syriac Gazetteer'
    else if($collection = ('spear','SPEAR: Syriac Persons, Events, and Relations')) then 'SPEAR: Syriac Persons, Events, and Relations'
    else if($collection != '' ) then $collection
    else ()
};         
                   
(: Formats end dates queries for searching :)
declare function browse:get-end-date(){
let $date := substring-after($browse:date,'-')
return 
    if($date = '0-100') then '0001-01-01'
    else if($date = '2000-') then '2100-01-01'
    else if(matches($date,'\d{4}')) then concat($date,'-01-01')
    else if(matches($date,'\d{3}')) then concat('0',$date,'-01-01')
    else if(matches($date,'\d{2}')) then concat('00',$date,'-01-01')
    else if(matches($date,'\d{1}')) then concat('000',$date,'-01-01')
    else '0100-01-01'
};

(: Formats end start queries for searching :)
declare function browse:get-start-date(){
let $date := substring-before($browse:date,'-')
return 
    if($date = '0-100') then '0001-01-01'
    else if($date = '2000-') then '2100-01-01'
    else if(matches($date,'\d{4}')) then concat($date,'-01-01')
    else if(matches($date,'\d{3}')) then concat('0',$date,'-01-01')
    else if(matches($date,'\d{2}')) then concat('00',$date,'-01-01')
    else if(matches($date,'\d{1}')) then concat('000',$date,'-01-01')
    else '0100-01-01'
};

(:~
 : Matches English letters and their equivalent letters as established by Syriaca.org
 : @param $browse:sort indicates letter for browse
 :)
declare function browse:get-sort(){
    if(exists($browse:sort) and $browse:sort != '') then
        if($browse:lang = 'ar') then
            browse:ar-sort()
        else
            if($browse:sort = 'A') then '(A|a|ẵ|Ẵ|ằ|Ằ|ā|Ā)'
            else if($browse:sort = 'D') then '(D|d|đ|Đ)'
            else if($browse:sort = 'S') then '(S|s|š|Š|ṣ|Ṣ)'
            else if($browse:sort = 'E') then '(E|e|ễ|Ễ)'
            else if($browse:sort = 'U') then '(U|u|ū|Ū)'
            else if($browse:sort = 'H') then '(H|h|ḥ|Ḥ)'
            else if($browse:sort = 'T') then '(T|t|ṭ|Ṭ)'
            else if($browse:sort = 'I') then '(I|i|ī|Ī)'
            else if($browse:sort = 'O') then '(O|Ō|o|Œ|œ)'
            else $browse:sort
    else '(A|a|ẵ|Ẵ|ằ|Ằ|ā|Ā)'
};

declare function browse:ar-sort(){
    if($browse:sort = 'ٱ') then '(ٱ|ا|آ|أ|إ)'
        else if($browse:sort = 'ٮ') then '(ٮ|ب)'
        else if($browse:sort = 'ة') then '(ة|ت)'
        else if($browse:sort = 'ڡ') then '(ڡ|ف)'
        else if($browse:sort = 'ٯ') then '(ٯ|ق)'
        else if($browse:sort = 'ں') then '(ں|ن)'
        else if($browse:sort = 'ھ') then '(ھ|ه)'
        else if($browse:sort = 'ۈ') then '(ۈ|ۇ|ٷ|ؤ|و)'
        else if($browse:sort = 'ى') then '(ى|ئ|ي)'
        else $browse:sort
};

(:~
 : Display in html templates
:)
declare %templates:wrap function browse:pageination($node as node()*, $model as map(*), $collection as xs:string?, $sort-options as xs:string*){
   page:pages($model("browse-data"), $browse:start, $browse:perpage,'', $sort-options)
};

declare function browse:pages($hits, $collection as xs:string?, $sort-options as xs:string*){
 page:pages($hits, $browse:start, $browse:perpage,'', $sort-options)
};

(:
 : Set up browse page, select correct results function based on URI params
 : @param $collection passed from html 
:)
declare function browse:results-panel($node as node(), $model as map(*), $collection, $sort-options as xs:string*){
let $hits := $model("browse-data")
return
 if($browse:view = 'type' or $browse:view = 'date' or $browse:view = 'facets') then
    (<div class="col-md-4">
        {if($browse:view='type') then 
            browse:browse-type($collection) 
         else if($browse:view = 'facets') then 
            facet:html-list-facets-as-buttons(facet:count($hits, facet-defs:facet-definition($collection)/child::*))
         else browse:browse-date()}
     </div>,
     <div class="col-md-8">{
        if($browse:view='type') then
            if($browse:type != '') then
                (
                browse:pages($hits, $collection, ''),
                <h3>{concat(upper-case(substring($browse:type,1,1)),substring($browse:type,2))}</h3>,
                <div>
                    {(
                        browse:get-map($hits),
                        browse:display-hits($hits)
                        )}
                </div>)
            else <h3>Select Type</h3>    
        else if($browse:view='date') then 
            if($browse:date !='') then 
                (browse:pages($hits, $collection, $sort-options),
                <h3>{$browse:date}</h3>,
                 <div>{browse:display-hits($hits)}</div>)
            else <h3>Select Date</h3>  
        else (
                browse:pages($hits, $collection, ''),
                
                <h3>Results {concat(upper-case(substring($browse:type,1,1)),substring($browse:type,2))} ({count($hits)})</h3>,
                <div>
                    {(
                        browse:get-map($hits),
                        browse:display-hits($hits)
                        )}
                </div>)
        }</div>)
else if($browse:view = 'map') then 
    <div class="col-md-12 map-lg">
        {geo:build-map($hits//tei:geo, '', '')}
    </div>
else if($browse:view = 'all' or $browse:view = 'ܐ-ܬ' or $browse:view = 'ا-ي' or $browse:view = 'other') then 
    <div class="col-md-12">
        <div>{browse:pages($hits, $collection, $sort-options)}</div>
        <div>{browse:display-hits($hits)}</div>
    </div>
else 
    <div class="col-md-12">
        {(
        if(($browse:lang = 'syr') or ($browse:lang = 'ar')) then (attribute dir {"rtl"}) else(),
        <div class="float-container">
            <div class="{if(($browse:lang = 'syr') or ($browse:lang = 'ar')) then "pull-left" else "pull-right"}">
                 <div>{browse:pages($hits, $collection, $sort-options)}</div>
            </div>
            {browse:browse-abc-menu()}
        </div>,
        <h3>{(
            if(($browse:lang = 'syr') or ($browse:lang = 'ar')) then 
                (attribute dir {"rtl"}, attribute lang {"syr"}, attribute class {"label pull-right"}) 
            else attribute class {"label"},
                if($browse:sort != '') then $browse:sort else 'A')}</h3>,
        <div class="{if($browse:lang = 'syr' or $browse:lang = 'ar') then 'syr-list' else 'en-list'}">
            <div class="row">
                <div class="col-sm-12">
                {if(($browse:lang = 'syr') or ($browse:lang = 'ar')) then (attribute dir {"rtl"}) else()}
                {browse:display-hits($hits)}</div>
            </div>
        </div>
        )}
    </div>
};

declare function browse:display-hits($hits){
    for $data in subsequence($hits, $browse:start,$browse:perpage)
    return (:global:display-recs-short-view($data, $browse:computed-lang):)
    <div class="results-list">
       <span class="sort-title">
            <a href="entry.html?id={$data/descendant::tei:idno[@type='URI'][1]}">{$data/tei:head}</a>
            <span class="type">{$data/tei:ab[@type='infobox']}</span>
        </span>
        <span class="results-list-desc uri">
            <span class="srp-label">URI: </span>
            <a href="entry.html?id={$data/descendant::tei:idno[@type='URI'][1]}">{$data/descendant::tei:idno[@type='URI'][1]}</a>
        </span>
    </div>
};

(: Display map :)
declare function browse:get-map($hits){
if($hits//tei:geo) then 
    <div class="col-md-12 map-md">
        {geo:build-map($hits//tei:geo, '', '')}
    </div>
else ()    
};

(:~
 : Browse Alphabetical Menus
:)
declare function browse:browse-abc-menu(){
    <div class="browse-alpha tabbable">
        <ul class="list-inline">
        {
            if(($browse:lang = 'syr')) then  
                for $letter in tokenize('ܐ ܒ ܓ ܕ ܗ ܘ ܙ ܚ ܛ ܝ ܟ ܠ ܡ ܢ ܣ ܥ ܦ ܩ ܪ ܫ ܬ', ' ')
                return 
                    <li class="syr-menu" lang="syr"><a href="?lang={$browse:lang}&amp;sort={$letter}">{$letter}</a></li>
            else if(($browse:lang = 'ar')) then  
                for $letter in tokenize('ا ب ت ث ج ح  خ  د  ذ  ر  ز  س  ش  ص  ض  ط  ظ  ع  غ  ف  ق  ك ل م ن ه  و ي', ' ')
                return 
                    <li class="ar-menu" lang="ar"><a href="?lang={$browse:lang}&amp;sort={$letter}">{$letter}</a></li>
            else if($browse:lang = 'ru') then 
                for $letter in tokenize('А Б В Г Д Е Ё Ж З И Й К Л М Н О П Р С Т У Ф Х Ц Ч Ш Щ Ъ Ы Ь Э Ю Я',' ')
                return 
                <li><a href="?lang={$browse:lang}&amp;sort={$letter}">{$letter}</a></li>
            else                
                for $letter in tokenize('A B C D E F G H I J K L M N O P Q R S T U V W X Y Z', ' ')
                return
                    <li><a href="?lang={$browse:lang}&amp;sort={$letter}">{$letter}</a></li>
        }
        </ul>
    </div>
};
(:~
 : Browse Type Menus
:)
declare function browse:browse-type($collection){  
    <ul class="nav nav-tabs nav-stacked">
        {
            if($collection = ('places','geo')) then 
                    for $types in collection($global:data-root || '/places/tei')//tei:place
                    group by $place-types := $types/@type
                    order by $place-types ascending
                    return
                        <li> {if($browse:type = replace(string($place-types),'#','')) then attribute class {'active'} else '' }
                            <a href="?view=type&amp;type={$place-types}">
                            {if(string($place-types) = '') then 'unknown' else replace(string($place-types),'#|-',' ')}  <span class="count"> ({count($types)})</span>
                            </a> 
                        </li>
            else      
                   let $persons := collection($global:data-root || '/persons/tei')//tei:person
                   let $unknown := count($persons[ancestor::tei:TEI[not(descendant::tei:title[@level='m'] = 'A Guide to Syriac Authors') and not(descendant::tei:title[@level='m'] = 'Qadishe: A Guide to the Syriac Saints')]])
                   let $author := count($persons[ancestor::tei:TEI/descendant::tei:title[@level='m'][. = 'A Guide to Syriac Authors']])
                   let $saint := count($persons[ancestor::tei:TEI/descendant::tei:title[@level='m'][. = 'Qadishe: A Guide to the Syriac Saints']])
                   return 
                         (<li>{if($browse:type = 'authors') then attribute class {'active'} else '' }
                             <a href="?view=type&amp;type=authors">
                                Authors <span class="count"> ({$author})</span>
                             </a>
                         </li>,
                        <li>{if($browse:type = 'saints') then attribute class {'active'} else '' }
                             <a href="?view=type&amp;type=saints">
                                Saints <span class="count"> ({$saint})</span>
                             </a>
                         </li>
                         (:,
                         <li>{if($browse:type = 'unknown') then attribute class {'active'} else '' }
                             <a href="?view=type&amp;type=unknown">
                                Unknown <span class="count"> ({$unknown})</span>
                             </a>
                         </li>:))
        }
    </ul>

};

(:
 : Browse by date
 : Precomputed values
 : NOTE: would be nice to use facets, however, it is currently inefficient 
:)
declare function browse:browse-date(){
    <ul class="nav nav-tabs nav-stacked pull-left type-nav">
        {   
            let $all-dates := 'BC dates, 0-100, 100-200, 200-300, 300-400, 400-500, 500-600, 700-800, 800-900, 900-1000, 1100-1200, 1200-1300, 1300-1400, 1400-1500, 1500-1600, 1600-1700, 1700-1800, 1800-1900, 1900-2000, 2000-'
            for $date in tokenize($all-dates,', ')
            return
                    <li>{if($browse:date = $date) then attribute class {'active'} else '' }
                        <a href="?view=date&amp;date={$date}">
                            {$date}  <!--<span class="count"> ({count($types)})</span>-->
                        </a>
                    </li>
            }
    </ul>
};

(:
 : Build Tabs dynamically.
 : @param $text tab text, from template
 : @param $param tab parameter passed to url from template
 : @param $value value of tab parameter passed to url from template
 : @param $sort-value for abc menus. 
:)
declare function browse:tabs($node as node(), $model as map(*), $text as xs:string?, $param as xs:string?, $value as xs:string?, $sort-value as xs:string?){
let $s := if($sort-value != '') then $sort-value else if($browse:sort != '') then $browse:sort else 'A'
return
    <li xmlns="http://www.w3.org/1999/xhtml" test="{$value}">{
        if($value = 'en' and not(exists(request:get-parameter-names()))) then attribute class {'active'} 
        else if($value = $browse:view) then attribute class {'active'}
        else if($value = $browse:lang) then attribute class {'active'}
        else ()
        }
        <a href="browse.html?{$param}={$value}{if($param = 'lang') then concat('&amp;sort=',$s) else ()}">
        {if($value = 'syr' or $value = 'ar') then (attribute lang {$value},attribute dir {'ltr'}) else ()}
        {$text}
        </a>
    </li> 
};

