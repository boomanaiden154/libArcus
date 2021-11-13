import os

from conans import ConanFile, tools
from conan.tools.cmake import CMakeToolchain, CMakeDeps, CMake
from conan.tools.layout import cmake_layout
from conan.tools.files.packager import AutoPackager

class ArcusConan(ConanFile):
    name = "arcus"
    version = "4.13.0-alpha+001"
    license = "LGPL-3.0"
    author = "Ultimaker B.V."
    url = "https://github.com/Ultimaker/libArcus"
    description = "Communication library between internal components for Ultimaker software"
    topics = ("conan", "python", "binding", "sip", "cura", "protobuf", "c++")
    settings = "os", "compiler", "build_type", "arch"
    revision_mode = "scm"
    build_policy = "missing"
    default_user = "ultimaker"
    default_channel = "testing"
    exports = "LICENSE*"
    options = {
        "build_python": [True, False],
        "shared": [True, False],
        "fPIC": [True, False],
        "examples": [True, False]
    }
    default_options = {
        "build_python": True,
        "shared": True,
        "fPIC": True,
        "examples": False
    }
    scm = {
        "type": "git",
        "subfolder": ".",
        "url": "auto",
        "revision": "auto"
    }
    build_requires = "protobuf/3.17.1"

    def requirements(self):
        if self.options.build_python:
            self.requires("Python/3.8.10@python/stable")
            self.requires("sip/4.19.25@riverbankcomputing/stable")
        self.requires("protobuf/3.17.1")

    def config_options(self):
        if self.settings.os == "Windows":
            self.options.shared = False
            if self.settings.compiler == "gcc":
                self.options.build_python = False
        if self.settings.os == "Macos":
            self.options["protobuf"].shared = False
        else:
            self.options["protobuf"].shared = self.options.shared

    def configure(self):
        if self.options.build_python:
            self.options["sip"].shared = self.options.shared
        if self.options.shared or self.settings.compiler == "Visual Studio":
            del self.options.fPIC

    def validate(self):
        if self.settings.compiler.get_safe("cppstd"):
            tools.check_min_cppstd(self, 17)

    def layout(self):
        cmake_layout(self)
        self.cpp.source.includedirs = ["include"]
        self.cpp.build.libs = ["Arcus"]

    def generate(self):
        cmake = CMakeDeps(self)
        cmake.generate()

        tc = CMakeToolchain(self)

        # FIXME: This shouldn't be necessary (maybe a bug in Conan????)
        if self.settings.compiler == "Visual Studio":
            tc.blocks["generic_system"].values["generator_platform"] = None
            tc.blocks["generic_system"].values["toolset"] = None

        tc.variables["ALLOW_IN_SOURCE_BUILD"] = True
        tc.variables["BUILD_EXAMPLES"] = self.options.examples
        tc.variables["BUILD_PYTHON"] = self.options.build_python
        if self.options.build_python:
            tc.variables["Python_VERSION"] = self.deps_cpp_info['Python'].version
            tc.variables["SIP_MODULE_SITE_PATH"] = "site-packages"

        tc.variables["BUILD_STATIC"] = not self.options.shared
        tc.generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()
        cmake.install()

    def package(self):
        packager = AutoPackager(self)
        packager.run()

    def package_info(self):
        self.cpp_info.libs = tools.collect_libs(self)
        self.cpp_info.defines.append("ARCUS")
        if self.settings.build_type == "Debug":
            self.cpp_info.defines.append("ARCUS_DEBUG")
        if self.settings.os in ["Linux", "FreeBSD", "Macos"]:
            self.cpp_info.system_libs.append("pthread")
        elif self.settings.os == "Windows":
            self.cpp_info.system_libs.append("ws2_32")
        if self.in_local_cache:
            self.runenv_info.prepend_path("PYTHONPATH", os.path.join(self.folders.package, "site-packages"))
        else:
            self.runenv_info.prepend_path("PYTHONPATH", self.folders.build)

    def package_id(self):
        self.info.requires.full_version_mode()