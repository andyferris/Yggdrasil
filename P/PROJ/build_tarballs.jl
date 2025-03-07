# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "PROJ"
upstream_version = v"9.1.0"
version_offset = v"0.0.0"
version = VersionNumber(upstream_version.major * 100 + version_offset.major,
                        upstream_version.minor * 100 + version_offset.minor,
                        upstream_version.patch * 100 + version_offset.patch)

# Collection of sources required to complete build
sources = [
    ArchiveSource("https://download.osgeo.org/proj/proj-$upstream_version.tar.gz", "81b2239b94cad0886222cde4f53cb49d34905aad2a1317244a0c30a553db2315")
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/proj-*

EXE_SQLITE3=${host_bindir}/sqlite3

if [[ ${target} == *mingw* ]]; then
    SQLITE3_LIBRARY=${libdir}/libsqlite3-0.dll
    CURL_LIBRARY=${libdir}/libcurl-4.dll
    TIFF_LIBRARY_RELEASE=${libdir}/libtiff-5.dll
else
    SQLITE3_LIBRARY=${libdir}/libsqlite3.${dlext}
    CURL_LIBRARY=${libdir}/libcurl.${dlext}
    TIFF_LIBRARY_RELEASE=${libdir}/libtiff.${dlext}
fi

if [[ "${target}" == x86_64-linux-musl* ]]; then
    export LDFLAGS="-lcurl"
fi

mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${prefix} \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=OFF \
    -DEXE_SQLITE3=$EXE_SQLITE3 \
    -DSQLITE3_INCLUDE_DIR=${includedir} \
    -DSQLITE3_LIBRARY=$SQLITE3_LIBRARY \
    -DCURL_INCLUDE_DIR=${includedir} \
    -DCURL_LIBRARY=$CURL_LIBRARY \
    -DTIFF_INCLUDE_DIR=${includedir} \
    -DTIFF_LIBRARY_RELEASE=$TIFF_LIBRARY_RELEASE \
    ..

make -j${nproc}
make install
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = expand_cxxstring_abis(supported_platforms())

# The products that we will ensure are always built
products = [
    LibraryProduct(["libproj", "libproj_$(upstream_version.major)_$(upstream_version.minor)"], :libproj),

    ExecutableProduct("proj", :proj),
    ExecutableProduct("gie", :gie),
    ExecutableProduct("projinfo", :projinfo),
    ExecutableProduct("projsync", :projsync),
    ExecutableProduct("cs2cs", :cs2cs),
    ExecutableProduct("geod", :geod),
    ExecutableProduct("cct", :cct),

    # complete contents of share/proj, must be kept up to date
    FileProduct(joinpath("share", "proj", "CH"), :ch),
    FileProduct(joinpath("share", "proj", "GL27"), :gl27),
    FileProduct(joinpath("share", "proj", "ITRF2000"), :itrf2000),
    FileProduct(joinpath("share", "proj", "ITRF2008"), :itrf2008),
    FileProduct(joinpath("share", "proj", "ITRF2014"), :itrf2014),
    FileProduct(joinpath("share", "proj", "nad.lst"), :nad_lst),
    FileProduct(joinpath("share", "proj", "nad27"), :nad27),
    FileProduct(joinpath("share", "proj", "nad83"), :nad83),
    FileProduct(joinpath("share", "proj", "other.extra"), :other_extra),
    FileProduct(joinpath("share", "proj", "proj.db"), :proj_db),
    FileProduct(joinpath("share", "proj", "proj.ini"), :proj_ini),
    FileProduct(joinpath("share", "proj", "world"), :world),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    # Host SQLite needed to build proj.db
    HostBuildDependency("SQLite_jll")
    Dependency("SQLite_jll")
    Dependency("Libtiff_jll")
    Dependency("LibCURL_jll"; compat="7.73")
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.6")
