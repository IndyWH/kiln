# LLVM: BOLT crashes on a program built with -fsplit-machine-functions

**Status:** not sent to any project. Recorded here for developers who read this repo.
**Written by:** Claude Code, an AI tool, on 5 Nov 2026. Not yet reviewed by a person.

## The machine

mlrig: Intel i9-13900K, 96 GB DDR5-6400, RTX 4090, Radeon Pro WX 3200. Kiln Linux, built on Gentoo for amd64, with Clang 22.1.8. BOLT was built from the LLVM 22.1.8 source release, as Release, with assertions off.

## The bug

`llvm-bolt` crashes with a segmentation fault when given a small C++ program built with `-fprofile-use -fsplit-machine-functions -Wl,-q`. It crashes with or without `-instrument`. The same program without the split option passes.

```
BOLT-WARNING: split function detected on input : _Z4workii.cold. The support is limited in relocation mode
 #4 llvm::MCInstrAnalysis::isCall(llvm::MCInst const&) const
 #5 llvm::bolt::MCPlusBuilder::isCall(llvm::MCInst const&) const
 #6 llvm::bolt::BinaryFunction::parseLSDA(llvm::ArrayRef<unsigned char>, unsigned long)
 #7 llvm::bolt::RewriteInstance::disassembleFunctions()
```

`parseLSDA` reads C++ exception tables. Built with `-fno-exceptions`, the program still has a split function, `main.cold`, and BOLT passes. That points at exception tables in a split function, but this one test does not prove it, because `work` itself is not split in that build.

## How to repeat it

`t.cpp`:

```cpp
#include <cstdio>
#include <cstdlib>
#include <vector>

__attribute__((noinline)) int work(int x, int rare) {
    int total = 0;
    for (int i = 0; i < x; i++) {
        switch (i % 7) {
            case 0: total += i; break;
            case 1: total ^= i * 3; break;
            case 2: total -= i / 2; break;
            default: total += 1; break;
        }
        if (rare) {
            std::vector<int> v(1000, i);
            for (int n : v) total += n;
            std::printf("rare path %d\n", total);
            if (total == 12345) std::abort();
        }
    }
    return total;
}

int main(int argc, char **) {
    long sum = 0;
    for (int i = 0; i < 200000; i++) sum += work(100 + i % 5, argc > 5);
    std::printf("%ld\n", sum);
    return 0;
}
```

Commands:

```
clang++ -O2 -fprofile-generate=raw -fuse-ld=lld t.cpp -o gen
./gen
llvm-profdata merge -o p.profdata raw/*.profraw
clang++ -O2 -fprofile-use=p.profdata -fuse-ld=lld -Wl,-q -Wl,-z,lazy t.cpp -o plain
clang++ -O2 -fprofile-use=p.profdata -fsplit-machine-functions -fuse-ld=lld -Wl,-q -Wl,-z,lazy t.cpp -o split
llvm-bolt plain -o plain.bolt     # passes
llvm-bolt split -o split.bolt     # segmentation fault
```

## A related failure, not reduced

BOLT also failed on Rust's `libLLVM`, built with ThinLTO, PGO and `-fsplit-machine-functions`, but differently. It ran further, then stopped with `error: Undefined temporary symbol .Ltmp1313787` and `BOLT-ERROR: Emission failed`. It may or may not have the same cause. The log is not in this repo. That build was not reduced to a small test.

## What was checked and what was not

- LLVM's GitHub issues, 5 Nov 2026, searched for BOLT with `split-machine-functions`, `split function detected` and `Undefined temporary symbol`. Nothing matching was found. The closest, #76800 and #235619, are a different assertion and an AArch64 case.
- BOLT warns that its support for split input is limited, so its authors may regard this as known. A crash is still worth recording.
- Not tested: BOLT built with assertions on, LLVM's main branch, or GCC-built programs.
- The cost to Kiln is small: BOLT does its own splitting, so this option is not needed.
