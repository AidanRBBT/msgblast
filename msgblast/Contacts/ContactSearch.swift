import Contacts
import msgblastCore

@MainActor
final class ContactSearch {
    let store = CNContactStore()
    private let keysToFetch: [CNKeyDescriptor] = [CNContactIdentifierKey, CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactThumbnailImageDataKey].map { $0 as CNKeyDescriptor }
    var status: CNAuthorizationStatus { CNContactStore.authorizationStatus(for: .contacts) }
    func request() async throws { guard try await store.requestAccess(for: .contacts) else { throw AppFailure.blocked("Contacts access denied. Enable Contacts for msgblast in System Settings.") } }
    func search(_ query: String) throws -> [Agent] {
        guard status == .authorized else { throw AppFailure.blocked("Allow Contacts access to search for agents.") }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let keys = keysToFetch
        // Name search is performed by Contacts; exact email/number queries search only matching records.
        var contacts: [CNContact] = []
        if query.contains("@") || query.filter(\.isNumber).count >= 5 {
            let request = CNContactFetchRequest(keysToFetch: keys)
            try store.enumerateContacts(with: request) { contact, _ in
                let handles = contact.emailAddresses.map { String($0.value) } + contact.phoneNumbers.map { $0.value.stringValue }
                if handles.contains(where: { ChatResolver.normalize($0).contains(ChatResolver.normalize(query)) }) { contacts.append(contact) }
            }
        } else { contacts = try store.unifiedContacts(matching: CNContact.predicateForContacts(matchingName: query), keysToFetch: keys) }
        return contacts.map { contact in
            let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let handles = contact.phoneNumbers.map { $0.value.stringValue } + contact.emailAddresses.map { String($0.value) }
            return Agent(contactID: contact.identifier, name: name.isEmpty ? (handles.first ?? "Agent") : name, handles: handles, avatar: contact.thumbnailImageData, colorIndex: abs(contact.identifier.hashValue % 6))
        }
    }
    func saveManual(_ agent: Agent) async throws -> Agent {
        if status == .notDetermined { try await request() }
        guard status == .authorized else { throw AppFailure.blocked("Contacts access is needed to save this agent. Enable Contacts for msgblast in System Settings.") }
        guard let handle = agent.handles.first else { throw AppFailure.blocked("Enter an email address or phone number.") }
        let normalized = ChatResolver.normalize(handle)
        if var existing = try search(handle).first(where: { $0.handles.contains { ChatResolver.normalize($0) == normalized } }) {
            existing.id = agent.id
            return existing
        }
        let contact = CNMutableContact()
        if agent.name != handle { contact.givenName = agent.name }
        contact.imageData = agent.avatar
        if handle.contains("@") {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelOther, value: handle as NSString)]
        } else {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelOther, value: CNPhoneNumber(stringValue: handle))]
        }
        let request = CNSaveRequest()
        request.add(contact, toContainerWithIdentifier: nil)
        try store.execute(request)
        let stored = try store.unifiedContact(withIdentifier: contact.identifier, keysToFetch: keysToFetch)
        var saved = agent
        saved.contactID = stored.identifier
        return saved
    }
    func refreshed(_ agent: Agent) throws -> Agent {
        guard let contactID = agent.contactID else { throw AppFailure.blocked("This agent has no saved Contacts entry. Add it again before sending.") }
        guard status == .authorized else { throw AppFailure.blocked("Contacts permission is unavailable. Restore it before resolving destinations.") }
        let keys = keysToFetch
        let contact = try store.unifiedContact(withIdentifier: contactID, keysToFetch: keys)
        var result = agent
        result.handles = contact.phoneNumbers.map { $0.value.stringValue } + contact.emailAddresses.map { String($0.value) }
        result.avatar = contact.thumbnailImageData
        return result
    }
}
