import Foundation
import Testing
@testable import NoyaCore

@Suite("Assistant requests")
struct AssistantParserTests {
    private let workspaces = ["Freelance", "Impôts 2026"]

    @Test("Finds invoices of a year and the workspace to put them in")
    func invoicesIntoWorkspace() {
        let intent = AssistantParser.parse(
            "Trouve mes factures de 2026 et range-les dans l'espace Impôts 2026.",
            workspaces: workspaces
        )
        #expect(intent == .gather(AssistantRequest(
            topic: .invoices, year: 2026, workspaceName: "Impôts 2026", workspaceExists: true, renames: true
        )))
    }

    @Test("Matches workspaces whatever the case and accents")
    func workspaceMatching() {
        // “2026” belongs to the workspace name here, not to the search.
        let intent = AssistantParser.parse("ajoute mes contrats à l’espace impots 2026 sans renommer", workspaces: workspaces)
        #expect(intent == .gather(AssistantRequest(
            topic: .contracts, workspaceName: "Impôts 2026", workspaceExists: true, renames: false
        )))
    }

    @Test("A workspace that does not exist yet is created")
    func newWorkspace() {
        let intent = AssistantParser.parse("Put my receipts into the workspace Japan Trip", workspaces: workspaces)
        #expect(intent == .gather(AssistantRequest(topic: .receipts, workspaceName: "Japan Trip", workspaceExists: false)))
    }

    @Test("Keeps the extra words of a request, such as a company name")
    func keywords() {
        let intent = AssistantParser.parse("Trouve les factures EDF de l'année dernière", now: date(2026, 11, 15))
        #expect(intent == .gather(AssistantRequest(topic: .invoices, keywords: ["EDF"], year: 2025)))
    }

    @Test("Searches plain words when no kind of document is named")
    func plainSearch() {
        let intent = AssistantParser.parse("Trouve le budget vacances")
        #expect(intent == .gather(AssistantRequest(keywords: ["budget", "vacances"])))
    }

    @Test("Recognizes the suggested requests")
    func suggestions() {
        #expect(AssistantParser.parse("Résume ce PDF") == .summarize)
        #expect(AssistantParser.parse("Renomme mes captures d'écran") == .renameScreenshots)
        #expect(AssistantParser.parse("Rename my screenshots") == .renameScreenshots)
        #expect(AssistantParser.parse("Que puis-je supprimer ?") == .freeUpSpace)
        #expect(AssistantParser.parse("What can I delete?") == .freeUpSpace)
    }

    @Test("Says when it does not understand")
    func unknown() {
        #expect(AssistantParser.parse("") == .unknown)
        #expect(AssistantParser.parse("et les") == .unknown)
    }

    @Test("Builds a Spotlight query for a topic and keywords")
    func query() {
        let request = AssistantRequest(topic: .invoices, keywords: ["EDF"], year: 2026)
        let query = request.spotlightQuery ?? ""
        #expect(query.hasPrefix(#"(kMDItemFSName == "*facture*"cd || kMDItemTextContent == "*facture*"cd || kMDItemFSName == "*invoice*"cd"#))
        #expect(query.contains(#"kMDItemContentTypeTree == "com.adobe.pdf""#))
        #expect(query.hasSuffix(#"(kMDItemFSName == "*EDF*"cd || kMDItemTextContent == "*EDF*"cd)"#))
        #expect(!query.contains("2026"))
        #expect(AssistantRequest().spotlightQuery == nil)
        #expect(AssistantRequest(topic: .screenshots).spotlightQuery?.contains("kMDItemIsScreenCapture == 1") == true)
    }

    @Test("Matches files found without Spotlight")
    func directMatching() {
        let invoices = AssistantRequest(topic: .invoices)
        #expect(invoices.matches(fileName: "Facture 2026-118.pdf", text: nil))
        #expect(invoices.matches(fileName: "scan0012.pdf", text: "EDF\nFACTURE n° 4471"))
        #expect(!invoices.matches(fileName: "scan0013.pdf", text: "Contrat de location"))
        #expect(!invoices.matches(fileName: "Facture.docx", text: nil))

        let edf = AssistantRequest(topic: .invoices, keywords: ["EDF"])
        #expect(edf.matches(fileName: "scan0012.pdf", text: "Facture EDF"))
        #expect(!edf.matches(fileName: "document(3).pdf", text: "Facture Free"))

        let photos = AssistantRequest(topic: .photos)
        #expect(photos.matches(fileName: "IMG_4021.HEIC", text: nil))
        #expect(!photos.matches(fileName: "notes.txt", text: nil))
        #expect(AssistantRequest(keywords: ["budget"]).matches(fileName: "Budget vacances.numbers", text: nil))
        #expect(!AssistantRequest().matches(fileName: "anything.pdf", text: nil))
    }

    @Test("Checks the year on each file")
    func year() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let request = AssistantRequest(topic: .invoices, year: 2026)
        let in2025 = calendar.date(from: DateComponents(year: 2025, month: 12, day: 30))!
        let in2026 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        #expect(request.matchesYear(fileName: "Facture 2026-118.pdf", dates: [in2025], calendar: calendar))
        #expect(request.matchesYear(fileName: "scan0012.pdf", dates: [in2025, in2026], calendar: calendar))
        #expect(!request.matchesYear(fileName: "scan0012.pdf", dates: [in2025], calendar: calendar))
        #expect(AssistantRequest(topic: .invoices).matchesYear(fileName: "old.pdf", dates: [in2025]))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
    }
}

@Suite("File names")
struct FileNamingTests {
    @Test("Spots names that say nothing about the file")
    func unclearNames() {
        for name in ["scan0012.pdf", "document(3).pdf", "IMG_4021.HEIC", "Sans titre 2.pdf", "20261012_1432.pdf",
                     "3f9a2c1e-77b0-4c1d.pdf", "doc.pdf", "Screenshot 2026-11-02 at 10.12.44.png"] {
            #expect(FileNaming.isUnclear(name), "\(name)")
        }
        for name in ["Facture 2026-118.pdf", "Relevé EDF juillet.pdf", "Contrat de location.pdf", "budget-2026.numbers"] {
            #expect(!FileNaming.isUnclear(name), "\(name)")
        }
    }

    @Test("Names an invoice after its sender and month")
    func invoiceName() {
        let text = """
        EDF
        Facture n° 1234567
        Date : 12/10/2026
        Votre espace client : www.edf.fr
        Contact : service-client@edf.fr — client : jean.dupont@gmail.com
        Montant TTC : 84,12 €
        """
        #expect(FileNaming.proposedName(fromText: text, title: "Facture") == "Facture EDF octobre 2026")
        #expect(FileNaming.proposedName(fromText: text, title: "Invoice", languageCode: "en") == "Invoice EDF October 2026")
    }

    @Test("Uses written dates and company names")
    func writtenDates() {
        let text = """
        Free SAS
        8 rue de la Ville l'Évêque, Paris
        Facture du 3 septembre 2026
        """
        #expect(FileNaming.proposedName(fromText: text, title: "Facture") == "Facture Free septembre 2026")
        let website = "Facture du 3 septembre 2026\nVotre espace abonné : https://subscribe.free.fr/login"
        #expect(FileNaming.proposedName(fromText: website, title: "Facture") == "Facture Free septembre 2026")
        #expect(FileNaming.issuer(in: "Order from shop.acme.co.uk") == nil)
        #expect(FileNaming.issuer(in: "See https://www.acme.co.uk") == "Acme")
    }

    @Test("Gives up when the text says neither who nor when")
    func noName() {
        #expect(FileNaming.proposedName(fromText: "Merci pour votre commande.", title: "Facture") == nil)
    }

    @Test("Finds the first date in several formats")
    func dates() {
        #expect(FileNaming.firstDate(in: "Émis le 2026-03-04, échéance 2026-04-04") == .init(month: 3, year: 2026))
        #expect(FileNaming.firstDate(in: "Statement — February 2025") == .init(month: 2, year: 2025))
        #expect(FileNaming.firstDate(in: "Le 15 août 2026 à Paris") == .init(month: 8, year: 2026))
        #expect(FileNaming.firstDate(in: "Aucune date") == nil)
    }

    @Test("Names a screenshot after its first readable line")
    func screenshotName() {
        let text = "12:04\nRéglages Système\nGénéral\nÀ propos"
        #expect(FileNaming.proposedScreenshotName(fromText: text, prefix: "Capture") == "Capture – Réglages Système")
    }

    @Test("Removes characters macOS refuses in names")
    func sanitizing() {
        #expect(FileNaming.sanitized(" « Facture 10/2026: EDF » ") == "Facture 10-2026- EDF")
    }
}

@Suite("Summaries")
struct SummarizerTests {
    @Test("Keeps the sentences that best sum up the text, in order")
    func keySentences() {
        let text = """
        Ce contrat de location porte sur un appartement situé à Lyon. Le loyer mensuel du logement est de 950 euros, \
        charges comprises. Il fait beau aujourd'hui. Le locataire verse un dépôt de garantie équivalent à un loyer. \
        Le contrat de location prend effet le 1er décembre 2026 pour une durée de trois ans.
        """
        let summary = Summarizer.keySentences(in: text, count: 2)
        #expect(summary.count == 2)
        #expect(summary.first?.hasPrefix("Ce contrat de location") == true)
        #expect(!summary.contains("Il fait beau aujourd'hui."))
    }

    @Test("Short texts are returned whole")
    func shortText() {
        #expect(Summarizer.keySentences(in: "Une seule phrase assez longue ici.", count: 3) == ["Une seule phrase assez longue ici."])
    }

    @Test("Joins lines broken in the middle of a sentence")
    func lineBreaks() {
        let sentences = Summarizer.splitSentences("Le loyer est payé\nchaque mois par virement.\n\nTitre suivant sans point")
        #expect(sentences == ["Le loyer est payé chaque mois par virement.", "Titre suivant sans point"])
    }
}
