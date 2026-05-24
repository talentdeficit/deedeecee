import Foundation
import CoreGraphics
import IOKit

// Set to true by MonitorService after loading AppConfig.diagnostics.
nonisolated(unsafe) var ddcVerbose = false

// MARK: - Private framework symbols

// CoreDisplay is linked via Package.swift linker flags so its symbols live in the
// process image. RTLD_DEFAULT (-2) resolves symbols from all linked images.
// dlopen on macOS 12+ fails because framework binaries are in the dyld shared cache.
private nonisolated(unsafe) let processHandle = UnsafeMutableRawPointer(bitPattern: -2)

private func load<T>(_ name: String) -> T? {
    guard let raw = dlsym(processHandle, name) else { return nil }
    return unsafeBitCast(raw, to: T.self)
}

private func cstring(_ buf: [CChar]) -> String {
    buf.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
}

private typealias AVCreateFn = @convention(c) (CFAllocator?, io_service_t) -> OpaquePointer?
private let avServiceCreate: AVCreateFn? = load("IOAVServiceCreateWithService")

private typealias AVWriteFn = @convention(c) (OpaquePointer, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn
private let avServiceWrite: AVWriteFn? = load("IOAVServiceWriteI2C")

// MARK: - External display model

struct ExternalDisplay: Identifiable, Sendable {
    let id: String        // IORegistry proxy path (session-stable)
    let name: String
    let displayId: String // "ManufacturerID-ProductID", e.g. "GSM-23745"
    fileprivate let avProxyPath: String
}

// MARK: - Display discovery

private struct ShimInfo {
    var name: String = "Unknown Display"
    var displayId: String = "UNK-0"
}

func discoverExternalDisplays() -> [ExternalDisplay] {
    // Single IORegistry pass correlated by "dispextN" key.
    // IOMobileFramebufferShim: .../dispextN@ADDR/IOMobileFramebufferShim  → name + ids + capability flags
    // DCPAVServiceProxy:       .../dispextN:dcpav-service-epic:N/DCPAVServiceProxy → DDC endpoint
    var shimByDispext: [String: ShimInfo] = [:]
    var proxyPathByDispext: [String: String] = [:]

    var iter: io_iterator_t = 0
    guard IORegistryEntryCreateIterator(
        IORegistryGetRootEntry(kIOMainPortDefault),
        kIOServicePlane,
        IOOptionBits(kIORegistryIterateRecursively),
        &iter
    ) == KERN_SUCCESS else { return [] }
    defer { IOObjectRelease(iter) }

    var nameBuf = [CChar](repeating: 0, count: 128)
    var pathBuf = [CChar](repeating: 0, count: 512)

    while true {
        let svc = IOIteratorNext(iter)
        guard svc != MACH_PORT_NULL else { break }
        defer { IOObjectRelease(svc) }

        IORegistryEntryGetName(svc, &nameBuf)
        let nodeName = cstring(nameBuf)

        if nodeName == "IOMobileFramebufferShim" {
            guard IORegistryEntryGetPath(svc, kIOServicePlane, &pathBuf) == KERN_SUCCESS else { continue }
            guard let key = dispextKey(from: cstring(pathBuf), separator: "@") else { continue }
            guard
                let raw = IORegistryEntryCreateCFProperty(svc, "DisplayAttributes" as CFString, kCFAllocatorDefault, 0),
                let attrs = raw.takeRetainedValue() as? NSDictionary,
                let product = attrs["ProductAttributes"] as? [String: Any]
            else { continue }

            let name = product["ProductName"] as? String ?? "Unknown Display"
            let mfr  = product["ManufacturerID"] as? String ?? "UNK"
            let pid  = product["ProductID"] as? Int ?? 0

            shimByDispext[key] = ShimInfo(
                name: name,
                displayId: "\(mfr)-\(pid)"
            )
        }

        if nodeName == "DCPAVServiceProxy" {
            let location = IORegistryEntryCreateCFProperty(svc, "Location" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
            guard location == "External" else { continue }
            guard IORegistryEntryGetPath(svc, kIOServicePlane, &pathBuf) == KERN_SUCCESS else { continue }
            let proxyPath = cstring(pathBuf)
            guard let key = dispextKey(from: proxyPath, separator: ":") else { continue }
            proxyPathByDispext[key] = proxyPath
        }
    }

    return proxyPathByDispext.map { (key, proxyPath) in
        let shim = shimByDispext[key] ?? ShimInfo()
        return ExternalDisplay(
            id: proxyPath,
            name: shim.name,
            displayId: shim.displayId,
            avProxyPath: proxyPath
        )
    }
}

// Extracts the "dispextN" prefix from the first path component that starts with
// "dispext" and contains the given separator character.
private func dispextKey(from path: String, separator: Character) -> String? {
    for component in path.split(separator: "/") {
        guard component.hasPrefix("dispext"), let sepIdx = component.firstIndex(of: separator) else { continue }
        return String(component[..<sepIdx])
    }
    return nil
}

// MARK: - IOAVService lookup

private func findAVService(for display: ExternalDisplay) -> OpaquePointer? {
    guard let avServiceCreate else { return nil }
    let entry = IORegistryEntryCopyFromPath(kIOMainPortDefault, display.avProxyPath as CFString)
    guard entry != MACH_PORT_NULL else { return nil }
    defer { IOObjectRelease(entry) }
    return avServiceCreate(nil, entry)
}

// MARK: - Diagnostics

func ddcDiagnose() {
    guard ddcVerbose else { return }
    func log(_ s: String) { fputs("DDC: \(s)\n", stderr) }

    log("avServiceCreate  = \(avServiceCreate  != nil ? "ok" : "MISSING symbol")")
    log("avServiceWrite   = \(avServiceWrite   != nil ? "ok" : "MISSING symbol")")

    var count: CGDisplayCount = 0
    CGGetOnlineDisplayList(0, nil, &count)
    log("online displays  = \(count)")

    // Scan for all IORegistry nodes that carry DisplayAttributes
    log("scanning IORegistry for DisplayAttributes...")
    var iter: io_iterator_t = 0
    IORegistryEntryCreateIterator(
        IORegistryGetRootEntry(kIOMainPortDefault),
        kIOServicePlane,
        IOOptionBits(kIORegistryIterateRecursively),
        &iter
    )
    var nameBuf = [CChar](repeating: 0, count: 128)
    var pathBuf = [CChar](repeating: 0, count: 512)
    while true {
        let svc = IOIteratorNext(iter)
        guard svc != MACH_PORT_NULL else { break }
        defer { IOObjectRelease(svc) }
        guard
            let raw = IORegistryEntryCreateCFProperty(svc, "DisplayAttributes" as CFString, kCFAllocatorDefault, 0),
            let attrs = raw.takeRetainedValue() as? NSDictionary,
            let product = attrs["ProductAttributes"] as? [String: Any]
        else { continue }
        let name  = product["ProductName"] as? String ?? "?"
        let mfr   = product["ManufacturerID"] as? String ?? "?"
        let pid   = product["ProductID"] as? Int ?? 0
        let activeOff = (attrs["SupportsActiveOff"] as? Int ?? 0) != 0
        let standby   = (attrs["SupportsStandby"]   as? Int ?? 0) != 0
        log("  \(mfr)-\(pid):  # \(name) (activeOff=\(activeOff) standby=\(standby))")
    }
    IOObjectRelease(iter)

    log("scanning IORegistry for DCPAVServiceProxy...")
    IORegistryEntryCreateIterator(
        IORegistryGetRootEntry(kIOMainPortDefault),
        kIOServicePlane,
        IOOptionBits(kIORegistryIterateRecursively),
        &iter
    )
    defer { IOObjectRelease(iter) }
    while true {
        let svc = IOIteratorNext(iter)
        guard svc != MACH_PORT_NULL else { break }
        defer { IOObjectRelease(svc) }
        IORegistryEntryGetName(svc, &nameBuf)
        guard cstring(nameBuf) == "DCPAVServiceProxy" else { continue }
        IORegistryEntryGetPath(svc, kIOServicePlane, &pathBuf)
        let proxyPath = cstring(pathBuf)
        let location = IORegistryEntrySearchCFProperty(
            svc, kIOServicePlane, "Location" as CFString,
            kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)
        ) as? String ?? "nil"
        log("  DCPAVServiceProxy location=\(location) path=\(proxyPath)")
    }

    let displays = discoverExternalDisplays()
    log("discovered \(displays.count) external display(s):")
    for d in displays {
        log("  \(d.displayId):  # \(d.name)")
    }
}

// MARK: - Input mode

enum InputMode: String, Sendable {
    case alt       // LG proprietary: VCP 0xF4 at I2C sub-address 0x50
    case standard  // VESA DDC/CI:    VCP 0x60 at I2C sub-address 0x51
}

// MARK: - DDC constants

// LG alt-mode input codes (VCP 0xF4)
let ddcInputDP1:   UInt16 = 208
let ddcInputDP2:   UInt16 = 209
let ddcInputHDMI:  UInt16 = 144
let ddcInputHDMI2: UInt16 = 145
let ddcInputUSBC:  UInt16 = 210

// Standard DDC/CI input source codes (VCP 0x60)
let ddcStdDP1:   UInt16 = 0x0F
let ddcStdDP2:   UInt16 = 0x10
let ddcStdHDMI:  UInt16 = 0x11
let ddcStdHDMI2: UInt16 = 0x12
let ddcStdUSBC:  UInt16 = 0x1B  // common; varies by monitor

private let vcpInputAlt: UInt8  = 0xF4
private let vcpInputStd: UInt8  = 0x60
private let addrAlt:     UInt32 = 0x50  // LG alt-mode sub-address
private let addrStd:     UInt32 = 0x51  // standard DDC/CI host address
private let chipAddr:    UInt32 = 0x37
private let ddcWait:     UInt32 = 10_000
private let ddcRetries          = 2

// MARK: - DDC write

func ddcWriteInput(_ display: ExternalDisplay, code: UInt16, mode: InputMode) -> Bool {
    let vcp  = mode == .alt ? vcpInputAlt : vcpInputStd
    let addr = mode == .alt ? addrAlt     : addrStd
    guard let svc = findAVService(for: display),
          let avServiceWrite
    else { return false }

    var pkt = [UInt8](repeating: 0, count: 256)
    pkt[0] = 0x84
    pkt[1] = 0x03
    pkt[2] = vcp
    pkt[3] = UInt8(code >> 8)
    pkt[4] = UInt8(code & 0xFF)
    pkt[5] = 0x6E ^ UInt8(addr) ^ pkt[0] ^ pkt[1] ^ pkt[2] ^ pkt[3] ^ pkt[4]

    let pktLen = UInt32(pkt.lastIndex(where: { $0 != 0 }).map { $0 + 1 } ?? 0)
    if ddcVerbose { fputs("DDC write: \(display.name) vcp=0x\(String(vcp, radix: 16)) addr=0x\(String(addr, radix: 16)) code=\(code) pkt=\(pkt[0..<6].map { String(format: "%02X", $0) }.joined(separator: " "))\n", stderr) }
    for i in 0..<ddcRetries {
        usleep(ddcWait)
        let err = pkt.withUnsafeMutableBytes { avServiceWrite(svc, chipAddr, addr, $0.baseAddress!, pktLen) }
        if ddcVerbose { fputs("DDC write: \(display.name) attempt=\(i) err=\(err)\n", stderr) }
        if err != 0 { return false }
    }

    return true
}
