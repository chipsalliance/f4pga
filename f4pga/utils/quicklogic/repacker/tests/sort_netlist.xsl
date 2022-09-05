<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:include href="identity.xsl" />

  <!-- Sort everything -->
  <xsl:template match="block">
    <xsl:copy>     

      <xsl:apply-templates select="@*">
        <xsl:sort select="name()" order="ascending"/>
      </xsl:apply-templates>

      <xsl:apply-templates select="attributes"/>
      <xsl:apply-templates select="parameters"/>

      <xsl:apply-templates select="inputs">
        <xsl:sort select="@name" order="ascending"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="outputs">
        <xsl:sort select="@name" order="ascending"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="clocks">
        <xsl:sort select="@name" order="ascending"/>
      </xsl:apply-templates>

      <xsl:apply-templates select="block">
        <xsl:sort select="@instance" order="ascending"/>
      </xsl:apply-templates>

      <xsl:apply-templates select="*[not(self::attributes or self::parameters or self::inputs or self::outputs or self::clocks or self::block)]"/>

    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>

