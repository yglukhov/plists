===========
plists
===========

Generate and parse Mac OS X `.plist` files in `Nim <https://github.com/nim-lang/nim>`_.
The library uses Nim's JsonNode as a primary data structure.

Quick start
===========

Installation
------------
.. code-block:: sh

    nimble install plists

Usage
------------
.. code-block:: nim

    import plists, json

    let p : JsonNode = loadPlist("/Applications/Calculator.app/Contents/Info.plist")
    doAssert(p["CFBundleExecutable"].str == "Calculator")
    writePlist(p, "test.plist")
