import Foundation
import Observation

/// Shared services, injected once at the root through the SwiftUI environment.
@MainActor
@Observable
final class AppModel {
    let catalog: any CatalogService
    let entitlements: EntitlementStore
    let purchases: PurchaseService
    let library: LibraryStore
    @ObservationIgnored let players = PlayerPool()

    init(
        catalog: any CatalogService = MockCatalogService(),
        entitlements: EntitlementStore = EntitlementStore(),
        library: LibraryStore = LibraryStore()
    ) {
        self.catalog = catalog
        self.entitlements = entitlements
        self.library = library
        purchases = PurchaseService(entitlements: entitlements)
    }
}
