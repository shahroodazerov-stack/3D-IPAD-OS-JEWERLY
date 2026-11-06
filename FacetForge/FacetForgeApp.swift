import Foundation
import SwiftUI

@main
struct FacetForgeApp: App {
    private var isLayoutLab: Bool {
        ProcessInfo.processInfo.arguments.contains("-FFLayoutLab")
    }

    var body: some Scene {
        WindowGroup {
            if isLayoutLab {
                FFLayoutLabView()
            } else {
                ContentView()
            }
        }
    }
}
