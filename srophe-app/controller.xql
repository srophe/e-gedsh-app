xquery version "3.0";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;
(:
<div>
    <p>$exist:path: {$exist:path}</p>
    <p>$exist:resource: {$exist:resource}</p>
    <p>$exist:controller: {$exist:controller}</p>
    <p>$exist:prefix: {$exist:prefix}</p>
    <p>$exist:root: {$exist:root}</p>
</div>
:)

if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{concat($exist:controller, 'index.html')}" absolute="yes"/>
    </dispatch>
else if ($exist:resource eq '') then 
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>   
else if (ends-with($exist:path,"/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>
(: Resource paths starting with $app-root are resolved relative to app :)
else if (contains($exist:path, "/$app-root/")) then
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{concat($exist:controller,'/', substring-after($exist:path, '/$app-root/'))}">
                <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
            </forward>
        </dispatch>        
(: Resource paths starting with $shared are loaded from the shared-resources app :)
else if (contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>    

(: Checks for any record uri patterns as defined in repo.xml :)    
else if(contains($exist:path,"/entry/") or ends-with($exist:path, ("/atom","/tei","/rdf","/ttl",'.tei','.atom','.rdf','.ttl'))) then
    (: Sends to restxql to handle /atom, /tei,/rdf:)
    if (ends-with($exist:path, ("/atom","/tei","/rdf","/ttl",'.tei','.atom','.rdf','.ttl'))) then
        let $path := 
            if(ends-with($exist:path, (".atom",".tei",".rdf",".ttl"))) then 
                replace($exist:path, "\.(atom|tei|rdf|ttl)", "/$1")
            else $exist:path
        return 
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <forward url="{concat('/restxq/e-gedsh', $path)}" absolute="yes"/>
            </dispatch>
    (: Special handling for collections with app-root that matches record-URI-pattern sends html pages to html, others are assumed to be records :)
    else if($exist:resource = ('index.html','search.html','browse.html','about.html')) then 
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
           <view>
               <forward url="{$exist:controller}/modules/view.xql"/>
           </view>
   		<error-handler>
   			<forward url="{$exist:controller}/error-page.html" method="get"/>
   			<forward url="{$exist:controller}/modules/view.xql"/>
   		</error-handler>
       </dispatch>
    (: parses out record id to be passed to correct collection view, based on values in repo.xml :)       
    else if($exist:resource = '') then 
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <redirect url="index.html"/>
        </dispatch>
    else 
       let $id := 
        if(matches($exist:resource,"\*.html")) then substring-before($exist:resource,'.html')
        else $exist:resource
        let $html-path := '/entry.html'
        return 
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="{$exist:controller}{$html-path}"></forward>
                <view>
                    <forward url="{$exist:controller}/modules/view.xql">
                         <add-parameter name="id" value="{concat('http://gedsh.bethmardutho.org/',$id)}"/>
                    </forward>
                </view>
                <error-handler>
                    <forward url="{$exist:controller}/error-page.html" method="get"/>
                    <forward url="{$exist:controller}/modules/view.xql"/>
                </error-handler>
         </dispatch> 
else if (contains($exist:path,'/api/')) then
  if (ends-with($exist:path,"/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="/api-documentation/index.html"/>
    </dispatch> 
   else if($exist:resource = 'index.html') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="/api-documentation/index.html"/>
    </dispatch>
    else if($exist:resource = 'oai') then
     <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{replace($exist:path,'/api/oai','/e-gedsh/modules/oai.xql')}"/>
     </dispatch>
    else
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{concat('/restxq/e-gedsh', $exist:path)}" absolute="yes"/>
    </dispatch>
else if (ends-with($exist:path, "/atom") or ends-with($exist:path, "/tei")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{concat('/restxq/e-gedsh', $exist:path)}" absolute="yes"/>
    </dispatch>
else if (ends-with($exist:resource, ".html")) then
    (: the html page is run through view.xql to expand templates :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="{$exist:controller}/modules/view.xql"/>
        </view>
		<error-handler>
			<forward url="{$exist:controller}/error-page.html" method="get"/>
			<forward url="{$exist:controller}/modules/view.xql"/>
		</error-handler>
    </dispatch>
(: Redirects paths with directory, and no trailing slash to index.html in that directory :)    
else if (matches($exist:resource, "^([^.]+)$")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{concat($exist:path,'/index.html')}"/>
    </dispatch>         
else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>