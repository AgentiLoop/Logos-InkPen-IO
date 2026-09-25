import SwiftUI

extension VectorDocument {

    func requestZoom(to targetZoom: CGFloat, mode: ZoomMode) {
        let request = ZoomRequest(targetZoom: targetZoom, mode: mode)
        viewState.zoomRequest = request
    }

    func clearZoomRequest() {
        viewState.zoomRequest = nil
    }
}
