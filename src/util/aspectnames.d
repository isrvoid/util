/*
 * Copyright:   Copyright Johannes Teichrieb 2019
 * License:     opensource.org/licenses/MIT
 */
module util.aspectnames;

import std.regex : ctRegex, matchAll;
import std.file : readText;
import std.stdio : writeln; // FIXME remove

import util.removecomments;

version (unittest) { } else
void main()
{
    enum r = ctRegex!r"enum\s+class\s+(\w*Aspect)[^{]*\{([^}]*)\}\s*;";
    auto text = readText("test/aspectnames/package.h");
    foreach (c; matchAll(text, r))
    {
        writeln("match: ", c[1]);
        writeln(c[2].removeCommentsReplaceStrings);
    }
}
