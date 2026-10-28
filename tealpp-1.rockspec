package = "tealpp"
version = "0.1.0-1"
source = {
   url = "https://github.com/Sheldevv/tealpp"
}
description = {
   summary = "Teal++ (T++), an object-oriented Teal superset",
   detailed = "A source-to-source transpiler that extends Teal with class syntax and quality-of-life features.",
   homepage = "https://github.com/Sheldevv/tealpp",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      ["tpp"] = "src/tpp.lua"
   },
   install = {
      bin = {
         ["tpp"] = "bin/tpp"
      }
   }
}
