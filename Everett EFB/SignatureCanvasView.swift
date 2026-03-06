import SwiftUI
import PencilKit

struct SignatureCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data?

    func makeCoordinator() -> Coordinator {
        Coordinator(drawingData: $drawingData)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .secondarySystemBackground
        canvas.layer.cornerRadius = 8
        canvas.layer.borderWidth = 1
        canvas.layer.borderColor = UIColor.systemGray4.cgColor
        canvas.delegate = context.coordinator

        if let drawingData,
           let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if let drawingData,
           let drawing = try? PKDrawing(data: drawingData) {
            if uiView.drawing.dataRepresentation() != drawingData {
                uiView.drawing = drawing
            }
        } else if drawingData == nil && !uiView.drawing.bounds.isEmpty {
            uiView.drawing = PKDrawing()
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawingData: Data?

        init(drawingData: Binding<Data?>) {
            self._drawingData = drawingData
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let data = canvasView.drawing.dataRepresentation()
            drawingData = data.isEmpty ? nil : data
        }
    }
}
