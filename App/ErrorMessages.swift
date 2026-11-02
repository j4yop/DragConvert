import Foundation

extension Error {
    /// Cocoa file-system errors are unreadable in a toast. Map the common ones
    /// to a sentence a person can act on; fall back to the system message.
    var friendlyMessage: String {
        let ns = self as NSError
        switch (ns.domain, ns.code) {
        case (NSCocoaErrorDomain, NSFileWriteNoPermissionError):
            return "No permission to save there. Use “Grant Folder Access…” and try again."
        case (NSCocoaErrorDomain, NSFileWriteOutOfSpaceError):
            return "Not enough disk space to save the result."
        case (NSCocoaErrorDomain, NSFileReadNoSuchFileError):
            return "The file moved or was deleted before it could be read."
        case (NSCocoaErrorDomain, NSFileReadNoPermissionError):
            return "No permission to read that file."
        case (NSCocoaErrorDomain, NSFileWriteFileExistsError):
            return "A file with that name is already open."
        default:
            return localizedDescription
        }
    }
}
