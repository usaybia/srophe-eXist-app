<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:t="http://www.tei-c.org/ns/1.0" xmlns:x="http://www.w3.org/1999/xhtml" xmlns:saxon="http://saxon.sf.net/" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:local="http://syriaca.org/ns" exclude-result-prefixes="xs t x saxon local" version="2.0">
    
    <!-- =================================================================== -->
    <!--  Core TEI to HTML transformations  -->
    <!-- =================================================================== -->
    
    <!-- A -->
    <xsl:template match="t:abbr">
        <abbr>
            <xsl:sequence select="local:attributes(.)"/>
            <xsl:call-template name="rend"/>
        </abbr>
    </xsl:template>
    
    <!-- C -->
    <xsl:template match="t:cell">
        <td>
            <xsl:call-template name="rend"/>
        </td>
    </xsl:template> 
    <xsl:template match="t:choice">
        <span class="tei-choice">
            <xsl:apply-templates select="t:reg"/>
            <xsl:if test="t:orig">
                (<xsl:value-of select="t:orig"/>)
            </xsl:if>
        </span>
    </xsl:template>
    <!-- G -->
    <xsl:template match="t:graphic">
        <img src="{string(@url)}"/>
        <xsl:copy-of select="@*"/>
        <xsl:apply-templates select="child::*"/>
    </xsl:template> 
    
    <!-- H -->
    <xsl:template match="t:head">
        <xsl:choose>
            <xsl:when test="parent::t:div1">
                <h2>
                    <xsl:sequence select="local:attributes(.)"/>
                    <xsl:call-template name="rend"/>
                </h2>
            </xsl:when>
            <xsl:when test="parent::t:div2">
                <h3>
                    <xsl:sequence select="local:attributes(.)"/>
                    <xsl:call-template name="rend"/>
                </h3>
            </xsl:when>
            <xsl:otherwise>
                <span class="tei-{name(parent::*[1])} tei-head">
                    <xsl:sequence select="local:attributes(.)"/>
                    <xsl:call-template name="rend"/>
                </span>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- L -->
    <xsl:template match="t:l">
        <xsl:element name="{if (ancestor::t:hi) then 'span' else 'div'}">
            <xsl:attribute name="class">tei-l</xsl:attribute>
            <xsl:sequence select="local:attributes(.)"/>
            <xsl:call-template name="rend"/>
        </xsl:element>
    </xsl:template>
    <xsl:template match="t:lb">
        <br/>
    </xsl:template>
    <xsl:template match="t:list">
        <xsl:if test="t:head">
            <span class="tei-head"><xsl:apply-templates select="t:head"/></span>
        </xsl:if>
        <xsl:choose>
            <xsl:when test="t:label">
                <dl class="dl-inline">
                    <xsl:sequence select="local:attributes(.)"/>
                    <xsl:apply-templates mode="dlList"/>
                </dl>
            </xsl:when>
            <xsl:otherwise>
                <li>
                    <xsl:for-each select="child::*">
                        <li><xsl:apply-templates/></li>
                    </xsl:for-each>
                </li>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:label" mode="dlList">
        <dt><xsl:apply-templates/></dt>
    </xsl:template>
    <xsl:template match="t:item" mode="dlList">
        <dd><xsl:apply-templates/></dd><br/>
    </xsl:template>
    
    <xsl:template match="t:lg">
        <div class="tei-{local-name(.)}">
            <xsl:sequence select="local:attributes(.)"/>
            <xsl:call-template name="rend"/>
        </div>
    </xsl:template>
    <!-- Handles t:link elements for deperciated notes, pulls value from matching element, output element and footnotes -->
    <xsl:template match="t:link">
        <xsl:variable name="elementID" select="substring-after(substring-before(@target,' '),'#')"/>
        <xsl:for-each select="/descendant-or-self::*[@xml:id=$elementID]">
            <xsl:apply-templates select="."/>
            <xsl:text> </xsl:text>
        </xsl:for-each>
    </xsl:template> 
    
    <!-- O -->
    <xsl:template match="t:offset | t:measure | t:source ">
        <xsl:if test="preceding-sibling::*">
            <xsl:text> </xsl:text>
        </xsl:if>
        <xsl:apply-templates select="." mode="plain"/>
    </xsl:template>
    
    <!-- Q -->
    <xsl:template match="t:quote">
        <xsl:variable name="quot">"</xsl:variable>
        <span class="tei-quote" dir="ltr" lang="en">
            <xsl:choose>
                <xsl:when test="@xml:lang">
                    <xsl:if test="not(starts-with(.,$quot))">
                        <span dir="ltr">
                            <xsl:text> “</xsl:text>
                        </span>
                    </xsl:if>
                    <span>
                        <xsl:sequence select="local:attributes(.)"/>
                        <xsl:call-template name="rend"/>
                    </span>
                    <xsl:if test="not(ends-with(normalize-space(.),$quot))">
                        <span dir="ltr">
                            <xsl:text>”  </xsl:text>
                        </span>
                    </xsl:if>
                </xsl:when>
                <xsl:when test="parent::*/@xml:lang">
                    <!-- Quotes need to be outside langattr for Syriac and arabic characters to render correctly.  -->
                    <xsl:if test="not(starts-with(.,$quot))">
                        <span dir="ltr">
                            <xsl:text> “</xsl:text>
                        </span>
                    </xsl:if>
                    <span class="langattr">
                        <xsl:sequence select="local:attributes(parent::*[@xml:lang])"/>
                        <xsl:call-template name="rend"/>
                    </span>
                    <xsl:if test="not(ends-with(normalize-space(.),$quot))">
                        <span dir="ltr">
                            <xsl:text>”  </xsl:text>
                        </span>
                    </xsl:if>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates/>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:sequence select="local:add-footnotes(@source,ancestor::t:*[@xml:lang][1])"/> 
        </span>
    </xsl:template>
    
    <!-- R -->
    <xsl:template match="t:ref | t:ptr">
        <a href="{@target}">
            <xsl:apply-templates/>
        </a>
    </xsl:template>
    
    <!-- T -->
    <xsl:template match="t:table">
        <table class="tei-table">
            <xsl:apply-templates/>
        </table>
    </xsl:template>
    
    <!-- R -->
    <xsl:template match="t:row">
        <tr>
            <xsl:apply-templates/>
        </tr>
    </xsl:template>
    
    <!-- Default templates handle any element not specifically styled -->
    <xsl:template match="*">
        <span class="tei-{local-name(.)}">
            <xsl:sequence select="local:attributes(.)"/>
            <xsl:call-template name="rend"/>
            <xsl:sequence select="local:add-footnotes(@source,.)"/>
        </span>
    </xsl:template>
    <xsl:template match="t:*" mode="inline plain" xml:space="preserve">
        <xsl:apply-templates/>
    </xsl:template>
    <xsl:template match="text()" mode="cleanout">
        <xsl:value-of select="."/>
    </xsl:template>
    <xsl:template match="t:*" mode="cleanout">
        <xsl:apply-templates mode="cleanout"/>
    </xsl:template>
    <xsl:template match="t:*" mode="out-normal">
        <xsl:variable name="thislang" select="ancestor-or-self::*[@xml:lang][1]/@xml:lang"/>
        <xsl:choose>
            <xsl:when test="starts-with($thislang, 'syr') or starts-with($thislang, 'syc') or starts-with($thislang, 'ar')">
                <span dir="rtl">
                    <xsl:apply-templates select="." mode="text-normal"/>
                </span>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="." mode="text-normal"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="t:*" mode="text-normal">
        <xsl:value-of select="normalize-space(normalize-unicode(., $normalization))"/>
    </xsl:template>
    <xsl:template match="text()" mode="text-normal">
        <xsl:variable name="prefix">
            <xsl:if test="(preceding-sibling::t:* or preceding-sibling::text()[normalize-space()!='']) and string-length(.) &gt; 0 and substring(., 1, 1)=' '">
                <xsl:text> </xsl:text>
            </xsl:if>
        </xsl:variable>
        <xsl:variable name="suffix">
            <xsl:if test="(following-sibling::t:* or following-sibling::text()[normalize-space()!='']) and string-length(.) &gt; 0 and substring(., string-length(.), 1)=' '">
                <xsl:text> </xsl:text>
            </xsl:if>
        </xsl:variable>
        <xsl:value-of select="$prefix"/>
        <xsl:value-of select="normalize-space(normalize-unicode(., $normalization))"/>
        <xsl:value-of select="$suffix"/>
    </xsl:template>
    
</xsl:stylesheet>