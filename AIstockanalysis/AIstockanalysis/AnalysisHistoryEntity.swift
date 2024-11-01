import CoreData

@objc(AnalysisHistoryEntity)
public class AnalysisHistoryEntity: NSManagedObject {
    @NSManaged public var confidence: Int16
    @NSManaged public var currentPrice: Double
    @NSManaged public var decision: String?
    @NSManaged public var expectedPrice: Double
    @NSManaged public var id: UUID?
    @NSManaged public var language: String?
    @NSManaged public var reason: String?
    @NSManaged public var symbol: String?
    @NSManaged public var timestamp: Date?
}

// MARK: - Generated accessors
extension AnalysisHistoryEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AnalysisHistoryEntity> {
        return NSFetchRequest<AnalysisHistoryEntity>(entityName: "AnalysisHistoryEntity")
    }
    
    var decisionType: StockAnalysis.Decision {
        get {
            return StockAnalysis.Decision(rawValue: decision ?? "NEUTRAL") ?? .neutral
        }
        set {
            decision = newValue.rawValue
        }
    }
}

// MARK: - Identifiable Support
extension AnalysisHistoryEntity: Identifiable {}
