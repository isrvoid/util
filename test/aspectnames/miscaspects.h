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
    bOne = 42,
    /* might insert another one here */
    bTwo, // second
    end,
    // this end is normal enum
    _end,
};

namespace c {

class Bar {
    double a, b;
};

enum class ModuleCAspect : unsigned int /* why not leave it int? */
{
    cOne = 16
    // there
    , cTwo, _end_wrong/* another fake end */, _end // _end
} ;

} // namespace c
} // namespace b

void somefunc();
int anotherfunc();

} // namespace package
