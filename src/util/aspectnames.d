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
 * - no commented out '{' or '}' between Aspect's 'enum' and ';'
 *
 * comments within { } are fine
 * verifying enum values is problematic:
 * - can't determine foo = VAL without preprocessor
 * - can't determine foo = AnotherEnum::bar without compiling
 * We only allow assignment of numeric offset >= 0 to the first enum: foo = 1.
 * Extended version which allows
 * - assignment to arbitrary enums: foo, bar = 2
 * - assignment of own enumerators: foo, bar = foo + 2
 * would need to detect collisions:
 * (foo, bar = foo), (foo = 2, bar, baz = 2), (foo, bar, baz = foo + 1), etc.
 * Without collision detection, names could be wrong,
 *      which is much worse than prohibiting arbitrary assignment.
 * '_end' enumerator:
 * - no check, if missing -- it would fail to compile later anyway
 * - if present, verified to be the last enum
 * - no name is generated for it
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
        _front.elem = convElem(cap[2]);
        const pPost = cap.post.ptr;
        const pInput = input.ptr;
        _front.upToPost = pInput[0 .. pPost - pInput];
        _front.post = cap.post;
    }

    string[] convElem(string s) pure const
    {
        import std.algorithm : map, filter, findSplitBefore;
        import std.array : array, split;
        import std.string : strip;
        return s
            .removeCommentsReplaceStrings
            .split(',')
            .map!(a => a.findSplitBefore("=")[0].strip)
            .filter!`a.length && a != "_end"`
            .array;
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

@("trailing ,") unittest
{
    string input = "enum class Aspect { foo,\n };";
    assert(["foo"] == Parser(input).front.elem);
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

@("assign 0 has no effect") unittest
{
    string input = "enum class Aspect { foo = 0 };";
    auto parser = Parser(input);
    assert(["foo"] == parser.front.elem);
}

@("assign") unittest
{
    string input = "enum class Aspect { foo = 1, bar };";
    auto parser = Parser(input);
    assert(["", "foo", "bar"] == parser.front.elem);
}

// TODO
// assign < 0 throws
// assign following enum throws
// _end not being last throws
