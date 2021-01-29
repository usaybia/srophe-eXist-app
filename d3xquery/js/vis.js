//Saved while test tooltip issue
/* Global vars */

function makeGraph(data, w, h, rootURL, type) {
   //set up global vars
   //data stores
    var graph, store;
    var linkedByIndex = {};
    var rootURL = rootURL;
    var type = type;
    //SVG set up variables
    var color = d3.scaleOrdinal(d3.schemeCategory20c),
        rel = d3.scaleOrdinal(d3.schemeCategory20c),
        occ = d3.scaleOrdinal(d3.schemeCategory20c),
        margin = {
                  top: 20, right: 30, bottom: 30, left: 30
                },
        width = w - margin.left - margin.right,
        height = h - margin.top - margin.bottom,
        radius = 5,
        nodeColor = '#8db99f',
        firstDegree = '#C5DCCE';
    
    //Create SVG on #vis element
    var svg = d3.select('#graphVis')
                .append('svg')
                .attr("width", width)
                .attr("height", height + margin.top + margin.bottom)
                .call(responsivefy);

    //Create a tooltip div 
    var legend = d3.select("#graphVis")
            .append("div")
            .attr("class", "legend")
            .attr("id","legendContainer")
            .style("opacity", 1)
            .html("<h3>Filters</h3><h4>Relationships</h4><div id='relationFilter' class='filterList'></div><h4>Occupations</h4><div id='occupationFilter' class='filterList'></div>"); 
            
    //Tooltip   
    var tooltip = d3.select("body").append("div")
            .attr("class", "d3jstooltip")
        	.style("position","absolute")
        	.style("opacity", 0);
    //Set up containers for links and nodes
    var link = svg.append("g").selectAll(".link"),
        node = svg.append("g").selectAll(".node");
    
    //Select graph type
    //selectGraphType(type);
    getData(data);
  
    function getData(data) {
      //Data read and store
      /* 
      if(dataURL){
          d3.json(data, function(err, g) {
      	if (err) throw err;
      	//Do any data updates here, currently not used
      	graph = g;
      	store = $.extend(true, {}, g);
          //update graph
      	selectGraphType(type);
      	console.log('get data');
        });
      }else{
       graph = data;
       selectGraphType(type);   
      } 
       * */
       graph = data;
       selectGraphType(type); 
      //end getData
    };
    
    //responsivefy resize svg
    function responsivefy(svg) {
        // get container + svg aspect ratio
        var container = d3.select(svg.node().parentNode),
            width = parseInt(svg.style("width")), 
            height = parseInt(svg.style("height")),
            aspect = width / height;
        
        // add viewBox and preserveAspectRatio properties,
        // and call resize so that svg resizes on inital page load
        svg.attr("viewBox", "0 0 " + width + " " + height)
            .attr("perserveAspectRatio", "xMinYMid")
            .call(resize);
    
        // to register multiple listeners for same event type, 
        // you need to add namespace, i.e., 'click.foo'
        // necessary if you call invoke this function for multiple svgs
        // api docs: https://github.com/mbostock/d3/wiki/Selections#on
        d3.select(window).on("resize." + container.attr("id"), resize);
    
        // get width of container and resize svg to fit it
        function resize() {
            var targetWidth = (isNaN(parseInt(container.style("width")))) ? 960 : parseInt(container.style("width")); 
            svg.attr("width", targetWidth);
            svg.attr("height", Math.round(targetWidth / aspect));
        }
    //end responsivefy    
    }
  
   //Select graph type/mode
    function selectGraphType(type) {
        if (type.toLowerCase() === 'force') {
            //console.log(type + ' cant do that one yet');
            forcegraph()
        } else if (type.toLowerCase() === 'bubble') {
            //console.log(type + ' cant do that one yet');
            bubble()
        } else if (type.toLowerCase() === 'raw xml') {
            console.log(type + ' cant do that one yet');
            //  rawXML()
        } else if (type.toLowerCase() === 'Raw json') {
            console.log(type + ' cant do that one yet');
            //  rawJSON()
        } else {
            console.log(type.toLowerCase() + ' cant do that one yet');
        }
     //end selectGraphType   
    };
  

    /* Force Graph */
    function forcegraph() {
         //Force simulation initialization
         var simulation = d3.forceSimulation()
             .force("link", d3.forceLink().id(function (d) {return d.id;}).distance(80).strength(0.75))
             .force("charge", d3.forceManyBody().strength(-100))
             .force("center", d3.forceCenter(width / 2, height / 3));
        
        var link = svg.append("g")
            .attr("class", "links")
            .selectAll("g")
            .data(graph.links).enter()
            .append('path')
            .attr('class', 'link')
            .attr('fill-opacity', 0)
            .attr('stroke-opacity', 1)
            .attr("stroke-width", "1")
            .style('fill', 'none')
            .attr("stroke", function (d) {
                return d3.rgb(rel(d.relationship));
            })
            .attr('id', function (d, i) {return 'link' + i})
            .style("pointer-events", "none");
        
        var node = svg.append("g")
            .attr("class", "nodes")
            .selectAll("g")
            .data(graph.nodes).enter()
            .append("g");
        
        var circles = node.append("circle")
            .attr("r",function(d) {
	       if(d.degree === 'primary'){
	           return radius * 3.5;    
            } else if(d.degree === 'first') {
                return radius * 2;
            } else {
                return radius;
        }}) 
        //.attr("class", "forceNode")
        .attr("class", function (d) {
            return d.occupation;
        })
        .style("fill", function (d) {
            //return d3.rgb(occ(d.occupation));
            /* Color by relationship degree */  
            if(d.degree === 'primary'){
                return nodeColor;
            } else if(d.degree === 'first') {
                return firstDegree;
            } else {
                return 'white';
            }}) 
            .style("stroke", function (d) {
                //return d3.rgb(color(d.occupation)).darker();
                return nodeColor;
            })
            .call(d3.drag().on("start", dragstarted).on("drag", dragged).on("end", dragended))
            .on("mouseover", function (d) {
                fade(d,.1);
                tooltip.style("visibility", "visible").html('<span class="nodelabel">' + d.label + '</span><br/>' + d.occupation).style("padding", "4px").style("opacity", .99).style("left", (d3.event.pageX) + "px").style("top", (d3.event.pageY - 28) + "px");
                    /* 
                    .text(d.label)
                    .style("opacity", 1)
                    .style("left", (d3.event.pageX) + "px")
                    .style("top", (d3.event.pageY + 5) + "px");
                     */ 
            }).on("mouseout", function (d) { 
                fade(d,1);
                tooltip.style("visibility", "hidden");
            }).on("mousemove", function () {
                return tooltip.style("top", (event.pageY -10) + "px").style("left",(event.pageX + 10) + "px");                     
            }).on('dblclick', function (d, i) { 
                window.location = d.id;
            });
        
        node.append("title").text(function (d) {
            return d.id;
        });
        
        //Add legend
        // flat map will flatten the inner arrays
        var occupations = graph.nodes.flatMap((d) => d.occupation);
        // get distinct values
        var occFilter = [... new Set(occupations)];
        //console.log(occFilter)
        
        d3.select('#legend').selectAll('ul').remove();
    	occupation =  svg.append("g").selectAll(".occupation"),
    	relation =  svg.append("g").selectAll(".relation");
    
        d3.select("#occupationFilter").selectAll("div")
            .data(occFilter.sort())
            .enter()
            .append("div")
            .attr("class","option")
            .html(function(d){ return '<button class="filter">' + d + '</button>';})
            .on('click', function (d, i) { 
                    console.log('FilterNodes: ', d );
                    filter(d, .1)
                });
            //.text(function(d){ return d;});
         
        var nest2 = d3.nest()
            .key(function(d) { return d;})
            .entries(rel.domain().sort());
            
        d3.select("#relationFilter").selectAll("div")
            .data(nest2)
            .enter()
            .append("div")
            .attr("class","option")
            .html(function(d){ return '<button class="filter">' + d.key + '</button>';})
            //.text(function(d) { return d.key; })
            //.style("fill", function(d){ return rel(d.key) })
            //.style("font-size", 15)
            .on('click', function (d, i) { 
                    console.log('FilterLinks: ', d.key );
                    filterLinks(d.key, .1)
                });
        
        simulation.nodes(graph.nodes).on("tick", ticked);
        
        simulation.force("link").links(graph.links);
        
        function ticked() {
            circles
      		.attr("cx", function(d) { return d.x = Math.max(radius, Math.min(width - radius, d.x)); })
      		.attr("cy", function(d) { return d.y = Math.max(radius, Math.min(height - radius, d.y)); });
      
      	/* curved lines */                   
              link.attr("d", function(d) {
                  var dx = d.target.x - d.source.x,
                      dy = d.target.y - d.source.y,
                      dr = Math.sqrt(dx * dx + dy * dy);
                      return "M" + d.source.x + "," + d.source.y + "A" + dr + "," + dr + " 0 0,1 " + d.target.x + "," + d.target.y;
                  });
        }
        
        //Link Connected
        graph.links.forEach(function (d) {
             linkedByIndex[d.source.index + "," + d.target.index] = 1;
        });
      
        //Connection for Highlight related
        function isConnected(a, b) {
            return linkedByIndex[a.index + "," + b.index] || linkedByIndex[b.index + "," + a.index] || a.index === b.index;
        }
        
        function fade(d,opacity) {
                node.style("stroke-opacity", function (o) {
                    thisOpacity = isConnected(d, o) ? 1: opacity;
                    this.setAttribute('fill-opacity', thisOpacity);
                    return thisOpacity;
                    return isConnected(d, o);
                });
                link.style("stroke-opacity", opacity).style("stroke-opacity", function (o) {
                    return o.source === d || o.target === d ? 1: opacity;
                });
        //end fade function
        }; 
        
        //Drag functions
        function dragstarted(d) {
            if (! d3.event.active) simulation.alphaTarget(0.3).restart();
            d.fx = d.x;
            d.fy = d.y;
        }
        
        function dragged(d) {
            d.fx = d3.event.x;
            d.fy = d3.event.y;
        }
        
        function dragended(d) {
            if (! d3.event.active) simulation.alphaTarget(0);
            d.fx = null;
            d.fy = null;
        }
        
    //Filter functions, Occupations    
    function filter(filter,opacity){
        node.style("stroke-opacity", function (o) {
            var occupation = o.occupation
            thisOpacity = occupation.includes(filter) ? 1: opacity;
            this.setAttribute('fill-opacity', thisOpacity);
            return thisOpacity;
        });
        link.style("stroke-opacity", opacity).style("stroke-opacity", function (o) {
            return opacity;
        });
    }
    //Filter functions, Relationships
    function filterLinks(filter,opacity){
        link.style("stroke-opacity", opacity).style("stroke-opacity", function (o) {
            thisOpacity = o.relationship === filter ? 1: opacity;
            this.setAttribute('fill-opacity', thisOpacity);
            return thisOpacity;
        });
    }
    

    };
    
    //Force Graph functions
    function bubble() {
        console.log('root url: ' + rootURL)
        /* Set up svg */
        var svg = d3.select("#graphVis").append("svg")
            .attr("width", width)
            .attr("height", height)
            .style("border", "1px solid grey")
            .call(responsivefy);
        
       var tooltip = d3.select("body").append("div")
            .attr("class", "d3jstooltip")
        	.style("position","absolute")
        	.style("opacity", 0);
        
        //Data
        data = graph.data.children;
        
        var minRadius = d3.min(data, function(d){return d.size})
        var maxRadius = d3.max(data, function(d){return d.size})
        var radiusScale = d3.scaleSqrt()
                .domain([minRadius, maxRadius])
                .range([10,80]); 
        
        var n = data.length, // total number of circles
            m = 10; // number of distinct clusters
    
        
        //color based on cluster
        var c = d3.scaleOrdinal(d3.schemeCategory10).domain(d3.range(m));
        
        // The largest node for each cluster.
        var clusters = new Array(m);
        
        var nodes = data.map(function (d) {
            var i = d.group,
            l = d.name,
            s = d.size,
            id = d.id,
            r = radiusScale(d.size),
            d = {
                cluster: i, radius: r, name: l, size: s, id: id
            };
            if (! clusters[i] || (r > clusters[i].radius)) clusters[i] = d;
            return d;
        });
        
        var forceCollide = d3.forceCollide()
            .radius(function (d) {
                return d.radius + 2.5;
            }).iterations(1);
            
        var force = d3.forceSimulation()
            .nodes(nodes)
            .force("center", d3.forceCenter())
            .force("collide", forceCollide)
            .force("cluster", forceCluster)
            .force("gravity", d3.forceManyBody(30))
            .force("x", d3.forceX().strength(.5))
            .force("y", d3.forceY().strength(.5))
            .on("tick", tick);
        
        var g = svg.append('g').attr('transform', 'translate(' + width / 2 + ',' + height / 2 + ')');
        
        var circle = g.selectAll("circle")
            .data(nodes).enter()
            .append("circle")
            .attr("r", function (d) {
                return d.radius;
            }).style("fill", function (d) {
                return color(d.cluster);
            }).attr("stroke", function (d) {
                return d3.rgb(color(d.cluster)).darker();
            }).on("mouseover", function (d) {
                d3.select(this).style("opacity", .5);
                return tooltip.style("visibility", "visible")
                        .text(d.name + ' [' + d.size + ' works]')
                        .style("opacity", 1)
                        .style("left", (d3.event.pageX) + "px")
                        .style("top", (d3.event.pageY + 10) + "px");
            }).on("mouseout", function (d) {
                d3.select(this).style("opacity", 1);
                return tooltip.style("visibility", "hidden");
            }).on("mousemove", function () {
                return tooltip.style("top", (event.pageY -10) + "px").style("left",(event.pageX + 10) + "px");
            }).on('dblclick', function (d, i) {
                var searchString = ";fq-Taxonomy:" + d.id;
                var url = rootURL + "/search.html?fq=" + encodeURIComponent(searchString);
                window.location = url;
                //console.log('URL: ' + url);
            });
        
        function tick() {
            circle.attr("cx", function (d) {
                return d.x;
            }).attr("cy", function (d) {
                return d.y;
            });
        }
        
        function forceCluster(alpha) {
            for (var i = 0, n = nodes.length, node, cluster, k = alpha * 1; i < n;++ i) {
                node = nodes[i];
                cluster = clusters[node.cluster];
                node.vx -= (node.x - cluster.x) * k;
                node.vy -= (node.y - cluster.y) * k;
            }
        }
    };  
  
    
    
  //end make graph  
}

