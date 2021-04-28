import class Foundation.Bundle

extension Foundation.Bundle {
    static var module: Bundle = {
        let mainPath = Bundle.main.bundlePath + "/" + "SPCamera_SPCamera.bundle"
        let buildPath = "/Users/stevepint/dev/sgp/github/SPCamera/.build/x86_64-apple-macosx/debug/SPCamera_SPCamera.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle != nil ? preferredBundle : Bundle(path: buildPath) else {
            fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}