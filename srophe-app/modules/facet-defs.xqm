(:~    
 : Builds Facet definitions for each submodule. 
 :)
xquery version "3.0";

module namespace facet-defs="http://syriaca.org/facet-defs";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace app="http://syriaca.org/templates" at "app.xql";
declare namespace tei="http://www.tei-c.org/ns/1.0";


declare function facet-defs:facet-definition($collection){
if($collection = 'e-gedsh') then
<facets xmlns="http://expath.org/ns/facet">
    <facet-definition name="Browse">
        <facet-definition name="Front Matter">
            <group-by function="facet:group-front-back">
                <sub-path>descendant::tei:idno[@type="front"]/@type</sub-path>
            </group-by>
        </facet-definition>
        <facet-definition name="ABC">
            <group-by function="facet:group-by-abc">
                <sub-path>self::tei:div[@type="entry" or @type="crossreference"]/tei:head[1]</sub-path>
            </group-by>
        </facet-definition>
        <facet-definition name="Back Matter">
            <group-by function="facet:group-front-back">
                <sub-path>descendant::tei:idno[@type="back"]/@type</sub-path>
            </group-by>
        </facet-definition>
        <max-values show="50">50</max-values>
        <order-by direction="descending">order</order-by>
    </facet-definition>     
</facets> 
else ()
};