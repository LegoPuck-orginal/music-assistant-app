import WidgetKit
import SwiftUI

#if canImport(ActivityKit)
@main
struct MusicAssistantWidgetsBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            MusicAssistantDynamicIslandWidget()
        }
    }
}
#endif
