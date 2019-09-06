/*
 * Copyright:   Copyright Johannes Teichrieb 2019
 * License:     opensource.org/licenses/MIT
 */
module util.aspectnames;

/*
 * specification:
 *
 * aspectnames sides with simplicity, incurring slight syntax restrictions:
 * - don't comment out enum class Aspect definition
 * - no comments or macros between enum and opening {
 * - don't use preprocessor within enum class Aspect { } block (macros, include, conditional)
 * - no commented out '{' or '}' between Aspect's 'enum' and ';'
 * - comments within { } are fine
 *
 * verifying enum values is problematic:
 * - can't determine foo = VAL without preprocessor
 * - can't determine foo = AnotherEnum::bar without compiling
 * We'll only allow assignment of numeric offset >= 0 to the first enum.
 *
 * Extended version which allows
 * - assignment to arbitrary enums: foo, bar = 2
 * - assignment of own enumerators: foo, bar = foo + 2
 * would need to detect collisions:
 * (foo, bar = foo), (foo = 2, bar, baz = 2), (foo, bar, baz = foo + 1), etc.
 * Without collision detection, names could be wrong,
 *      which is much worse than prohibiting arbitrary assignment.
 *
 * '_end' enumerator at the end is required; no name is generated for it
 */

import util.removecomments;
import std.format : format;
import std.array : Appender;
import std.regex : ctRegex, Captures, matchFirst;

@safe:

version (unittest) { } else
void main()
{
}

class ParseException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow
    {
        super(msg, file, line, next);
    }
}

struct Parser
{
    struct Aspect
    {
        string name;
        string[] e;
        uint offset;

        string upToPost;
        string post;
    }

    this(string _input)
    {
        input = _input;
        toParse = input;
        matchNext();
    }

    bool empty() pure nothrow const
    {
        return cap.empty;
    }

    Aspect front() pure
    in (!empty)
    {
        return _front;
    }

    void popFront()
    in (!empty)
    {
        matchNext();
    }

private:
    void matchNext()
    {
        cap = matchFirst(toParse, r);
        if (!cap.empty)
            convCap();

        toParse = cap.post;
    }

    void convCap() pure @trusted
    {
        _front.name = cap[1];
        try
            _front.e = convEnums(cap[2], _front.offset);
        catch (ParseException e)
            throw new ParseException(format!"Failed to parse '%s': %s"(_front.name, e.msg));

        const pPost = cap.post.ptr;
        const pInput = input.ptr;
        _front.upToPost = pInput[0 .. pPost - pInput];
        _front.post = cap.post;
    }

    string[] convEnums(string s, out uint offset) pure const
    {
        import std.algorithm : map, filter, canFind;
        import std.array : array, split;
        import std.string : strip;

        string[] enums = s
            .removeCommentsReplaceStrings
            .split(',')
            .map!strip
            .filter!"a.length"
            .array;

        if (enums.length < 2)
            throw new ParseException("Aspect should have at least 2 enums (including '_end')");

        foreach (e; enums[1 .. $])
            if (e.canFind('='))
                throw new ParseException("Only first enumerator can be assigned");

        if (enums[$ - 1] != "_end")
            throw new ParseException("Missing '_end' enumerator");

        enums = enums[0 .. $ - 1];

        uint getOffsetStrippingEq(ref string s)
        {
            import std.algorithm : findSplit;
            import std.conv : to;

            if (!s.canFind('='))
                return 0;

            auto enumAndVal = s.findSplit("=");
            s = enumAndVal[0].strip;

            uint offset;
            try
                offset = enumAndVal[2].strip.to!uint;
            catch (Exception)
                throw new ParseException("Only positive integers can be assigned");

            return offset;
        }

        offset = getOffsetStrippingEq(enums[0]);
        return enums;
    }

    enum aspectEnumNamePattern = r"enum\s+class\s+(\w*Aspect)";
    enum aspectEnumPattern = aspectEnumNamePattern ~ r"[^{]*\{([^}]*)\}\s*;";
    static immutable r = ctRegex!aspectEnumPattern;

    string input;
    string toParse;
    Captures!string cap;
    Aspect _front;
}

version (unittest)
import std.exception : assertThrown;

@("empty input") unittest
{
    auto parser = Parser("");
    assert(parser.empty);
}

@("non empty input") unittest
{
    const input = "#include <cstdio>\n\nclass Foo { int i; };\n";
    auto parser = Parser(input);
    assert(parser.empty);
}

@("non aspect enum") unittest
{
    const input = "#include <cstddef>\n\nenum class Foo { one, two };\n";
    auto parser = Parser(input);
    assert(parser.empty);
}

@("aspect enum") unittest
{
    const input = "#include <cstdint>\n\nenum class Aspect { foo, _end };\n";
    auto parser = Parser(input);
    assert(!parser.empty);
    assert("Aspect" == parser.front.name);
    assert(["foo"] == parser.front.e);
    assert(0 == parser.front.offset);
    assert(input[0 .. $ - 1] == parser.front.upToPost);
    assert("\n" == parser.front.post);
}

@("empty post") unittest
{
    const input = "enum class FooAspect {bar,_end};";
    auto parser = Parser(input);
    auto res = parser.front;
    assert("FooAspect" == res.name);
    assert(["bar"] == res.e);
    assert(0 == res.offset);
    assert(input == res.upToPost);
    assert(!res.post.length);
}

@("trailing ,") unittest
{
    const input = "enum class Aspect { foo\n, _end ,\n };";
    auto res = Parser(input).front;
    assert(["foo"] == res.e);
    assert(0 == res.offset);
}

@("popFront") unittest
{
    const input = "enum class Aspect { foo, _end };";
    auto parser = Parser(input);
    assert(!parser.empty);
    parser.popFront();
    assert(parser.empty);
}

@("specified type") unittest
{
    const input = "enum class Aspect:unsinged\nint{\none,\n_end\n};\n";
    assert(["one"] == Parser(input).front.e);
}

@("commented enums") unittest
{
    const input = "enum class Aspect { one, // the quick brown fox
        // jumps over\n  two,\n  _end /* _end enum */,  };";
    auto res = Parser(input).front;
    assert(["one", "two"] == res.e);
    assert(0 == res.offset);
}

@("two enums") unittest
{
    import std.algorithm : findSplitAfter;
    const input = "enum class AAspect : int\n{\none,two,_end }\n;
                    enum class BAspect :unsigned int{ three, four, _end } ;
    ";
    auto parser = Parser(input);
    auto res = parser.front;
    assert("AAspect" == res.name);
    assert(["one", "two"] == res.e);

    auto a = input.findSplitAfter(";");
    assert(a[0] == res.upToPost);
    assert(a[1] == res.post);

    parser.popFront();
    assert(!parser.empty);
    res = parser.front;

    assert("BAspect" == res.name);
    assert(["three", "four"] == res.e);

    auto b = a[1].findSplitAfter(";");
    assert(a[0] ~ b[0] == res.upToPost);
    assert(b[1] == res.post);
    parser.popFront();
    assert(parser.empty);
}

@("assign 0 has no effect") unittest
{
    const input = "enum class Aspect { foo = 0, _end };";
    auto res = Parser(input).front;
    assert(["foo"] == res.e);
    assert(0 == res.offset);
}

@("assign") unittest
{
    const input = "enum class Aspect { foo = 42, bar, _end };";
    auto parser = Parser(input);
    assert(["foo", "bar"] == parser.front.e);
    assert(42 == parser.front.offset);
}

@("assign negative int throws") unittest
{
    assertThrown(Parser("enum class Aspect { foo = -1, bar, _end };"));
}

@("assing non int throws") unittest
{
    assertThrown(Parser("enum class Aspect { foo = FIRST, _end };"));
}

@("assign following element throws") unittest
{
    assertThrown(Parser("enum class Aspect { foo = 1, bar = 3, _end };"));
    assertThrown(Parser("enum class Aspect { foo, bar = 2, _end };"));
}

@("'_end' not being last throws") unittest
{
    assertThrown(Parser("enum class Aspect { foo, _end, bar };"));
}

@("large offset") unittest
{
    // this would result in a large LUT, but it's not parser's concern
    assert(1000000 == Parser("enum class Aspect { foo = 1000000, _end };").front.offset);
}

@("slightly convoluted input") unittest
{
    import std.file : readText;
    const input = readText("test/aspectnames/miscaspects.h");

    auto parser = Parser(input);
    assert("ModuleAAspect" == parser.front.name);
    assert(["aOne", "aTwo"] == parser.front.e);
    assert(0 == parser.front.offset);

    parser.popFront();
    assert("Aspect" == parser.front.name);
    assert(["bOne", "bTwo", "end"] == parser.front.e);
    assert(42 == parser.front.offset);

    parser.popFront();
    assert("ModuleCAspect" == parser.front.name);
    assert(["cOne", "cTwo", "_end_wrong"] == parser.front.e);
    assert(16 == parser.front.offset);

    parser.popFront();
    assert(parser.empty);
}

private enum NameLutQualifier = "static constexpr const char* ";

string makeNameLut(string aspectName, string[] enums, uint offset) pure
in (enums)
{
    enum : string {
        qualifier = NameLutQualifier,
        postName = "Name[] = {\n",
        indent = "    "
    }

    enum offsetMax = 256;
    if (offset > offsetMax)
        throw new Exception(format!"Offset %d would result in a large LUT. Max offset: %d"(offset, offsetMax));

    Appender!string app;
    app ~= qualifier;
    app ~= aspectName;
    app ~= postName;

    foreach (i; 0 .. offset)
    {
        app ~= indent;
        app ~= "nullptr,\n";
    }

    app ~= indent;
    app ~= enums[0];
    enums = enums[1 .. $];

    while (enums.length)
    {
        app ~= ",\n";
        app ~= indent;
        app ~= enums[0];
        enums = enums[1 .. $];
    }
    app ~= "\n};\n";

    return app.data;
}

@("single enumerator") unittest
{
    const expect = NameLutQualifier ~ "AspectName[] = {\n    foo\n};\n";
    assert(expect == makeNameLut("Aspect", ["foo"], 0));
}

@("two enumerators") unittest
{
    const expect = NameLutQualifier ~ "FooBarAspectName[] = {\n    foo,\n    bar\n};\n";
    assert(expect == makeNameLut("FooBarAspect", ["foo", "bar"], 0));
}

@("multiple enumerators") unittest
{
    const expect = NameLutQualifier ~ "NumberAspectName[] = {\n"
        ~ "    one,\n    two,\n    three\n};\n";
    assert(expect == makeNameLut("NumberAspect", ["one", "two", "three"], 0));
}

@("offset single enumerator") unittest
{
    const expect = NameLutQualifier ~ "FooAspectName[] = {\n    nullptr,\n    foo\n};\n";
    assert(expect == makeNameLut("FooAspect", ["foo"], 1));
}

@("offset multiple enumerators") unittest
{
    const expect = NameLutQualifier ~ "NumberAspectName[] = {\n    nullptr,\n    nullptr,\n"
        ~ "    nullptr,\n    nullptr,\n    one,\n    two,\n    three\n};\n";
    assert(expect == makeNameLut("NumberAspect", ["one", "two", "three"], 4));
}

private enum includeFileNamePrefix = "_gen_";
private enum includeComment = " // generated\n";

string maybeUpdateInclude(string s) @trusted
{
    import std.algorithm : find;
    static immutable r = ctRegex!(`^\s*#include "` ~ includeFileNamePrefix ~ `(\w*Aspect)Name.h"`);

    auto parser = Parser(s);
    if (parser.empty)
        return s;

    immutable (char)* tail = parser.front.upToPost.ptr;
    Appender!string app;
    void appendInclude()
    {
        app ~= "\n\n";
        app ~= parser.front.name.getInclude;
        app ~= includeComment;
    }

    for (; !parser.empty; parser.popFront())
    {
        immutable char* tailEnd = parser.front.upToPost.ptr + parser.front.upToPost.length;
        app ~= tail[0 .. tailEnd - tail];
        tail = parser.front.post.ptr;

        auto cap = parser.front.post.matchFirst(r);
        const bool missing = cap.empty;
        const bool wrongName = !cap.empty && cap[1] != parser.front.name;
        if (wrongName)
            tail = cap.post.find('\n').ptr; // strip old include

        if (missing || wrongName)
            appendInclude();
    }
    immutable char* tailEnd = s.ptr + s.length;
    app ~= tail[0 .. tailEnd - tail];
    return app.data;
}

private string getInclude(string aspectName) pure nothrow
{
    Appender!string app;
    app ~= "#include \"";
    app ~= includeFileNamePrefix;
    app ~= aspectName;
    app ~= "Name.h\"";
    return app.data;
}

@("getInclude") unittest
{
    const expect = "#include \"" ~ includeFileNamePrefix ~ "FooAspectName.h\"";
    assert(expect, getInclude("FooAspect"));
}

@("no effect on non aspect enum") unittest
{
    const input = "#inclue <cstdio>\n\nenum class Foo {\nfoo,\nbar\n};\n";
    assert(input == input.maybeUpdateInclude);
}

@("missing include is inserted") unittest
{
    const input = "#include <cstdint>\n\nenum class FooAspect { foo, _end };";
    const expect = input ~ "\n\n" ~ "FooAspect".getInclude ~ includeComment;
    assert(expect == input.maybeUpdateInclude);
}

@("matching include is not changed") unittest
{
    const input = "#include <cstddef>\n\nenum class FooAspect { foo, _end };\n" ~ "FooAspect".getInclude;
    assert(input == input.maybeUpdateInclude);
}

@("include is overwritten on name mismatch") unittest
{
    const input = "enum class FooAspect { foo, _end };\n" ~ "Aspect".getInclude;
    const expect = "enum class FooAspect { foo, _end };\n\n" ~ "FooAspect".getInclude ~ includeComment;
    assert(expect == input.maybeUpdateInclude);
}

@("two includes") unittest
{
    import std.file : readText;
    const input = readText("test/aspectnames/twoincludes.h");
    const expect = readText("test/aspectnames/twoincludes-expect.h");
    assert(expect == input.maybeUpdateInclude);
}

@("multiple misc includes") unittest
{
    import std.file : readText;
    const input = readText("test/aspectnames/multincludes.h");
    const expect = readText("test/aspectnames/multincludes-expect.h");
    assert(expect == input.maybeUpdateInclude);
}
