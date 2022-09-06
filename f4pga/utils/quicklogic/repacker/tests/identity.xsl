<?xml version="1.0"?>
<!-- 
 Copyright (C) 2020  The SymbiFlow Authors.

 Use of this source code is governed by a ISC-style
 license that can be found in the LICENSE file or at
 https://opensource.org/licenses/ISC

 SPDX-License-Identifier:   ISC
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes"/>
  <xsl:strip-space elements="*"/>

  <xsl:template match="@*">
    <xsl:copy/>
  </xsl:template>

  <xsl:template match="*">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="text()|processing-instruction()">
    <xsl:copy>
      <xsl:apply-templates select="text()|processing-instruction()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:param name="strip_comments" select="''" />
  <xsl:template match="comment()">
    <xsl:choose>
      <xsl:when test="$strip_comments"></xsl:when>
      <xsl:otherwise><xsl:copy /></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
