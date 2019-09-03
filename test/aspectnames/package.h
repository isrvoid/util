#include <cstdio>

#include <bar.h>

namespace package {
namespace a {

enum class ModuleAAspect:int{ // sloppy spacing is not unheard of
    // some of these might have comments
    aOne, // first
    aTwo, /// another
    _end // required terminator
};

class Foo {
    int i;
};

} // namespace a

namespace b {

enum class Aspect {
    bOne,
    /* might insert another one here */
    bTwo, // second
    end
    // end missing _ is intended
};

namespace c {

class Bar {
    double a, b;
};

enum class ModuleCAspect : unsigned int /* why not leave it int? */
{
    cOne
    // there
    , cTwo, _end_wrong // finish
} ;

} // namespace c
} // namespace b

void somefunc();
int anotherfunc();

} // namespace package
