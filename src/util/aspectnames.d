/*
 * Copyright:   Copyright Johannes Teichrieb 2019
 * License:     opensource.org/licenses/MIT
 */
module util.aspectnames;

import util.removecomments;

@safe:

/*
 * specification:
 *
 * aspectnames sides with simplicity, incurring slight syntax restrictions:
 * - don't comment out enum class Aspect definition
 * - no comments or macros between enum and opening {
 * - don't use preprocessor within enum class Aspect { } block (macros, include, conditional)
 *      exception: specifying enum values is fine: foo = FIRST,
 * - no commented out '{' or '}' between Aspect's 'enum' and ';'
 *
 * comments within { } are fine
 * verifying the value of last element is a separate concern
 *      (can't determine foo = VAL without preprocessor anyway)
 * verifying '_end' enumerator is a separate concern, it is simply ignored:
 * - no name is generated for _end
 * - no check for missing _end -- it would fail to compile later anyway
 * - _end not being the last element or assignment to it is up to developer:
 *      e.g.: (_end, any = _end) or (any, _end = any)
 */


version (unittest) { } else
void main()
{
}

struct Parser
{
    import std.regex : matchFirst;

    struct Aspect
    {
        string name;
        string[] elem;

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
    {
        return _front;
    }

    void popFront()
        in (!empty)
    {
        matchNext();
    }

    private void matchNext()
    {
        cap = matchFirst(toParse, r);
        if (!cap.empty)
            convCap();

        toParse = cap.post;
    }

    private void convCap() @trusted
    {
        import std.algorithm : map, filter;
        import std.array : array, split;
        import std.string : strip;
        _front.name = cap[1];
        _front.elem = cap[2]
            .removeCommentsReplaceStrings
            .strip
            .split(',')
            .map!strip
            .filter!`a != "_end"`
            .array;
        const pPost = cap.post.ptr;
        const pInput = input.ptr;
        _front.upToPost = pInput[0 .. pPost - pInput];
        _front.post = cap.post;
    }

    private
    {
        import std.regex : ctRegex, Captures;
        enum aspectEnumNamePattern = r"enum\s+class\s+(\w*Aspect)";
        enum aspectEnumPattern = aspectEnumNamePattern ~ r"[^{]*\{([^}]*)\}\s*;";
        static const r = ctRegex!aspectEnumPattern;

        string input;
        string toParse;
        Captures!string cap;
        Aspect _front;
    }
}

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

@("not aspect enum") unittest
{
    string input = "#include <cstddef>\n\nenum class Foo { one, two };\n";
    auto parser = Parser(input);
    assert(parser.empty);
}

@("empty aspect enum") unittest
{
    string input = "#include <cstdint>\n\nenum class Aspect { };\n// end\n";
    auto parser = Parser(input);
    assert(!parser.empty);
    assert("Aspect" == parser.front.name);
    assert(0 == parser.front.elem.length);
    assert(input[0 .. $ - 8] == parser.front.upToPost);
    assert("\n// end\n" == parser.front.post);
}

@("single element enum") unittest
{
    string input = "enum class FooAspect {foo};";
    auto parser = Parser(input);
    auto res = parser.front;
    assert("FooAspect" == res.name);
    assert(["foo"] == res.elem);
    assert(input == res.upToPost);
    assert("" == res.post);
}

@("popFront") unittest
{
    string input = "enum class Aspect {};";
    auto parser = Parser(input);
    assert(!parser.empty);
    parser.popFront();
    assert(parser.empty);
}

@("_end is ignored") unittest
{
    string input = "enum class Aspect { one, two, _end };";
    auto parser = Parser(input);
    assert(["one", "two"] == parser.front.elem);
}

@("two enums") unittest
{
    import std.algorithm : findSplitAfter;
    string input = "enum class AAspect{ one,two,_end } ;
                    enum class BAspect :unsigned int{ three, four, _end } ;
    ";
    auto parser = Parser(input);
    auto res = parser.front;
    assert("AAspect" == res.name);
    assert(["one", "two"] == res.elem);

    auto a = input.findSplitAfter(";");
    assert(a[0] == res.upToPost);
    assert(a[1] == res.post);

    parser.popFront();
    assert(!parser.empty);
    res = parser.front;

    assert("BAspect" == res.name);
    assert(["three", "four"] == res.elem);

    auto b = a[1].findSplitAfter(";");
    assert(a[0] ~ b[0] == res.upToPost);
    assert(b[1] == res.post);
    parser.popFront();
    assert(parser.empty);
}
