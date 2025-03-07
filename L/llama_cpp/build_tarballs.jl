using BinaryBuilder, Pkg

name = "llama_cpp"
version = v"0.0.4"  # fake version number

# url = "https://github.com/ggerganov/llama.cpp"
# description = "Port of Facebook's LLaMA model in C/C++"

# TODO
# - i686, x86_64, aarch64 build
#   missing architectures: powerpc64le, armv6l, arm7vl

# versions: fake_version to github_version mapping
#
# fake_version    date_released    github_version    github_url
# 0.0.1           20.03.2023       master-074bea2    https://github.com/ggerganov/llama.cpp/releases/tag/master-074bea2
# 0.0.2           21.03.2023       master-8cf9f34    https://github.com/ggerganov/llama.cpp/releases/tag/master-8cf9f34
# 0.0.3           22.03.2023       master-d5850c5    https://github.com/ggerganov/llama.cpp/releases/tag/master-d5850c5
# 0.0.4           25.03.2023       master-1972616    https://github.com/ggerganov/llama.cpp/releases/tag/master-1972616

sources = [
    # fake version = 0.0.4
    GitSource("https://github.com/ggerganov/llama.cpp.git",
              "19726169b379bebc96189673a19b89ab1d307659"),
    DirectorySource("./bundled"),
]

script = raw"""
cd $WORKSPACE/srcdir/llama.cpp*

atomic_patch -p1 ../patches/cmake-remove-mcpu-native.patch
if [[ "${target}" == *-w64-mingw32* ]]; then
    atomic_patch -p1 ../patches/windows-examples-fix-missing-ggml-link.patch
fi

EXTRA_CMAKE_ARGS=
if [[ "${target}" == *-linux-* ]]; then
    EXTRA_CMAKE_ARGS='-DCMAKE_EXE_LINKER_FLAGS="-lrt"'
fi

mkdir build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=$prefix \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_BUILD_TYPE=RELEASE \
    -DBUILD_SHARED_LIBS=ON \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=ON \
    -DLLAMA_OPENBLAS=OFF \
    -DLLAMA_NATIVE=OFF \
    $EXTRA_CMAKE_ARGS
make -j${nproc}

# `make install` doesn't work (2023.03.21)
# make install

# executables
for prg in embedding main perplexity quantize; do
    install -Dvm 755 "./bin/${prg}${exeext}" "${bindir}/${prg}${exeext}"
done

# libs
for lib in libllama; do
    if [[ "${target}" == *-w64-mingw32* ]]; then
        install -Dvm 755 "./bin/${lib}.${dlext}" "${libdir}/${lib}.${dlext}"
    else
        install -Dvm 755 "./${lib}.${dlext}" "${libdir}/${lib}.${dlext}"
    fi
done


# header files
for hdr in llama.h ggml.h; do
    install -Dvm 644 "../${hdr}" "${includedir}/${hdr}"
done

install_license ../LICENSE
"""

platforms = supported_platforms(; exclude = p -> arch(p) ∉ ["i686", "x86_64", "aarch64"])
platforms = expand_cxxstring_abis(platforms)

products = [
    ExecutableProduct("embedding", :embedding),
    ExecutableProduct("main", :main),
    ExecutableProduct("perplexity", :perplexity),
    ExecutableProduct("quantize", :quantize),
    LibraryProduct("libllama", :libllama),
]

dependencies = Dependency[
]

build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat="1.6", preferred_gcc_version = v"8.1.0")
