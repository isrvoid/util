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
        import std.regex : matchFirst;

        cap = matchFirst(toParse, r);
        if (!cap.empty)
            convCap();

        toParse = cap.post;
    }

    void convCap() pure @trusted
    {
        import std.format : format;

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

    import std.regex : ctRegex, Captures;
    enum aspectEnumNamePattern = r"enum\s+class\s+(\w*Aspect)";
    enum aspectEnumPattern = aspectEnumNamePattern ~ r"[^{]*\{([^}]*)\}\s*;";
    static const r = ctRegex!aspectEnumPattern;

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
    string input = "#include <cstdio>\n\nclass Foo { int i; };\n";
    auto parser = Parser(input);
    assert(parser.empty);
}

@("non aspect enum") unittest
{
    string input = "#include <cstddef>\n\nenum class Foo { one, two };\n";
    auto parser = Parser(input);
    assert(parser.empty);
}

@("aspect enum") unittest
{
    string input = "#include <cstdint>\n\nenum class Aspect { foo, _end };\n";
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
    string input = "enum class FooAspect {bar,_end};";
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
    string input = "enum class Aspect { foo\n, _end ,\n };";
    auto res = Parser(input).front;
    assert(["foo"] == res.e);
    assert(0 == res.offset);
}

@("popFront") unittest
{
    string input = "enum class Aspect { foo, _end };";
    auto parser = Parser(input);
    assert(!parser.empty);
    parser.popFront();
    assert(parser.empty);
}

@("specified type") unittest
{
    string input = "enum class Aspect:unsinged\nint{\none,\n_end\n};\n";
    assert(["one"] == Parser(input).front.e);
}

@("commented enums") unittest
{
    string input = "enum class Aspect { one, // the quick brown fox
        // jumps over\n  two,\n  _end /* _end enum */,  };";
    auto res = Parser(input).front;
    assert(["one", "two"] == res.e);
    assert(0 == res.offset);
}

@("two enums") unittest
{
    import std.algorithm : findSplitAfter;
    string input = "enum class AAspect : int\n{\none,two,_end }\n;
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
    string input = "enum class Aspect { foo = 0, _end };";
    auto res = Parser(input).front;
    assert(["foo"] == res.e);
    assert(0 == res.offset);
}

@("assign") unittest
{
    string input = "enum class Aspect { foo = 42, bar, _end };";
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
    // this would result in a large LUT, but it's not for parser to decide
    assert(1000000 == Parser("enum class Aspect { foo = 1000000, _end };").front.offset);
}

@("slightly convoluted input") unittest
{
    import std.file : readText;
    string input = readText("test/aspectnames/miscaspects.h");

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
