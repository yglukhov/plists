import xmltree, xmlparser, json, strutils, streams
export json

proc plistXMLToJson(node: XmlNode): JsonNode =
    case node.tag
    of "dict":
        result = newJObject()
        var isKey = true
        var key = ""
        for n in node:
            if isKey:
                key = n.innerText
                isKey = false
            else:
                result[key] = plistXMLToJson(n)
                isKey = true
    of "string":
        result = newJString(node.innerText)
    of "integer":
        result = newJInt(parseInt(node.innerText))
    of "real":
        result = newJFloat(parseFloat(node.innerText))
    of "true":
        result = newJBool(true)
    of "false":
        result = newJBool(false)
    of "array":
        result = newJArray()
        for n in node:
            result.add(plistXMLToJson(n))
    of "plist":
        result = plistXMLToJson(node[0])
    else:
        echo "ERROR! ", node.tag

when defined(macosx):
    import darwin/core_foundation

    proc CFPropertyListToJson(p: CFPropertyList): JsonNode =
        let tid = p.getTypeId()
        if tid == CFArrayGetTypeId():
            result = newJArray()
            let p = cast[CFArray[CFPropertyList]](p)
            for e in p:
                result.add(CFPropertyListToJson(e))
        elif tid == CFDictionaryGetTypeId():
            let p = cast[CFDictionary[CFString, CFPropertyList]](p)
            result = newJObject()
            for k, v in p:
                result[$k] = CFPropertyListToJson(v)
        elif tid == CFStringGetTypeId():
            result = newJString($cast[CFString](p))
        elif tid == CFNumberGetTypeId():
            let p = cast[CFNumber](p)
            result = if p.isFloatType:
                newJFloat(p.getFloat)
            else:
                newJInt(p.getInt64)
        elif tid == CFBooleanGetTypeId():
            result = newJBool(cast[CFBoolean](p).value)

    proc CFStreamToJson(s: CFReadStream): JsonNode =
        if not s.isNil:
            if s.open():
                let pl = CFPropertyListCreateWithStream(nil, s, 0, kCFPropertyListImmutable, nil, nil)
                if not pl.isNil:
                    result = CFPropertyListToJson(pl)
                    pl.release()
            s.release()

proc jsonToPlistXML(node: JsonNode): XmlNode =
    case node.kind
    of JString:
        result = newElement("string")
        result.add(newText(node.str))
    of JInt:
        result = newElement("integer")
        result.add(newText($node.num))
    of JFloat:
        result = newElement("real")
        result.add(newText($node.fnum))
    of JBool:
        result = newElement($node.bval)
    of JNull:
        result = newElement("integer")
        result.add(newText("0"))
    of JObject:
        result = newElement("dict")
        for k, v in node:
            let key = newElement("key")
            key.add(newText(k))
            result.add(key)
            result.add(jsonToPlistXML(v))
    of JArray:
        result = newElement("array")
        for v in node.elems:
            result.add(jsonToPlistXML(v))

proc writePlistXML*(node: XmlNode, s: Stream) =
    s.write(xmlHeader)
    s.write("<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\x0A")
    s.write("<plist version=\"1.0\">\x0A")
    s.write(($node).replace(" />", "/>"))
    s.write("\L</plist>\L")

proc writePlistXML*(node: XmlNode, path: string) =
    let s = newFileStream(path, fmWrite)
    writePlistXML(node, s)
    s.close()

proc writePlist*(node: JsonNode, path: string) = writePlistXML(jsonToPlistXML(node), path)
proc writePlist*(node: JsonNode, s: Stream) = writePlistXML(jsonToPlistXML(node), s)

proc parsePlist*(s: Stream): JsonNode =
    when defined(macosx):
        var c = s.readAll()
        if c.len != 0:
            let s = CFReadStreamCreateWithBytesNoCopy(nil, addr c[0], c.len, kCFAllocatorNull)
            result = CFStreamToJson(s)
    else:
        plistXMLToJson(parseXml(s))

proc loadPlist*(path: string): JsonNode =
    when defined(macosx):
        let p = CFStringCreate(path)
        let u = CFURLCreateWithFileSystemPath(nil, p, kCFURLPOSIXPathStyle, 0)
        p.release()
        if not u.isNil:
            let s = CFReadStreamCreateWithFile(nil, u)
            u.release()
            if not s.isNil:
                result = CFStreamToJson(s)
    else:
        plistXMLToJson(loadXml(path))

when isMainModule:
    const samplePlist = """<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>testDict</key>
    <dict>
        <key>key1</key>
        <string>val1</string>
    </dict>
    <key>testArray</key>
    <array>
        <integer>123</integer>
        <integer>456</integer>
        <false/>
        <true/>
    </array>
</dict>
</plist>
"""
    let p = parsePlist(newStringStream(samplePlist))
    doAssert(p["testDict"]["key1"].str == "val1")
    doAssert(p["testArray"][0].num == 123)
    doAssert(p["testArray"][1].num == 456)
    doAssert(p["testArray"][2].bval == false)
    doAssert(p["testArray"][3].bval == true)
