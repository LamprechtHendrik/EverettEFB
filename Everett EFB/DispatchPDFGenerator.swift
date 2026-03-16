//
//  DispatchPDFGenerator.swift
//  Everett EFB
//

import Foundation
import PDFKit
import UIKit
import PencilKit

final class DispatchPDFGenerator {

    enum DispatchPDFError: LocalizedError {
        case emptyFlight

        var errorDescription: String? {
            switch self {
            case .emptyFlight:
                return "Cannot generate a dispatch package for a flight with no legs."
            }
        }
    }

    struct PackageInput {
        let flight: Flight
        let aircraft: Aircraft?
        let pic: CrewMember?
        let sic: CrewMember?
        let cabinCrew: CrewMember?
    }

    private let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
    private let margin: CGFloat = 28
    private let cautionDays = 30

    // MARK: - PDF Generation

    func generatePDF(for input: PackageInput, signatureData: Data? = nil) throws -> PDFDocument {
        guard !input.flight.legs.isEmpty else {
            throw DispatchPDFError.emptyFlight
        }

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, pageRect, nil)

        drawDispatchFormPage(for: input, signatureData: signatureData)
        drawAircraftRecencyPage(for: input.aircraft, flight: input.flight)
        drawCrewRecencyPage(title: "PIC RECENCY", crewMember: input.pic)
        drawCrewRecencyPage(title: "FO / SIC RECENCY", crewMember: input.sic)

        if let cabin = input.cabinCrew,
           !input.flight.cabinCrew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            drawCrewRecencyPage(title: "CABIN CREW RECENCY", crewMember: cabin)
        }

        UIGraphicsEndPDFContext()

        guard let document = PDFDocument(data: data as Data) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return document
    }

    // MARK: - Page 1

    private func drawDispatchFormPage(for input: PackageInput, signatureData: Data?) {
        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)

        drawPageBorder()
        drawDispatchHeader(
            title: "MASTER DISPATCH LIST",
            subtitle: "Captain Dispatch Form"
        )

        let flight = input.flight
        let sortedLegs = flight.legs.sorted { $0.sequence < $1.sequence }
        let firstLeg = sortedLegs.first

        let dateText = firstLeg?.date.efbDate ?? flight.createdAt.efbDate
        let routeText = sortedLegs.isEmpty
            ? "-"
            : sortedLegs.map { "\($0.departure)-\($0.destination)" }.joined(separator: " / ")
        let typeText = valueOrDash(flight.flightType.rawValue)
        let clientText = valueOrDash(flight.client)
        let aircraftText = valueOrDash(flight.aircraftReg)
        let picText = valueOrDash(flight.pic)
        let sicText = valueOrDash(flight.sic)
        let cabinText: String = {
            let trimmed = flight.cabinCrew.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "N/A" : trimmed
        }()
        let attachedPages = 4 + (flight.cabinCrew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)

        let contentWidth = pageRect.width - (margin * 2)
        let topY: CGFloat = 96
        let gap: CGFloat = 12
        let topBlockWidth = (contentWidth - gap) / 2

        let leftRows: [(String, String)] = [
            ("Date", dateText),
            ("Flight #", valueOrDash(flight.reportNumber)),
            ("Aircraft", aircraftText),
            ("PIC", picText)
        ]

        let rightRows: [(String, String)] = [
            ("Flight Type", typeText),
            ("Client", clientText),
            ("SIC", sicText.isEmpty ? "N/A" : sicText),
            ("Cabin Crew", cabinText)
        ]

        let leftHeight = drawFormalInfoBlock(
            title: "FLIGHT DETAILS",
            origin: CGPoint(x: margin, y: topY),
            width: topBlockWidth,
            rows: leftRows
        )

        let rightHeight = drawFormalInfoBlock(
            title: "OPERATIONAL DETAILS",
            origin: CGPoint(x: margin + topBlockWidth + gap, y: topY),
            width: topBlockWidth,
            rows: rightRows
        )

        let routeY = topY + max(leftHeight, rightHeight) + 12
        let routeHeight = drawFormalRouteBlock(
            origin: CGPoint(x: margin, y: routeY),
            width: contentWidth,
            routeText: routeText,
            attachedPagesText: "\(attachedPages)"
        )

        let releaseY = routeY + routeHeight + 14
        let releaseHeight = drawCaptainReleaseBlock(
            flight: flight,
            signatureData: signatureData ?? flight.firstPICSignatureDrawing,
            origin: CGPoint(x: margin, y: releaseY),
            width: contentWidth
        )

        let notesY = releaseY + releaseHeight + 14
        _ = drawNotesBlock(
            origin: CGPoint(x: margin, y: notesY),
            width: contentWidth,
            notes: "This dispatch package contains the release page followed by aircraft and crew recency records. Any expired item requiring operational acceptance must be reviewed before departure."
        )
    }

    // MARK: - Formal Page 1 Blocks

    @discardableResult
    private func drawFormalInfoBlock(
        title: String,
        origin: CGPoint,
        width: CGFloat,
        rows: [(String, String)]
    ) -> CGFloat {
        let titleHeight: CGFloat = 24
        let rowHeight: CGFloat = 24
        let labelWidth: CGFloat = 106
        let totalHeight = titleHeight + CGFloat(rows.count) * rowHeight

        drawTableFrame(origin: origin, width: width, height: totalHeight)

        drawSectionTitle(title, rect: CGRect(x: origin.x, y: origin.y, width: width, height: titleHeight))
        drawHorizontalLine(y: origin.y + titleHeight, from: origin.x, to: origin.x + width)
        drawVerticalLine(x: origin.x + labelWidth, from: origin.y + titleHeight, to: origin.y + totalHeight)

        for (index, row) in rows.enumerated() {
            let y = origin.y + titleHeight + CGFloat(index) * rowHeight
            drawHorizontalLine(y: y + rowHeight, from: origin.x, to: origin.x + width)

            drawCellText(
                row.0.uppercased(),
                frame: CGRect(x: origin.x + 6, y: y, width: labelWidth - 12, height: rowHeight),
                font: .boldSystemFont(ofSize: 9.5),
                alignment: .left
            )

            drawCellText(
                row.1,
                frame: CGRect(x: origin.x + labelWidth + 8, y: y, width: width - labelWidth - 12, height: rowHeight),
                font: .systemFont(ofSize: 10),
                alignment: .left
            )
        }

        return totalHeight
    }

    @discardableResult
    private func drawFormalRouteBlock(
        origin: CGPoint,
        width: CGFloat,
        routeText: String,
        attachedPagesText: String
    ) -> CGFloat {
        let titleHeight: CGFloat = 24
        let routeHeight: CGFloat = 40
        let footerHeight: CGFloat = 24
        let totalHeight = titleHeight + routeHeight + footerHeight
        let labelWidth: CGFloat = 110
        let footerSplitX = origin.x + (width * 0.68)

        drawTableFrame(origin: origin, width: width, height: totalHeight)
        drawSectionTitle("SECTOR ROUTING", rect: CGRect(x: origin.x, y: origin.y, width: width, height: titleHeight))

        let routeY = origin.y + titleHeight
        let footerY = routeY + routeHeight

        drawHorizontalLine(y: routeY, from: origin.x, to: origin.x + width)
        drawHorizontalLine(y: footerY, from: origin.x, to: origin.x + width)
        drawVerticalLine(x: origin.x + labelWidth, from: routeY, to: footerY)
        drawVerticalLine(x: footerSplitX, from: footerY, to: origin.y + totalHeight)

        drawCellText(
            "LEGS",
            frame: CGRect(x: origin.x + 6, y: routeY, width: labelWidth - 12, height: routeHeight),
            font: .boldSystemFont(ofSize: 9.5),
            alignment: .left
        )

        drawWrappedText(
            routeText,
            in: CGRect(x: origin.x + labelWidth + 8, y: routeY + 6, width: width - labelWidth - 14, height: routeHeight - 10),
            font: .systemFont(ofSize: 10),
            color: .black,
            alignment: .left
        )

        drawCellText(
            "ATTACHED PAGES",
            frame: CGRect(x: origin.x + 6, y: footerY, width: footerSplitX - origin.x - 12, height: footerHeight),
            font: .boldSystemFont(ofSize: 9.5),
            alignment: .left
        )

        drawCellText(
            attachedPagesText,
            frame: CGRect(x: footerSplitX + 8, y: footerY, width: origin.x + width - footerSplitX - 12, height: footerHeight),
            font: .systemFont(ofSize: 10),
            alignment: .left
        )

        return totalHeight
    }

    @discardableResult
    private func drawCaptainReleaseBlock(
        flight: Flight,
        signatureData: Data?,
        origin: CGPoint,
        width: CGFloat
    ) -> CGFloat {
        let titleHeight: CGFloat = 24
        let statementHeight: CGFloat = 48
        let printedNameHeight: CGFloat = 26
        let signatureHeight: CGFloat = 66
        let dateHeight: CGFloat = 26
        let totalHeight = titleHeight + statementHeight + printedNameHeight + signatureHeight + dateHeight
        let labelWidth: CGFloat = 120

        drawTableFrame(origin: origin, width: width, height: totalHeight)
        drawSectionTitle("CAPTAIN RELEASE", rect: CGRect(x: origin.x, y: origin.y, width: width, height: titleHeight))

        let statementY = origin.y + titleHeight
        let printedNameY = statementY + statementHeight
        let signatureY = printedNameY + printedNameHeight
        let dateY = signatureY + signatureHeight

        drawHorizontalLine(y: statementY, from: origin.x, to: origin.x + width)
        drawHorizontalLine(y: printedNameY, from: origin.x, to: origin.x + width)
        drawHorizontalLine(y: signatureY, from: origin.x, to: origin.x + width)
        drawHorizontalLine(y: dateY, from: origin.x, to: origin.x + width)

        drawWrappedText(
            "I confirm that the dispatch information, aircraft recency, and crew recency pages were reviewed before departure and that the flight may be released subject to operational requirements.",
            in: CGRect(x: origin.x + 10, y: statementY + 8, width: width - 20, height: statementHeight - 12),
            font: .systemFont(ofSize: 10.5),
            color: .black,
            alignment: .left
        )

        drawVerticalLine(x: origin.x + labelWidth, from: printedNameY, to: origin.y + totalHeight)

        drawCellText(
            "PRINTED NAME",
            frame: CGRect(x: origin.x + 6, y: printedNameY, width: labelWidth - 12, height: printedNameHeight),
            font: .boldSystemFont(ofSize: 9.5),
            alignment: .left
        )
        drawCellText(
            valueOrDash(flight.pic),
            frame: CGRect(x: origin.x + labelWidth + 8, y: printedNameY, width: width - labelWidth - 12, height: printedNameHeight),
            font: .systemFont(ofSize: 10),
            alignment: .left
        )

        drawCellText(
            "SIGNATURE",
            frame: CGRect(x: origin.x + 6, y: signatureY, width: labelWidth - 12, height: signatureHeight),
            font: .boldSystemFont(ofSize: 9.5),
            alignment: .left
        )

        if let signatureImage = signatureImage(from: signatureData) {
            let imageRect = CGRect(
                x: origin.x + labelWidth + 12,
                y: signatureY + 10,
                width: width - labelWidth - 24,
                height: signatureHeight - 20
            )
            drawSignatureImage(signatureImage, in: imageRect)
        }

        drawCellText(
            "DATE",
            frame: CGRect(x: origin.x + 6, y: dateY, width: labelWidth - 12, height: dateHeight),
            font: .boldSystemFont(ofSize: 9.5),
            alignment: .left
        )
        drawCellText(
            flight.dispatchDisplayDate.efbDate,
            frame: CGRect(x: origin.x + labelWidth + 8, y: dateY, width: width - labelWidth - 12, height: dateHeight),
            font: .systemFont(ofSize: 10),
            alignment: .left
        )

        return totalHeight
    }

    @discardableResult
    private func drawNotesBlock(
        origin: CGPoint,
        width: CGFloat,
        notes: String
    ) -> CGFloat {
        let titleHeight: CGFloat = 24
        let bodyHeight: CGFloat = 54
        let totalHeight = titleHeight + bodyHeight

        drawTableFrame(origin: origin, width: width, height: totalHeight)
        drawSectionTitle("DISPATCH NOTES", rect: CGRect(x: origin.x, y: origin.y, width: width, height: titleHeight))
        drawHorizontalLine(y: origin.y + titleHeight, from: origin.x, to: origin.x + width)

        drawWrappedText(
            notes,
            in: CGRect(x: origin.x + 10, y: origin.y + titleHeight + 8, width: width - 20, height: bodyHeight - 12),
            font: .systemFont(ofSize: 10),
            color: .black,
            alignment: .left
        )

        return totalHeight
    }

    // MARK: - Recency Pages

    private func drawAircraftRecencyPage(for aircraft: Aircraft?, flight: Flight) {
        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)

        drawPageBorder()
        drawDispatchHeader(title: "AIRCRAFT RECENCY", subtitle: valueOrDash(flight.aircraftReg))

        guard let aircraft else {
            drawEmptyState(text: "No aircraft record was linked to this flight.")
            return
        }

        let rows = aircraft.documents
            .sorted { $0.type.rawValue < $1.type.rawValue }
            .map {
                RecencyRow(
                    title: $0.type.rawValue,
                    lastConducted: $0.lastCompleted?.efbDate ?? "-",
                    expiry: $0.expiry?.efbDate ?? "N/A",
                    status: Compliance.status(
                        forExpiry: $0.expiry,
                        asOf: Date(),
                        cautionDays: cautionDays
                    )
                )
            }

        drawRecencyTable(title: "AIRCRAFT DOCUMENTS", rows: rows, originY: 150)
    }

    private func drawCrewRecencyPage(title: String, crewMember: CrewMember?) {
        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)

        drawPageBorder()
        drawDispatchHeader(
            title: title,
            subtitle: crewMember?.fullDisplayName ?? "No record linked"
        )

        guard let crewMember else {
            drawEmptyState(text: "No crew record was linked for this page.")
            return
        }

        let rows = crewRows(for: crewMember)
        drawRecencyTable(title: "TRAINING", rows: rows, originY: 150)
    }

    private func crewRows(for crewMember: CrewMember) -> [RecencyRow] {
        let trainingRows = crewMember.trainings
            .sorted { $0.type.rawValue < $1.type.rawValue }
            .map {
                RecencyRow(
                    title: $0.type.rawValue,
                    lastConducted: $0.isNotApplicable ? "N/R" : ($0.lastConducted?.efbDate ?? "-"),
                    expiry: $0.isNotApplicable ? "N/R" : ($0.expiry?.efbDate ?? "-"),
                    status: $0.isNotApplicable ? .na : $0.status(asOf: Date(), cautionDays: cautionDays)
                )
            }

        let recencyItems: [(String, Bool)] = [
            ("Line training record", crewMember.lineTrainingRecord),
            ("Line training report", crewMember.lineTrainingReport),
            ("Induction checklist", crewMember.inductionChecklist),
            ("CV", crewMember.cv),
            ("Personal data sheet", crewMember.personalDataSheet),
            ("Drug and alcohol policy", crewMember.drugAndAlcoholPolicy),
            ("Internet usage policy", crewMember.internetUsagePolicy)
        ]

        let recencyRows = recencyItems.map { item in
            RecencyRow(
                title: item.0,
                lastConducted: item.1 ? "RECORDED" : "MISSING",
                expiry: "-",
                status: item.1 ? .ok : .expired
            )
        }

        return recencyRows + trainingRows
    }

    // MARK: - Drawing Helpers

    private func drawDispatchHeader(title: String, subtitle: String) {
        drawWrappedText(
            title,
            in: CGRect(
                x: margin,
                y: 20,
                width: pageRect.width - (margin * 2),
                height: 30
            ),
            font: .boldSystemFont(ofSize: 22),
            color: .black,
            alignment: .center
        )

        drawWrappedText(
            subtitle,
            in: CGRect(
                x: margin,
                y: 52,
                width: pageRect.width - (margin * 2),
                height: 20
            ),
            font: .systemFont(ofSize: 12),
            color: .darkGray,
            alignment: .center
        )
    }

    private func drawSectionTitle(_ title: String, rect: CGRect) {
        drawCellText(
            title,
            frame: rect,
            font: .boldSystemFont(ofSize: 11.5),
            alignment: .center
        )
    }

    private func drawPageBorder() {
        let rect = pageRect.insetBy(dx: 12, dy: 12)
        let path = UIBezierPath(rect: rect)

        UIColor.black.setStroke()
        path.lineWidth = 1.2
        path.stroke()
    }

    private func drawEmptyState(text: String) {
        drawWrappedText(
            text,
            in: CGRect(
                x: margin,
                y: 200,
                width: pageRect.width - (margin * 2),
                height: 120
            ),
            font: .systemFont(ofSize: 16),
            color: .darkGray,
            alignment: .center
        )
    }

    // MARK: - Tables

    private func drawRecencyTable(title: String, rows: [RecencyRow], originY: CGFloat) {
        let width = pageRect.width - margin * 2
        let x = margin

        let headerHeight: CGFloat = 24
        let columnHeaderHeight: CGFloat = 24
        let rowHeight: CGFloat = 22

        let usableRows = min(rows.count, 28)
        let tableHeight = headerHeight + columnHeaderHeight + CGFloat(usableRows) * rowHeight

        let titleWidth: CGFloat = width * 0.40
        let lastWidth: CGFloat = width * 0.20
        let expiryWidth: CGFloat = width * 0.20
        let statusWidth: CGFloat = width - titleWidth - lastWidth - expiryWidth

        drawTableFrame(origin: CGPoint(x: x, y: originY), width: width, height: tableHeight)

        drawCellText(
            title,
            frame: CGRect(x: x, y: originY, width: width, height: headerHeight),
            font: .boldSystemFont(ofSize: 12),
            alignment: .center
        )

        let headerY = originY + headerHeight
        drawHorizontalLine(y: headerY, from: x, to: x + width)
        drawHorizontalLine(y: headerY + columnHeaderHeight, from: x, to: x + width)

        let c1 = x + titleWidth
        let c2 = c1 + lastWidth
        let c3 = c2 + expiryWidth

        drawVerticalLine(x: c1, from: headerY, to: originY + tableHeight)
        drawVerticalLine(x: c2, from: headerY, to: originY + tableHeight)
        drawVerticalLine(x: c3, from: headerY, to: originY + tableHeight)

        drawCellText(
            "RECENCY ITEM",
            frame: CGRect(x: x + 6, y: headerY, width: titleWidth - 12, height: columnHeaderHeight),
            font: .boldSystemFont(ofSize: 10),
            alignment: .left
        )

        drawCellText(
            "LAST CONDUCTED",
            frame: CGRect(x: c1 + 4, y: headerY, width: lastWidth - 8, height: columnHeaderHeight),
            font: .boldSystemFont(ofSize: 10),
            alignment: .center
        )

        drawCellText(
            "EXPIRES",
            frame: CGRect(x: c2 + 4, y: headerY, width: expiryWidth - 8, height: columnHeaderHeight),
            font: .boldSystemFont(ofSize: 10),
            alignment: .center
        )

        drawCellText(
            "STATUS",
            frame: CGRect(x: c3 + 4, y: headerY, width: statusWidth - 8, height: columnHeaderHeight),
            font: .boldSystemFont(ofSize: 10),
            alignment: .center
        )

        for (index, row) in rows.prefix(usableRows).enumerated() {
            let y = headerY + columnHeaderHeight + CGFloat(index) * rowHeight

            drawHorizontalLine(y: y + rowHeight, from: x, to: x + width)

            drawCellText(
                row.title,
                frame: CGRect(x: x + 6, y: y, width: titleWidth - 12, height: rowHeight),
                font: .systemFont(ofSize: 9.5),
                alignment: .left
            )

            drawCellText(
                row.lastConducted,
                frame: CGRect(x: c1 + 4, y: y, width: lastWidth - 8, height: rowHeight),
                font: .systemFont(ofSize: 9.5),
                alignment: .center
            )

            drawCellText(
                row.expiry,
                frame: CGRect(x: c2 + 4, y: y, width: expiryWidth - 8, height: rowHeight),
                font: .systemFont(ofSize: 9.5),
                alignment: .center
            )

            if row.status == .na {
                drawCellText(
                    "N/R",
                    frame: CGRect(x: c3 + 4, y: y, width: statusWidth - 8, height: rowHeight),
                    font: .boldSystemFont(ofSize: 9.5),
                    alignment: .center
                )
            } else {
                drawStatusPill(
                    status: row.status,
                    frame: CGRect(x: c3 + 8, y: y + 3, width: statusWidth - 16, height: rowHeight - 6)
                )
            }
        }
    }

    private func drawStatusPill(status: ComplianceStatus, frame: CGRect) {
        let path = UIBezierPath(roundedRect: frame, cornerRadius: 6)

        status.uiColor.withAlphaComponent(0.15).setFill()
        path.fill()

        status.uiColor.setStroke()
        path.lineWidth = 0.8
        path.stroke()

        drawWrappedText(
            status.label,
            in: frame,
            font: .boldSystemFont(ofSize: 9),
            color: status.uiColor,
            alignment: .center
        )
    }

    private func drawTableFrame(origin: CGPoint, width: CGFloat, height: CGFloat) {
        let rect = CGRect(x: origin.x, y: origin.y, width: width, height: height)
        let path = UIBezierPath(rect: rect)

        UIColor.black.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawHorizontalLine(y: CGFloat, from startX: CGFloat, to endX: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: startX, y: y))
        path.addLine(to: CGPoint(x: endX, y: y))
        UIColor.black.setStroke()
        path.lineWidth = 0.8
        path.stroke()
    }

    private func drawVerticalLine(x: CGFloat, from startY: CGFloat, to endY: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x, y: startY))
        path.addLine(to: CGPoint(x: x, y: endY))
        UIColor.black.setStroke()
        path.lineWidth = 0.8
        path.stroke()
    }

    private func drawCellText(
        _ text: String,
        frame: CGRect,
        font: UIFont,
        alignment: NSTextAlignment
    ) {
        drawWrappedText(text, in: frame, font: font, color: .black, alignment: alignment)
    }

    private func drawWrappedText(
        _ text: String,
        in frame: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]

        (text as NSString).draw(in: frame, withAttributes: attrs)
    }

    // MARK: - Signature Handling

    private func signatureImage(from data: Data?) -> UIImage? {
        guard let data, !data.isEmpty else { return nil }

        if let image = UIImage(data: data) {
            return image
        }

        if let drawing = try? PKDrawing(data: data) {
            let bounds = drawing.bounds

            if bounds.isEmpty {
                return drawing.image(from: CGRect(x: 0, y: 0, width: 600, height: 200), scale: 2.0)
            }

            return drawing.image(from: bounds, scale: 2.0)
        }

        return nil
    }

    private func drawSignatureImage(_ image: UIImage, in rect: CGRect) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            image.draw(in: rect)
            return
        }

        let widthRatio = rect.width / imageSize.width
        let heightRatio = rect.height / imageSize.height
        let scale = min(widthRatio, heightRatio)

        let drawWidth = imageSize.width * scale
        let drawHeight = imageSize.height * scale

        let drawRect = CGRect(
            x: rect.midX - (drawWidth / 2),
            y: rect.midY - (drawHeight / 2),
            width: drawWidth,
            height: drawHeight
        )

        image.draw(in: drawRect)
    }

    // MARK: - Helpers

    private func valueOrDash(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed
    }
}

// MARK: - Models

private struct RecencyRow {
    let title: String
    let lastConducted: String
    let expiry: String
    let status: ComplianceStatus
}

// MARK: - Extensions

private extension ComplianceStatus {
    var uiColor: UIColor {
        switch self {
        case .ok: return .systemGreen
        case .caution: return .systemOrange
        case .expired: return .systemRed
        case .na: return .systemGray
        }
    }
}

private extension Flight {
    var firstPICSignatureDrawing: Data? {
        daySigns.sorted(by: { $0.date < $1.date }).first?.picSignOnDrawing
    }

    var dispatchDisplayDate: Date {
        legs.sorted(by: { $0.sequence < $1.sequence }).first?.date ?? createdAt
    }
}
