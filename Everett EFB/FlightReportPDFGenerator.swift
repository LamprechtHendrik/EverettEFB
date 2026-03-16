import Foundation
import PDFKit
import UIKit
import PencilKit
import CoreLocation
import AVFoundation

struct FlightReportPDFGenerator {
    private let pageSize = CGSize(width: 842, height: 595) // A4 landscape @ 72 dpi
    private let margin: CGFloat = 24

    private let authorizedRowsPerPage = 12
    private let voyageRowsPerPage = 12
    private let fdpRowsPerPage = 4

    private let brandRed = UIColor(red: 0.72, green: 0.12, blue: 0.22, alpha: 1.0)
    private let brandBlue = UIColor(red: 0.67, green: 0.82, blue: 0.96, alpha: 1.0)
    private let lineColor = UIColor.black
    private let lightFill = UIColor(white: 0.97, alpha: 1.0)

    enum GeneratorError: LocalizedError {
        case cannotCreateGeneratedDocument

        var errorDescription: String? {
            switch self {
            case .cannotCreateGeneratedDocument:
                return "The generated PDF could not be created."
            }
        }
    }

    func generatePDF(for flight: Flight) throws -> PDFDocument {
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let authorizedPages = max(1, Int(ceil(Double(flight.sortedLegs.count) / Double(authorizedRowsPerPage))))
        let voyagePages = max(1, Int(ceil(Double(flight.sortedLegs.count) / Double(voyageRowsPerPage))))
        let fdpPages = max(1, Int(ceil(Double(flight.sortedDaySigns.count) / Double(fdpRowsPerPage))))

        let data = renderer.pdfData { context in
            for pageIndex in 0..<authorizedPages {
                context.beginPage()
                drawAuthorizedLegsPage(
                    flight: flight,
                    pageIndex: pageIndex,
                    rowsPerPage: authorizedRowsPerPage,
                    context: context.cgContext,
                    pageRect: pageRect,
                    totalPages: authorizedPages
                )
            }

            for pageIndex in 0..<voyagePages {
                context.beginPage()
                drawVoyagePage(
                    flight: flight,
                    pageIndex: pageIndex,
                    rowsPerPage: voyageRowsPerPage,
                    context: context.cgContext,
                    pageRect: pageRect,
                    totalPages: voyagePages
                )
            }

            for pageIndex in 0..<fdpPages {
                context.beginPage()
                drawFDPPage(
                    flight: flight,
                    pageIndex: pageIndex,
                    rowsPerPage: fdpRowsPerPage,
                    context: context.cgContext,
                    pageRect: pageRect,
                    totalPages: fdpPages
                )
            }
        }

        guard let document = PDFDocument(data: data) else {
            throw GeneratorError.cannotCreateGeneratedDocument
        }

        return document
    }

    // MARK: - Section Pages

    private func drawAuthorizedLegsPage(
        flight: Flight,
        pageIndex: Int,
        rowsPerPage: Int,
        context: CGContext,
        pageRect: CGRect,
        totalPages: Int
    ) {
        drawPageChrome(
            title: "FLIGHT REPORT",
            subtitle: "AUTHORISED LEGS",
            sectionPageText: "Authorised Legs Page \(pageIndex + 1) of \(totalPages)",
            flight: flight,
            context: context,
            pageRect: pageRect
        )

        let detailRect = CGRect(x: margin, y: 130, width: pageRect.width - (margin * 2), height: 102)
        drawInfoGrid(
            title: "FLIGHT DETAILS",
            items: [
                ("Date", shortDate(flight.reportFolderDate)),
                ("Aircraft", nonEmpty(flight.aircraftReg)),
                ("Flight Report No", nonEmpty(flight.reportNumber)),
                ("Client", nonEmpty(flight.client)),
                ("Type of Flight", flight.flightType.rawValue),
                ("PIC", nonEmpty(flight.pic)),
                ("SIC", nonEmpty(flight.sic)),
                ("Cabin Crew", nonEmpty(flight.cabinCrew)),
                ("Open Legs", "\(flight.sortedLegs.count)")
            ],
            rect: detailRect,
            context: context
        )

        let columns: [ReportColumn] = [
            .init(title: "Leg", width: 48, alignment: .center),
            .init(title: "Date", width: 92, alignment: .center),
            .init(title: "ETD", width: 72, alignment: .center),
            .init(title: "Call Sign", width: 100, alignment: .center),
            .init(title: "Flights", width: 360, alignment: .left),
            .init(title: "Dist.", width: 80, alignment: .center),
            .init(title: "PAX", width: 42, alignment: .center)
        ]

        // Stop the table above the signature area
        let signatureBandTop: CGFloat = pageRect.height - 82
        let tableTop = detailRect.maxY + 14
        let tableHeight = signatureBandTop - tableTop

        let tableRect = CGRect(
            x: margin,
            y: tableTop,
            width: pageRect.width - (margin * 2),
            height: tableHeight
        )

        drawTable(
            columns: columns,
            rowCount: rowsPerPage,
            rowHeight: 22,
            in: tableRect,
            context: context,
            headerFill: brandBlue
        )

        let rows = pagedItems(flight.sortedLegs, pageIndex: pageIndex, rowsPerPage: rowsPerPage)
        for (rowIndex, leg) in rows.enumerated() {
            let rowRect = tableRowRect(tableRect: tableRect, rowIndex: rowIndex, rowHeight: 22)
            drawRow(
                values: [
                    "\(leg.sequence)",
                    shortDate(leg.date),
                    TimeEntryHelper.display(from: leg.departureTime),
                    leg.callSign,
                    authorizedFlightDescription(for: leg),
                    distanceText(for: leg),
                    intString(leg.pax)
                ],
                columns: columns,
                in: rowRect,
                context: context
            )
        }

        let signRect = CGRect(
            x: pageRect.width - 280,
            y: pageRect.height - 72,
            width: 256,
            height: 36
        )
        drawSignaturePanel(title: "Pilot Signature", rect: signRect, context: context)

        if pageIndex == 0,
           let image = imageFromDrawingData(flight.sortedDaySigns.first?.picSignOnDrawing) {
            drawSignatureImage(image, in: signRect.insetBy(dx: 90, dy: 5), context: context)
        }
    }

    private func drawVoyagePage(
        flight: Flight,
        pageIndex: Int,
        rowsPerPage: Int,
        context: CGContext,
        pageRect: CGRect,
        totalPages: Int
    ) {
        drawPageChrome(
            title: "FLIGHT REPORT",
            subtitle: "VOYAGE / ACTUALS",
            sectionPageText: "Voyage Page \(pageIndex + 1) of \(totalPages)",
            flight: flight,
            context: context,
            pageRect: pageRect
        )

        let columns: [ReportColumn] = [
            .init(title: "Leg", width: 28, alignment: .center),
            .init(title: "Date", width: 52, alignment: .center),
            .init(title: "From", width: 38, alignment: .center),
            .init(title: "To", width: 38, alignment: .center),
            .init(title: "BLK OFF", width: 46, alignment: .center),
            .init(title: "BLK ON", width: 46, alignment: .center),
            .init(title: "BLK TIME", width: 50, alignment: .center),
            .init(title: "TKOF", width: 44, alignment: .center),
            .init(title: "LDG", width: 44, alignment: .center),
            .init(title: "FLT TIME", width: 50, alignment: .center),
            .init(title: "DEP", width: 42, alignment: .center),
            .init(title: "LDG", width: 42, alignment: .center),
            .init(title: "USED", width: 38, alignment: .center),
            .init(title: "PAX", width: 34, alignment: .center),
            .init(title: "CARGO", width: 40, alignment: .center),
            .init(title: "UPLIFT", width: 40, alignment: .center),
            .init(title: "INVOICE", width: 54, alignment: .left),
            .init(title: "LOC", width: 30, alignment: .center)
        ]

        let tableRect = CGRect(x: margin, y: 144, width: pageRect.width - (margin * 2), height: 290)

        let groupHeaderRect = CGRect(x: tableRect.minX, y: tableRect.minY - 12, width: tableRect.width, height: 18)
        drawVoyageGroupHeader(columns: columns, in: groupHeaderRect, context: context)

        drawTable(columns: columns, rowCount: rowsPerPage, rowHeight: 22, in: tableRect, context: context, headerFill: brandBlue)

        let rows = pagedItems(flight.sortedLegs, pageIndex: pageIndex, rowsPerPage: rowsPerPage)
        for (rowIndex, leg) in rows.enumerated() {
            let rowRect = tableRowRect(tableRect: tableRect, rowIndex: rowIndex, rowHeight: 22)
            drawRow(
                values: [
                    "\(leg.sequence)",
                    shortDate(leg.date),
                    leg.departure,
                    leg.destination,
                    TimeEntryHelper.display(from: leg.blockOff),
                    TimeEntryHelper.display(from: leg.blockOn),
                    durationString(leg.blockTimeMinutes),
                    TimeEntryHelper.display(from: leg.takeOff),
                    TimeEntryHelper.display(from: leg.landing),
                    durationString(leg.flightTimeMinutes),
                    intString(leg.depFuel),
                    intString(leg.ldgFuel),
                    intString(leg.fuelUsed),
                    intString(leg.pax),
                    intString(leg.cargo),
                    intString(leg.uplift),
                    leg.fuelInvoice,
                    leg.loc
                ],
                columns: columns,
                in: rowRect,
                context: context
            )
        }

        let totalsRowRect = CGRect(
            x: tableRect.minX,
            y: tableRect.maxY + 10,
            width: tableRect.width,
            height: 34
        )
        drawVoyageTotalsRow(flight: flight, columns: columns, in: totalsRowRect, context: context)

        let delaysRect = CGRect(
            x: tableRect.minX,
            y: totalsRowRect.maxY + 10,
            width: tableRect.width,
            height: 64
        )
        drawVoyageDelaysBox(flight: flight, in: delaysRect, context: context)

        let notesRect = CGRect(
            x: tableRect.minX,
            y: delaysRect.maxY + 10,
            width: tableRect.width,
            height: 56
        )
        drawVoyageNotesBox(flight: flight, in: notesRect, context: context)
    }

    private func drawFDPPage(
        flight: Flight,
        pageIndex: Int,
        rowsPerPage: Int,
        context: CGContext,
        pageRect: CGRect,
        totalPages: Int
    ) {
        drawPageChrome(
            title: "FLIGHT REPORT",
            subtitle: "FLIGHT DUTY PERIOD RECORD",
            sectionPageText: "FDP Page \(pageIndex + 1) of \(totalPages)",
            flight: flight,
            context: context,
            pageRect: pageRect
        )

        let days = pagedItems(flight.sortedDaySigns, pageIndex: pageIndex, rowsPerPage: rowsPerPage)
        let blockTop: CGFloat = 130
        let blockHeight: CGFloat = 132
        let spacing: CGFloat = 12

        for (index, day) in days.enumerated() {
            let y = blockTop + CGFloat(index) * (blockHeight + spacing)
            let blockRect = CGRect(x: margin, y: y, width: pageRect.width - (margin * 2), height: blockHeight)
            drawPanel(rect: blockRect, fill: lightFill, context: context)

            drawSectionTitle("Operating Day", at: CGPoint(x: blockRect.minX + 10, y: blockRect.minY + 8), context: context)
            drawValueLabel("Date", value: shortDate(day.date), x: blockRect.minX + 12, y: blockRect.minY + 30, context: context)

            let timeColumnStartX = blockRect.minX + 180
            let timeColumnTopY = blockRect.minY + 24
            let timeLabelRowHeight: CGFloat = 14
            let timeValueRowHeight: CGFloat = 16
            let timeColumnWidth: CGFloat = 92

            let totalDutyMinutes = TimeEntryHelper.durationMinutes(from: day.signOnTime, to: day.signOffTime)
            let allowedDutyMinutes = dutyAllowedMinutes(for: day, flight: flight)
            let dutyAllowedDisplay = allowedDutyMinutes.map(TimeEntryHelper.formattedDuration) ?? "-"
            let totalDutyDisplay = TimeEntryHelper.formattedDuration(totalDutyMinutes)

            let totalDutyExceeded = {
                guard let totalDutyMinutes, let allowedDutyMinutes else { return false }
                return totalDutyMinutes > allowedDutyMinutes
            }()

            let timeItems: [(String, String, UIColor)] = [
                ("SIGN ON", nonEmpty(day.signOnTime), .black),
                ("INT SIGN OFF", day.intermediateSignOffDisplay, .black),
                ("INT SIGN ON", day.intermediateSignOnDisplay, .black),
                ("TOTAL SPLIT DUTY", day.totalSplitDutyDisplay, .black),
                ("DUTY ALLOWED", dutyAllowedDisplay, .black),
                ("TOTAL DUTY", totalDutyDisplay, totalDutyExceeded ? .red : .black)
            ]

            for (index, item) in timeItems.enumerated() {
                let x = timeColumnStartX + CGFloat(index) * timeColumnWidth
                let labelRect = CGRect(x: x, y: timeColumnTopY, width: timeColumnWidth, height: timeLabelRowHeight)
                let valueRect = CGRect(x: x, y: timeColumnTopY + timeLabelRowHeight, width: timeColumnWidth, height: timeValueRowHeight)

                drawFDPTimeHeader(title: item.0, rect: labelRect, context: context)
                drawFDPTimeValue(value: item.1, rect: valueRect, color: item.2, context: context)
            }

            var crewEntries: [(role: String, name: String, signOn: Data?, signOff: Data?)] = [
                ("PIC", flight.pic, day.picSignOnDrawing, day.picSignOffDrawing),
                ("SIC", flight.sic, day.sicSignOnDrawing, day.sicSignOffDrawing)
            ]

            if !flight.cabinCrew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                crewEntries.append(("CABIN", flight.cabinCrew, day.cabinSignOnDrawing, day.cabinSignOffDrawing))
            }

            for (crewIndex, entry) in crewEntries.enumerated() {
                let baseX = blockRect.minX + 220 + CGFloat(crewIndex) * 170
                let signOnRect = CGRect(x: baseX, y: blockRect.minY + 62, width: 70, height: 28)
                let signOffRect = CGRect(x: baseX + 78, y: blockRect.minY + 62, width: 70, height: 28)

                drawSignaturePanel(title: "ON", rect: signOnRect, context: context)
                drawSignaturePanel(title: "OFF", rect: signOffRect, context: context)

                if let image = imageFromDrawingData(entry.signOn) {
                    drawSignatureImage(image, in: signOnRect.insetBy(dx: 14, dy: 5), context: context)
                }
                if let image = imageFromDrawingData(entry.signOff) {
                    drawSignatureImage(image, in: signOffRect.insetBy(dx: 14, dy: 5), context: context)
                }

                drawSectionTitle(entry.role, at: CGPoint(x: baseX, y: blockRect.minY + 96), context: context)
                drawText(nonEmpty(entry.name), x: baseX, y: blockRect.minY + 108, fontSize: 10, in: context, maxWidth: 150)
            }
        }
    }

    // MARK: - Page Chrome

    private func drawPageChrome(
        title: String,
        subtitle: String,
        sectionPageText: String,
        flight: Flight,
        context: CGContext,
        pageRect: CGRect
    ) {
        context.setFillColor(UIColor.white.cgColor)
        context.fill(pageRect)

        let outerRect = pageRect.insetBy(dx: margin, dy: margin)
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1.2)
        context.stroke(outerRect)

        let titleRect = CGRect(x: margin, y: margin, width: pageRect.width - (margin * 2), height: 74)
        drawPanel(rect: titleRect, fill: UIColor.white, context: context)
        context.setFillColor(brandRed.cgColor)
        context.fill(CGRect(x: titleRect.minX, y: titleRect.minY, width: 6, height: titleRect.height))

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        let subAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.darkGray
        ]
        let rightAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]

        let logoRect = CGRect(x: titleRect.minX - 130, y: titleRect.minY - 25, width: 420, height: 116)
        drawEverettLogo(in: logoRect, context: context)

        let centerTitleRect = CGRect(x: titleRect.minX + 230, y: titleRect.minY + 12, width: titleRect.width - 430, height: 28)
        let centerSubtitleRect = CGRect(x: titleRect.minX + 230, y: titleRect.minY + 42, width: titleRect.width - 430, height: 16)
        let rightTextRect = CGRect(x: titleRect.maxX - 190, y: titleRect.minY + 14, width: 170, height: 30)

        let centerParagraph = NSMutableParagraphStyle()
        centerParagraph.alignment = .center
        let centeredTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black,
            .paragraphStyle: centerParagraph
        ]
        let centeredSubtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: centerParagraph
        ]

        let rightParagraph = NSMutableParagraphStyle()
        rightParagraph.alignment = .right
        let rightAlignedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: rightParagraph
        ]

        NSString(string: title).draw(in: centerTitleRect, withAttributes: centeredTitleAttributes)
        NSString(string: subtitle).draw(in: centerSubtitleRect, withAttributes: centeredSubtitleAttributes)
        NSString(string: sectionPageText).draw(in: rightTextRect, withAttributes: rightAlignedAttributes)

        let headerRect = CGRect(x: margin, y: 100, width: pageRect.width - (margin * 2), height: 28)
        drawHeaderStrip(flight: flight, rect: headerRect, context: context)
    }

    private func drawHeaderStrip(flight: Flight, rect: CGRect, context: CGContext) {
        context.setFillColor(brandBlue.withAlphaComponent(0.25).cgColor)
        context.fill(rect)
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1)
        context.stroke(rect)

        let items = [
            "Date: \(shortDate(flight.reportFolderDate))",
            "Aircraft: \(nonEmpty(flight.aircraftReg))",
            "Client: \(nonEmpty(flight.client))",
            "FR No: \(nonEmpty(flight.reportNumber))"
        ]

        let columnWidth = rect.width / CGFloat(items.count)
        for (index, item) in items.enumerated() {
            let x = rect.minX + CGFloat(index) * columnWidth
            if index > 0 {
                context.stroke(CGRect(x: x, y: rect.minY, width: 0, height: rect.height))
            }
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]
            NSString(string: item).draw(in: CGRect(x: x + 8, y: rect.minY + 8, width: columnWidth - 12, height: 12), withAttributes: attrs)
        }
    }

    private func drawEverettLogo(in rect: CGRect, context: CGContext) {
        if let image = UIImage(named: "EverettLogo") ?? UIImage(named: "everett_logo") {
            drawLogoImage(image, in: rect, context: context)
            return
        }

        if let bundledImage = UIImage(contentsOfFile: Bundle.main.path(forResource: "EverettLogo", ofType: "png") ?? "") ??
            UIImage(contentsOfFile: Bundle.main.path(forResource: "EverettLogo", ofType: "jpg") ?? "") ??
            UIImage(contentsOfFile: Bundle.main.path(forResource: "EverettLogo", ofType: "jpeg") ?? "") {
            drawLogoImage(bundledImage, in: rect, context: context)
            return
        }

        // Fallback placeholder until the real logo asset is added to the app bundle.
        let oval = UIBezierPath(ovalIn: rect)
        context.setStrokeColor(brandRed.cgColor)
        context.setLineWidth(2)
        context.addPath(oval.cgPath)
        context.strokePath()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.darkGray
        ]
        NSString(string: "EVERETT").draw(in: CGRect(x: rect.minX + 10, y: rect.minY + 4, width: rect.width - 20, height: 12), withAttributes: attrs)
        NSString(string: "AVIATION").draw(
            in: CGRect(x: rect.minX + 14, y: rect.minY + 13, width: rect.width - 28, height: 10),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
        )
    }

    private func drawLogoImage(_ image: UIImage, in rect: CGRect, context: CGContext) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            image.draw(in: rect)
            return
        }

        let aspectFitRect = AVMakeRect(aspectRatio: imageSize, insideRect: rect)
        image.draw(in: aspectFitRect)
    }

    // MARK: - Blocks

    private func drawInfoGrid(
        title: String,
        items: [(String, String)],
        rect: CGRect,
        context: CGContext
    ) {
        drawPanel(rect: rect, fill: lightFill, context: context)
        drawSectionTitle(title, at: CGPoint(x: rect.minX + 10, y: rect.minY + 8), context: context)

        let columns = 2
        let rows = Int(ceil(Double(items.count) / Double(columns)))
        let itemWidth = (rect.width - 20) / CGFloat(columns)
        let itemHeight = (rect.height - 28) / CGFloat(max(rows, 1))

        for (index, item) in items.enumerated() {
            let col = index % columns
            let row = index / columns
            let x = rect.minX + 10 + CGFloat(col) * itemWidth
            let y = rect.minY + 28 + CGFloat(row) * itemHeight
            drawValueLabel(item.0, value: item.1, x: x, y: y, context: context, maxWidth: itemWidth - 14)
        }
    }

    private func drawPanel(rect: CGRect, fill: UIColor, context: CGContext) {
        context.setFillColor(fill.cgColor)
        context.fill(rect)
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1)
        context.stroke(rect)
    }

    private func drawSectionTitle(_ text: String, at point: CGPoint, context: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        NSString(string: text).draw(at: point, withAttributes: attrs)
    }

    private func drawValueLabel(
        _ label: String,
        value: String,
        x: CGFloat,
        y: CGFloat,
        context: CGContext,
        maxWidth: CGFloat = 180
    ) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]
        NSString(string: label).draw(at: CGPoint(x: x, y: y), withAttributes: labelAttrs)
        drawText(value, x: x + 92, y: y - 1, fontSize: 10, in: context, maxWidth: maxWidth - 92)
    }

    private func drawSignaturePanel(title: String, rect: CGRect, context: CGContext) {
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)

        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1)
        context.stroke(rect)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]
        NSString(string: title).draw(at: CGPoint(x: rect.minX + 6, y: rect.minY + 4), withAttributes: attrs)
    }

    private func drawFDPTimeHeader(title: String, rect: CGRect, context: CGContext) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 7),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]

        NSString(string: title).draw(in: rect, withAttributes: attrs)
    }

    private func drawFDPTimeValue(value: String, rect: CGRect, color: UIColor = .black, context: CGContext) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]

        NSString(string: value).draw(in: rect, withAttributes: attrs)
    }

    private func dutyAllowedMinutes(for day: FlightDaySign, flight: Flight) -> Int? {
        let sectors = max(1, min(8, flight.legs(on: day.date).count))

        guard let signOnMinutes = clockMinutes(from: day.signOnTime) else {
            return nil
        }

        let baseAllowedMinutes: Int
        switch signOnMinutes {
        case 300...419: // 05:00 - 06:59
            baseAllowedMinutes = [780, 735, 690, 645, 600, 555, 540, 540][sectors - 1]
        case 420...839: // 07:00 - 13:59
            baseAllowedMinutes = [840, 795, 750, 705, 660, 615, 555, 540][sectors - 1]
        case 840...1259: // 14:00 - 20:59
            baseAllowedMinutes = [780, 735, 690, 645, 600, 555, 540, 540][sectors - 1]
        case 1260...1318: // 21:00 - 21:58
            baseAllowedMinutes = [720, 675, 630, 585, 540, 540, 540, 540][sectors - 1]
        default: // 21:59 - 04:59
            baseAllowedMinutes = [660, 615, 570, 540, 540, 540, 540, 540][sectors - 1]
        }

        let splitDutyBonus: Int
        if let splitMinutes = day.totalSplitDutyMinutes, splitMinutes >= 180 {
            splitDutyBonus = splitMinutes / 2
        } else {
            splitDutyBonus = 0
        }

        return baseAllowedMinutes + splitDutyBonus
    }

    private func clockMinutes(from time: String) -> Int? {
        let normalized = TimeEntryHelper.normalizedDisplay(time) ?? time
        let parts = normalized.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return hour * 60 + minute
    }

    // MARK: - Tables

    private func drawTable(
        columns: [ReportColumn],
        rowCount: Int,
        rowHeight: CGFloat,
        in rect: CGRect,
        context: CGContext,
        headerFill: UIColor
    ) {
        let headerRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rowHeight)
        context.setFillColor(headerFill.cgColor)
        context.fill(headerRect)

        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1)
        context.stroke(rect)

        var x = rect.minX
        for column in columns {
            context.stroke(CGRect(x: x, y: rect.minY, width: 0, height: rect.height))
            drawTableHeader(title: column.title, rect: CGRect(x: x, y: rect.minY, width: column.width, height: rowHeight))
            x += column.width
        }
        context.stroke(CGRect(x: rect.maxX, y: rect.minY, width: 0, height: rect.height))

        for row in 0...rowCount {
            let y = rect.minY + rowHeight + CGFloat(row) * rowHeight
            context.stroke(CGRect(x: rect.minX, y: y, width: rect.width, height: 0))
        }
    }

    private func drawVoyageGroupHeader(columns: [ReportColumn], in rect: CGRect, context: CGContext) {
        var x = rect.minX
        var timeStartX: CGFloat?
        var timeEndX: CGFloat?
        var fuelStartX: CGFloat?
        var fuelEndX: CGFloat?

        for column in columns {
            if column.title == "BLK OFF" { timeStartX = x }
            if column.title == "FLT TIME" { timeEndX = x + column.width }
            if column.title == "DEP" { fuelStartX = x }
            if column.title == "USED" { fuelEndX = x + column.width }
            x += column.width
        }

        // Make the top band look like a true continuation of the table header.
        context.setFillColor(brandBlue.cgColor)
        context.fill(rect)

        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1)
        context.stroke(rect)

        func drawVerticalBorder(at x: CGFloat) {
            context.stroke(CGRect(x: x, y: rect.minY, width: 0, height: rect.height))
        }

        if let timeStartX { drawVerticalBorder(at: timeStartX) }
        if let timeEndX { drawVerticalBorder(at: timeEndX) }
        if let fuelStartX { drawVerticalBorder(at: fuelStartX) }
        if let fuelEndX { drawVerticalBorder(at: fuelEndX) }

        func drawGroupTitle(_ title: String, start: CGFloat, end: CGFloat) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 8),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]

            NSString(string: title).draw(
                in: CGRect(x: start, y: rect.minY + 1, width: end - start, height: rect.height - 2),
                withAttributes: attrs
            )
        }

        if let start = timeStartX, let end = timeEndX {
            drawGroupTitle("TIMES", start: start, end: end)
        }

        if let start = fuelStartX, let end = fuelEndX {
            drawGroupTitle("FUEL", start: start, end: end)
        }
    }

    private func drawTableHeader(title: String, rect: CGRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 8),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]
        NSString(string: title).draw(in: rect.insetBy(dx: 3, dy: 6), withAttributes: attrs)
    }

    private func drawRow(values: [String], columns: [ReportColumn], in rowRect: CGRect, context: CGContext) {
        var x = rowRect.minX
        for (index, column) in columns.enumerated() {
            let value = index < values.count ? values[index] : ""
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = column.alignment
            paragraph.lineBreakMode = .byTruncatingTail
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]
            NSString(string: value).draw(
                in: CGRect(x: x + 3, y: rowRect.minY + 6, width: column.width - 6, height: rowRect.height - 8),
                withAttributes: attrs
            )
            x += column.width
        }
    }

    private func drawVoyageTotalsRow(
        flight: Flight,
        columns: [ReportColumn],
        in rect: CGRect,
        context: CGContext
    ) {
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1)

        let totalBlockTime = flight.sortedLegs.compactMap { $0.blockTimeMinutes }.reduce(0, +)
        let totalFlightTime = flight.sortedLegs.compactMap { $0.flightTimeMinutes }.reduce(0, +)
        let totalFuelUsed = flight.sortedLegs.compactMap { $0.fuelUsed }.reduce(0, +)
        let totalPax = flight.sortedLegs.compactMap { $0.pax }.reduce(0, +)
        let totalCargo = flight.sortedLegs.compactMap { $0.cargo }.reduce(0, +)
        let totalUplift = flight.sortedLegs.compactMap { $0.uplift }.reduce(0, +)

        let mergedLabelColumns = 6
        let mergedLabelWidth = columns.prefix(mergedLabelColumns).reduce(CGFloat(0)) { $0 + $1.width }

        func columnStart(_ title: String) -> CGFloat? {
            var currentX = rect.minX
            for column in columns {
                if column.title == title { return currentX }
                currentX += column.width
            }
            return nil
        }

        func columnWidth(_ title: String) -> CGFloat? {
            columns.first(where: { $0.title == title })?.width
        }

        let blockTimeStart = columnStart("BLK TIME") ?? rect.minX + mergedLabelWidth
        let blockTimeWidth = columnWidth("BLK TIME") ?? 0
        let takeoffStart = columnStart("TKOF") ?? blockTimeStart + blockTimeWidth
        let flightTimeStart = columnStart("FLT TIME") ?? takeoffStart
        let flightTimeWidth = columnWidth("FLT TIME") ?? 0
        let depStart = columnStart("DEP") ?? flightTimeStart + flightTimeWidth
        let ldgFuelStart = columnStart("LDG") ?? depStart
        let ldgFuelWidth = columnWidth("LDG") ?? 0
        let usedStart = columnStart("USED") ?? (ldgFuelStart + ldgFuelWidth)
        let usedWidth = columnWidth("USED") ?? 0
        let paxStart = columnStart("PAX") ?? usedStart + usedWidth
        let paxWidth = columnWidth("PAX") ?? 0
        let cargoStart = columnStart("CARGO") ?? paxStart + paxWidth
        let cargoWidth = columnWidth("CARGO") ?? 0
        let upliftStart = columnStart("UPLIFT") ?? cargoStart + cargoWidth
        let upliftWidth = columnWidth("UPLIFT") ?? 0

        let totalsRect = CGRect(x: rect.minX, y: rect.minY, width: mergedLabelWidth, height: rect.height)
        let tkofStart = columnStart("TKOF") ?? (blockTimeStart + blockTimeWidth)
        let tkofWidth = columnWidth("TKOF") ?? 0
        let ldgStart = columnStart("LDG") ?? (tkofStart + tkofWidth)
        let ldgWidth = columnWidth("LDG") ?? 0

        let blankMidRect = CGRect(x: tkofStart, y: rect.minY, width: (ldgStart + ldgWidth) - tkofStart, height: rect.height)
        let blankFuelRect = CGRect(x: depStart, y: rect.minY, width: usedStart - depStart, height: rect.height)
        let blankRightRect = CGRect(x: upliftStart + upliftWidth, y: rect.minY, width: rect.maxX - (upliftStart + upliftWidth), height: rect.height)

        for fillRect in [totalsRect, blankMidRect, blankFuelRect, blankRightRect] where fillRect.width > 0 {
            context.setFillColor(brandBlue.cgColor)
            context.fill(fillRect)
            context.stroke(fillRect)
        }

        let valueRects: [(CGRect, String)] = [
            (CGRect(x: blockTimeStart, y: rect.minY, width: blockTimeWidth, height: rect.height), TimeEntryHelper.formattedDuration(totalBlockTime)),
            (CGRect(x: flightTimeStart, y: rect.minY, width: flightTimeWidth, height: rect.height), TimeEntryHelper.formattedDuration(totalFlightTime)),
            (CGRect(x: usedStart, y: rect.minY, width: usedWidth, height: rect.height), "\(totalFuelUsed)"),
            (CGRect(x: paxStart, y: rect.minY, width: paxWidth, height: rect.height), "\(totalPax)"),
            (CGRect(x: cargoStart, y: rect.minY, width: cargoWidth, height: rect.height), "\(totalCargo)"),
            (CGRect(x: upliftStart, y: rect.minY, width: upliftWidth, height: rect.height), "\(totalUplift)")
        ]

        for (valueRect, _) in valueRects {
            context.setFillColor(lightFill.cgColor)
            context.fill(valueRect)
            context.stroke(valueRect)
        }

        context.stroke(rect)

        let labelParagraph = NSMutableParagraphStyle()
        labelParagraph.alignment = .left
        let valueParagraph = NSMutableParagraphStyle()
        valueParagraph.alignment = .center

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9),
            .foregroundColor: UIColor.black,
            .paragraphStyle: labelParagraph
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 8),
            .foregroundColor: UIColor.black,
            .paragraphStyle: valueParagraph
        ]

        NSString(string: "TOTALS").draw(
            in: CGRect(x: totalsRect.minX + 8, y: totalsRect.minY + 10, width: totalsRect.width - 12, height: 14),
            withAttributes: labelAttrs
        )

        for (valueRect, valueText) in valueRects {
            NSString(string: valueText).draw(
                in: CGRect(x: valueRect.minX + 2, y: valueRect.minY + 10, width: valueRect.width - 4, height: 14),
                withAttributes: valueAttrs
            )
        }
    }

    private func drawVoyageDelaysBox(
        flight: Flight,
        in rect: CGRect,
        context: CGContext
    ) {
        drawPanel(rect: rect, fill: lightFill, context: context)
        drawSectionTitle("DELAYS", at: CGPoint(x: rect.minX + 10, y: rect.minY + 8), context: context)

        let rows = voyageDelayRows(for: flight)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.black
        ]

        let headerY = rect.minY + 24
        NSString(string: "Leg").draw(at: CGPoint(x: rect.minX + 10, y: headerY), withAttributes: labelAttrs)
        NSString(string: "IATA Code").draw(at: CGPoint(x: rect.minX + 70, y: headerY), withAttributes: labelAttrs)
        NSString(string: "Description").draw(at: CGPoint(x: rect.minX + 150, y: headerY), withAttributes: labelAttrs)
        NSString(string: "Note").draw(at: CGPoint(x: rect.minX + 410, y: headerY), withAttributes: labelAttrs)

        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(1)
        context.stroke(CGRect(x: rect.minX + 8, y: rect.minY + 40, width: rect.width - 16, height: 0))

        if rows.isEmpty {
            let emptyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.darkGray
            ]
            NSString(string: "No delays recorded.").draw(
                in: CGRect(x: rect.minX + 10, y: rect.minY + 46, width: rect.width - 20, height: 12),
                withAttributes: emptyAttrs
            )
            return
        }

        for (index, row) in rows.prefix(2).enumerated() {
            let y = rect.minY + 46 + CGFloat(index) * 12
            NSString(string: row.legLabel).draw(in: CGRect(x: rect.minX + 10, y: y, width: 52, height: 10), withAttributes: valueAttrs)
            NSString(string: row.code).draw(in: CGRect(x: rect.minX + 70, y: y, width: 70, height: 10), withAttributes: valueAttrs)
            NSString(string: row.description).draw(in: CGRect(x: rect.minX + 150, y: y, width: 250, height: 10), withAttributes: valueAttrs)
            NSString(string: row.note).draw(in: CGRect(x: rect.minX + 410, y: y, width: rect.width - 420, height: 10), withAttributes: valueAttrs)
        }
    }

    private func drawVoyageNotesBox(
        flight: Flight,
        in rect: CGRect,
        context: CGContext
    ) {
        drawPanel(rect: rect, fill: lightFill, context: context)
        drawSectionTitle("NOTES", at: CGPoint(x: rect.minX + 10, y: rect.minY + 8), context: context)

        let notes = voyageNotesText(for: flight)
        let noteAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.black
        ]
        let emptyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.darkGray
        ]

        if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            NSString(string: "No notes recorded.").draw(
                in: CGRect(x: rect.minX + 10, y: rect.minY + 24, width: rect.width - 20, height: rect.height - 30),
                withAttributes: emptyAttrs
            )
        } else {
            NSString(string: notes).draw(
                in: CGRect(x: rect.minX + 10, y: rect.minY + 24, width: rect.width - 20, height: rect.height - 30),
                withAttributes: noteAttrs
            )
        }
    }

    private func voyageDelayRows(for flight: Flight) -> [VoyageDelayRow] {
        flight.sortedLegs.flatMap { leg in
            leg.delays.sorted(by: { $0.delayNumber < $1.delayNumber }).map { delay in
                VoyageDelayRow(
                    legLabel: "Leg \(leg.sequence)",
                    code: delay.code,
                    description: delay.descriptionText,
                    note: delay.crewComment
                )
            }
        }
    }

    private func voyageNotesText(for flight: Flight) -> String {
        flight.sortedLegs
            .map { leg in
                let trimmed = leg.crewNote.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return "Leg \(leg.sequence): \(trimmed)"
            }
            .compactMap { $0 }
            .joined(separator: "\n")
    }

    private func tableRowRect(tableRect: CGRect, rowIndex: Int, rowHeight: CGFloat) -> CGRect {
        CGRect(
            x: tableRect.minX,
            y: tableRect.minY + rowHeight + CGFloat(rowIndex) * rowHeight,
            width: tableRect.width,
            height: rowHeight
        )
    }

    // MARK: - Helpers

    private func drawText(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        fontSize: CGFloat,
        in context: CGContext,
        maxWidth: CGFloat = 200
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byTruncatingTail

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]

        NSString(string: text).draw(in: CGRect(x: x, y: y, width: maxWidth, height: 18), withAttributes: attrs)
    }

    private func drawSignatureImage(_ image: UIImage, in rect: CGRect, context: CGContext) {
        image.draw(in: rect)
    }

    private func imageFromDrawingData(_ data: Data?) -> UIImage? {
        guard let data,
              let drawing = try? PKDrawing(data: data) else {
            return nil
        }

        let bounds = drawing.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 300, height: 80) : drawing.bounds
        return drawing.image(from: bounds, scale: 2.0)
    }

    private func pagedItems<T>(_ items: [T], pageIndex: Int, rowsPerPage: Int) -> [T] {
        let start = pageIndex * rowsPerPage
        guard start < items.count else { return [] }
        let end = min(start + rowsPerPage, items.count)
        return Array(items[start..<end])
    }

    private func authorizedFlightDescription(for leg: FlightLeg) -> String {
        let departureName = airportDisplayName(for: leg.departure)
        let destinationName = airportDisplayName(for: leg.destination)
        return "\(leg.departure) (\(departureName)) - \(leg.destination) (\(destinationName))"
    }

    private func distanceText(for leg: FlightLeg) -> String {
        guard let from = coordinate(for: leg.departure),
              let to = coordinate(for: leg.destination) else {
            return "-"
        }

        let meters = CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
        let nauticalMiles = Int((meters / 1852.0).rounded())
        return "\(nauticalMiles)"
    }

    private func airportDisplayName(for code: String) -> String {
        switch code.uppercased() {
        case "FQMA", "MPM": return "Maputo"
        case "FQPB", "POL": return "Pemba"
        case "FQVL", "VNX": return "Vilankulo"
        case "FQBR", "BEW": return "Beira"
        case "FQIN", "INY": return "Inhambane"
        case "FYWH", "WDH": return "Windhoek"
        case "FYKM", "MPA": return "Katima Mulilo"
        case "FYRU", "NDU": return "Rundu"
        case "FYKT", "KMP": return "Keetmanshoop"
        case "FYWB", "WVB": return "Walvis Bay"
        default: return code.uppercased()
        }
    }

    private func coordinate(for code: String) -> CLLocationCoordinate2D? {
        switch code.uppercased() {
        case "FQMA", "MPM": return CLLocationCoordinate2D(latitude: -25.9208, longitude: 32.5726)
        case "FQPB", "POL": return CLLocationCoordinate2D(latitude: -12.9868, longitude: 40.5225)
        case "FQVL", "VNX": return CLLocationCoordinate2D(latitude: -22.0184, longitude: 35.3133)
        case "FQBR", "BEW": return CLLocationCoordinate2D(latitude: -19.7964, longitude: 34.9076)
        case "FQIN", "INY": return CLLocationCoordinate2D(latitude: -23.8764, longitude: 35.4085)
        case "FYWH", "WDH": return CLLocationCoordinate2D(latitude: -22.4799, longitude: 17.4709)
        case "FYKM", "MPA": return CLLocationCoordinate2D(latitude: -17.6344, longitude: 24.1767)
        case "FYRU", "NDU": return CLLocationCoordinate2D(latitude: -17.9565, longitude: 19.7194)
        case "FYKT", "KMP": return CLLocationCoordinate2D(latitude: -26.5398, longitude: 18.1114)
        case "FYWB", "WVB": return CLLocationCoordinate2D(latitude: -22.9799, longitude: 14.6453)
        default: return nil
        }
    }

    private func shortDate(_ date: Date) -> String {
        date.efbDate
    }

    private func durationString(_ minutes: Int?) -> String {
        TimeEntryHelper.formattedDuration(minutes)
    }

    private func intString(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }

    private func nonEmpty(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed
    }
}

private struct VoyageDelayRow {
    let legLabel: String
    let code: String
    let description: String
    let note: String
}

private struct ReportColumn {
    let title: String
    let width: CGFloat
    let alignment: NSTextAlignment
}

private extension Flight {
    var sortedLegs: [FlightLeg] {
        legs.sorted {
            if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                return $0.sequence < $1.sequence
            }
            return $0.date < $1.date
        }
    }

    var sortedDaySigns: [FlightDaySign] {
        daySigns.sorted { $0.date < $1.date }
    }

    var reportFolderDate: Date {
        sortedLegs.first?.date ?? createdAt
    }
}

