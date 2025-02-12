import Foundation

enum AppEnvironment {
    static let current: String = {
        print("AppEnvironment initializing...")
        let bundle = Bundle.main
        print("Bundle identifier: \(bundle.bundleIdentifier ?? "none")")
        
        if let environment = Bundle.main.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String {
            print("Found environment in Info.plist: \(environment)")
            return environment
        } else {
            print("No environment found in Info.plist, defaulting to production")
            return "debug" // Default to production
        }
    }()
    
    static var isProduction: Bool {
        let isProd = current == "production"
        print("isProduction: \(isProd)")
        return isProd
    }
    
    static var baseURL: String {
        let url = isProduction ? "https://stack-54k8.onrender.com" : "http://localhost:8000"
        print("Using baseURL: \(url)")
        return url
    }
} 