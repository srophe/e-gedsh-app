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
        <group-by function="facet:group-by-abc">
            <sub-path>tei:head[1]</sub-path>
        </group-by>
        <max-values show="2000">200</max-values>
        <order-by direction="descending">value</order-by>
    </facet-definition> 
</facets> 
else ()
};