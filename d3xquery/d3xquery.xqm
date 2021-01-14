xquery version "3.1";

module namespace d3xquery="http://srophe.org/srophe/d3xquery";
import module namespace config="http://srophe.org/srophe/config" at "../modules/config.xqm";
import module namespace functx="http://www.functx.com";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace json="http://www.json.org";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare function d3xquery:list-relationship($records){
    <list>{
        for $r in distinct-values(for $r in $records//tei:relation return $r/@ref)
        return 
            <option label="{if(contains($r,':')) then substring-after($r,':') else $r}" value="{$r}"/>
            }
    </list>
};

declare function d3xquery:formatDate($date){
let $formatDate := 
    if($date castable as xs:date) then xs:date($date)
    else if(matches($date,'^\d{4}$')) then 
        let $newDate :=  concat($date,'-01-01')
        return 
            if($newDate castable as xs:date) then xs:date($newDate)
            else $newDate
    else if(matches($date,'^\d{4}-\d{2}')) then 
        let $newDate :=  concat($date,'-01')
        return 
            if($newDate castable as xs:date) then xs:date($newDate)
            else $newDate            
    else $date 
return 
    try {format-date(xs:date($formatDate), "[M]-[D]-[Y]")} catch * {concat('ERROR: invalid date.' ,$formatDate)}
};

declare function d3xquery:relationship-graph($data, $recID, $relationship){
    let $relationship :=
            if($relationship != '') then $relationship
            else if(request:get-parameter('relationship', '')) then request:get-parameter('relationship', '') 
            else ()
    let $pid := 
            if($recID != '') then $recID
            else if(request:get-parameter('id', '')) then request:get-parameter('id', '') 
            else if(request:get-parameter('pid', '')) then request:get-parameter('pid', '')
            else if(request:get-parameter('recID', '')) then request:get-parameter('recID', '') 
            else ()
    let $degree := 
            if(request:get-parameter('degree', '')) then request:get-parameter('degree', '') 
            else 'second'
    let $id := concat($pid,'(\W.*)?$')
    let $dataset := 
        if($pid) then 
            if($degree = 'second') then
                let $firstDegree := collection($config:data-root)//tei:relation[
                        @passive[matches(.,$id)] or 
                        @active[matches(.,$id)] or
                        @mutual[matches(.,$id)]]                                   
                let $firstIDs := string-join(($firstDegree/@active, $firstDegree/@passive,$firstDegree/@mutual),'(\W.*)?$|')
                let $secondDegree := 
                    if(count($firstDegree) lt 50) then 
                        collection($config:data-root)//tei:relation[
                            @passive[matches(.,($firstIDs))] or 
                            @active[matches(.,($firstIDs))] or
                            @mutual[matches(.,($firstIDs))]]
                     else $firstDegree       
                 return functx:distinct-nodes(($secondDegree))
            else 
                let $firstDegree := collection($config:data-root)//tei:relation[
                        @passive[matches(.,$id)] or 
                        @active[matches(.,$id)] or
                        @mutual[matches(.,$id)]]
                return functx:distinct-nodes($firstDegree)
        else functx:distinct-nodes($data//tei:relation)
    let $filters := if($relationship) then 
                        $dataset[@ref=$relationship]
                    else $dataset
    let $uris := distinct-values((
                    for $r in $filters return tokenize($r/@active,' '), 
                    for $r in $filters return tokenize($r/@passive,' '), 
                    for $r in $filters return tokenize($r/@mutual,' ')
                    ))
    let $tei := collection($config:data-root)//tei:idno[. = $uris]/ancestor::tei:TEI
    let $json := <root>{(d3xquery:nodes($filters, $pid), d3xquery:links($filters, $pid))}</root>
    return $json       
};

declare function d3xquery:get-relationship($records, $relationship, $id){
    let $id := concat($id,'(\W.*)?$')
    let $all-relationships := 
            if(contains($relationship,'Select relationship') or contains($relationship,'All') or $relationship = '') then true() 
            else false()
    return 
        if($all-relationships = false()) then 
            if($id != '') then
               $records//tei:relation[@ref=$relationship or @name=$relationship][@passive[matches(.,$id)] or 
                    @active[matches(.,$id)] or
                    @mutual[matches(.,$id)]] 
            else $records//tei:relation[@ref=$relationship or @name=$relationship] 
        else if($id != '') then 
              $records//tei:relation[@passive[matches(.,$id)] or 
                    @active[matches(.,$id)] or
                    @mutual[matches(.,$id)]]
        else $records//tei:relation
};

declare function d3xquery:nodes($data, $pid){
let $uris := distinct-values((
                    for $r in $data return tokenize($r/@active,' '), 
                    for $r in $data return tokenize($r/@passive,' '), 
                    for $r in $data return tokenize($r/@mutual,' ')
                    ))
return  
    <nodes>{
        for $uri in $uris
        let $id := concat($pid,'(\W.*)?$')
        let $currentID := concat($uri,'(\W.*)?$')
        let $rec := collection('/db/apps/usaybia-data')//tei:idno[. = $uri]/ancestor::tei:TEI
        let $label := string-join($rec/descendant::tei:title[1]//text(),' ')
        let $relationships := 
                $data[@passive[matches(.,$currentID)] or 
                    @active[matches(.,$currentID)] or
                    @mutual[matches(.,$currentID)]]
        let $degree := 
            if($uri = $pid) then 'primary'
            else if($relationships[@passive[matches(.,$id)] or 
                    @active[matches(.,$id)] or
                    @mutual[matches(.,$id)]]) then 'first'
            else 'second'
        return
            <json:value>
                <id>{$uri}</id>
                <type>{tokenize($uri,'/')[4]}</type>
                <label>{$label}</label>
                {if($rec/descendant::tei:state[@type = 'occupation']) then
                    for $o in $rec/descendant::tei:state[@type = 'occupation']
                    return <occupation json:array="true">{string($o/@role)}</occupation>
                else <occupation json:array="true"></occupation>}
                <degree>{$degree}</degree>
            </json:value>
    }</nodes>
};

declare function d3xquery:links($data, $pid){
<links>{
    for $r in $data
    return 
        if($r/@mutual) then 
            let $mutual := tokenize($r/@mutual,' ')
            let $num := count($mutual)
            for $m at $i in $mutual
            let $n := $mutual[$i + 1]
            where $i lt $num
            return 
                <json:value>
                    <source>{$m}</source>
                    <target>{$n}</target>
                    <relationship>{replace($r/@ref,'^(.*?):','')}</relationship>
                    <value>0</value>
                </json:value>  
        else if(contains($r/@active,' ')) then 
        (: Check passive for spaces/multiple values :)
            if(contains($r/@passive,' ')) then 
                for $a in tokenize($r/@active,' ')
                for $p in tokenize($r/@passive,' ')
                return 
                        <json:value>
                            <source>{string($p)}</source>
                            <target>{string($a)}</target>
                            <relationship>{replace($r/@ref,'^(.*?):','')}</relationship>
                            <value>0</value>
                        </json:value> 
            (: multiple active, one passive :)
            else 
                let $passive := string($r/@passive)
                for $a in tokenize($r/@active,' ')
                return 
                    <json:value>
                        <source>{string($passive)}</source>
                        <target>{string($a)}</target>
                        <relationship>{replace($r/@name,'^(.*?):','')}</relationship>
                        <value>0</value>
                    </json:value>
            (: One active multiple passive :)
            else if(contains($r/@passive,' ')) then 
                let $active := string($r/@active)
                for $p in tokenize($r/@passive,' ')
                return 
                <json:value>{if(count($data) = 1) then attribute {xs:QName("json:array")} {'true'} else ()}
                    <source>{string($p)}</source>
                    <target>{string($active)}</target>
                    <relationship>{replace($r/@ref,'^(.*?):','')}</relationship>
                    <value>0</value>
                </json:value>
            (: One active one passive :)            
            else 
                <json:value>{if(count($data) = 1) then attribute {xs:QName("json:array")} {'true'} else ()}
                    <source>{string($r/@passive)}</source>
                    <target>{string($r/@active)}</target>
                    <relationship>{replace($r/@ref,'^(.*?):','')}</relationship>
                    <value>0</value>
                </json:value>
    }</links>
};

(: Output based on d3js requirements for producing an HTML table:)
declare function d3xquery:format-table($relationships){       
        <root>{
                (
                <head>{
                for $attr in $relationships[1]/@* 
                return <vars>{name($attr)}</vars>
                }</head>,
                <results>{
                for $r in $relationships 
                return $r
                }</results>)
            }
        </root>
};

(: Output based on d3js requirements for producing a d3js tree format, single nested level, gives collection overview :)
declare function d3xquery:format-tree-types($relationships){
    <root>
        <data>
            <children>
                {
                    for $r in $relationships
                    let $group := if($r/@ref) then $r/@ref else $r/@name
                    group by $type := $group
                    order by count($r) descending
                    return 
                        <json:value>
                            <name>{string($type)}</name>
                            <size>{count($r)}</size>
                         </json:value>
                 }
            </children>
        </data>
    </root>
};

(: output based on d3js requirements :)
declare function d3xquery:format-relationship-graph($relationships){
    let $uris := distinct-values((
                    for $r in $relationships return tokenize($r/@active,' '), 
                    for $r in $relationships return tokenize($r/@passive,' '), 
                    for $r in $relationships return tokenize($r/@mutual,' ')
                    )) 
    return 
        <root>
            <nodes>
                {
                for $uri in $uris
                return
                    <json:value>
                        <id>{$uri}</id>
                        <label>{$uri}</label>
                   </json:value>
                }
            </nodes>
            <links>
                {
                    for $r in $relationships
                    return 
                        if($r/@mutual) then 
                             for $m in tokenize($r/@mutual,' ')
                             return 
                                 let $node := 
                                     for $p in tokenize($r/@mutual,' ')
                                     where $p != $m
                                     return 
                                         <json:value>
                                             <source>{$m}</source>
                                             <target>{$p}</target>
                                             <relationship>{replace($r/@ref,'^(.*?):','')}</relationship>
                                             <value>0</value>
                                         </json:value>
                                 return $node
                        else if(contains($r/@active,' ')) then 
                                (: Check passive for spaces/multiple values :)
                                if(contains($r/@passive,' ')) then 
                                    for $a in tokenize($r/@active,' ')
                                    return 
                                        for $p in tokenize($r/@passive,' ')
                                        return 
                                           <json:value>
                                                <source>{string($p)}</source>
                                                <target>{string($a)}</target>
                                                <relationship>{replace($r/@ref,'^(.*?):','')}</relationship>
                                                <value>0</value>
                                            </json:value> 
                                (: multiple active, one passive :)
                                else 
                                    let $passive := string($r/@passive)
                                    for $a in tokenize($r/@active,' ')
                                    return 
                                            <json:value>
                                                <source>{string($passive)}</source>
                                                <target>{string($a)}</target>
                                                <relationship>{replace($r/@name,'^(.*?):','')}</relationship>
                                                <value>0</value>
                                            </json:value>
                            (: One active multiple passive :)
                            else if(contains($r/@passive,' ')) then 
                                    let $active := string($r/@active)
                                    for $p in tokenize($r/@passive,' ')
                                    return 
                                            <json:value>
                                            {if(count($relationships) = 1) then attribute {xs:QName("json:array")} {'true'} else ()}
                                                <source>{string($p)}</source>
                                                <target>{string($active)}</target>
                                                <relationship>{replace($r/@ref,'^(.*?):','')}</relationship>
                                                <value>0</value>
                                            </json:value>
                                (: One active one passive :)            
                            else 
                                    <json:value>
                                    {if(count($relationships) = 1) then attribute {xs:QName("json:array")} {'true'} else ()}
                                        <source>{string($r/@passive)}</source>
                                        <target>{string($r/@active)}</target>
                                        <relationship>{replace($r/@ref,'^(.*?):','')}</relationship>
                                        <value>0</value>
                                    </json:value>
                }
            </links>
        </root>
};

(:~
 : Build JSON data for d3js visualizations
 : @param $data record or records
 : @param $id record id for locus on single record
 : @param $relationship name of relationship to filter data on
 : @param $mode graph type: Force, Sankey, Table, Bubble
:)
declare function d3xquery:build-graph-type($data, $id as xs:string?, $relationship as xs:string?, $mode as xs:string?, $locus as xs:string?){
let $visData := 
    if($mode = ('force','Force','sankey','Sankey')) then
        d3xquery:relationship-graph($data, $id, $relationship)
    else if($mode = ('tree','Tree','bubble','Bubble')) then
        d3xquery:format-tree-types(d3xquery:get-relationship($data, $relationship, $id))
    else d3xquery:format-table(d3xquery:get-relationship($data, $id, $relationship))
return 
        if(request:get-parameter('format', '') = ('json','JSON')) then
            (serialize($visData, 
                        <output:serialization-parameters>
                            <output:method>json</output:method>
                        </output:serialization-parameters>),
                        response:set-header("Content-Type", "application/json"))        
        else $visData
};        