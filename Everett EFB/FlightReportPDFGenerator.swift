@MainActor
private func generatePDF() async {
    do {
        let generator = FlightReportPDFGenerator()
        document = try generator.generatePDF(for: flight)
    } catch {
        errorMessage = error.localizedDescription
    }
}
