xquery version "3.1";
(:~  
 : Basic data interactions, returns raw data for use in other modules  
 : Not a library module
:)
import module namespace config="http://srophe.org/srophe/config" at "config.xqm";
import module namespace data="http://srophe.org/srophe/data" at "lib/data.xqm";
import module namespace d3xquery="http://srophe.org/srophe/d3xquery" at "../d3xquery/d3xquery.xqm";
import module namespace tei2html="http://srophe.org/srophe/tei2html" at "content-negotiation/tei2html.xqm";
import module namespace functx="http://www.functx.com";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace util="http://exist-db.org/xquery/util";

(: Get posted data :)
let $results := 
            if(request:get-parameter('query', '')) then 
                request:get-parameter('query', '')
            else if(request:get-parameter('getVis', '')) then
                let $id := if(request:get-parameter('recordID', '')) then request:get-parameter('recordID', '')
                           else request:get-parameter('id', '')
                let $relationship := 
                           if(request:get-parameter('relationship', '') != '') then request:get-parameter('relationship', '') 
                           else ()         
               let $mode := 
                            if(request:get-parameter('mode', '') != '') then 
                                request:get-parameter('mode', '') 
                            else 'Force'
               return d3xquery:build-graph-type((), $id, $relationship, $mode, if($id != '') then 'single' else ())
            else request:get-data() 

return 
    if(request:get-parameter('getPage', '') != '') then 
        $results
    else if(request:get-parameter('view', '') = 'expand' and request:get-parameter('workid', '') != '') then
        $results
    else (response:set-header("Content-Type", "application/json"),
        serialize($results, 
            <output:serialization-parameters>
                <output:method>json</output:method>
            </output:serialization-parameters>))    