#!/usr/bin/env python3
from sipbuild.abstract_project import AbstractProject
from sipbuild.exceptions import handle_exception

project = AbstractProject.bootstrap('build', "Generate the project bindings.")
project.builder._generate_bindings()
project.progress("The project bindings are ready for build.")
