xquery version "3.1";
(:~      
 : Main application module for Srophe software. 
 : Output TEI to HTML via eXist-db templating system. 
 : Add your own custom modules at the end of the file. 
:)
module namespace app="http://srophe.org/srophe/templates";

(:eXist templating module:)
import module namespace templates="http://exist-db.org/xquery/templates" ;

(: Import Srophe application modules. :)
import module namespace config="http://srophe.org/srophe/config" at "config.xqm";
import module namespace data="http://srophe.org/srophe/data" at "lib/data.xqm";
import module namespace facet="http://expath.org/ns/facet" at "lib/facet.xqm";
import module namespace global="http://srophe.org/srophe/global" at "lib/global.xqm";
import module namespace maps="http://srophe.org/srophe/maps" at "lib/maps.xqm";
import module namespace page="http://srophe.org/srophe/page" at "lib/paging.xqm";
import module namespace rel="http://srophe.org/srophe/related" at "lib/get-related.xqm";
import module namespace teiDocs="http://srophe.org/srophe/teiDocs" at "teiDocs/teiDocs.xqm";
import module namespace tei2html="http://srophe.org/srophe/tei2html" at "content-negotiation/tei2html.xqm";
import module namespace d3xquery="http://srophe.org/srophe/d3xquery" at "../d3xquery/d3xquery.xqm";

(: Namespaces :)
declare namespace srophe="https://srophe.app";
declare namespace http="http://expath.org/ns/http-client";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace tan="tag:textalign.net,2015:ns";
declare namespace html="http://www.w3.org/1999/xhtml";

(: Global Variables:)
declare variable $app:start {request:get-parameter('start', 1) cast as xs:integer};
declare variable $app:perpage {request:get-parameter('perpage', 25) cast as xs:integer};

(:~
 : Get app logo. Value passed from repo-config.xml  
:)
declare
    %templates:wrap
function app:logo($node as node(), $model as map(*)) {
    if($config:get-config//repo:logo != '') then
        <img class="app-logo" src="{$config:nav-base || '/resources/images/' || $config:get-config//repo:logo/text() }" title="{$config:app-title}"/>
    else ()
};

(:~
 : Select page view, record or html content
 : If no record is found redirect to 404
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
declare function app:get-work($node as node(), $model as map(*)) {
    if(request:get-parameter('id', '') != '' or request:get-parameter('doc', '') != '') then
        let $rec := data:get-document()
        return 
            if(empty($rec)) then 
                ('No record found. ',xmldb:encode-uri($config:data-root || "/" || request:get-parameter('doc', '') || '.xml'))
                (: Debugging ('No record found. ',xmldb:encode-uri($config:data-root || "/" || request:get-parameter('doc', '') || '.xml')):)
               (:response:redirect-to(xs:anyURI(concat($config:nav-base, '/404.html'))):)
            else map {"hits" : $rec }
    else map {"hits" : 'Output plain HTML page'}
};

(:~
 : Dynamically build html title based on TEI record and/or sub-module. 
 : @param request:get-parameter('id', '') if id is present find TEI title, otherwise use title of sub-module
:)
declare %templates:wrap function app:record-title($node as node(), $model as map(*), $collection as xs:string?){
    let $data := $model("hits")
    return 
        if(request:get-parameter('id', '')) then
           if(contains($data/descendant::tei:titleStmt[1]/tei:title[1]/text(),' — ')) then
                substring-before($data/descendant::tei:titleStmt[1]/tei:title[1],' — ')
           else $data/descendant::tei:titleStmt[1]/tei:title[1]/text()
        else if($collection != '') then
            string(config:collection-vars($collection)/@title)
        else $config:app-title
};  

(:~ 
 : Add header links for alternative formats.
 : Add additional metadata tags here 
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
    <meta name="DC.title " property="dc.title " content="{$model("hits")/ancestor::tei:TEI/descendant::tei:title[1]/text()}"/>,
    if($model("hits")/ancestor::tei:TEI/descendant::tei:desc or $model("hits")/ancestor::tei:TEI/descendant::tei:note[@type="abstract"]) then 
        <meta name="DC.description " property="dc.description " content="{$model("hits")/ancestor::tei:TEI/descendant::tei:desc[1]/text() | $model("hits")/ancestor::tei:TEI/descendant::tei:note[@type="abstract"]}"/>
    else (),
    <link xmlns="http://www.w3.org/1999/xhtml" type="text/html" href="{request:get-parameter('id', '')}.html" rel="alternate"/>,
    <link xmlns="http://www.w3.org/1999/xhtml" type="text/xml" href="{request:get-parameter('id', '')}/tei" rel="alternate"/>,
    <link xmlns="http://www.w3.org/1999/xhtml" type="application/atom+xml" href="{request:get-parameter('id', '')}/atom" rel="alternate"/>
    )
    else ()
};

(:~ 
 : Adds google analytics from repo-config.xml
 : @param $node
 : @param $model 
:)
declare  
    %templates:wrap 
function app:google-analytics($node as node(), $model as map(*)){
  $config:get-config//google_analytics/text()
};

(:~  
 : Display any TEI nodes passed to the function via the paths parameter
 : Used by templating module, defaults to tei:body if no nodes are passed. 
 : @param $paths comma separated list of xpaths for display. Passed from html page  
:)
declare function app:display-nodes($node as node(), $model as map(*), $paths as xs:string?, $collection as xs:string?){
    let $record := $model("hits")
    let $nodes := if($paths != '') then 
                    for $p in $paths
                    return util:eval(concat('$record/',$p))
                  else $record/descendant::tei:text
    return 
        if($config:get-config//repo:html-render/@type='xslt') then
            global:tei2html($nodes, $collection)
        else tei2html:tei2html($nodes)
}; 

(:~  
 : Default title display, used if no sub-module title function.
 : Used by templating module, not needed if full record is being displayed 
:)
declare function app:h1($node as node(), $model as map(*)){
 global:tei2html(
 <srophe-title xmlns="http://www.tei-c.org/ns/1.0">{(
    if($model("hits")/descendant::*[@syriaca-tags='#syriaca-headword']) then
        $model("hits")/descendant::*[@syriaca-tags='#syriaca-headword']
    else $model("hits")/descendant::tei:titleStmt[1]/tei:title[1], 
    $model("hits")/descendant::tei:publicationStmt/tei:idno[@type="URI"][1]
    )}
 </srophe-title>)
}; 
(:
declare function app:h1($node as node(), $model as map(*)){
    let $title := tei2html:tei2html($model("hits")/descendant::tei:titleStmt/tei:title[1])
    let $author := tei2html:tei2html($model("hits")/descendant::tei:titleStmt/tei:author[not(@role='anonymous')])
    return 
        <div class="title">
            <h1>{(if($author != '') then ($author, ': ') else (), $title)}</h1>
        </div>
};
:)

(:~ 
 : Data formats and sharing
 : to replace app-link
 :)
declare %templates:wrap function app:other-data-formats($node as node(), $model as map(*), $formats as xs:string?){
let $id := (:replace($model("hits")/descendant::tei:idno[contains(., $config:base-uri)][1],'/tei',''):)request:get-parameter('id', '')
return 
    if($formats) then
        <div class="indent" style="width:100%;clear:both;margin-bottom:1em; text-align:right;">
            {
                for $f in tokenize($formats,',')
                return 
                    if($f = 'geojson') then
                        if($model("hits")/descendant::tei:location/tei:geo) then 
                            (<a href="{concat(replace($id,$config:base-uri,$config:nav-base),'.geojson')}" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the GeoJSON data for this record." >
                                 <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> GeoJSON
                            </a>, '&#160;')
                        else()
                    else if($f = 'json') then 
                        (<a href="{concat(replace($id,$config:base-uri,$config:nav-base),'.json')}" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the GeoJSON data for this record." >
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> JSON-LD
                        </a>, '&#160;') 
                    else if($f = 'kml') then
                        if($model("hits")/descendant::tei:location/tei:geo) then
                            (<a href="{concat(replace($id,$config:base-uri,$config:nav-base),'.kml')}" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the KML data for this record." >
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> KML
                            </a>, '&#160;')
                         else()   
                    else if($f = 'print') then                        
                        (<a href="javascript:window.print();" type="button" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to send this page to the printer." >
                             <span class="glyphicon glyphicon-print" aria-hidden="true"></span>
                        </a>, '&#160;')   
                    else if($f = 'rdf') then
                        (<a href="{concat(replace($id,$config:base-uri,$config:nav-base),'.rdf')}" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the RDF-XML data for this record." >
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> RDF/XML
                        </a>, '&#160;')
                    else if($f = 'tei') then
                        (<a href="{concat(replace($id,$config:base-uri,$config:nav-base),'.tei')}" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the TEI XML data for this record." >
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> TEI/XML
                        </a>, '&#160;')
                    else if($f = 'text') then
                        (<a href="{concat(replace($id,$config:base-uri,$config:nav-base),'.txt')}" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the plain text data for this record." >
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> Text
                        </a>, '&#160;')                        
                    else if($f = 'ttl') then
                        (<a href="{concat(replace($id,$config:base-uri,$config:nav-base),'.ttl')}" class="btn btn-default btn-xs" id="teiBtn" data-toggle="tooltip" title="Click to view the RDF-Turtle data for this record." >
                             <span class="glyphicon glyphicon-download-alt" aria-hidden="true"></span> RDF/TTL
                        </a>, '&#160;')
                   else () 
            }
            <br/>
        </div>
    else ()
};

(:~  
 : Record status to be displayed in HTML sidebar 
 : Data from tei:teiHeader/tei:revisionDesc/@status
:)
declare %templates:wrap  function app:rec-status($node as node(), $model as map(*), $collection as xs:string?){
let $status := string($model("hits")/descendant::tei:revisionDesc/@status)
return
    if($status = 'published' or $status = '') then ()
    else <span class="rec-status {$status} btn btn-info">Status: {$status}</span>
};

(:~
 : Display paging functions in html templates
 : Used by browse and search pages. 
:)
declare %templates:wrap function app:pageination($node as node()*, $model as map(*), $collection as xs:string?, $sort-options as xs:string*, $search-string as xs:string?){
   page:pages($model("hits"), $collection, $app:start, $app:perpage,$search-string, $sort-options)
};

(:~
 : Builds list of related records based on tei:relation  
:)                   
declare function app:internal-relationships($node as node(), $model as map(*), $relationship-type as xs:string?, $display as xs:string?, $map as xs:string?){
    if($model("hits")//tei:relation) then 
        rel:build-relationships($model("hits")//tei:relation,request:get-parameter('id', ''), $relationship-type, $display, $map)
    else ()
};

(:~      
 : Builds list of external relations, list of records which refernece this record.
 : Used by NHSL for displaying child works
 : @param $relType name/ref of relation to be displayed in HTML page
:)                   
declare function app:external-relationships($node as node(), $model as map(*), $relationship-type as xs:string?, $sort as xs:string?, $count as xs:string?){
    let $rec := $model("hits")
    let $recid := replace($rec/descendant::tei:idno[@type='URI'][starts-with(.,$config:base-uri)][1],'/tei','')
    let $title := if(contains($rec/descendant::tei:title[1]/text(),' — ')) then 
                        substring-before($rec/descendant::tei:title[1],' — ') 
                   else $rec/descendant::tei:title[1]/text()
    return rel:external-relationships($recid, $title, $relationship-type, $sort, $count)
};

(:~
 : Passes any tei:geo coordinates in results set to map function. 
 : Suppress map if no coords are found. 
:)                   
declare function app:display-related-places-map($relationships as item()*){
    if(contains($relationships,'/place/')) then
        let $places := for $place in tokenize($relationships,' ')
                       return data:get-document($place)
        return maps:build-map($places,count($places//tei:geo))
    else ()
};

(:~
 : Passes any tei:geo coordinates in results set to map function. 
 : Suppress map if no coords are found. 
:)                   
declare function app:display-map($node as node(), $model as map(*)){
    if($model("hits")//tei:geo) then 
        maps:build-map($model("hits"),count($model("hits")//tei:geo))
    else ()
};

(:~
 : Display Dates using timelinejs
 :)                 
declare function app:display-timeline($node as node(), $model as map(*)){
    if($model("hits")/descendant::tei:body/descendant::*[@when or @notBefore or @notAfter]) then
        <div>Timeline</div>
     else ()
};

(:~
 : Configure dropdown menu for keyboard layouts for input boxes
 : Options are defined in repo-config.xml
 : @param $input-id input id used by javascript to select correct keyboard layout.  
 :)
declare %templates:wrap function app:keyboard-select-menu($node as node(), $model as map(*), $input-id as xs:string){
    global:keyboard-select-menu($input-id)    
};

(:
 : Display facets from HTML page 
 : @param $collection passed from html 
 : @param $facets relative (from collection root) path to facet-config file if different from facet-config.xml
:)
declare function app:display-facets($node as node(), $model as map(*), $collection as xs:string?){
    let $hits := $model("hits")
    let $facet-config := global:facet-definition-file($collection)
    return 
        if(not(empty($facet-config))) then 
            facet:html-list-facets-as-buttons(facet:count($hits, $facet-config/descendant::facet:facet-definition))
        else ()
};

(:~
 : Generic contact form can be added to any page by calling:
 : <div data-template="app:contact-form"/>
 : with a link to open it that looks like this: 
 : <button class="btn btn-default" data-toggle="modal" data-target="#feedback">CLink text</button>&#160;
:)
declare %templates:wrap function app:contact-form($node as node(), $model as map(*), $collection) {
   <div class="modal fade" id="feedback" tabindex="-1" role="dialog" aria-labelledby="feedbackLabel" aria-hidden="true" xmlns="http://www.w3.org/1999/xhtml">
       <div class="modal-dialog">
           <div class="modal-content">
           <div class="modal-header">
               <button type="button" class="close" data-dismiss="modal"><span aria-hidden="true">x</span><span class="sr-only">Close</span></button>
               <h2 class="modal-title" id="feedbackLabel">Corrections/Additions?</h2>
           </div>
           <form action="{$config:nav-base}/modules/email.xql" method="post" id="email" role="form">
               <div class="modal-body" id="modal-body">
                   <!-- More information about submitting data from howtoadd.html -->
                   <p><strong>Notify the editors of a mistake:</strong>
                   <a class="btn btn-link togglelink" data-toggle="collapse" data-target="#viewdetails" data-text-swap="hide information">more information...</a>
                   </p>
                   <div class="collapse" id="viewdetails">
                       <p>Using the following form, please inform us which page URI the mistake is on, where on the page the mistake occurs,
                       the content of the correction, and a citation for the correct information (except in the case of obvious corrections, such as misspelled words). 
                       Please also include your email address, so that we can follow up with you regarding 
                       anything which is unclear. We will publish your name, but not your contact information as the author of the  correction.</p>
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
                   <input class="input url" id="url" placeholder="url" required="required" style="display:none;"/>
                   <!-- start reCaptcha API-->
                   {if($config:recaptcha != '') then                                
                       <div class="g-recaptcha" data-sitekey="{$config:recaptcha}"></div>                
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
 : Select page view, record or html content
 : If no record is found redirect to 404
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)
declare function app:get-wiki($node as node(), $model as map(*), $wiki-uri as xs:string?) {
    let $wiki-uri := 
        if(request:get-parameter('wiki-uri', '')) then 
            request:get-parameter('wiki-uri', '')
        else if($wiki-uri != '') then 
                    $wiki-uri
        else 'https://github.com/srophe/srophe/wiki'            
    let $uri := 
        if(request:get-parameter('wiki-page', '')) then 
            concat($wiki-uri, request:get-parameter('wiki-page', ''))
        else $wiki-uri
    let $wiki-data := app:wiki-rest-request($uri)
    return map {"hits" : $wiki-data}
};

(:~
 : Pulls github wiki data into Syriaca.org documentation pages. 
 : @param $wiki-uri pulls content from specified wiki or wiki page. 
:)
declare function app:wiki-rest-request($wiki-uri as xs:string?){
    http:send-request(
            <http:request href="{xs:anyURI($wiki-uri)}" method="get">
                <http:header name="Connection" value="close"/>
            </http:request>)[2]//html:div[@class = 'repository-content']            
};

(:~
 : Pulls github wiki data H1.  
:)
declare function app:wiki-page-title($node, $model){
    let $content := $model("hits")//html:div[@id='wiki-body']
    return $content/descendant::html:h1[1]
};
(:~
 : Pulls github wiki content.  
:)
declare function app:wiki-page-content($node, $model){
    let $wiki-data := $model("hits")
    return 
        app:wiki-data($wiki-data//html:div[@id='wiki-body']) 
};

(:~
 : Typeswitch to processes wiki anchors links for use with Syriaca.org documentation pages. 
 : @param $wiki pulls content from specified wiki or wiki page. 
:)
declare function app:wiki-data($nodes as node()*) {
    for $node in $nodes
    return 
        typeswitch($node)
            case element() return
                element { node-name($node) } {
                    if($node/@id) then attribute id { replace($node/@id,'user-content-','') } else (),
                    $node/@*[name()!='id'], app:wiki-data($node/node())
                }
            default return $node               
};

(:~
 : Pull github wiki data into Syriaca.org documentation pages. 
 : Grabs wiki menus to add to Syraica.org pages
 : @param $wiki pulls content from specified wiki or wiki page. 
:)
declare function app:wiki-menu($node, $model, $wiki-uri){
    let $wiki-data := app:wiki-rest-request($wiki-uri)
    let $menu := app:wiki-links($wiki-data//html:div[@id='wiki-rightbar']/descendant::html:ul, $wiki-uri)
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
                let $href := concat($config:nav-base, replace($node/@href, $wiki-path, "/documentation/wiki.html?wiki-page="),'&amp;wiki-uri=', $wiki)
                return
                    <a href="{$href}">
                        {$node/@* except $node/@href, $node/node()}
                    </a>
            case element() return
                element { node-name($node) } {
                    $node/@*, app:wiki-links($node/node(), $wiki)
                }
            default return $node               
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
                let $href := concat($config:nav-base, replace($node/@href, $wiki-path, "/documentation/wiki.html?wiki-page="),'&amp;wiki-uri=', $wiki)
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
 : Enables shared content with template expansion.  
 : Used for shared menus in navbar where relative links can be problematic 
 : @param $node
 : @param $model
 : @param $path path to html content file, relative to app root. 
:)
declare function app:shared-content($node as node(), $model as map(*), $path as xs:string){
    let $links := doc($config:app-root || $path)
    return templates:process(app:fix-links($links/node()), $model)
};

(:~
 : Call app:fix-links for HTML pages. 
:)
declare
    %templates:wrap
function app:fix-links($node as node(), $model as map(*)) {
    app:fix-links(templates:process($node/node(), $model))
};

(:~
 : Recurse through menu output absolute urls based on repo-config.xml values.
 : Addapted from https://github.com/eXistSolutions/hsg-shell 
 : @param $nodes html elements containing links with '$nav-base'
:)
declare %private function app:fix-links($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(html:a) return
                let $href := replace($node/@href, "\$nav-base", $config:nav-base)
                return
                    <a href="{$href}">
                        {$node/@* except $node/@href, $node/node()}
                    </a>
            case element(html:form) return
                let $action := replace($node/@action, "\$nav-base", $config:nav-base)
                return
                    <form action="{$action}">
                        {$node/@* except $node/@action, app:fix-links($node/node())}
                    </form>      
            case element() return
                element { node-name($node) } {
                    $node/@*, app:fix-links($node/node())
                }
            default return
                $node
};

(:~ 
 : Used by teiDocs
:)
declare %templates:wrap function app:set-data($node as node(), $model as map(*), $doc as xs:string){
    teiDocs:generate-docs($config:data-root || $doc)
};

(:~
 : Generic output documentation from xml
 : @param $doc as string
:)
declare %templates:wrap function app:build-documentation($node as node(), $model as map(*), $doc as xs:string?){
    let $doc := doc($config:app-root || '/documentation/' || $doc)//tei:encodingDesc
    return tei2html:tei2html($doc)
};

(:~   
 : get editors as distinct values
:)
declare function app:get-editors(){
distinct-values(
    (for $editors in collection($config:data-root || '/places/tei')//tei:respStmt/tei:name/@ref
     return substring-after($editors,'#'),
     for $editors-change in collection($config:data-root || '/places/tei')//tei:change/@who
     return substring-after($editors-change,'#'))
    )
};

(:~
 : Build editor list. Sort alphabeticaly
:)
declare %templates:wrap function app:build-editor-list($node as node(), $model as map(*)){
    let $editors := doc($config:app-root || '/documentation/editors.xml')//tei:listPerson
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
 : Adds google analytics from config.xml
 : @param $node
 : @param $model
 : @param $path path to html content file, relative to app root. 
:)
declare  
    %templates:wrap 
function app:google-analytics($node as node(), $model as map(*)){
   $config:get-config//google_analytics/text() 
};

(: Syriaca.org specific functions :)
(:~
 : Grabs latest news for Syriaca.org home page
 : http://syriaca.org/feed/
 :) 
declare %templates:wrap function app:get-feed($node as node(), $model as map(*)){
    try {
        let $feed := http:send-request(<http:request http-version="1.1" href="{xs:anyURI('http://syriaca.org/blog/feed/')}" method="get"/>)[2]
        return  if($feed != '') then 
                for $latest at $n in subsequence($feed//*:item, 1, 3)
                return 
                    <li>
                         <a href="{$latest/link/text()}">{$latest/*:title/text()}</a>
                    </li>
                else ()
       } catch * {
           <error>Caught error {$err:code}: {$err:description}</error>
    }     
};

(:~    
 : Special output for NHSL work records
:)
declare %templates:wrap function app:display-work($node as node(), $model as map(*)){
        <div class="row">
            <div class="col-md-8 column1">
                {
                    let $data := $model("hits")/descendant::tei:body/tei:bibl
                    let $infobox := 
                        <body xmlns="http://www.tei-c.org/ns/1.0">
                        <bibl>
                        {(
                            $data/@*,
                            $data/tei:title[not(@type=('initial-rubric','final-rubric'))],
                            $data/tei:author,
                            $data/tei:editor,
                            $data/tei:desc[@type='abstract' or starts-with(@xml:id, 'abstract-en')],
                            $data/tei:note[@type='abstract'],
                            $data/tei:date,
                            $data/tei:extent,
                            $data/tei:idno[starts-with(.,'http://syriaca.org')]
                         )}
                        </bibl>
                        </body>
                     let $allData := 
                     <body xmlns="http://www.tei-c.org/ns/1.0"><bibl>
                        {(
                            $data/@*,
                            $data/child::*
                            [not(self::tei:title[not(@type=('initial-rubric','final-rubric'))])]
                            [not(self::tei:author)]
                            [not(self::tei:editor)]
                            [not(self::tei:desc[@type='abstract' or starts-with(@xml:id, 'abstract-en')])]
                            [not(self::tei:note[@type='abstract'])]
                            [not(self::tei:date)]
                            [not(self::tei:extent)]
                            [not(self::tei:idno)])}
                        </bibl></body>
                     return 
                        (
                        app:work-toc($data),
                        global:tei2html($infobox),
                        app:external-relationships($node, $model,'dcterms:isPartOf','',''),
                        app:external-relationships($node, $model,'skos:broadMatch','',''),
                        app:external-relationships($node, $model,'syriaca:sometimesCirculatesWith','',''),
                        app:external-relationships($node, $model,'syriaca:part-of-tradition','',''),
                        global:tei2html($allData))  
                } 
            </div>
            <div class="col-md-4 column2">
                {(
                app:rec-status($node, $model,''),
                <div class="info-btns">  
                    <button class="btn btn-default" data-toggle="modal" data-target="#feedback">Corrections/Additions?</button>&#160;
                    <a href="#" class="btn btn-default" data-toggle="modal" data-target="#selection" data-ref="../documentation/faq.html" id="showSection">Is this record complete?</a>
                </div>,                
                if($model("hits")//tei:body/child::*/tei:listRelation) then 
                rel:build-relationships($model("hits")//tei:body/child::*/tei:listRelation,request:get-parameter('id', ''), (), 'list-description', 'false')
                else (),
                app:link-icons-list($node, $model)
                )}  
            </div>
        </div>
};

(:~    
 : Works TOC on bibl elements
:)
declare function app:work-toc($data){
let $data := $data/tei:bibl[@type != ('lawd:Citation','lawd:ConceptualWork')]
return global:tei2html(<work-toc xmlns="http://www.tei-c.org/ns/1.0" >{$data}</work-toc>)
};

(:~
 : bibl module relationships
:)                   
declare function app:subject-headings($node as node(), $model as map(*)){
    rel:subject-headings($model("hits")//tei:idno[@type='URI'][ends-with(.,'/tei')])
};

(:~
 : bibl module relationships
:)                   
declare function app:cited($node as node(), $model as map(*)){
    rel:cited($model("hits")//tei:idno[@type='URI'][ends-with(.,'/tei')], request:get-parameter('start', 1),request:get-parameter('perpage', 5))
};


(:~      
 : Return teiHeader info to be used in citation used for Syriaca.org bibl module
:)
declare %templates:wrap function app:about($node as node(), $model as map(*)){
    let $rec := $model("hits")
    let $header := 
        <srophe-about xmlns="http://www.tei-c.org/ns/1.0">
            {$rec//tei:teiHeader}
        </srophe-about>
    return global:tei2html($header)
};

(:~  
 : Display any TEI nodes passed to the function via the paths parameter
 : Used by templating module, defaults to tei:body if no nodes are passed. 
 : @param $paths comma separated list of xpaths for display. Passed from html page  
:)
declare function app:link-icons-list($node as node(), $model as map(*)){
let $data := $model("hits")//tei:body/descendant::tei:idno[not(contains(., $config:base-uri))]  
return 
    if(not(empty($data))) then 
        <div class="panel panel-default">
            <div class="panel-heading"><h3 class="panel-title">See Also </h3></div>
            <div class="panel-body">
                <ul>
                    {for $l in $data
                     return <li>{string($l/@type)}: {global:tei2html($l)}</li>
                    }
                </ul>
            </div>
        </div>
    else ()
}; 

(: Test image-map functions with IU-sample-alignment.xml:)
declare function app:page-view($node as node(), $model as map(*)){
<div class="row">
    {
    let $rec := doc('/db/apps/usaybia-data/data/texts/IU-sample-alignment.xml')
    return 
    <div class="record row">
        <div class="col-md-6">
        <!--
            <img src="/exist/apps/usaybia-data/IU-mueller-1884-vol2b-103.png" width="100%" usemap="#planetmap"/>
            <map name="planetmap">
              <area shape="poly" coords="342,77 342,2802 1700,2802 1700,77" alt="Sun" style="border:1px solid red;"/>
            </map>
            -->
            <script><![CDATA[
                $(function() {
                    $('.map').maphilight();
                });
            ]]></script>
            <!-- Image Map Generated by http://www.image-map.net/ -->

            <img src="/exist/apps/usaybia-data/IU-mueller-1884-vol2b-103.png" usemap="#image-map" class="map"/>
            
            <map name="image-map">
				<area coords="354,2502 420,2501 487,2499 554,2498 620,2497 687,2496 754,2496 820,2495 887,2495 954,2495 1021,2495 1087,2495 1154,2495 1221,2495 1287,2495 1354,2495 1421,2495 1487,2495 1554,2495 1621,2495 1688,2494 1688,2443 1621,2444 1554,2444 1487,2444 1421,2444 1354,2444 1287,2444 1221,2444 1154,2444 1087,2444 1021,2444 954,2444 887,2444 820,2444 754,2445 687,2445 620,2446 554,2447 487,2448 420,2450 354,2451" shape="poly" subtype="paragraph" xml:id="facs_103_line_1549019333137_21" style="display:inline-block;border:1x solid red;"/>
            </map>

            <!--
            <img src="https://cdn-images-1.medium.com/max/1600/0*H8odJZNPmo13lEJ2" usemap="#image-map" class="map"/>
            <map name="image-map">
                <area target="" alt="" title="" href="" coords="421,528,383,596,424,672,416,828,455,850,486,836,548,726,613,610,581,583,544,568,461,508" shape="poly"/>
            </map>
            -->
            
        </div>
        <div class="col-md-6">
                {''(:$rec//tei:text:)}
        </div>
    </div>
    }
</div>
};

(: Functions from the Syriac Corpus :)
(:~
 : TOC for Syriac Corpus records. 
:)  
declare function app:toc($node as node(), $model as map(*)){
let $toc := app:toc($model("hits")/descendant::tei:body/child::*)
return  
    <div class="panel toc-slide" id="menu">
		<header class="panel-header">
			<a href="#menu" class="menu-link btn btn-green btn-rounded pull-right" data-toggle="tooltip" title="Table of Contents"> x </a>
			<h2>Contents</h2>
		</header>
		<div class="panel-container">
			{$toc}
	   </div>
    </div>	  
}; 

(:~
 : Transform TOC for Syriac Corpus records. 
:)
declare function app:toc($nodes){
for $node in $nodes
return 
        typeswitch($node)
            case text() return normalize-space($node)
            case element(tei:div) return 
                if($node/@type='ch') then
                    if($node/tei:head) then 
                        app:toc($node/node())
                    else if($node/@n) then
                        <span class="toc-item">
                            <a href="#{string($node/@n)}" class="toc-item">{string($node/@n)}</a>
                            {app:toc($node/node())}
                        </span>
                    else app:toc($node/node())
                else if($node/@type='bio') then
                    if($node/tei:head) then 
                        app:toc($node/node())
                    else if($node/@n) then
                        <span class="toc-item">
                            <a href="#{string($node/@n)}" class="toc-item">{string($node/@n)}</a>
                            {app:toc($node/node())}
                        </span>
                    else app:toc($node/node())                    
                else app:toc($node/node())
            case element(tei:div1) return 
                app:toc($node/node())
            case element(tei:div2) return 
                <span class="toc div2">{app:toc($node/node())}</span>
            case element(tei:div3) return 
                <span class="toc div3">{app:toc($node/node())}</span>
            case element(tei:div4) return 
                <span class="toc div4">{app:toc($node/node())}</span>
            case element(tei:head) return 
                let $id := 
                    if($node/@xml:id) then string($node/@xml:id) 
                    else if($node/parent::*[1]/@n) then
                        concat('Head-id.',string-join($node/ancestor::*[@n]/@n,'.'))
                    else ()
                return 
                    if($id != '') then 
                        <span class="toc-item">
                            <a href="#{$id}" class="toc-item" bdi="bdi">{string($node/@n)} {string-join($node/descendant-or-self::text(),' ')}</a> 
                        </span>
                    else ()
            default return ()          
};

(:~
 : TOC for Syriac Corpus records. 
:)  
declare function app:toggle-text-display($node as node(), $model as map(*)){
if($model("hits")/descendant::tei:body/descendant::*[@n][not(@type='section') and not(@type='part')]) then     
        <div class="panel panel-default">
            <div class="panel-heading"><a href="#" data-toggle="collapse" data-target="#toggleText">Show  </a>
            <span class="glyphicon glyphicon-question-sign text-info moreInfo" aria-hidden="true" data-toggle="tooltip" 
            title="Toggle the text display to show line numbers, section numbers and other structural divisions"></span>
            <!--<a href="#" data-toggle="collapse" data-target="#showToc"><span id="tocIcon" class="glyphicon glyphicon-collapse-up"/></a>-->
            </div>
            <div class="panel-body collapse in" id="toggleText">
                {( 
                    let $types := distinct-values($model("hits")/descendant::tei:body/descendant::tei:div[@n]/@type)
                    for $type in $types
                    order by $type
                    return 
                        if($type = ('part','text','rubric','heading','title')) then ()
                        else
                            <div class="toggle-buttons">
                               <span class="toggle-label"> {$type} : </span>
                               <input class="toggleDisplay" type="checkbox" id="toggle{$type}" data-element="{concat('tei-',$type)}"/>
                                 {if($type = 'section') then attribute checked {"checked" } else ()}
                                 {if($type = 'chapter') then attribute checked {"checked" } else ()}
                                 <label for="toggle{$type}"> {$type}</label>
                            </div>,
                    if($model("hits")/descendant::tei:body/descendant::tei:ab[not(@type) and not(@subtype)][@n]) then 
                        <div class="toggle-buttons">
                            <span class="toggle-label"> ab : </span>
                            <input class="toggleDisplay" type="checkbox" id="toggleab" data-element="tei-ab"/>
                                <label for="toggleab">ab</label>
                         </div>
                    else (),   
                    if($model("hits")/descendant::tei:body/descendant::tei:ab[@type][@n]) then  
                        let $types := distinct-values($model("hits")/descendant::tei:body/descendant::tei:ab[@n]/@type)
                        for $type in $types
                        order by $type
                        return 
                            <div class="toggle-buttons">
                               <span class="toggle-label"> {$type} : </span>
                               <input class="toggleDisplay" type="checkbox" id="toggle{$type}" data-element="{concat('tei-',$type)}"/>
                                 {if($type = 'section') then attribute checked {"checked" } else ()}
                                 <label for="toggle{$type}"> {$type}</label>
                            </div>
                    else (),    
                    if($model("hits")/descendant::tei:body/descendant::tei:l) then 
                        <div class="toggle-buttons">
                            <span class="toggle-label"> line : </span>
                            <input class="toggleDisplay" type="checkbox" id="togglel" data-element="tei-l" checked="checked"/>
                                <label for="togglel">line</label>
                        </div>
                    else (),
                    if($model("hits")/descendant::tei:body/descendant::tei:lb) then 
                        <div class="toggle-buttons">
                            <span class="toggle-label"> line break : </span>
                            <input class="toggleDisplay" type="checkbox" id="togglelb" data-element="tei-lb"/>
                                <label for="togglelb">line break</label>
                        </div>
                    else (),                    
                    if($model("hits")/descendant::tei:body/descendant::tei:lg) then 
                        <div class="toggle-buttons">
                            <span class="toggle-label"> line group : </span>
                            <input class="toggleDisplay" type="checkbox" id="togglelg" data-element="tei-lg"/>
                                <label for="togglelg">line group</label>
                         </div>                        
                    else (),
                    if($model("hits")/descendant::tei:body/descendant::tei:pb) then
                        <div class="toggle-buttons">
                            <span class="toggle-label"> page break : </span>
                            <input class="toggleDisplay" type="checkbox" id="togglepb" data-element="tei-pb"/>
                                <label for="togglepb">page break</label>
                         </div>                                            
                    else (),
                    if($model("hits")/descendant::tei:body/descendant::tei:cb) then 
                        <div class="toggle-buttons">
                            <span class="toggle-label"> column break : </span>
                            <input class="toggleDisplay" type="checkbox" id="togglecb" data-element="tei-cb"/>
                                <label for="togglecb">column break</label>
                         </div>                         
                    else (),
                    if($model("hits")/descendant::tei:body/descendant::tei:milestone[not(@type) and not(@subtype) and not(@unit='SyrChapter')]) then 
                        <div class="toggle-buttons">
                            <span class="toggle-label"> milestone : </span>
                            <input class="toggleDisplay" type="checkbox" id="togglemilestone" data-element="tei-milestone"/>
                                <label for="togglemilestone">milestone</label>
                         </div>                                                 
                    else (),
                    if($model("hits")/descendant::tei:body/descendant::tei:note[@place = ('foot','footer','footnote')]) then 
                        <div class="toggle-buttons">
                            <span class="toggle-label"> footnote : </span>
                            <input class="toggleDisplay" type="checkbox" id="togglemilestone" data-element="tei-footnote" checked="checked"/>
                                <label for="togglemilestone">footnote</label>
                         </div>                                                 
                    else () 
                )}
            </div>
        </div>
else ()
}; 

(: paging function :)
(: Note: There may be a problem if there are multiple types of pb elements (refereing to different editions. how to know which to use to page? ):)
(: Need to make paging more robust so we can page on differnt attibutes and elements :)
(:~
 : Display manuscript texts
 : Allow mulit column view and paging of texts
 : @param $node 
 : @param $model
 : @param $milestone - how to 'chunk' text. Accepted values page, chapter, milestone
 : @param $type - Text type. Accepted values: source, translation
 : @param $col - column number. Not used yet, maybe unnecessary. 
:)
declare function app:display-page-text($node as node(), $model as map(*), $milestone as xs:string?, $type as xs:string?, $col as xs:string?){
let $source := 
    if(empty($type)) then $model("hits")
    else if($type = 'translation') then  
        doc($config:data-root || '/texts/iu-sample-kopf-en-tan.xml')
    else ()     
return 
    if($source) then
        <div class="flex-col">
            <div class="tei-teiHeader sourceInfo"><h4>Source</h4>{global:tei2html($source/descendant::tei:sourceDesc)}</div>
            {
            if($milestone != '') then 
                global:tei2html(app:get-by-milestone($source, $milestone))
            else global:tei2html($source//tei:text)
            }
        </div>
    else ()
};

declare function app:get-by-milestone($node as node(), $milestone as xs:string?){
    let $page := string(request:get-parameter('page', ''))
    let $pageNo := concat('#',$page)
    let $start :=
                    if($page != '') then
                        if($node/descendant::tei:surface) then 
                            replace($node/descendant::tei:surface[@start = $pageNo]/@start,'#','')
                        else replace($node/descendant::tei:pb[@xml:id = $page]/@xml:id,'#','')
                    else ()
    let $end := 
                    if($node/descendant::tei:surface) then 
                        replace(string($node/descendant::tei:surface[@start = $pageNo]/following::tei:surface[1]/@start),'#','')
                    else replace(string($node/descendant::tei:pb[@xml:id = $page]/following::tei:pb[@xml:id][1]/@xml:id),'#','')        
    let $ms1 := if($start != '' and $node/descendant::tei:pb[@xml:id = $start]) then 
                    $node/descendant::tei:pb[@xml:id = $start]
                else $node/descendant::tei:pb[1]
    let $ms2 := if($end != '' and $node/descendant::tei:pb[@xml:id = $end]) then
                    $node/descendant::tei:pb[@xml:id = $end] 
                else if($start != '' and $node/descendant::tei:pb[@xml:id = $start]) then 
                    $node/descendant::tei:pb[@xml:id = $start]/following::tei:pb[1]   
                else ($node//descendant::tei:pb)[last()]
    return data:get-fragment-from-doc($node, $ms1, $ms2, true(), true(),'')
};

(: page images :)
(:app:display-page-image:)
(:NOTE:  will need to know how all the parts are linked so we can call the different views, and what will be the main entry point? the text alighement? something else? What should show up in the search etc? :)
declare function app:display-page-image($node as node(), $model as map(*)){
if($model("hits")//tei:facsimile) then
    <div class="flex-col">
        { 
        let $page := string(request:get-parameter('page', ''))
        let $pageNo := concat('#',$page)
        let $current-page :=
            if($page != '') then $model("hits")/descendant::tei:surface[@start = $pageNo]
            else ()
        let $image := string($current-page/tei:graphic/@url)
        let $src := if(starts-with($image,'https://') or starts-with($image,'http://')) then $image  
                    else if(matches($image,'^\.\./img/')) then 
                        concat($config:get-config//repo:page-images-root,replace($image,'../img/',''))
                    else concat($config:get-config//repo:page-images-root,$image) 
        return if($image != '') then <img src="{$src}" class="page-image" width="100%" /> else ()                  
       }
    </div>
else ()
};

(: paging  app:display-alt-text :)
declare function app:display-translation($node as node(), $model as map(*)){
let $text := $model("hits")
let $docURI := document-uri(root($text))
let $refs := string($text//tei:title[1]/@ref)
let $additionalVersion := 
    for $r in collection($config:data-root)//tei:title[@ref = $refs]
    where document-uri(root($r)) != $docURI
    return $r
(: Hard coded for now :)
(: maybe use these : <anchor xml:id="kopf6" corresp="iu-sample-mueller-ar-tan.xml#mueller6"/> :)
(: have an expandable top to column with teiHeader info:)
let $translation :=  doc($config:data-root || '/texts/iu-sample-kopf-en-tan.xml')   
return
    <div class="flex-col">
        {global:tei2html($translation//tei:text)}
    </div>
(:
    if(count($additionalVersion) gt 1) then
        <div class="flex-col">Transcript</div>
    else ()
:)    
};

declare function app:next-page($node as node(), $model as map(*)){
let $page := string(request:get-parameter('page', ''))
let $pageNo := concat('#',$page)
let $current-page :=
    if($page != '') then
        if($model("hits")/descendant::tei:surface) then 
            $model("hits")/descendant::tei:surface[@start = $pageNo]
        else $model("hits")/descendant::tei:pb[@xml:id = $page]
    else $model("hits")/descendant::tei:pb[1]
let $next-id := 
                if($model("hits")/descendant::tei:surface) then 
                    $current-page/following::tei:surface[1]/@start
                else $current-page/descendant::tei:pb[@xml:id = request:get-parameter('page', '')[1]]/following::tei:pb[1]    
let $prev-id := 
                if($model("hits")/descendant::tei:surface) then 
                    $current-page/preceding::tei:surface[1]/@start
                else $current-page/descendant::tei:pb[@xml:id = $page[1]]/preceding::tei:pb[1]  
let $next := if($next-id != '') then <a href="{request:get-uri()}?page={replace($next-id,'#','')}">next page</a> else 'no  next' 
let $prev := if($prev-id != '') then <a href="{request:get-uri()}?page={replace($prev-id,'#','')}">prev page</a> else 'no prev'
return <span> {$prev} | {$next}</span>
};

(: Net work visualizations:)
(:~ 
 : d3js visualization with $model($hits)
 : Use d3xquery/d3xquery.xqm to generate appropriately formatted JSON data. 
:)
declare function app:data-visualization($node as node(), $model as map(*), $mode as xs:string?, $locus as xs:string?, $relationship as xs:string?) {
    let $data := $model("hits")
    let $id := if($locus = 'single') then 
                    if(request:get-parameter('recordID', '')) then request:get-parameter('recordID', '')
                    else if(request:get-parameter('id', '')) then request:get-parameter('id', '')
                    else replace($data/descendant::tei:idno[@type='URI'][1],'/tei','')
               else ()
    let $relationship := 
               if($relationship) then $relationship 
               else if(request:get-parameter('relationship', '') != '') then request:get-parameter('relationship', '') 
               else ()         
   let $mode := if($mode) then $mode else if(request:get-parameter('mode', '') != '') then request:get-parameter('mode', '') else 'Force'
   let $visData := 
                if($locus = 'single') then '[]'
                else 
                    (serialize(d3xquery:build-graph-type($data, $id, $relationship, $mode, $locus), 
                     <output:serialization-parameters>
                         <output:method>json</output:method>
                     </output:serialization-parameters>))
   return
        <div id="LODResults" xmlns="http://www.w3.org/1999/xhtml" class="resizeable">
                <script src="{$config:nav-base}/d3xquery/js/d3.v4.min.js" type="text/javascript"/>
                <h3>Relationship Graph</h3>
                <div id="graphVis" style="height:500px;"/>
                <script><![CDATA[
                        $(document).ready(function () {
                            var dataURL = ']]>{concat($config:nav-base,'/modules/data.xql?getVis=true&amp;id=',$id,'&amp;mode=',$mode)}<![CDATA[';
                            var rootURL = ']]>{$config:nav-base}<![CDATA[';
                            var postData =]]>{$visData}<![CDATA[;
                            var id = ']]>{$id}<![CDATA[';
                            var type = ']]>{$mode}<![CDATA[';
                            $.get(dataURL, function(data) {
                                     makeGraph(data,"500","400",rootURL,type);                
                                }, "json"); 
                            /*
                            if($('#graphVis svg').length == 0){}
                            jQuery(window).trigger('resize');
                            */
                        });
                ]]></script>
                <style><![CDATA[
                    .d3jstooltip {
                      background-color:white;
                      border: 1px solid #ccc;
                      border-radius: 6px;
                      padding:.5em;
                      font-size:10px; 
                      }
                    .nodelabel {font-size:12px; font-color: #666;}
                    
                    #legendContainer {
               	    font-size: 12px; 
               	    color: #666;
                       position: absolute;
                       top: 20px;
                       right: 10px;
                       background-color: white;
                       width: 25%;
                       min-height:200px;
                       max-height:400px;
                       padding: 4px;
                       border-style: solid;
                       border-radius: 4px;
                       border-width: 1px;
                       box-shadow: 3px 3px 10px rgba(0, 0, 0, .5);
                       font-size:10px; 
                       font-color: #666;
                       overflow: auto;
                    } 
                    #legendContainer.legend h3 {font-size: 18px; text-align:center; margin: 8px;}
                    #legendContainer.legend h4 {font-size: 14px; margin: 8px;}
                    .filterList {margin-left: 16px;}
                    #legendContainer button.filter {
                      background: none!important;
                      border: none;
                      padding: 0!important;
                      cursor: pointer;
                    }
                    ]]>
                </style>
                <script src="{$config:nav-base}/d3xquery/js/vis.js" type="text/javascript"/>
        </div>      
};
