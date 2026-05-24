import Foundation

enum Input: String, CaseIterable, Identifiable, Hashable {
    case displayPort1
    case displayPort2
    case hdmi
    case hdmi2
    case usbC

    var id: String { rawValue }

    var label: String {
        switch self {
        case .displayPort1: "DisplayPort 1"
        case .displayPort2: "DisplayPort 2"
        case .hdmi:         "HDMI 1"
        case .hdmi2:        "HDMI 2"
        case .usbC:         "USB-C"
        }
    }

    var ddcCode: UInt16 {
        switch self {
        case .displayPort1: ddcInputDP1
        case .displayPort2: ddcInputDP2
        case .hdmi:         ddcInputHDMI
        case .hdmi2:        ddcInputHDMI2
        case .usbC:         ddcInputUSBC
        }
    }

    var standardCode: UInt16 {
        switch self {
        case .displayPort1: ddcStdDP1
        case .displayPort2: ddcStdDP2
        case .hdmi:         ddcStdHDMI
        case .hdmi2:        ddcStdHDMI2
        case .usbC:         ddcStdUSBC
        }
    }

    func code(for mode: InputMode) -> UInt16 {
        mode == .alt ? ddcCode : standardCode
    }
}
