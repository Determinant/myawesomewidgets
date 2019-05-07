extern "C" {
    #include "lua.h"
    #include "lualib.h"
    #include "lauxlib.h"
}

#include <cmath>
#include <cstring>
#include <algorithm>

/* color model conversion is adopted from:
 * https://stackoverflow.com/a/6930407/544806 */

struct RGB {
    double r;       // a fraction between 0 and 1
    double g;       // a fraction between 0 and 1
    double b;       // a fraction between 0 and 1

    RGB() = default;
    RGB(double r, double g, double b): r(r), g(g), b(b) {}
};

struct HSV {
    double h;       // angle in degrees
    double s;       // a fraction between 0 and 1
    double v;       // a fraction between 0 and 1
};

static HSV rgb2hsv(RGB in) {
    HSV out;
    double min, max, delta;

    min = in.r < in.g ? in.r : in.g;
    min = min < in.b ? min : in.b;

    max = in.r > in.g ? in.r : in.g;
    max = max > in.b ? max : in.b;

    out.v = max; // v
    delta = max - min;
    if (delta < 0.00001)
    {
        out.s = 0;
        out.h = 0; // undefined, maybe nan?
        return out;
    }
    if (max > 0.0) { // NOTE: if Max is == 0, this divide would cause a crash
        out.s = (delta / max); // s
    } else {
        // if max is 0, then r = g = b = 0
        // s = 0, h is undefined
        out.s = 0.0;
        out.h = NAN;// its now undefined
        return out;
    }
    if (in.r >= max) // > is bogus, just keeps compilor happy
        out.h = (in.g - in.b) / delta; // between yellow & magenta
    else
        if( in.g >= max )
            out.h = 2.0 + (in.b - in.r) / delta; // between cyan & yellow
        else
            out.h = 4.0 + (in.r - in.g) / delta; // between magenta & cyan

    out.h *= 60.0; // degrees
    if (out.h < 0.0)
        out.h += 360.0;
    return out;
}

static RGB hsv2rgb(HSV in) {
    double hh, p, q, t, ff;
    int32_t i;
    RGB out;

    if (in.s <= 0.0) { //< is bogus, just shuts up warnings
        out.r = in.v;
        out.g = in.v;
        out.b = in.v;
        return out;
    }
    hh = in.h;
    if (hh >= 360.0) hh = 0.0;
    hh /= 60.0;
    i = (int32_t)hh;
    ff = hh - i;
    p = in.v * (1.0 - in.s);
    q = in.v * (1.0 - (in.s * ff));
    t = in.v * (1.0 - (in.s * (1.0 - ff)));

    switch (i) {
        case 0: return RGB(in.v, t, p);
        case 1: return RGB(q, in.v, p);
        case 2: return RGB(p, in.v, t);
        case 3: return RGB(p, q, in.v);
        case 4: return RGB(t, p, in.v);
        case 5:
        default: return RGB(in.v, p, q);
    }
}

typedef struct Histogram {
    int count;
    double total_h;
    double total_s;
    double total_v;
} Histogram;

#define MAX_NHIST 128

Histogram hist[MAX_NHIST];

bool hist_comp(const Histogram &a, const Histogram &b) {
    return a.count > b.count;
}

extern "C" {
static int downsample(lua_State *L) {
    unsigned int *data = (unsigned int *)lua_touserdata(L, 1);
    int height = luaL_checknumber(L, 2);
    int width = luaL_checknumber(L, 3);
    int i;
    int n = height * width;
    int neff = 0;
    RGB c;
    memset(hist, 0, sizeof(hist));
    for (i = 0; i < n; i++)
    {
        double alpha = (data[i] >> 24) / 255.0;
        if (alpha < 0.5) continue;
        c.r = ((data[i] >> 16) & 0xff) / 255.0;
        c.g = ((data[i] >> 8) & 0xff) / 255.0;
        c.b = ((data[i] & 0xff)) / 255.0;
        HSV hsv_c = rgb2hsv(c);
        int idx = floor(hsv_c.h / 360 * (MAX_NHIST - 1));
        neff++;
        hist[idx].count++;
        hist[idx].total_h += hsv_c.h;
        hist[idx].total_s += hsv_c.s;
        hist[idx].total_v += hsv_c.v;
    }
    std::sort(hist, hist + MAX_NHIST, hist_comp);
    lua_newtable(L);
    for (i = 0; i < 4; i++)
    {
        const Histogram &e = hist[i];
        HSV c;
        if (e.count)
        {
            c.h = e.total_h / e.count;
            c.s = e.total_s / e.count;
            c.v = e.total_v / e.count;
        }
        else c.h = c.s = c.v = 0;
        RGB rgb_c = hsv2rgb(c);
        lua_pushnumber(L, i + 1);
        lua_newtable(L);
        lua_pushnumber(L, 1);
        lua_pushnumber(L, rgb_c.r);
        lua_settable(L, -3);
        lua_pushnumber(L, 2);
        lua_pushnumber(L, rgb_c.g);
        lua_settable(L, -3);
        lua_pushnumber(L, 3);
        lua_pushnumber(L, rgb_c.b);
        lua_settable(L, -3);
        lua_pushnumber(L, 4);
        lua_pushnumber(L, e.count / (double)neff);
        lua_settable(L, -3);
        lua_settable(L, -3);
    }
    return 1;
}

static const struct luaL_Reg myawesomewidgets_cairohack [] = {
    {"downsample", downsample},
    {NULL, NULL}
};

int luaopen_myawesomewidgets_cairohack(lua_State *L) {
    luaL_newlib(L, myawesomewidgets_cairohack);
    return 1;
}

}
