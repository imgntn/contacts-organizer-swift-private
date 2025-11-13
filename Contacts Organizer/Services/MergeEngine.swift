import Contacts

struct MergeEngine {
    static func mergedContact(
        configuration: MergeConfiguration,
        destinationContact: CNContact,
        sourceContacts: [CNContact]
    ) -> CNMutableContact {
        let allContacts = [destinationContact] + sourceContacts
        let mergedContact = destinationContact.mutableCopy() as! CNMutableContact

        applyPreferredName(configuration, to: mergedContact, from: allContacts)
        applyPreferredOrganization(configuration, to: mergedContact, from: allContacts)
        applyPreferredPhoto(configuration, to: mergedContact, from: allContacts)

        mergedContact.phoneNumbers = mergePhoneNumbers(
            destinationContact: destinationContact,
            sources: sourceContacts,
            allowedValues: configuration.includedPhoneNumbers
        )

        mergedContact.emailAddresses = mergeEmailAddresses(
            destinationContact: destinationContact,
            sources: sourceContacts,
            allowedValues: configuration.includedEmailAddresses
        )

        mergePostalAddresses(into: mergedContact, from: sourceContacts)
        mergeURLAddresses(into: mergedContact, from: sourceContacts)
        mergeSocialProfiles(into: mergedContact, from: sourceContacts)
        mergeInstantMessages(into: mergedContact, from: sourceContacts)

        if mergedContact.birthday == nil {
            for source in sourceContacts {
                if let birthday = source.birthday {
                    mergedContact.birthday = birthday
                    break
                }
            }
        }

        return mergedContact
    }

    private static func applyPreferredName(_ configuration: MergeConfiguration, to contact: CNMutableContact, from contacts: [CNContact]) {
        let targetId = configuration.preferredNameSourceId ?? configuration.primaryContactId
        guard let source = contacts.first(where: { $0.identifier == targetId }) else { return }
        contact.givenName = source.givenName
        contact.familyName = source.familyName
        contact.middleName = source.middleName
        contact.nickname = source.nickname
        contact.namePrefix = source.namePrefix
        contact.nameSuffix = source.nameSuffix
    }

    private static func applyPreferredOrganization(_ configuration: MergeConfiguration, to contact: CNMutableContact, from contacts: [CNContact]) {
        let targetId = configuration.preferredOrganizationSourceId ?? configuration.primaryContactId
        guard let source = contacts.first(where: { $0.identifier == targetId }) else { return }
        if !source.organizationName.isEmpty {
            contact.organizationName = source.organizationName
            contact.departmentName = source.departmentName
            contact.jobTitle = source.jobTitle
        }
    }

    private static func applyPreferredPhoto(_ configuration: MergeConfiguration, to contact: CNMutableContact, from contacts: [CNContact]) {
        guard let photoSourceId = configuration.preferredPhotoSourceId,
              let source = contacts.first(where: { $0.identifier == photoSourceId }),
              source.imageDataAvailable,
              let imageData = source.imageData else {
            return
        }
        contact.imageData = imageData
    }

    private static func mergePhoneNumbers(
        destinationContact: CNContact,
        sources: [CNContact],
        allowedValues: Set<String>?
    ) -> [CNLabeledValue<CNPhoneNumber>] {
        var final: [CNLabeledValue<CNPhoneNumber>] = []
        var seen = Set<String>()
        let whitelist = allowedValues

        let allPhones = destinationContact.phoneNumbers + sources.flatMap { $0.phoneNumbers }
        for phone in allPhones {
            let value = phone.value.stringValue
            if let whitelist, !whitelist.contains(value) {
                continue
            }
            if seen.insert(value).inserted {
                final.append(phone)
            }
        }

        return final
    }

    private static func mergeEmailAddresses(
        destinationContact: CNContact,
        sources: [CNContact],
        allowedValues: Set<String>?
    ) -> [CNLabeledValue<NSString>] {
        var final: [CNLabeledValue<NSString>] = []
        var seen = Set<String>()
        let whitelist = allowedValues
        let allEmails = destinationContact.emailAddresses + sources.flatMap { $0.emailAddresses }

        for email in allEmails {
            let value = email.value as String
            if let whitelist, !whitelist.contains(value) {
                continue
            }
            if seen.insert(value).inserted {
                final.append(email)
            }
        }

        return final
    }

    private static func mergePostalAddresses(into contact: CNMutableContact, from sources: [CNContact]) {
        for source in sources {
            for address in source.postalAddresses {
                let exists = contact.postalAddresses.contains { existing in
                    let lhs = existing.value
                    let rhs = address.value
                    return lhs.street == rhs.street && lhs.city == rhs.city && lhs.postalCode == rhs.postalCode
                }
                if !exists {
                    contact.postalAddresses.append(address)
                }
            }
        }
    }

    private static func mergeURLAddresses(into contact: CNMutableContact, from sources: [CNContact]) {
        var seen = Set(contact.urlAddresses.map { $0.value as String })
        for source in sources {
            for url in source.urlAddresses {
                let value = url.value as String
                if seen.insert(value).inserted {
                    contact.urlAddresses.append(url)
                }
            }
        }
    }

    private static func mergeSocialProfiles(into contact: CNMutableContact, from sources: [CNContact]) {
        for source in sources {
            for profile in source.socialProfiles {
                let duplicate = contact.socialProfiles.contains { existing in
                    existing.value.service == profile.value.service &&
                    existing.value.username == profile.value.username
                }
                if !duplicate {
                    contact.socialProfiles.append(profile)
                }
            }
        }
    }

    private static func mergeInstantMessages(into contact: CNMutableContact, from sources: [CNContact]) {
        for source in sources {
            for im in source.instantMessageAddresses {
                let duplicate = contact.instantMessageAddresses.contains { existing in
                    existing.value.service == im.value.service &&
                    existing.value.username == im.value.username
                }
                if !duplicate {
                    contact.instantMessageAddresses.append(im)
                }
            }
        }
    }
}

extension MergePlan {
    func configuration(primaryContactId: String, group: DuplicateGroup) -> MergeConfiguration {
        MergeConfiguration(
            primaryContactId: primaryContactId,
            mergingContactIds: group.contacts.map { $0.id },
            preferredNameSourceId: preferredNameContactId,
            preferredOrganizationSourceId: preferredOrganizationContactId,
            preferredPhotoSourceId: preferredPhotoContactId,
            includedPhoneNumbers: selectedPhoneNumbers,
            includedEmailAddresses: selectedEmailAddresses
        )
    }
}
