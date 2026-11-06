import SwiftUI
import UIKit

/// ADR-006: the workspace never gets narrower than the compact breakpoint.
/// The policy is a value so the unit test can pin it and the inspector can
/// show the same number the scene restriction applies.
enum FFSceneSizePolicy {
    static let minimumSize = CGSize(width: 640, height: 480)
    static let summary = "min 640 pt"
}

/// Applies `UISceneSizeRestrictions` once the SwiftUI host is attached to a
/// window scene. Keeping this in a tiny representable avoids swizzling or
/// reaching into `UIApplication` from a global on launch.
struct FFSceneSizeRestrictionsView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> FFSceneRestrictionsController {
        FFSceneRestrictionsController()
    }

    func updateUIViewController(_ controller: FFSceneRestrictionsController, context: Context) {
        controller.applyRestrictions()
    }
}

final class FFSceneRestrictionsController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyRestrictions()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyRestrictions()
    }

    func applyRestrictions() {
        guard let scene = view.window?.windowScene else {
            return
        }
        scene.sizeRestrictions?.minimumSize = FFSceneSizePolicy.minimumSize
    }
}
