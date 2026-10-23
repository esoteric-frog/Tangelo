import Darwin
import Foundation

public enum OutputNamer {
    /// Move `temp` into `dir` as `name`, or `name 2`, `name 3`… Never overwrites.
    /// FileManager.moveItem checks-then-renames, so two racing jobs can clobber each other;
    /// renamex_np(RENAME_EXCL) makes "only if the name is free" one atomic step.
    public static func place(_ temp: URL, in dir: URL, name: String) throws -> URL {
        let fm = FileManager.default
        var source = temp
        defer {
            if source != temp {  // staged copy used: drop both leftovers (the placed file is safe at its new name)
                try? fm.removeItem(at: source)
                try? fm.removeItem(at: temp)
            }
        }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var n = 1
        while n <= 10_000 {
            let candidate = n == 1 ? name : "\(base) \(n)" + (ext.isEmpty ? "" : ".\(ext)")
            let url = dir.appendingPathComponent(candidate)
            if renamex_np(source.path, url.path, UInt32(RENAME_EXCL)) == 0 { return url }
            let err = errno
            if err == EEXIST { n += 1; continue }
            if err == EXDEV && source == temp {
                // Different disk: copy next to the target, then retry the same name within that disk.
                let staged = dir.appendingPathComponent(".tangelo-\(UUID().uuidString)")
                do { try fm.copyItem(at: temp, to: staged) } catch {
                    throw TangeloError("Couldn't save into \(dir.lastPathComponent): \(error.localizedDescription)")
                }
                source = staged
                continue
            }
            throw TangeloError("Couldn't save into \(dir.lastPathComponent): \(String(cString: strerror(err)))")
        }
        throw TangeloError("Too many files named \(name) in \(dir.lastPathComponent)")
    }
}
