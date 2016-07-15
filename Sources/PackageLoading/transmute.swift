/*
 This source file is part of the Swift.org open source project

 Copyright 2015 - 2016 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Basic
import PackageModel
import Utility

import func POSIX.exit

/// Load packages into a complete set of modules and products.
public func transmute(_ rootPackage: Package, externalPackages: [Package]) throws -> (modules: [Module], externalModules: [Module], products: [Product]) {
    var products: [Product] = []
    var map: [Package: [Module]] = [:]
    
    let packages = externalPackages + [rootPackage]

    for package in packages {

        var modules: [Module]
        do {
            modules = try package.modules()
        } catch ModuleError.noModules(let pkg) where pkg === rootPackage {
            // Ignore and print warning if root package doesn't contain any sources.
            print("warning: root package '\(pkg)' does not contain any sources")
            if packages.count == 1 { exit(0) } //Exit now if there is no more packages 
            modules = []
        }

        if package == rootPackage {
            // TODO: allow testing of external package tests.
            modules += try package.testModules(modules: modules)
        }

        map[package] = modules
        products += try package.products(modules)
    }

    // ensure modules depend on the modules of any dependent packages
    fillModuleGraph(packages, modulesForPackage: { map[$0]! })

    let modules = try PackageLoading.recursiveDependencies(packages.flatMap{ map[$0] ?? [] })
    let externalModules = try PackageLoading.recursiveDependencies(externalPackages.flatMap{ map[$0] ?? [] })

    return (modules, externalModules, products)
}

/// Add inter-package dependencies.
///
/// This function will add cross-package dependencies between a module and all
/// of the modules produced by any package in the transitive closure of its
/// containing package's dependencies.
private func fillModuleGraph(_ packages: [Package], modulesForPackage: (Package) -> [Module]) {
    for package in packages {
        let packageModules = modulesForPackage(package)
        let dependencies = try! topologicalSort(package.dependencies, successors: { $0.dependencies })
        for dep in dependencies {
            let depModules = modulesForPackage(dep).filter{
                guard !$0.isTest else { return false }

                switch $0 {
                case let module as SwiftModule where module.type == .library:
                    return true
                case is CModule:
                    return true
                default:
                    return false
                }
            }
            for module in packageModules {
                // FIXME: This is inefficient.
                module.dependencies.insert(contentsOf: depModules, at: 0)
            }
        }
    }
}

private func recursiveDependencies(_ modules: [Module]) throws -> [Module] {
    // FIXME: Refactor this to a common algorithm.
    var stack = modules
    var set = Set<Module>()
    var rv = [Module]()

    while stack.count > 0 {
        let top = stack.removeFirst()
        if !set.contains(top) {
            rv.append(top)
            set.insert(top)
            stack += top.dependencies
        } else {
            // See if the module in the set is actually the same.
            guard let index = set.index(of: top),
                  top.sources.root != set[index].sources.root else {
                continue;
            }

            throw Module.Error.duplicateModule(top.name)
        }
    }

    return rv
}
