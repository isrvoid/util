/*
 * Copyright:   Copyright Johannes Teichrieb 2019
 * License:     opensource.org/licenses/MIT
 */
module util.aspectnames;

import std.regex : ctRegex, matchAll;
import std.file : readText;
import std.stdio : writeln; // FIXME remove

import util.removecomments;

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
    enum r = ctRegex!r"enum\s+class\s+(\w*Aspect)[^{]*\{([^}]*)\}\s*;";
    auto text = readText("test/aspectnames/package.h");
    foreach (c; matchAll(text, r))
    {
        writeln("match: ", c[1]);
        writeln(c[2].removeCommentsReplaceStrings);
    }
}
