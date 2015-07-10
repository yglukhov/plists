import xmltree, xmlparser, json, strutils, streams

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
        for kv in node.fields:
            let k = newElement("key")
            k.add(newText(kv.key))
            result.add(k)
            result.add(jsonToPlistXML(kv.val))
    of JArray:
        result = newElement("array")
        for v in node.elems:
            result.add(jsonToPlistXML(v))

proc writePlistXML*(node: XmlNode, s: Stream) =
    s.write(xmlHeader)
    s.write("<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\x0A")
    s.write("<plist version=\"1.0\">\x0A")
    s.write($node)
    s.write("\x0A</plist>\x0A")

proc writePlistXML*(node: XmlNode, path: string) =
    let s = newFileStream(path, fmWrite)
    writePlistXML(node, s)
    s.close()

proc writePlist*(node: JsonNode, path: string) = writePlistXML(jsonToPlistXML(node), path)
proc writePlist*(node: JsonNode, s: Stream) = writePlistXML(jsonToPlistXML(node), s)

proc parsePlist*(s: Stream): JsonNode = plistXMLToJson(parseXml(s))
proc loadPlist*(path: string): JsonNode = plistXMLToJson(loadXml(path))

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
