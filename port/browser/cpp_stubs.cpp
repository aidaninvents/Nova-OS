#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>

extern "C" {
extern void* malloc(size_t size);
extern void  free(void* ptr);
extern void* realloc(void* ptr, size_t new_size);
}

/* =========================================================================
 * C++ Freestanding Heap & ABI Runtime Glue
 * ========================================================================= */
void* operator new(size_t size) {
    return malloc(size ? size : 1);
}

void* operator new[](size_t size) {
    return malloc(size ? size : 1);
}

void operator delete(void* ptr) noexcept {
    if (ptr) free(ptr);
}

void operator delete[](void* ptr) noexcept {
    if (ptr) free(ptr);
}

void operator delete(void* ptr, size_t) noexcept {
    if (ptr) free(ptr);
}

void operator delete[](void* ptr, size_t) noexcept {
    if (ptr) free(ptr);
}

namespace std {
enum class align_val_t : size_t {};
struct nothrow_t {};
const nothrow_t nothrow{};
} // namespace std

void* operator new(size_t size, const std::nothrow_t&) noexcept {
    return malloc(size ? size : 1);
}

void* operator new[](size_t size, const std::nothrow_t&) noexcept {
    return malloc(size ? size : 1);
}

void* operator new(size_t size, std::align_val_t) {
    return malloc(size ? size : 1);
}

void* operator new[](size_t size, std::align_val_t) {
    return malloc(size ? size : 1);
}

void operator delete(void* ptr, std::align_val_t) noexcept {
    if (ptr) free(ptr);
}

void operator delete[](void* ptr, std::align_val_t) noexcept {
    if (ptr) free(ptr);
}

void operator delete(void* ptr, size_t, std::align_val_t) noexcept {
    if (ptr) free(ptr);
}

void operator delete[](void* ptr, size_t, std::align_val_t) noexcept {
    if (ptr) free(ptr);
}

extern "C" {

void* __dso_handle = nullptr;

void __cxa_pure_virtual(void) {
    for (;;) { __asm__ volatile("hlt"); }
}

int __cxa_atexit(void (*)(void*), void*, void*) {
    return 0;
}

int __cxa_guard_acquire(uint64_t* g) {
    return !*reinterpret_cast<volatile char*>(g);
}

void __cxa_guard_release(uint64_t* g) {
    *reinterpret_cast<volatile char*>(g) = 1;
}

void __cxa_guard_abort(uint64_t*) {}

void abort(void) {
    for (;;) { __asm__ volatile("cli; hlt"); }
}

void __assert_fail(const char*, const char*, unsigned int, const char*) {
    abort();
}

uintptr_t __stack_chk_guard = 0x595E9FBD94FDA766ULL;
void __stack_chk_fail(void) {
    abort();
}

/* =========================================================================
 * Minimal Libc Memory & String Functions
 * ========================================================================= */
void* memcpy(void* dst, const void* src, size_t n) {
    auto* d = static_cast<uint8_t*>(dst);
    const auto* s = static_cast<const uint8_t*>(src);
    while (n--) *d++ = *s++;
    return dst;
}

void* memmove(void* dst, const void* src, size_t n) {
    auto* d = static_cast<uint8_t*>(dst);
    const auto* s = static_cast<const uint8_t*>(src);
    if (d < s) {
        while (n--) *d++ = *s++;
    } else if (d > s) {
        d += n;
        s += n;
        while (n--) *--d = *--s;
    }
    return dst;
}

void* memset(void* dst, int c, size_t n) {
    auto* d = static_cast<uint8_t*>(dst);
    while (n--) *d++ = static_cast<uint8_t>(c);
    return dst;
}

int memcmp(const void* a, const void* b, size_t n) {
    const auto* p = static_cast<const uint8_t*>(a);
    const auto* q = static_cast<const uint8_t*>(b);
    while (n--) {
        if (*p != *q) return static_cast<int>(*p) - static_cast<int>(*q);
        ++p;
        ++q;
    }
    return 0;
}

void* memchr(const void* s, int c, size_t n) {
    const auto* p = static_cast<const uint8_t*>(s);
    while (n--) {
        if (*p == static_cast<uint8_t>(c)) return const_cast<uint8_t*>(p);
        ++p;
    }
    return nullptr;
}

size_t strlen(const char* s) {
    size_t len = 0;
    while (s && s[len]) ++len;
    return len;
}

size_t strnlen(const char* s, size_t maxlen) {
    size_t len = 0;
    while (s && len < maxlen && s[len]) ++len;
    return len;
}

int strcmp(const char* a, const char* b) {
    while (*a && (*a == *b)) { ++a; ++b; }
    return static_cast<uint8_t>(*a) - static_cast<uint8_t>(*b);
}

int strncmp(const char* a, const char* b, size_t n) {
    while (n && *a && (*a == *b)) { ++a; ++b; --n; }
    if (n == 0) return 0;
    return static_cast<uint8_t>(*a) - static_cast<uint8_t>(*b);
}

int tolower(int c) {
    return (c >= 'A' && c <= 'Z') ? (c - 'A' + 'a') : c;
}

int toupper(int c) {
    return (c >= 'a' && c <= 'z') ? (c - 'a' + 'A') : c;
}

int isdigit(int c)  { return c >= '0' && c <= '9'; }
int isxdigit(int c) { return isdigit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'); }
int isalpha(int c)  { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }
int isalnum(int c)  { return isalpha(c) || isdigit(c); }
int isspace(int c)  { return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\v' || c == '\f'; }
int isprint(int c)  { return c >= 0x20 && c <= 0x7E; }
int iscntrl(int c)  { return (c >= 0 && c < 0x20) || c == 0x7F; }

int strcasecmp(const char* a, const char* b) {
    while (*a && (tolower(static_cast<uint8_t>(*a)) == tolower(static_cast<uint8_t>(*b)))) {
        ++a;
        ++b;
    }
    return tolower(static_cast<uint8_t>(*a)) - tolower(static_cast<uint8_t>(*b));
}

int strncasecmp(const char* a, const char* b, size_t n) {
    while (n && *a && (tolower(static_cast<uint8_t>(*a)) == tolower(static_cast<uint8_t>(*b)))) {
        ++a;
        ++b;
        --n;
    }
    if (n == 0) return 0;
    return tolower(static_cast<uint8_t>(*a)) - tolower(static_cast<uint8_t>(*b));
}

char* strchr(const char* s, int c) {
    while (*s) {
        if (*s == static_cast<char>(c)) return const_cast<char*>(s);
        ++s;
    }
    return (c == 0) ? const_cast<char*>(s) : nullptr;
}

char* strrchr(const char* s, int c) {
    const char* last = nullptr;
    while (*s) {
        if (*s == static_cast<char>(c)) last = s;
        ++s;
    }
    if (c == 0) return const_cast<char*>(s);
    return const_cast<char*>(last);
}

char* strstr(const char* hay, const char* needle) {
    if (!*needle) return const_cast<char*>(hay);
    size_t nlen = strlen(needle);
    for (; *hay; ++hay) {
        if (*hay == *needle && strncmp(hay, needle, nlen) == 0) {
            return const_cast<char*>(hay);
        }
    }
    return nullptr;
}

char* strcpy(char* dst, const char* src) {
    char* r = dst;
    while ((*dst++ = *src++)) {}
    return r;
}

char* strncpy(char* dst, const char* src, size_t n) {
    char* r = dst;
    while (n && (*dst++ = *src++)) --n;
    while (n--) *dst++ = '\0';
    return r;
}

char* strcat(char* dst, const char* src) {
    char* r = dst;
    while (*dst) ++dst;
    while ((*dst++ = *src++)) {}
    return r;
}

char* strdup(const char* s) {
    size_t len = strlen(s) + 1;
    char* p = static_cast<char*>(malloc(len));
    if (p) memcpy(p, s, len);
    return p;
}

void* calloc(size_t nmemb, size_t size) {
    size_t total = nmemb * size;
    void* p = malloc(total ? total : 1);
    if (p) memset(p, 0, total);
    return p;
}

/* =========================================================================
 * Minimal Number Parsing & Formatting
 * ========================================================================= */
long strtol(const char* s, char** endptr, int base) {
    while (isspace(static_cast<uint8_t>(*s))) ++s;
    bool neg = false;
    if (*s == '-') { neg = true; ++s; }
    else if (*s == '+') { ++s; }
    if (base == 0) {
        if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) { base = 16; s += 2; }
        else if (s[0] == '0') { base = 8; ++s; }
        else base = 10;
    } else if (base == 16 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        s += 2;
    }
    long val = 0;
    while (*s) {
        int d = -1;
        if (*s >= '0' && *s <= '9') d = *s - '0';
        else if (*s >= 'a' && *s <= 'z') d = *s - 'a' + 10;
        else if (*s >= 'A' && *s <= 'Z') d = *s - 'A' + 10;
        if (d < 0 || d >= base) break;
        val = val * base + d;
        ++s;
    }
    if (endptr) *endptr = const_cast<char*>(s);
    return neg ? -val : val;
}

unsigned long strtoul(const char* s, char** endptr, int base) {
    return static_cast<unsigned long>(strtol(s, endptr, base));
}

long long strtoll(const char* s, char** endptr, int base) {
    return static_cast<long long>(strtol(s, endptr, base));
}

unsigned long long strtoull(const char* s, char** endptr, int base) {
    return static_cast<unsigned long long>(strtol(s, endptr, base));
}

int atoi(const char* s) {
    return static_cast<int>(strtol(s, nullptr, 10));
}

double strtod(const char* s, char** endptr) {
    while (isspace(static_cast<uint8_t>(*s))) ++s;
    bool neg = false;
    if (*s == '-') { neg = true; ++s; }
    else if (*s == '+') { ++s; }
    double val = 0.0;
    while (isdigit(static_cast<uint8_t>(*s))) {
        val = val * 10.0 + (*s - '0');
        ++s;
    }
    if (*s == '.') {
        ++s;
        double place = 0.1;
        while (isdigit(static_cast<uint8_t>(*s))) {
            val += (*s - '0') * place;
            place *= 0.1;
            ++s;
        }
    }
    if (endptr) *endptr = const_cast<char*>(s);
    return neg ? -val : val;
}

float strtof(const char* s, char** endptr) {
    return static_cast<float>(strtod(s, endptr));
}

static void _fmt_uint(char* dst, size_t cap, size_t* pos, unsigned long long v, int base, bool upper) {
    char tmp[32];
    int n = 0;
    const char* digits = upper ? "0123456789ABCDEF" : "0123456789abcdef";
    if (v == 0) tmp[n++] = '0';
    while (v > 0 && n < 32) {
        tmp[n++] = digits[v % static_cast<unsigned>(base)];
        v /= static_cast<unsigned>(base);
    }
    while (n > 0) {
        if (*pos + 1 < cap) dst[*pos] = tmp[--n];
        else --n;
        ++(*pos);
    }
}

int vsnprintf(char* buf, size_t cap, const char* fmt, va_list ap) {
    size_t pos = 0;
    while (*fmt) {
        if (*fmt != '%') {
            if (pos + 1 < cap) buf[pos] = *fmt;
            ++pos;
            ++fmt;
            continue;
        }
        ++fmt;
        bool is_long = false;
        while (*fmt == 'l') { is_long = true; ++fmt; }
        char spec = *fmt ? *fmt++ : '\0';
        if (spec == '%') {
            if (pos + 1 < cap) buf[pos] = '%';
            ++pos;
        } else if (spec == 's') {
            const char* s = va_arg(ap, const char*);
            if (!s) s = "(null)";
            while (*s) {
                if (pos + 1 < cap) buf[pos] = *s;
                ++pos;
                ++s;
            }
        } else if (spec == 'c') {
            char c = static_cast<char>(va_arg(ap, int));
            if (pos + 1 < cap) buf[pos] = c;
            ++pos;
        } else if (spec == 'd' || spec == 'i') {
            long long v = is_long ? va_arg(ap, long) : va_arg(ap, int);
            if (v < 0) {
                if (pos + 1 < cap) buf[pos] = '-';
                ++pos;
                v = -v;
            }
            _fmt_uint(buf, cap, &pos, static_cast<unsigned long long>(v), 10, false);
        } else if (spec == 'u') {
            unsigned long long v = is_long ? va_arg(ap, unsigned long) : va_arg(ap, unsigned int);
            _fmt_uint(buf, cap, &pos, v, 10, false);
        } else if (spec == 'x' || spec == 'X' || spec == 'p') {
            unsigned long long v = (spec == 'p') ? reinterpret_cast<uintptr_t>(va_arg(ap, void*))
                                                 : (is_long ? va_arg(ap, unsigned long) : va_arg(ap, unsigned int));
            _fmt_uint(buf, cap, &pos, v, 16, spec == 'X');
        } else if (spec == 'f' || spec == 'g') {
            double d = va_arg(ap, double);
            if (d < 0) {
                if (pos + 1 < cap) buf[pos] = '-';
                ++pos;
                d = -d;
            }
            unsigned long long ip = static_cast<unsigned long long>(d);
            _fmt_uint(buf, cap, &pos, ip, 10, false);
            if (pos + 1 < cap) buf[pos] = '.';
            ++pos;
            unsigned long long fp = static_cast<unsigned long long>((d - static_cast<double>(ip)) * 100.0);
            if (fp < 10) {
                if (pos + 1 < cap) buf[pos] = '0';
                ++pos;
            }
            _fmt_uint(buf, cap, &pos, fp, 10, false);
        }
    }
    if (cap > 0) {
        buf[pos < cap ? pos : cap - 1] = '\0';
    }
    return static_cast<int>(pos);
}

int snprintf(char* buf, size_t cap, const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int r = vsnprintf(buf, cap, fmt, ap);
    va_end(ap);
    return r;
}

/* =========================================================================
 * Minimal Math Functions (x86_64 freestanding)
 * ========================================================================= */
double fabs(double x)  { return x < 0.0 ? -x : x; }
float  fabsf(float x)  { return x < 0.0f ? -x : x; }

double floor(double x) {
    long long i = static_cast<long long>(x);
    return (x < static_cast<double>(i)) ? static_cast<double>(i - 1) : static_cast<double>(i);
}
float floorf(float x) { return static_cast<float>(floor(static_cast<double>(x))); }

double ceil(double x) {
    long long i = static_cast<long long>(x);
    return (x > static_cast<double>(i)) ? static_cast<double>(i + 1) : static_cast<double>(i);
}
float ceilf(float x) { return static_cast<float>(ceil(static_cast<double>(x))); }

double trunc(double x) { return static_cast<double>(static_cast<long long>(x)); }
float  truncf(float x) { return static_cast<float>(static_cast<long long>(x)); }

double round(double x) { return (x >= 0.0) ? floor(x + 0.5) : ceil(x - 0.5); }
float  roundf(float x) { return static_cast<float>(round(static_cast<double>(x))); }

double fmod(double x, double y) {
    if (y == 0.0) return 0.0;
    return x - trunc(x / y) * y;
}
float fmodf(float x, float y) { return static_cast<float>(fmod(x, y)); }

double sqrt(double x) {
    if (x <= 0.0) return 0.0;
    double res;
    __asm__ volatile("sqrtsd %1, %0" : "=x"(res) : "x"(x));
    return res;
}
float sqrtf(float x) {
    if (x <= 0.0f) return 0.0f;
    float res;
    __asm__ volatile("sqrtss %1, %0" : "=x"(res) : "x"(x));
    return res;
}

double sin(double x) {
    double r;
    __asm__ volatile("fldl %1; fsin; fstpl %0" : "=m"(r) : "m"(x));
    return r;
}
double cos(double x) {
    double r;
    __asm__ volatile("fldl %1; fcos; fstpl %0" : "=m"(r) : "m"(x));
    return r;
}
double tan(double x) { return sin(x) / cos(x); }
float  sinf(float x) { return static_cast<float>(sin(x)); }
float  cosf(float x) { return static_cast<float>(cos(x)); }
float  tanf(float x) { return static_cast<float>(tan(x)); }

double atan2(double y, double x) {
    double r;
    __asm__ volatile("fldl %1; fldl %2; fpatan; fstpl %0" : "=m"(r) : "m"(y), "m"(x));
    return r;
}
float atan2f(float y, float x) { return static_cast<float>(atan2(y, x)); }

double pow(double base, double exp) {
    if (exp == 0.0) return 1.0;
    if (base == 0.0) return 0.0;
    long long ei = static_cast<long long>(exp);
    if (static_cast<double>(ei) == exp && ei >= 0 && ei <= 64) {
        double acc = 1.0;
        for (long long i = 0; i < ei; ++i) acc *= base;
        return acc;
    }
    double r = 1.0;
    if (exp > 0) {
        for (long long i = 0; i < ei; ++i) r *= base;
    }
    return r;
}
float powf(float base, float exp) { return static_cast<float>(pow(base, exp)); }

} // extern "C"

/* =========================================================================
 * libstdc++ -fno-exceptions throw stubs (used by std::vector / std::string)
 * ========================================================================= */
namespace std {
void __throw_bad_alloc() { abort(); }
void __throw_bad_array_new_length() { abort(); }
void __throw_length_error(const char*) { abort(); }
void __throw_out_of_range(const char*) { abort(); }
void __throw_out_of_range_fmt(const char*, ...) { abort(); }
void __throw_logic_error(const char*) { abort(); }
void __throw_invalid_argument(const char*) { abort(); }
void __throw_bad_function_call() { abort(); }
void __throw_bad_optional_access() { abort(); }
void __glibcxx_assert_fail(const char*, int, const char*, const char*) noexcept { abort(); }
} // namespace std
