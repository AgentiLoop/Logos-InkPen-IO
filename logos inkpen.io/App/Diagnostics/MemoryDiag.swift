import Foundation
import CoreGraphics

enum MemoryDiag {
    private static var lastReport = Date.distantPast
    private static var baselineMB = 0

    static func setBaseline() {
        baselineMB = processMemoryMB()
    }

    static func checkpoint(_ label: String) {
        _ = label
    }

    static func report(_ label: String, document: VectorDocument? = nil) {
        _ = (label, document)
    }

    static func dumpObjects(_ doc: VectorDocument) {
        _ = doc
    }

    static func measureObjectSizes(_ doc: VectorDocument) {
        _ = doc
    }

    static func processMemoryMB() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Int(info.phys_footprint) / (1024 * 1024)
    }
}
