/*
 * Copyright:   Copyright Johannes Teichrieb 2015 - 2019
 * License:     opensource.org/licenses/MIT
 */
module util.removecomments;

import std.regex;
import std.algorithm.searching;
import std.range;

class NoMatchException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe
    {
        super(msg, file, line, next);
    }
}

private:
enum lineCommentStart = "//";
enum blockCommentStart = "/*";
enum stringStart = `"`;

/* Removes C-style comments and strings to allow easier parsing of source files.
Block comments are replaced with a space.
Strings are replaced with given argument.
For simplicity, also removes unterminated block comment or string
at the end of the input (printing a warning).  */
public string removeCommentsReplaceStrings(string strReplacement = " s ")(string s) pure @trusted
{
    import std.array : Appender;
    Appender!string app;
    app.reserve(s.length);

    while (true)
    {
        auto start = s.findNextStart();
        if (start.empty)
        {
            app.put(s);
            return app.data;
        }

        auto preStart = s[0 .. start.ptr - s.ptr];
        app.put(preStart);

        auto postStart = s[start.ptr - s.ptr + start.length .. $];
        s = postStart;

        app.put(getReplacement!strReplacement(start));

        try
        {
            s = getPostFunction(start)(s);
        }
        catch (NoMatchException)
        {
            s = s.getLineTerminatorAtBack();
        }
    }

    return app.data;
}

string findNextStart(string s) pure
{
    size_t i;
    while (i < s.length)
    {
        const c = s[i];
        const bool isCharOfInterest = c == '/' || c == '"';
        if (isCharOfInterest)
        {
            s = s[i .. $];
            if (s[0] == '"')
                return s[0 .. 1];

            // s[0] == '/'
            if (s.length >= 2 && (s[1] == '/' || s[1] == '*'))
                return s[0 .. 2];

            i = 0;
        }
        i++;
    }

    return null;
}

string getReplacement(string strReplacement)(string matchedStart)
{
    if (matchedStart == lineCommentStart)
        return "";

    if (matchedStart == blockCommentStart)
        return " ";

    if (matchedStart == stringStart)
        return strReplacement;

    assert(0);
}

string function(string) pure getPostFunction(string matchedStart) pure nothrow @safe
{
    if (matchedStart == lineCommentStart)
        return &postLineComment;

    if (matchedStart == blockCommentStart)
        return &postBlockComment;

    if (matchedStart == stringStart)
        return &postString;

    assert(0);
}

// single CR as line terminator is not supported
string postLineComment(string s) pure @trusted
{
    auto hit = s.find('\n');
    if (hit.empty)
        throw new NoMatchException(null);

    bool isLfPrecededByCr = hit.ptr > s.ptr && hit.ptr[-1] == '\r';
    if (!isLfPrecededByCr)
        return hit;
    else
        return (hit.ptr - 1)[0 .. hit.length + 1];
}

string postBlockComment(string s) pure @safe
{
    auto hit = s.find("*/");
    if (hit.empty)
        throw new NoMatchException(null);

    return hit[2 .. $];
}

string postString(string s) pure @safe
{
    while (true)
    {
        auto hit = s.find('"');
        if (hit.empty)
            throw new NoMatchException(null);

        if (getPrecedingBackslashCount(s, &hit[0]) % 2 == 0)
            return hit[1 .. $];
        else
            s = hit[1 .. $];
    }
}

auto getPrecedingBackslashCount(string s, immutable(char)* cp) pure nothrow @trusted
{
    size_t count = 0;
    while (s.ptr < cp && *(--cp) == '\\')
        ++count;

    return count;
}

string getLineTerminatorAtBack(string s) pure nothrow @safe
{
    if (s.endsWith("\r\n"))
        return "\r\n";

    if (s.endsWith("\n"))
        return "\n";

    return null;
}

// removeCommentsReplaceStrings()
// cover some simple cases before going over test files

@("empty input") unittest
{
    assert("" == "".removeCommentsReplaceStrings);
}

@("single char") unittest
{
    assert(" " == " ".removeCommentsReplaceStrings);
    assert("\n" == "\n".removeCommentsReplaceStrings);
    assert("/" == "/".removeCommentsReplaceStrings);
}

@("string") unittest
{
    assert("" == `"the quick brown fox"`.removeCommentsReplaceStrings!"");
    assert(" token " == `"hello /* there */"`.removeCommentsReplaceStrings!" token ");
}

@("comment") unittest
{
    assert("" == "// hello".removeCommentsReplaceStrings);
    assert("\n" == "// hello\n".removeCommentsReplaceStrings);
    assert("\n\n" == "\n// hello\n".removeCommentsReplaceStrings);
}

@("block comment") unittest
{
    assert(" " == "/* hello */".removeCommentsReplaceStrings);
    assert(" \n" == "/* hello */\n".removeCommentsReplaceStrings);
    assert(" " == "/* the \n quick \n */".removeCommentsReplaceStrings);
    assert("\n \n" == "\n/* the \n quick \n */\n".removeCommentsReplaceStrings);
}

@("removeCommentsReplaceStrings test inputs") unittest
{
    import std.file;

    enum expectSuffix = "-expect";

    string[] getTestInputFilenames()
    {
        string[] result;
        enum testFilesDir = "test/removeCommentsReplaceStrings";
        foreach (DirEntry e; dirEntries(testFilesDir, SpanMode.depth, false))
            if (e.isFile && !e.name.endsWith(expectSuffix))
                result ~= e.name;

        return result;
    }

    foreach (filename; getTestInputFilenames()) {
        auto input = cast(string) read(filename);
        auto expectedOutput = readText(filename ~ expectSuffix);
        assert(input.removeCommentsReplaceStrings!" "() == expectedOutput, filename);
    }
}
