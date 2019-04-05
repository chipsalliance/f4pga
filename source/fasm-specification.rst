FPGA ASM (FASM) Specification
=============================

Introduction
------------

The FASM is a file format designed to specify the bits in an FPGA bitstream that need to be set (e.g. binary 1) or cleared (e.g. binary 0).

A FASM file declares that specific "Features" within the bitstream should be enabled. Enabling a feature will cause bits within the bitstream to be set or cleared.

A FASM file is illegal if a bit in the final bitstream must be set and cleared to respect the set of features specified in the FASM file.

An empty FASM file will generate a platform specific "default" bitstream. The FASM file will specific zero or more features that mutate the "default" bitstream into the target bitstream.

File Syntax description
-----------------------

FASM is a line oriented format.

* A single FASM line will do nothing (blank or comments or annotations) or enable a set of features.
* The FASM file format does not support line continuations. Enabling a feature will always be contained within one line.
* Constants and arrays follow verilog syntax

Due to the line orientated format, a FASM file has the following properties:

* Removing a line from a FASM file, produces a FASM file.
* Concatenating two FASM files together, produces a FASM file.
* Sorting a FASM file does not change the resulting bitstream.

If two FASM files are identical, then the resulting bitstream should have identical set of features are enabled. FASM does support various equivalent forms for enabling features, so there is a "canonical" form of a FASM file that removes this variation. If the canonical forms of two FASM files are the same, then they must generate the same bitstream.

Lines
+++++

Examples FASM feature lines
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Canonical enabling of feature
`````````````````````````````

.. code-block:: text

    # Set a single feature bit to 1 (with an implicit 1)
    INT_L_X10Y146.SW6BEG0.WW2END0
    CLBLL_L_X12Y124.SLICEL_X0.BLUT.INIT[17]

Recommended bitarray
````````````````````

.. code-block:: text

    # Setting a bitarray
    CLBLL_R_X13Y132.SLICEL_X0.ALUT.INIT[63:32] = 32'b11110000111100001111000011110000

Permitted advanced variations
`````````````````````````````

.. code-block:: text

    # The bitarray syntax also allows explicit 1 and explicit 0, if verbosity is desired.
    # An explicit 1 is the same as an implicit 1.
    INT_L_X10Y146.SW6BEG0.WW2END0 = 1
    CLBLL_L_X12Y124.SLICEL_X0.BLUT.INIT[17] = 1
    # Explicit bit range to 1
    INT_L_X10Y146.SW6BEG0.WW2END0[0:0] = 1'b1
    CLBLL_L_X12Y124.SLICEL_X0.BLUT.INIT[17:17] = 1'b1
    
    # An explicit 0 has no effect on the bitstream output.
    INT_L_X10Y146.SW6BEG0.WW2END0 = 0
    CLBLL_L_X12Y124.SLICEL_X0.BLUT.INIT[17] = 0
    # Explicit bit range to 0
    INT_L_X10Y146.SW6BEG0.WW2END0[0:0] = 1'b0
    CLBLL_L_X12Y124.SLICEL_X0.BLUT.INIT[17:17] = 1'b0

Annotations
+++++++++++

To allow tools to output machine usable annotations (e.g. compiler metadata), annotations are supported. Annotations can be on the line with a FASM feature, or on a line by itself. An annotations must not change the output bitstream. If an annotation would have an affect on the output bitstream, it should be a FASM feature.

Annotations that are on the same line as a FASM feature are associated with the feature. Annotations that are on a line with no FASM feature as associated with the FASM file itself.

Example Annotations
~~~~~~~~~~~~~~~~~~~

.. code-block:: text

    # Annotation on a FASM feature
    INT_L_X10Y146.SW6BEG0.WW2END0 { .attr = "" }
    INT_L_X10Y146.SW6BEG0.WW2END0 { .filename = "/a/b/c.txt" }
    INT_L_X10Y146.SW6BEG0.WW2END0 { module = "top", file = "/a/b/d.txt", line_number = "123" }
    
    # Annotation by itself
    { .top_module = "/a/b/c/d.txt" }
    
    # Annotation with FASM feature and comment
    INT_L_X10Y146.SW6BEG0.WW2END0 { .top_module = "/a/b/c/d.txt" } # This is a comment
    
Formal syntax specification of a line of a FASM file
++++++++++++++++++++++++++++++++++++++++++++++++++++

.. code-block:: text

    Identifier ::= [a-zA-Z] [0-9a-zA-Z]*
    Feature ::= Identifier ( '.' Identifier )*
    S ::= #x9 | #x20
    
    DecimalValue ::= [0-9_]*
    HexidecimalValue ::= [0-9a-fA-F_]+
    OctalValue ::= [0-7_]+
    BinaryValue ::= [01_]+
    
    VerilogValue ::= (( DecimalValue? S* "'" ( 'h' S* HexidecimalValue | 'b' S* BinaryValue | 'd' S*  DecimalValue | 'o' S* OctalValue ) | DecimalValue )
    
    FeatureAddress ::= '[' DecimalValue (':' DecimalValue)? ']'
    
    Any ::= [^#xA#]
    Comment ::= '#' Any*
    
    AnnotationName ::= [.a-zA-Z] [_0-9a-zA-Z]*
    NonEscapeCharacters ::= [^\"]
    EscapeSequences ::= '\\' | '\"'
    Annotation ::= AnnotationName S* '=' S* '"' (NonEscapeCharacters | EscapeSequences)* '"'
    Annotations ::= '{' S* Annotation ( ',' S* Annotation )* S* '}'
    
    SetFasmFeature ::= Feature FeatureAddress? S* ('=' S* VerilogValue)?
    FasmLine ::= S* SetFasmFeature? S* Annotations? S* Comment?

Canonicalization
++++++++++++++++

If two FASM files have been canonicalized, then they enable an identical set of features. The canonical FASM file is also equivalent to the FASM file that would be generated by taking the output bitstream and converting it back into a FASM file.

The canonicalization process is as follows:

#. Flatten any ``FeatureAddress`` with width greater than 1.

   * For ``SetFasmFeature`` lines with a ``FeatureAddress`` width greater than 1 bit, 1 ``SetFasmFeature`` for the width the original ``FeatureAddress``.
   * When flattening, if the flattened address is 0, do not emit the address.
#. Remove all comments and annotations.
#. If the ``FeatureValue`` is 0, remove the FASM line.
#. If the ``FeatureValue`` is 1, only output the ``Feature`` and the ``FeatureAddress`` if the ``Feature`` has addresses other than 0.
#. Remove any lines that do not modify the default bitstream.

   * Example are psuedo-pips in Xilinx parts.
#. Sort the lines in the FASM file.

Example Canonicalization
~~~~~~~~~~~~~~~~~~~~~~~~

``ALUT.INIT[0] = 1``

becomes

``ALUT.INIT``

----

``ALUT.SMALL = 1``

becomes

``ALUT.SMALL``

----

``ALUT.INIT[3:0] = 4'b1101``

becomes

``ALUT.INIT``

``ALUT.INIT[2]``

``ALUT.INIT[3]``

Meaning of a FASM line
----------------------

.. csv-table:: Simplified ``SetFasmFeature``
    :delim: |
    :header-rows: 1
    
    YYYY.XXXXX   | [A:B]              | = C
    ``Feature``  | ``FeatureAddress`` | ``FeatureValue``
    **Required** | *Optional*         | *Optional*

Each line of a FASM file that enables a feature is defined by a ``SetFasmFeature``. Table 1 provides a simplified ``SetFasmFeature`` parse has three parts, the feature to be set (``Feature``), the address within the feature to be set (``FeatureAddress``) and the value of the feature (``FeatureValue``). Both the ``FeatureAddress`` and ``FeatureValue`` are optional.

When a FASM file declares that a feature is to be enabled or disabled, then specific bits in the bitstream will be cleared or set.

This section describes how the state of the bits are determined.

Feature
+++++++

The ``Feature`` should uniquely specify a feature within the bitstream.  If the feature is repeated across FPGA elements, a prefix identifier is required to uniquely identify where a feature is located.

For example all SLICEL tiles have ALUT.INIT feature, however each tile CLBLL_L tile actually have two SLICEL, and there are many CLBLL_L tiles with a 7-series FPGA.  So a unique path would required to both clarify which tile is being set, and which SLICEL within the tile is being set.

FeatureAddress and FeatureValue
+++++++++++++++++++++++++++++++

If the ``FeatureAddress`` is not specified, then the address selected is 0.

If the ``FeatureValue`` is not specified, then the value is 1.

If the ``FeatureAddress`` is specified as a specific bit rather than a range (e.g. "[5]"), then the ``FeatureValue`` width must be 1-bit wide (e.g. 0 or 1). If the ``FeatureAddress`` is a range (e.g. "[15:0]"), then the ``FeatureValue`` width must be equal or less than the ``FeatureAddress`` width. It is invalid to specific a ``FeatureValue`` wider than the ``FeatureAddress``.

For example, if the ``FeatureAddress`` was [15:0], then the address width is 16 bits, and the ``FeatureValue`` must be 16 bits or less. So a ``FeatureValue`` of 16'hFFFF is valid, but a ``FeatureValue`` of 17'h10000 is invalid.

When the ``FeatureAddress`` is wider than 1 bit, the ``FeatureValue`` is shifted and masked for each specific address before enabling or disabling the feature. So for a ``FeatureAddress`` of [7:4], the feature at address 4 is set with a value of (``FeatureValue`` >> 0) & 1, and the feature at address 5 is set with a value of (``FeatureValue`` >> 1) & 1, etc.

If the value of a feature is 1, then the output bitstream must clear and set all bits as specified.
If the value of a feature is 0, then no change to the "default" bitstream is made.

Note that the absence of a FASM feature line does not imply that the feature is set to 0. It only means that the relevant bits are used from the implementation specific "default" bitstream.

